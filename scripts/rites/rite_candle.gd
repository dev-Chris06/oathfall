class_name RiteCandle
extends Node3D
## Le cierge du rite du même nom : dans sa lueur, aucun corps ne se relève, et
## les morts debout avancent moins vite (voir `Enemy.rise_rate` et
## `Enemy.candle_slow`). Groupe « candles ».

var radius := 4.5
var slow := 0.5
var duration := 10.0
var _time := 0.0
var _ring: MeshInstance3D
var _flame: MeshInstance3D


func _ready() -> void:
	add_to_group(&"candles")
	var model := (load("res://assets/kaykit/halloween/candle_triple.gltf") as PackedScene).instantiate() as Node3D
	add_child(model)
	_ring = Fx.disc(radius, Color(0.91, 0.69, 0.38, 0.16))
	add_child(_ring)
	var edge := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.08
	torus.outer_radius = radius
	torus.rings = 40
	torus.ring_segments = 4
	edge.mesh = torus
	edge.scale = Vector3(1.0, 0.05, 1.0)
	edge.position.y = 0.1
	edge.material_override = Fx.glow(Color(0.91, 0.69, 0.38, 0.7))
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(edge)
	_flame = Fx.disc(0.5, Color(1.0, 0.75, 0.35, 0.5))
	_flame.position.y = 0.6
	add_child(_flame)
	Fx.ring(get_parent(), global_position, Color(0.91, 0.69, 0.38, 0.8), radius, 0.6)


func _process(delta: float) -> void:
	_time += delta
	_flame.scale = Vector3.ONE * (1.0 + 0.15 * sin(_time * 14.0))
	# La lueur faiblit dans les deux dernières secondes.
	modulate_fade(clampf((duration - _time) / 2.0, 0.0, 1.0))
	if _time >= duration:
		queue_free()


func modulate_fade(alpha: float) -> void:
	(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.16 * alpha


## Vrai si `point` est dans la lueur.
func covers(point: Vector3) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length() <= radius


## Vrai si un cierge couvre `point`.
static func lit(tree: SceneTree, point: Vector3) -> bool:
	for node in tree.get_nodes_in_group(&"candles"):
		var candle := node as RiteCandle
		if candle != null and not candle.is_queued_for_deletion() and candle.covers(point):
			return true
	return false
