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

	_info = _make_label(18, Color(0.85, 0.9, 1.0))
	_info.position = Vector2(24.0, 64.0)

	_debug = _make_label(13, Color(1.0, 1.0, 1.0, 0.5))
	_debug.position = Vector2(24.0, 92.0)

	_message = _make_label(34, Color(1.0, 0.93, 0.78))
	# Toute la largeur de l'écran : le texte se centre quelle que soit sa longueur.
	_message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_message.offset_top = 110.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	_build_boss_bar()


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
