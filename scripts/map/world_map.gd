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
## La cour d'armes : l'entraînement.
signal training_requested

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

## Rapprochement de la caméra permis par le pincement.
const ZOOM_MIN := 0.55
const ZOOM_MAX := 1.3
## Deux touchers sur la carte, à moins de ce délai : retour au lieu « ici ».
const DOUBLE_TAP := 0.35
## Durée de la plongée vers un niveau, du recul au retour, du travelling
## d'ouverture.
const DIVE_TIME := 1.9
const BACK_TIME := 1.5
const OPENING_TIME := 2.8
const PORTRAITS := "res://assets/ui/portraits/"

## Les niveaux construits, donnés par `Main`.
var available: Array = []
## Faux pendant les essais : ni travelling, ni plongée.
var cinematics := true
## Le niveau qu'on vient de quitter : la caméra recule depuis lui.
var arrived_from: StringName = &""

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
var _zoom := 1.0
## Décalage horizontal de la visée (plan) ; négatif : la visée par défaut.
var _focus_x := -1.0
var _touches := {}
var _pinch_distance := 0.0
var _last_empty_tap := -10.0
## Un mouvement de caméra en cours : départ et arrivée (x, y du plan,
## rapprochement), avancement, durée. Vide sinon.
var _glide := {}
## La plongée vers le niveau choisi, en cours.
var _dive := {}
var _fade: ColorRect
var _portraits: HBoxContainer
## La fiche d'un rite qui vient de s'ouvrir, s'il y en a une.
var _rite_card: Control
## Les trois rites portés, dans la fiche du lieu, et la liste pour en changer.
var _rites_strip: HBoxContainer
var _rite_picker: Control

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
	_world.animate_reveal = cinematics
	_viewport.add_child(_world)
	_world.build(_scene)

	_build_ui()
	Progress.changed.connect(refresh)
	resized.connect(_layout)
	refresh()
	_layout()
	_focus.call_deferred()
	# Un quartier sort de la brume : une cloche sonne au loin.
	if cinematics and _world.life.is_revealing():
		Audio.play(&"bell_toll")
	# Un rite de combat vient de s'ouvrir : il se présente.
	if cinematics:
		show_next_rite()


## Le modèle de la carte n'est pas dans l'arbre : il faut le libérer à la main.
func _exit_tree() -> void:
	if is_instance_valid(_scene):
		_scene.free()
		_scene = null


func _process(delta: float) -> void:
	_time += delta
	if not _dive.is_empty():
		# La plongée finie, la carte est retirée : plus rien à faire.
		_update_dive(delta)
		return
	if not _glide.is_empty():
		_update_glide(delta)
	elif not _dragging and absf(_velocity) > 2.0:
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


## Entre dans le niveau choisi, s'il est construit : le corbeau y vole, la
## caméra le suit et plonge (sauf pendant les essais).
func enter_selected() -> void:
	var id := selected_id()
	if id == &"" or not is_ready(id) or not _dive.is_empty():
		return
	if not cinematics:
		level_chosen.emit(id)
		return
	Audio.play(&"ui_select")
	_glide = {}
	_bottom.visible = false
	var target := WorldMap.MILL_POINT if _refuge_selected else _scene.node_positions[_selected]
	var from := Vector2(_current_x(), _focus_y)
	var start := MapWorld.to_world(from, 3.2) + Vector3(-2.5, 0.0, 4.0)
	var end := MapWorld.to_world(target, 0.45)
	_dive = {"id": id, "t": 0.0, "from": from, "to": target, "zoom": _zoom,
		"a": start, "b": (start + end) / 2.0 + Vector3(0.0, 3.5, 0.0), "c": end}
	_world.raven.visible = true


