class_name GraveStone
extends Node3D
## Une pierre tombale lancée par la Fossoyeuse. Elle retombe sur un point du
## sol que marque un disque rouge, et blesse ce qui s'y trouve, sauf un héros
## qui esquive à ce moment-là. Groupe « stones » tant qu'elle vole.

## La pierre est retombée ; `hit` dit si elle a touché le héros.
signal landed(hit: bool)

var hero: Hero
var start := Vector3.ZERO
var target := Vector3.ZERO
var flight := 1.15
var radius := 2.3
var damage := 22

var _time := 0.0
var _marker: MeshInstance3D
var _model: Node3D


func _ready() -> void:
	add_to_group(&"stones")
	var scene := load("res://assets/kaykit/halloween/gravestone.gltf") as PackedScene
	_model = scene.instantiate() as Node3D
	_model.scale = Vector3.ONE * 1.5
	add_child(_model)
	global_position = start
	_marker = Fx.disc(radius, Color(1.0, 0.25, 0.1, 0.25))
	_marker.top_level = true
	add_child(_marker)
	_marker.global_position = Vector3(target.x, 0.09, target.z)


## Secondes avant la chute.
func time_left() -> float:
	return maxf(0.0, flight - _time)


func _physics_process(delta: float) -> void:
	_time += delta
	var u := clampf(_time / flight, 0.0, 1.0)
	var flat := start.lerp(target, u)
	flat.y = lerpf(start.y, target.y, u) + 7.0 * 4.0 * u * (1.0 - u)
	global_position = flat
	_model.rotation.x += delta * 5.0
	_marker.material_override.albedo_color.a = 0.2 + 0.35 * u
	if _time >= flight:
		_land()


func _land() -> void:
	Audio.play(&"hit_heavy")
	var hit := false
	if hero != null and not hero.is_dead() and not hero.is_dodging():
		var offset := hero.global_position - target
		offset.y = 0.0
		if offset.length() <= radius:
			hero.take_damage(damage, target)
			hit = true
	Fx.ring(get_parent(), target, Color(0.55, 0.42, 0.28, 0.7), radius * 1.3, 0.45)
	landed.emit(hit)
	remove_from_group(&"stones")
	queue_free()
