class_name MapWorld
extends Node3D
## La carte d'Orvana en 3D : un diorama de la capitale, en terrasses, gravi
## par une route de braises. La caméra est inclinée comme en jeu et suit la
## route. Les positions (points de la route, moulin, étages) viennent de
## `MapScene`, qui reste le modèle des données : un point du plan (x, y) se
## pose en (x, hauteur de l'étage, y) du monde, à l'échelle `S`.
##
## Peu d'objets, regroupés (MultiMesh), et des matériaux qui luisent : le
## téléphone de l'auteur est modeste, et sans lueur tout retombe au noir.

const S := 0.03
const CENTER := Vector2(640.0, 1500.0)
## Hauteur de chaque étage : la ville se gravit.
const HEIGHTS := [0.0, 2.0, 4.0, 6.0]
const CAMERA_OFFSET := Vector3(0.0, 13.0, 15.0)
const PALE := Color(0.94, 0.89, 0.76)
const AMBER := Color(0.91, 0.69, 0.38)
const EMBER := Color(1.0, 0.54, 0.35)
const WATER_LEVEL := -0.8

var camera: Camera3D
var data: MapScene
var terrain: MapTerrain
var city: MapCity
var life: MapLife
## Le corbeau qui guide la caméra vers un niveau.
var raven: MeshInstance3D
## Rapprochement de la caméra : 1, la vue normale ; moins, plus près.
var zoom := 1.0
## Faux pendant les essais : la brume se lève d'un coup.
var animate_reveal := true

var _nodes: Array[Dictionary] = []
var _labels: Array[Label3D] = []
var _circles: Array[MeshInstance3D] = []
var _qmark: Label3D
var _sails: Node3D
var _sails_basis := Basis.IDENTITY
var _wheel: Node3D
var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _time := 0.0
var _selected := -1
var _refuge := false
var _here := -1
var _built_count := 0


## Hauteur du sol au point du plan d'ordonnée `y` : des plateaux d'étage, et
## des rampes entre deux.
static func height_at(y: float) -> float:
	var terraces := MapScene.TERRACES
	# De bas en haut : le plateau de chaque étage, puis la rampe jusqu'au suivant.
	for i in terraces.size():
		var terrace: Dictionary = terraces[i]
		var top := float(terrace["y1"])
		var bottom := float(terrace["y0"])
		if y >= bottom and i == 0:
			return float(HEIGHTS[0])
		if y >= top:
			return float(HEIGHTS[i])
		if i + 1 < terraces.size():
			var next_bottom := float((terraces[i + 1] as Dictionary)["y0"])
			if y > next_bottom:
				return lerpf(float(HEIGHTS[i + 1]), float(HEIGHTS[i]), clampf((y - next_bottom) / maxf(top - next_bottom, 1.0), 0.0, 1.0))
	return float(HEIGHTS[HEIGHTS.size() - 1])


static func to_world(p: Vector2, extra := 0.0) -> Vector3:
	return Vector3((p.x - CENTER.x) * S, height_at(p.y) + extra, (p.y - CENTER.y) * S)


func _init() -> void:
	name = "MapWorld"


# --- Mise en place ------------------------------------------------------------

func build(model: MapScene) -> void:
	data = model
	_build_environment()
	terrain = MapTerrain.new(model.route)
	_build_ground()
	city = MapCity.new()
	add_child(city)
	city.build(terrain, model.route)
	life = MapLife.new()
	add_child(life)
	life.build(city)
	_build_road()
	_build_river()
	_build_mill()
	_build_foundations()
	_build_nodes()
	_build_labels()
	raven = MeshInstance3D.new()
	raven.mesh = MapLife.crow_mesh()
	raven.material_override = MapLife.crow_material()
	raven.scale = Vector3.ONE * 2.4
	raven.visible = false
	raven.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(raven)
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.current = true
	add_child(camera)
	focus(float(data.node_positions[0].y))


func _mat(color: Color, energy := 1.0) -> StandardMaterial3D:
	var material := Fx.flat(color, 0.0, 1.0)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _unshaded(color: Color) -> StandardMaterial3D:
	var material := Fx.glow(color)
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


func _box(parent: Node, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	parent.add_child(node)
	return node


func _multi(mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.015, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.45, 0.7)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.04, 0.08)
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.78, 1.0)
	moon.light_energy = 0.45
	moon.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	moon.shadow_enabled = false
	add_child(moon)


## Le relief, fabriqué d'avance (`MapTerrain`).
func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Relief"
	ground.mesh = load(MapTerrain.MESH_PATH)
	ground.material_override = MapTerrain.material()
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


