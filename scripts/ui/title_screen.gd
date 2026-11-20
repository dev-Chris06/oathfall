class_name TitleScreen
extends Control
## L'écran-titre : Continuer, Nouvelle partie, Options. Sur la même nuit que la
## carte, avec la ville à l'horizon et le moulin éclairé au premier plan.

signal continue_pressed
## Le joueur a choisi de commencer une partie neuve (confirmée s'il y avait
## une partie en cours).
signal new_game_pressed

var _menu: VBoxContainer
var _continue_button: Button
var _new_button: Button
var _confirm: PanelContainer
var _options: PanelContainer
var _credits: PanelContainer
var _update: PanelContainer
var _update_text: Label
var _download_button: Button
var _update_check: UpdateCheck
var _info: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(NightSky.new())
	var backdrop := Backdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var title := Theatre.label("Oathfall", 150, Theatre.AMBER, GameFonts.title())
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 26.0
	title.offset_left = -400.0
	title.offset_right = 400.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var subtitle := Theatre.label("Nul ne mourra plus en Orvana.", 28, Theatre.CREAM, GameFonts.italic())
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_top = 196.0
	subtitle.offset_left = -400.0
	subtitle.offset_right = 400.0
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 14)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu.offset_left = -190.0
	_menu.offset_right = 190.0
	_menu.offset_top = -10.0
	_menu.offset_bottom = 320.0
	add_child(_menu)
	_continue_button = _button("Continuer", true)
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	_info = Theatre.label("", 18, Theatre.MUTED, GameFonts.italic())
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(_info)
	_new_button = _button("Nouvelle partie", false)
	_new_button.pressed.connect(press_new_game)
	var options := _button("Options", false)
	options.pressed.connect(func() -> void: _show_panel(_options))
	var update := _button("Mise à jour", false)
	update.pressed.connect(check_update)

	var version := Theatre.label("Oathfall %s" % ProjectSettings.get_setting("application/config/version", "?"),
		16, Color(Theatre.MUTED, 0.7))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -22.0
	version.offset_bottom = -16.0
	add_child(version)

	_confirm = _panel("Effacer la partie en cours ?", "Tes niveaux, ton or et tes rites seront perdus.", [
		["Oui, recommencer", confirm_new_game], ["Non", func() -> void: _show_panel(null)]])
	_options = _panel("Options", "", [
		["Crédits", func() -> void: _show_panel(_credits)],
		["Effacer la sauvegarde", erase_save],
		["Retour", func() -> void: _show_panel(null)]])
	_add_volume_sliders(_options)
	_credits = _panel("Crédits",
		"Modèles : KayKit, de Kay Lousberg (CC0).\nPolices : Standard Blackletter, de David Grigg, et MFB Oldstyle (CC0).\nSons : Kenney (CC0). Musiques et bruitages lourds : synthèse faite pour le jeu.\nMoteur : Godot Engine (licence MIT).",
		[["Retour", func() -> void: _show_panel(_options)]])
	_update = _panel("Mise à jour", " ", [
		["Télécharger", UpdateCheck.open_download],
		["Retour", func() -> void: _show_panel(null)]])
	var update_column := _update.get_child(0) as VBoxContainer
	_update_text = update_column.get_child(1) as Label
	_download_button = update_column.get_child(2) as Button
	_update_check = UpdateCheck.new()
	_update_check.finished.connect(show_update_result)
	add_child(_update_check)
	refresh()


## Met à jour ce qui dépend de la partie : Continuer n'existe que s'il y en a une.
func refresh() -> void:
	var has_game := Progress.has_progress()
	_continue_button.visible = has_game
	_info.visible = has_game
	if has_game:
		var done := 0
		for level: Dictionary in WorldData.chapter_levels():
			if Progress.is_completed(level["id"]):
				done += 1
		_info.text = "Niveau %d — %d sur %d niveaux terminés" % [Progress.hero_level, done, WorldData.chapter_levels().size()]


func has_continue() -> bool:
	return _continue_button.visible


func press_continue() -> void:
	continue_pressed.emit()


## « Nouvelle partie » : demande confirmation s'il y a une partie en cours.
func press_new_game() -> void:
	if Progress.has_progress():
		_show_panel(_confirm)
	else:
		confirm_new_game()


func is_confirming() -> bool:
	return _confirm.visible


func confirm_new_game() -> void:
	new_game_pressed.emit()


## « Mise à jour » : cherche une version plus récente sur la page du jeu.
func check_update() -> void:
	_update_text.text = "Recherche d'une nouvelle version…"
	_download_button.visible = false
	_show_panel(_update)
	_update_check.start()


## Affiche le résultat de la recherche : `state` vaut "ok", "new" ou "error".
func show_update_result(state: String, remote: String) -> void:
	var local := UpdateCheck.local_version()
	match state:
		"new":
			_update_text.text = "La version %s est disponible (tu as la %s).\nTélécharge-la, puis installe-la par-dessus : ta partie est gardée." % [remote, local]
		"ok":
			_update_text.text = "Ton jeu est à jour (version %s)." % local
		_:
			_update_text.text = "Impossible de joindre la page du jeu. Vérifie ta connexion, puis réessaie."
	_download_button.visible = state == "new"


