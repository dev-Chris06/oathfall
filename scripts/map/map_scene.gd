class_name MapScene
extends Control
## La ville d'Orvana, vue de face, en silhouettes de papier noir : quatre
## étages en gradins, du fleuve au palais, plus clairs à mesure qu'ils
## s'éloignent. Une route en lacets les gravit ; les niveaux y sont des
## braises. Tout est dessiné par code, une fois (le dessin est conservé), sauf
## ce qui bouge : voir `WorldMap`.

const W := 1280.0
const H := 2960.0
const NODE_COUNT := 50

## Chaque étage : son rang, sa base et son sommet, ses bords, et les voies de
## la route qui le traversent.
const TERRACES := [
	{"act": 1, "y0": 2560.0, "y1": 2110.0, "x0": 70.0, "x1": 1210.0, "lanes": [2505.0, 2355.0, 2205.0]},
	{"act": 2, "y0": 2020.0, "y1": 1500.0, "x0": 190.0, "x1": 1090.0, "lanes": [1965.0, 1815.0, 1665.0]},
	{"act": 3, "y0": 1470.0, "y1": 1000.0, "x0": 320.0, "x1": 960.0, "lanes": [1415.0, 1315.0, 1215.0]},
	{"act": 4, "y0": 970.0, "y1": 330.0, "x0": 430.0, "x1": 850.0, "lanes": [915.0]},
]
## Les silhouettes sont d'autant plus claires qu'elles sont loin.
const BODY := {1: Color(0.02, 0.02, 0.04), 2: Color(0.05, 0.063, 0.125), 3: Color(0.086, 0.114, 0.21), 4: Color(0.137, 0.18, 0.31)}
const GROUND := {1: Color(0.04, 0.04, 0.07), 2: Color(0.08, 0.1, 0.18), 3: Color(0.12, 0.157, 0.26), 4: Color(0.18, 0.227, 0.353)}
const LAMP := Color(1.0, 0.7, 0.28)
const PALE_LAMP := Color(0.95, 0.82, 0.54)
const LABEL_Y := [2062.0, 1540.0, 1062.0, 380.0]

## Le fleuve passe au pied de la ville basse ; le moulin se tient sur sa rive
## sud, et un pont mène à la ville.
const RIVER_TOP := 2562.0
const RIVER_BOTTOM := 2700.0
const BRIDGE_X := 232.0
const MILL_X := 135.0
const MILL_HUB := Vector2(135.0, 2590.0)
const MILL_DOOR := Vector2(152.0, 2706.0)
## La roue à aubes, au flanc du moulin, plongée dans l'anse que l'eau creuse
## dans la rive.
const WHEEL := Vector2(90.0, 2690.0)
const WHEEL_RADIUS := 27.0
## Les niveaux d'un chapitre se répartissent sur sa voie, hors des angles.
const LANE_MARGIN := 0.1

var node_positions := PackedVector2Array()
var route := PackedVector2Array()
## « fait », « ici », « ouvert » ou « ferme », pour chacun des points.
var states := PackedStringArray()
## Pour chaque niveau du chapitre 1 : le niveau est-il construit ?
var ready_flags: Array = []
## L'eau, le pont et les ailes du moulin : ce qui bouge sur la rive.
var river: MapRiver
## Pour chaque voie de la route : son départ et son arrivée.
var lane_segments: Array = []
## Un chapitre est accompli quand ses cinq niveaux sont faits : son cercle
## s'allume sous la ville.
var chapters_done: Array[bool] = []

var _shapes: Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 5
	_build_shapes()
	_build_route()
	river = MapRiver.new()
	add_child(river)
	states.resize(NODE_COUNT)
	states.fill("ferme")


func set_states(new_states: PackedStringArray, ready: Array) -> void:
	states = new_states
	ready_flags = ready
	chapters_done = []
	for c in WorldData.ROUTE_CHAPTERS:
		var done := true
		for i in WorldData.LEVELS_PER_CHAPTER:
			var n := c * WorldData.LEVELS_PER_CHAPTER + i
			if n >= states.size() or states[n] != "fait":
				done = false
		chapters_done.append(done)
	queue_redraw()


# --- Géométrie ----------------------------------------------------------------

func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _add(role: String, points: PackedVector2Array, act: int) -> void:
	_shapes.append({"role": role, "pts": points, "act": act})


