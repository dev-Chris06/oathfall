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
## L'onglet de la page de droite : « rites », « combat » ou « equipement ».
var tab := &"rites"
## Le rite de combat montré dans l'onglet « combat ».
var shown_rite: StringName = &""
## Ouvert en plein niveau : les rites portés ne changent pas (on les choisit
## sur la carte, avant d'entrer).
var in_level := false

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

	Audio.play(&"book_open")
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
	Audio.play(&"book_close")
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
	head.add_child(Theatre.label({&"rites": "Rites", &"combat": "Combat", &"equipement": "Équipement"}[tab], 50, Theatre.AMBER, GameFonts.title()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	for entry: Array in [[&"rites", "Rites"], [&"combat", "Combat"], [&"equipement", "Équipement"]]:
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
	if tab == &"combat":
		_fill_combat(page)
		return
	for skill: Dictionary in Progression.skills_for(Progress.class_id):
		page.add_child(_skill_entry(skill))
	var known: Array[String] = []
	for rite: Dictionary in Progression.ADVANCED:
		if Progress.has_advanced(rite["id"]):
			known.append(rite["name"])
	var note := "Rites supérieurs : %s." % ", ".join(known) if not known.is_empty() \
		else "Frère Anselme enseigne des rites supérieurs, au moulin."
	var summary := Theatre.label(note, 18, Theatre.AMBER if not known.is_empty() else Theatre.MUTED, GameFonts.italic())
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(summary)


# --- Onglet « Combat » : les rites de combat ------------------------------------

## Montre un rite de combat, comme si le joueur avait touché son icône.
func show_rite(rite_id: StringName) -> void:
	shown_rite = rite_id
	tab = &"combat"
	_refresh()


## Porte le rite montré à l'emplacement `slot`.
func wear_rite(slot: int) -> bool:
	if in_level:
		return false
	var done := Progress.equip_rite(shown_rite, slot)
	_refresh()
	return done


## Le rite montré : son animation, sa fiche, les trois emplacements ; puis
## les neuf rites, en icônes, leur nom dessous.
func _fill_combat(page: VBoxContainer) -> void:
	if shown_rite == &"":
		for id in Progress.rite_slots:
			if id != &"":
				shown_rite = id
				break
		if shown_rite == &"":
			shown_rite = RiteData.ORDER[0]
	var rite := RiteData.get_rite(shown_rite)
	var open := Progress.rite_unlocked(shown_rite)
	var preview := RitePreview.new(Vector2(520.0, 172.0))
	preview.rite = shown_rite
	page.add_child(preview)

	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	var badge := RiteBadge.new(shown_rite, 54.0, open)
	info.add_child(badge)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 12)
	title.add_child(Theatre.label(rite["name"], 26, Theatre.CREAM if open else Theatre.MUTED))
	var cost := int(rite["cost"])
	title.add_child(Theatre.label("%s · %d braise%s" % [String(rite["kind"]).to_lower(), cost, "s" if cost > 1 else ""], 16, Theatre.EMBER, GameFonts.italic()))
	lines.add_child(title)
	var text := Theatre.label(rite["text"] if open else RiteData.unlock_text(shown_rite), 16, Theatre.MUTED, GameFonts.italic())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(text)
	info.add_child(lines)
	page.add_child(info)

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	slots.add_child(Theatre.label("Porter :", 18, Theatre.AMBER))
	for i in RiteData.SLOTS:
		var worn: StringName = Progress.rite_slots[i]
		var button := Button.new()
		button.text = "%d · %s" % [i + 1, RiteData.RITES[worn]["name"] if worn != &"" else "vide"]
		Theatre.pill(button, 16, Theatre.AMBER if worn == shown_rite else Theatre.MUTED)
		button.disabled = not open or in_level
		button.pressed.connect(wear_rite.bind(i))
		slots.add_child(button)
	page.add_child(slots)
	if in_level:
		var note := Theatre.label("En combat, on garde ses rites : ils se choisissent sur la carte, avant d'entrer.", 15, Theatre.MUTED, GameFonts.italic())
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(note)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	for id: StringName in RiteData.ORDER:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.custom_minimum_size = Vector2(98.0, 0.0)
		var unlocked := Progress.rite_unlocked(id)
		var icon := RiteBadge.new(id, 44.0, unlocked, id == shown_rite)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.pressed.connect(show_rite.bind(id))
		cell.add_child(icon)
		var name_label := Theatre.label(RiteData.RITES[id]["name"], 15, Theatre.CREAM if unlocked else Theatre.MUTED)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)
		grid.add_child(cell)
	page.add_child(grid)


## Une icône de rite cliquable : un disque sombre, l'icône dessinée en code,
## pâle si le rite est ouvert, sombre sinon ; liseré d'or s'il est montré.
class RiteBadge extends Button:
	var rite_id: StringName
	var radius := 44.0
	var open := true
	var chosen := false

	func _init(id: StringName, r: float, unlocked: bool, selected := false) -> void:
		rite_id = id
		radius = r
		open = unlocked
		chosen = selected
		custom_minimum_size = Vector2(r * 1.6, r * 1.6)
		flat = true
		focus_mode = Control.FOCUS_NONE
		process_mode = Node.PROCESS_MODE_ALWAYS
		draw.connect(_paint)

	func _paint() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 2.0
		draw_circle(c, r, Color(0.045, 0.05, 0.1, 0.95))
		draw_arc(c, r, 0.0, TAU, 40, Color(Theatre.AMBER, 0.95 if chosen else (0.55 if open else 0.2)), 3.0 if chosen else 2.0, true)
		RiteIcons.draw(self, rite_id, c, r * 0.62, Theatre.CREAM if open else Color(0.3, 0.3, 0.38),
			Theatre.EMBER if open else Color(0.3, 0.28, 0.34))


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
	var supplies := "Fioles : %d sur %d" % [Progress.flasks, int(Supplies.FLASK["max"])]
	if Progress.packed_meal != &"":
		supplies += "    Sac : %s" % String(Supplies.MEALS[Progress.packed_meal]["name"]).to_lower()
	elif Progress.active_meal != &"":
		supplies += "    Repas : %s" % String(Supplies.MEALS[Progress.active_meal]["name"]).to_lower()
	page.add_child(Theatre.label(supplies, 18, Theatre.AMBER))
	var hint := Theatre.label("Maud vend équipement, fioles et vivres, au moulin.", 17, Theatre.MUTED, GameFonts.italic())
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
