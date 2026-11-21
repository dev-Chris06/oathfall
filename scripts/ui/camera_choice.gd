class_name CameraChoice
extends RefCounted
## La ligne « Caméra » des options et du menu pause : un bouton qui passe d'une
## vue à l'autre (Classique, Épaule, Première personne) et garde le choix.


static func row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var name_label := Theatre.label("Caméra", 22, Theatre.CREAM)
	name_label.custom_minimum_size = Vector2(130.0, 0.0)
	row.add_child(name_label)
	var button := Button.new()
	button.name = "CameraButton"
	button.text = GameCamera.mode_name(GameCamera.mode)
	Theatre.pill(button, 22)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		GameCamera.next_mode()
		button.text = GameCamera.mode_name(GameCamera.mode)
		Audio.save_settings()
		Audio.play(&"ui_select"))
	row.add_child(button)
	return row