func _house(x: float, base: float, w: float, h: float, act: int) -> void:
	# Des maisons irrégulières, avec des vides.
	if _rng.randf() < 0.32:
		return
	x += _rng.randi_range(-14, 14)
	h += _rng.randi_range(-6, 14)
	w += [-6, 0, 0, 10][_rng.randi_range(0, 3)]
	_add("body", _rect(x, base - h, w, h), act)
	_add("body", PackedVector2Array([Vector2(x - 5, base - h), Vector2(x + w + 5, base - h), Vector2(x + w / 2, base - h - 20)]), act)
	_add("lamp", _rect(x + w / 2 - 4, base - 14, 8, 14), act)


func _tower(x: float, base: float, w: float, h: float, act: int) -> void:
	_add("body", _rect(x, base - h, w, h), act)
	for i in 4:
		_add("body", _rect(x + i * w / 4 + 1, base - h - 10, w / 8, 10), act)
	_add("lamp", _rect(x + w / 2 - 4, base - h * 0.6, 8, h * 0.2), act)


func _wall(x1: float, x2: float, base: float, h: float, act: int) -> void:
	_add("body", _rect(x1, base - h, x2 - x1, h), act)
	var x := x1
	while x < x2 - 10.0:
		_add("body", _rect(x + 2, base - h - 9, 10, 9), act)
		x += 24.0


func _build_shapes() -> void:
	# La ville basse
	var t: Dictionary = TERRACES[0]
	_wall(t["x0"], t["x1"], t["y0"], 36.0, 1)
	for ly: float in t["lanes"]:
		var i := 0
		for x in range(130, 1150, 74):
			_house(x, ly - 16.0, 44.0, 28.0 + 8.0 * ((i + int(ly)) % 2), 1)
			i += 1
	_tower(t["x0"] + 6.0, t["y0"], 38.0, 100.0, 1)
	_tower(t["x1"] - 44.0, t["y0"], 38.0, 100.0, 1)
	# La citadelle
	t = TERRACES[1]
	_wall(t["x0"], t["x1"], t["y0"], 40.0, 2)
	for ly: float in t["lanes"]:
		for x in range(260, 1040, 96):
			if absf(x - 640.0) < 120.0 and ly == t["lanes"][2]:
				continue
			_house(x, ly - 16.0, 50.0, 34.0, 2)
	_tower(t["x0"] + 4.0, t["y0"], 46.0, 150.0, 2)
	_tower(t["x1"] - 50.0, t["y0"], 46.0, 150.0, 2)
	_add("body", _rect(550, 1500, 180, 150), 2)
	for i in 6:
		_add("body", _rect(552 + i * 30, 1490, 16, 10), 2)
	_add("lamp", _rect(630, 1545, 20, 40), 2)
	# La cathédrale
	t = TERRACES[2]
	_wall(t["x0"], t["x1"], t["y0"], 36.0, 3)
	var nave := 1250.0
	_add("body", _rect(550, nave - 95, 180, 95), 3)
	for dx in [-60, -20, 20, 60]:
		_add("lamp", _rect(640 + dx - 7, nave - 70, 14, 40), 3)
	_add("body", _rect(612, nave - 185, 56, 90), 3)
	_add("body", PackedVector2Array([Vector2(606, nave - 185), Vector2(674, nave - 185), Vector2(640, nave - 300)]), 3)
	_add("lamp", _rect(638, nave - 330, 4, 30), 3)
	_add("lamp", _rect(628, nave - 320, 24, 4), 3)
	_tower(t["x0"] + 6.0, t["y0"], 40.0, 110.0, 3)
	_tower(t["x1"] - 46.0, t["y0"], 40.0, 110.0, 3)
	for ly: float in t["lanes"]:
		for x in [400, 470, 800, 870]:
			_house(x, ly - 16.0, 44.0, 30.0, 3)
	# Le palais
	t = TERRACES[3]
	_wall(t["x0"], t["x1"], t["y0"], 36.0, 4)
	_add("body", _rect(500, 470, 280, 100), 4)
	for dx in [-100, 0, 100]:
		var cx: float = 640.0 + dx
		_add("body", PackedVector2Array([Vector2(cx - 36, 470), Vector2(cx - 30, 440), Vector2(cx - 14, 420),
			Vector2(cx, 414), Vector2(cx + 14, 420), Vector2(cx + 30, 440), Vector2(cx + 36, 470)]), 4)
		_add("lamp", _rect(cx - 6, 500, 12, 36), 4)
	_add("flag", PackedVector2Array([Vector2(640, 414), Vector2(680, 424), Vector2(640, 434)]), 4)
	_add("body", _rect(639, 390, 2, 24), 4)
	_tower(t["x0"] + 6.0, t["y0"], 40.0, 170.0, 4)
	_tower(t["x1"] - 46.0, t["y0"], 40.0, 170.0, 4)
	for ly: float in t["lanes"]:
		for x in [480, 550, 700, 770]:
			_house(x, ly - 16.0, 40.0, 28.0, 4)


