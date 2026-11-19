class_name PrevotEnemy
extends Enemy
## Le Prévôt des halles, boss de la Halle du Prévôt.
##
## Il se bat à la masse, lentement. À intervalles, il lève l'impôt : un cercle
## d'or est annoncé sur le sol et, quelques secondes plus tard, la levée frappe
## toute la salle sauf le cercle. Il lève les bras pendant l'annonce ; les coups
## le blessent alors sans l'interrompre. À chaque tiers de sa vie, il décrète
## (intouchable un instant) et convoque ses percepteurs, et la levée vient plus
## vite.

enum Phase { NONE, EDICT, LEVY }

## Il décrète : un nouveau tiers de sa vie, ses percepteurs arrivent.
signal stage_changed(stage: int)
## Une levée est annoncée ; le cercle d'or est à cet endroit.
signal levy_called(center: Vector3)
## La levée a frappé ; `hit` dit si elle a touché le héros, `raised` combien de
## corps se sont relevés (ceux qui n'étaient pas dans le cercle).
signal levied(hit: bool, raised: int)

## Le centre de la salle et son rayon : la levée choisit son cercle dedans.
var home := Vector3.ZERO
var arena_radius := 11.0
var levy_center := Vector3.ZERO
## Le faux cercle du dernier tiers : il ne protège de rien.
var levy_fake := Vector3.ZERO
var levy_pending := false

var _stage := 1
var _phase := Phase.NONE
var _levy_timer := 6.0
var _levy_marker: MeshInstance3D
var _fake_marker: MeshInstance3D
var _drift := Vector3.ZERO
var _invulnerable := false


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	home = global_position
	add_to_group(&"boss")
	_levy_timer = float(_type["levy_interval"]) * 0.5


func _physics_process(delta: float) -> void:
	if state == State.CHASE or state == State.WINDUP or state == State.STAGGER:
		_levy_timer = maxf(0.0, _levy_timer - delta)
		var ratio := float(health) / float(_type["health"])
		var wanted := 1
		if ratio <= float(_type["stage2_at"]):
			wanted = 2
		if ratio <= float(_type["stage3_at"]):
			wanted = 3
		if wanted > _stage and state != State.SPECIAL:
			_begin_edict(wanted)
	super._physics_process(delta)


func _chase() -> void:
	super._chase()
	if state == State.CHASE and _levy_timer <= 0.0 and _hero != null and not _hero.is_dead():
		_begin_levy()


func stage() -> int:
	return _stage


func levy_interval() -> float:
	var interval := float(_type["levy_interval"])
	var factors := [1.0, 0.8, 0.6]
	return interval * float(factors[_stage - 1])


## Rayon du cercle sûr et durée de l'annonce, selon le tiers de sa vie.
func safe_radius() -> float:
	return float((_type["safe_radius"] as Array)[_stage - 1])


func levy_windup() -> float:
	return float((_type["levy_windup"] as Array)[_stage - 1])


## Vrai au dernier tiers de sa vie : un faux cercle accompagne le vrai.
func has_fake() -> bool:
	return _stage >= 3


## Secondes avant que la levée ne frappe, ou -1 s'il n'y en a pas.
func levy_time_left() -> float:
	if not levy_pending:
		return -1.0
	return maxf(0.0, levy_windup() - _state_time)


func _begin_edict(stage_number: int) -> void:
	_stage = stage_number
	_phase = Phase.EDICT
	_invulnerable = true
	_begin_special()
	_once(_animation("edict"), 0.8)
	Audio.play(&"scream", -2.0)
	stage_changed.emit(_stage)


func _begin_levy() -> void:
	# Le cercle d'or tombe loin du héros : il faut aller le chercher.
	var center := home
	for attempt in 16:
		var angle := randf() * TAU
		var reach := randf_range(2.0, maxf(2.0, arena_radius - 3.0))
		center = home + Vector3(cos(angle), 0.0, sin(angle)) * reach
		if center.distance_to(_hero.global_position) >= 8.0:
			break
	levy_center = Vector3(center.x, 0.0, center.z)
	var drift_angle := randf() * TAU
	_drift = Vector3(cos(drift_angle), 0.0, sin(drift_angle)) * float(_type["circle_drift"])
	levy_pending = true
	_phase = Phase.LEVY
	_begin_special()
	_once(_animation("levy"), 0.8)
	var radius := safe_radius()
	_levy_marker = Fx.disc(radius, Color(1.0, 0.8, 0.3, 0.2))
	_levy_marker.position = Vector3(levy_center.x, 0.09, levy_center.z)
	get_parent().add_child(_levy_marker)
	if has_fake():
		# Le faux cercle est terne et ne bouge pas : le vrai brille et dérive.
		var mirrored := home - (levy_center - home)
		levy_fake = Vector3(mirrored.x, 0.0, mirrored.z)
		_fake_marker = Fx.disc(radius, Color(0.55, 0.38, 0.2, 0.2))
		_fake_marker.position = Vector3(levy_fake.x, 0.09, levy_fake.z)
		get_parent().add_child(_fake_marker)
	levy_called.emit(levy_center)


