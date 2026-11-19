class_name RiteIcons
extends RefCounted
## Les icônes des rites de combat, dessinées en code : sur les boutons du jeu,
## dans le carnet, dans les fiches. Une forme claire et lisible de loin, pour
## chaque rite ; `s` est la demi-taille de l'icône.

const PALE := Color(0.94, 0.89, 0.76)
const EMBER := Color(1.0, 0.54, 0.35)
const GOLD := Color(0.91, 0.69, 0.38)
const REST := Color(0.62, 0.82, 1.0)


static func draw(ci: CanvasItem, id: StringName, c: Vector2, s: float, color := PALE, accent := EMBER) -> void:
	var w := maxf(2.0, s * 0.13)
	match id:
		&"glas":
			# Une cloche, et l'onde qu'elle jette au sol.
			var bell := PackedVector2Array()
			for k in 13:
				var a := PI * float(k) / 12.0
				bell.append(c + Vector2(-cos(a) * 0.36, -0.25 - sin(a) * 0.42) * s)
			bell.append(c + Vector2(0.52, 0.22) * s)
			bell.append(c + Vector2(-0.52, 0.22) * s)
			ci.draw_colored_polygon(bell, color)
			ci.draw_circle(c + Vector2(0.0, 0.33) * s, 0.11 * s, color)
			ci.draw_rect(Rect2(c + Vector2(-0.07, -0.82) * s, Vector2(0.14, 0.16) * s), color)
			for k in 2:
				var r := (0.62 + 0.24 * k) * s
				ci.draw_arc(c + Vector2(0.0, 0.36) * s, r, PI * 0.12, PI * 0.88, 16, Color(accent, 0.9 - 0.3 * k), w, true)
		&"linceul":
			# Un tourbillon : trois lames qui tournent autour d'un cœur.
			for k in 3:
				var a := TAU * float(k) / 3.0
				ci.draw_arc(c, 0.62 * s, a, a + 1.5, 14, color, w * 1.2, true)
				var tip := c + Vector2.from_angle(a + 1.5) * 0.62 * s
				var along := Vector2.from_angle(a + 1.5 + PI / 2.0)
				ci.draw_colored_polygon(PackedVector2Array([tip + along * 0.24 * s, tip + Vector2.from_angle(a + 1.5) * 0.16 * s, tip - Vector2.from_angle(a + 1.5) * 0.16 * s]), color)
			ci.draw_arc(c, 0.86 * s, 0.4, 2.2, 14, Color(accent, 0.7), w * 0.7, true)
			ci.draw_arc(c, 0.86 * s, 3.5, 5.3, 14, Color(accent, 0.7), w * 0.7, true)
			ci.draw_circle(c, 0.16 * s, accent)
		&"cortege":
			# Une ruée : trois chevrons, et les traits de la vitesse.
			for k in 3:
				var x := -0.42 + 0.34 * k
				var a := Color(color, 0.45 + 0.27 * k)
				ci.draw_polyline(PackedVector2Array([c + Vector2(x, -0.45) * s, c + Vector2(x + 0.3, 0.0) * s, c + Vector2(x, 0.45) * s]), a, w * 1.4, true)
			for k in 3:
				var y := -0.3 + 0.3 * k
				ci.draw_line(c + Vector2(-0.95, y) * s, c + Vector2(-0.62, y) * s, Color(accent, 0.9), w * 0.8, true)
		&"tombee":
			# Une chute droite sur le sol, et l'impact.
			ci.draw_line(c + Vector2(0.0, -0.85) * s, c + Vector2(0.0, 0.05) * s, color, w * 1.5, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.3, -0.05) * s, c + Vector2(0.3, -0.05) * s, c + Vector2(0.0, 0.32) * s]), color)
			ci.draw_line(c + Vector2(-0.8, 0.5) * s, c + Vector2(0.8, 0.5) * s, color, w, true)
			for k in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(0.25 * k, 0.42) * s, c + Vector2(0.62 * k, 0.12) * s, accent, w * 0.9, true)
				ci.draw_line(c + Vector2(0.45 * k, 0.48) * s, c + Vector2(0.86 * k, 0.32) * s, Color(accent, 0.7), w * 0.7, true)
		&"requiem":
			# Un écu fendu par une lame lourde.
			var shield := PackedVector2Array([c + Vector2(-0.55, -0.55) * s, c + Vector2(0.55, -0.55) * s, c + Vector2(0.5, 0.1) * s,
				c + Vector2(0.0, 0.7) * s, c + Vector2(-0.5, 0.1) * s])
			ci.draw_colored_polygon(shield, Color(color, 0.85))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.12, -0.6) * s, c + Vector2(0.08, -0.2) * s, c + Vector2(-0.1, 0.12) * s, c + Vector2(0.06, 0.66) * s]),
				Color(0.05, 0.05, 0.1), w * 1.3, true)
			ci.draw_line(c + Vector2(0.62, -0.9) * s, c + Vector2(-0.1, 0.1) * s, accent, w * 1.6, true)
			ci.draw_line(c + Vector2(0.48, -0.68) * s, c + Vector2(0.76, -0.56) * s, accent, w * 1.2, true)
		&"litanie":
			# Cinq entailles, de plus en plus vives.
			for k in 5:
				var x := -0.6 + 0.3 * k
				ci.draw_line(c + Vector2(x - 0.12, 0.55) * s, c + Vector2(x + 0.2, -0.55) * s, Color(accent if k == 4 else color, 0.5 + 0.12 * k), w * (1.0 + 0.15 * k), true)
		&"cierge":
			# Un cierge, sa flamme et sa lueur.
			ci.draw_arc(c + Vector2(0.0, -0.35) * s, 0.55 * s, 0.0, TAU, 28, Color(GOLD, 0.45), w * 0.7, true)
			ci.draw_rect(Rect2(c + Vector2(-0.16, -0.15) * s, Vector2(0.32, 0.8) * s), color)
			ci.draw_rect(Rect2(c + Vector2(-0.34, 0.62) * s, Vector2(0.68, 0.14) * s), color)
			var flame := PackedVector2Array([c + Vector2(0.0, -0.75) * s, c + Vector2(0.15, -0.38) * s, c + Vector2(0.0, -0.22) * s, c + Vector2(-0.15, -0.38) * s])
			ci.draw_colored_polygon(flame, GOLD)
		&"absoute":
			# Un croissant de lumière qui file, et sa traînée.
			var arc := PackedVector2Array()
			for k in 11:
				var a := lerpf(-1.15, 1.15, float(k) / 10.0)
				arc.append(c + Vector2(0.25 + cos(a) * 0.5, sin(a) * 0.62) * s)
			for k in range(10, -1, -1):
				var a := lerpf(-1.15, 1.15, float(k) / 10.0)
				arc.append(c + Vector2(0.08 + cos(a) * 0.42, sin(a) * 0.5) * s)
			ci.draw_colored_polygon(arc, color)
			for k in 3:
				var y := -0.3 + 0.3 * k
				ci.draw_line(c + Vector2(-0.9, y) * s, c + Vector2(-0.3, y) * s, Color(accent, 0.85 - 0.2 * absf(k - 1.0)), w * 0.8, true)
		&"rappel":
			# Une silhouette qui se relève, dorée, au-dessus d'une tombe.
			ci.draw_line(c + Vector2(-0.7, 0.62) * s, c + Vector2(0.7, 0.62) * s, color, w, true)
			ci.draw_rect(Rect2(c + Vector2(-0.24, 0.3) * s, Vector2(0.48, 0.32) * s), Color(color, 0.6))
			ci.draw_circle(c + Vector2(0.0, -0.58) * s, 0.17 * s, GOLD)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.25, -0.36) * s, c + Vector2(0.25, -0.36) * s, c + Vector2(0.16, 0.2) * s, c + Vector2(-0.16, 0.2) * s]), GOLD)
			for k in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(0.55 * k, 0.1) * s, c + Vector2(0.55 * k, -0.45) * s, Color(REST, 0.8), w * 0.8, true)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.55 * k - 0.12, -0.38) * s, c + Vector2(0.55 * k + 0.12, -0.38) * s, c + Vector2(0.55 * k, -0.58) * s]), Color(REST, 0.8))
		_:
			ci.draw_circle(c, 0.4 * s, Color(color, 0.4))


## Les losanges du coût, en rang, centrés sur `c`.
static func draw_cost(ci: CanvasItem, cost: int, c: Vector2, size: float, lit: bool) -> void:
	var gap := size * 2.4
	var start := c - Vector2(gap * float(cost - 1) / 2.0, 0.0)
	for k in cost:
		var at := start + Vector2(gap * k, 0.0)
		var points := PackedVector2Array([at + Vector2(0.0, -size), at + Vector2(size, 0.0), at + Vector2(0.0, size), at + Vector2(-size, 0.0)])
		ci.draw_colored_polygon(points, EMBER if lit else Color(0.3, 0.27, 0.35))
