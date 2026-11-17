class_name CrierEnemy
extends Enemy
## Le Crieur : il ne frappe pas. Il se tient à distance et, à intervalles,
## s'il y a des morts debout près de lui, il pousse un cri qui les presse :
## ils vont et frappent plus vite pendant quelques secondes. Le frapper
## pendant qu'il prend son souffle interrompt le cri.

signal shouted(hurried: int)

var _shout_timer := 4.0
var _glow: OmniLight3D


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	_shout_timer = float(_type["shout_interval"]) * 0.5
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.62, 0.3)
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
	_shout_timer -= get_physics_process_delta_time()
	if _shout_timer <= 0.0:
		if _allies_in_reach() > 0:
			_begin_special()
			_once(_animation("shout"), 0.8)
		else:
			_shout_timer = 1.5


func _special(_delta: float) -> void:
	velocity = Vector3.ZERO
	var windup := float(_type["shout_windup"])
	_glow.light_energy = 3.0 * _state_time / windup
	if _state_time >= windup:
		_glow.light_energy = 0.0
		_shout()
		state = State.CHASE
		_shout_timer = float(_type["shout_interval"])


func take_hit(from: Vector3, damage: int) -> void:
	if state == State.SPECIAL:
		# Interrompu, il reprendra son souffle un peu plus tard.
		_glow.light_energy = 0.0
		_shout_timer = 3.5
	super.take_hit(from, damage)


func _shout() -> void:
	Audio.play(&"scream", -4.0)
	var hurried := 0
	for ally in _allies():
		ally.hasten(float(_type["haste_time"]))
		hurried += 1
	Fx.ring(get_parent(), global_position, Color(1.0, 0.62, 0.3, 0.6), float(_type["shout_radius"]), 1.0)
	shouted.emit(hurried)


## Les morts debout (ni lui, ni les boss) dans la portée du cri.
func _allies() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"hittable"):
		var other := node as Enemy
		if other != null and other != self and other.is_standing() \
				and other.global_position.distance_to(global_position) <= float(_type["shout_radius"]):
			found.append(other)
	return found


func _allies_in_reach() -> int:
	return _allies().size()


func _on_fall() -> void:
	_glow.light_energy = 0.0


## Un cor de métal, en main : un pavillon évasé et un embout.
func _build_prop(kind: String) -> Node3D:
	if kind != "horn":
		return null
	var horn := Node3D.new()
	var flare := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.26
	cone.bottom_radius = 0.06
	cone.height = 0.7
	cone.radial_segments = 12
	flare.mesh = cone
	flare.material_override = Fx.flat(Color(0.55, 0.38, 0.16), 0.7, 0.45)
	flare.position.y = 0.35
	horn.add_child(flare)
	return horn
