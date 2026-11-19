class_name MapCity
extends Node3D
## Les bâtiments d'Orvana sur la carte : maisons le long des voies, remparts
## au front de chaque étage, tours aux angles, donjon, cathédrale et palais,
## arbres et rochers sur les collines. Modèles du pack KayKit Medieval Hexagon
## (CC0), regroupés en MultiMesh **par étage** : la caméra n'en voit que deux à
## la fois, et ce qui est hors champ n'est pas dessiné.
##
## Tous partagent un matériau de nuit : couleurs éteintes et bleutées, et les
## fenêtres (les cases sombres de l'atlas) s'allument selon la donnée propre
## de chaque instance (`INSTANCE_CUSTOM.r`), que `set_district_light` règle.

const DIR := "res://assets/kaykit/medieval/"
const HOMES := ["building_home_A_red", "building_home_B_red", "building_home_A_red", "building_home_B_red", "building_blacksmith_red", "building_home_B_red"]
const TREES := ["tree_single_A", "tree_single_B"]
const ROCKS := ["rock_single_C", "rock_single_E"]
## Distance minimale (plan) entre une maison et la route.
const ROAD_CLEARANCE := 52.0
## La case de l'atlas (colonne, première rangée) qui sert de vitre à chaque
## modèle ; ceux qui n'en ont pas restent éteints.
const GLASS := {
	"building_tower_A_red": 3, "building_tower_B_red": 3, "building_castle_red": 3, "building_barracks_red": 3,
}
## Les maisons n'ont pas de vitres dans l'atlas : on leur pose de petites
## fenêtres lumineuses sur la façade, de part et d'autre de la porte.
const WINDOWED := ["building_home_A_red", "building_home_B_red", "building_blacksmith_red"]

const WINDOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;

varying float lit;
varying float phase;

void vertex() {
	lit = INSTANCE_CUSTOM.r;
	phase = INSTANCE_CUSTOM.g * 6.2831;
}

void fragment() {
	float flicker = 0.8 + 0.2 * sin(TIME * 2.3 + phase) * sin(TIME * 0.7 + phase * 1.7);
	ALBEDO = vec3(1.0, 0.66, 0.3) * flicker * lit + vec3(0.05, 0.05, 0.09) * (1.0 - lit);
}
"""
## Écart moyen entre deux maisons (plan).
const HOUSE_SPACING := 64.0

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float glow = 0.3;
uniform float windows = 1.0;
uniform float always_lit = 0.0;
uniform float lit_glass = 1.0;

varying float lit;
varying float phase;
varying float glass_column;

void vertex() {
	lit = max(INSTANCE_CUSTOM.r, always_lit);
	phase = INSTANCE_CUSTOM.g * 6.2831 + always_lit * 1.3;
	glass_column = always_lit > 0.5 ? lit_glass : INSTANCE_CUSTOM.b * 8.0 - 1.0;
}

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 night = mix(vec3(l), c, 0.55) * vec3(0.5, 0.54, 0.8);
	ALBEDO = night;
	// Les vitres : une case de la premiere rangee de l'atlas, propre au modele.
	vec2 cell = floor(UV * vec2(8.0, 4.0));
	float glass = (cell.y < 0.5 && abs(cell.x - glass_column) < 0.5) ? 1.0 : 0.0;
	float window = glass * windows * lit;
	float flicker = 0.8 + 0.2 * sin(TIME * 2.3 + phase) * sin(TIME * 0.7 + phase * 1.7);
	EMISSION = night * glow + vec3(1.0, 0.62, 0.26) * window * flicker * 2.2;
	ROUGHNESS = 0.9;
}
"""

var _material: ShaderMaterial
## Les parties de modèle déjà lues : nom -> [[maillage, transformation], …].
var _parts := {}
## Ce qui sera regroupé : clé (modèle, étage) -> [transformations, lumières].
var _batches := {}
## Les MultiMesh des maisons, par étage, pour rallumer leurs fenêtres.
var _district_meshes := {}
## Les fenêtres posées : étage -> [transformations, lumières].
var _windows := {}
## Façade de chaque modèle à fenêtres : [z de la façade, demi-largeur de la porte].
var _facades := {}
var _terrain: MapTerrain
var _route := PackedVector2Array()


func _init() -> void:
	name = "MapCity"


