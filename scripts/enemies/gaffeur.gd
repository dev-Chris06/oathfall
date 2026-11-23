class_name GaffeurEnemy
extends Enemy
## Le Gaffeur : un batelier mort, armé de sa gaffe. De près, il frappe ; à
## mi-distance, il lance sa gaffe et tire le héros à lui, au milieu des
## autres. Avant le jet, un trait orangé le relie au héros : c'est le moment
## d'esquiver. Le frapper pendant qu'il vise l'interrompt.

var _hook_timer := 2.5
var _thrown := false
var _line: MeshInstance3D
var _line_material: StandardMaterial3D


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	_line_material = Fx.glow(Color(1.0, 0.5, 0.12, 0.0))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.07, 1.0)
	_line = MeshInstance3D.new()
	_line.mesh = mesh
	_line.material_override = _line_material
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.visible = false
	_line.top_level = true
	add_child(_line)


func _chase() -> void:
	if _hero == null or _hero.is_dead():
		super._chase()
		return
	_hook_timer -= get_physics_process_delta_time()
	var distance := _to_hero().length()
	if _hook_timer <= 0.0 and _cooldown <= 0.0 and distance >= float(_type["hook_min"]) \
			and distance <= float(_type["hook_range"]):
		_facing = _to_hero().normalized()
		_begin_special()
		_thrown = false
		_play_blow("throw", float(_type["hook_windup"]), float(_type["hook_impact"]))
		return
	super._chase()


func _special(_delta: float) -> void:
	velocity = Vector3.ZERO
	var windup := float(_type["hook_windup"])
	if not _thrown:
		var offset := _to_hero()
		if offset.length() > 0.05:
			_facing = offset.normalized()
		_show_line(clampf(_state_time / windup, 0.0, 1.0))
		if _state_time >= windup:
			_thrown = true
			_throw()
	elif _state_time >= windup + 0.3:
		_line.visible = false
		state = State.CHASE
		_hook_timer = float(_type["hook_cooldown"])
		_cooldown = 0.0


func _throw() -> void:
	Audio.play(&"hook")
	_line_material.albedo_color = Color(0.75, 0.6, 0.4, 0.9)
	var offset := _to_hero()
	if offset.length() > float(_type["hook_range"]) + 1.0 or _hero.is_dodging():
		return
	var before := _hero.health
	_hero.take_damage(damage_of(int(_type["hook_damage"])), global_position, self)
	if _hero.health < before and _hero.health > 0:
		_hero.pull(global_position + offset.normalized() * 1.4)


func take_hit(from: Vector3, damage: int) -> void:
	if state == State.SPECIAL:
		_line.visible = false
		_hook_timer = float(_type["hook_cooldown"]) * 0.5
	super.take_hit(from, damage)


func _on_fall() -> void:
	_line.visible = false


func _show_line(progress: float) -> void:
	var from := global_position + Vector3(0.0, 1.2, 0.0)
	var to := _hero.global_position + Vector3(0.0, 1.0, 0.0)
	_line.visible = true
	_line.global_position = (from + to) / 2.0
	_line.look_at(to, Vector3.UP)
	_line.scale = Vector3(1.0, 1.0, from.distance_to(to))
	_line_material.albedo_color = Color(1.0, 0.5, 0.12, 0.15 + 0.6 * progress)


## La gaffe : une longue perche, un croc de fer au bout.
func _build_prop(kind: String) -> Node3D:
	if kind != "gaffe":
		return null
	var root := Node3D.new()
	var pole := Docks.box(root, Vector3(0.07, 0.07, 2.6), Vector3(0.0, 0.0, 0.5), Docks.wood())
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Docks.box(root, Vector3(0.06, 0.06, 0.4), Vector3(0.0, 0.0, 1.9), Docks.iron())
	var hook := Docks.box(root, Vector3(0.06, 0.32, 0.06), Vector3(0.0, -0.12, 1.75), Docks.iron())
	hook.rotation_degrees.x = -25.0
	return root
