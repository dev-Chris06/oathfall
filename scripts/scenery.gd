class_name Scenery
extends RefCounted
## Les abords d'un niveau : le terrain jouable est un plateau surélevé, et tout
## ce que la caméra voit autour est un décor défini selon le lieu, jamais du
## noir ni un horizon indéfini.
##
## La caméra regarde vers le bas (36° sous l'horizontale, 24° de demi-champ) :
## elle ne voit jamais le ciel, seulement le sol jusqu'à environ 45 m. Les
## abords sont donc du sol plus bas, vu d'en haut, avec ce qui s'y trouve :
## toits d'un faubourg, collines, rive d'en face, ou roche sous terre.
##
## Tout est fait de peu d'objets (des MultiMesh, une seule commande de dessin
## chacun) et de matériaux qui luisent un peu : le téléphone de l'auteur est
## modeste, et un matériau sans lueur retombe au noir sous la brume.

const CEMETERY := &"cemetery"
const PIT := &"pit"
const UNDERGROUND := &"underground"
const RIVER := &"river"


## Habille les abords. `floor_rect` : le sol dallé (x, z, largeur, profondeur) ;
## `walls` : le terrain jouable, que ferment les murs.
static func dress(level: Level, kind: StringName, floor_rect: Rect2, walls: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.title)
	match kind:
		UNDERGROUND:
			# Sous terre, ce sont les blocs posés sur les murs (`Level._caps`)
			# qui cachent l'arrière : rien d'autre à ajouter.
			pass
		PIT:
			_ground(level, floor_rect, 6.0, Color(0.24, 0.16, 0.14), Color(0.13, 0.09, 0.08))
			_hills(level, floor_rect, 6.0, rng)
			_trees(level, floor_rect, 6.0, rng, 34, Color(0.05, 0.03, 0.03))
		RIVER:
			_river(level, floor_rect, rng)
		_:
			_ground(level, floor_rect, 8.0, Color(0.17, 0.23, 0.42), Color(0.1, 0.12, 0.22))
			_town(level, floor_rect, 8.0, rng)
			_trees(level, floor_rect, 8.0, rng, 26, Color(0.03, 0.035, 0.07))


# --- Pièces communes ----------------------------------------------------------

