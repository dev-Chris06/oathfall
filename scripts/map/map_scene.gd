class_name MapScene
extends Control
## La ville d'Orvana, vue de face, en silhouettes de papier noir : quatre
## étages en gradins, du fleuve au palais, plus clairs à mesure qu'ils
## s'éloignent. Une route en lacets les gravit ; les niveaux y sont des
## braises. Tout est dessiné par code, une fois (le dessin est conservé), sauf
## ce qui bouge : voir `WorldMap`.

const W := 1280.0
const H := 2800.0
const NODE_COUNT := 50

## Chaque étage : son rang, sa base et son sommet, ses bords, et les voies de
## la route qui le traversent.
const TERRACES := [
	{"act": 1, "y0": 2380.0, "y1": 1990.0, "x0": 70.0, "x1": 1210.0, "lanes": [2325.0, 2205.0, 2085.0]},
	{"act": 2, "y0": 1960.0, "y1": 1500.0, "x0": 190.0, "x1": 1090.0, "lanes": [1905.0, 1785.0, 1665.0]},
	{"act": 3, "y0": 1470.0, "y1": 1000.0, "x0": 320.0, "x1": 960.0, "lanes": [1415.0, 1315.0]},
	{"act": 4, "y0": 970.0, "y1": 330.0, "x0": 430.0, "x1": 850.0, "lanes": [915.0, 815.0, 715.0]},
]
## Les silhouettes sont d'autant plus claires qu'elles sont loin.
const BODY := {1: Color(0.02, 0.02, 0.04), 2: Color(0.05, 0.063, 0.125), 3: Color(0.086, 0.114, 0.21), 4: Color(0.137, 0.18, 0.31)}
const GROUND := {1: Color(0.04, 0.04, 0.07), 2: Color(0.08, 0.1, 0.18), 3: Color(0.12, 0.157, 0.26), 4: Color(0.18, 0.227, 0.353)}
const LAMP := Color(1.0, 0.7, 0.28)
const PALE_LAMP := Color(0.95, 0.82, 0.54)
const LABEL_Y := [2050.0, 1540.0, 1062.0, 380.0]

var node_positions := PackedVector2Array()
var route := PackedVector2Array()
## « fait », « ici », « ouvert » ou « ferme », pour chacun des points.
var states := PackedStringArray()
## Pour chaque niveau du chapitre 1 : le niveau est-il construit ?
var ready_flags: Array = []

var _shapes: Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 5
	_build_shapes()
	_build_route()
	states.resize(NODE_COUNT)
	states.fill("ferme")


func set_states(new_states: PackedStringArray, ready: Array) -> void:
	states = new_states
	ready_flags = ready
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
	var points: Array[Vector2] = [Vector2(200.0, 2405.0)]
	var k := 0
	for terrace: Dictionary in TERRACES:
		for ly: float in terrace["lanes"]:
			var a := Vector2(float(terrace["x0"]) + 55.0, ly)
			var b := Vector2(float(terrace["x1"]) - 55.0, ly)
			if k % 2 == 0:
				points.append(a)
				points.append(b)
			else:
				points.append(b)
				points.append(a)
			k += 1
	points.append(Vector2(640.0, 575.0))
	route = PackedVector2Array(points)

	var cumulative: Array[float] = [0.0]
	for i in range(1, route.size()):
		cumulative.append(cumulative[i - 1] + route[i].distance_to(route[i - 1]))
	var total: float = cumulative[cumulative.size() - 1]
	node_positions = PackedVector2Array()
	for n in NODE_COUNT:
		var wanted := total * (0.025 + 0.95 * float(n) / float(NODE_COUNT - 1))
		for j in range(1, cumulative.size()):
			if cumulative[j] >= wanted:
				var t := (wanted - cumulative[j - 1]) / (cumulative[j] - cumulative[j - 1] + 0.0001)
				node_positions.append(route[j - 1].lerp(route[j], t))
				break


