class_name ShopScreen
extends CanvasLayer
## La boutique de Maud, en trois onglets : l'équipement (avec un aperçu du
## héros qui essaie l'objet avant de l'acheter), les fioles, les vivres. Chaque
## article a son icône. Le jeu est en pause tant qu'elle est ouverte.

signal closed

const ICONS := "res://assets/ui/icons/"

var selected: StringName = &"ecu_insigne"
## L'onglet : « equipement », « fioles » ou « vivres ».
var tab := &"equipement"
var selected_meal: StringName = &"pain"

var _page: CutPage
var _gold: Label
var _preview: HeroPreview
var _buttons := {}
var _detail: VBoxContainer
var _prices := {}


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
	_page = CutPage.new(5)
	_page.custom_minimum_size = Vector2(1180.0, 640.0)
	center.add_child(_page)
	_refresh()


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


## Achète l'objet sélectionné ou donné, comme si le joueur avait touché son bouton.
func buy(item_id: StringName) -> bool:
	var bought := Progress.buy_gear(item_id)
	if bought:
		Audio.play(&"coins")
	_refresh()
	return bought


func select(item_id: StringName) -> void:
	selected = item_id
	_refresh()


func show_tab(new_tab: StringName) -> void:
	tab = new_tab
	_refresh()


## Achète une fiole, comme si le joueur avait touché son bouton.
func buy_flask() -> bool:
	var bought := Progress.buy_flask()
	if bought:
		Audio.play(&"coins")
	_refresh()
	return bought


## Emballe un repas pour le prochain niveau.
func pack(meal_id: StringName) -> bool:
	selected_meal = meal_id
	var packed := Progress.pack_meal(meal_id)
	_refresh()
	return packed


func _refresh() -> void:
	var column := _page.column
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	_buttons.clear()

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 30)
	head.add_child(Theatre.label("Maud", 56, Theatre.AMBER, GameFonts.title()))
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_child(Theatre.label("La meunière vend contre ton or.", 20, Theatre.MUTED, GameFonts.italic()))
	head.add_child(side)
	_gold = Theatre.label("Or : %d" % Progress.gold, 30, Theatre.CREAM)
	head.add_child(_gold)
	column.add_child(head)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color(Theatre.AMBER, 0.5)
	column.add_child(rule)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	for entry: Array in [[&"equipement", "Équipement"], [&"fioles", "Fioles"], [&"vivres", "Vivres"]]:
		var button := Button.new()
		button.text = entry[1]
		Theatre.pill(button, 20, Theatre.AMBER if tab == entry[0] else Theatre.MUTED)
		button.pressed.connect(show_tab.bind(entry[0]))
		tabs.add_child(button)
	column.add_child(tabs)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	if tab == &"fioles":
		_fill_flasks(body)
	elif tab == &"vivres":
		_fill_meals(body)
	else:
		_fill_gear(body)

	var back := Button.new()
	back.text = "Refermer"
	Theatre.pill(back, 20)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close)
	column.add_child(back)


## L'équipement, par emplacement, en icônes ; à droite l'aperçu et la fiche.
func _fill_gear(body: HBoxContainer) -> void:
	var shelves := VBoxContainer.new()
	shelves.add_theme_constant_override("separation", 6)
	body.add_child(shelves)
	for slot in Gear.SLOTS:
		shelves.add_child(Theatre.label(Gear.SLOT_NAMES[slot], 24, Theatre.AMBER))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		shelves.add_child(row)
		for id in Gear.items_in(slot):
			row.add_child(_item_button(id))

	# À droite : l'aperçu du héros et la fiche.
	_preview = HeroPreview.new(Vector2(250.0, 380.0))
	body.add_child(_preview)
	_preview.show_gear(_with(selected))
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 6)
	body.add_child(_detail)
	_fill_detail()


## L'équipement porté, avec l'objet donné à la place de son emplacement.
func _with(item_id: StringName) -> Dictionary:
	var map := Progress.equipped_map()
	map[Gear.ITEMS[item_id]["slot"]] = item_id
	return map


