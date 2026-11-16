class_name TouchControls
extends CanvasLayer
## Commandes du joueur : joystick tactile à gauche, boutons à droite, et
## clavier pour tester sur PC (ZQSD ou flèches, J ou Espace pour frapper,
## K ou Maj pour esquiver, E pour le Repos). Le reste du jeu ne lit que
## `move`, `rite_held` et les signaux.

signal attack_pressed
signal dodge_pressed

const STICK_RADIUS := 95.0
const ATTACK_RADIUS := 88.0
const DODGE_RADIUS := 62.0
const RITE_RADIUS := 66.0

## Direction voulue, de longueur 0 à 1. x vers la droite, y vers le bas de l'écran.
var move := Vector2.ZERO
## Vrai tant que le joueur maintient le bouton du Repos.
var rite_held := false
## Renseignés par le héros : le bouton du Repos n'apparaît que près d'un corps,
## et son anneau se remplit pendant le rite.
var rite_available := false
var rite_progress := 0.0
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


func _ready() -> void:
	layer = 10
	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)


func _process(delta: float) -> void:
	var keys := Vector2(
		float(_key(KEY_D) or _key(KEY_RIGHT)) - float(_key(KEY_A) or _key(KEY_LEFT)),
		float(_key(KEY_S) or _key(KEY_DOWN)) - float(_key(KEY_W) or _key(KEY_UP)))
	move = (_stick_vector + keys + simulated_move).limit_length(1.0)
	rite_held = _rite_index != -1 or _key(KEY_E) or simulated_rite

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
			if touch.position.distance_to(_attack_center()) <= ATTACK_RADIUS * 1.25:
				press_attack()
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


func press_attack() -> void:
	_attack_flash = 1.0
	attack_pressed.emit()


func press_dodge() -> void:
	_dodge_flash = 1.0
	dodge_pressed.emit()


func _attack_center() -> Vector2:
	return Vector2(_pad.size.x - 150.0, _pad.size.y - 150.0)


func _dodge_center() -> Vector2:
	return Vector2(_pad.size.x - 335.0, _pad.size.y - 105.0)


func _rite_center() -> Vector2:
	return Vector2(_pad.size.x - 140.0, _pad.size.y - 345.0)


func _draw_pad() -> void:
	var font := ThemeDB.fallback_font

	# Joystick : il apparaît là où le pouce se pose, sinon à sa place de repos.
	var base := _stick_origin if _stick_index != -1 else Vector2(175.0, _pad.size.y - 175.0)
	_pad.draw_circle(base, STICK_RADIUS, Color(1, 1, 1, 0.07))
	_pad.draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.3), 3.0, true)
	_pad.draw_circle(base + _stick_vector * STICK_RADIUS, 38.0, Color(1, 1, 1, 0.32))

	_draw_button(_attack_center(), ATTACK_RADIUS, Color(0.85, 0.25, 0.2), _attack_flash, "FRAPPER", font)
	_draw_button(_dodge_center(), DODGE_RADIUS, Color(0.75, 0.7, 0.55), _dodge_flash, "ESQUIVE", font)

	if rite_available:
		var center := _rite_center()
		var held := 1.0 if rite_held else 0.0
		_draw_button(center, RITE_RADIUS, Color(0.6, 0.82, 1.0), held * 0.6, "REPOS", font)
		if rite_progress > 0.0:
			_pad.draw_arc(center, RITE_RADIUS + 9.0, -PI / 2.0, -PI / 2.0 + TAU * rite_progress,
				48, Color(0.85, 0.95, 1.0, 0.95), 7.0, true)


func _draw_button(center: Vector2, radius: float, color: Color, flash: float, text: String, font: Font) -> void:
	_pad.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.22 + 0.4 * flash))
	_pad.draw_arc(center, radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.75), 3.0, true)
	var font_size := 17
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_pad.draw_string(font, center + Vector2(-text_size.x / 2.0, font_size * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1, 1, 1, 0.85))