func _update_dive(delta: float) -> void:
	_dive["t"] = minf(float(_dive["t"]) + delta / DIVE_TIME, 1.0)
	var t: float = _dive["t"]
	# Le corbeau : une courbe, du haut de l'écran jusqu'au lieu.
	var u := ease(minf(t / 0.8, 1.0), -1.8)
	var a: Vector3 = _dive["a"]
	var b: Vector3 = _dive["b"]
	var c: Vector3 = _dive["c"]
	var at := a.lerp(b, u).lerp(b.lerp(c, u), u)
	var ahead := (b.lerp(c, u) - a.lerp(b, u))
	if ahead.length() > 0.01:
		_world.raven.basis = Basis.looking_at(-ahead.normalized(), Vector3.UP) * Basis.from_scale(Vector3.ONE * 2.4)
	_world.raven.position = at
	# La caméra le suit, puis plonge vers le sol.
	var follow := ease(t, -2.0)
	var from: Vector2 = _dive["from"]
	var to: Vector2 = _dive["to"]
	_focus_x = lerpf(from.x, to.x, follow)
	_focus_y = lerpf(from.y, to.y, follow)
	_zoom = lerpf(float(_dive["zoom"]), 0.22, ease(t, 2.4))
	_apply_scroll()
	_fade.color.a = smoothstep(0.72, 1.0, t)
	if t >= 1.0:
		var id: StringName = _dive["id"]
		_dive = {}
		level_chosen.emit(id)


## Fait glisser la caméra d'une vue à une autre (x, y du plan, rapprochement).
func _start_glide(from: Vector3, to: Vector3, duration: float) -> void:
	_glide = {"from": from, "to": to, "t": 0.0, "time": duration}
	_apply_glide(0.0)


func _update_glide(delta: float) -> void:
	_glide["t"] = minf(float(_glide["t"]) + delta / float(_glide["time"]), 1.0)
	_apply_glide(float(_glide["t"]))
	if float(_glide["t"]) >= 1.0:
		_glide = {}


func _apply_glide(t: float) -> void:
	var view := (_glide["from"] as Vector3).lerp(_glide["to"], ease(t, -2.2))
	_focus_x = view.x
	_focus_y = view.y
	_zoom = view.z
	_fade.color.a = minf(_fade.color.a, 1.0 - smoothstep(0.0, 0.4, t))
	_apply_scroll()
	if t >= 1.0 and _zoom > 0.97:
		_focus_x = -1.0


func _current_x() -> float:
	return _focus_x if _focus_x >= 0.0 else _world.default_x(_focus_y)


## Vrai pendant un mouvement de caméra (travelling, recul, plongée).
func is_moving() -> bool:
	return not _glide.is_empty() or not _dive.is_empty()


func _select_index(index: int) -> void:
	_selected = index
	_refuge_selected = false
	_world.set_selected(index, false)
	_show_selection()


## Bouton « Moulin » : la carte descend jusqu'au refuge et le choisit.
func go_to_refuge() -> void:
	Audio.play(&"ui_select")
	scroll_to(MILL_POINT.y)
	select_refuge()


## Choisit le moulin, le refuge.
func select_refuge() -> void:
	_selected = -1
	_refuge_selected = true
	_world.set_selected(-1, true)
	_show_selection()


func _show_selection() -> void:
	var level := WorldData.level_at(_selected)
	_bottom.visible = (_selected >= 0 or _refuge_selected) and _dive.is_empty()
	_show_portraits(level.get("dead", []) if not _refuge_selected else [])
	_show_worn_rites(not _refuge_selected and not level.is_empty() and is_ready(level.get("id", &"")))
	if _refuge_selected:
		_bottom_title.text = "Le moulin"
		_bottom_text.text = "Le refuge, hors des murs : ce n'est pas un niveau, aucun mort n'y entre. Maud, frère Anselme et Tibert y vivent encore : on y achète, on y apprend."
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
	var target_y := _clamp_focus(_scene.node_positions[index].y)
	scroll_to(target_y)
	if not cinematics:
		return
	var goal := Vector3(_world.default_x(target_y), target_y, 1.0)
	var back := WorldData.level_index(arrived_from)
	if arrived_from == &"refuge":
		# Du moulin, la caméra recule depuis sa porte.
		_fade.color.a = 1.0
		_start_glide(Vector3(WorldMap.MILL_POINT.x, WorldMap.MILL_POINT.y, 0.25), Vector3(_world.default_x(FOCUS_MAX), FOCUS_MAX, 1.0), BACK_TIME)
	elif back >= 0:
		# D'un niveau : on en ressort, et la caméra recule.
		var from: Vector2 = _scene.node_positions[back]
		_fade.color.a = 1.0
		_start_glide(Vector3(from.x, from.y, 0.22), Vector3(_world.default_x(from.y), _clamp_focus(from.y), 1.0), BACK_TIME)
	else:
		# En ouvrant la partie : un lent travelling, du fleuve jusqu'au lieu,
		# face à la ville.
		_start_glide(Vector3(MapWorld.CENTER.x, MapScene.RIVER_TOP + 60.0, 1.15), goal, OPENING_TIME)


