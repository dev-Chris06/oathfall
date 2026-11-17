class_name BellRope
extends Node3D
## Une des cordes qui retiennent la grosse cloche. Le héros ne la frappe pas :
## il la coupe en maintenant le bouton (voir `Hero._start_cut`), en restant sans
## défense. Elle est dans le groupe « ropes » tant qu'elle tient.

signal cut(rope: BellRope)

var is_cut := false

var _strand: MeshInstance3D
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D
var _top := Vector3.UP * 5.0
var _time := 0.0


## `top` est l'attache sur la cloche, dans le repère du monde ; la corde est
## posée à son pied, au sol.
func setup(top: Vector3) -> void:
	_top = top - global_position
	add_to_group(&"ropes")

	var length := _top.length()
	var cylinder := CylinderMesh.new()
	cylinder.radial_segments = 12
	cylinder.top_radius = 0.07
	cylinder.bottom_radius = 0.07
	cylinder.height = length
	cylinder.radial_segments = 6
	_strand = MeshInstance3D.new()
	_strand.mesh = cylinder
	_strand.material_override = Fx.flat(Color(0.42, 0.3, 0.18))
	_strand.position = _top / 2.0
	_strand.basis = Basis(Quaternion(Vector3.UP, _top.normalized()))
	add_child(_strand)

	# Une lueur sur la corde, pour qu'on la repère dans la pénombre.
	var sphere := SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.radius = 0.2
	sphere.height = 0.4
	_marker_material = Fx.glow(Color(1.0, 0.7, 0.3, 0.8))
	_marker = MeshInstance3D.new()
	_marker.mesh = sphere
	_marker.material_override = _marker_material
	_marker.position = _top.normalized() * 1.3
	add_child(_marker)


func _process(delta: float) -> void:
	if is_cut:
		return
	_time += delta
	_marker_material.albedo_color.a = 0.55 + 0.3 * sin(_time * 4.0)


## Coupe la corde.
func cut_now() -> void:
	if is_cut:
		return
	_snap()


func _snap() -> void:
	Audio.play(&"rope_snap")
	is_cut = true
	remove_from_group(&"ropes")
	_marker.visible = false
	cut.emit(self)
	# Le brin cédé retombe au sol.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_strand, "position", Vector3(_top.x * 0.05, 0.1, _top.z * 0.05), 0.5) \
		.set_ease(Tween.EASE_IN)
	tween.tween_property(_strand, "scale", Vector3(1.0, 0.12, 1.0), 0.5)
