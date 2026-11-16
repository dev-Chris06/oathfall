class_name SkillBook
extends CanvasLayer
## Le carnet du soldat, ouvert sur deux pages : à gauche ce qu'il est
## devenu (niveau, souvenirs, oboles), à droite les rites qu'il peut
## apprendre avec ses points. Le jeu est en pause tant qu'il est ouvert.
##
## Au refuge, c'est Frère Anselme qui enseignera les compétences ; ce carnet
## permet de les apprendre en attendant, et restera pour les consulter.

signal closed

const PARCHMENT := preload("res://scripts/ui/parchment.gdshader")
const BOOK_SIZE := Vector2(1140.0, 640.0)
const LEATHER := Color(0.17, 0.09, 0.06)

var _left: VBoxContainer
var _right: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	# Toucher hors du carnet le referme.
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close_book())
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# La couverture de cuir, un peu plus grande que les pages.
	var cover := Panel.new()
	cover.custom_minimum_size = BOOK_SIZE
	var leather := StyleBoxFlat.new()
	leather.bg_color = LEATHER
	leather.border_color = Color(0.08, 0.04, 0.03)
	leather.set_border_width_all(4)
	leather.set_corner_radius_all(10)
	leather.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	leather.shadow_size = 18
	cover.add_theme_stylebox_override("panel", leather)
	center.add_child(cover)

	var page_size := Vector2((BOOK_SIZE.x - 36.0) / 2.0, BOOK_SIZE.y - 32.0)
	_left = _page(cover, Vector2(16.0, 16.0), page_size, -1.0)
	_right = _page(cover, Vector2(16.0 + page_size.x + 4.0, 16.0), page_size, 1.0)

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_ESCAPE or key == KEY_C or key == KEY_TAB:
			get_viewport().set_input_as_handled()
			close_book()


func close_book() -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = false
	closed.emit()
	queue_free()


## Apprend une compétence, comme si le joueur avait touché son entrée.
func learn(skill_id: StringName) -> bool:
	var learned := Progress.learn(skill_id)
	_refresh()
	return learned


func _refresh() -> void:
	for page in [_left, _right]:
		for child in page.get_children():
			page.remove_child(child)
			child.queue_free()
	_fill_left()
	_fill_right()


# --- Page de gauche : le soldat -----------------------------------------------

func _fill_left() -> void:
	var data := HeroClasses.get_class_data(Progress.class_id)
	_left.add_child(_write("Carnet", GameFonts.title(), 58, GameFonts.RUBRIC))
	_left.add_child(_write("%s de la dernière légion d'Orvana" % data["name"],
		GameFonts.italic(), 20, GameFonts.FADED_INK))
	_left.add_child(_rule())

	_left.add_child(_write("Niveau %d" % Progress.hero_level, GameFonts.text(), 34, GameFonts.INK))
	var next := Progression.threshold(Progress.hero_level + 1)
	_left.add_child(_write("Souvenirs : %d sur %d" % [Progress.memories, next],
		GameFonts.text(), 22, GameFonts.INK))
	_left.add_child(_ink_gauge(Progress.level_progress()))
	_left.add_child(_write("Oboles : %d" % Progress.gold, GameFonts.text(), 22, GameFonts.INK))
	var points := Progress.skill_points
	var points_text := "Aucun point à dépenser." if points == 0 \
		else "%d point%s à dépenser." % [points, "s" if points > 1 else ""]
	_left.add_child(_write(points_text, GameFonts.text(), 22,
		GameFonts.RUBRIC if points > 0 else GameFonts.FADED_INK))

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(filler)

	var note := _write("Chaque corps mis au repos me rend un peu\nde ce qu'il portait.",
		GameFonts.italic(), 19, GameFonts.FADED_INK)
	_left.add_child(note)
	var close := _ink_button("Refermer le carnet", 22, GameFonts.INK)
	close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(close_book)
	_left.add_child(close)


