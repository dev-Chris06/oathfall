class_name NightSky
extends Control
## La nuit du théâtre d'ombres : un dégradé du bleu profond au noir, des
## étoiles, la lune. Sert de fond à la carte, au menu et à l'ouverture. Sur la
## carte, elle défile moins vite que la ville, comme un décor plus lointain.

var shift := 0.0
var _stars: Array[Vector3] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(2600.0, 2000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 170:
		_stars.append(Vector3(rng.randf_range(0.0, 2600.0), rng.randf_range(0.0, 1900.0), rng.randf_range(0.6, 1.8)))


func _draw() -> void:
	var top := Color(0.137, 0.165, 0.29)
	var bottom := Color(0.043, 0.043, 0.078)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	for star in _stars:
		draw_circle(Vector2(star.x, star.y), star.z, Color(0.85, 0.82, 0.7, 0.55))
	var moon := Vector2(1130.0, 230.0)
	for k in 7:
		draw_circle(moon, 150.0 - k * 16.0, Color(0.95, 0.92, 0.82, 0.03 + 0.012 * k))
	draw_circle(moon, 62.0, Color(0.95, 0.92, 0.82))
