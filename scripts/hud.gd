class_name Hud
extends CanvasLayer
## Affichage en jeu : vie du héros, compte des morts, messages.

const BAR_SIZE := Vector2(300.0, 18.0)

var _health_fill: ColorRect
var _memory_fill: ColorRect
var _level_label: Label
var _info: Label
var _message: Label
var _debug: Label
var _message_time := 0.0
var _flash: ColorRect
var _boss_box: Control
var _boss_fill: ColorRect
var _boss_label: Label
var _guide: Polygon2D
var _balance: BalanceMeter
var _embers: EmberGauge
var _victory: Control


func _ready() -> void:
	layer = 5

	# Voile rouge bref quand le héros est touché.
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.6, 0.0, 0.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	var back := ColorRect.new()
	back.position = Vector2(22.0, 20.0)
	back.size = BAR_SIZE + Vector2(6.0, 6.0)
	back.color = Color(0.0, 0.0, 0.0, 0.6)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	_health_fill = ColorRect.new()
	_health_fill.position = Vector2(25.0, 23.0)
	_health_fill.size = BAR_SIZE
	_health_fill.color = Color(0.62, 0.08, 0.08)
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_fill)

	# Sous la vie, la jauge des souvenirs : elle mène au niveau suivant.
	var memory_back := ColorRect.new()
	memory_back.position = Vector2(22.0, 48.0)
	memory_back.size = Vector2(BAR_SIZE.x + 6.0, 9.0)
	memory_back.color = Color(0.0, 0.0, 0.0, 0.6)
	memory_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(memory_back)

	_memory_fill = ColorRect.new()
	_memory_fill.position = Vector2(25.0, 50.0)
	_memory_fill.size = Vector2(0.0, 5.0)
	_memory_fill.color = Color(0.62, 0.78, 1.0)
	_memory_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_memory_fill)

	_level_label = _make_label(18, Color(1.0, 0.93, 0.78))
	_level_label.position = Vector2(BAR_SIZE.x + 40.0, 18.0)

	# Sous les souvenirs, les braises des rites de combat.
	_embers = EmberGauge.new()
	_embers.position = Vector2(25.0, 64.0)
	add_child(_embers)

	_info = _make_label(18, Color(0.85, 0.9, 1.0))
	_info.position = Vector2(24.0, 86.0)

	_debug = _make_label(13, Color(1.0, 1.0, 1.0, 0.5))
	_debug.position = Vector2(24.0, 112.0)

	_message = _make_label(34, Color(1.0, 0.93, 0.78))
	# Toute la largeur de l'écran : le texte se centre quelle que soit sa longueur.
	_message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_message.offset_top = 110.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	_build_boss_bar()
	_build_guide()
	_balance = BalanceMeter.new()
	_balance.visible = false
	add_child(_balance)


## Le bandeau de victoire, au centre de l'écran : « Victoire », le nom du
## niveau, une phrase, et ce que le niveau a rapporté.
func show_victory(level_title: String, line: String, gains: String) -> void:
	if _victory != null:
		_victory.queue_free()
	hide_boss_bar_only()
	_message.modulate.a = 0.0
	_message_time = 0.0
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Theatre.panel_box(0.9))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(520.0, 0.0)
	panel.add_child(column)
	for entry: Array in [["Victoire", 64, Theatre.AMBER, GameFonts.title()],
			[level_title, 28, Theatre.CREAM, GameFonts.text()],
			[line, 23, Theatre.CREAM, GameFonts.italic()],
			[gains, 21, Theatre.MUTED, GameFonts.text()]]:
		if String(entry[0]) == "":
			continue
		var label := Theatre.label(entry[0], entry[1], entry[2], entry[3])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	_victory = centre
	centre.modulate.a = 0.0
	add_child(centre)
	create_tween().tween_property(centre, "modulate:a", 1.0, 0.5)


func victory_shown() -> bool:
	return _victory != null


## Cache la barre du boss sans changer la musique (la victoire a la sienne).
func hide_boss_bar_only() -> void:
	_boss_box.visible = false


func set_embers(count: int) -> void:
	_embers.count = count
	_embers.queue_redraw()


func embers_shown() -> int:
	return _embers.count


## Les braises : cinq losanges, allumés un par Repos donné.
class EmberGauge extends Control:
	var count := 0

	func _init() -> void:
		custom_minimum_size = Vector2(130.0, 18.0)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for k in RiteData.MAX_EMBERS:
			var at := Vector2(9.0 + 22.0 * k, 9.0)
			var points := PackedVector2Array([at + Vector2(0.0, -8.0), at + Vector2(8.0, 0.0), at + Vector2(0.0, 8.0), at + Vector2(-8.0, 0.0)])
			if k < count:
				draw_circle(at, 11.0, Color(1.0, 0.54, 0.35, 0.25))
				draw_colored_polygon(points, Color(1.0, 0.54, 0.35))
			else:
				draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.55))
				draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(1.0, 0.54, 0.35, 0.6), 1.5, true)


## L'indicateur de la balance du Peseur : le fléau penche du côté des morts
## debout (à gauche) ou des corps (à droite).
func set_balance(standing: int, bodies: int) -> void:
	_balance.set_counts(standing, bodies)


func hide_balance() -> void:
	_balance.visible = false


## La flèche d'or qui montre l'objectif quand il est hors de l'écran.
func _build_guide() -> void:
	_guide = Polygon2D.new()
	_guide.polygon = PackedVector2Array([Vector2(0.0, -26.0), Vector2(22.0, 16.0), Vector2(0.0, 6.0), Vector2(-22.0, 16.0)])
	_guide.color = Color(0.95, 0.72, 0.32, 0.9)
	_guide.visible = false
	add_child(_guide)