## La route : un ruban sombre et des braises qui la jalonnent.
func _build_road() -> void:
	var route := data.route
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dashes: Array[Transform3D] = []
	var carry := 0.0
	for i in range(1, route.size()):
		var a := to_world(route[i - 1], 0.05)
		var b := to_world(route[i], 0.05)
		var along := b - a
		along.y = 0.0
		var length := along.length()
		if length < 0.01:
			continue
		var direction := along.normalized()
		var side := direction.cross(Vector3.UP) * 0.25
		var a_high := to_world(route[i - 1], 0.05)
		var b_high := to_world(route[i], 0.05)
		for v: Vector3 in [a_high - side, a_high + side, b_high + side, a_high - side, b_high + side, b_high - side]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(v)
		var at := 0.0 - carry
		while at < length:
			if at >= 0.0:
				var p := a.lerp(b, at / maxf(length, 0.01))
				var basis := Basis.looking_at(direction, Vector3.UP) * Basis.from_scale(Vector3(0.09, 0.06, 0.26))
				dashes.append(Transform3D(basis, p + Vector3(0.0, 0.05, 0.0)))
			at += 0.7
		carry = fmod(carry + length, 0.7)
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = surface.commit()
	ribbon.material_override = _mat(Color(0.2, 0.13, 0.07), 1.0)
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ribbon)
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3.ONE
	_multi(dash_mesh, _unshaded(Color(1.0, 0.72, 0.3, 1.0)), dashes)


func _build_river() -> void:
	var shader := Shader.new()
	# La même eau que dans le niveau du moulin, en plus sombre : c'est la nuit.
	shader.code = Scenery.WATER_SHADER.replace("vec3(0.13, 0.25, 0.48)", "vec3(0.035, 0.065, 0.15)") \
		.replace("vec3(0.22, 0.36, 0.55)", "vec3(0.07, 0.12, 0.22)").replace("vec3(0.35, 0.33, 0.22)", "vec3(0.16, 0.15, 0.1)")
	var water := ShaderMaterial.new()
	water.shader = shader
	var plane := PlaneMesh.new()
	# Le fleuve traverse tout le relief ; le lit est creusé dans le terrain.
	plane.size = Vector2(MapTerrain.X_SPAN.y - MapTerrain.X_SPAN.x, (2770.0 - 2540.0) * S)
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = water
	node.position = Vector3(0.0, WATER_LEVEL, to_world(Vector2(640.0, 2655.0)).z)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	# Le pont vers la ville.
	var deck := to_world(Vector2(MapScene.BRIDGE_X, 2634.0))
	_box(self, Vector3(1.1, 0.16, (MapScene.RIVER_BOTTOM - MapScene.RIVER_TOP + 24.0) * S), Vector3(deck.x, -0.05, deck.z), _mat(Color(0.25, 0.17, 0.1), 1.2))
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(0.08, 0.35, (MapScene.RIVER_BOTTOM - MapScene.RIVER_TOP) * S), Vector3(deck.x + side * 0.52, 0.15, deck.z), _mat(Color(0.3, 0.2, 0.12), 1.2))


## Le moulin : le moulin à vent du pack, agrandi, ses ailes qui tournent, et
## la roue à aubes qui plonge dans l'anse.
func _build_mill() -> void:
	var base := to_world(Vector2(MapScene.MILL_X, 2700.0))
	var mill := (load(MapCity.DIR + "building_windmill_red.gltf") as PackedScene).instantiate() as Node3D
	mill.position = base
	mill.scale = Vector3.ONE * 2.3
	add_child(mill)
	for mesh: Node in mill.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = city.night_material()
	# Les fenêtres du refuge restent allumées.
	for side: float in [-1.0, 1.0]:
		_box(mill, Vector3(0.09, 0.12, 0.02), Vector3(side * 0.16, 0.42, 0.39), _unshaded(Color(1.0, 0.66, 0.3, 1.0)))
	_sails = mill.find_child("building_windmill_top_fan_red", true, false) as Node3D
	if _sails != null:
		_sails_basis = _sails.basis
	var wood := _mat(Color(0.15, 0.1, 0.07), 1.2)
	_wheel = Node3D.new()
	_wheel.position = base + Vector3(-1.5, 0.7, 0.2)
	add_child(_wheel)
	for k in 8:
		var spoke := Node3D.new()
		spoke.rotation.z = k * TAU / 8.0
		_wheel.add_child(spoke)
		_box(spoke, Vector3(0.08, 1.5, 0.1), Vector3(0.0, 0.75, 0.0), wood)
		_box(spoke, Vector3(0.3, 0.1, 0.5), Vector3(0.0, 1.5, 0.0), wood)


