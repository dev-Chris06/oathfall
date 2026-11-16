class_name WorldMap
extends Control
## L'écran de la carte d'Orvana, qui sert de menu : on y choisit le niveau à
## jouer. La ville est vue de face et se gravit en faisant glisser le doigt.
##
## Un niveau est « fait » (rejouable), « ici » (le prochain), « ouvert »
## (construit, jouable quand on veut) ou « ferme » (pas encore construit).

signal level_chosen(id: StringName)
## Le joueur veut revenir à l'écran-titre.
signal menu_requested

const TAP_SLOP := 14.0
const PICK_RADIUS := 52.0
const PARALLAX := 0.35
const FRICTION := 5.0
## Le moulin, sur la carte : le refuge, hors des murs.
## Sa zone tactile est petite et un niveau proche passe toujours avant lui :
## la Grille est à 60 pixels de là.
const MILL_POINT := Vector2(190.0, 2345.0)
const MILL_RADIUS := 46.0

## Les niveaux construits, donnés par `Main`.
var available: Array = []

var _view: Control
var _sky: NightSky
var _scene: MapScene
var _glow: MapGlow
var _scroll := 0.0
var _velocity := 0.0
var _dragging := false
var _moved := 0.0
var _selected := -1
var _refuge_selected := false
var _time := 0.0

var _chapter_label: Label
var _chapter_title: Label
var _progress_label: Label
var _stats_label: Label
var _book_button: Button
var _bottom: PanelContainer
var _bottom_title: Label
var _bottom_text: Label
var _enter_button: Button
var _book: SkillBook


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	add_child(_view)

	_sky = NightSky.new()
	_view.add_child(_sky)
	_scene = MapScene.new()
	_view.add_child(_scene)
	_glow = MapGlow.new()
	_glow.scene = _scene
	_scene.add_child(_glow)

	_build_ui()
	Progress.changed.connect(refresh)
	resized.connect(_layout)
	refresh()
	_layout()
	_focus.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	if not _dragging and absf(_velocity) > 2.0:
		_scroll = _clamp_scroll(_scroll + _velocity * delta)
		_velocity *= exp(-FRICTION * delta)
	elif not _dragging:
		_velocity = 0.0
	_apply_scroll()
	_glow.time = _time
	_glow.queue_redraw()


# --- États --------------------------------------------------------------------

func is_ready(id: StringName) -> bool:
	return available.has(id)


## Le prochain niveau à jouer : le premier construit qui n'est pas fait.
func current_id() -> StringName:
	for level: Dictionary in WorldData.chapter_levels():
		var id: StringName = level["id"]
		if is_ready(id) and not Progress.is_completed(id):
			return id
	return &""


func state_of(id: StringName) -> String:
	if Progress.is_completed(id):
		return "fait"
	if id == current_id():
		return "ici"
	return "ouvert" if is_ready(id) else "ferme"


func refresh() -> void:
	if _scene == null:
		return
	var new_states := PackedStringArray()
	new_states.resize(MapScene.NODE_COUNT)
	new_states.fill("ferme")
	var flags: Array = []
	var levels := WorldData.chapter_levels()
	var done := 0
	for i in levels.size():
		var id: StringName = levels[i]["id"]
		new_states[i] = state_of(id)
		flags.append(is_ready(id))
		if new_states[i] == "fait":
			done += 1
	_scene.set_states(new_states, flags)
	_glow.ici_index = WorldData.level_index(current_id())
	var focus := WorldData.level_index(current_id())
	var chapter := WorldData.chapter_of(maxi(focus, 0) if focus >= 0 else levels.size() - 1)
	_chapter_label.text = "Chapitre %s" % WorldData.roman(chapter)
	_chapter_title.text = WorldData.chapter_title(chapter)
	_progress_label.text = "%d sur %d niveaux terminés" % [done, levels.size()]
	_stats_label.text = "Niv. %d    Or : %d" % [Progress.hero_level, Progress.gold]
	_book_button.text = "Carnet !" if Progress.skill_points > 0 else "Carnet"
	if _selected >= 0:
		_show_selection()


