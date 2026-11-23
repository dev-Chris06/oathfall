class_name HaleurEnemy
extends Enemy
## Le Haleur, boss du Halage.
##
## Un haleur mort, enchaîné à sa barge : elle flotte le long du quai et le
## suit partout où il va. De près, il frappe de son croc (armure d'élan).
##
## **Le coup de collier** : à intervalle régulier, il s'arc-boute et tire. Une
## bande rouge s'allume au sol, de lui jusqu'au bord de l'eau, sous la chaîne.
## Quand la chaîne se tend, elle balaie la bande : le héros qui s'y trouve est
## blessé et jeté vers l'eau (sauf s'il esquive), et **les corps qu'elle
## traverse se relèvent**. Chaque coup de collier amène la barge, d'où
## débarquent de nouveaux morts (`hauled` : le niveau les fait venir).
##
## Sous la moitié de sa vie, il enrage : les coups de collier se rapprochent,
## et ce sont des Noyés qui débarquent.

## La chaîne s'est tendue : la barge débarque près de `at`.
signal hauled(at: Vector3)
## Il passe sous la moitié de sa vie.
signal enraged

const LINKS := 16

var barge: Node3D
var phase := 1

var _haul_timer := 5.0
var _yanked := false
var _band: MeshInstance3D
var _band_material: StandardMaterial3D
var _band_from := Vector3.ZERO
var _band_to := Vector3.ZERO
var _links: Array[MeshInstance3D] = []


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	add_to_group(&"boss")
	_haul_timer = float(_type["haul_interval"]) * 0.6
	var level := get_parent() as Level
	if level != null and level.water_x < INF:
		barge = Docks.barge(level, Vector3(level.water_x + 5.2, 0.0, position.z), 12.0, 0.0, true)
	# La bande du coup de collier.
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.02, 1.0)
	_band_material = Fx.glow(Color(1.0, 0.15, 0.08, 0.0))
	_band = MeshInstance3D.new()
	_band.mesh = box
	_band.material_override = _band_material
	_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_band.top_level = true
	_band.visible = false
	add_child(_band)
	# La chaîne : des maillons, de son harnais à la proue de la barge.
	if barge != null:
		var link_mesh := BoxMesh.new()
		link_mesh.size = Vector3(0.16, 0.16, 0.5)
		for i in LINKS:
			var link := MeshInstance3D.new()
			link.mesh = link_mesh
			link.material_override = Docks.material(Color(0.2, 0.2, 0.23), 0.5)
			link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			link.top_level = true
			add_child(link)
			_links.append(link)


## Le point de la barge où la chaîne est amarrée.
func anchor() -> Vector3:
	return barge.global_position + Vector3(-1.7, 1.5, 0.0)


func _physics_process(delta: float) -> void:
	if barge != null:
		# La barge suit son haleur, lentement, le long du quai.
		var target_z := global_position.z if is_standing() else barge.global_position.z
		barge.global_position.z = move_toward(barge.global_position.z, target_z, float(_type["barge_speed"]) * delta)
		_update_chain()
	if is_standing():
		if phase == 1 and health <= int(float(max_health()) * float(_type["enrage_at"])):
			phase = 2
			_haul_timer = minf(_haul_timer, 2.0)
			enraged.emit()
		# Le minuteur court tant qu'il se bat, qu'on le harcèle ou non.
		if state != State.SPECIAL:
			_haul_timer = maxf(0.0, _haul_timer - delta)
			if _haul_timer <= 0.0 and barge != null and _hero != null and not _hero.is_dead() \
					and state == State.CHASE:
				_begin_haul()
	else:
		_band.visible = false
	super._physics_process(delta)


func haul_interval() -> float:
	return float(_type["haul_interval" if phase == 1 else "haul_interval_enraged"])


func _begin_haul() -> void:
	var level := get_parent() as Level
	_begin_special()
	_yanked = false
	_band_from = Vector3(global_position.x, 0.0, global_position.z)
	_band_to = Vector3(level.water_x, 0.0, barge.global_position.z)
	# Il tourne le dos à la barge, la chaîne sur l'épaule.
	var away := _band_from - _band_to
	if away.length() > 0.1:
		_facing = away.normalized()
	_band.visible = true
	_place_band(0.0)
	Audio.play(&"rope_snap", -8.0)
	_play_blow("haul", float(_type["haul_windup"]), float(_type["haul_impact"]))