func _clamp_focus(value: float) -> float:
	return clampf(value, FOCUS_MIN, FOCUS_MAX)


func _apply_scroll() -> void:
	_world.zoom = _zoom
	if _focus_x >= 0.0:
		_world.focus_point(Vector2(_focus_x, _focus_y))
	else:
		_world.focus(_focus_y)


func _layout() -> void:
	_focus_y = _clamp_focus(_focus_y)
	_apply_scroll()


## Position à l'écran d'un point du plan de la carte (pour les essais).
func screen_of(plane: Vector2) -> Vector2:
	return _world.screen_of(plane)


func _on_view_input(event: InputEvent) -> void:
	if not _dive.is_empty():
		return
	# Un toucher interrompt le travelling.
	if not _glide.is_empty() and (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		_glide = {}
		_fade.color.a = 0.0
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_on_touch(event)
		return
	if event is InputEventMagnifyGesture:
		_set_zoom(_zoom / (event as InputEventMagnifyGesture).factor)
		return
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
				if button.ctrl_pressed:
					_set_zoom(_zoom * 0.9)
				else:
					_focus_y = _clamp_focus(_focus_y - 160.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.ctrl_pressed:
					_set_zoom(_zoom / 0.9)
				else:
					_focus_y = _clamp_focus(_focus_y + 160.0)
	elif event is InputEventMouseMotion and _dragging and _touches.size() < 2:
		var motion := event as InputEventMouseMotion
		_moved += absf(motion.relative.x) + absf(motion.relative.y)
		_focus_y = _clamp_focus(_focus_y - motion.relative.y * DRAG_RATIO * _zoom)
		_velocity = lerpf(_velocity, motion.relative.y * 60.0 * _zoom, 0.5)
		# On peut aussi longer les voies, à gauche et à droite.
		_focus_x = clampf(_current_x() - motion.relative.x * DRAG_RATIO * _zoom, 160.0, 1120.0)


## Deux doigts : on pince pour rapprocher ou éloigner la caméra.
func _on_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
		if _touches.size() == 2:
			_dragging = false
			_moved = TAP_SLOP
			_pinch_distance = _pinch_span()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touches[drag.index] = drag.position
		if _touches.size() == 2 and _pinch_distance > 1.0:
			var span := _pinch_span()
			_set_zoom(_zoom * _pinch_distance / maxf(span, 1.0))
			_pinch_distance = span


func _pinch_span() -> float:
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1])


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	_apply_scroll()


## Revient au lieu « ici », en vue d'ensemble.
func return_here() -> void:
	var index := WorldData.level_index(current_id())
	if index < 0:
		return
	var y := _clamp_focus(_scene.node_positions[index].y)
	_start_glide(Vector3(_current_x(), _focus_y, _zoom), Vector3(_world.default_x(y), y, 1.0), 0.9)