## Montre la flèche à `at` (coordonnées d'écran), tournée de `angle`.
func set_guide(shown: bool, at: Vector2, angle: float) -> void:
	_guide.visible = shown
	if shown:
		_guide.position = at
		_guide.rotation = angle


## La barre du boss, en haut au centre : nom, puis vie.
func _build_boss_bar() -> void:
	_boss_box = Control.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	add_child(_boss_box)
	var width := 520.0
	var back := ColorRect.new()
	back.set_anchors_preset(Control.PRESET_CENTER_TOP)
	back.offset_left = -width / 2.0 - 3.0
	back.offset_right = width / 2.0 + 3.0
	back.offset_top = 46.0
	back.offset_bottom = 68.0
	back.color = Color(0.0, 0.0, 0.0, 0.7)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(back)
	_boss_fill = ColorRect.new()
	_boss_fill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_fill.offset_left = -width / 2.0
	_boss_fill.offset_right = width / 2.0
	_boss_fill.offset_top = 49.0
	_boss_fill.offset_bottom = 65.0
	_boss_fill.color = Color(0.55, 0.28, 0.1)
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(_boss_fill)
	_boss_label = _make_label(24, Color(0.95, 0.85, 0.65))
	_boss_label.reparent(_boss_box)
	_boss_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_label.offset_top = 14.0
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Cache le compte des morts : au refuge, il n'y en a pas.
func hide_counts() -> void:
	_info.visible = false


func show_boss(boss_name: String, health: int, max_health: int) -> void:
	_boss_label.text = boss_name
	_boss_box.visible = true
	Audio.music(&"boss")
	set_boss(health, max_health)


func set_boss(health: int, max_health: int) -> void:
	var ratio := clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
	_boss_fill.offset_right = -260.0 + 520.0 * ratio


func hide_boss() -> void:
	_boss_box.visible = false
	Audio.music(Audio.level_track)


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time / 0.6, 0.0, 1.0)
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.2)


func set_health(health: int, max_health: int) -> void:
	_health_fill.size.x = BAR_SIZE.x * float(health) / float(maxi(max_health, 1))


func flash_damage() -> void:
	_flash.color.a = 0.32


## `standing` : morts debout. `down` : corps au sol, qui vont se relever.
func set_counts(standing: int, down: int) -> void:
	_info.text = "Debout : %d    Au sol : %d" % [standing, down]


## Niveau du héros, part de la jauge des souvenirs remplie, or porté.
func set_progress(level: int, progress: float, gold: int) -> void:
	_memory_fill.size.x = BAR_SIZE.x * progress
	_level_label.text = "Niv. %d    Or : %d" % [level, gold]


func set_debug(text: String) -> void:
	_debug.text = text


func show_message(text: String, seconds: float) -> void:
	_message.text = text
	_message_time = seconds
	_message.modulate.a = 1.0


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", GameFonts.text())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## Une petite balance, sous la barre du boss : un fléau, deux plateaux, deux
## chiffres. Elle penche en direct et s'écrit « équilibre » quand elle est droite.
class BalanceMeter extends Control:
	var standing := 0
	var bodies := 0
	var _tilt := 0.0
	var _left: Label
	var _right: Label
	var _caption: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		offset_left = -170.0
		offset_right = 170.0
		offset_top = 74.0
		offset_bottom = 190.0
		_left = Theatre.label("", 20, Theatre.CREAM)
		_left.position = Vector2(8.0, 78.0)
		add_child(_left)
		_right = Theatre.label("", 20, Theatre.CREAM)
		_right.position = Vector2(206.0, 78.0)
		add_child(_right)
		_caption = Theatre.label("", 20, Theatre.AMBER)
		_caption.position = Vector2(112.0, 82.0)
		add_child(_caption)

	func set_counts(new_standing: int, new_bodies: int) -> void:
		standing = new_standing
		bodies = new_bodies
		visible = true
		_left.text = "Debout %d" % standing
		_right.text = "Au sol %d" % bodies
		var even := absi(standing - bodies) < 2
		_caption.text = "ÉQUILIBRE" if even else ""
		_caption.position.x = 170.0 - _caption.get_minimum_size().x / 2.0

	func _process(delta: float) -> void:
		var target := clampf(float(standing - bodies) * 0.12, -0.42, 0.42)
		_tilt = lerpf(_tilt, target, minf(1.0, delta * 4.0))
		if visible:
			queue_redraw()

	func _draw() -> void:
		var centre := Vector2(170.0, 22.0)
		var gold := Color(Theatre.AMBER, 0.95)
		draw_colored_polygon(PackedVector2Array([centre + Vector2(0.0, -4.0), centre + Vector2(12.0, 48.0), centre + Vector2(-12.0, 48.0)]), Color(0.3, 0.22, 0.12, 0.95))
		var left_end := centre + Vector2(-cos(_tilt), sin(_tilt)) * 110.0
		var right_end := centre + Vector2(cos(_tilt), -sin(_tilt)) * 110.0
		draw_line(left_end, right_end, gold, 5.0)
		for end in [left_end, right_end]:
			var pan := (end as Vector2) + Vector2(0.0, 30.0)
			draw_line(end, pan, Color(gold, 0.7), 2.0)
			var dish := PackedVector2Array()
			for k in 14:
				var angle := TAU * k / 14.0
				dish.append(pan + Vector2(cos(angle) * 34.0, sin(angle) * 6.0))
			draw_colored_polygon(dish, Color(0.55, 0.4, 0.18, 0.95))
			draw_polyline(dish + PackedVector2Array([dish[0]]), gold, 1.5)
		draw_circle(centre, 6.0, gold)
