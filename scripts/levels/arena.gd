class_name Arena
extends Level
## Salle d'essai : une pièce fermée où des Dépouilles arrivent par vagues.
##
## Elle sert au test automatique des mécaniques de combat, et peut se lancer
## à la main avec `-- --arena`. Une vague n'est finie que lorsque tous les
## morts reposent.

## Les dalles et les murs du pack font 4 unités de côté.
const TILE := 4.0
const COLS := 7
const ROWS := 5

var _wave := 0


func _init() -> void:
	title = "Arène"


func _run(_checkpoint: int) -> void:
	if scripted:
		return
	hud.show_message("Les morts se relèvent.\nReste près d'un corps et maintiens REPOS.", 6.0)
	while not hero.is_dead():
		_wave += 1
		spawn_wave(mini(2 + _wave, 8))
		await until_peace()
		hud.show_message("La salle est en paix.", 3.0)
		await wait(3.5)


## Fait entrer `count` Dépouilles autour du héros. `rise_delay` remplace,
## s'il est positif, le délai de relèvement du type (utilisé par les tests).
func spawn_wave(count: int, rise_delay := -1.0) -> void:
	var half_x := COLS * TILE / 2.0 - 1.5
	var half_z := ROWS * TILE / 2.0 - 1.5
	var start := randf() * TAU
	for i in count:
		var angle := start + TAU * i / count
		var pos := hero.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 8.5
		pos.x = clampf(pos.x, -half_x, half_x)
		pos.z = clampf(pos.z, -half_z, half_z)
		var enemy := spawn(&"depouille", pos, false)
		if rise_delay > 0.0:
			enemy.rise_delay = rise_delay


func _build() -> void:
	var half_x := COLS * TILE / 2.0
	var half_z := ROWS * TILE / 2.0

	for c in COLS:
		var x := (c - (COLS - 1) / 2.0) * TILE
		for r in ROWS:
			var z := (r - (ROWS - 1) / 2.0) * TILE
			place("floor_tile_large.glb", Vector3(x, 0.0, z))
		var north := "wall_doorway.glb" if c == COLS / 2 else "wall.glb"
		place(north, Vector3(x, 0.0, -half_z - 0.5))
		# Pas de mur au sud : il se trouverait entre la caméra et le héros.

	for r in ROWS:
		var z := (r - (ROWS - 1) / 2.0) * TILE
		place("wall.glb", Vector3(-half_x - 0.5, 0.0, z), 90.0)
		place("wall.glb", Vector3(half_x + 0.5, 0.0, z), -90.0)

	for sx: float in [-1.0, 1.0]:
		place("pillar.glb", Vector3(sx * (half_x + 0.5), 0.0, -half_z - 0.5))

	place("barrel_large.glb", Vector3(-half_x + 1.4, 0.0, -half_z + 1.4))
	place("barrel_small_stack.glb", Vector3(half_x - 1.6, 0.0, -half_z + 1.3), 25.0)

	for tx: float in [-8.0, 8.0]:
		_torch(Vector3(tx, 2.3, -half_z), 0.0)
	_torch(Vector3(-half_x, 2.3, 2.0), 90.0)
	_torch(Vector3(half_x, 2.3, 2.0), -90.0)

	# Murs invisibles : personne ne sort de la salle.
	var wide := COLS * TILE + 2.0
	var deep := ROWS * TILE + 2.0
	solid(Vector3(0.0, 0.0, -half_z - 0.5), Vector3(wide, 4.0, 1.0))
	solid(Vector3(0.0, 0.0, half_z + 0.5), Vector3(wide, 4.0, 1.0))
	solid(Vector3(-half_x - 0.5, 0.0, 0.0), Vector3(1.0, 4.0, deep))
	solid(Vector3(half_x + 0.5, 0.0, 0.0), Vector3(1.0, 4.0, deep))


func _torch(pos: Vector3, yaw_deg: float) -> void:
	place("torch_mounted.glb", pos, yaw_deg)
	var forward := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	flame(pos + forward * 0.7 + Vector3(0.0, 0.6, 0.0))