func _special(_delta: float) -> void:
	velocity = Vector3.ZERO
	var windup := float(_type["haul_windup"])
	if not _yanked:
		_place_band(clampf(_state_time / windup, 0.0, 1.0))
		if _state_time >= windup:
			_yanked = true
			_yank()
	elif _state_time >= windup + 0.6:
		_band.visible = false
		state = State.CHASE
		_cooldown = 0.6
		_haul_timer = haul_interval()


func _place_band(progress: float) -> void:
	var length := _band_from.distance_to(_band_to)
	_band.global_position = (_band_from + _band_to) / 2.0 + Vector3(0.0, 0.08, 0.0)
	_band.look_at(_band_to + Vector3(0.0, 0.08, 0.0), Vector3.UP)
	_band.scale = Vector3(float(_type["haul_width"]), 1.0, maxf(length, 0.1))
	_band_material.albedo_color = Color(1.0, 0.15, 0.08, 0.15 + 0.5 * progress)


## Vrai si `point` est sur la bande du coup de collier (avec `margin` en plus).
func in_band(point: Vector3, margin := 0.0) -> bool:
	var a := Vector2(_band_from.x, _band_from.z)
	var b := Vector2(_band_to.x, _band_to.z)
	var p := Vector2(point.x, point.z)
	var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
	return p.distance_to(closest) <= float(_type["haul_width"]) / 2.0 + margin


## Temps avant que la chaîne se tende, ou INF s'il ne tire pas.
func haul_time_left() -> float:
	if state != State.SPECIAL or _yanked:
		return INF
	return float(_type["haul_windup"]) - _state_time


## La chaîne se tend : elle balaie la bande.
func _yank() -> void:
	Audio.play(&"rope_snap")
	Audio.play(&"quake", -4.0)
	_band_material.albedo_color = Color(1.0, 0.45, 0.2, 0.8)
	var level := get_parent() as Level
	if level != null:
		level.shake(0.8)
	if _hero != null and not _hero.is_dead() and not _hero.is_dodging() and in_band(_hero.global_position, 0.35):
		var before := _hero.health
		_hero.take_damage(damage_of(int(_type["haul_damage"])), _band_from, self)
		if _hero.health < before and _hero.health > 0:
			var toward := _band_to - _band_from
			toward.y = 0.0
			_hero.pull(_hero.global_position + toward.normalized() * 2.0)
	# Les corps balayés se relèvent.
	for node in get_tree().get_nodes_in_group(&"bodies"):
		var body := node as Enemy
		if body != null and body != self and body.is_down() and in_band(body.body_position(), 0.4):
			body.force_rise()
	hauled.emit(Vector3(_band_to.x, 0.0, _band_to.z))


func _update_chain() -> void:
	var from := (global_position + Vector3(0.0, 2.3, 0.0)) if is_standing() \
		else body_position() + Vector3(0.0, 0.3, 0.0)
	var to := anchor()
	var taut := state == State.SPECIAL
	var sag := 0.15 if taut else 0.9
	var previous := from
	for i in LINKS:
		var t := float(i + 1) / float(LINKS)
		var point := from.lerp(to, t)
		point.y -= sag * sin(PI * t)
		var link := _links[i]
		link.global_position = (previous + point) / 2.0
		if previous.distance_to(point) > 0.01:
			link.look_at(point, Vector3.UP)
		previous = point


func _on_fall() -> void:
	_band.visible = false


## Son croc de batelier : une hampe de fer, deux dents.
func _build_prop(kind: String) -> Node3D:
	if kind != "croc":
		return null
	var root := Node3D.new()
	var iron := Docks.iron()
	Docks.box(root, Vector3(0.09, 0.09, 1.5), Vector3(0.0, 0.0, 0.45), Docks.dark_wood())
	Docks.box(root, Vector3(0.55, 0.1, 0.1), Vector3(0.0, 0.0, 1.15), iron)
	for side: float in [-1.0, 1.0]:
		var tooth := Docks.box(root, Vector3(0.08, 0.08, 0.35), Vector3(side * 0.27, 0.0, 1.0), iron)
		tooth.rotation_degrees.y = side * 25.0
	return root
