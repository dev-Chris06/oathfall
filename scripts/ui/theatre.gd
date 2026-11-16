class_name Theatre
extends RefCounted
## Le style « théâtre d'ombres » : silhouettes de papier noir sur une nuit
## bleue, braises et or pâle pour tout ce qui brille. Palette et gestes
## communs de la carte, du carnet et des menus.

const NIGHT := Color(0.043, 0.051, 0.094)
const DEEP := Color(0.02, 0.02, 0.04)
const CREAM := Color(0.89, 0.85, 0.71)
const MUTED := Color(0.6, 0.56, 0.69)
const AMBER := Color(0.91, 0.69, 0.38)
const EMBER := Color(1.0, 0.54, 0.35)
const BLOOD := Color(0.48, 0.12, 0.07)


static func label(text: String, size: int, color := CREAM, font: Font = null) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font if font != null else GameFonts.text())
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Un cadre sombre, au liseré d'or pâle.
static func panel_box(alpha := 0.92) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(NIGHT, alpha)
	box.border_color = Color(AMBER, 0.55)
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	box.shadow_size = 10
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	return box


## Un bouton réduit à un liseré, comme découpé dans le papier.
static func pill(button: Button, font_size := 19, accent := AMBER) -> void:
	_style_button(button, font_size)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_focus_color", accent)
	button.add_theme_stylebox_override("normal", _box(accent, 0.0))
	button.add_theme_stylebox_override("hover", _box(accent, 0.14))
	button.add_theme_stylebox_override("pressed", _box(accent, 0.3))
	button.add_theme_stylebox_override("disabled", _box(MUTED, 0.0, 0.35))


## Le bouton qui engage : rouge sombre, liseré d'or.
static func primary(button: Button, font_size := 24) -> void:
	_style_button(button, font_size)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_focus_color", CREAM)
	for state in ["normal", "hover", "pressed"]:
		var box := _box(AMBER, 0.0)
		box.bg_color = BLOOD.lightened(0.0 if state == "normal" else (0.12 if state == "hover" else 0.25))
		box.content_margin_left = 30.0
		box.content_margin_right = 30.0
		button.add_theme_stylebox_override(state, box)


static func _style_button(button: Button, font_size: int) -> void:
	if not button.has_meta(&"clic"):
		button.set_meta(&"clic", true)
		button.pressed.connect(func() -> void: Audio.play(&"ui_click"))
	button.add_theme_font_override("font", GameFonts.text())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.45))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _box(border: Color, tint: float, border_alpha := 0.9) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(border, tint) if tint > 0.0 else Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = Color(border, border_alpha)
	box.set_border_width_all(2)
	box.set_corner_radius_all(22)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 9.0
	box.content_margin_bottom = 9.0
	return box
