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

var _nodes: Array[Dictionary] = []
var _labels: Array[Label3D] = []
var _circles: Array[MeshInstance3D] = []
var _qmark: Label3D
var _sails: Node3D
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
	_build_terraces()
	_build_town()
	_build_road()
	_build_river()
	_build_mill()
	_build_foundations()
	_build_nodes()
	_build_labels()
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
	env.ambient_light_energy = 0.7
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
	# Un sol sombre très bas, loin sous la ville, pour que rien ne flotte dans le noir.
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = plane
	floor_node.material_override = _mat(Color(0.03, 0.04, 0.08), 0.8)
	floor_node.position = Vector3(0.0, -4.0, 0.0)
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_node)
	# Des étoiles, pour que le haut de l'écran ne soit jamais vide.
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var stars: Array[Transform3D] = []
	for i in 160:
		stars.append(Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.5, 1.4)),
			Vector3(rng.randf_range(-50.0, 50.0), rng.randf_range(14.0, 40.0), rng.randf_range(-95.0, 10.0))))
	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(0.12, 0.12, 0.12)
	_multi(star_mesh, _unshaded(Color(0.8, 0.85, 1.0, 0.8)), stars)


## Les quatre étages : un socle en gradin chacun, un rempart devant, des tours.
func _build_terraces() -> void:
	var tints := [Color(0.1, 0.11, 0.2), Color(0.14, 0.17, 0.3), Color(0.19, 0.23, 0.38), Color(0.25, 0.3, 0.46)]
	for i in MapScene.TERRACES.size():
		var terrace: Dictionary = MapScene.TERRACES[i]
		var x0 := float(terrace["x0"]) - 22.0
		var x1 := float(terrace["x1"]) + 22.0
		var y0 := float(terrace["y0"])
		var y1 := float(terrace["y1"])
		var height := float(HEIGHTS[i])
		var depth := 3.2
		var size := Vector3((x1 - x0) * S, depth, (y0 - y1) * S)
		var center := to_world(Vector2((x0 + x1) / 2.0, (y0 + y1) / 2.0))
		_box(self, size, Vector3(center.x, height - depth / 2.0, center.z), _mat(tints[i] as Color, 1.0))
		# Le rempart, le long du bord sud de l'étage, et deux tours aux angles.
		var tint: Color = tints[i]
		var wall_color := tint.darkened(0.4)
		_box(self, Vector3(size.x, 0.55, 0.28), Vector3(center.x, height + 0.27, center.z + size.z / 2.0 - 0.14), _mat(wall_color, 0.9))
		for side: float in [-1.0, 1.0]:
			var tower_at := Vector3(center.x + side * (size.x / 2.0 - 0.7), height + 1.0, center.z + size.z / 2.0 - 0.7)
			_box(self, Vector3(1.0, 2.0, 1.0), tower_at, _mat(wall_color, 0.9))
			_box(self, Vector3(1.2, 0.3, 1.2), tower_at + Vector3(0.0, 1.1, 0.0), _mat(wall_color.lightened(0.1), 0.9))