# --- Sélection ----------------------------------------------------------------

func select_level(id: StringName) -> void:
	_select_index(WorldData.level_index(id))


func selected_id() -> StringName:
	if _refuge_selected:
		return &"refuge"
	var level := WorldData.level_at(_selected)
	return level["id"] if not level.is_empty() else &""


## Entre dans le niveau choisi, s'il est construit.
func enter_selected() -> void:
	var id := selected_id()
	if id != &"" and is_ready(id):
		level_chosen.emit(id)


func _select_index(index: int) -> void:
	_selected = index
	_refuge_selected = false
	_glow.selected_index = index
	_glow.refuge_selected = false
	_show_selection()


## Choisit le moulin, le refuge.
func select_refuge() -> void:
	_selected = -1
	_refuge_selected = true
	_glow.selected_index = -1
	_glow.refuge_selected = true
	_show_selection()


func _show_selection() -> void:
	var level := WorldData.level_at(_selected)
	_bottom.visible = _selected >= 0 or _refuge_selected
	if _refuge_selected:
		_bottom_title.text = "Le moulin"
		_bottom_text.text = "Le refuge, hors des murs. Maud, frère Anselme et Tibert y vivent encore : on y achète, on y apprend."
		_enter_button.visible = is_ready(&"refuge")
		return
	if _selected < 0:
		return
	if level.is_empty():
		_bottom_title.text = "Chapitre %d" % (_selected / WorldData.LEVELS_PER_CHAPTER + 1)
		_bottom_text.text = "Ce chapitre n'est pas encore ouvert."
		_enter_button.visible = false
		return
	var id: StringName = level["id"]
	_bottom_title.text = "%d. %s" % [_selected + 1, level["name"]]
	_bottom_text.text = {
		"fait": "Terminé. Tu peux le refaire.",
		"ici": "Le prochain niveau.",
		"ouvert": "Ouvert : tu peux y aller quand tu veux.",
		"ferme": "Pas encore construit.",
	}[state_of(id)]
	_enter_button.visible = is_ready(id)


# --- Défilement ---------------------------------------------------------------

func scroll_to(content_y: float, anchor := 0.58) -> void:
	_scroll = _clamp_scroll(size.y * anchor - content_y)
	_velocity = 0.0
	_apply_scroll()


func _focus() -> void:
	var index := WorldData.level_index(current_id())
	if index < 0:
		index = 0
		for i in WorldData.chapter_levels().size():
			if Progress.is_completed(WorldData.level_at(i)["id"]):
				index = i
	scroll_to(_scene.node_positions[index].y)


func _clamp_scroll(value: float) -> float:
	return clampf(value, minf(0.0, size.y - MapScene.H), 0.0)


func _apply_scroll() -> void:
	_scene.position = Vector2(floorf((size.x - MapScene.W) / 2.0), _scroll)
	_sky.position.y = _scroll * PARALLAX
	_sky.shift = _scene.position.x


