class_name FlaskPickup
extends Node3D
## Une fiole tombée d'un corps mis au repos. Le héros la ramasse en passant
## dessus ; s'il en porte déjà le maximum, elle reste au sol et attend.

signal picked

const RADIUS := 1.3

var hero: Hero
var _bottle: Node3D
var _time := 0.0


func _ready() -> void:
	var scene := load(Supplies.FLASK["model"]) as PackedScene
	_bottle = scene.instantiate() as Node3D
	_bottle.scale = Vector3.ONE * 1.1
	add_child(_bottle)
	# Une lueur verte au sol : sans elle, la fiole se perd sous la brume.
	var halo := Fx.disc(0.55, Color(0.45, 0.95, 0.55, 0.35))
	add_child(halo)


func _physics_process(delta: float) -> void:
	_time += delta
	_bottle.position.y = 0.35 + 0.12 * sin(_time * 3.0)
	_bottle.rotation.y = _time * 1.6
	if hero == null or hero.is_dead():
		return
	var offset := hero.global_position - global_position
	offset.y = 0.0
	if offset.length() > RADIUS:
		return
	if Progress.gain_flask():
		Audio.play(&"equip")
		picked.emit()
		queue_free()
