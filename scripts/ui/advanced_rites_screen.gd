class_name AdvancedRitesScreen
extends CanvasLayer
## Les rites supérieurs que frère Anselme enseigne : chacun demande d'avoir
## terminé un niveau, et des points. Le jeu est en pause tant qu'elle est
## ouverte.

signal closed

var _page: CutPage


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
	_page = CutPage.new(13)
	_page.custom_minimum_size = Vector2(980.0, 600.0)
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


## Apprend un rite supérieur, comme si le joueur avait touché son bouton.
func learn(rite_id: StringName) -> bool:
	var learned := Progress.learn_advanced(rite_id)
	_refresh()
	return learned


func _refresh() -> void:
	var column := _page.column
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	head.add_child(Theatre.label("Rites supérieurs", 52, Theatre.AMBER, GameFonts.title()))
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_child(Theatre.label("Frère Anselme ne les enseigne qu'à celui qui les a mérités.", 19, Theatre.MUTED, GameFonts.italic()))
	head.add_child(side)
	var points := Theatre.label("Points : %d" % Progress.skill_points, 28, Theatre.EMBER if Progress.skill_points > 0 else Theatre.MUTED)
	head.add_child(points)
	column.add_child(head)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color(Theatre.AMBER, 0.5)
	column.add_child(rule)

	for rite: Dictionary in Progression.ADVANCED:
		column.add_child(_entry(rite))

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


func _entry(rite: Dictionary) -> Control:
	var id: StringName = rite["id"]
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 1)
	entry.add_child(Theatre.label(rite["name"], 28))
	var text := Theatre.label(rite["text"], 19, Theatre.MUTED, GameFonts.italic())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(text)
	entry.add_child(Theatre.label(rite["effect"], 20, Theatre.EMBER))
	var blocker := Progress.advanced_blocker(id)
	if blocker == "appris":
		entry.add_child(Theatre.label("Appris.", 20, Theatre.AMBER, GameFonts.italic()))
		return entry
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.text = "Apprendre : %d points" % int(rite["cost"])
	Theatre.pill(button, 20)
	button.disabled = blocker != ""
	button.pressed.connect(learn.bind(id))
	entry.add_child(button)
	if blocker == "niveau":
		var names: Array[String] = []
		for level_id: StringName in rite["needs"]:
			names.append(String(WorldData.chapter_levels()[WorldData.level_index(level_id)]["name"]))
		entry.add_child(Theatre.label("Pas encore : termine d'abord %s." % ", ".join(names), 17, Theatre.EMBER, GameFonts.italic()))
	elif blocker == "points":
		entry.add_child(Theatre.label("Il te manque %d point%s." % [int(rite["cost"]) - Progress.skill_points,
			"s" if int(rite["cost"]) - Progress.skill_points > 1 else ""], 17, Theatre.EMBER, GameFonts.italic()))
	return entry