func _layout() -> void:
	_scroll = _clamp_scroll(_scroll)
	_apply_scroll()


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					_dragging = true
					_moved = 0.0
					_velocity = 0.0
				else:
					if _dragging and _moved < TAP_SLOP:
						_tap(button.position)
					_dragging = false
			MOUSE_BUTTON_WHEEL_UP:
				_scroll = _clamp_scroll(_scroll + 140.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll = _clamp_scroll(_scroll - 140.0)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_moved += absf(motion.relative.x) + absf(motion.relative.y)
		_scroll = _clamp_scroll(_scroll + motion.relative.y)
		_velocity = lerpf(_velocity, motion.relative.y * 60.0, 0.5)


## Un toucher sur la carte : le point de la route le plus proche est choisi.
func _tap(at: Vector2) -> void:
	var local := at - _scene.position
	var best := -1
	var best_distance := PICK_RADIUS
	for i in _scene.node_positions.size():
		var distance := _scene.node_positions[i].distance_to(local)
		if distance < best_distance:
			best_distance = distance
			best = i
	if best >= 0:
		_select_index(best)
	elif local.distance_to(MILL_POINT) <= MILL_RADIUS:
		select_refuge()


# --- Interface ----------------------------------------------------------------

func _build_ui() -> void:
	# Le cartouche du chapitre, en haut à gauche.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Theatre.panel_box(0.88))
	card.position = Vector2(22.0, 18.0)
	var card_column := VBoxContainer.new()
	card_column.add_theme_constant_override("separation", 0)
	card.add_child(card_column)
	_chapter_label = Theatre.label("", 38, Theatre.AMBER, GameFonts.title())
	card_column.add_child(_chapter_label)
	_chapter_title = Theatre.label("", 21, Theatre.CREAM, GameFonts.italic())
	card_column.add_child(_chapter_title)
	_progress_label = Theatre.label("", 17, Theatre.MUTED)
	card_column.add_child(_progress_label)
	add_child(card)

	# Le niveau du héros et le carnet, en haut à droite.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top.offset_right = -22.0
	top.offset_left = -32.0
	top.offset_top = 22.0
	_stats_label = Theatre.label("", 21)
	top.add_child(_stats_label)
	var menu_button := Button.new()
	menu_button.text = "Menu"
	Theatre.pill(menu_button, 21, Theatre.MUTED)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	top.add_child(menu_button)
	_book_button = Button.new()
	Theatre.pill(_book_button, 21)
	_book_button.pressed.connect(open_book)
	top.add_child(_book_button)
	add_child(top)

	# Le panneau du niveau choisi, en bas.
	_bottom = PanelContainer.new()
	_bottom.add_theme_stylebox_override("panel", Theatre.panel_box(0.94))
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom.offset_left = 22.0
	_bottom.offset_right = -22.0
	_bottom.offset_bottom = -18.0
	_bottom.offset_top = -28.0
	_bottom.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_bottom.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	_bottom_title = Theatre.label("", 32, Theatre.AMBER)
	_bottom_text = Theatre.label("", 19, Theatre.MUTED, GameFonts.italic())
	texts.add_child(_bottom_title)
	texts.add_child(_bottom_text)
	row.add_child(texts)
	_enter_button = Button.new()
	_enter_button.text = "Entrer"
	Theatre.primary(_enter_button, 26)
	_enter_button.pressed.connect(enter_selected)
	row.add_child(_enter_button)
	add_child(_bottom)


func open_book() -> void:
	if _book != null and is_instance_valid(_book):
		return
	_book = SkillBook.new()
	add_child(_book)


## Ce qui bouge sur la carte : la braise du prochain niveau, l'anneau du
## niveau choisi.
class MapGlow extends Control:
	var scene: MapScene
	var ici_index := -1
	var selected_index := -1
	var refuge_selected := false
	var time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(MapScene.W, MapScene.H)

	func _draw() -> void:
		if scene == null:
			return
		if ici_index >= 0:
			var p := scene.node_positions[ici_index]
			var pulse := 0.5 + 0.5 * sin(time * 2.4)
			# Le halo ne dépasse pas le rond de sélection : tous les niveaux
			# choisis ont la même taille.
			for k in 4:
				draw_circle(p, 12.0 + 5.0 * k + 3.0 * pulse, Color(Theatre.EMBER, 0.16 - 0.03 * k))
			draw_circle(p, 11.0, Color(1.0, 0.35, 0.19))
			draw_circle(p, 5.0, Color(1.0, 0.86, 0.7))
		if selected_index >= 0:
			draw_arc(scene.node_positions[selected_index], 25.0 + 2.0 * sin(time * 3.0), 0.0, TAU, 40, Theatre.CREAM, 3.0)
		if refuge_selected:
			draw_arc(WorldMap.MILL_POINT, 28.0 + 2.0 * sin(time * 3.0), 0.0, TAU, 40, Theatre.CREAM, 3.0)