static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := Fx.flat(color, 0.0, 1.0)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func _add(level: Level, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	level.add_child(node)
	return node


static func _multi(level: Level, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
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
	level.add_child(node)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## Du sol plus bas, à perte de vue, et sous le dallage un socle plein : le
## terrain jouable se lit comme un plateau.
static func _ground(level: Level, floor_rect: Rect2, drop: float, ground: Color, plinth: Color) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(500.0, 500.0)
	_add(level, plane, _glow(ground, 1.5), Vector3(floor_rect.get_center().x, -drop, floor_rect.get_center().y))
	var height := drop - 0.55
	_add(level, _box(Vector3(floor_rect.size.x, height, floor_rect.size.y)), _glow(plinth, 1.2),
		Vector3(floor_rect.get_center().x, -0.55 - height / 2.0, floor_rect.get_center().y))


## Un point au hasard dans l'anneau autour du terrain, à `near` mètres au moins
## de lui et `far` au plus.
static func _ring_point(rng: RandomNumberGenerator, floor_rect: Rect2, near: float, far: float) -> Vector2:
	var inner := floor_rect.grow(near)
	for attempt in 40:
		var spread := rng.randf_range(near, far)
		var p := Vector2(
			rng.randf_range(floor_rect.position.x - spread, floor_rect.end.x + spread),
			rng.randf_range(floor_rect.position.y - spread, floor_rect.end.y + spread))
		if not inner.has_point(p):
			return p
	return Vector2(floor_rect.end.x + near + 1.0, floor_rect.end.y + near + 1.0)


# --- Faubourg, collines, arbres -----------------------------------------------

## Les toits du faubourg, vus d'en haut, et ses lanternes.
static func _town(level: Level, floor_rect: Rect2, drop: float, rng: RandomNumberGenerator) -> void:
	var walls: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var cell := 10.0
	var area := floor_rect.grow(70.0)
	var inner := floor_rect.grow(5.0)
	var x := area.position.x
	while x < area.end.x:
		var z := area.position.y
		while z < area.end.y:
			var p := Vector2(x + rng.randf_range(0.0, cell * 0.4), z + rng.randf_range(0.0, cell * 0.4))
			z += cell
			if inner.has_point(p) or rng.randf() < 0.28:
				continue
			var w := rng.randf_range(4.0, 7.0)
			var d := rng.randf_range(4.0, 7.0)
			var h := rng.randf_range(3.0, 6.0)
			walls.append(Transform3D(Basis.from_scale(Vector3(w, h, d)), Vector3(p.x, -drop + h / 2.0, p.y)))
			var turn := Basis(Vector3.UP, PI * 0.5 * rng.randi_range(0, 1))
			roofs.append(Transform3D(turn * Basis.from_scale(Vector3(w + 0.8, 2.2, d + 0.8)), Vector3(p.x, -drop + h + 1.1, p.y)))
			if rng.randf() < 0.55:
				lamps.append(Transform3D(Basis.from_scale(Vector3(0.5, 0.5, 0.5)), Vector3(p.x + w / 2.0 + 1.0, -drop + 1.2, p.y + d / 2.0 + 0.8)))
		x += cell
	_multi(level, _box(Vector3.ONE), _glow(Color(0.13, 0.17, 0.32), 1.6), walls)
	var prism := PrismMesh.new()
	prism.size = Vector3.ONE
	_multi(level, prism, _glow(Color(0.2, 0.12, 0.15), 1.3), roofs)
	_multi(level, _box(Vector3.ONE), _glow(Color(1.0, 0.7, 0.3), 4.5), lamps)


## Des collines basses autour de la fosse.
static func _hills(level: Level, floor_rect: Rect2, drop: float, rng: RandomNumberGenerator) -> void:
	var transforms: Array[Transform3D] = []
	for i in 46:
		var p := _ring_point(rng, floor_rect, 10.0, 70.0)
		var r := rng.randf_range(7.0, 16.0)
		var h := rng.randf_range(3.0, 7.0)
		transforms.append(Transform3D(Basis.from_scale(Vector3(r, h, r)), Vector3(p.x, -drop, p.y)))
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	_multi(level, mesh, _glow(Color(0.2, 0.13, 0.12), 1.3), transforms)


## Des arbres morts, en silhouette, plantés sur le sol bas.
static func _trees(level: Level, floor_rect: Rect2, drop: float, rng: RandomNumberGenerator, count: int, color: Color) -> void:
	var trunks: Array[Transform3D] = []
	var branches: Array[Transform3D] = []
	for i in count:
		var p := _ring_point(rng, floor_rect, 4.0, 45.0)
		var h := rng.randf_range(4.5, 8.0)
		trunks.append(Transform3D(Basis.from_scale(Vector3(1.0, h, 1.0)), Vector3(p.x, -drop + h / 2.0, p.y)))
		for b in 3:
			var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.7, 1.2))
			var length := rng.randf_range(2.0, 3.5)
			branches.append(Transform3D(tilt * Basis.from_scale(Vector3(1.0, length, 1.0)), Vector3(p.x, -drop + h * rng.randf_range(0.6, 0.95), p.y)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.08
	trunk.bottom_radius = 0.28
	trunk.height = 1.0
	trunk.radial_segments = 5
	trunk.rings = 1
	var twig := CylinderMesh.new()
	twig.top_radius = 0.02
	twig.bottom_radius = 0.1
	twig.height = 1.0
	twig.radial_segments = 4
	twig.rings = 1
	var material := _glow(color, 0.3)
	_multi(level, trunk, material, trunks)
	_multi(level, twig, material, branches)


# --- Le fleuve ----------------------------------------------------------------

const WATER_SHADER := """
shader_type spatial;
render_mode unshaded;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Des rides qui glissent vers l'est, et la lueur de la lune par endroits.
	float flow = world.x * 0.7 - TIME * 1.3 + sin(world.z * 0.45) * 2.0;
	float ripple = sin(flow) * sin(world.z * 1.1 - TIME * 0.6 + world.x * 0.2);
	float line = smoothstep(0.82, 1.0, ripple);
	float glint = smoothstep(0.93, 1.0, sin(world.x * 0.23 + TIME * 0.4) * sin(world.z * 0.31 - TIME * 0.3));
	vec3 water = vec3(0.13, 0.25, 0.48);
	ALBEDO = water + line * vec3(0.22, 0.36, 0.55) + glint * vec3(0.35, 0.33, 0.22);
}
"""


## Un fleuve en contrebas ; sa rive d'en face porte un faubourg bas.
static func _river(level: Level, floor_rect: Rect2, rng: RandomNumberGenerator) -> void:
	var drop := 3.5
	var shader := Shader.new()
	shader.code = WATER_SHADER
	var water := ShaderMaterial.new()
	water.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(500.0, 500.0)
	_add(level, plane, water, Vector3(floor_rect.get_center().x, -drop, floor_rect.get_center().y))
	var height := drop - 0.55
	_add(level, _box(Vector3(floor_rect.size.x, height, floor_rect.size.y)), _glow(Color(0.12, 0.12, 0.2), 1.2),
		Vector3(floor_rect.get_center().x, -0.55 - height / 2.0, floor_rect.get_center().y))
	# La rive d'en face : de la terre à 20 m, qui porte des toits bas et des arbres.
	var far := floor_rect.grow(20.0)
	var bank := _glow(Color(0.13, 0.16, 0.28), 1.4)
	var top := -2.6
	for part: Rect2 in [
			Rect2(far.position.x - 300.0, far.position.y - 300.0, 300.0, far.size.y + 600.0),
			Rect2(far.end.x, far.position.y - 300.0, 300.0, far.size.y + 600.0),
			Rect2(far.position.x, far.position.y - 300.0, far.size.x, 300.0),
			Rect2(far.position.x, far.end.y, far.size.x, 300.0)]:
		_add(level, _box(Vector3(part.size.x, 1.0, part.size.y)), bank, Vector3(part.get_center().x, top - 0.5, part.get_center().y))
	var houses: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	for i in 40:
		var p := _ring_point(rng, floor_rect, 24.0, 60.0)
		var w := rng.randf_range(4.0, 7.0)
		var d := rng.randf_range(4.0, 7.0)
		var h := rng.randf_range(2.5, 4.5)
		houses.append(Transform3D(Basis.from_scale(Vector3(w, h, d)), Vector3(p.x, top + h / 2.0, p.y)))
		roofs.append(Transform3D(Basis.from_scale(Vector3(w + 0.8, 2.0, d + 0.8)), Vector3(p.x, top + h + 1.0, p.y)))
		if rng.randf() < 0.6:
			lamps.append(Transform3D(Basis.from_scale(Vector3(0.5, 0.5, 0.5)), Vector3(p.x + w / 2.0 + 1.0, top + 1.2, p.y)))
	_multi(level, _box(Vector3.ONE), _glow(Color(0.13, 0.17, 0.32), 1.6), houses)
	var prism := PrismMesh.new()
	prism.size = Vector3.ONE
	_multi(level, prism, _glow(Color(0.2, 0.12, 0.15), 1.3), roofs)
	_multi(level, _box(Vector3.ONE), _glow(Color(1.0, 0.7, 0.3), 3.0), lamps)
	_trees(level, floor_rect.grow(18.0), 2.6, rng, 22, Color(0.04, 0.05, 0.09))