func _build_route() -> void:
	var points: Array[Vector2] = [MILL_DOOR, Vector2(BRIDGE_X, MILL_DOOR.y)]
	lane_segments = []
	var k := 0
	for terrace: Dictionary in TERRACES:
		for ly: float in terrace["lanes"]:
			var a := Vector2(float(terrace["x0"]) + 55.0, ly)
			var b := Vector2(float(terrace["x1"]) - 55.0, ly)
			var from := a if k % 2 == 0 else b
			var to := b if k % 2 == 0 else a
			if k == 0:
				# La première voie commence au pont.
				from = Vector2(BRIDGE_X, ly)
			points.append(from)
			points.append(to)
			lane_segments.append([from, to])
			k += 1
	points.append(Vector2(640.0, 575.0))
	route = PackedVector2Array(points)

	# Un chapitre par voie : cinq niveaux, régulièrement espacés.
	node_positions = PackedVector2Array()
	for n in NODE_COUNT:
		var segment: Array = lane_segments[mini(n / WorldData.LEVELS_PER_CHAPTER, lane_segments.size() - 1)]
		var t := LANE_MARGIN + (1.0 - 2.0 * LANE_MARGIN) * float(n % WorldData.LEVELS_PER_CHAPTER) / float(WorldData.LEVELS_PER_CHAPTER - 1)
		node_positions.append((segment[0] as Vector2).lerp(segment[1], t))


# --- Dessin -------------------------------------------------------------------

func _draw() -> void:
	_draw_river_bed()
	_draw_foundations()

	# Du plus loin au plus proche : chaque étage cache le pied du précédent.
	for act in [4, 3, 2, 1]:
		_draw_terrace(TERRACES[act - 1])
		for shape: Dictionary in _shapes:
			if shape["act"] == act:
				_draw_shape(shape)
	_draw_bridge()
	_draw_mill()

	# La route : un chemin de braises, qui luit.
	draw_polyline(route, Color(LAMP, 0.1), 16.0)
	for i in range(1, route.size()):
		draw_dashed_line(route[i - 1], route[i], Color(Theatre.AMBER, 0.9), 4.0, 7.0)
	_draw_nodes()
	_draw_labels()


func _draw_terrace(terrace: Dictionary) -> void:
	var inset := 22.0
	var polygon := PackedVector2Array([
		Vector2(float(terrace["x0"]) - inset, terrace["y0"]), Vector2(float(terrace["x1"]) + inset, terrace["y0"]),
		Vector2(terrace["x1"], terrace["y1"]), Vector2(terrace["x0"], terrace["y1"])])
	# L'ombre que le papier projette sur ce qui est derrière lui.
	for grow in [20.0, 13.0, 7.0]:
		var grown := Geometry2D.offset_polygon(polygon, grow)
		if not grown.is_empty():
			var shadow := PackedVector2Array()
			for point in grown[0]:
				shadow.append(point + Vector2(0.0, -6.0))
			draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.17))
	draw_colored_polygon(polygon, GROUND[terrace["act"]])


func _draw_shape(shape: Dictionary) -> void:
	var points: PackedVector2Array = shape["pts"]
	match shape["role"]:
		"lamp":
			var act: int = shape["act"]
			var color := LAMP if act < 3 else PALE_LAMP
			var box := Rect2(points[0], points[2] - points[0]).grow(5.0)
			draw_rect(box, Color(color, 0.16))
			draw_colored_polygon(points, color)
		"flag":
			draw_colored_polygon(points, Color(0.77, 0.23, 0.12))
		_:
			draw_colored_polygon(points, BODY[shape["act"]])