func _item_button(id: StringName) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	var button := Button.new()
	button.custom_minimum_size = Vector2(104.0, 104.0)
	button.expand_icon = true
	var path := ICONS + "%s.png" % id
	button.icon = load(path) as Texture2D if ResourceLoader.exists(path) else null
	var active := id == selected
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, _cell(active or state != "normal"))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(select.bind(id))
	cell.add_child(button)
	var state_text := "Équipé" if Progress.equipped_id(Gear.ITEMS[id]["slot"]) == id \
		else ("Possédé" if Progress.owns(id) else "%d or" % int(Gear.ITEMS[id]["cost"]))
	var label := Theatre.label(state_text, 17, Theatre.AMBER if state_text == "Équipé" else Theatre.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(label)
	_buttons[id] = button
	return cell


func _fill_detail() -> void:
	var item: Dictionary = Gear.ITEMS[selected]
	_detail.add_child(Theatre.label(item["name"], 36))
	_detail.add_child(Theatre.label(Gear.SLOT_NAMES[item["slot"]], 19, Theatre.MUTED, GameFonts.italic()))
	var text := Theatre.label(item["text"], 21, Theatre.CREAM, GameFonts.italic())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(text)
	for line in Gear.describe(selected):
		var effect := Theatre.label(line, 21, Theatre.EMBER)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(effect)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(filler)

	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if Progress.equipped_id(item["slot"]) == selected:
		button.text = "Équipé"
		Theatre.pill(button, 22)
		button.disabled = true
	elif Progress.owns(selected):
		button.text = "Équiper"
		Theatre.primary(button, 24)
		button.pressed.connect(func() -> void:
			Progress.equip(selected)
			_refresh())
	else:
		var cost := int(item["cost"])
		var short := cost - Progress.gold
		button.text = "Acheter : %d or" % cost
		Theatre.primary(button, 24)
		button.disabled = short > 0
		button.pressed.connect(buy.bind(selected))
		if short > 0:
			_detail.add_child(Theatre.label("Il te manque %d or." % short, 18, Theatre.EMBER, GameFonts.italic()))
	_detail.add_child(button)


## Les fioles : l'icône, ce qu'elles font, et le héros avec celles qu'il porte.
func _fill_flasks(body: HBoxContainer) -> void:
	var flask: Dictionary = Supplies.FLASK
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(200.0, 200.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := ICONS + "%s.png" % flask["icon"]
	icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	body.add_child(icon)
	_preview = HeroPreview.new(Vector2(250.0, 380.0))
	body.add_child(_preview)
	_preview.show_gear(Progress.equipped_map())
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 6)
	body.add_child(detail)
	detail.add_child(Theatre.label(flask["name"], 36))
	var text := Theatre.label(flask["text"], 21, Theatre.CREAM, GameFonts.italic())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(text)
	detail.add_child(Theatre.label("Rend %d de vie." % int(flask["heal"]), 21, Theatre.EMBER))
	detail.add_child(Theatre.label("Boire prend un instant, sans défense. Un coup ou une esquive l'annule.", 19, Theatre.MUTED, GameFonts.italic()))
	detail.add_child(Theatre.label("Tu en portes %d sur %d. Elles se voient à ta ceinture." % [Progress.flasks, int(flask["max"])], 21, Theatre.AMBER))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(filler)
	var blocker := Progress.flask_blocker()
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.text = "Acheter une fiole : %d or" % int(flask["cost"])
	Theatre.primary(button, 24)
	button.disabled = blocker != ""
	button.pressed.connect(buy_flask)
	detail.add_child(button)
	if blocker == "pleines":
		detail.add_child(Theatre.label("Ta ceinture est pleine.", 18, Theatre.EMBER, GameFonts.italic()))
	elif blocker == "or":
		detail.add_child(Theatre.label("Il te manque %d or." % (int(flask["cost"]) - Progress.gold), 18, Theatre.EMBER, GameFonts.italic()))


## Les vivres : un repas emballé, pour le prochain niveau seulement.
func _fill_meals(body: HBoxContainer) -> void:
	var shelf := HBoxContainer.new()
	shelf.add_theme_constant_override("separation", 10)
	body.add_child(shelf)
	for id: StringName in Supplies.MEALS:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var button := Button.new()
		button.custom_minimum_size = Vector2(112.0, 112.0)
		button.expand_icon = true
		var meal: Dictionary = Supplies.MEALS[id]
		var path := ICONS + "%s.png" % meal["icon"]
		button.icon = load(path) as Texture2D if ResourceLoader.exists(path) else null
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, _cell(id == selected_meal or state != "normal"))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(func() -> void:
			selected_meal = id
			_refresh())
		cell.add_child(button)
		var label := Theatre.label("Emballé" if Progress.packed_meal == id else "%d or" % int(meal["cost"]), 17,
			Theatre.AMBER if Progress.packed_meal == id else Theatre.MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(label)
		shelf.add_child(cell)

	var meal: Dictionary = Supplies.MEALS[selected_meal]
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 6)
	body.add_child(detail)
	detail.add_child(Theatre.label(meal["name"], 36))
	var text := Theatre.label(meal["text"], 21, Theatre.CREAM, GameFonts.italic())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(text)
	for line in Supplies.describe_meal(selected_meal):
		detail.add_child(Theatre.label(line, 21, Theatre.EMBER))
	detail.add_child(Theatre.label("Un seul repas à la fois, pour le prochain niveau seulement.", 19, Theatre.MUTED, GameFonts.italic()))
	if Progress.packed_meal != &"":
		detail.add_child(Theatre.label("Dans ton sac : %s." % String(Supplies.MEALS[Progress.packed_meal]["name"]).to_lower(), 21, Theatre.AMBER))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(filler)
	var blocker := Progress.meal_blocker(selected_meal)
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.text = "Emballer : %d or" % int(meal["cost"])
	Theatre.primary(button, 24)
	button.disabled = blocker != ""
	button.pressed.connect(pack.bind(selected_meal))
	detail.add_child(button)
	if blocker == "deja":
		detail.add_child(Theatre.label("Tu as déjà un repas dans ton sac.", 18, Theatre.EMBER, GameFonts.italic()))
	elif blocker == "or":
		detail.add_child(Theatre.label("Il te manque %d or." % (int(meal["cost"]) - Progress.gold), 18, Theatre.EMBER, GameFonts.italic()))


func _cell(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Theatre.DEEP, 0.9)
	box.border_color = Color(Theatre.AMBER, 0.95 if active else 0.35)
	box.set_border_width_all(3 if active else 2)
	box.set_corner_radius_all(4)
	return box
