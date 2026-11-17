class_name BellRinger
extends Enemy
## Le Porte-cloche : lent et solide. Tant qu'il est debout, chaque coup de
## sa cloche presse les corps alentour de se relever (voir `Enemy.rise_rate`).
## L'abattre en premier fait gagner du temps sur tous les autres.

const BRONZE := Color(0.55, 0.38, 0.16)

var _ring_timer := 1.0
var _bell: Node3D
## Ce qui oscille : la cloche pend de la main, couchée de 90° par rapport à
## l'os de la main, dont l'axe pointe vers l'avant.
var _swing: Node3D


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	add_to_group(&"bells")


func _chase() -> void:
	super._chase()
	_ring_timer -= get_physics_process_delta_time()
	if _ring_timer <= 0.0:
		_ring_timer = float(_type["ring_interval"])
		_ring()


func _ring() -> void:
	Audio.play(&"bell_small")
	Fx.ring(get_parent(), global_position, Color(0.85, 0.62, 0.3, 0.55), BELL_RADIUS, 1.3)
	if _swing != null:
		var tween := _swing.create_tween()
		tween.tween_property(_swing, "rotation_degrees:x", 35.0, 0.12)
		tween.tween_property(_swing, "rotation_degrees:x", -25.0, 0.2)
		tween.tween_property(_swing, "rotation_degrees:x", 0.0, 0.25)


func _on_fall() -> void:
	remove_from_group(&"bells")


func _finish_rising() -> void:
	super._finish_rising()
	add_to_group(&"bells")


func _build_prop(kind: String) -> Node3D:
	if kind != "bell":
		return null
	_bell = Node3D.new()
	_swing = Node3D.new()
	_swing.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	_bell.add_child(_swing)
	var body := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.radial_segments = 12
	cone.top_radius = 0.1
	cone.bottom_radius = 0.3
	cone.height = 0.42
	cone.radial_segments = 14
	body.mesh = cone
	body.material_override = Fx.flat(BRONZE, 0.7, 0.45)
	body.position.y = -0.3
	_swing.add_child(body)
	var crown := MeshInstance3D.new()
	var knob := SphereMesh.new()
	knob.radial_segments = 16
	knob.rings = 8
	knob.radius = 0.09
	knob.height = 0.18
	crown.mesh = knob
	crown.material_override = body.material_override
	crown.position.y = -0.06
	_swing.add_child(crown)
	var clapper := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radial_segments = 16
	ball.rings = 8
	ball.radius = 0.06
	ball.height = 0.12
	clapper.mesh = ball
	clapper.material_override = Fx.flat(Color(0.15, 0.13, 0.12), 0.5, 0.6)
	clapper.position.y = -0.55
	_swing.add_child(clapper)
	return _bell
