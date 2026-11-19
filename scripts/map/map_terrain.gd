class_name MapTerrain
extends RefCounted
## Le relief d'Orvana, sous la carte : chaque étage de la ville est un plateau
## pavé, bordé de falaises de roche ; des rampes suivent la route d'un étage à
## l'autre ; le fleuve creuse son lit au pied de la ville basse ; au-delà, des
## collines sombres.
##
## Le relief se calcule à partir du plan de `MapScene` (unités du plan), et se
## pose dans le monde comme le reste de la carte (`MapWorld.to_world`). Le
## calcul est lent pour un téléphone : le maillage est fabriqué une fois, par
## `godot --headless --path . -- --terrain`, et enregistré dans
## `MESH_PATH`. Changer le relief, c'est changer ce fichier et `VERSION`, puis
## relancer l'outil (le test vérifie la version).

const VERSION := 1
const MESH_PATH := "res://assets/terrain/orvana_terrain.res"

## Largeur des falaises entre deux étages, et ce qu'elles descendent.
const CLIFF := 34.0
const CLIFF_DROP := 2.4
## Pente des terres hors de la ville, au-delà des falaises.
const SLOPE := 0.0045
## Les collines lointaines.
const FAR := -3.4
const HILLS := 1.6
## Demi-largeur d'une rampe de la route.
const RAMP_HALF := 46.0
## Profondeur du lit du fleuve (l'eau est à `MapWorld.WATER_LEVEL`).
const RIVER_BED := -1.8

## Le maillage : fin là où la caméra regarde, plus lâche sur les bords.
const FINE := 0.6
const COARSE := 1.5
const X_SPAN := Vector2(-44.0, 44.0)
const X_FINE := Vector2(-23.0, 23.0)
const Z_SPAN := Vector2(-62.0, 56.0)
const Z_FINE := Vector2(-40.0, 46.0)

var _ramps: Array = []
var _route := PackedVector2Array()
var _rects: Array[Rect2] = []
var _levels: Array[float] = []
var _noise := FastNoiseLite.new()
var _hills := FastNoiseLite.new()


func _init(route: PackedVector2Array) -> void:
	_route = route
	_noise.seed = 1312
	_noise.frequency = 0.02
	_noise.fractal_octaves = 3
	_hills.seed = 77
	_hills.frequency = 0.004
	_hills.fractal_octaves = 2
	# Chaque étage s'étend vers le nord jusqu'au pied de l'étage suivant ; le
	# plus haut, un peu au-delà du palais.
	var terraces := MapScene.TERRACES
	for i in terraces.size():
		var t: Dictionary = terraces[i]
		var north := float((terraces[i + 1] as Dictionary)["y0"]) if i + 1 < terraces.size() else float(t["y1"]) - 70.0
		var x0 := float(t["x0"]) - 22.0
		var x1 := float(t["x1"]) + 22.0
		_rects.append(Rect2(x0, north, x1 - x0, float(t["y0"]) - north))
		_levels.append(float(MapWorld.HEIGHTS[i]))
	# La rive sud, où se tient le moulin.
	_rects.append(Rect2(-900.0, MapScene.RIVER_BOTTOM - 12.0, 3100.0, 900.0))
	_levels.append(0.0)
	# Les rampes : les tronçons de la route qui changent d'étage.
	for i in range(1, route.size()):
		var a := route[i - 1]
		var b := route[i]
		if absf(MapWorld.height_at(a.y) - MapWorld.height_at(b.y)) > 0.05:
			_ramps.append([a, b])


## Hauteur du sol au point `p` du plan.
func height(p: Vector2) -> float:
	var jitter := _noise.get_noise_2dv(p) * 16.0
	var h := FAR + _hills.get_noise_2dv(p) * HILLS
	for i in _rects.size():
		var d := _rect_distance(_rects[i], p)
		if d > 0.0:
			d = maxf(d + jitter, 0.0)
		var drop := CLIFF_DROP * smoothstep(0.0, CLIFF, d) + SLOPE * maxf(d - CLIFF, 0.0)
		# Des strates dans la roche.
		if d > 0.0 and d < CLIFF:
			drop += _noise.get_noise_2d(p.x * 3.0, p.y * 0.4) * 0.18
		h = maxf(h, _levels[i] - drop)
	# Les rampes suivent exactement la route.
	for ramp: Array in _ramps:
		var closest := Geometry2D.get_closest_point_to_segment(p, ramp[0], ramp[1])
		var w := 1.0 - smoothstep(RAMP_HALF - 18.0, RAMP_HALF, closest.distance_to(p))
		if w > 0.0:
			h = lerpf(h, MapWorld.height_at(closest.y), w)
	# Le lit du fleuve, et l'anse où plonge la roue du moulin.
	var outside := maxf(maxf(MapScene.RIVER_TOP + 30.0 - p.y, p.y - (MapScene.RIVER_BOTTOM - 22.0)), 0.0)
	h = minf(h, RIVER_BED + outside * 0.1)
	h = minf(h, RIVER_BED + maxf(p.distance_to(MapScene.WHEEL) - 26.0, 0.0) * 0.1)
	return h