## Sous la ville : une plaque sombre, un « ? » et dix cercles, un par chapitre.
func _build_foundations() -> void:
	var plate := to_world(Vector2(690.0, 2865.0))
	_box(self, Vector3(520.0 * S, 0.06, 130.0 * S), Vector3(plate.x, 0.03, plate.z), _mat(Color(0.04, 0.04, 0.09), 1.0))
	for i in WorldData.ROUTE_CHAPTERS:
		var at := to_world(Vector2(680.0 + 54.0 * (i % 5) + (0.0 if i < 5 else 27.0), 2840.0 + 50.0 * (i / 5)))
		var disc := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.32
		cylinder.bottom_radius = 0.32
		cylinder.height = 0.1
		cylinder.radial_segments = 16
		disc.mesh = cylinder
		disc.material_override = _mat(Color(0.29, 0.27, 0.38), 1.0)
		disc.position = Vector3(at.x, 0.1, at.z)
		add_child(disc)
		_circles.append(disc)
	_qmark = Label3D.new()
	_qmark.text = "?"
	_qmark.font = GameFonts.text()
	_qmark.font_size = 160
	_qmark.pixel_size = 0.012
	_qmark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_qmark.modulate = Color(0.6, 0.56, 0.69, 0.55)
	_qmark.position = to_world(Vector2(540.0, 2850.0), 1.0)
	add_child(_qmark)


## Les points de la route : un cœur, un anneau, un halo. Les niveaux écrits ont
## le jeu complet ; les autres ne sont que de petits repères.
func _build_nodes() -> void:
	_built_count = WorldData.chapter_levels().size()
	var dots: Array[Transform3D] = []
	for i in data.node_positions.size():
		var at := to_world(data.node_positions[i], 0.12)
		if i >= _built_count:
			dots.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.2), at))
			_nodes.append({})
			continue
		var root := Node3D.new()
		root.position = at
		add_child(root)
		var core := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.2
		sphere.height = 0.4
		sphere.radial_segments = 12
		sphere.rings = 6
		core.mesh = sphere
		core.position.y = 0.25
		root.add_child(core)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.34
		torus.outer_radius = 0.42
		torus.rings = 16
		torus.ring_segments = 6
		ring.mesh = torus
		ring.position.y = 0.2
		root.add_child(ring)
		var halo := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.75
		disc.bottom_radius = 0.75
		disc.height = 0.02
		disc.radial_segments = 20
		halo.mesh = disc
		halo.position.y = 0.04
		root.add_child(halo)
		var brazier := _brazier(i)
		root.add_child(brazier)
		_nodes.append({"root": root, "core": core, "ring": ring, "halo": halo, "brazier": brazier})
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.5
	dot_mesh.height = 1.0
	dot_mesh.radial_segments = 8
	dot_mesh.rings = 4
	_multi(dot_mesh, _mat(Color(0.35, 0.33, 0.48), 1.2), dots)
	# La colonne de lueur du prochain niveau, et l'anneau du niveau choisi.
	_beam = MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 0.1
	column.bottom_radius = 0.1
	column.height = 5.0
	column.radial_segments = 8
	_beam.mesh = column
	_beam.material_override = Fx.glow(Color(1.0, 0.45, 0.25, 0.28))
	_beam.visible = false
	add_child(_beam)
	_ring = MeshInstance3D.new()
	var selection := TorusMesh.new()
	selection.inner_radius = 0.62
	selection.outer_radius = 0.72
	selection.rings = 24
	selection.ring_segments = 6
	_ring.mesh = selection
	_ring.material_override = _unshaded(Color(PALE, 0.95))
	_ring.visible = false
	add_child(_ring)


const FIRE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float seed = 0.0;

