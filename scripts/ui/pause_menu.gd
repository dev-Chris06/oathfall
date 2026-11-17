class_name PauseMenu
extends CanvasLayer
## Le menu de pause, ouvert par le bouton à côté du carnet (ou Échap, P). Le
## jeu s'arrête tant qu'il est ouvert : Reprendre, régler la musique et les
## sons, ou quitter le niveau (après confirmation).

signal resumed
signal leave_requested

var _leave_button: Button
var _confirm_row: HBoxContainer
var _asking := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.0, 0.02, 0.62)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Theatre.panel_box(0.95))
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.custom_minimum_size = Vector2(520.0, 0.0)
	panel.add_child(column)

	var title := Theatre.label("Pause", 44, Theatre.AMBER, GameFonts.title())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var resume := Button.new()
	resume.text = "Reprendre"
	Theatre.primary(resume, 28)
	resume.pressed.connect(close_menu)
	column.add_child(resume)

	_add_volume_row(column, "Musique", Audio.music_volume, Audio.set_music_volume)
	_add_volume_row(column, "Sons", Audio.sfx_volume, Audio.set_sfx_volume)

	_leave_button = Button.new()
	_leave_button.text = "Quitter le niveau"
	Theatre.pill(_leave_button, 22, Theatre.MUTED)
	_leave_button.pressed.connect(_ask)
	column.add_child(_leave_button)

	_confirm_row = HBoxContainer.new()
	_confirm_row.add_theme_constant_override("separation", 16)
	_confirm_row.visible = false
	var yes := Button.new()
	yes.text = "Oui, quitter"
	Theatre.pill(yes, 22, Theatre.EMBER)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(confirm_leave)
	_confirm_row.add_child(yes)
	var no := Button.new()
	no.text = "Non"
	Theatre.pill(no, 22)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_cancel)
	_confirm_row.add_child(no)
	column.add_child(_confirm_row)


func _add_volume_row(column: VBoxContainer, name_text: String, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var name_label := Theatre.label(name_text, 22, Theatre.CREAM)
	name_label.custom_minimum_size = Vector2(130.0, 0.0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(300.0, 40.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(setter)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		Audio.save_settings()
		Audio.play(&"ui_select"))
	row.add_child(slider)
	column.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_ESCAPE or key.physical_keycode == KEY_P:
			get_viewport().set_input_as_handled()
			close_menu()


## Demande confirmation avant de quitter le niveau.
func _ask() -> void:
	_asking = true
	_leave_button.visible = false
	_confirm_row.visible = true


func _cancel() -> void:
	_asking = false
	_leave_button.visible = true
	_confirm_row.visible = false


func is_asking() -> bool:
	return _asking


func confirm_leave() -> void:
	get_tree().paused = false
	leave_requested.emit()
	queue_free()


func close_menu() -> void:
	get_tree().paused = false
	resumed.emit()
	queue_free()
