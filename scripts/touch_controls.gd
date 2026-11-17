class_name TouchControls
extends CanvasLayer
## Commandes du joueur : joystick tactile à gauche, boutons à droite, et
## clavier pour tester sur PC (ZQSD ou flèches, J ou Espace pour frapper,
## K ou Maj pour esquiver, E pour le Repos). Le reste du jeu ne lit que
## `move`, `rite_held` et les signaux.

signal attack_pressed
signal dodge_pressed
signal book_pressed
signal pause_pressed
signal flask_pressed

const STICK_RADIUS := 95.0
const ATTACK_RADIUS := 88.0
const DODGE_RADIUS := 62.0
const RITE_RADIUS := 66.0
const BOOK_RADIUS := 44.0
const FLASK_RADIUS := 50.0
const PAUSE_RADIUS := 38.0

## Direction voulue, de longueur 0 à 1. x vers la droite, y vers le bas de l'écran.
var move := Vector2.ZERO
## Vrai tant que le joueur maintient le bouton du Repos.
var rite_held := false
## Renseignés par le héros : le bouton du Repos n'apparaît que près d'un corps,
## et son anneau se remplit pendant le rite.
var rite_available := false
## Ce qu'écrit le bouton : « REPOS » près d'un corps, « COUPER » près d'une corde.
var rite_label := "REPOS"
## Fioles portées : le bouton FIOLE n'apparaît que s'il en reste.
var flask_count := 0
var rite_progress := 0.0
## Vrai quand des points de compétence attendent : le bouton du carnet luit.
var book_alert := false
## Part du temps de recharge de l'esquive déjà écoulée (1 : prête).
var dodge_ready := 1.0
## Entrées imposées par un script (tests, démonstrations).
var simulated_move := Vector2.ZERO
var simulated_rite := false

var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_vector := Vector2.ZERO
var _rite_index := -1
var _attack_flash := 0.0
var _dodge_flash := 0.0
var _pad: Control
## La légende du bouton d'action (« REPOS », « PARLER »…), sous lui.
var _caption: Label


func _ready() -> void:
	layer = 10
	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	_caption = Theatre.label("", 22, PALE)
	_caption.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.03, 0.95))
	_caption.add_theme_constant_override("outline_size", 7)
	_caption.visible = false
	_pad.add_child(_caption)


func _process(delta: float) -> void:
	var keys := Vector2(
		float(_key(KEY_D) or _key(KEY_RIGHT)) - float(_key(KEY_A) or _key(KEY_LEFT)),
		float(_key(KEY_S) or _key(KEY_DOWN)) - float(_key(KEY_W) or _key(KEY_UP)))
	move = (_stick_vector + keys + simulated_move).limit_length(1.0)
	rite_held = _rite_index != -1 or _key(KEY_E) or simulated_rite

	_caption.visible = rite_available and rite_label != ""
	if _caption.visible:
		_caption.text = rite_label
		var size := _caption.get_minimum_size()
		_caption.position = _rite_center() + Vector2(-size.x / 2.0, -RITE_RADIUS - 14.0 - size.y)

	_attack_flash = maxf(0.0, _attack_flash - delta * 5.0)
	_dodge_flash = maxf(0.0, _dodge_flash - delta * 5.0)
	_pad.queue_redraw()


