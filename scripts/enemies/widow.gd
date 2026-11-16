class_name Widow
extends Enemy
## La Veuve : elle ne frappe pas. Elle se tient à distance et, à intervalles,
## pousse un cri qui relève sur-le-champ tous les corps sans repos alentour.
## La frapper pendant qu'elle prend son souffle interrompt le cri.

const SCREAM_RADIUS := 22.0

signal screamed(raised: int)

var _scream_timer := 4.0
var _glow: OmniLight3D


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	_scream_timer = float(_type["scream_interval"]) * 0.5
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.7, 0.8, 1.0)
	_glow.light_energy = 0.0
	_glow.omni_range = 5.0
	_glow.position.y = 1.6
	add_child(_glow)


func _chase() -> void:
	if _hero == null or _hero.is_dead():
		velocity = Vector3.ZERO
		_loop(_animation("idle"))
		return
	var offset := _to_hero()
	var distance := offset.length()
	if distance > 0.05:
		_facing = offset / distance
	_keep_distance(distance, float(_type["keep_min"]), float(_type["keep_max"]))
	_scream_timer -= get_physics_process_delta_time()
	if _scream_timer <= 0.0:
		if _bodies_in_reach() > 0:
			_begin_special()
			_once(_animation("scream"), 0.8)
		else:
			_scream_timer = 1.5


func _special(_delta: float) -> void:
	velocity = Vector3.ZERO
	var windup := float(_type["scream_windup"])
	_glow.light_energy = 3.0 * _state_time / windup
	if _state_time >= windup:
		_glow.light_energy = 0.0
		_scream()
		state = State.CHASE
		_scream_timer = float(_type["scream_interval"])


func take_hit(from: Vector3, damage: int) -> void:
	if state == State.SPECIAL:
		# Interrompue, elle reprendra son souffle un peu plus tard.
		_glow.light_energy = 0.0
		_scream_timer = 3.5
	super.take_hit(from, damage)


func _scream() -> void:
	var raised := 0
	for node in get_tree().get_nodes_in_group(&"bodies"):
		var body := node as Enemy
		if body != null and body.body_position().distance_to(global_position) <= SCREAM_RADIUS:
			body.force_rise()
			raised += 1
	Fx.ring(get_parent(), global_position, Color(0.75, 0.85, 1.0, 0.6), SCREAM_RADIUS, 1.1)
	screamed.emit(raised)


func _bodies_in_reach() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"bodies"):
		var body := node as Enemy
		if body != null and body.body_position().distance_to(global_position) <= SCREAM_RADIUS:
			count += 1
	return count


func _on_fall() -> void:
	_glow.light_energy = 0.0
