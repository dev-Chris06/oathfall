class_name Docks
extends RefCounted
## Pièces du port fluvial (chapitre III, les Quais noirs). Les packs n'ont ni
## barque ni quai : tout est fait de formes simples, peu nombreuses.
##
## Le quai est le plateau du niveau ; le fleuve (`Scenery.RIVER`) coule en
## contrebas, à 3,5 sous le pavé. Les barges y flottent, du côté de la caméra
## (+X), et restent basses : elles ne cachent jamais le héros.

const WATER_Y := -3.5

static var _materials := {}


## Matériau qui luit un peu : sans lueur, il retombe au noir sous la brume du
## téléphone.
static func material(color: Color, glow := 0.5) -> StandardMaterial3D:
	var key := "%s/%.2f" % [color.to_html(), glow]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = glow
		_materials[key] = m
	return _materials[key]


static func wood() -> StandardMaterial3D:
	return material(Color(0.5, 0.34, 0.2), 0.12)


static func dark_wood() -> StandardMaterial3D:
	return material(Color(0.34, 0.23, 0.15), 0.15)


static func iron() -> StandardMaterial3D:
	return material(Color(0.1, 0.1, 0.12), 0.3)


static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, yaw_deg := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.rotation_degrees.y = yaw_deg
	parent.add_child(node)
	return node


static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.1
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node


## Une bitte d'amarrage : un fût de fer bas, coiffé.
static func bollard(level: Level, at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	level.add_child(root)
	cylinder(root, 0.28, 0.8, Vector3(0.0, 0.4, 0.0), iron())
	cylinder(root, 0.38, 0.14, Vector3(0.0, 0.85, 0.0), iron())


## Une pile de caisses, solide, à l'emprise de la pile.
static func crates(level: Level, at: Vector3, yaw_deg := 0.0, high := false) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.y = yaw_deg
	level.add_child(root)
	box(root, Vector3(1.1, 1.0, 1.1), Vector3(-0.6, 0.5, 0.0), wood(), 4.0)
	box(root, Vector3(1.0, 0.9, 1.0), Vector3(0.6, 0.45, 0.1), dark_wood(), -7.0)
	if high:
		box(root, Vector3(0.9, 0.8, 0.9), Vector3(-0.3, 1.4, 0.05), dark_wood(), 12.0)
	level.solid(at, Vector3(2.3, 1.6, 1.3), yaw_deg)


## Le bord du quai, du côté du fleuve : un parapet bas, des bittes, et
## l'obstacle qui arrête le héros. `x` : l'aplomb du bord ; de `z_from` à `z_to`.
static func quay_edge(level: Level, x: float, z_from: float, z_to: float) -> void:
	var length := absf(z_to - z_from)
	var mid := (z_from + z_to) / 2.0
	var root := Node3D.new()
	level.add_child(root)
	box(root, Vector3(0.7, 0.7, length), Vector3(x, 0.35, mid), material(Color(0.2, 0.21, 0.27), 0.4))
	var z := maxf(z_from, z_to) - 2.0
	while z > minf(z_from, z_to) + 1.0:
		bollard(level, Vector3(x, 0.7, z))
		z -= 7.0
	level.solid(Vector3(x, 0.0, mid), Vector3(0.8, 4.0, length))


## Une barge amarrée, posée sur l'eau en contrebas, chargée de caisses et de
## formes couchées sous des bâches. `yaw_deg` : 0 pour une barge le long du quai.
static func barge(level: Level, at: Vector3, length := 11.0, yaw_deg := 0.0, lantern := true) -> void:
	var root := Node3D.new()
	root.position = Vector3(at.x, WATER_Y, at.z)
	root.rotation_degrees.y = yaw_deg
	level.add_child(root)
	var hull := material(Color(0.1, 0.075, 0.06), 0.55)
	var width := 3.6
	box(root, Vector3(width, 1.1, length), Vector3(0.0, 0.35, 0.0), hull)
	# Les plats-bords, un peu plus hauts, et les deux bouts relevés.
	for side: float in [-1.0, 1.0]:
		box(root, Vector3(0.25, 0.5, length), Vector3(side * (width / 2.0 - 0.1), 1.1, 0.0), hull)
	for end: float in [-1.0, 1.0]:
		box(root, Vector3(width - 0.4, 0.9, 0.4), Vector3(0.0, 1.2, end * (length / 2.0 - 0.15)), hull)
	box(root, Vector3(width - 0.6, 0.06, length - 0.8), Vector3(0.0, 0.92, 0.0), material(Color(0.2, 0.14, 0.1), 0.5))
	# La cargaison : des caisses, et des bâches sur ce qu'on n'a pas déchargé.
	var cloth := material(Color(0.16, 0.16, 0.2), 0.5)
	var n := int(length / 3.0)
	for i in n:
		var z := -length / 2.0 + 1.6 + i * (length - 3.2) / maxf(n - 1, 1)
		if i % 2 == 0:
			box(root, Vector3(1.0, 0.8, 1.0), Vector3(-0.6, 1.35, z), material(Color(0.24, 0.17, 0.11), 0.5), 9.0 * i)
		else:
			box(root, Vector3(0.75, 0.35, 1.9), Vector3(0.5, 1.12, z), cloth, 4.0 - 6.0 * i)
	if lantern:
		box(root, Vector3(0.08, 1.8, 0.08), Vector3(0.0, 1.8, length / 2.0 - 0.6), iron())
		var light := box(root, Vector3(0.25, 0.3, 0.25), Vector3(0.0, 2.75, length / 2.0 - 0.6), material(Color(1.0, 0.62, 0.28), 3.0))
		light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Une amarre, du plat-bord au quai.
	var rope := box(root, Vector3(3.4, 0.06, 0.06), Vector3(-width / 2.0 - 1.1, 2.4, length / 2.0 - 1.0), material(Color(0.3, 0.26, 0.2), 0.5))
	rope.rotation_degrees.z = -48.0


## Des pieux plantés dans l'eau, le long du quai.
static func piles(level: Level, x: float, z_from: float, z_to: float, step := 4.0) -> void:
	var z := z_from
	while z > z_to:
		cylinder(level, 0.22, 3.6, Vector3(x, WATER_Y + 1.6, z), dark_wood())
		z -= step