# --- Page de droite : les rites -----------------------------------------------

func _fill_right() -> void:
	_right.add_child(_write("Rites", GameFonts.title(), 46, GameFonts.RUBRIC))
	for skill: Dictionary in Progression.skills_for(Progress.class_id):
		_right.add_child(_skill_entry(skill))


func _skill_entry(skill: Dictionary) -> Control:
	var skill_id: StringName = skill["id"]
	var rank := Progress.rank_of(skill_id)
	var rank_list: Array = skill["ranks"]

	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 0)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_line := "%s   %s" % [skill["name"], "I".repeat(rank) if rank > 0 else "—"]
	entry.add_child(_write(name_line, GameFonts.text(), 25, GameFonts.INK))
	var detail: String = skill["text"]
	if rank > 0:
		detail += " Acquis : %s." % _lower_first(rank_list[rank - 1]["text"])
	entry.add_child(_write(detail, GameFonts.italic(), 18, GameFonts.FADED_INK))

	var next := Progress.next_rank(skill_id)
	if next.is_empty():
		entry.add_child(_write("Maîtrisé.", GameFonts.italic(), 18, GameFonts.FADED_INK))
	else:
		var cost := int(next["cost"])
		var label := "Apprendre : %s, %d point%s" % [
			_lower_first(next["text"]), cost, "s" if cost > 1 else ""]
		var button := _ink_button(label, 19, GameFonts.RUBRIC)
		button.disabled = not Progress.can_learn(skill_id)
		button.pressed.connect(learn.bind(skill_id))
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		entry.add_child(button)
	return entry


func _lower_first(text: String) -> String:
	return text.left(1).to_lower() + text.substr(1)


# --- Écriture sur la page -----------------------------------------------------

func _page(cover: Control, at: Vector2, page_size: Vector2, spine: float) -> VBoxContainer:
	var paper := ColorRect.new()
	paper.position = at
	paper.size = page_size
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PARCHMENT
	material.set_shader_parameter("spine", spine)
	material.set_shader_parameter("page_size", page_size)
	material.set_shader_parameter("seed", 1.0 if spine > 0.0 else 0.0)
	paper.material = material
	cover.add_child(paper)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 54 if spine < 0.0 else 44)
	margin.add_theme_constant_override("margin_right", 44 if spine < 0.0 else 54)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	paper.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	return column


func _write(text: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Un trait d'encre sous le titre.
func _rule() -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.color = Color(GameFonts.INK, 0.55)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Jauge des souvenirs, tracée à l'encre.
func _ink_gauge(progress: float) -> Control:
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(0.0, 14.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	outline.border_color = Color(GameFonts.INK, 0.7)
	outline.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", outline)
	var fill := ColorRect.new()
	fill.color = Color(GameFonts.INK, 0.75)
	fill.anchor_bottom = 1.0
	fill.anchor_right = progress
	fill.offset_left = 3.0
	fill.offset_top = 3.0
	fill.offset_bottom = -3.0
	fill.offset_right = -3.0 if progress >= 1.0 else 0.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(fill)
	return frame


## Une ligne écrite qu'on peut toucher : soulignée à l'encre, sans cadre.
func _ink_button(text: String, size: int, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = false
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.add_theme_font_override("font", GameFonts.text())
	button.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, color)
	button.add_theme_color_override("font_disabled_color", Color(GameFonts.FADED_INK, 0.55))
	button.add_theme_stylebox_override("normal", _underline(Color(color, 0.8), 0.0))
	button.add_theme_stylebox_override("hover", _underline(Color(color, 0.8), 0.08))
	button.add_theme_stylebox_override("pressed", _underline(color, 0.18))
	button.add_theme_stylebox_override("disabled", _underline(Color(GameFonts.FADED_INK, 0.25), 0.0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _underline(color: Color, tint: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GameFonts.INK, tint)
	box.border_color = color
	box.border_width_bottom = 2
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 6.0
	return box
