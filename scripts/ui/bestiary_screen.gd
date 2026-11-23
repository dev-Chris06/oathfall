class_name BestiaryScreen
extends CanvasLayer
## Le bestiaire de Tibert : un portrait par type de mort, ce qu'il fait, et
## comment s'y prendre. Un mort qu'on n'a pas rencontré reste une silhouette.
## Le jeu est en pause tant qu'il est ouvert.

signal closed

## Les types, dans l'ordre où on les rencontre.
## Tout type déclaré dans `EnemyTypes` doit y figurer (le test le vérifie) : un
## mort rencontré s'affiche, un mort inconnu reste une silhouette.
const ORDER: Array[StringName] = [&"depouille", &"archer_creux", &"porte_cloche", &"fouisseur", &"veuve", &"sonneur", &"fossoyeuse",
	&"boucher", &"crieur", &"peseur", &"prevot", &"noye", &"gaffeur"]
const PORTRAITS := "res://assets/ui/portraits/"

var selected: StringName = &"depouille"

var _page: CutPage
var _portrait: TextureRect
var _name: Label
var _kind: Label
var _text: Label
var _tip: Label
var _count: Label
var _buttons := {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.17, 0.21, 0.35, 0.93))
	gradient.set_color(1, Color(0.03, 0.035, 0.07, 0.96))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.0, 1.0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_page = CutPage.new(11)
	_page.custom_minimum_size = Vector2(1180.0, 640.0)
	center.add_child(_page)
	_build()
	for id in ORDER:
		if Progress.has_met(id):
			selected = id
			break
	select(selected)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = false
	closed.emit()
	queue_free()


## Le nom affiché sur la fiche (« ??? » pour un mort inconnu).
func shown_name() -> String:
	return _name.text


func is_known(id: StringName) -> bool:
	return Progress.has_met(id)


func known_count() -> int:
	var count := 0
	for id in ORDER:
		if is_known(id):
			count += 1
	return count


func _build() -> void:
	var column := _page.column
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	head.add_child(Theatre.label("Bestiaire", 54, Theatre.AMBER, GameFonts.title()))
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_child(Theatre.label("Ce que Tibert a noté sur les morts que tu as croisés.", 20, Theatre.MUTED, GameFonts.italic()))
	head.add_child(side)
	column.add_child(head)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color(Theatre.AMBER, 0.5)
	column.add_child(rule)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 36)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	# À gauche : un portrait cliquable par type.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for id in ORDER:
		var button := Button.new()
		button.custom_minimum_size = Vector2(118.0, 118.0)
		button.expand_icon = true
		button.icon = _portrait_texture(id)
		button.add_theme_stylebox_override("normal", _cell(false))
		button.add_theme_stylebox_override("hover", _cell(true))
		button.add_theme_stylebox_override("pressed", _cell(true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(select.bind(id))
		grid.add_child(button)
		_buttons[id] = button
		# Un mort inconnu n'est qu'une silhouette.
		button.modulate = Color.WHITE if is_known(id) else Color(0.0, 0.0, 0.0, 0.85)

	# À droite : la fiche.
	var sheet := VBoxContainer.new()
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.custom_minimum_size = Vector2(640.0, 0.0)
	sheet.add_theme_constant_override("separation", 8)
	body.add_child(sheet)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	sheet.add_child(top)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(250.0, 250.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(_portrait)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(titles)
	_name = Theatre.label("", 38, Theatre.CREAM)
	titles.add_child(_name)
	_kind = Theatre.label("", 19, Theatre.MUTED, GameFonts.italic())
	titles.add_child(_kind)
	_count = Theatre.label("", 21, Theatre.AMBER)
	titles.add_child(_count)
	_text = Theatre.label("", 23)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(_text)
	_tip = Theatre.label("", 21, Theatre.EMBER)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(_tip)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(filler)
	var back := Button.new()
	back.text = "Refermer"
	Theatre.pill(back, 20)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close)
	column.add_child(back)


## Affiche la fiche d'un type.
func select(id: StringName) -> void:
	selected = id
	var data := EnemyTypes.get_type(id)
	_portrait.texture = _portrait_texture(id)
	_portrait.modulate = Color.WHITE if is_known(id) else Color(0.0, 0.0, 0.0, 0.85)
	for key: StringName in _buttons:
		(_buttons[key] as Button).add_theme_stylebox_override("normal", _cell(key == id))
	if not is_known(id):
		_name.text = "???"
		_kind.text = ""
		_count.text = ""
		_text.text = "Tu n'as pas encore croisé ce mort."
		_tip.text = ""
		return
	_name.text = data["name"]
	_kind.text = "Boss" if data.get("boss", false) else "Mort du chapitre"
	var rested := Progress.rest_count(id)
	_count.text = "Mis au repos : %d" % rested
	var sheet: Dictionary = data.get("bestiary", {})
	_text.text = sheet.get("text", "")
	_tip.text = "Comment s'y prendre : %s" % sheet.get("tip", "")


func _portrait_texture(id: StringName) -> Texture2D:
	var path := PORTRAITS + "%s.png" % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _cell(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Theatre.DEEP, 0.9)
	box.border_color = Color(Theatre.AMBER, 0.95 if active else 0.35)
	box.set_border_width_all(3 if active else 2)
	box.set_corner_radius_all(4)
	return box
