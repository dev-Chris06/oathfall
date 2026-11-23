class_name Enemy
extends CharacterBody3D
## Un mort d'Orvana.
##
## Abattu, il ne disparaît pas : son corps reste au sol, puis il se relève
## après un délai, sauf si le héros lui a donné le Repos entre-temps.
## Groupes : « hittable » tant qu'il est debout, « bodies » tant qu'il gît.

signal fell(enemy: Enemy)
signal rose(enemy: Enemy)
signal rested(enemy: Enemy)
## La vie du mort change (barre du boss).
signal health_changed(health: int, max_health: int)

enum State { CHASE, WINDUP, STAGGER, DOWN, RISING, RESTED, SPECIAL }

## Comportement de chaque type de mort (clé « behavior » des données).
const BEHAVIORS := {
	"melee": "res://scripts/enemy.gd",
	"archer": "res://scripts/enemies/archer.gd",
	"bell": "res://scripts/enemies/bell_ringer.gd",
	"burrower": "res://scripts/enemies/burrower.gd",
	"widow": "res://scripts/enemies/widow.gd",
	"sonneur": "res://scripts/enemies/sonneur.gd",
	"fossoyeuse": "res://scripts/enemies/fossoyeuse.gd",
	"crier": "res://scripts/enemies/crier.gd",
	"peseur": "res://scripts/enemies/peseur.gd",
	"butcher": "res://scripts/enemies/butcher.gd",
	"prevot": "res://scripts/enemies/prevot.gd",
	"drowned": "res://scripts/enemies/drowned.gd",
	"hook": "res://scripts/enemies/gaffeur.gd",
	"haleur": "res://scripts/enemies/haleur.gd",
}
## Portée et force des cloches : chaque Porte-cloche debout dans ce rayon
## ajoute `BELL_BOOST` à la vitesse de relèvement d'un corps.
const BELL_RADIUS := 15.0
const BELL_BOOST := 1.5

## Un mort pressé par un Crieur va et frappe plus vite pendant quelques secondes,
## et frappe plus fort.
const HASTE := 1.45
const RALLY_DAMAGE := 1.4
## Après un coup raté, un mort « à armure » reste ouvert : il subit plus.
const OPEN_FACTOR := 1.5

const TURN_SPEED := 9.0
const STAGGER_TIME := 0.35

## Le brouillard du fleuve (Noyés debout) : les repères des corps s'effacent.
static var mist_hides := false

var state := State.CHASE
var type_id_name: StringName
## Rang d'apparition dans le niveau : stable d'une partie d'essai à l'autre,
## contrairement à l'identifiant interne de l'objet.
var spawn_index := 0
var health := 0
## Délai avant de se relever. Modifiable par ce qui l'entoure (Porte-cloche,
## sceaux brisés, tests).
var rise_delay := 20.0

var _type: Dictionary
var _hero: Hero
var _model: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _hips := -1
var _shape: CollisionShape3D
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D
var _facing := Vector3(0.0, 0.0, 1.0)
var _state_time := 0.0
var _cooldown := 0.0
var _struck := false
var _attack_duration := 0.0
var _knockback := Vector3.ZERO
var _down_time := 0.0
var _rise_duration := 0.0
## Vrai pendant la première sortie de terre : le mort garde alors toute sa vie.
var _emerging := false
## Secondes de hâte restantes (voir `hasten`).
var haste_time := 0.0
## Échelle de difficulté du chapitre (voir `apply_chapter`).
var health_scale := 1.0
var damage_scale := 1.0

var _open_time := 0.0
## Garde fendue par le Requiem : le prochain coup abat (un boss : double).
var _rent_time := 0.0
var _rent_mark: MeshInstance3D
var _stagger_guard := 0.0
var _combo := 0
var _haste_aura: MeshInstance3D


## Crée un mort du bon comportement pour ce type.
static func create(type_id: StringName) -> Enemy:
	var behavior: String = EnemyTypes.get_type(type_id).get("behavior", "melee")
	var script := load(BEHAVIORS[behavior]) as GDScript
	return script.new() as Enemy