func _key(code: Key) -> bool:
	# Position physique des touches : ZQSD en AZERTY, WASD en QWERTY.
	return Input.is_physical_key_pressed(code)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.position.distance_to(_pause_center()) <= PAUSE_RADIUS * 1.35:
				_release_all()
				pause_pressed.emit()
			elif touch.position.distance_to(_book_center()) <= BOOK_RADIUS * 1.3:
				_release_all()
				book_pressed.emit()
			elif touch.position.distance_to(_attack_center()) <= ATTACK_RADIUS * 1.25:
				press_attack()
			elif flask_count > 0 and touch.position.distance_to(_flask_center()) <= FLASK_RADIUS * 1.3:
				flask_pressed.emit()
			elif touch.position.distance_to(_dodge_center()) <= DODGE_RADIUS * 1.3:
				press_dodge()
			elif rite_available and touch.position.distance_to(_rite_center()) <= RITE_RADIUS * 1.3:
				_rite_index = touch.index
			elif touch.position.x < _pad.size.x * 0.5 and _stick_index == -1:
				_stick_index = touch.index
				_stick_origin = touch.position
				_stick_vector = Vector2.ZERO
		else:
			if touch.index == _stick_index:
				_stick_index = -1
				_stick_vector = Vector2.ZERO
			if touch.index == _rite_index:
				_rite_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_index:
			_stick_vector = ((drag.position - _stick_origin) / STICK_RADIUS).limit_length(1.0)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.physical_keycode:
				KEY_J, KEY_SPACE:
					press_attack()
				KEY_K, KEY_SHIFT:
					press_dodge()
				KEY_F:
					flask_pressed.emit()
				KEY_C, KEY_TAB:
					_release_all()
					book_pressed.emit()
				KEY_ESCAPE, KEY_P:
					_release_all()
					pause_pressed.emit()


func press_attack() -> void:
	_attack_flash = 1.0
	attack_pressed.emit()


func press_dodge() -> void:
	_dodge_flash = 1.0
	dodge_pressed.emit()


## Oublie les doigts posés : un menu va s'ouvrir par-dessus le jeu.
func _release_all() -> void:
	_stick_index = -1
	_stick_vector = Vector2.ZERO
	_rite_index = -1


func _pause_center() -> Vector2:
	return Vector2(_pad.size.x - 80.0 - 98.0, 70.0)


func _flask_center() -> Vector2:
	return Vector2(_pad.size.x - 318.0, _pad.size.y - 232.0)


func _book_center() -> Vector2:
	return Vector2(_pad.size.x - 80.0, 70.0)


func _attack_center() -> Vector2:
	return Vector2(_pad.size.x - 150.0, _pad.size.y - 150.0)


func _dodge_center() -> Vector2:
	return Vector2(_pad.size.x - 335.0, _pad.size.y - 105.0)


func _rite_center() -> Vector2:
	return Vector2(_pad.size.x - 140.0, _pad.size.y - 345.0)


## Les icônes, dessinées en code : une épée, une roulade, une fiole, une
## pierre tombale (le Repos), une bulle, une porte, des ciseaux, un livre.
const PALE := Color(0.94, 0.89, 0.76)
const ACCENT_ATTACK := Color(0.9, 0.3, 0.2)
const ACCENT_DODGE := Color(0.62, 0.76, 0.95)
const ACCENT_FLASK := Color(0.42, 0.88, 0.66)
const ACCENT_REST := Color(0.62, 0.82, 1.0)
const ACCENT_BOOK := Color(0.95, 0.78, 0.42)
const ACCENT_PAUSE := Color(0.7, 0.68, 0.82)