## Le point est-il sur un étage pavé de la ville (et pas sur la rive) ?
func paved(p: Vector2) -> float:
	var best := 0.0
	for i in MapScene.TERRACES.size():
		var d := _rect_distance(_rects[i].grow(-14.0), p)
		best = maxf(best, 1.0 - smoothstep(0.0, 10.0, d))
	return best


## Distance à la route (unités du plan).
func road_distance(p: Vector2) -> float:
	var best := INF
	for i in range(1, _route.size()):
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, _route[i - 1], _route[i]).distance_to(p))
	return best


static func _rect_distance(rect: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - p.x, p.x - rect.end.x), 0.0)
	var dy := maxf(maxf(rect.position.y - p.y, p.y - rect.end.y), 0.0)
	return sqrt(dx * dx + dy * dy)


static func _axis(span: Vector2, fine: Vector2) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	var v := span.x
	while v < span.y:
		values.append(v)
		v += FINE if (v >= fine.x - 0.01 and v < fine.y) else COARSE
	values.append(span.y)
	return values


## Fabrique le maillage du relief. Couleur des sommets : rouge = pavé,
## vert = lueur de la route, bleu = berge mouillée.
func build_mesh() -> ArrayMesh:
	var xs := _axis(X_SPAN, X_FINE)
	var zs := _axis(Z_SPAN, Z_FINE)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in zs.size():
		for xi in xs.size():
			var world := Vector2(xs[xi], zs[zi])
			var p := Vector2(world.x / MapWorld.S + MapWorld.CENTER.x, world.y / MapWorld.S + MapWorld.CENTER.y)
			var h := height(p)
			var warm := exp(-road_distance(p) / 45.0) * 0.8
			var wet := 1.0 - smoothstep(-1.4, -0.4, h)
			surface.set_color(Color(paved(p), warm, wet, 1.0))
			surface.add_vertex(Vector3(world.x, h, world.y))
	var row := xs.size()
	for zi in zs.size() - 1:
		for xi in row - 1:
			var a := zi * row + xi
			var b := a + 1
			var c := a + row
			var d := c + 1
			for index in [a, b, c, b, d, c]:
				surface.add_index(index)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.set_meta("version", VERSION)
	return mesh


## L'outil : fabrique et enregistre le maillage.
static func bake(route: PackedVector2Array) -> Error:
	var started := Time.get_ticks_msec()
	var mesh := MapTerrain.new(route).build_mesh()
	var error := ResourceSaver.save(mesh, MESH_PATH, ResourceSaver.FLAG_COMPRESS)
	print("Relief d'Orvana : %d sommets, %d ms, %s" % [mesh.surface_get_array_len(0), Time.get_ticks_msec() - started, error_string(error)])
	return error


# --- Le matériau --------------------------------------------------------------

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform sampler2D rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cobble : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D clouds : filter_linear, repeat_enable;
uniform float glow = 0.36;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float slope = 1.0 - n.y;
	// La roche se projette sur le plan de la falaise, pour ne pas s'etirer.
	vec3 rock_x = texture(rock, world_pos.zy * 0.22).rgb;
	vec3 rock_z = texture(rock, world_pos.xy * 0.22).rgb;
	vec3 rock_color = mix(rock_z, rock_x, smoothstep(0.35, 0.65, abs(n.x)));
	// Les etages sont paves, sauf quelques cours de terre battue.
	float yards = smoothstep(0.32, 0.5, texture(clouds, world_pos.xz * 0.045).r);
	vec3 ground = mix(texture(soil, world_pos.xz * 0.28).rgb, texture(cobble, world_pos.xz * 0.55).rgb, COLOR.r * yards);
	vec3 c = mix(ground, rock_color, smoothstep(0.22, 0.45, slope));
	c *= mix(1.0, 0.55, COLOR.b);
	// La nuit : des couleurs éteintes, bleutées.
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(l), c, 0.45) * vec3(0.62, 0.68, 1.0);
	// L'ombre des nuages qui passent devant la lune.
	float cloud = texture(clouds, world_pos.xz * 0.018 + vec2(TIME * 0.006, TIME * 0.0025)).r;
	float shade = mix(0.5, 1.0, smoothstep(0.38, 0.62, cloud));
	ALBEDO = c * shade;
	EMISSION = c * shade * glow + vec3(1.0, 0.5, 0.22) * COLOR.g * COLOR.g * 0.45;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
"""


static func material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("rock", load("res://assets/terrain/rock_face.jpg"))
	m.set_shader_parameter("cobble", load("res://assets/terrain/cobblestone_floor_08.jpg"))
	m.set_shader_parameter("soil", load("res://assets/terrain/forrest_ground_01.jpg"))
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var clouds := NoiseTexture2D.new()
	clouds.width = 128
	clouds.height = 128
	clouds.seamless = true
	clouds.noise = noise
	m.set_shader_parameter("clouds", clouds)
	return m