func build(terrain: MapTerrain, route: PackedVector2Array) -> void:
	_terrain = terrain
	_route = route
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("atlas", load(DIR + "hexagons_medieval.png"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_houses(rng)
	_landmarks()
	_ramparts()
	_nature(rng)
	_flush()


## Le matériau de nuit, pour un modèle posé à part (le moulin) ; `lit` : ses
## fenêtres sont toujours allumées.
func night_material(lit := false) -> ShaderMaterial:
	if not lit:
		return _material
	var copy := _material.duplicate() as ShaderMaterial
	copy.set_shader_parameter("always_lit", 1.0)
	return copy


# --- La ville -----------------------------------------------------------------

## Les maisons couvrent chaque étage, sur une grille dérangée : hors de la
## route, des grands édifices et des bords.
func _houses(rng: RandomNumberGenerator) -> void:
	for i in MapScene.TERRACES.size():
		var terrace: Dictionary = MapScene.TERRACES[i]
		var north := float((MapScene.TERRACES[i + 1] as Dictionary)["y0"]) + 40.0 if i + 1 < MapScene.TERRACES.size() else float(terrace["y1"]) + 20.0
		var y := float(terrace["y0"]) - 60.0
		while y > north:
			var x := float(terrace["x0"]) + 30.0 + rng.randf_range(0.0, 30.0)
			while x < float(terrace["x1"]) - 30.0:
				var p := Vector2(x + rng.randf_range(-10.0, 10.0), y + rng.randf_range(-10.0, 10.0))
				x += rng.randf_range(HOUSE_SPACING, HOUSE_SPACING * 1.3)
				if rng.randf() < 0.22 or _reserved(i, p) or _terrain.road_distance(p) < ROAD_CLEARANCE:
					continue
				var model: String = HOMES[rng.randi() % HOMES.size()]
				# Les maisons tournent le dos au nord : on voit leurs façades.
				var yaw := rng.randf_range(-14.0, 14.0) + (90.0 * float(rng.randi_range(-1, 1)) if rng.randf() < 0.2 else 0.0)
				var scale := rng.randf_range(1.6, 1.95)
				_put(model, MapLife.zone_of(i, p), MapWorld.to_world(p), yaw, Vector3(scale, scale * rng.randf_range(0.95, 1.2), scale), 1.0 if rng.randf() < 0.7 else 0.0, rng.randf())
			y -= rng.randf_range(HOUSE_SPACING * 0.95, HOUSE_SPACING * 1.15)
	_put("building_market_red", MapLife.zone_of(0, Vector2(640.0, 2290.0)), MapWorld.to_world(Vector2(640.0, 2290.0)), 0.0, Vector3.ONE * 1.7, 0.6, 0.3)
	_put("building_well_red", MapLife.zone_of(0, Vector2(470.0, 2440.0)), MapWorld.to_world(Vector2(470.0, 2440.0)), 20.0, Vector3.ONE * 1.5, 0.0, 0.0)


## Les places des grands édifices, sans maisons.
func _reserved(district: int, p: Vector2) -> bool:
	match district:
		0:
			return p.distance_to(Vector2(640.0, 2290.0)) < 80.0 or p.distance_to(Vector2(470.0, 2440.0)) < 45.0
		1:
			return absf(p.x - 610.0) < 120.0 and absf(p.y - 1590.0) < 85.0
		2:
			return absf(p.x - 640.0) < 145.0 and absf(p.y - 1205.0) < 90.0
		3:
			return absf(p.x - 640.0) < 190.0 and p.y < 650.0
	return false


## Le donjon de la citadelle, la cathédrale, le palais.
func _landmarks() -> void:
	_landmark("building_castle_red", 1, Vector2(650.0, 1585.0), 0.0, 2.2, 0.8, 0.1)
	_landmark("building_barracks_red", 1, Vector2(540.0, 1600.0), -8.0, 1.7, 0.6, 0.4)
	_landmark("building_church_red", 2, Vector2(640.0, 1200.0), 0.0, 3.4, 1.0, 0.7)
	for side: float in [-1.0, 1.0]:
		_landmark("building_tower_A_red", 2, Vector2(640.0 + side * 115.0, 1235.0), 0.0, 1.7, 0.5, 0.2)
	_landmark("building_castle_red", 3, Vector2(640.0, 515.0), 0.0, 3.6, 1.0, 0.5)
	for side: float in [-1.0, 1.0]:
		_landmark("building_tower_B_red", 3, Vector2(640.0 + side * 160.0, 560.0), 0.0, 2.1, 0.7, 0.9)


func _landmark(model: String, tier: int, p: Vector2, yaw: float, scale: float, light: float, phase: float) -> void:
	_put(model, MapLife.zone_of(tier, p), MapWorld.to_world(p), yaw, Vector3.ONE * scale, light, phase)


## Au front de chaque étage, un rempart, ouvert là où passe la route ; une
## tour à chaque angle.
func _ramparts() -> void:
	var length := 2.0
	for i in MapScene.TERRACES.size():
		var terrace: Dictionary = MapScene.TERRACES[i]
		var y := float(terrace["y0"]) - 14.0
		var x0 := float(terrace["x0"]) - 4.0
		var x1 := float(terrace["x1"]) + 4.0
		var step := length / MapWorld.S
		var x := x0 + step * 0.5
		while x < x1 - step * 0.5:
			var p := Vector2(x, y)
			if _terrain.road_distance(p) > 40.0:
				_put("wall_straight", MapLife.zone_of(i, p), MapWorld.to_world(p), 0.0, Vector3.ONE, 0.0, 0.0)
			x += step
		for corner: float in [x0, x1]:
			_put("building_tower_A_red", MapLife.zone_of(i, Vector2(corner, y)), MapWorld.to_world(Vector2(corner, y)), 0.0, Vector3.ONE * 1.4, 0.6, fmod(corner / 1000.0, 1.0))


## Arbres et rochers hors des murs, sur les collines et au pied des falaises.
func _nature(rng: RandomNumberGenerator) -> void:
	var placed := 0
	var tries := 0
	while placed < 260 and tries < 6000:
		tries += 1
		var world := Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-58.0, 52.0))
		var p := Vector2(world.x / MapWorld.S + MapWorld.CENTER.x, world.y / MapWorld.S + MapWorld.CENTER.y)
		if _terrain.paved(p) > 0.05 or _terrain.road_distance(p) < 40.0:
			continue
		var h := _terrain.height(p)
		if h < -0.5 and p.y > MapScene.RIVER_TOP - 40.0 and p.y < MapScene.RIVER_BOTTOM + 40.0:
			continue
		# La pente : pas d'arbre dans la falaise.
		var slope := absf(_terrain.height(p + Vector2(20.0, 0.0)) - h) + absf(_terrain.height(p + Vector2(0.0, 20.0)) - h)
		if slope > 0.35:
			if rng.randf() < 0.3:
				_put(ROCKS[rng.randi() % ROCKS.size()], -1, Vector3(world.x, h - 0.05, world.y), rng.randf_range(0.0, 360.0), Vector3.ONE * rng.randf_range(2.0, 4.0), 0.0, 0.0)
			continue
		var s := rng.randf_range(1.3, 2.1)
		_put(TREES[rng.randi() % TREES.size()], -1, Vector3(world.x, h - 0.05, world.y), rng.randf_range(0.0, 360.0), Vector3(s, s * rng.randf_range(0.9, 1.25), s), 0.0, 0.0)
		placed += 1