## L'eau (sans ses ondes, voir `MapRiver`) et la rive sud, avec ses roseaux.
func _draw_river_bed() -> void:
	var height := RIVER_BOTTOM - RIVER_TOP
	draw_rect(Rect2(0.0, RIVER_TOP, W, height), Color(0.045, 0.07, 0.15))
	draw_rect(Rect2(0.0, RIVER_TOP + height * 0.3, W, height * 0.4), Color(0.06, 0.09, 0.185))
	# La rive sud : de la terre sombre, au bord irrégulier.
	var bank := PackedVector2Array()
	var x := 0.0
	while x <= W + 20.0:
		bank.append(Vector2(x, RIVER_BOTTOM + 3.0 * sin(x * 0.021) + 2.0 * sin(x * 0.067 + 1.0)))
		x += 20.0
	var edge := bank.duplicate()
	bank.append(Vector2(W, H))
	bank.append(Vector2(0.0, H))
	draw_colored_polygon(bank, Color(0.03, 0.034, 0.056))
	draw_polyline(edge, Color(0.2, 0.25, 0.4, 0.5), 1.5)
	# Une anse : l'eau entre dans la rive et baigne le pied du moulin.
	var cove := PackedVector2Array([Vector2(40.0, RIVER_BOTTOM - 2.0), Vector2(132.0, RIVER_BOTTOM - 2.0), Vector2(136.0, 2718.0),
		Vector2(122.0, 2742.0), Vector2(90.0, 2758.0), Vector2(58.0, 2750.0), Vector2(40.0, 2724.0)])
	draw_colored_polygon(cove, Color(0.045, 0.07, 0.15))
	draw_colored_polygon(cove, Color(0.07, 0.1, 0.2, 0.5))
	draw_polyline(PackedVector2Array([cove[0], cove[6], cove[5], cove[4], cove[3], cove[2], cove[1]]), Color(0.2, 0.25, 0.4, 0.5), 1.5)
	# Des roseaux au bord de l'eau.
	var reeds := RandomNumberGenerator.new()
	reeds.seed = 17
	for i in 46:
		var rx := reeds.randf_range(20.0, W - 20.0)
		if absf(rx - BRIDGE_X) < 34.0 or rx < 190.0:
			continue
		var base_y := RIVER_BOTTOM + 3.0
		for blade in 3:
			var lean := reeds.randf_range(-6.0, 6.0)
			draw_line(Vector2(rx + blade * 4.0, base_y), Vector2(rx + blade * 4.0 + lean, base_y - reeds.randf_range(14.0, 30.0)),
				Color(0.012, 0.016, 0.03), 2.0)


## Sous la ville : une plaque sombre, un « ? » et dix cercles, un par chapitre.
## Un cercle s'allume quand son chapitre est accompli ; le « ? » s'allume quand
## les dix le sont.
func _draw_foundations() -> void:
	var plaque := Rect2(430.0, 2800.0, 520.0, 130.0)
	draw_rect(plaque, Color(0.012, 0.012, 0.03))
	draw_rect(plaque, Color(0.2, 0.25, 0.4, 0.4), false, 1.5)
	var all_done := chapters_done.size() == WorldData.ROUTE_CHAPTERS and not chapters_done.has(false)
	draw_string(GameFonts.text(), Vector2(plaque.position.x, plaque.position.y + 98.0), "?", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 100,
		Color(Theatre.AMBER, 0.95) if all_done else Color(Theatre.MUTED, 0.35))
	for i in WorldData.ROUTE_CHAPTERS:
		var at := Vector2(680.0 + 54.0 * (i % 5) + (0.0 if i < 5 else 27.0), 2840.0 + 50.0 * (i / 5))
		if i < chapters_done.size() and chapters_done[i]:
			draw_circle(at, 17.0, Color(Theatre.AMBER, 0.2))
			draw_circle(at, 9.0, Theatre.AMBER)
		else:
			draw_arc(at, 9.0, 0.0, TAU, 20, Color(0.29, 0.27, 0.38, 0.75), 2.0)