## Un toucher sur la carte : le point de la route le plus proche est choisi,
## sinon le moulin.
func _tap(at: Vector2) -> void:
	var found := _world.pick(at, PICK_RADIUS, MILL_RADIUS)
	if found >= 0:
		_select_index(found)
	elif found == -2:
		select_refuge()
	else:
		# Deux touchers dans le vide : retour au lieu « ici ».
		if _time - _last_empty_tap < DOUBLE_TAP:
			return_here()
			_last_empty_tap = -10.0
		else:
			_last_empty_tap = _time


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
	# Le moulin n'est pas une étape de la route : on s'y rend d'ici.
	var mill_button := Button.new()
	mill_button.text = "Moulin"
	Theatre.pill(mill_button, 21)
	mill_button.pressed.connect(go_to_refuge)
	top.add_child(mill_button)
	var training_button := Button.new()
	training_button.text = "Entraînement"
	Theatre.pill(training_button, 21, Theatre.MUTED)
	training_button.pressed.connect(func() -> void: training_requested.emit())
	top.add_child(training_button)
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
	# Les morts qu'on croise en ce lieu : portraits, ou silhouettes s'ils sont
	# encore inconnus.
	_portraits = HBoxContainer.new()
	_portraits.add_theme_constant_override("separation", 6)
	_portraits.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(_portraits)
	# À droite : les trois rites portés (on les choisit ici, avant d'entrer),
	# puis « Entrer ».
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(right)
	_rites_strip = HBoxContainer.new()
	_rites_strip.add_theme_constant_override("separation", 6)
	_rites_strip.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(_rites_strip)
	_enter_button = Button.new()
	_enter_button.text = "Entrer"
	Theatre.primary(_enter_button, 26)
	_enter_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_enter_button.pressed.connect(enter_selected)
	right.add_child(_enter_button)
	add_child(_bottom)

	# Le noir de la plongée et du retour.
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.02, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func _show_portraits(dead: Array) -> void:
	for child in _portraits.get_children():
		child.queue_free()
	for type_id: StringName in dead:
		var frame := PanelContainer.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(Theatre.DEEP, 0.9)
		box.border_color = Color(Theatre.AMBER, 0.4)
		box.set_border_width_all(2)
		frame.add_theme_stylebox_override("panel", box)
		var picture := TextureRect.new()
		picture.custom_minimum_size = Vector2(54.0, 54.0)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path := PORTRAITS + "%s.png" % type_id
		picture.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
		picture.modulate = Color.WHITE if Progress.has_met(type_id) else Color(0.0, 0.0, 0.0, 0.85)
		picture.tooltip_text = String(EnemyTypes.TYPES[type_id].get("name", type_id)) if Progress.has_met(type_id) else "?"
		frame.add_child(picture)
		_portraits.add_child(frame)


# --- Les rites qui s'ouvrent --------------------------------------------------

## Les rites ouverts que le joueur n'a pas encore vus présentés.
func pending_rites() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in Progress.unlocked_rites():
		if not Progress.has_seen(StringName("rite_%s" % id)):
			ids.append(id)
	return ids


## Présente le premier rite pas encore vu : son icône, son animation, ce
## qu'il fait, et où on le porte. Renvoie faux s'il n'y en a pas.
func show_next_rite() -> bool:
	if _rite_card != null and is_instance_valid(_rite_card):
		_rite_card.queue_free()
		_rite_card = null
	var pending := pending_rites()
	if pending.is_empty():
		return false
	var id := pending[0]
	Progress.mark_seen(StringName("rite_%s" % id))
	var rite := RiteData.get_rite(id)
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.0, 0.03, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	_rite_card = veil
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Theatre.panel_box(0.97))
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(560.0, 0.0)
	card.add_child(column)
	column.add_child(Theatre.label("Nouveau rite de combat", 22, Theatre.MUTED, GameFonts.italic()))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(SkillBook.RiteBadge.new(id, 40.0, true))
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	name_box.add_child(Theatre.label(rite["name"], 40, Theatre.AMBER, GameFonts.title()))
	var cost := int(rite["cost"])
	name_box.add_child(Theatre.label("%s · %d braise%s" % [rite["kind"], cost, "s" if cost > 1 else ""], 18, Theatre.EMBER, GameFonts.italic()))
	head.add_child(name_box)
	column.add_child(head)
	var preview := RitePreview.new(Vector2(560.0, 220.0))
	preview.rite = id
	column.add_child(preview)
	for line: String in [rite["text"], "Quand : " + String(rite["use"])]:
		var label := Theatre.label(line, 18, Theatre.CREAM if line == rite["text"] else Theatre.MUTED)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(560.0, 0.0)
		column.add_child(label)
	var hint := Theatre.label("Chaque Repos donné allume une braise. Les rites se portent dans le CARNET, onglet Combat.", 16, Theatre.MUTED, GameFonts.italic())
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(560.0, 0.0)
	column.add_child(hint)
	var ok := Button.new()
	ok.text = "Compris"
	Theatre.primary(ok, 22)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(func() -> void: show_next_rite())
	column.add_child(ok)
	Audio.play(&"page")
	return true


