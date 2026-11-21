class_name LOssuaire
extends Level
## Niveau 4 — L'Ossuaire.
##
## Sous le cimetière, des couloirs étroits relient trois salles d'ossements.
## Le joueur y rencontre le Fouisseur, qui jaillit du sol, et la Veuve, dont
## le cri relève tous les corps. La dernière salle mêle tous les morts du
## chapitre.
##
##   z =   4 … -12 : premier couloir
##   z = -12 … -28 : première salle        grille z = -30
##   z = -28 … -42 : deuxième couloir
##   z = -42 … -60 : deuxième salle        grille z = -62
##   z = -60 … -70 : troisième couloir
##   z = -70 … -88 : dernière salle, sortie au nord, vers la Fosse

const CORRIDOR := 3.0
const ROOM := 9.0
## Les salles : [z sud, z nord].
const ROOMS: Array[Vector2] = [Vector2(-12.0, -28.0), Vector2(-42.0, -60.0), Vector2(-70.0, -88.0)]
## Les couloirs : [z sud, z nord].
const CORRIDORS: Array[Vector2] = [Vector2(5.0, -12.0), Vector2(-28.0, -42.0), Vector2(-60.0, -70.0)]
const EXIT := Vector3(0.0, 0.0, -86.0)


func _init() -> void:
	title = "L'Ossuaire"
	play_area = Rect2(-8.8, -90.0, 17.6, 95.0)
	underground = true
	next_level = &"la_fosse"


func _checkpoint_position(index: int) -> Vector3:
	match index:
		1:
			return Vector3(0.0, 0.0, -34.0)
		2:
			return Vector3(0.0, 0.0, -65.5)
	return Vector3(0.0, 0.0, 2.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _first_room()
	if checkpoint <= 1:
		await _widow_room()
	await _last_room()
	await _leave()


## Le couloir d'entrée, puis la première salle : le Fouisseur.
func _first_room() -> void:
	await say("L'OSSUAIRE", 2.5)
	hud.show_message("Les couloirs sont étroits.\nNe te laisse pas encercler.", 4.0)
	await reach(Vector3(0.0, 0.0, -2.0), 3.0)
	spawn_group(&"depouille", [Vector3(-1.5, 0.0, -8.0), Vector3(1.5, 0.0, -10.0)])
	await until_peace()

	await reach(Vector3(0.0, 0.0, -15.0), 3.0)
	spawn(&"fouisseur", Vector3(-7.0, 0.0, -25.0))
	spawn_group(&"depouille", [Vector3(6.0, 0.0, -24.0), Vector3(-5.0, 0.0, -26.0)])
	hud.show_message("Le sol remue. Quand la terre tremble\nà tes pieds, ESQUIVE.", 5.0)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"fouisseur", Vector3(7.0, 0.0, -20.0))
	await until_peace()
	hud.show_message("La grille du couloir s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


## Le second couloir, puis la première Veuve.
func _widow_room() -> void:
	spawn(&"fouisseur", Vector3(2.0, 0.0, -40.0))
	await until_peace()
	await reach(Vector3(0.0, 0.0, -44.0), 3.0)
	spawn(&"veuve", Vector3(0.0, 0.0, -57.0))
	spawn_group(&"depouille", [Vector3(-5.0, 0.0, -50.0), Vector3(5.0, 0.0, -52.0)])
	hud.show_message("Une Veuve. Son cri relève tous les corps.\nFrappe-la quand elle prend son souffle.", 5.5)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn_group(&"depouille", [Vector3(-6.0, 0.0, -56.0), Vector3(6.0, 0.0, -45.0)])
	await until_peace()
	hud.show_message("La grille s'ouvre.", 2.5)
	open_gate(1)
	await reach(_checkpoint_position(2), 3.0)
	mark_checkpoint(2)


## La dernière salle : tous les morts du chapitre.
func _last_room() -> void:
	await reach(Vector3(0.0, 0.0, -72.0), 3.0)
	hud.show_message("Ils sont tous là.", 3.0)
	spawn(&"veuve", Vector3(-6.0, 0.0, -84.0))
	spawn(&"archer_creux", Vector3(6.0, 0.0, -84.0))
	spawn_group(&"depouille", [Vector3(-3.0, 0.0, -78.0), Vector3(3.0, 0.0, -79.0)], 16.0)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"porte_cloche", Vector3(0.0, 0.0, -85.0))
	spawn(&"fouisseur", Vector3(-7.0, 0.0, -74.0))
	await until_peace()