## Les maisons, de part et d'autre de la route, leurs toits et leurs fenêtres
## allumées ; et les grands édifices : donjon, cathédrale, palais.
func _build_town() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var walls: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var windows: Array[Transform3D] = []
	for i in MapScene.TERRACES.size():
		var terrace: Dictionary = MapScene.TERRACES[i]
		var height := float(HEIGHTS[i])
		for lane_y: float in terrace["lanes"]:
			var x := float(terrace["x0"]) + 60.0
			while x < float(terrace["x1"]) - 60.0:
				x += 70.0
				if rng.randf() < 0.3 or (absf(x - 640.0) < 90.0 and i >= 1):
					continue
				var w := rng.randf_range(1.1, 1.6)
				var h := rng.randf_range(0.7, 1.2)
				var d := rng.randf_range(0.8, 1.1)
				var at := to_world(Vector2(x + rng.randf_range(-12.0, 12.0), lane_y - 24.0))
				walls.append(Transform3D(Basis.from_scale(Vector3(w, h, d)), Vector3(at.x, height + h / 2.0, at.z)))
				roofs.append(Transform3D(Basis.from_scale(Vector3(w + 0.25, 0.7, d + 0.25)), Vector3(at.x, height + h + 0.35, at.z)))
				if rng.randf() < 0.7:
					windows.append(Transform3D(Basis.from_scale(Vector3(0.24, 0.3, 0.06)),
						Vector3(at.x + rng.randf_range(-0.3, 0.3), height + h * 0.55, at.z + d / 2.0 + 0.02)))
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE
	var prism := PrismMesh.new()
	prism.size = Vector3.ONE
	_multi(box_mesh, _mat(Color(0.12, 0.15, 0.28), 1.5), walls)
	_multi(prism, _mat(Color(0.2, 0.12, 0.16), 1.3), roofs)
	_multi(box_mesh, _unshaded(Color(1.0, 0.7, 0.28, 1.0)), windows)
	# Le donjon de la citadelle, la nef et la flèche de la cathédrale, le palais.
	var keep := to_world(Vector2(640.0, 1575.0))
	_box(self, Vector3(5.4, 2.6, 4.0), Vector3(keep.x, HEIGHTS[1] + 1.3, keep.z), _mat(Color(0.16, 0.2, 0.34), 1.2))
	var nave := to_world(Vector2(640.0, 1205.0))
	_box(self, Vector3(5.4, 3.0, 2.8), Vector3(nave.x, HEIGHTS[2] + 1.5, nave.z), _mat(Color(0.2, 0.24, 0.4), 1.2))
	_box(self, Vector3(1.7, 3.6, 1.7), Vector3(nave.x, HEIGHTS[2] + 1.8, nave.z - 2.4), _mat(Color(0.2, 0.24, 0.4), 1.2))
	var spire := MeshInstance3D.new()
	var cone := PrismMesh.new()
	cone.size = Vector3(1.9, 3.4, 1.9)
	spire.mesh = cone
	spire.material_override = _mat(Color(0.18, 0.2, 0.36), 1.2)
	spire.position = Vector3(nave.x, HEIGHTS[2] + 5.3, nave.z - 2.4)
	add_child(spire)
	var palace := to_world(Vector2(640.0, 520.0))
	_box(self, Vector3(8.4, 3.0, 3.0), Vector3(palace.x, HEIGHTS[3] + 1.5, palace.z), _mat(Color(0.26, 0.31, 0.48), 1.3))
	for dx: float in [-3.0, 0.0, 3.0]:
		var tower := _box(self, Vector3(1.6, 4.2, 1.6), Vector3(palace.x + dx, HEIGHTS[3] + 2.1, palace.z - 0.4), _mat(Color(0.28, 0.33, 0.5), 1.3))
		var dome := MeshInstance3D.new()
		var roof := PrismMesh.new()
		roof.size = Vector3(1.9, 1.6, 1.9)
		dome.mesh = roof
		dome.material_override = _mat(Color(0.3, 0.2, 0.26), 1.3)
		dome.position = tower.position + Vector3(0.0, 2.9, 0.0)
		add_child(dome)


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
				var basis := Basis.looking_at(direction, Vector3.UP) * Basis.from_scale(Vector3(0.14, 0.08, 0.4))
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
	# Le fleuve seulement, et l'anse du moulin : pas une mer autour de la ville.
	plane.size = Vector2(1240.0 * S, (2770.0 - 2540.0) * S)
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = water
	node.position = Vector3(0.0, WATER_LEVEL, to_world(Vector2(640.0, 2655.0)).z)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	# La rive sud, avec l'anse où plonge la roue ; le pont vers la ville.
	var bank := _mat(Color(0.08, 0.1, 0.18), 1.2)
	var south := to_world(Vector2(660.0, 2865.0))
	_box(self, Vector3(1200.0 * S, 1.6, 150.0 * S), Vector3(south.x, -0.8, south.z), bank)
	var strip := to_world(Vector2(700.0, 2745.0))
	_box(self, Vector3(1090.0 * S, 1.6, 90.0 * S), Vector3(strip.x + 0.0, -0.8, strip.z), bank)
	var deck := to_world(Vector2(MapScene.BRIDGE_X, 2634.0))
	_box(self, Vector3(1.1, 0.16, (MapScene.RIVER_BOTTOM - MapScene.RIVER_TOP + 24.0) * S), Vector3(deck.x, -0.05, deck.z), _mat(Color(0.25, 0.17, 0.1), 1.2))
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(0.08, 0.35, (MapScene.RIVER_BOTTOM - MapScene.RIVER_TOP) * S), Vector3(deck.x + side * 0.52, 0.15, deck.z), _mat(Color(0.3, 0.2, 0.12), 1.2))


