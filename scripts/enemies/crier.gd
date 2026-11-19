class_name CrierEnemy
extends Enemy
## Le Crieur : il ne frappe pas. Il se tient à distance. Quand au moins deux
## morts se battent contre le héros, il pousse un cri qui les presse : ils vont
## plus vite et frappent plus fort quelques secondes (un anneau rouge sous
## leurs pieds). Seul, il appelle du renfort : des Dépouilles sortent de terre.
## Le frapper pendant qu'il prend son souffle interrompt son cri.
## Là où le Porte-cloche agit sur les corps, lui agit sur les vivants.

signal shouted(hurried: int)
## Il appelle du renfort : `count` Dépouilles doivent sortir de terre près de lui.
signal call_requested(count: int)

enum Cry { SHOUT, CALL }

var _cry := Cry.SHOUT
var _shout_timer := 2.0
var _call_timer := 6.0
var _glow: OmniLight3D


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	_shout_timer = float(_type["shout_interval"]) * 0.3
	_call_timer = float(_type["call_interval"]) * 0.4
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.45, 0.25)
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
	var delta := get_physics_process_delta_time()
	_shout_timer -= delta
	_call_timer -= delta
	# Son cri presse les morts qui se battent : il attend qu'au moins deux
	# d'entre eux soient sur le héros. Seul, il appelle du renfort.
	if _shout_timer <= 0.0 and engaged_allies().size() >= 2:
		_begin_cry(Cry.SHOUT)
	elif _call_timer <= 0.0 and standing_allies().size() < 3:
		_begin_cry(Cry.CALL)


func _begin_cry(kind: Cry) -> void:
	_cry = kind
	_begin_special()
	_once(_animation("shout"), 0.8)


func _special(_delta: float) -> void:
	velocity = Vector3.ZERO
	var windup := float(_type["shout_windup"])
	_glow.light_energy = 3.0 * _state_time / windup
	if _state_time < windup:
		return
	_glow.light_energy = 0.0
	if _cry == Cry.SHOUT:
		_shout()
		_shout_timer = float(_type["shout_interval"])
	else:
		_call()
		_call_timer = float(_type["call_interval"])
	state = State.CHASE


func take_hit(from: Vector3, damage: int) -> void:
	if state == State.SPECIAL:
		# Interrompu, il reprendra son souffle un peu plus tard.
		_glow.light_energy = 0.0
		_shout_timer = maxf(_shout_timer, 3.0)
		_call_timer = maxf(_call_timer, 3.0)
	super.take_hit(from, damage)


func _shout() -> void:
	Audio.play(&"scream", -4.0)
	var hurried := 0
	for ally in standing_allies():
		ally.hasten(float(_type["haste_time"]))
		hurried += 1
	Fx.ring(get_parent(), global_position, Color(1.0, 0.35, 0.2, 0.65), float(_type["shout_radius"]), 1.0)
	shouted.emit(hurried)


func _call() -> void:
	Audio.play(&"scream", -4.0)
	Fx.ring(get_parent(), global_position, Color(0.9, 0.85, 0.7, 0.55), 6.0, 0.8)
	call_requested.emit(int(_type["call_count"]))


## Les morts debout (ni lui, ni les boss) dans la portée du cri.
func standing_allies() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"hittable"):
		var other := node as Enemy
		if other != null and other != self and other.is_standing() and not bool(other._type.get("boss", false)) \
				and other.global_position.distance_to(global_position) <= float(_type["shout_radius"]):
			found.append(other)
	return found


## Ceux qui sont sur le héros : à `engage_radius` de lui au plus.
func engaged_allies() -> Array[Enemy]:
	var found: Array[Enemy] = []
	if _hero == null:
		return found
	for ally in standing_allies():
		if ally.global_position.distance_to(_hero.global_position) <= float(_type["engage_radius"]):
			found.append(ally)
	return found


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
