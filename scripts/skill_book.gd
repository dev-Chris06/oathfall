class_name SkillBook
extends CanvasLayer
## Le carnet du soldat, ouvert sur deux pages de papier noir : à gauche ce
## qu'il est devenu (niveau, souvenirs, or), à droite les rites qu'il peut
## apprendre avec ses points. Le jeu est en pause tant qu'il est ouvert.
##
## On y apprend ses rites, où que l'on soit, avec les points gagnés. Frère
## Anselme, au moulin, aide à les désapprendre.

signal closed
## Le joueur veut quitter le niveau pour revenir à la carte.
signal leave_requested

## Vrai quand le carnet est ouvert en plein niveau : il propose alors de le
## quitter.
var can_leave := false
## L'onglet de la page de droite : « rites » ou « equipement ».
var tab := &"rites"

var _left: CutPage
var _right: CutPage


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	# Le fond : la nuit, plus claire au centre.
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
	# Toucher hors du carnet le referme.
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close_book())
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	center.add_child(row)
	_left = CutPage.new(3)
	_left.custom_minimum_size = Vector2(560.0, 610.0)
	row.add_child(_left)
	_right = CutPage.new(7)
	_right.custom_minimum_size = Vector2(560.0, 610.0)
	row.add_child(_right)

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
		for child in page.column.get_children():
			page.column.remove_child(child)
			child.queue_free()
	_fill_left()
	_fill_right()


# --- Page de gauche : le soldat -----------------------------------------------

func _fill_left() -> void:
	var data := HeroClasses.get_class_data(Progress.class_id)
	var page := _left.column
	page.add_child(Theatre.label("Carnet", 62, Theatre.AMBER, GameFonts.title()))
	page.add_child(Theatre.label("%s de la dernière légion d'Orvana" % data["name"], 19, Theatre.MUTED, GameFonts.italic()))
	page.add_child(_rule())

	page.add_child(Theatre.label("Niveau %d" % Progress.hero_level, 36))
	var next := Progression.threshold(Progress.hero_level + 1)
	page.add_child(Theatre.label("Souvenirs : %d sur %d" % [Progress.memories, next], 23))
	var gauge := Gauge.new()
	gauge.value = Progress.level_progress()
	page.add_child(gauge)
	page.add_child(Theatre.label("Or : %d" % Progress.gold, 23))
	var points := Progress.skill_points
	if points == 0:
		page.add_child(Theatre.label("Aucun point à dépenser.", 23, Theatre.MUTED))
	else:
		page.add_child(Theatre.label("%d point%s à dépenser." % [points, "s" if points > 1 else ""], 23, Theatre.EMBER))

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(filler)

	var memo := Theatre.label("Chaque corps mis au repos me rend un peu de ce qu'il portait.", 19, Theatre.MUTED, GameFonts.italic())
	memo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(memo)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var close := Button.new()
	close.text = "Refermer le carnet"
	Theatre.pill(close, 20)
	close.pressed.connect(close_book)
	buttons.add_child(close)
	if can_leave:
		var leave := Button.new()
		leave.text = "Quitter le niveau"
		Theatre.pill(leave, 20, Theatre.EMBER)
		leave.pressed.connect(func() -> void: leave_requested.emit())
		buttons.add_child(leave)
	page.add_child(buttons)


# --- Page de droite : les rites -----------------------------------------------

func show_tab(new_tab: StringName) -> void:
	tab = new_tab
	_refresh()


## Équipe un objet depuis le carnet, comme si le joueur avait touché son icône.
func equip(item_id: StringName) -> bool:
	var done := Progress.equip(item_id)
	_refresh()
	return done


