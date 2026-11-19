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
const FRICTION := 5.0
## La caméra de la carte regarde un point de la route ; ces bornes sont les
## ordonnées du plan qu'elle peut viser, du haut du palais au moulin.
const FOCUS_MIN := 520.0
const FOCUS_MAX := 2720.0
## Ordonnées du plan parcourues par pixel d'écran quand on fait glisser.
const DRAG_RATIO := 1.15
## Le moulin, sur la carte : le refuge, hors des murs.
## Il se tient sur la rive sud, loin des niveaux : sa zone tactile est la tour.
const MILL_POINT := Vector2(135.0, 2650.0)
const MILL_RADIUS := 70.0

## Les niveaux construits, donnés par `Main`.
var available: Array = []

var _view: Control
## Le modèle de la carte (positions, états), non affiché : c'est `_world` qui
## le montre, en 3D.
var _scene: MapScene
var _container: SubViewportContainer
var _viewport: SubViewport
var _world: MapWorld
var _focus_y := 1500.0
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

	_scene = MapScene.new()
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.add_child(_container)
	_viewport = SubViewport.new()
	_viewport.handle_input_locally = false
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_container.add_child(_viewport)
	_world = MapWorld.new()
	_viewport.add_child(_world)
	_world.build(_scene)

	_build_ui()
	Progress.changed.connect(refresh)
	resized.connect(_layout)
	refresh()
	_layout()
	_focus.call_deferred()


## Le modèle de la carte n'est pas dans l'arbre : il faut le libérer à la main.
func _exit_tree() -> void:
	if is_instance_valid(_scene):
		_scene.free()
		_scene = null


func _process(delta: float) -> void:
	_time += delta
	if not _dragging and absf(_velocity) > 2.0:
		_focus_y = _clamp_focus(_focus_y - _velocity * delta * DRAG_RATIO)
		_velocity *= exp(-FRICTION * delta)
	elif not _dragging:
		_velocity = 0.0
	_apply_scroll()
	_scene.river.time = _time


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
	_world.set_states(new_states, flags)
	_world.set_here(WorldData.level_index(current_id()))
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
	_world.set_selected(index, false)
	_show_selection()


## Choisit le moulin, le refuge.
func select_refuge() -> void:
	_selected = -1
	_refuge_selected = true
	_world.set_selected(-1, true)
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

## Vise le point du plan d'ordonnée `content_y` (`anchor` est gardé pour
## compatibilité : la caméra centre toujours son point de visée).
func scroll_to(content_y: float, _anchor := 0.58) -> void:
	_focus_y = _clamp_focus(content_y)
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


func _clamp_focus(value: float) -> float:
	return clampf(value, FOCUS_MIN, FOCUS_MAX)


func _apply_scroll() -> void:
	_world.focus(_focus_y)


func _layout() -> void:
	_focus_y = _clamp_focus(_focus_y)
	_apply_scroll()


## Position à l'écran d'un point du plan de la carte (pour les essais).
func screen_of(plane: Vector2) -> Vector2:
	return _world.screen_of(plane)


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
				_focus_y = _clamp_focus(_focus_y - 160.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_focus_y = _clamp_focus(_focus_y + 160.0)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_moved += absf(motion.relative.x) + absf(motion.relative.y)
		_focus_y = _clamp_focus(_focus_y - motion.relative.y * DRAG_RATIO)
		_velocity = lerpf(_velocity, motion.relative.y * 60.0, 0.5)


## Un toucher sur la carte : le point de la route le plus proche est choisi,
## sinon le moulin.
func _tap(at: Vector2) -> void:
	var found := _world.pick(at, PICK_RADIUS, MILL_RADIUS)
	if found >= 0:
		_select_index(found)
	elif found == -2:
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