# --- Regroupement -------------------------------------------------------------

func _put(model: String, district: int, at: Vector3, yaw_deg: float, scale: Vector3, light: float, phase: float) -> void:
	var key := "%s|%d" % [model, district]
	if not _batches.has(key):
		_batches[key] = [[], []]
	(_batches[key][0] as Array).append(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis.from_scale(scale), at))
	if district >= 0 and WINDOWED.has(model):
		_add_windows(model, district, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis.from_scale(scale), at), light, phase)
	var glass := (float(GLASS[model]) + 1.0) / 8.0 if GLASS.has(model) else 0.0
	(_batches[key][1] as Array).append(Color(light, phase, glass, 0.0))


## Deux fenêtres de part et d'autre de la porte, à mi-hauteur du mur.
func _add_windows(model: String, district: int, xf: Transform3D, light: float, phase: float) -> void:
	var facade := _facade(model)
	if not _windows.has(district):
		_windows[district] = [[], []]
	for side: float in [-1.0, 1.0]:
		var local := Vector3(side * (float(facade[1]) + 0.11), 0.2, float(facade[0]) + 0.012)
		(_windows[district][0] as Array).append(xf * Transform3D(Basis.IDENTITY, local))
		(_windows[district][1] as Array).append(Color(light, fmod(phase + side * 0.37 + 1.0, 1.0), 0.0, 0.0))