func _leave() -> void:
	await victory("L'Ossuaire est en paix.")


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	var cells: Array[Vector2] = []
	for col in range(-2, 3):
		for row in range(-22, 2):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(DUNGEON + "floor_tile_large.glb", cells)

	for corridor in CORRIDORS:
		_corridor(corridor.x, corridor.y)
	for room in ROOMS:
		_room(room.x, room.y)

	# Les grilles, à l'entrée des couloirs.
	for gz: float in [-30.0, -62.0]:
		for x: float in [-2.6, 2.6]:
			grave_piece("fence_pillar", Vector3(x, 0.0, gz))
	add_gate(Vector3(0.0, 0.0, -30.0), 1)
	add_gate(Vector3(0.0, 0.0, -62.0), 2)

	# Le fond : un mur derrière le héros au départ, la sortie au nord.
	solid(Vector3(0.0, 0.0, 5.5), Vector3(2.0 * CORRIDOR, 4.0, 1.0))
	# Un muret : la caméra est derrière lui au départ et doit voir le héros.
	for x: float in [-2.0, 2.0]:
		place("wall.glb", Vector3(x, 0.0, 5.5), 0.0, 0.35)
	place("wall_doorway.glb", Vector3(0.0, 0.0, -88.5), 0.0, 1.0, true)
	solid(Vector3(0.0, 0.0, -89.5), Vector3(6.6, 4.0, 1.0))
	for x: float in [-2.0, 2.0]:
		place("wall.glb", Vector3(x, 0.0, -89.5), 0.0, 1.0, true)
	flame(Vector3(0.0, 2.6, -87.4), 2.6, 9.0)

	# Les ossements.
	_bones(Vector3(-2.2, 0.0, -5.0))
	_bones(Vector3(2.2, 0.0, -9.5))
	_bones(Vector3(-7.5, 0.0, -14.5))
	_bones(Vector3(7.5, 0.0, -26.0))
	_bones(Vector3(-2.2, 0.0, -37.0))
	_bones(Vector3(7.8, 0.0, -44.0))
	_bones(Vector3(-7.8, 0.0, -58.0))
	_bones(Vector3(2.2, 0.0, -66.0))
	_bones(Vector3(-7.5, 0.0, -72.5))
	_bones(Vector3(7.5, 0.0, -86.0))
	grave_piece("coffin", Vector3(-7.0, 0.0, -20.0), 0.0)
	solid(Vector3(-7.0, 0.0, -20.0), Vector3(2.0, 1.4, 3.0))
	grave_piece("coffin", Vector3(7.2, 0.0, -51.0), 0.0)
	solid(Vector3(7.2, 0.0, -51.0), Vector3(2.0, 1.4, 3.0))
	grave_piece("shrine_candles", Vector3(0.0, 0.0, -59.0))
	flame(Vector3(0.0, 1.6, -58.6), 1.8, 8.0)
	place("barrel_small_stack.glb", Vector3(7.5, 0.0, -13.5), 30.0)
	place("barrel_large.glb", Vector3(-7.6, 0.0, -43.5))
	solid(Vector3(-7.6, 0.0, -43.5), Vector3(1.8, 2.0, 1.8))
	grave_piece("coffin", Vector3(-7.0, 0.0, -80.0), 0.0)
	solid(Vector3(-7.0, 0.0, -80.0), Vector3(2.0, 1.4, 3.0))


## Un couloir nord-sud, ses murs et une torche de chaque côté.
func _corridor(south: float, north: float) -> void:
	var z := south - 2.0
	while z > north + 1.0:
		for side: float in [-1.0, 1.0]:
			place("wall.glb", Vector3(side * (CORRIDOR + 0.5), 0.0, z), -90.0 * side)
		z -= 4.0
	var length := south - north
	for side: float in [-1.0, 1.0]:
		solid(Vector3(side * (CORRIDOR + 0.5), 0.0, (south + north) / 2.0), Vector3(1.0, 4.0, length))
	var middle := (south + north) / 2.0
	_torch(Vector3(-CORRIDOR, 2.3, middle), 90.0)


## Une salle : murs de côté, mur du nord de part et d'autre de la sortie,
## et deux torches. Le côté sud reste ouvert vers la caméra.
func _room(south: float, north: float) -> void:
	var z := south - 2.0
	while z > north + 1.0:
		for side: float in [-1.0, 1.0]:
			place("wall.glb", Vector3(side * (ROOM + 0.5), 0.0, z), -90.0 * side)
		z -= 4.0
	for x: float in [-5.0, -8.0, 5.0, 8.0]:
		place("wall.glb", Vector3(x, 0.0, north - 0.5), 0.0, 1.0, true)
	var length := south - north
	for side: float in [-1.0, 1.0]:
		solid(Vector3(side * (ROOM + 0.5), 0.0, (south + north) / 2.0), Vector3(1.0, 4.0, length))
		solid(Vector3(side * 6.5, 0.0, north - 0.5), Vector3(7.0, 4.0, 1.0))
		solid(Vector3(side * 6.5, 0.0, south + 0.5), Vector3(7.0, 4.0, 1.0))
		for x: float in [5.0, 9.0]:
			place("wall.glb", Vector3(side * x, 0.0, south + 0.5))
	_torch(Vector3(-ROOM, 2.3, (south + north) / 2.0), 90.0)
	_torch(Vector3(ROOM, 2.3, (south + north) / 2.0 - 4.0), -90.0)


func _torch(pos: Vector3, yaw_deg: float) -> void:
	place("torch_mounted.glb", pos, yaw_deg)
	var forward := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	flame(pos + forward * 0.7 + Vector3(0.0, 0.6, 0.0), 2.8, 12.0)


## Un tas d'ossements : crâne, os, cage thoracique.
func _bones(at: Vector3) -> void:
	var skull := grave_piece("skull", at + Vector3(0.0, 0.0, 0.0), at.z * 13.0)
	skull.scale = Vector3.ONE * 0.45
	grave_piece("bone_A", at + Vector3(0.6, 0.05, 0.4), at.z * 31.0)
	grave_piece("bone_B", at + Vector3(-0.5, 0.05, -0.3), at.z * 7.0)
	if int(absf(at.z)) % 2 == 0:
		grave_piece("ribcage", at + Vector3(0.3, 0.3, -0.7), at.z * 17.0)
