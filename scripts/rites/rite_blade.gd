class_name RiteBlade
extends Node3D
## La lame de lumière de l'Absoute : elle file droit devant, au ras du sol, et
## frappe une fois chaque mort qu'elle traverse.

var direction := Vector3.FORWARD
var speed := 17.0
var reach := 14.0
var width := 1.4
var damage := 26
var _travelled := 0.0
var _touched := {}
## Morts touchés (pour les essais).
var hits := 0


func _ready() -> void:
	var blade := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width * 1.8, 0.7)
	blade.mesh = quad
	blade.rotation.x = -PI / 2.0
	blade.position.y = 0.9
	blade.material_override = Fx.glow(Color(0.98, 0.92, 0.75, 0.85))
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blade)
	var trail := MeshInstance3D.new()
	var long := QuadMesh.new()
	long.size = Vector2(0.5, 2.6)
	trail.mesh = long
	trail.rotation.x = -PI / 2.0
	trail.position = Vector3(0.0, 0.88, -1.4)
	trail.material_override = Fx.glow(Color(0.91, 0.69, 0.38, 0.4))
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	rotation.y = atan2(direction.x, direction.z)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	global_position += direction * step
	_travelled += step
	for node in get_tree().get_nodes_in_group(&"hittable"):
		var target := node as Node3D
		if target == null or _touched.has(target) or not target.has_method(&"take_hit"):
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length() <= width:
			_touched[target] = true
			hits += 1
			target.call(&"take_hit", global_position - direction, damage)
	if _travelled >= reach:
		queue_free()