void vertex() {
	// Toujours face a la camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(MAIN_CAM_INV_VIEW_MATRIX[0], MAIN_CAM_INV_VIEW_MATRIX[1], MAIN_CAM_INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME * 3.0 + seed;
	float x = (uv.x - 0.5) * 2.0 + sin(t * 2.1 + uv.y * 6.0) * 0.14 * uv.y;
	float width = pow(1.0 - uv.y, 0.6) * (0.85 + 0.12 * sin(t * 3.3));
	float shape = smoothstep(width, width * 0.2, abs(x)) * smoothstep(1.0, 0.45, uv.y + 0.1 * sin(t * 5.0)) * smoothstep(0.0, 0.06, uv.y);
	vec3 color = mix(vec3(0.9, 0.2, 0.04), vec3(1.0, 0.62, 0.2), smoothstep(0.35, 1.0, shape));
	ALBEDO = color * shape * 1.25;
	ALPHA = shape;
}
"""


## Le brasier qui s'allume sur un niveau terminé : une vasque de fer sur un
## pied, et sa flamme.
func _brazier(index: int) -> Node3D:
	var root := Node3D.new()
	root.visible = false
	var iron := _mat(Color(0.09, 0.08, 0.1), 1.0)
	_box(root, Vector3(0.06, 0.3, 0.06), Vector3(0.0, 0.15, 0.0), iron)
	var bowl := MeshInstance3D.new()
	var cup := CylinderMesh.new()
	cup.top_radius = 0.17
	cup.bottom_radius = 0.07
	cup.height = 0.12
	cup.radial_segments = 10
	cup.rings = 1
	bowl.mesh = cup
	bowl.material_override = iron
	bowl.position.y = 0.34
	root.add_child(bowl)
	var embers := MeshInstance3D.new()
	var top := CylinderMesh.new()
	top.top_radius = 0.15
	top.bottom_radius = 0.15
	top.height = 0.01
	top.radial_segments = 10
	embers.mesh = top
	embers.material_override = _unshaded(Color(1.0, 0.45, 0.15, 1.0))
	embers.position.y = 0.4
	root.add_child(embers)
	var flame := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 1.05)
	flame.mesh = quad
	var shader := Shader.new()
	shader.code = FIRE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("seed", float(index) * 1.37)
	flame.material_override = material
	flame.position.y = 0.88
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flame)
	return root


func _label(text: String, size: int, color: Color, at: Vector3, pixel := 0.0055) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = GameFonts.text()
	label.font_size = size
	label.pixel_size = pixel
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 12
	label.outline_modulate = Color(0.0, 0.0, 0.03, 0.95)
	label.modulate = color
	label.position = at
	add_child(label)
	return label


func _build_labels() -> void:
	var levels := WorldData.chapter_levels()
	for i in levels.size():
		_labels.append(_label("%d. %s" % [i + 1, levels[i]["name"]], 60, PALE, to_world(data.node_positions[i], 2.0 if i % 2 == 0 else 2.7), 0.0065))
	for c in WorldData.CHAPTERS.size():
		var start: Vector2 = (data.lane_segments[c] as Array)[0]
		var first_above := (c * WorldData.LEVELS_PER_CHAPTER) % 2 == 1
		_label("Chapitre %s" % WorldData.roman(c + 1), 70, EMBER, to_world(start + Vector2(0.0, 55.0 if first_above else -50.0), 2.2), 0.0065)
	for a in WorldData.ACTS.size():
		var act: Dictionary = WorldData.ACTS[a]
		var terrace: Dictionary = MapScene.TERRACES[a]
		var at := to_world(Vector2(1010.0, float(terrace["y1"]) + 30.0), 1.3)
		_label(String(act["name"]).to_upper(), 70, Color(0.6, 0.56, 0.69, 0.85), at, 0.0075)
	_label("le moulin, refuge", 52, Color(0.7, 0.66, 0.8, 0.95), to_world(Vector2(MapScene.MILL_X, 2745.0), 0.8))


# --- États --------------------------------------------------------------------

func set_states(states: PackedStringArray, flags: Array) -> void:
	for i in _built_count:
		var node: Dictionary = _nodes[i]
		var state := states[i] if i < states.size() else "ferme"
		var core := node["core"] as MeshInstance3D
		var ring := node["ring"] as MeshInstance3D
		var halo := node["halo"] as MeshInstance3D
		match state:
			"fait":
				core.material_override = _mat(AMBER, 3.0)
				ring.material_override = _unshaded(Color(AMBER, 0.95))
				halo.material_override = Fx.glow(Color(AMBER, 0.22))
				halo.visible = true
			"ici":
				core.material_override = _mat(EMBER, 4.0)
				ring.material_override = _unshaded(Color(EMBER, 0.95))
				halo.material_override = Fx.glow(Color(EMBER, 0.3))
				halo.visible = true
			"ouvert":
				core.material_override = _mat(AMBER, 1.2)
				ring.material_override = _unshaded(Color(AMBER, 0.9))
				halo.visible = false
			_:
				core.material_override = _mat(Color(0.35, 0.33, 0.48), 1.2)
				ring.material_override = _unshaded(Color(0.35, 0.33, 0.48, 0.6))
				halo.visible = false
		# Un niveau terminé : son brasier brûle à la place de la braise.
		var done := state == "fait"
		(node["brazier"] as Node3D).visible = done
		core.visible = not done
		var ready: bool = i < flags.size() and flags[i]
		_labels[i].modulate = PALE if ready else Color(0.6, 0.56, 0.69, 0.85)
	for i in _circles.size():
		var done: bool = i < data.chapters_done.size() and data.chapters_done[i]
		_circles[i].material_override = _mat(AMBER if done else Color(0.29, 0.27, 0.38), 3.0 if done else 1.0)
	life.set_states(zone_states(states), animate_reveal)
	var all_done := data.chapters_done.size() == WorldData.ROUTE_CHAPTERS and not data.chapters_done.has(false)
	_qmark.modulate = Color(AMBER, 0.95) if all_done else Color(0.6, 0.56, 0.69, 0.55)


## L'état de chaque quartier de la ville, d'après les niveaux de son chapitre.
func zone_states(states: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	for k in life.lanes.size():
		var chapter := MapLife.chapter_of_zone(k)
		var state := MapLife.PERDU
		if chapter < data.chapters_done.size() and data.chapters_done[chapter]:
			state = MapLife.APAISE
		else:
			for n in range(chapter * WorldData.LEVELS_PER_CHAPTER, (chapter + 1) * WorldData.LEVELS_PER_CHAPTER):
				if n < states.size() and (states[n] == "fait" or states[n] == "ici"):
					state = MapLife.ATTEINT
		result.append(state)
	return result


func set_here(index: int) -> void:
	_here = index
	_beam.visible = index >= 0 and index < _built_count
	if _beam.visible:
		_beam.position = to_world(data.node_positions[index], 2.7)


func set_selected(index: int, refuge: bool) -> void:
	_selected = index
	_refuge = refuge
	_ring.visible = refuge or (index >= 0 and index < data.node_positions.size())
	if refuge:
		_ring.position = to_world(Vector2(MapScene.MILL_X, 2700.0), 1.0)
	elif index >= 0:
		_ring.position = to_world(data.node_positions[index], 0.3)


# --- Caméra et choix ----------------------------------------------------------

## Place la caméra pour regarder le point du plan d'ordonnée `plane_y`.
func focus(plane_y: float) -> void:
	# Près du bas de la carte, la caméra se décale vers le moulin, à gauche.
	var shift := clampf((plane_y - 2300.0) / 320.0, 0.0, 1.0) * 300.0
	focus_point(Vector2(CENTER.x - shift, plane_y))


## Place la caméra pour regarder le point `plane` du plan, au rapprochement
## `zoom`.
func focus_point(plane: Vector2) -> void:
	var target := to_world(plane, 0.3)
	camera.position = target + CAMERA_OFFSET * zoom
	camera.look_at(target, Vector3.UP)


## Où la caméra regarde : x du plan quand on ne la décale pas.
func default_x(plane_y: float) -> float:
	return CENTER.x - clampf((plane_y - 2300.0) / 320.0, 0.0, 1.0) * 300.0


## Position à l'écran d'un point du plan.
func screen_of(plane: Vector2) -> Vector2:
	return camera.unproject_position(to_world(plane, 0.25))


## Le point de la route le plus proche du toucher `at`, à `radius` pixels au
## plus ; -1 s'il n'y en a pas, -2 pour le moulin.
func pick(at: Vector2, radius: float, mill_radius: float) -> int:
	var best := -1
	var best_distance := radius
	for i in data.node_positions.size():
		var p := to_world(data.node_positions[i], 0.25)
		if camera.is_position_behind(p):
			continue
		var distance := camera.unproject_position(p).distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = i
	if best >= 0:
		return best
	var mill := to_world(Vector2(MapScene.MILL_X, 2650.0), 1.0)
	if not camera.is_position_behind(mill) and camera.unproject_position(mill).distance_to(at) <= mill_radius:
		return -2
	return -1


func _process(delta: float) -> void:
	_time += delta
	if _sails != null:
		_sails.basis = _sails_basis * Basis(Vector3.BACK, _time * 0.5)
	if _wheel != null:
		_wheel.rotation.z = -_time * 0.9
	var pulse := 0.5 + 0.5 * sin(_time * 2.4)
	if _here >= 0 and _here < _built_count:
		var halo := (_nodes[_here]["halo"] as MeshInstance3D)
		halo.scale = Vector3.ONE * (1.0 + 0.25 * pulse)
	if _ring.visible:
		_ring.scale = Vector3.ONE * (1.0 + 0.06 * sin(_time * 3.0))
