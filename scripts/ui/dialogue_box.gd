class_name DialogueBox
extends CanvasLayer
## Une réplique à l'écran : le nom de celui qui parle, son texte, et de quoi
## continuer. Le jeu est en pause tant qu'elle est ouverte. À la dernière
## réplique, les `actions` s'affichent (voir `open`) ; `finished` donne celle
## qu'on a choisie.

signal finished(action: StringName)

var _root: Control
var _speaker: Label
var _text: Label
var _buttons: HBoxContainer
var _lines: Array = []
var _actions: Array = []
var _index := 0
var _tween: Tween


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Toucher la boîte fait avancer.
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			advance())
	add_child(_root)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Theatre.panel_box(0.96))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 40.0
	panel.offset_right = -40.0
	panel.offset_bottom = -26.0
	panel.offset_top = -40.0
	_root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_speaker = Theatre.label("", 38, Theatre.AMBER, GameFonts.title())
	column.add_child(_speaker)
	_text = Theatre.label("", 25)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(900.0, 84.0)
	column.add_child(_text)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 14)
	column.add_child(_buttons)
	_show_line()


## Ouvre la boîte. `lines` : les répliques (texte). `actions` : de quoi
## choisir à la fin, des {id, label} ; sans choix, un simple « Fermer ».
func open(speaker: String, lines: Array, actions: Array = []) -> void:
	_lines = lines
	_actions = actions
	_index = 0
	if is_inside_tree():
		get_tree().paused = true
	if is_inside_tree() and _speaker != null:
		_speaker.text = speaker
		_show_line()
	else:
		_pending_speaker = speaker


var _pending_speaker := ""


func _show_line() -> void:
	if _speaker == null:
		return
	if _pending_speaker != "":
		_speaker.text = _pending_speaker
		_pending_speaker = ""
	if _lines.is_empty():
		return
	_text.text = _lines[_index]
	# Le texte se dévoile ; un toucher le montre en entier.
	_text.visible_ratio = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, clampf(float(_text.text.length()) * 0.018, 0.2, 1.6))
	for child in _buttons.get_children():
		child.queue_free()
	if _index < _lines.size() - 1:
		var next := Button.new()
		next.text = "Suite"
		Theatre.pill(next, 20)
		next.pressed.connect(advance)
		_buttons.add_child(next)
	else:
		for action: Dictionary in _actions:
			var button := Button.new()
			button.text = action["label"]
			var id: StringName = action["id"]
			Theatre.pill(button, 20, Theatre.AMBER if id != &"leave" else Theatre.MUTED)
			button.pressed.connect(close.bind(id))
			_buttons.add_child(button)
		if _actions.is_empty():
			var done := Button.new()
			done.text = "Fermer"
			Theatre.pill(done, 20)
			done.pressed.connect(close.bind(&"leave"))
			_buttons.add_child(done)


## Passe à la réplique suivante ; si le texte s'écrit encore, l'affiche en entier.
func advance() -> void:
	if _text.visible_ratio < 1.0:
		if _tween != null:
			_tween.kill()
		_text.visible_ratio = 1.0
		return
	if _index < _lines.size() - 1:
		_index += 1
		_show_line()


func close(action: StringName = &"leave") -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = false
	finished.emit(action)
	queue_free()


func is_last_line() -> bool:
	return _index >= _lines.size() - 1