## Le moulin : une tour de pierre, un toit, des ailes qui tournent, et la roue
## à aubes qui plonge dans l'anse.
func _build_mill() -> void:
	var base := to_world(Vector2(MapScene.MILL_X, 2700.0))
	var tower := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.7
	shaft.bottom_radius = 0.95
	shaft.height = 2.6
	shaft.radial_segments = 12
	tower.mesh = shaft
	tower.material_override = _mat(Color(0.2, 0.22, 0.34), 1.3)
	tower.position = base + Vector3(0.0, 1.3, 0.0)
	add_child(tower)
	var roof := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 1.0
	cap.height = 1.1
	cap.radial_segments = 12
	roof.mesh = cap
	roof.material_override = _mat(Color(0.22, 0.12, 0.14), 1.3)
	roof.position = base + Vector3(0.0, 3.15, 0.0)
	add_child(roof)
	_box(self, Vector3(0.28, 0.4, 0.06), base + Vector3(0.0, 1.5, 0.95), _unshaded(Color(1.0, 0.7, 0.28, 1.0)))
	_sails = Node3D.new()
	_sails.position = base + Vector3(0.0, 2.7, 1.05)
	add_child(_sails)
	var wood := _mat(Color(0.15, 0.1, 0.07), 1.2)
	for k in 4:
		var blade := Node3D.new()
		blade.rotation.z = k * PI / 2.0
		_sails.add_child(blade)
		_box(blade, Vector3(0.1, 2.0, 0.08), Vector3(0.0, 1.1, 0.0), wood)
		_box(blade, Vector3(0.45, 1.3, 0.05), Vector3(0.28, 1.4, 0.0), _mat(Color(0.3, 0.26, 0.2), 1.2))
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
		_nodes.append({"root": root, "core": core, "ring": ring, "halo": halo})
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
		var ready: bool = i < flags.size() and flags[i]
		_labels[i].modulate = PALE if ready else Color(0.6, 0.56, 0.69, 0.85)
	for i in _circles.size():
		var done: bool = i < data.chapters_done.size() and data.chapters_done[i]
		_circles[i].material_override = _mat(AMBER if done else Color(0.29, 0.27, 0.38), 3.0 if done else 1.0)
	var all_done := data.chapters_done.size() == WorldData.ROUTE_CHAPTERS and not data.chapters_done.has(false)
	_qmark.modulate = Color(AMBER, 0.95) if all_done else Color(0.6, 0.56, 0.69, 0.55)


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
	var target := to_world(Vector2(CENTER.x - shift, plane_y), 0.3)
	camera.position = target + CAMERA_OFFSET
	camera.look_at(target, Vector3.UP)


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
		_sails.rotation.z = _time * 0.5
	if _wheel != null:
		_wheel.rotation.z = -_time * 0.9
	var pulse := 0.5 + 0.5 * sin(_time * 2.4)
	if _here >= 0 and _here < _built_count:
		var halo := (_nodes[_here]["halo"] as MeshInstance3D)
		halo.scale = Vector3.ONE * (1.0 + 0.25 * pulse)
	if _ring.visible:
		_ring.scale = Vector3.ONE * (1.0 + 0.06 * sin(_time * 3.0))