## Le pont de bois, du moulin à la ville, avec deux lanternes.
func _draw_bridge() -> void:
	var deck := Color(0.012, 0.012, 0.03)
	var left := BRIDGE_X - 17.0
	var right := BRIDGE_X + 17.0
	draw_rect(Rect2(left, RIVER_TOP - 6.0, 34.0, RIVER_BOTTOM - RIVER_TOP + 12.0), deck)
	draw_line(Vector2(left, RIVER_TOP - 6.0), Vector2(left, RIVER_BOTTOM + 6.0), Color(0.3, 0.34, 0.5, 0.55), 1.5)
	draw_line(Vector2(right, RIVER_TOP - 6.0), Vector2(right, RIVER_BOTTOM + 6.0), Color(0.3, 0.34, 0.5, 0.55), 1.5)
	var y := RIVER_TOP + 6.0
	while y < RIVER_BOTTOM:
		draw_rect(Rect2(left - 3.0, y, 40.0, 3.0), Color(0.025, 0.025, 0.05))
		y += 14.0
	for side: float in [left - 8.0, right + 8.0]:
		draw_rect(Rect2(side - 2.0, RIVER_BOTTOM - 40.0, 4.0, 46.0), deck)
		draw_rect(Rect2(side - 7.0, RIVER_BOTTOM - 52.0, 14.0, 14.0), Color(LAMP, 0.18))
		draw_rect(Rect2(side - 4.0, RIVER_BOTTOM - 49.0, 8.0, 9.0), LAMP)


## Le moulin, sur la rive sud : une tour de pierre, un toit, une fenêtre
## allumée. Ses ailes tournent (voir `MapRiver`).
func _draw_mill() -> void:
	var dark := Color(0.008, 0.008, 0.02)
	var rim := Color(0.28, 0.33, 0.52, 0.55)
	var body := PackedVector2Array([
		Vector2(MILL_X - 33.0, MILL_DOOR.y), Vector2(MILL_X + 33.0, MILL_DOOR.y),
		Vector2(MILL_X + 24.0, MILL_HUB.y + 8.0), Vector2(MILL_X - 24.0, MILL_HUB.y + 8.0)])
	var roof := PackedVector2Array([
		Vector2(MILL_X - 30.0, MILL_HUB.y + 8.0), Vector2(MILL_X + 30.0, MILL_HUB.y + 8.0),
		Vector2(MILL_X, MILL_HUB.y - 40.0)])
	draw_colored_polygon(body, dark)
	draw_colored_polygon(roof, dark)
	draw_polyline(PackedVector2Array([body[0], body[3], roof[0], roof[2], roof[1], body[2], body[1]]), rim, 1.5)
	# La porte, et la fenêtre allumée : le refuge est le seul endroit habité.
	draw_rect(Rect2(MILL_DOOR.x - 9.0, MILL_DOOR.y - 30.0, 18.0, 30.0), Color(0.03, 0.025, 0.04))
	draw_rect(Rect2(MILL_X - 11.0, MILL_DOOR.y - 78.0, 22.0, 30.0), Color(LAMP, 0.16))
	draw_rect(Rect2(MILL_X - 6.0, MILL_DOOR.y - 73.0, 12.0, 20.0), LAMP)
	draw_rect(Rect2(MILL_X - 4.0, MILL_HUB.y + 14.0, 8.0, 12.0), Color(LAMP, 0.85))


func _draw_nodes() -> void:
	for i in NODE_COUNT:
		var p := node_positions[i]
		match states[i]:
			"fait":
				draw_circle(p, 19.0, Color(Theatre.AMBER, 0.2))
				draw_circle(p, 9.0, Theatre.AMBER)
			"ouvert":
				draw_arc(p, 11.0, 0.0, TAU, 24, Theatre.AMBER, 3.0)
				draw_circle(p, 4.0, Color(Theatre.AMBER, 0.6))
			"ici":
				draw_circle(p, 9.0, Theatre.EMBER)
			_:
				draw_circle(p, 7.0, Color(0.29, 0.27, 0.38))
		if i >= 10 and i % 5 == 0:
			draw_string(GameFonts.text(), p + Vector2(-30.0, -24.0), str(i / 5 + 1), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 20, Color(Theatre.MUTED, 0.85))


