class_name OpeningScreen
extends Control
## Le texte d'ouverture : quelques phrases qui apparaissent et s'effacent sur
## la nuit, avant le premier niveau. Un toucher passe à la suivante.
##
## Ces phrases sont dans un dépôt public : elles s'en tiennent au point de
## départ que le jeu pose lui-même.

signal finished

const CARDS: Array[String] = [
	"Orvana perdait une guerre de vingt ans.\nLes villages se vidaient. Les légions ne revenaient plus.",
	"Alors le roi a prêté un serment :\n« Nul ne mourra plus en Orvana. »",
	"Le serment a tenu, à la lettre.\nCeux qui meurent se relèvent.",
	"Sept ans ont passé.\nTu es soldat de la dernière légion, et tu rentres chez toi.",
]

var _label: Label
var _index := -1
var _tween: Tween
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(NightSky.new())
	_label = Theatre.label("", 34, Theatre.CREAM, GameFonts.italic())
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_label.offset_left = -520.0
	_label.offset_right = 520.0
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.modulate.a = 0.0
	add_child(_label)
	var skip := Button.new()
	skip.text = "Passer"
	Theatre.pill(skip, 20, Theatre.MUTED)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -22.0
	skip.offset_top = 22.0
	skip.pressed.connect(skip_all)
	add_child(skip)
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			next_card())
	next_card()


## Passe à la phrase suivante, ou termine après la dernière.
func next_card() -> void:
	if _done:
		return
	_index += 1
	if _index >= CARDS.size():
		skip_all()
		return
	if _tween != null:
		_tween.kill()
	_label.text = CARDS[_index]
	var hold := 2.4 + 0.035 * float(CARDS[_index].length())
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.9)
	_tween.tween_interval(hold)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.7)
	_tween.tween_callback(next_card)


func skip_all() -> void:
	if _done:
		return
	_done = true
	if _tween != null:
		_tween.kill()
	finished.emit()
