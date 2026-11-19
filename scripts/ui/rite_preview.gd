class_name RitePreview
extends Control
## Une courte animation, vue de dessus, qui montre comment fonctionne un rite
## de combat : le héros (pâle), les morts debout (bleus), les corps (gris),
## l'effet du rite. Elle tourne en boucle ; dans le carnet et à la découverte
## d'un rite. Tout est dessiné en code : rien à charger.
##
## La scène se décrit dans un terrain de 16 × 9 unités, mis à l'échelle du
## contrôle.

const LOOP := 3.4
const HERO := Color(0.94, 0.89, 0.76)
const DEAD := Color(0.5, 0.58, 0.85)
const BODY := Color(0.33, 0.35, 0.46)
const EMBER := Color(1.0, 0.54, 0.35)
const GOLD := Color(0.91, 0.69, 0.38)
const REST := Color(0.62, 0.82, 1.0)

var rite: StringName = &"glas":
	set(value):
		rite = value
		_time = 0.0
		queue_redraw()
var _time := 0.0


func _init(size_hint := Vector2(480.0, 270.0)) -> void:
	custom_minimum_size = size_hint
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Le carnet met le jeu en pause : l'animation tourne quand même.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_time = fmod(_time + delta, LOOP)
	queue_redraw()


## Avancement de la boucle, de 0 à 1 (pour les essais).
func phase() -> float:
	return _time / LOOP


# --- Dessin -------------------------------------------------------------------

var _scale := 1.0
var _origin := Vector2.ZERO


func _p(x: float, y: float) -> Vector2:
	return _origin + Vector2(x, y) * _scale


func _draw() -> void:
	_scale = minf(size.x / 16.0, size.y / 9.0)
	_origin = (size - Vector2(16.0, 9.0) * _scale) / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.03, 0.06))
	var grid := Color(0.6, 0.62, 0.75, 0.06)
	for x in 17:
		draw_line(_p(x, 0.0), _p(x, 9.0), grid, 1.0)
	for y in 10:
		draw_line(_p(0.0, y), _p(16.0, y), grid, 1.0)
	var u := _time / LOOP
	match rite:
		&"glas": _glas(u)
		&"linceul": _linceul(u)
		&"cortege": _cortege(u)
		&"tombee": _tombee(u)
		&"requiem": _requiem(u)
		&"litanie": _litanie(u)
		&"cierge": _cierge(u)
		&"absoute": _absoute(u)
		&"rappel": _rappel(u)
	draw_rect(Rect2(Vector2.ZERO, size), Color(GOLD, 0.45), false, 2.0)


## Les silhouettes sont grandes par rapport au terrain : on doit les lire
## d'un coup d'œil, même dans un petit cadre.
const FIGURE := 1.9


func _figure(at: Vector2, color: Color, lift := 0.0, kneel := false) -> void:
	var s := _scale * FIGURE
	draw_circle(_p(at.x, at.y + 0.45), s * 0.36 * (1.0 - lift * 0.3), Color(0.0, 0.0, 0.0, 0.4))
	var body := _p(at.x, at.y) - Vector2(0.0, lift * _scale)
	var h := 0.7 if kneel else 1.0
	draw_set_transform(body, 0.0, Vector2(1.0, 1.45 * h))
	draw_circle(Vector2.ZERO, s * 0.27, color)
	draw_set_transform(Vector2.ZERO)
	draw_circle(body - Vector2(0.0, s * 0.55 * h), s * 0.19, color)


func _corpse(at: Vector2, color := BODY, alpha := 1.0) -> void:
	draw_set_transform(_p(at.x, at.y + 0.3), 0.25, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, _scale * 0.55 * FIGURE, Color(color, alpha))
	draw_set_transform(Vector2.ZERO)


## Un mort : debout jusqu'à `fall_at`, puis au sol (projeté de `push`).
func _dead(at: Vector2, u: float, fall_at: float, push := Vector2.ZERO, color := DEAD) -> void:
	if u < fall_at:
		_figure(at, color)
	else:
		var k := clampf((u - fall_at) / 0.08, 0.0, 1.0)
		_corpse(at + push * k)


func _ring(center: Vector2, radius: float, color: Color, width := 3.0) -> void:
	draw_arc(_p(center.x, center.y), radius * _scale, 0.0, TAU, 40, color, width, true)


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


# --- Les rites ----------------------------------------------------------------

