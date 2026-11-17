class_name Burrower
extends Enemy
## Le Fouisseur : il file sous terre vers le héros, signalé par un monticule
## qui avance, puis jaillit à ses pieds. Le monticule qui s'arrête et tremble
## annonce le coup : c'est le moment d'esquiver. Après un temps à la surface,
## il replonge.

enum Phase { UNDER, WARNING, BURST }

var _phase := Phase.UNDER
var _surface_timer := 0.0
var _mound: MeshInstance3D
var _burst_hit := false


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	var dome := SphereMesh.new()
	dome.radial_segments = 16
	dome.rings = 8
	dome.radius = 0.75
	dome.height = 0.7
	dome.is_hemisphere = true
	_mound = MeshInstance3D.new()
	_mound.mesh = dome
	_mound.material_override = Fx.flat(Color(0.2, 0.15, 0.11))
	_mound.visible = false
	add_child(_mound)
	_surface_timer = float(_type["surface_time"])


## Sorti de terre au début d'une vague : il commence enfoui.
func emerge() -> void:
	_dive()


## Vrai tant qu'il est sous terre : on ne peut pas le frapper.
func is_burrowed() -> bool:
	return state == State.SPECIAL


func _dive() -> void:
	remove_from_group(&"hittable")
	_shape.set_deferred("disabled", true)
	_model.visible = false
	_mound.visible = true
	_mound.scale = Vector3.ONE
	_phase = Phase.UNDER
	_begin_special()


func _chase() -> void:
	super._chase()
	_surface_timer -= get_physics_process_delta_time()
	if _surface_timer <= 0.0 and state == State.CHASE and _to_hero().length() > 3.0:
		_dive()


func _special(delta: float) -> void:
	var offset := _to_hero()
	match _phase:
		Phase.UNDER:
			if _hero == null or _hero.is_dead():
				velocity = Vector3.ZERO
				return
			if offset.length() > 0.05:
				_facing = offset.normalized()
			velocity = _facing * float(_type["burrow_speed"])
			# Sous terre, rien ne l'arrête, pas même les murs.
			global_position += velocity * delta
			velocity = Vector3.ZERO
			_mound.position.y = sin(_state_time * 14.0) * 0.04
			if offset.length() <= float(_type["burst_distance"]):
				_phase = Phase.WARNING
				_state_time = 0.0
		Phase.WARNING:
			velocity = Vector3.ZERO
			_mound.position = Vector3(randf_range(-0.08, 0.08), 0.0, randf_range(-0.08, 0.08))
			_mound.scale = Vector3.ONE * (1.0 + 0.4 * _state_time / float(_type["burst_warning"]))
			if _state_time >= float(_type["burst_warning"]):
				_burst()
		Phase.BURST:
			velocity = Vector3.ZERO
			if not _burst_hit and _state_time >= 0.15:
				_burst_hit = true
				if _hero != null and offset.length() <= float(_type["burst_distance"]) + 1.0:
					_hero.take_damage(int(_type["burst_damage"]), global_position)
			if _state_time >= 0.9:
				state = State.CHASE
				_cooldown = 0.5


func _burst() -> void:
	Audio.play(&"dig")
	_phase = Phase.BURST
	_state_time = 0.0
	_burst_hit = false
	_mound.visible = false
	_model.visible = true
	_shape.set_deferred("disabled", false)
	add_to_group(&"hittable")
	_surface_timer = float(_type["surface_time"])
	_once(_animation("burst"), 1.6)
	Fx.ring(get_parent(), global_position, Color(0.35, 0.25, 0.15, 0.7), 2.5, 0.5)


func _on_fall() -> void:
	_mound.visible = false
	_model.visible = true
