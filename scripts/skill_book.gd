class_name SkillBook
extends CanvasLayer
## Le carnet du soldat : niveau, souvenirs, or, et les compétences à
## apprendre avec les points gagnés. Le jeu est en pause tant qu'il est ouvert.
##
## Au refuge, c'est Frère Anselme qui enseignera les compétences ; ce carnet
## permet de les apprendre en attendant, et restera pour les consulter.

signal closed

const INK := Color(0.92, 0.88, 0.78)
const FADED := Color(0.62, 0.6, 0.55)
const ACCENT := Color(0.62, 0.78, 1.0)

var _status: Label
var _rows: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.02, 0.78)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860.0, 0.0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.06, 0.06, 0.08, 0.96), Color(0.35, 0.32, 0.26)))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	column.add_child(_label("CARNET DU SOLDAT", 30, INK))
	_status = _label("", 19, ACCENT)
	column.add_child(_status)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	column.add_child(_rows)

	var close := _button("Reprendre")
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(close_book)
	column.add_child(close)

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_ESCAPE or key == KEY_C or key == KEY_TAB:
			get_viewport().set_input_as_handled()
			close_book()


func close_book() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()


## Apprend une compétence, comme si le joueur avait touché son bouton.
func learn(skill_id: StringName) -> bool:
	var learned := Progress.learn(skill_id)
	_refresh()
	return learned


func _refresh() -> void:
	var next := Progression.threshold(Progress.hero_level + 1)
	_status.text = "Niveau %d    Souvenirs : %d / %d    Or : %d    Points à dépenser : %d" % [
		Progress.hero_level, Progress.memories, next, Progress.gold, Progress.skill_points]

	for child in _rows.get_children():
		child.queue_free()
	for skill: Dictionary in Progression.skills_for(Progress.class_id):
		_rows.add_child(_skill_row(skill))


func _skill_row(skill: Dictionary) -> Control:
	var skill_id: StringName = skill["id"]
	var rank := Progress.rank_of(skill_id)
	var rank_list: Array = skill["ranks"]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)

	text.add_child(_label("%s   rang %d/%d" % [skill["name"], rank, rank_list.size()], 22, INK))
	var detail: String = skill["text"]
	if rank > 0:
		detail += "  Acquis : %s." % rank_list[rank - 1]["text"]
	text.add_child(_label(detail, 16, FADED))

	var next := Progress.next_rank(skill_id)
	var button: Button
	if next.is_empty():
		button = _button("Maîtrisé")
		button.disabled = true
	else:
		var cost := int(next["cost"])
		button = _button("%s — %d pt%s" % [next["text"], cost, "s" if cost > 1 else ""])
		button.disabled = not Progress.can_learn(skill_id)
		button.pressed.connect(learn.bind(skill_id))
	button.custom_minimum_size = Vector2(300.0, 58.0)
	row.add_child(button)
	return row


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220.0, 58.0)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.44, 0.42))
	button.add_theme_stylebox_override("normal", _box(Color(0.14, 0.13, 0.12), Color(0.45, 0.4, 0.3)))
	button.add_theme_stylebox_override("hover", _box(Color(0.2, 0.18, 0.15), Color(0.6, 0.52, 0.38)))
	button.add_theme_stylebox_override("pressed", _box(Color(0.25, 0.3, 0.38), ACCENT))
	button.add_theme_stylebox_override("disabled", _box(Color(0.08, 0.08, 0.08), Color(0.2, 0.2, 0.2)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box
