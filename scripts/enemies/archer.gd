class_name ArcherEnemy
extends Enemy
## L'Archer creux : fragile, il tire de loin et recule quand on l'approche.
## Avant chaque tir, un trait rouge le relie au héros : c'est le moment
## d'esquiver.

var _shot_timer := 1.2
var _fired := false
var _aim_line: MeshInstance3D
var _aim_material: StandardMaterial3D


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	_aim_material = Fx.glow(Color(1.0, 0.15, 0.1, 0.0))
	var line := BoxMesh.new()
	line.size = Vector3(0.05, 0.05, 1.0)
	_aim_line = MeshInstance3D.new()
	_aim_line.mesh = line
	_aim_line.material_override = _aim_material
	_aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_line.visible = false
	_aim_line.top_level = true
	add_child(_aim_line)


func _chase() -> void:
	if _hero == null or _hero.is_dead():
		velocity = Vector3.ZERO
		_loop(_animation("idle"))
		return
	_shot_timer -= get_physics_process_delta_time()
	var offset := _to_hero()
	var distance := offset.length()
	if distance > 0.05:
		_facing = offset / distance
	# Acculé, il se défend d'un coup de pied.
	if distance <= float(_type["attack_range"]) and _cooldown <= 0.0:
		super._chase()
		return
	var settled := _keep_distance(distance, float(_type["keep_min"]), float(_type["keep_max"]))
	if (settled or distance > float(_type["keep_min"]) * 0.7) and _shot_timer <= 0.0 \
			and distance <= float(_type["keep_max"]) + 3.0:
		_begin_special()
		_fired = false
		_once(_animation("aim"), 1.0)


func _special(_delta: float) -> void:
	velocity = Vector3.ZERO
	var aim_time := float(_type["aim_time"])
	if not _fired:
		var offset := _to_hero()
		if offset.length() > 0.05:
			_facing = offset.normalized()
		_show_aim(clampf(_state_time / aim_time, 0.0, 1.0))
		if _state_time >= aim_time:
			_fired = true
			_aim_line.visible = false
			_shoot()
			_once(_animation("shoot"), 1.0)
	elif _state_time >= aim_time + 0.5:
		state = State.CHASE
		_shot_timer = float(_type["shot_cooldown"])


func take_hit(from: Vector3, damage: int) -> void:
	_aim_line.visible = false
	if state == State.SPECIAL:
		_shot_timer = float(_type["shot_cooldown"]) * 0.6
	super.take_hit(from, damage)


func _on_fall() -> void:
	_aim_line.visible = false


func _show_aim(progress: float) -> void:
	var from := global_position + Vector3(0.0, 1.2, 0.0)
	var to := _hero.global_position + Vector3(0.0, 1.0, 0.0)
	var length := from.distance_to(to)
	_aim_line.visible = true
	_aim_line.global_position = (from + to) / 2.0
	_aim_line.look_at(to, Vector3.UP)
	_aim_line.scale = Vector3(1.0, 1.0, length)
	_aim_material.albedo_color.a = 0.15 + 0.6 * progress


func _shoot() -> void:
	Audio.play(&"twang")
	var bolt := Bolt.new()
	var start := global_position + Vector3(0.0, 1.2, 0.0) + _facing * 0.6
	var target := _hero.global_position + Vector3(0.0, 1.0, 0.0)
	bolt.direction = (target - start).normalized()
	bolt.speed = float(_type["bolt_speed"])
	bolt.damage = damage_of(int(_type["bolt_damage"]))
	bolt.hero = _hero
	get_parent().add_child(bolt)
	bolt.global_position = start