func rite_card_shown() -> bool:
	return _rite_card != null and is_instance_valid(_rite_card) and not _rite_card.is_queued_for_deletion()


# --- Les rites portés, choisis avant d'entrer ----------------------------------

## Montre les trois rites portés au-dessus d'« Entrer » ; toucher l'un d'eux
## ouvre la liste des rites pour le remplacer. Rien tant qu'aucun rite n'est
## ouvert.
func _show_worn_rites(shown: bool) -> void:
	for child in _rites_strip.get_children():
		child.queue_free()
	_rites_strip.visible = shown and not Progress.unlocked_rites().is_empty()
	if not _rites_strip.visible:
		return
	_rites_strip.add_child(Theatre.label("Rites :", 18, Theatre.MUTED, GameFonts.italic()))
	for i in RiteData.SLOTS:
		var id: StringName = Progress.rite_slots[i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.custom_minimum_size = Vector2(76.0, 0.0)
		var badge := SkillBook.RiteBadge.new(id, 26.0, id != &"")
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.pressed.connect(open_rite_picker.bind(i))
		cell.add_child(badge)
		var name_label := Theatre.label(RiteData.RITES[id]["name"] if id != &"" else "vide", 15, Theatre.CREAM if id != &"" else Theatre.MUTED)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)
		_rites_strip.add_child(cell)


## Les rites portés montrés dans la fiche du lieu (pour les essais).
func worn_rites_shown() -> int:
	if not _rites_strip.visible:
		return 0
	return _rites_strip.get_children().filter(func(child: Node) -> bool: return child is VBoxContainer and not child.is_queued_for_deletion()).size()


## Porte le rite `id` à l'emplacement `slot`, comme si le joueur l'avait
## choisi dans la liste.
func choose_rite(slot: int, id: StringName) -> bool:
	var done := Progress.equip_rite(id, slot)
	_close_rite_picker()
	_show_selection()
	return done


## La liste des rites ouverts, pour l'emplacement `slot` : une icône, le nom
## dessous, le coût ; celui qui est déjà porté là est cerclé d'or.
func open_rite_picker(slot: int) -> void:
	_close_rite_picker()
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.0, 0.03, 0.7)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_rite_picker())
	add_child(veil)
	_rite_picker = veil
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Theatre.panel_box(0.97))
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	column.add_child(Theatre.label("Rite %d : lequel porter ?" % (slot + 1), 30, Theatre.AMBER, GameFonts.title()))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for id in Progress.unlocked_rites():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.custom_minimum_size = Vector2(104.0, 0.0)
		var badge := SkillBook.RiteBadge.new(id, 40.0, true, Progress.rite_slots[slot] == id)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.pressed.connect(choose_rite.bind(slot, id))
		cell.add_child(badge)
		var name_label := Theatre.label(RiteData.RITES[id]["name"], 17)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)
		var cost := RiteData.cost(id)
		var cost_label := Theatre.label("◆".repeat(cost), 13, Theatre.EMBER)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(cost_label)
		grid.add_child(cell)
	var hint := Theatre.label("Leurs animations sont dans le CARNET, onglet Combat. En plein niveau, les rites portés ne changent plus.", 16, Theatre.MUTED, GameFonts.italic())
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(540.0, 0.0)
	column.add_child(hint)
	var cancel := Button.new()
	cancel.text = "Garder"
	Theatre.pill(cancel, 20, Theatre.MUTED)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel.pressed.connect(_close_rite_picker)
	column.add_child(cancel)
	Audio.play(&"page")


func _close_rite_picker() -> void:
	if _rite_picker != null and is_instance_valid(_rite_picker):
		_rite_picker.queue_free()
	_rite_picker = null


func rite_picker_shown() -> bool:
	return _rite_picker != null and is_instance_valid(_rite_picker) and not _rite_picker.is_queued_for_deletion()


## Les portraits montrés dans la fiche du lieu (pour les essais).
func portrait_count() -> int:
	return _portraits.get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion()).size()


func open_book() -> void:
	if _book != null and is_instance_valid(_book):
		return
	_book = SkillBook.new()
	add_child(_book)