func _glas(u: float) -> void:
	var hero := Vector2(8.0, 4.7)
	var impact := 0.42
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		var start := hero + Vector2(cos(a) * 5.5, sin(a) * 3.3)
		var stop := hero + Vector2(cos(a) * 1.9, sin(a) * 1.3)
		var at := start.lerp(stop, _ease(clampf(u / impact, 0.0, 1.0)))
		_dead(at, u, impact, Vector2(cos(a), sin(a)) * 1.1)
	_figure(hero, HERO)
	if u > impact and u < impact + 0.35:
		var w := (u - impact) / 0.35
		_ring(hero + Vector2(0.0, 0.4), 0.5 + 4.2 * w, Color(EMBER, 1.0 - w), 6.0 * (1.0 - w) + 1.0)


func _linceul(u: float) -> void:
	var hero := Vector2(7.0 + 2.0 * clampf((u - 0.2) / 0.5, 0.0, 1.0), 4.6)
	var spin := u > 0.2 and u < 0.7
	var fallers := [Vector2(7.6, 3.2), Vector2(9.8, 3.6), Vector2(10.6, 5.4), Vector2(8.4, 6.2), Vector2(6.0, 5.6)]
	for k in fallers.size():
		var fall := 0.32 + 0.08 * k
		_dead(fallers[k], u, fall, (fallers[k] - hero).normalized() * 0.8)
	_figure(hero, HERO)
	if spin:
		for k in 3:
			var a := u * 60.0 + k * 2.1
			draw_arc(_p(hero.x, hero.y + 0.1), (1.7 - k * 0.25) * _scale, a, a + 1.6, 14, Color(EMBER, 0.85 - k * 0.22), 5.0 - k, true)


func _cortege(u: float) -> void:
	var from := Vector2(2.5, 4.7)
	var to := Vector2(13.5, 4.7)
	var dash := clampf((u - 0.3) / 0.14, 0.0, 1.0)
	var hero := from.lerp(to, dash)
	if dash > 0.0 and u < 0.6:
		draw_line(_p(from.x, from.y), _p(hero.x, hero.y), Color(HERO, 0.5 * (1.0 - clampf((u - 0.44) / 0.16, 0.0, 1.0))), _scale * 0.5)
	for k in 4:
		var at := Vector2(5.0 + 2.4 * k, 4.7 + (0.5 if k % 2 == 0 else -0.5))
		var when := 0.3 + 0.14 * (at.x - from.x) / (to.x - from.x)
		_dead(at, u, when, Vector2(0.0, 0.9 if k % 2 == 0 else -0.9))
	_figure(hero, HERO)


func _tombee(u: float) -> void:
	var from := Vector2(3.0, 5.0)
	var land := Vector2(11.0, 4.6)
	var jump := clampf((u - 0.18) / 0.3, 0.0, 1.0)
	var hero := from.lerp(land, _ease(jump))
	var lift := sin(jump * PI) * 2.2
	var impact := 0.48
	for at: Vector2 in [Vector2(10.0, 3.6), Vector2(12.2, 3.9), Vector2(12.0, 5.6), Vector2(9.8, 5.5), Vector2(11.2, 4.9)]:
		_dead(at, u, impact, (at - land).normalized() * 1.0)
	_figure(hero, HERO, lift)
	if u > impact and u < impact + 0.3:
		var w := (u - impact) / 0.3
		_ring(land + Vector2(0.0, 0.4), 0.4 + 3.0 * w, Color(EMBER, 1.0 - w), 5.0 * (1.0 - w) + 1.0)


func _requiem(u: float) -> void:
	var hero := Vector2(6.0, 4.7)
	var target := Vector2(8.6, 4.7)
	_figure(hero, HERO)
	# Le mort à armure : un liseré d'or. Fendu, un anneau doré ; le coup
	# suivant l'abat.
	var rent := u > 0.3 and u < 0.66
	if u < 0.66:
		_figure(target, DEAD)
		_ring(target + Vector2(0.0, 0.45), 0.55, Color(0.75, 0.78, 0.9, 0.9), 2.0)
	else:
		_corpse(target + Vector2(1.0, 0.0) * clampf((u - 0.66) / 0.08, 0.0, 1.0))
	if rent:
		_ring(target + Vector2(0.0, 0.45), 0.75 + 0.06 * sin(u * 60.0), GOLD, 4.0)
	if u > 0.27 and u < 0.36:
		var w := (u - 0.27) / 0.09
		draw_line(_p(target.x - 0.7, target.y - 1.4 + 2.0 * w), _p(target.x + 0.6, target.y - 1.6 + 2.0 * w), Color(GOLD, 1.0 - w), 6.0, true)
	if u > 0.62 and u < 0.7:
		draw_arc(_p(hero.x, hero.y), 1.8 * _scale, -0.8, 0.8, 14, EMBER, 5.0, true)