func _special(_delta: float) -> void:
	velocity = Vector3.ZERO
	var offset := _to_hero()
	if offset.length() > 0.05:
		_facing = offset.normalized()
	match _phase:
		Phase.LEVY:
			var windup := levy_windup()
			# Le vrai cercle dérive, sans sortir de la salle.
			var moved := levy_center + _drift * _delta
			if moved.distance_to(home) <= arena_radius - 1.0:
				levy_center = moved
			if is_instance_valid(_levy_marker):
				_levy_marker.position = Vector3(levy_center.x, 0.09, levy_center.z)
				var pulse := 0.3 + 0.2 * sin(_state_time * 7.0) + 0.3 * clampf(_state_time / windup, 0.0, 1.0)
				(_levy_marker.material_override as StandardMaterial3D).albedo_color.a = pulse
			if is_instance_valid(_fake_marker):
				(_fake_marker.material_override as StandardMaterial3D).albedo_color.a = 0.25
			if _state_time >= windup:
				_levy()
		Phase.EDICT:
			if _state_time >= float(_type["edict_time"]):
				_invulnerable = false
				_phase = Phase.NONE
				state = State.CHASE
				_cooldown = 0.8


func _levy() -> void:
	Audio.play(&"quake", -2.0)
	Fx.ring(get_parent(), home, Color(1.0, 0.3, 0.12, 0.6), arena_radius * 1.6, 0.7)
	var hit := false
	if _hero != null and not _hero.is_dead() and not _hero.is_dodging():
		var offset := _hero.global_position - levy_center
		offset.y = 0.0
		if offset.length() > safe_radius():
			hit = true
			_hero.take_damage(int(_type["levy_damage"]), global_position)
	# Les corps qui ne sont pas dans le cercle d'or sont repris : ils se relèvent.
	var raised := 0
	for node in get_tree().get_nodes_in_group(&"bodies"):
		var body := node as Enemy
		if body == null or body == self:
			continue
		var gap := body.body_position() - levy_center
		gap.y = 0.0
		if gap.length() > safe_radius():
			body.force_rise()
			raised += 1
	_clear_levy()
	_phase = Phase.NONE
	state = State.CHASE
	_cooldown = 0.8
	_levy_timer = levy_interval()
	levied.emit(hit, raised)


func _clear_levy() -> void:
	levy_pending = false
	levy_fake = Vector3.ZERO
	for marker in [_levy_marker, _fake_marker]:
		if marker != null and is_instance_valid(marker):
			(marker as Node).queue_free()
	_levy_marker = null
	_fake_marker = null


func take_hit(from: Vector3, damage: int) -> void:
	if _invulnerable or state == State.DOWN or state == State.RISING or state == State.RESTED:
		return
	# Pendant l'annonce de la levée, un coup le blesse sans l'interrompre.
	if state == State.SPECIAL:
		health -= damage
		health_changed.emit(health, int(_type["health"]))
		if health <= 0:
			_fall()
		return
	super.take_hit(from, damage)


func _on_fall() -> void:
	_clear_levy()
	_invulnerable = false
	_phase = Phase.NONE


## Une masse d'apparat : un manche et une tête d'or.
func _build_prop(kind: String) -> Node3D:
	if kind != "mace":
		return null
	var mace := Node3D.new()
	var rod := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.radial_segments = 8
	shaft.top_radius = 0.05
	shaft.bottom_radius = 0.06
	shaft.height = 1.4
	rod.mesh = shaft
	rod.material_override = Fx.flat(Color(0.25, 0.16, 0.1))
	rod.position.y = 0.5
	mace.add_child(rod)
	var head := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.2
	ball.height = 0.4
	ball.radial_segments = 12
	ball.rings = 6
	head.mesh = ball
	head.material_override = Fx.flat(Color(0.8, 0.6, 0.2), 0.8, 0.35)
	head.position.y = 1.25
	mace.add_child(head)
	return mace