func update_text() -> String:
	return _update_text.text


## Efface la partie en cours, sans en commencer une autre.
func erase_save() -> void:
	Progress.delete_save()
	Progress.reset()
	refresh()
	_show_panel(null)


func _show_panel(panel: Control) -> void:
	for candidate: Control in [_confirm, _options, _credits, _update]:
		candidate.visible = candidate == panel
	_menu.visible = panel == null


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(380.0, 56.0)
	if primary:
		Theatre.primary(button, 28)
	else:
		Theatre.pill(button, 24)
	_menu.add_child(button)
	return button


## Un petit cadre au centre : un titre, un texte, des boutons [libellé, action].
func _panel(heading: String, text: String, buttons: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Theatre.panel_box(0.96))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = 0.0
	panel.offset_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(Theatre.label(heading, 46, Theatre.AMBER, GameFonts.title()))
	if text != "":
		var body := Theatre.label(text, 22, Theatre.CREAM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(600.0, 0.0)
		column.add_child(body)
	for entry: Array in buttons:
		var button := Button.new()
		button.text = entry[0]
		Theatre.pill(button, 22)
		button.pressed.connect(entry[1])
		column.add_child(button)
	add_child(panel)
	return panel


## Deux curseurs de volume, sous le titre du panneau des options.
func _add_volume_sliders(panel: PanelContainer) -> void:
	var column := panel.get_child(0) as VBoxContainer
	var rows := [["Musique", Audio.music_volume, Audio.set_music_volume],
		["Sons", Audio.sfx_volume, Audio.set_sfx_volume]]
	var at := 1
	for entry: Array in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var name_label := Theatre.label(entry[0], 22, Theatre.CREAM)
		name_label.custom_minimum_size = Vector2(130.0, 0.0)
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = entry[1]
		slider.custom_minimum_size = Vector2(420.0, 40.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(entry[2])
		slider.drag_ended.connect(func(_changed: bool) -> void:
			Audio.save_settings()
			Audio.play(&"ui_select"))
		row.add_child(slider)
		column.add_child(row)
		column.move_child(row, at)
		at += 1


## La ville à l'horizon et le moulin, en silhouettes.
class Backdrop extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := maxf(size.x, 1280.0)
		var h := maxf(size.y, 720.0)
		# La ville, au loin : trois étages et des tours.
		var far := Color(0.05, 0.06, 0.125)
		var ridge := PackedVector2Array([Vector2(0, h), Vector2(0, h - 190), Vector2(w * 0.28, h - 205),
			Vector2(w * 0.4, h - 250), Vector2(w * 0.5, h - 330), Vector2(w * 0.62, h - 250),
			Vector2(w * 0.74, h - 215), Vector2(w, h - 195), Vector2(w, h)])
		draw_colored_polygon(ridge, far)
		for x in [0.38, 0.45, 0.5, 0.55, 0.62]:
			var tower_h := 60.0 + 90.0 * (1.0 - absf(x - 0.5) * 3.0)
			draw_rect(Rect2(w * x - 9.0, h - 330.0 - tower_h * 0.4 + 40.0, 18.0, tower_h), Color(0.035, 0.045, 0.1))
		for k in 22:
			var wx := w * (0.2 + 0.6 * float(k) / 22.0)
			draw_rect(Rect2(wx, h - 215.0 - 70.0 * sin(float(k) * 0.9) * 0.4 - 20.0, 4.0, 7.0), Color(1.0, 0.7, 0.28, 0.8))
		# Une colline plus proche, sombre.
		var near := Color(0.03, 0.03, 0.06)
		draw_colored_polygon(PackedVector2Array([Vector2(0, h), Vector2(0, h - 110), Vector2(w * 0.3, h - 90),
			Vector2(w * 0.7, h - 120), Vector2(w, h - 80), Vector2(w, h)]), near)
		# Le moulin, à gauche, une fenêtre allumée.
		var mx := w * 0.14
		var base := h - 100.0
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 34, base), Vector2(mx + 34, base),
			Vector2(mx + 22, base - 150), Vector2(mx - 22, base - 150)]), near)
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 30, base - 150), Vector2(mx + 30, base - 150),
			Vector2(mx, base - 200)]), near)
		draw_rect(Rect2(mx - 6.0, base - 95.0, 12.0, 20.0), Color(1.0, 0.72, 0.3))
		var hub := Vector2(mx, base - 120.0)
		for a in 4:
			var angle := deg_to_rad(25.0 + a * 90.0)
			var tip := hub + Vector2(cos(angle), sin(angle)) * 100.0
			draw_line(hub, tip, near, 5.0)
			var side := Vector2(-sin(angle), cos(angle)) * 22.0
			var start := hub.lerp(tip, 0.35)
			draw_colored_polygon(PackedVector2Array([start, tip, tip + side, start + side]), near)