func _draw_pad() -> void:
	# Joystick : il apparaît là où le pouce se pose, sinon à sa place de repos.
	var base := _stick_origin if _stick_index != -1 else Vector2(175.0, _pad.size.y - 175.0)
	_pad.draw_circle(base, STICK_RADIUS, Color(0.05, 0.06, 0.12, 0.34))
	_pad.draw_arc(base, STICK_RADIUS, 0.0, TAU, 56, Color(ACCENT_BOOK, 0.55), 3.0, true)
	_pad.draw_arc(base, STICK_RADIUS * 0.55, 0.0, TAU, 40, Color(ACCENT_BOOK, 0.18), 1.5, true)
	for k in 4:
		var tick := base + Vector2.from_angle(k * PI / 2.0) * STICK_RADIUS
		_diamond(tick, 5.0, Color(ACCENT_BOOK, 0.85))
	var knob := base + _stick_vector * STICK_RADIUS
	_pad.draw_circle(knob + Vector2(0.0, 3.0), 38.0, Color(0.0, 0.0, 0.0, 0.3))
	_pad.draw_circle(knob, 38.0, Color(0.12, 0.13, 0.2, 0.78))
	_pad.draw_circle(knob, 30.0, Color(PALE, 0.28))
	_pad.draw_arc(knob, 38.0, 0.0, TAU, 40, Color(ACCENT_BOOK, 0.9), 3.0, true)

	_draw_button(_attack_center(), ATTACK_RADIUS, ACCENT_ATTACK, _attack_flash, &"sword")
	var dodge_wait := dodge_ready < 1.0
	_draw_button(_dodge_center(), DODGE_RADIUS, ACCENT_DODGE, _dodge_flash, &"roll",
		dodge_ready if dodge_wait else -1.0, 0.5 if dodge_wait else 0.0)

	if flask_count > 0:
		_draw_button(_flask_center(), FLASK_RADIUS, ACCENT_FLASK, 0.0, &"flask", -1.0, 0.0, str(flask_count))
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0) if book_alert else 0.0
	_draw_button(_book_center(), BOOK_RADIUS, ACCENT_BOOK, glow * 0.5, &"book", -1.0, 0.0, "", "", glow if book_alert else -1.0)
	_draw_button(_pause_center(), PAUSE_RADIUS, ACCENT_PAUSE, 0.0, &"pause")

	if rite_available:
		var held := 1.0 if rite_held else 0.0
		var kind: StringName = {"COUPER": &"cut", "PARLER": &"talk", "PARTIR": &"leave"}.get(rite_label, &"rest")
		_draw_button(_rite_center(), RITE_RADIUS, ACCENT_REST, held, kind,
			rite_progress if rite_progress > 0.0 else -1.0, 0.0, "", rite_label)


## Un bouton : ombre, disque sombre, double liseré aux losanges, icône. `progress`
## (0 à 1) trace un anneau autour ; `dim` assombrit (recharge) ; `badge` écrit
## un chiffre ; `caption` une légende dessous ; `alert` un point d'exclamation.
func _draw_button(center: Vector2, radius: float, accent: Color, pressed: float, kind: StringName,
		progress := -1.0, dim := 0.0, badge := "", caption := "", alert := -1.0) -> void:
	_pad.draw_circle(center + Vector2(0.0, 5.0), radius + 3.0, Color(0.0, 0.0, 0.0, 0.36))
	var body := Color(0.045, 0.05, 0.1, 0.86).lerp(Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, 0.92), pressed * 0.75)
	_pad.draw_circle(center, radius, body)
	_pad.draw_circle(center, radius - 6.0, Color(accent.r, accent.g, accent.b, 0.1 + 0.22 * pressed))
	_pad.draw_arc(center, radius - 7.0, 0.0, TAU, 48, Color(accent, 0.4), 1.5, true)
	_pad.draw_arc(center, radius, 0.0, TAU, 56, Color(accent, 0.95), 4.0, true)
	_pad.draw_arc(center, radius + 4.5, 0.0, TAU, 56, Color(PALE, 0.5), 1.5, true)
	for k in 4:
		_diamond(center + Vector2.from_angle(k * PI / 2.0 - PI / 4.0) * (radius + 2.0), 3.5, Color(PALE, 0.9))
	var scale := radius * 0.5 * (1.0 - 0.1 * pressed)
	_draw_icon(kind, center, scale, accent)
	if dim > 0.0:
		_pad.draw_circle(center, radius - 2.0, Color(0.0, 0.0, 0.03, dim))
	if progress >= 0.0:
		_pad.draw_arc(center, radius + 10.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(progress, 0.0, 1.0),
			56, Color(0.88, 0.95, 1.0, 0.95), 6.0, true)
	var font := GameFonts.text()
	if badge != "":
		var at := center + Vector2(radius * 0.72, radius * 0.72)
		_pad.draw_circle(at, 15.0, Color(0.03, 0.03, 0.07, 0.95))
		_pad.draw_arc(at, 15.0, 0.0, TAU, 24, Color(accent, 0.95), 2.5, true)
		var size := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19)
		_pad.draw_string(font, at + Vector2(-size.x / 2.0, 7.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19, Color(1, 1, 1, 0.95))
	if alert >= 0.0:
		var at := center + Vector2(radius * 0.74, -radius * 0.74)
		_pad.draw_circle(at, 13.0 + 2.0 * alert, Color(ACCENT_BOOK, 0.95))
		_pad.draw_string(font, at + Vector2(-4.0, 8.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.1, 0.05, 0.02))


func _diamond(at: Vector2, size: float, color: Color) -> void:
	_pad.draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -size), at + Vector2(size, 0.0),
		at + Vector2(0.0, size), at + Vector2(-size, 0.0)]), color)


