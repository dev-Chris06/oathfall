class_name ShopScreen
extends CanvasLayer
## La boutique de Maud : des améliorations permanentes, payées en or. Le jeu
## est en pause tant qu'elle est ouverte.

signal closed

var _page: CutPage
var _grid: GridContainer
var _gold: Label


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
	_page.custom_minimum_size = Vector2(1100.0, 600.0)
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


## Achète un article, comme si le joueur avait touché son bouton.
func buy(item_id: StringName) -> bool:
	var bought := Progress.buy(item_id)
	_refresh()
	return bought


func _refresh() -> void:
	var column := _page.column
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

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

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 40)
	_grid.add_theme_constant_override("v_separation", 12)
	column.add_child(_grid)
	for item: Dictionary in Shop.ITEMS:
		_grid.add_child(_item_entry(item))

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


func _item_entry(item: Dictionary) -> Control:
	var id: StringName = item["id"]
	var ranks: Array = item["ranks"]
	var owned := Progress.shop_rank(id)
	var entry := VBoxContainer.new()
	entry.custom_minimum_size = Vector2(470.0, 0.0)
	entry.add_theme_constant_override("separation", 1)

	var title := "%s" % item["name"]
	if ranks.size() > 1:
		title += "   rang %d/%d" % [owned, ranks.size()]
	entry.add_child(Theatre.label(title, 25))
	var text := Theatre.label(item["text"], 17, Theatre.MUTED, GameFonts.italic())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(text)

	var blocker := Progress.shop_blocker(id)
	if blocker == "maitrise":
		entry.add_child(Theatre.label("Acquis.", 18, Theatre.AMBER, GameFonts.italic()))
		return entry
	var next := Progress.shop_next(id)
	var cost := int(next["cost"])
	var button := Button.new()
	button.text = "%s : %d or" % [next["text"], cost]
	Theatre.pill(button, 18)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.disabled = blocker != ""
	button.pressed.connect(buy.bind(id))
	entry.add_child(button)
	if blocker == "prerequis":
		var needs: Dictionary = item.get("requires", {})
		for needed: String in needs:
			entry.add_child(Theatre.label("Il faut d'abord : %s." % Shop.find(StringName(needed))["name"].to_lower(),
				16, Theatre.EMBER, GameFonts.italic()))
	elif blocker == "or":
		entry.add_child(Theatre.label("Il te manque %d or." % (cost - Progress.gold), 16, Theatre.EMBER, GameFonts.italic()))
	return entry