func setup(type_id: StringName, hero: Hero) -> void:
	type_id_name = type_id
	_type = EnemyTypes.get_type(type_id)
	_hero = hero
	health = int(_type["health"])
	rise_delay = float(_type["rise_delay"])
	add_to_group(&"hittable")

	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	_shape.shape = capsule
	_shape.position.y = 1.0
	add_child(_shape)

	var scene := load(_type["model"]) as PackedScene
	if scene == null:
		push_error("Modèle d'ennemi introuvable : %s" % _type["model"])
		return
	_model = scene.instantiate() as Node3D
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton != null:
		_hips = _skeleton.find_bone("hips")
	_model.scale = Vector3.ONE * float(_type.get("scale", 1.0))
	for part_name: String in _type.get("hidden_parts", []):
		var part := _model.find_child(part_name, true, false) as Node3D
		if part != null:
			part.visible = false
	for prop: Dictionary in _type.get("props", []):
		_attach(prop)
	if _type.has("tint"):
		_tint(_type["tint"])

	_build_marker()
	_cooldown = randf_range(0.2, 0.9)
	_loop(_animation("idle"))


func _physics_process(delta: float) -> void:
	if _model == null:
		return
	_state_time += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_open_time = maxf(0.0, _open_time - delta)
	if _rent_time > 0.0:
		_rent_time = maxf(0.0, _rent_time - delta)
		if _rent_time <= 0.0 and _rent_mark != null:
			_rent_mark.visible = false
	_stagger_guard = maxf(0.0, _stagger_guard - delta)
	if haste_time > 0.0:
		haste_time = maxf(0.0, haste_time - delta)
		_cooldown = maxf(0.0, _cooldown - delta * (HASTE - 1.0))
		if haste_time <= 0.0 and _haste_aura != null:
			_haste_aura.visible = false

	match state:
		State.CHASE:
			_chase()
		State.WINDUP:
			velocity = Vector3.ZERO
			if not _struck and _state_time >= float(_type["attack_windup"]):
				_struck = true
				_strike()
			if _state_time >= _attack_duration:
				state = State.CHASE
				_end_attack()
		State.STAGGER:
			velocity = _knockback * (1.0 - _state_time / STAGGER_TIME)
			if _state_time >= STAGGER_TIME:
				state = State.CHASE
		State.DOWN:
			velocity = Vector3.ZERO
			_down_time += delta * rise_rate()
			_update_marker()
			if _down_time >= rise_delay:
				_start_rising()
		State.RISING:
			velocity = Vector3.ZERO
			if _state_time >= _rise_duration:
				_finish_rising()
		State.RESTED:
			velocity = Vector3.ZERO
		State.SPECIAL:
			_special(delta)

	if state == State.CHASE or state == State.WINDUP or state == State.STAGGER or state == State.SPECIAL:
		var target_yaw := atan2(_facing.x, _facing.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, minf(1.0, TURN_SPEED * delta))
		if haste_time > 0.0 and state == State.CHASE:
			velocity *= HASTE
		velocity *= candle_slow()
		move_and_slide()


## Là où gît réellement le corps. L'animation de chute projette le mort à
## quelques pas de l'endroit où il a été abattu : c'est ce point-là que le
## joueur voit, et c'est donc près de lui qu'il doit se tenir pour le rite.
func body_position() -> Vector3:
	if state != State.DOWN or _skeleton == null or _hips < 0:
		return global_position
	var point := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hips).origin
	point.y = global_position.y
	return point


## Vrai tant que le corps gît et peut recevoir le Repos.
func is_down() -> bool:
	return state == State.DOWN


## Vitesse à laquelle le corps approche de son relèvement : 1, plus chaque
## cloche qui sonne à portée.
func rise_rate() -> float:
	# Dans la lueur d'un cierge, aucun corps ne se relève.
	if RiteCandle.lit(get_tree(), body_position()):
		return 0.0
	var rate := 1.0
	for node in get_tree().get_nodes_in_group(&"bells"):
		var bell := node as Node3D
		if bell != null and bell.global_position.distance_to(body_position()) <= BELL_RADIUS:
			rate += BELL_BOOST
	return rate


## Relève le corps sur-le-champ (cri de la Veuve, cloche du Sonneur).
func force_rise() -> void:
	if state == State.DOWN:
		_start_rising()


## Distance entre `point` et le corps : la plus courte entre l'endroit où
## il gît et celui où il est tombé. Le corps peut avoir été projeté derrière
## une grille ; on peut alors toujours lui donner le Repos d'où il est tombé.
func distance_to_body(point: Vector3) -> float:
	var flat := Vector3(point.x, global_position.y, point.z)
	return minf(flat.distance_to(body_position()), flat.distance_to(global_position))


## Vrai si le mort est debout et peut agir.
func is_standing() -> bool:
	return state == State.CHASE or state == State.WINDUP or state == State.STAGGER or state == State.SPECIAL