func _draw_labels() -> void:
	var font := GameFonts.text()
	draw_string(GameFonts.title(), Vector2(0.0, 170.0), "Orvana", HORIZONTAL_ALIGNMENT_CENTER, W, 120, Theatre.AMBER)
	for a in WorldData.ACTS.size():
		var act: Dictionary = WorldData.ACTS[a]
		var y: float = LABEL_Y[a]
		draw_string(font, Vector2(W - 600.0, y), String(act["name"]).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, 400.0, 26, Theatre.MUTED)
		draw_string(font, Vector2(W - 600.0, y + 28.0), act["title"], HORIZONTAL_ALIGNMENT_RIGHT, 400.0, 19, Color(Theatre.MUTED, 0.8))
	draw_string(GameFonts.italic(), Vector2(MILL_X - 110.0, MILL_DOOR.y + 92.0), "le moulin, refuge", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 20, Color(Theatre.MUTED, 0.95))
	# Le titre du chapitre, au départ de sa voie, du côté que n'occupe pas le
	# nom de son premier niveau.
	for c in WorldData.CHAPTERS.size():
		var segment: Array = lane_segments[c]
		var start: Vector2 = segment[0]
		var first_above := (c * WorldData.LEVELS_PER_CHAPTER) % 2 == 1
		_outlined(Vector2(start.x - 150.0, start.y + (50.0 if first_above else -46.0)),
			"Chapitre %s" % WorldData.roman(c + 1), 24, Theatre.EMBER, 300.0)
	var levels := WorldData.chapter_levels()
	for i in levels.size():
		var p := node_positions[i]
		var ready: bool = i < ready_flags.size() and ready_flags[i]
		var name := "%d. %s" % [i + 1, levels[i]["name"]]
		var color := Theatre.CREAM if ready else Color(Theatre.MUTED, 0.85)
		_outlined(Vector2(p.x - 200.0, p.y + (-34.0 if i % 2 == 1 else 50.0)), name, 23, color, 400.0)


