class_name GameCamera
extends Camera3D
## Caméra de jeu : suit le héros à angle fixe, d'assez près et d'assez bas
## pour que les combats aient du poids, et tremble quand un coup porte.

const OFFSET := Vector3(0.0, 6.6, 7.4)
const FOLLOW_SPEED := 7.0

var target: Node3D
var _shake := 0.0


func _ready() -> void:
	fov = 48.0
	current = true


func follow(node: Node3D) -> void:
	target = node
	global_position = node.global_position + OFFSET
	look_at(node.global_position + Vector3(0.0, 1.1, 0.0), Vector3.UP)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if target == null:
		return
	var wanted := target.global_position + OFFSET
	global_position = global_position.lerp(wanted, 1.0 - exp(-FOLLOW_SPEED * delta))

	_shake = maxf(0.0, _shake - delta * 2.2)
	h_offset = randf_range(-1.0, 1.0) * _shake * 0.3
	v_offset = randf_range(-1.0, 1.0) * _shake * 0.3