## Souvenirs rendus au héros quand ce mort reçoit le Repos.
func memories_given() -> int:
	return int(_type["memories"])


## Or laissé par ce mort quand il reçoit le Repos.
func gold_given() -> int:
	return int(_type.get("gold", 0))


## Part du délai déjà écoulée avant le relèvement, de 0 à 1.
func rise_progress() -> float:
	return clampf(_down_time / maxf(rise_delay, 0.01), 0.0, 1.0)


func take_hit(from: Vector3, damage: int) -> void:
	if state == State.DOWN or state == State.RISING or state == State.RESTED:
		return
	if _open_time > 0.0:
		damage = int(round(float(damage) * OPEN_FACTOR))
	if _rent_time > 0.0:
		# La garde fendue : ce coup abat le mort ; un boss le prend double.
		_rent_time = 0.0
		if _rent_mark != null:
			_rent_mark.visible = false
		damage = health if not is_boss() else damage * 2
	health -= damage
	health_changed.emit(health, max_health())
	if health <= 0:
		_fall()
		return
	# Un mort « à armure » n'est pas interrompu pendant son coup, ni ébranlé
	# deux fois de suite : on esquive puis on frappe, on n'enchaîne pas.
	if bool(_type.get("armor", false)):
		if state == State.WINDUP or state == State.SPECIAL or _stagger_guard > 0.0:
			return
		_stagger_guard = float(_type.get("stagger_guard", 2.5))
	var push := global_position - from
	push.y = 0.0
	_knockback = push.normalized() * 5.0
	state = State.STAGGER
	_state_time = 0.0
	_once(_animation("hit"), 1.5)


func is_boss() -> bool:
	return bool(_type.get("boss", false))


## Renversé par un rite (Glas, Tombée) : un mort ordinaire tombe comme
## abattu ; un boss encaisse `boss_damage`.
func knock_down(from: Vector3, boss_damage: int) -> void:
	if not is_standing():
		return
	if is_boss():
		take_hit(from, boss_damage)
		return
	health = 0
	health_changed.emit(health, max_health())
	_fall()


## Garde fendue par le Requiem pendant `seconds` secondes : un anneau d'or
## sous ses pieds.
func rend(seconds: float) -> void:
	if not is_standing():
		return
	_rent_time = seconds
	if _rent_mark == null:
		_rent_mark = Fx.disc(1.0, Color(0.91, 0.69, 0.38, 0.6))
		add_child(_rent_mark)
	_rent_mark.visible = true


func is_rent() -> bool:
	return _rent_time > 0.0


## Ralentissement dû aux cierges : la moitié de la vitesse dans leur lueur.
func candle_slow() -> float:
	for node in get_tree().get_nodes_in_group(&"candles"):
		var candle := node as RiteCandle
		if candle != null and candle.covers(global_position):
			return candle.slow
	return 1.0


## Le presse pour `seconds` secondes : il va et frappe plus vite.
func hasten(seconds: float) -> void:
	if not is_standing():
		return
	haste_time = maxf(haste_time, seconds)
	# Un anneau rouge sous ses pieds : on voit qui est pressé.
	if _haste_aura == null:
		_haste_aura = Fx.disc(0.9, Color(1.0, 0.2, 0.1, 0.55))
		add_child(_haste_aura)
	_haste_aura.visible = true


## Vie maximale, selon la difficulté du chapitre.
func max_health() -> int:
	return int(round(float(_type["health"]) * health_scale))


## Dégâts d'un coup : l'échelle du chapitre, et la rage d'un cri de Crieur.
func damage_of(base: int) -> int:
	return int(round(float(base) * damage_scale * (RALLY_DAMAGE if haste_time > 0.0 else 1.0)))


## Chaque chapitre rend les morts plus solides et plus durs, et ils se
## relèvent plus vite. Les boss sont réglés un par un.
func apply_chapter(chapter: int) -> void:
	if chapter <= 1 or bool(_type.get("boss", false)):
		return
	health_scale = 1.0 + 0.3 * float(chapter - 1)
	damage_scale = 1.0 + 0.2 * float(chapter - 1)
	rise_delay *= pow(0.8, float(chapter - 1))
	health = max_health()


## Fin d'un coup : parfois un second tout de suite (enchaînement), sinon le
## temps de reprise, pendant lequel un mort à armure reste ouvert.
func _end_attack() -> void:
	if _combo < int(_type.get("combo_max", 1)) and randf() < float(_type.get("combo_chance", 0.0)):
		_combo += 1
		_cooldown = float(_type.get("combo_gap", 0.35))
		return
	_combo = 0
	_cooldown = float(_type["attack_cooldown"])
	if bool(_type.get("armor", false)):
		_open_time = float(_type.get("open_time", 1.2))


