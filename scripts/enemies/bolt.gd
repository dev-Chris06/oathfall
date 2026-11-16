class_name Bolt
extends Node3D
## Carreau d'arbalète. Il file droit et blesse le héros qu'il touche, sauf
## pendant une esquive.

const HIT_RADIUS := 0.75
const LIFETIME := 1.8

var direction := Vector3.FORWARD
var speed := 15.0
var damage := 9
var hero: Hero

var _age := 0.0


func _ready() -> void:
	var model := (load("res://assets/kaykit/skeletons/Skeleton_Arrow.gltf") as PackedScene).instantiate() as Node3D
	add_child(model)
	# La flèche du pack est couchée le long de son axe : on l'oriente vers +Z.
	model.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	rotation.y = atan2(direction.x, direction.z)


func _physics_process(delta: float) -> void:
	_age += delta
	global_position += direction * speed * delta
	if _age >= LIFETIME:
		queue_free()
		return
	if hero == null or hero.is_dead():
		return
	var offset := hero.global_position + Vector3(0.0, 1.0, 0.0) - global_position
	if offset.length() <= HIT_RADIUS + 0.4:
		if not hero.is_dodging():
			hero.take_damage(damage, global_position - direction)
			queue_free()
