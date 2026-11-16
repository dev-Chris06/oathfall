class_name Hero
extends CharacterBody3D
## Le héros : déplacement, enchaînement de coups et esquive.
##
## Le modèle et les noms d'animations viennent de HeroClasses, pour que ce
## code reste le même quelle que soit la classe ou le pack de modèles.

## Émis quand un coup touche au moins une cible. `heavy` vaut vrai pour le
## dernier coup de l'enchaînement.
signal hit_landed(heavy: bool)

enum State { MOVE, ATTACK, DODGE }

const TURN_SPEED := 16.0
const ATTACK_RANGE := 2.7
const ATTACK_ARC := deg_to_rad(120.0)
## Le coup porte à ce moment de l'animation, puis on peut enchaîner.
const HIT_MOMENT := 0.42
## On coupe la fin de l'animation pour que le héros réponde vite.
const RECOVERY_CUT := 0.8
const DODGE_SPEED := 13.0
const DODGE_TIME := 0.38
const DODGE_COOLDOWN := 0.8

var controls: TouchControls
var state := State.MOVE

var _data: Dictionary
var _model: Node3D
var _anim: AnimationPlayer
var _facing := Vector3(0.0, 0.0, 1.0)
var _state_time := 0.0
var _combo := 0
var _queued := false
var _hit_done := false
var _attack_duration := 0.0
var _dodge_direction := Vector3.ZERO
var _dodge_cooldown := 0.0


func setup(class_id: StringName, input: TouchControls) -> void:
	_data = HeroClasses.get_class_data(class_id)
	controls = input

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)

	var scene := load(_data["model"]) as PackedScene
	if scene == null:
		push_error("Modèle du héros introuvable : %s" % _data["model"])
		return
	_model = scene.instantiate() as Node3D
	add_child(_model)
	for part_name: String in _data.get("hidden_parts", []):
		var part := _model.find_child(part_name, true, false) as Node3D
		if part != null:
			part.visible = false
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer

	controls.attack_pressed.connect(_on_attack_pressed)
	controls.dodge_pressed.connect(_on_dodge_pressed)
	_loop(_animation("idle"))


func _physics_process(delta: float) -> void:
	if _model == null:
		return
	_state_time += delta
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	var wish := _wish_direction()

	match state:
		State.MOVE:
			velocity = wish * float(_data["move_speed"])
			if wish.length() > 0.1:
				_facing = wish.normalized()
				_loop(_animation("run"))
			else:
				_loop(_animation("idle"))
		State.ATTACK:
			# Un petit pas en avant au début du coup lui donne du poids.
			velocity = _facing * (3.0 if _state_time < 0.12 else 0.0)
			if not _hit_done and _state_time >= _attack_duration * HIT_MOMENT:
				_hit_done = true
				_strike()
			if _state_time >= _attack_duration:
				var attacks: Array = _data["attacks"]
				if _queued and _combo < attacks.size() - 1:
					if wish.length() > 0.1:
						_facing = wish.normalized()
					_start_attack(_combo + 1)
				else:
					state = State.MOVE
		State.DODGE:
			var slowdown := 1.0 - 0.6 * (_state_time / DODGE_TIME)
			velocity = _dodge_direction * DODGE_SPEED * slowdown
			if _state_time >= DODGE_TIME:
				state = State.MOVE

	# Les modèles regardent vers +Z.
	var target_yaw := atan2(_facing.x, _facing.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, minf(1.0, TURN_SPEED * delta))
	move_and_slide()


## Vrai pendant l'esquive : les coups ennemis ne portent pas.
func is_dodging() -> bool:
	return state == State.DODGE


func _wish_direction() -> Vector3:
	if controls == null:
		return Vector3.ZERO
	return Vector3(controls.move.x, 0.0, controls.move.y)


func _on_attack_pressed() -> void:
	match state:
		State.MOVE:
			var wish := _wish_direction()
			if wish.length() > 0.1:
				_facing = wish.normalized()
			_start_attack(0)
		State.ATTACK:
			_queued = true


func _on_dodge_pressed() -> void:
	if state == State.DODGE or _dodge_cooldown > 0.0:
		return
	var wish := _wish_direction()
	_dodge_direction = wish.normalized() if wish.length() > 0.1 else _facing
	_facing = _dodge_direction
	state = State.DODGE
	_state_time = 0.0
	_dodge_cooldown = DODGE_COOLDOWN
	_once(_animation("dodge"), 1.4)


func _start_attack(index: int) -> void:
	var attack: Dictionary = _data["attacks"][index]
	_combo = index
	_queued = false
	_hit_done = false
	state = State.ATTACK
	_state_time = 0.0
	var speed := float(attack["speed"])
	var length := _once(attack["animation"], speed)
	_attack_duration = length / speed * RECOVERY_CUT if length > 0.0 else 0.4


## Applique le coup à tout ce qui se trouve devant le héros.
func _strike() -> void:
	var attack: Dictionary = _data["attacks"][_combo]
	var touched := false
	for node in get_tree().get_nodes_in_group(&"hittable"):
		var target := node as Node3D
		if target == null or not target.has_method(&"take_hit"):
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length() > ATTACK_RANGE:
			continue
		if offset.length() > 0.3 and _facing.angle_to(offset) > ATTACK_ARC / 2.0:
			continue
		target.call(&"take_hit", global_position, int(attack["damage"]))
		touched = true
	if touched:
		var attacks: Array = _data["attacks"]
		hit_landed.emit(_combo == attacks.size() - 1)


func _animation(key: String) -> String:
	var names: Dictionary = _data["animations"]
	return names.get(key, "")


func _loop(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation == anim_name:
		return
	_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name, 0.12)


## Joue une animation une seule fois et renvoie sa durée d'origine.
func _once(anim_name: String, speed: float) -> float:
	if _anim == null or not _anim.has_animation(anim_name):
		push_warning("Animation introuvable : " + anim_name)
		return 0.0
	var anim := _anim.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_NONE
	_anim.stop()
	_anim.play(anim_name, 0.06, speed)
	return anim.length