## Donne le Repos : le mort ne se relèvera plus.
func give_rest() -> void:
	if state != State.DOWN:
		return
	_update_marker()
	state = State.RESTED
	remove_from_group(&"bodies")
	_marker.visible = false

	# Une lueur pâle, puis le corps s'enfonce dans le sol.
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.85, 1.0)
	light.light_energy = 4.0
	light.omni_range = 6.0
	add_child(light)
	light.global_position = _marker.global_position + Vector3(0.0, 0.8, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(light, "light_energy", 0.0, 1.3)
	tween.tween_property(_model, "position:y", -1.6, 1.3).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
	rested.emit(self)


## Action propre à un type (viser, sonner, crier, fouir). À écrire par les
## comportements qui en ont besoin.
func _special(_delta: float) -> void:
	state = State.CHASE


## Entre dans l'action propre au type.
func _begin_special() -> void:
	state = State.SPECIAL
	_state_time = 0.0
	velocity = Vector3.ZERO


## Distance au héros sur le sol, et direction vers lui.
func _to_hero() -> Vector3:
	var offset := _hero.global_position - global_position
	offset.y = 0.0
	return offset


## Garde le héros entre `keep_min` et `keep_max` : recule face à lui s'il
## approche, le suit s'il s'éloigne. Renvoie vrai quand la distance est bonne.
func _keep_distance(distance: float, keep_min: float, keep_max: float) -> bool:
	var speed := float(_type["move_speed"])
	if distance < keep_min:
		velocity = -_facing * speed * 0.85
		_loop(_animation("retreat"))
		return false
	if distance > keep_max:
		velocity = _facing * speed
		_loop(_animation("walk"))
		return false
	velocity = Vector3.ZERO
	_loop(_animation("idle"))
	return true


func _chase() -> void:
	if _hero == null or _hero.is_dead():
		velocity = Vector3.ZERO
		_loop(_animation("idle"))
		return
	var offset := _hero.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > 0.05:
		_facing = offset / distance
	var attack_range := float(_type["attack_range"])
	if distance <= attack_range and _cooldown <= 0.0:
		state = State.WINDUP
		_state_time = 0.0
		_struck = false
		velocity = Vector3.ZERO
		_attack_duration = _play_attack()
	elif distance > attack_range * 0.85:
		velocity = _facing * float(_type["move_speed"])
		_loop(_animation("walk"))
	else:
		velocity = Vector3.ZERO
		_loop(_animation("idle"))


func _strike() -> void:
	Audio.play(&"swing_light", -6.0)
	if _hero == null:
		return
	var offset := _hero.global_position - global_position
	offset.y = 0.0
	if offset.length() > float(_type["attack_range"]) + 0.5:
		return
	if offset.length() > 0.3 and _facing.angle_to(offset) > deg_to_rad(70.0):
		return
	_hero.take_damage(damage_of(int(_type["attack_damage"])), global_position, self)


func _fall() -> void:
	Audio.play(&"enemy_fall")
	_on_fall()
	state = State.DOWN
	_state_time = 0.0
	_down_time = 0.0
	velocity = Vector3.ZERO
	remove_from_group(&"hittable")
	add_to_group(&"bodies")
	# On peut marcher sur un corps au sol.
	_shape.set_deferred("disabled", true)
	_once(_animation("fall"), 1.0)
	_marker.visible = true
	_update_marker()
	fell.emit(self)


func _start_rising() -> void:
	Audio.play(&"enemy_rise")
	state = State.RISING
	_state_time = 0.0
	remove_from_group(&"bodies")
	_marker.visible = false
	var length := _once(_animation("rise"), 1.0)
	_rise_duration = length if length > 0.0 else 1.0


## Fait sortir le mort de sa tombe : il se dresse avant d'attaquer, et ne
## compte pas comme un mort relevé.
func emerge() -> void:
	remove_from_group(&"hittable")
	_shape.set_deferred("disabled", true)
	_emerging = true
	_start_rising()


func _finish_rising() -> void:
	state = State.CHASE
	_cooldown = 0.6
	_shape.set_deferred("disabled", false)
	add_to_group(&"hittable")
	if _emerging:
		_emerging = false
		return
	health = int(ceil(float(max_health()) * float(_type["rise_health"])))
	health_changed.emit(health, max_health())
	rose.emit(self)


## Appelé quand le mort tombe, avant qu'il ne devienne un corps.
func _on_fall() -> void:
	pass


## Accroche un objet (arme, cloche) à un os du squelette.
func _attach(prop: Dictionary) -> Node3D:
	if _skeleton == null:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = prop.get("bone", "handslot.r")
	_skeleton.add_child(attachment)
	var node: Node3D
	if prop.has("model"):
		node = (load(prop["model"]) as PackedScene).instantiate() as Node3D
	else:
		node = _build_prop(prop.get("kind", ""))
	if node == null:
		return null
	node.position = prop.get("offset", Vector3.ZERO)
	node.rotation_degrees = prop.get("rotation", Vector3.ZERO)
	node.scale = Vector3.ONE * float(prop.get("scale", 1.0))
	attachment.add_child(node)
	return node


## Objets construits par code, faute de modèle dans les packs.
func _build_prop(_kind: String) -> Node3D:
	return null


## Assombrit ou teinte le modèle (terre, cendre).
func _tint(color: Color) -> void:
	for mesh_node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		for i in mesh_instance.get_surface_override_material_count():
			var base := mesh_instance.get_active_material(i) as StandardMaterial3D
			if base == null:
				continue
			var tinted := base.duplicate() as StandardMaterial3D
			tinted.albedo_color = tinted.albedo_color * color
			mesh_instance.set_surface_override_material(i, tinted)


# --- Marque au sol ------------------------------------------------------------

## Disque posé sous le corps : pâle au début, il rougit et bat de plus en plus
## vite à mesure que le relèvement approche.
func _build_marker() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 1.05
	disc.bottom_radius = 1.05
	disc.height = 0.02
	disc.radial_segments = 24
	disc.rings = 1
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_material.albedo_color = Color(0.6, 0.8, 1.0, 0.2)
	_marker = MeshInstance3D.new()
	_marker.mesh = disc
	_marker.material_override = _marker_material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.position.y = 0.07
	_marker.visible = false
	add_child(_marker)


func _update_marker() -> void:
	_marker.visible = state == State.DOWN and not mist_hides
	_marker.global_position = body_position() + Vector3(0.0, 0.07, 0.0)
	var progress := rise_progress()
	var calm := Color(0.6, 0.8, 1.0)
	var danger := Color(1.0, 0.18, 0.1)
	var color := calm.lerp(danger, progress)
	var pulse := 0.5 + 0.5 * sin(_down_time * (2.0 + 10.0 * progress))
	color.a = 0.14 + 0.3 * progress + 0.14 * pulse
	_marker_material.albedo_color = color


# --- Animations ---------------------------------------------------------------

func _animation(key: String) -> String:
	var names: Dictionary = _type["animations"]
	return names.get(key, "")


func _loop(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation == anim_name:
		return
	_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name, 0.15)


## Joue l'animation d'attaque et renvoie la durée de l'attaque. Si le type
## donne `attack_impact` (la part de l'animation où le coup frappe), la
## vitesse est réglée pour que le coup visible tombe juste au moment où les
## dégâts sont appliqués (`attack_windup`) : sinon on voit le coup toucher,
## puis les dégâts n'arrivent que plus tard, et il suffit de s'écarter entre
## les deux.
func _play_attack() -> float:
	var anim_name := _animation("attack")
	var windup := float(_type["attack_windup"])
	if _type.has("attack_impact"):
		return maxf(_play_blow("attack", windup, float(_type["attack_impact"])), windup + 0.2)
	var speed := float(_type["attack_speed"])
	var length := _once(anim_name, speed)
	return maxf(length / speed, windup + 0.2)


## Joue l'animation `key` de façon que son moment d'impact (la part `impact`
## de sa durée) tombe `windup` secondes après le début. Renvoie sa durée.
func _play_blow(key: String, windup: float, impact: float) -> float:
	var anim_name := _animation(key)
	if _anim == null or not _anim.has_animation(anim_name):
		return windup + 0.2
	var length := _anim.get_animation(anim_name).length
	var speed := length * impact / maxf(windup, 0.05)
	_once(anim_name, speed)
	return length / speed


func _once(anim_name: String, speed: float) -> float:
	if _anim == null or not _anim.has_animation(anim_name):
		push_warning("Animation introuvable : " + anim_name)
		return 0.0
	var anim := _anim.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_NONE
	_anim.stop()
	_anim.play(anim_name, 0.06, speed)
	return anim.length