func _outlined(at: Vector2, text: String, size: int, color: Color, width: float) -> void:
	var font := GameFonts.text()
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 7, Color(0.0, 0.0, 0.02, 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


## Ce qui bouge sur la rive : l'eau qui coule vers l'est, les lueurs de la
## ville qui tremblent à sa surface, les ailes du moulin. Seule cette couche
## se redessine à chaque image.
class MapRiver extends Control:
	var time := 0.0
	var _streaks: Array[Dictionary] = []
	var _glints: Array[Dictionary] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(MapScene.W, MapScene.H)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 46:
			_streaks.append({
				"y": rng.randf_range(MapScene.RIVER_TOP + 12.0, MapScene.RIVER_BOTTOM - 8.0),
				"x": rng.randf_range(0.0, MapScene.W),
				"speed": rng.randf_range(14.0, 52.0),
				"length": rng.randf_range(14.0, 46.0),
				"alpha": rng.randf_range(0.18, 0.5),
			})
		for i in 20:
			var gx := rng.randf_range(60.0, MapScene.W - 60.0)
			if absf(gx - MapScene.BRIDGE_X) < 40.0:
				gx += 90.0
			_glints.append({
				"x": gx,
				"y": rng.randf_range(MapScene.RIVER_TOP + 8.0, MapScene.RIVER_BOTTOM - 10.0),
				"w": rng.randf_range(8.0, 26.0),
				"phase": rng.randf_range(0.0, TAU),
			})

	func _draw() -> void:
		_draw_waves()
		_draw_streaks()
		_draw_glints()
		_draw_cove()
		_draw_wheel()
		_draw_sails()

	## Dans l'anse, de petites vagues viennent lécher la roue et le pied du moulin.
	func _draw_cove() -> void:
		for i in 3:
			var base := 2712.0 + 13.0 * i
			var points := PackedVector2Array()
			for k in range(0, 9):
				var x := 54.0 + 9.0 * k + 3.0 * i
				points.append(Vector2(x, base + 2.0 * sin((x - time * 30.0) * 0.1 + i)))
			draw_polyline(points, Color(0.3, 0.42, 0.65, 0.45 - 0.1 * i), 2.0)

	## La roue à aubes : le courant la fait tourner, ses pales entrent dans l'eau.
	func _draw_wheel() -> void:
		var centre := MapScene.WHEEL
		var radius := MapScene.WHEEL_RADIUS
		var wood := Color(0.045, 0.03, 0.03)
		var rim := Color(0.45, 0.3, 0.16, 0.7)
		draw_arc(centre, radius, 0.0, TAU, 28, wood, 4.0)
		draw_arc(centre, radius - 9.0, 0.0, TAU, 24, wood, 3.0)
		for spoke in 8:
			var angle := -time * 0.9 + spoke * TAU / 8.0
			var direction := Vector2(cos(angle), sin(angle))
			draw_line(centre, centre + direction * radius, wood, 3.0)
			var tip := centre + direction * radius
			var side := Vector2(-direction.y, direction.x) * 7.0
			draw_colored_polygon(PackedVector2Array([tip - side, tip + side, tip + side + direction * 6.0, tip - side + direction * 6.0]), wood)
		draw_arc(centre, radius, 0.0, TAU, 28, rim, 1.2)
		draw_circle(centre, 4.0, wood)
		# L'écume, là où la roue touche l'eau.
		for k in 4:
			var foam_x := centre.x - 14.0 + 9.0 * k + 3.0 * sin(time * 3.0 + k)
			draw_line(Vector2(foam_x, MapScene.RIVER_BOTTOM + 14.0), Vector2(foam_x + 7.0, MapScene.RIVER_BOTTOM + 14.0),
				Color(0.75, 0.85, 1.0, 0.35 + 0.2 * sin(time * 4.0 + k)), 2.0)

	## Sous le pont, l'eau ne se voit pas.
	func _under_bridge(x: float, margin := 0.0) -> bool:
		return absf(x - MapScene.BRIDGE_X) < 24.0 + margin

	func _draw_waves() -> void:
		for i in 7:
			var base := MapScene.RIVER_TOP + 18.0 + i * 16.0
			var amplitude := 2.5 + 0.6 * i
			var speed := 22.0 + 7.0 * i
			var color := Color(0.2, 0.28, 0.46, 0.55 - 0.04 * i)
			var points := PackedVector2Array()
			var x := -16.0
			while x <= MapScene.W + 16.0:
				if _under_bridge(x):
					_flush(points, color)
					points = PackedVector2Array()
				else:
					var flow := x - time * speed
					points.append(Vector2(x, base + amplitude * sin(flow * 0.028 + i * 1.9) + 1.2 * sin(flow * 0.07 + i)))
				x += 16.0
			_flush(points, color)

	func _flush(points: PackedVector2Array, color: Color) -> void:
		if points.size() > 1:
			draw_polyline(points, color, 2.5)

	func _draw_streaks() -> void:
		var span := MapScene.W + 100.0
		for i in _streaks.size():
			var streak := _streaks[i]
			var x := fposmod(float(streak["x"]) + time * float(streak["speed"]), span) - 50.0
			var length: float = streak["length"]
			if _under_bridge(x + length * 0.5, length * 0.5):
				continue
			var alpha := float(streak["alpha"]) * (0.65 + 0.35 * sin(time * 2.0 + i))
			draw_line(Vector2(x, streak["y"]), Vector2(x + length, streak["y"]), Color(0.55, 0.68, 0.95, alpha), 2.0)

	## Les lanternes de la ville se reflètent en traits qui tremblent.
	func _draw_glints() -> void:
		for glint in _glints:
			var phase: float = glint["phase"]
			var width: float = glint["w"]
			var alpha := 0.2 + 0.16 * sin(time * 2.1 + phase)
			var x := float(glint["x"]) + 3.0 * sin(time * 1.3 + phase)
			draw_rect(Rect2(x - width * 0.5, glint["y"], width, 2.5), Color(MapScene.LAMP, alpha))

	func _draw_sails() -> void:
		var hub := MapScene.MILL_HUB
		var dark := Color(0.008, 0.008, 0.02)
		var rim := Color(0.28, 0.33, 0.52, 0.55)
		for blade in 4:
			var angle := time * 0.45 + blade * PI * 0.5
			var direction := Vector2(cos(angle), sin(angle))
			var tip := hub + direction * 74.0
			var side := Vector2(-direction.y, direction.x) * 15.0
			var start := hub + direction * 20.0
			var quad := PackedVector2Array([start, tip, tip + side, start + side])
			draw_colored_polygon(quad, dark)
			draw_polyline(PackedVector2Array([start, tip, tip + side, start + side, start]), rim, 1.2)
			draw_line(hub, tip, dark, 4.0)
		draw_circle(hub, 6.0, dark)