func _fill_right() -> void:
	var page := _right.column
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(Theatre.label("Rites" if tab == &"rites" else "Équipement", 50, Theatre.AMBER, GameFonts.title()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	for entry: Array in [[&"rites", "Rites"], [&"equipement", "Équipement"]]:
		var button := Button.new()
		button.text = entry[1]
		Theatre.pill(button, 18, Theatre.AMBER if tab == entry[0] else Theatre.MUTED)
		button.pressed.connect(show_tab.bind(entry[0]))
		head.add_child(button)
	page.add_child(head)
	page.add_child(_rule())
	if tab == &"equipement":
		_fill_equipment(page)
		return
	for skill: Dictionary in Progression.skills_for(Progress.class_id):
		page.add_child(_skill_entry(skill))


## L'équipement porté : le héros qui tourne, et ce qu'on possède par emplacement.
func _fill_equipment(page: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	page.add_child(body)
	var preview := HeroPreview.new(Vector2(215.0, 330.0))
	body.add_child(preview)
	preview.show_gear(Progress.equipped_map())
	var shelves := VBoxContainer.new()
	shelves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelves.add_theme_constant_override("separation", 6)
	body.add_child(shelves)
	for slot in Gear.SLOTS:
		shelves.add_child(Theatre.label(Gear.SLOT_NAMES[slot], 22, Theatre.AMBER))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		shelves.add_child(row)
		for id in Gear.items_in(slot):
			if not Progress.owns(id):
				continue
			var button := Button.new()
			button.custom_minimum_size = Vector2(66.0, 66.0)
			button.expand_icon = true
			var path := "res://assets/ui/icons/%s.png" % id
			button.icon = load(path) as Texture2D if ResourceLoader.exists(path) else null
			var worn := Progress.equipped_id(slot) == id
			for state in ["normal", "hover", "pressed"]:
				button.add_theme_stylebox_override(state, _icon_cell(worn))
			button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			button.pressed.connect(equip.bind(id))
			row.add_child(button)
		var current: StringName = Progress.equipped_id(slot)
		shelves.add_child(Theatre.label(Gear.ITEMS[current]["name"], 19))
		for line in Gear.describe(current):
			var effect := Theatre.label(line, 16, Theatre.EMBER, GameFonts.italic())
			effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			shelves.add_child(effect)
	var hint := Theatre.label("Maud vend d'autres équipements, au moulin.", 17, Theatre.MUTED, GameFonts.italic())
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(hint)


func _icon_cell(worn: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Theatre.DEEP, 0.9)
	box.border_color = Color(Theatre.AMBER, 0.95 if worn else 0.3)
	box.set_border_width_all(3 if worn else 2)
	box.set_corner_radius_all(4)
	return box



func _skill_entry(skill: Dictionary) -> Control:
	var skill_id: StringName = skill["id"]
	var rank := Progress.rank_of(skill_id)
	var rank_list: Array = skill["ranks"]

	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 1)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(Theatre.label(skill["name"], 26))
	head.add_child(Theatre.label("rang %d/%d" % [rank, rank_list.size()], 17, Theatre.MUTED, GameFonts.italic()))
	entry.add_child(head)
	var detail: String = skill["text"]
	if rank > 0:
		detail += " Acquis : %s." % _lower_first(rank_list[rank - 1]["text"])
	var text := Theatre.label(detail, 17, Theatre.MUTED, GameFonts.italic())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(text)

	var next := Progress.next_rank(skill_id)
	if next.is_empty():
		entry.add_child(Theatre.label("Maîtrisé.", 18, Theatre.AMBER, GameFonts.italic()))
	else:
		var cost := int(next["cost"])
		var button := Button.new()
		button.text = "Apprendre : %s, %d point%s" % [_lower_first(next["text"]), cost, "s" if cost > 1 else ""]
		Theatre.pill(button, 18)
		button.disabled = not Progress.can_learn(skill_id)
		button.pressed.connect(learn.bind(skill_id))
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		entry.add_child(button)
	return entry


func _lower_first(text: String) -> String:
	return text.left(1).to_lower() + text.substr(1)


## Un trait d'or pâle sous un titre.
func _rule() -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.color = Color(Theatre.AMBER, 0.5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## La jauge des souvenirs : un liseré d'or, rempli à mesure.
class Gauge extends Control:
	var value := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 16.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Theatre.AMBER, 0.9), false, 2.0)
		draw_rect(Rect2(Vector2(4.0, 4.0), Vector2((size.x - 8.0) * clampf(value, 0.0, 1.0), size.y - 8.0)), Theatre.AMBER)
