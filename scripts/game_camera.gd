class_name GameCamera
extends Camera3D
## Caméra de jeu : suit le héros à angle fixe, haute et plongeante, de biais
## (le chemin du niveau, vers -Z, monte en diagonale vers le haut à droite de
## l'écran), et tremble quand un coup porte. Le joystick suit ce biais
## (`TouchControls.view_yaw`).

## Biais de la caméra autour de la verticale, en degrés.
const YAW := 40.0
## Inclinaison sous l'horizontale, en degrés.
const PITCH := 52.0
## Distance au point visé (le buste du héros).
const DISTANCE := 11.0
const LOOK_HEIGHT := 1.1
const FOLLOW_SPEED := 7.0
static var OFFSET := offset()

var target: Node3D
var _shake := 0.0


func _ready() -> void:
	fov = 48.0
	current = true


func follow(node: Node3D) -> void:
	target = node
	global_position = node.global_position + OFFSET
	look_at(node.global_position + Vector3(0.0, LOOK_HEIGHT, 0.0), Vector3.UP)


## Position de la caméra par rapport aux pieds du héros.
static func offset() -> Vector3:
	var yaw := deg_to_rad(YAW)
	var pitch := deg_to_rad(PITCH)
	var flat := DISTANCE * cos(pitch)
	return Vector3(sin(yaw) * flat, LOOK_HEIGHT + DISTANCE * sin(pitch), cos(yaw) * flat)


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