# --- Dessin -------------------------------------------------------------------

func _draw() -> void:
	# Fondations : une zone sombre sous le fleuve.
	draw_rect(Rect2(60.0, 2480.0, 1160.0, 250.0), Color(0.016, 0.016, 0.04))
	draw_string(GameFonts.text(), Vector2(0.0, 2640.0), "?", HORIZONTAL_ALIGNMENT_CENTER, W, 110, Color(Theatre.MUTED, 0.3))
	for i in 10:
		var c := Vector2(450.0 + 70.0 * (i % 5) + (0.0 if i < 5 else 35.0), 2680.0 + 0.0 * i + 55.0 * (i / 5) - 55.0)
		draw_arc(c, 8.0, 0.0, TAU, 20, Color(0.29, 0.27, 0.38, 0.6), 2.0)
	# Le fleuve
	for i in 4:
		var line := PackedVector2Array()
		for k in 54:
			line.append(Vector2(40.0 + k * 22.0, 2402.0 + 18.0 * i + 4.0 * sin(k * 0.8 + i)))
		draw_polyline(line, Color(0.15, 0.2, 0.35), 3.0)

	# Du plus loin au plus proche : chaque étage cache le pied du précédent.
	for act in [4, 3, 2, 1]:
		_draw_terrace(TERRACES[act - 1])
		for shape: Dictionary in _shapes:
			if shape["act"] == act:
				_draw_shape(shape)
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


func _draw_mill() -> void:
	var dark: Color = BODY[1]
	draw_colored_polygon(PackedVector2Array([Vector2(174, 2400), Vector2(226, 2400), Vector2(214, 2310), Vector2(186, 2310)]), dark)
	# Une fenêtre allumée : le refuge est le seul endroit habité.
	draw_rect(Rect2(189.0, 2340.0, 22.0, 30.0), Color(LAMP, 0.16))
	draw_rect(Rect2(194.0, 2345.0, 12.0, 20.0), LAMP)
	var hub := Vector2(200.0, 2310.0)
	for a in 4:
		var angle := deg_to_rad(25.0 + a * 90.0)
		var tip := hub + Vector2(cos(angle), sin(angle)) * 78.0
		var side := Vector2(-sin(angle), cos(angle)) * 15.0
		var start := hub.lerp(tip, 0.3)
		draw_colored_polygon(PackedVector2Array([start, tip, tip + side, start + side]), dark)
		draw_line(hub, tip, dark, 4.0)


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
		if i >= 5 and i % 5 == 0:
			draw_string(GameFonts.text(), p + Vector2(-30.0, -24.0), str(i / 5 + 1), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 20, Color(Theatre.MUTED, 0.85))


func _draw_labels() -> void:
	var font := GameFonts.text()
	draw_string(GameFonts.title(), Vector2(0.0, 170.0), "Orvana", HORIZONTAL_ALIGNMENT_CENTER, W, 120, Theatre.AMBER)
	for a in WorldData.ACTS.size():
		var act: Dictionary = WorldData.ACTS[a]
		var y: float = LABEL_Y[a]
		draw_string(font, Vector2(W - 600.0, y), String(act["name"]).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, 400.0, 26, Theatre.MUTED)
		draw_string(font, Vector2(W - 600.0, y + 28.0), act["title"], HORIZONTAL_ALIGNMENT_RIGHT, 400.0, 19, Color(Theatre.MUTED, 0.8))
	draw_string(GameFonts.italic(), Vector2(60.0, 2440.0), "le moulin, refuge", HORIZONTAL_ALIGNMENT_LEFT, 300.0, 20, Color(Theatre.MUTED, 0.9))
	var p0 := node_positions[0]
	_outlined(Vector2(p0.x - 190.0, p0.y - 46.0), "Chapitre %s" % WorldData.roman(1), 24, Theatre.EMBER, 300.0)
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