## Les points d'une forme (en unités d'icône), tournés, mis à l'échelle et placés.
func _shape(points: Array, c: Vector2, s: float, angle := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(c + p.rotated(angle) * s)
	return out


func _draw_icon(kind: StringName, c: Vector2, s: float, accent: Color) -> void:
	var dark := Color(0.04, 0.045, 0.09)
	match kind:
		&"sword":
			var a := PI / 4.0
			_pad.draw_colored_polygon(_shape([Vector2(-0.1, 0.25), Vector2(-0.1, -0.78), Vector2(0.0, -1.02),
				Vector2(0.1, -0.78), Vector2(0.1, 0.25)], c, s, a), PALE)
			_pad.draw_line(c + Vector2(0.0, 0.2).rotated(a) * s, c + Vector2(0.0, -0.9).rotated(a) * s, Color(accent, 0.7), 1.5)
			_pad.draw_colored_polygon(_shape([Vector2(-0.44, 0.25), Vector2(0.44, 0.25), Vector2(0.44, 0.38), Vector2(-0.44, 0.38)], c, s, a), accent.lightened(0.25))
			_pad.draw_colored_polygon(_shape([Vector2(-0.07, 0.38), Vector2(0.07, 0.38), Vector2(0.07, 0.78), Vector2(-0.07, 0.78)], c, s, a), Color(0.55, 0.36, 0.2))
			_pad.draw_circle(c + Vector2(0.0, 0.88).rotated(a) * s, 0.13 * s, accent.lightened(0.25))
		&"roll":
			var r := 0.72 * s
			_pad.draw_arc(c, r, PI * 0.12, PI * 1.5, 28, PALE, 0.17 * s, true)
			var end := PI * 1.5
			var tip_at := c + Vector2.from_angle(end) * r
			var tangent := Vector2(-sin(end), cos(end))
			var normal := Vector2.from_angle(end)
			_pad.draw_colored_polygon(PackedVector2Array([tip_at + tangent * 0.4 * s, tip_at + normal * 0.3 * s, tip_at - normal * 0.3 * s]), PALE)
			_pad.draw_arc(c, r * 0.5, PI * 1.12, PI * 2.5, 20, Color(PALE, 0.55), 0.1 * s, true)
			_pad.draw_circle(c, 0.16 * s, accent)
		&"flask":
			_pad.draw_colored_polygon(_shape([Vector2(-0.2, -0.62), Vector2(0.2, -0.62), Vector2(0.2, -0.12), Vector2(-0.2, -0.12)], c, s), Color(PALE, 0.85))
			_pad.draw_circle(c + Vector2(0.0, 0.32) * s, 0.58 * s, Color(PALE, 0.9))
			_pad.draw_circle(c + Vector2(0.0, 0.36) * s, 0.46 * s, accent)
			_pad.draw_colored_polygon(_shape([Vector2(-0.46, 0.15), Vector2(0.46, 0.15), Vector2(0.52, 0.3), Vector2(-0.52, 0.3)], c, s), Color(PALE, 0.9))
			_pad.draw_colored_polygon(_shape([Vector2(-0.26, -0.84), Vector2(0.26, -0.84), Vector2(0.26, -0.62), Vector2(-0.26, -0.62)], c, s), Color(0.55, 0.36, 0.2))
			_pad.draw_arc(c + Vector2(-0.12, 0.38) * s, 0.28 * s, PI * 0.9, PI * 1.45, 8, Color(1, 1, 1, 0.7), 0.07 * s, true)
		&"rest", &"pierre":
			var stone := [Vector2(-0.5, 0.85), Vector2(0.5, 0.85)]
			for i in range(0, 9):
				var ang := -PI * i / 8.0
				stone.append(Vector2(0.5 * cos(ang), -0.2 + 0.5 * sin(ang)))
			_pad.draw_colored_polygon(_shape(stone, c, s), PALE)
			_pad.draw_line(c + Vector2(0.0, -0.5) * s, c + Vector2(0.0, 0.3) * s, dark, 0.14 * s)
			_pad.draw_line(c + Vector2(-0.24, -0.18) * s, c + Vector2(0.24, -0.18) * s, dark, 0.14 * s)
			_pad.draw_line(c + Vector2(-0.8, 0.85) * s, c + Vector2(0.8, 0.85) * s, Color(accent, 0.9), 0.1 * s)
		&"talk":
			_pad.draw_colored_polygon(_shape([Vector2(-0.82, -0.6), Vector2(0.82, -0.6), Vector2(0.82, 0.3), Vector2(-0.82, 0.3)], c, s), PALE)
			_pad.draw_colored_polygon(_shape([Vector2(-0.45, 0.3), Vector2(0.0, 0.3), Vector2(-0.5, 0.78)], c, s), PALE)
			for k in 3:
				_pad.draw_circle(c + Vector2(-0.4 + 0.4 * k, -0.15) * s, 0.1 * s, dark)
		&"leave":
			var door := [Vector2(-0.6, -0.82), Vector2(0.05, -0.82), Vector2(0.05, 0.82), Vector2(-0.6, 0.82), Vector2(-0.6, -0.82)]
			_pad.draw_polyline(_shape(door, c, s), PALE, 0.12 * s, true)
			_pad.draw_line(c + Vector2(-0.1, 0.0) * s, c + Vector2(0.62, 0.0) * s, PALE, 0.14 * s)
			_pad.draw_colored_polygon(_shape([Vector2(0.5, -0.3), Vector2(0.92, 0.0), Vector2(0.5, 0.3)], c, s), PALE)
		&"cut":
			_pad.draw_line(c + Vector2(0.0, 0.1) * s, c + Vector2(-0.62, -0.88) * s, PALE, 0.14 * s)
			_pad.draw_line(c + Vector2(0.0, 0.1) * s, c + Vector2(0.62, -0.88) * s, PALE, 0.14 * s)
			for side: float in [-1.0, 1.0]:
				_pad.draw_arc(c + Vector2(0.4 * side, 0.62) * s, 0.26 * s, 0.0, TAU, 18, PALE, 0.1 * s, true)
				_pad.draw_line(c + Vector2(0.0, 0.1) * s, c + Vector2(0.28 * side, 0.4) * s, PALE, 0.12 * s)
			_pad.draw_circle(c + Vector2(0.0, 0.1) * s, 0.1 * s, accent)
		&"book":
			_pad.draw_colored_polygon(_shape([Vector2(-0.86, -0.55), Vector2(-0.04, -0.4), Vector2(-0.04, 0.66), Vector2(-0.86, 0.5)], c, s), PALE)
			_pad.draw_colored_polygon(_shape([Vector2(0.86, -0.55), Vector2(0.04, -0.4), Vector2(0.04, 0.66), Vector2(0.86, 0.5)], c, s), PALE.darkened(0.08))
			for k in 3:
				_pad.draw_line(c + Vector2(-0.72, -0.2 + 0.25 * k) * s, c + Vector2(-0.22, -0.12 + 0.25 * k) * s, Color(dark, 0.6), 0.06 * s)
				_pad.draw_line(c + Vector2(0.72, -0.2 + 0.25 * k) * s, c + Vector2(0.22, -0.12 + 0.25 * k) * s, Color(dark, 0.6), 0.06 * s)
		&"pause":
			_pad.draw_colored_polygon(_shape([Vector2(-0.48, -0.62), Vector2(-0.14, -0.62), Vector2(-0.14, 0.62), Vector2(-0.48, 0.62)], c, s), PALE)
			_pad.draw_colored_polygon(_shape([Vector2(0.14, -0.62), Vector2(0.48, -0.62), Vector2(0.48, 0.62), Vector2(0.14, 0.62)], c, s), PALE)
