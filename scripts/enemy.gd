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

enum State { CHASE, WINDUP, STAGGER, DOWN, RISING, RESTED }

const TURN_SPEED := 9.0
const STAGGER_TIME := 0.35

var state := State.CHASE
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


func setup(type_id: StringName, hero: Hero) -> void:
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

	_build_marker()
	_cooldown = randf_range(0.2, 0.9)
	_loop(_animation("idle"))


func _physics_process(delta: float) -> void:
	if _model == null:
		return
	_state_time += delta
	_cooldown = maxf(0.0, _cooldown - delta)

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
				_cooldown = float(_type["attack_cooldown"])
		State.STAGGER:
			velocity = _knockback * (1.0 - _state_time / STAGGER_TIME)
			if _state_time >= STAGGER_TIME:
				state = State.CHASE
		State.DOWN:
			velocity = Vector3.ZERO
			_down_time += delta
			_update_marker()
			if _down_time >= rise_delay:
				_start_rising()
		State.RISING:
			velocity = Vector3.ZERO
			if _state_time >= _rise_duration:
				_finish_rising()
		State.RESTED:
			velocity = Vector3.ZERO

	if state == State.CHASE or state == State.WINDUP or state == State.STAGGER:
		var target_yaw := atan2(_facing.x, _facing.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, minf(1.0, TURN_SPEED * delta))
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


## Part du délai déjà écoulée avant le relèvement, de 0 à 1.
func rise_progress() -> float:
	return clampf(_down_time / maxf(rise_delay, 0.01), 0.0, 1.0)


func take_hit(from: Vector3, damage: int) -> void:
	if state == State.DOWN or state == State.RISING or state == State.RESTED:
		return
	health -= damage
	var push := global_position - from
	push.y = 0.0
	_knockback = push.normalized() * 5.0
	if health <= 0:
		_fall()
		return
	state = State.STAGGER
	_state_time = 0.0
	_once(_animation("hit"), 1.5)


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
		var speed := float(_type["attack_speed"])
		var length := _once(_animation("attack"), speed)
		_attack_duration = maxf(length / speed, float(_type["attack_windup"]) + 0.2)
	elif distance > attack_range * 0.85:
		velocity = _facing * float(_type["move_speed"])
		_loop(_animation("walk"))
	else:
		velocity = Vector3.ZERO
		_loop(_animation("idle"))


func _strike() -> void:
	if _hero == null:
		return
	var offset := _hero.global_position - global_position
	offset.y = 0.0
	if offset.length() > float(_type["attack_range"]) + 0.5:
		return
	if offset.length() > 0.3 and _facing.angle_to(offset) > deg_to_rad(70.0):
		return
	_hero.take_damage(int(_type["attack_damage"]), global_position)


func _fall() -> void:
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
	state = State.RISING
	_state_time = 0.0
	remove_from_group(&"bodies")
	_marker.visible = false
	var length := _once(_animation("rise"), 1.0)
	_rise_duration = length if length > 0.0 else 1.0


func _finish_rising() -> void:
	health = int(ceil(float(_type["health"]) * float(_type["rise_health"])))
	state = State.CHASE
	_cooldown = 0.6
	_shape.set_deferred("disabled", false)
	add_to_group(&"hittable")
	rose.emit(self)


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


func _once(anim_name: String, speed: float) -> float:
	if _anim == null or not _anim.has_animation(anim_name):
		push_warning("Animation introuvable : " + anim_name)
		return 0.0
	var anim := _anim.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_NONE
	_anim.stop()
	_anim.play(anim_name, 0.06, speed)
	return anim.length