## La façade d'un modèle : la porte (case 5,0 de l'atlas, tournée vers +Z).
func _facade(model: String) -> Array:
	if _facades.has(model):
		return _facades[model]
	var front := 0.3
	var half := 0.08
	for part: Array in _model_parts(model):
		var arrays := (part[0] as Mesh).surface_get_arrays(0)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var found := false
		for k in uvs.size():
			if int(uvs[k].x * 8.0) == 5 and int(uvs[k].y * 4.0) == 0 and normals[k].z > 0.9:
				var p := (part[1] as Transform3D) * points[k]
				front = p.z if not found else maxf(front, p.z)
				half = absf(p.x) if not found else maxf(half, absf(p.x))
				found = true
	_facades[model] = [front, half]
	return _facades[model]


func _model_parts(model: String) -> Array:
	if _parts.has(model):
		return _parts[model]
	var parts: Array = []
	var scene := load(DIR + model + ".gltf") as PackedScene
	var root := scene.instantiate() as Node3D
	_collect(root, Transform3D.IDENTITY, parts)
	root.free()
	_parts[model] = parts
	return parts


func _collect(node: Node, parent: Transform3D, out: Array) -> void:
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append([(node as MeshInstance3D).mesh, xf])
	for child in node.get_children():
		_collect(child, xf, out)


func _flush() -> void:
	for key: String in _batches:
		var model := key.get_slice("|", 0)
		var district := key.get_slice("|", 1).to_int()
		var transforms: Array = _batches[key][0]
		var lights: Array = _batches[key][1]
		for part: Array in _model_parts(model):
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_custom_data = true
			multimesh.mesh = part[0]
			multimesh.instance_count = transforms.size()
			for k in transforms.size():
				multimesh.set_instance_transform(k, (transforms[k] as Transform3D) * (part[1] as Transform3D))
				multimesh.set_instance_custom_data(k, lights[k])
			var node := MultiMeshInstance3D.new()
			node.multimesh = multimesh
			node.material_override = _material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			if district >= 0:
				if not _district_meshes.has(district):
					_district_meshes[district] = []
				(_district_meshes[district] as Array).append([multimesh, lights, PackedByteArray()])
	_batches.clear()
	var shader := Shader.new()
	shader.code = WINDOW_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.13)
	for district: int in _windows:
		var transforms: Array = _windows[district][0]
		var lights: Array = _windows[district][1]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = quad
		multimesh.instance_count = transforms.size()
		for k in transforms.size():
			multimesh.set_instance_transform(k, transforms[k])
			multimesh.set_instance_custom_data(k, lights[k])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		(_district_meshes[district] as Array).append([multimesh, lights, PackedByteArray()])
	_windows.clear()


## Allume les fenêtres d'un quartier : `amount` est la part des maisons
## allumées (0, aucune ; 1, toutes celles qui ont de la lumière). Elles
## s'allument une à une, dans un ordre propre à chaque maison.
func set_district_light(district: int, amount: float) -> void:
	for entry: Array in _district_meshes.get(district, []):
		var multimesh := entry[0] as MultiMesh
		var lights: Array = entry[1]
		# L'état de chaque fenêtre est gardé ici : sans affichage, le moteur
		# ne garde pas les données des instances.
		var state := PackedByteArray()
		state.resize(multimesh.instance_count)
		for k in multimesh.instance_count:
			var base: Color = lights[k]
			var on := 1.0 if base.r > 0.0 and base.g < amount else 0.0
			state[k] = int(on)
			multimesh.set_instance_custom_data(k, Color(on, base.g, base.b, 0.0))
		entry[2] = state


## Part des fenêtres allumées d'un quartier (pour les essais).
func district_light(district: int) -> float:
	var lit := 0
	var total := 0
	for entry: Array in _district_meshes.get(district, []):
		var state: PackedByteArray = entry[2]
		for k in (entry[1] as Array).size():
			if (entry[1][k] as Color).r > 0.0:
				total += 1
				if k < state.size() and state[k] > 0:
					lit += 1
	return float(lit) / float(maxi(total, 1))


## Nombre de triangles de toute la ville (pour surveiller le budget).
func triangle_count() -> int:
	var total := 0
	for child in get_children():
		if child is MultiMeshInstance3D:
			var multimesh := (child as MultiMeshInstance3D).multimesh
			var mesh := multimesh.mesh as ArrayMesh
			if mesh == null:
				continue
			for s in mesh.get_surface_count():
				var indices: int = mesh.surface_get_array_index_len(s)
				total += (indices if indices > 0 else mesh.surface_get_array_len(s)) / 3 * multimesh.instance_count
	return total