func _litanie(u: float) -> void:
	var hero := Vector2(6.0, 4.7)
	var target := Vector2(8.0, 4.7)
	_figure(hero, HERO)
	var last := 0.62
	if u < last:
		_figure(target, Color.WHITE if fmod(u, 0.075) < 0.03 and u > 0.25 else DEAD)
	else:
		_corpse(target + Vector2(4.0, 0.0) * _ease(clampf((u - last) / 0.15, 0.0, 1.0)))
	for k in 5:
		var at := 0.25 + 0.075 * k
		if u > at and u < at + 0.08:
			var w := (u - at) / 0.08
			var y := target.y - 1.0 + 0.4 * k
			draw_line(_p(target.x - 0.6, y + 0.4), _p(target.x + 0.6, y - 0.4), Color(EMBER if k == 4 else HERO, 1.0 - w), 4.0 + k, true)


func _cierge(u: float) -> void:
	var hero := Vector2(6.0, 4.6)
	var candle := Vector2(6.0, 5.3)
	var planted := u > 0.2
	if planted:
		var glow := 3.4 * _scale
		draw_circle(_p(candle.x, candle.y), glow, Color(GOLD, 0.12))
		_ring(candle, 3.4, Color(GOLD, 0.7), 2.0)
		draw_rect(Rect2(_p(candle.x - 0.12, candle.y - 0.6), Vector2(0.24, 0.6) * _scale), HERO)
		draw_circle(_p(candle.x, candle.y - 0.75), 0.14 * _scale * (1.0 + 0.2 * sin(u * 40.0)), GOLD)
	# Deux corps dans la lueur : leur anneau ne bouge plus. Un dehors : il se
	# relève.
	for at: Vector2 in [Vector2(4.2, 4.0), Vector2(8.2, 5.4)]:
		_corpse(at)
		var progress := clampf(u * 1.6, 0.0, 0.32) if planted else u * 1.6
		draw_arc(_p(at.x, at.y + 0.3), 0.8 * _scale, -PI / 2.0, -PI / 2.0 + TAU * progress, 24, Color(HERO, 0.6), 3.0, true)
	var outside := Vector2(13.2, 4.2)
	if u < 0.72:
		_corpse(outside)
		draw_arc(_p(outside.x, outside.y + 0.3), 0.8 * _scale, -PI / 2.0, -PI / 2.0 + TAU * (u / 0.72), 24, EMBER, 3.0, true)
	else:
		_figure(outside, DEAD)
	_figure(hero + Vector2(-0.9, -0.4), HERO, 0.0, u < 0.22 and u > 0.08)


func _absoute(u: float) -> void:
	var hero := Vector2(3.0, 4.7)
	_figure(hero, HERO)
	var fly := clampf((u - 0.22) / 0.32, 0.0, 1.0)
	var front := 3.6 + 11.5 * fly
	if u > 0.22 and u < 0.6:
		var at := _p(front, hero.y)
		draw_arc(at - Vector2(0.4 * _scale, 0.0), 0.9 * _scale, -1.0, 1.0, 14, HERO, 6.0, true)
		draw_line(at - Vector2(2.5 * _scale, 0.0), at - Vector2(0.9 * _scale, 0.0), Color(GOLD, 0.5), 3.0, true)
	for at: Vector2 in [Vector2(9.0, 4.4), Vector2(11.5, 5.0), Vector2(14.0, 4.6)]:
		var when := 0.22 + 0.32 * (at.x - 3.6) / 11.5
		_dead(at, u, when, Vector2(0.8, 0.0))


func _rappel(u: float) -> void:
	var hero := Vector2(5.0, 4.8)
	var grave := Vector2(6.8, 4.9)
	_figure(hero, HERO, 0.0, u < 0.15)
	if u < 0.15:
		_corpse(grave, REST, 1.0 - u / 0.15)
	var rise := clampf((u - 0.25) / 0.12, 0.0, 1.0)
	var foes := [Vector2(11.0, 3.8), Vector2(12.5, 5.6)]
	var ally := grave
	if rise > 0.0:
		ally = grave.lerp(Vector2(10.0, 4.6), clampf((u - 0.4) / 0.2, 0.0, 1.0))
		draw_circle(_p(ally.x, ally.y + 0.45), 0.7 * _scale, Color(GOLD, 0.15 * rise))
		_figure(ally, Color(GOLD, rise))
	for k in foes.size():
		_dead(foes[k], u, 0.62 + 0.1 * k, Vector2(1.0, 0.0))
	if u > 0.6 and u < 0.8:
		draw_arc(_p(ally.x, ally.y), 1.4 * _scale, -0.9, 0.9, 12, Color(GOLD, 0.9), 4.0, true)
