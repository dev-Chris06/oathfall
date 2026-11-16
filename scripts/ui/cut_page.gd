class_name CutPage
extends MarginContainer
## Une page de papier noir aux bords déchiquetés, découpée comme pour un
## théâtre d'ombres, avec un liseré d'or pâle à l'intérieur. Les enfants s'y
## rangent dans `column`.

var column: VBoxContainer
var seed_value := 1


func _init(page_seed := 1) -> void:
	seed_value = page_seed
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 38)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	add_child(column)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var outline := PackedVector2Array()
	var x := 0.0
	outline.append(Vector2(0.0, 12.0))
	while x < w:
		x = minf(x + rng.randf_range(36.0, 100.0), w)
		outline.append(Vector2(x, rng.randf_range(0.0, 12.0)))
	outline.append(Vector2(w, h - 12.0))
	x = w
	while x > 0.0:
		x = maxf(x - rng.randf_range(36.0, 100.0), 0.0)
		outline.append(Vector2(x, h - rng.randf_range(0.0, 12.0)))
	# L'ombre portée du papier sur le fond.
	for k in 3:
		var shadow := PackedVector2Array()
		for point in outline:
			shadow.append(point + Vector2(0.0, 5.0 + 5.0 * k))
		draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.22))
	draw_colored_polygon(outline, Theatre.NIGHT)
	var inset := Rect2(14.0, 22.0, w - 28.0, h - 44.0)
	draw_rect(inset, Color(Theatre.AMBER, 0.5), false, 2.0)
