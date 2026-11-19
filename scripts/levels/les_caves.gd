class_name LesCaves
extends Level
## Niveau 9 — Les Caves du marché.
##
## Chapitre II. Sous les halles, les caves où les marchands gardaient leurs
## réserves : des couloirs étroits, trois salles de tonneaux. Le joueur y
## retrouve le Boucher et le Crieur, mêlés aux morts des caves : le Fouisseur,
## la Veuve et le Porte-cloche.
##
##   z =   4 … -12 : premier couloir
##   z = -12 … -30 : première salle        grille z = -32
##   z = -30 … -44 : deuxième couloir
##   z = -44 … -62 : deuxième salle        grille z = -64
##   z = -62 … -76 : troisième couloir
##   z = -76 … -94 : dernière salle, sortie au nord, vers la Halle du Prévôt

const CORRIDOR := 3.0
const ROOM := 8.5
## Les salles : [z sud, z nord].
const ROOMS: Array[Vector2] = [Vector2(-12.0, -30.0), Vector2(-44.0, -62.0), Vector2(-76.0, -94.0)]
## Les couloirs : [z sud, z nord].
const CORRIDORS: Array[Vector2] = [Vector2(5.0, -12.0), Vector2(-30.0, -44.0), Vector2(-62.0, -76.0)]
const EXIT := Vector3(0.0, 0.0, -92.0)


func _init() -> void:
	title = "Les Caves du marché"
	chapter = 2
	play_area = Rect2(-9.0, -96.0, 18.0, 101.0)
	underground = true
	next_level = &"la_halle_du_prevot"


func _checkpoint_position(index: int) -> Vector3:
	match index:
		1:
			return Vector3(0.0, 0.0, -36.0)
		2:
			return Vector3(0.0, 0.0, -69.0)
	return Vector3(0.0, 0.0, 2.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _first_room()
	if checkpoint <= 1:
		await _second_room()
	await _last_room()
	await _leave()


## Le couloir d'entrée, puis la première salle : un Boucher dans l'étroit.
func _first_room() -> void:
	await say("LES CAVES DU MARCHÉ", 2.8)
	hud.show_message("Sous les halles, les réserves des marchands.\nLes couloirs sont étroits.", 4.0)
	await reach(Vector3(0.0, 0.0, -2.0), 3.0)
	spawn_group(&"depouille", [Vector3(-1.5, 0.0, -8.0), Vector3(1.5, 0.0, -10.0)])
	await until_peace()
	await reach(Vector3(0.0, 0.0, -15.0), 3.0)
	spawn(&"boucher", Vector3(0.0, 0.0, -27.0))
	spawn_group(&"depouille", [Vector3(-6.0, 0.0, -24.0), Vector3(6.0, 0.0, -25.0)])
	hud.show_message("Un Boucher dans la salle : recule dans le couloir\net frappe-le quand il a manqué son coup.", 5.0)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"fouisseur", Vector3(7.0, 0.0, -20.0))
	await until_peace()
	hud.show_message("La grille du couloir s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


## Le second couloir, puis la salle du Crieur et de la cloche.
func _second_room() -> void:
	spawn(&"fouisseur", Vector3(2.0, 0.0, -42.0))
	await until_peace()
	await reach(Vector3(0.0, 0.0, -46.0), 3.0)
	spawn(&"crieur", Vector3(0.0, 0.0, -59.0))
	spawn_group(&"depouille", [Vector3(-5.0, 0.0, -52.0), Vector3(5.0, 0.0, -54.0), Vector3(0.0, 0.0, -50.0)])
	hud.show_message("Le Crieur presse les morts debout.\nAbats-le en premier.", 5.0)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"porte_cloche", Vector3(0.0, 0.0, -58.0))
	spawn_group(&"depouille", [Vector3(-6.0, 0.0, -56.0), Vector3(6.0, 0.0, -47.0)], 15.0)
	await until_peace()
	hud.show_message("La grille s'ouvre.", 2.5)
	open_gate(1)
	await reach(_checkpoint_position(2), 3.0)
	mark_checkpoint(2)


## La dernière salle : tous les morts du chapitre.
func _last_room() -> void:
	await reach(Vector3(0.0, 0.0, -78.0), 3.0)
	hud.show_message("Toute la boucherie est descendue ici.", 3.5)
	spawn(&"veuve", Vector3(-6.0, 0.0, -91.0))
	spawn(&"crieur", Vector3(6.0, 0.0, -91.0))
	spawn(&"boucher", Vector3(0.0, 0.0, -86.0))
	spawn_group(&"depouille", [Vector3(-3.0, 0.0, -83.0), Vector3(3.0, 0.0, -84.0)], 16.0)
	await wait_until(func() -> bool: return standing_count() <= 2)
	spawn(&"boucher", Vector3(-4.0, 0.0, -88.0))
	spawn(&"fouisseur", Vector3(7.0, 0.0, -82.0))
	await until_peace()


func _leave() -> void:
	await say("Les caves sont silencieuses.", 2.5)
	hud.show_message("Au bout, l'escalier vers la Halle du Prévôt.", 4.0)
	await reach(EXIT, 2.5)
	finish()


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	var cells: Array[Vector2] = []
	for col in range(-2, 3):
		for row in range(-24, 2):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(DUNGEON + "floor_tile_large.glb", cells)

	for corridor in CORRIDORS:
		_corridor(corridor.x, corridor.y)
	for room in ROOMS:
		_room(room.x, room.y)
	# Les grilles, à l'entrée des couloirs.
	for gz: float in [-32.0, -64.0]:
		for x: float in [-2.6, 2.6]:
			grave_piece("fence_pillar", Vector3(x, 0.0, gz))
	add_gate(Vector3(0.0, 0.0, -32.0), 1)
	add_gate(Vector3(0.0, 0.0, -64.0), 2)

	# Le fond : un muret derrière le héros au départ, la sortie au nord.
	solid(Vector3(0.0, 0.0, 5.5), Vector3(2.0 * CORRIDOR, 4.0, 1.0))
	for x: float in [-2.0, 2.0]:
		place("wall.glb", Vector3(x, 0.0, 5.5), 0.0, 0.35)
	place("wall_doorway.glb", Vector3(0.0, 0.0, -94.5), 0.0, 1.0, true)
	solid(Vector3(0.0, 0.0, -95.5), Vector3(6.6, 4.0, 1.0))
	for x: float in [-2.0, 2.0]:
		place("wall.glb", Vector3(x, 0.0, -95.5), 0.0, 1.0, true)
	flame(Vector3(0.0, 2.6, -93.4), 2.6, 9.0)

	# Les réserves : tonneaux, caisses, dans les salles.
	for at: Vector3 in [Vector3(-7.4, 0.0, -14.5), Vector3(7.4, 0.0, -28.0), Vector3(-7.4, 0.0, -46.5),
			Vector3(7.4, 0.0, -60.0), Vector3(-7.4, 0.0, -78.5), Vector3(7.4, 0.0, -92.0)]:
		place("barrel_large.glb", at, at.z * 9.0)
		solid(at, Vector3(1.8, 2.0, 1.8))
	for at: Vector3 in [Vector3(7.4, 0.0, -14.5), Vector3(-7.4, 0.0, -28.5), Vector3(7.2, 0.0, -46.5),
			Vector3(-7.2, 0.0, -60.0), Vector3(-7.2, 0.0, -92.0)]:
		place("barrel_small_stack.glb", at, at.z * 7.0)
		solid(at, Vector3(1.8, 1.4, 1.8))
	# Des carcasses suspendues, au fond de chaque salle.
	for z: float in [-27.0, -59.0, -91.0]:
		_hanging_meat(Vector3(-5.5, 0.0, z))
		_hanging_meat(Vector3(5.5, 0.0, z - 2.0))


## Quelques carcasses pendues à une poutre.
func _hanging_meat(at: Vector3) -> void:
	var meat := Fx.flat(Color(0.46, 0.1, 0.09), 0.0, 0.6)
	for k in 3:
		var piece := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.16
		capsule.height = 0.8
		capsule.radial_segments = 8
		capsule.rings = 3
		piece.mesh = capsule
		piece.material_override = meat
		piece.position = at + Vector3(0.9 * (k - 1), 3.0, 0.0)
		add_child(piece)


## Un couloir nord-sud, ses murs et une torche.
func _corridor(south: float, north: float) -> void:
	var z := south - 2.0
	while z > north + 1.0:
		for side: float in [-1.0, 1.0]:
			place("wall.glb", Vector3(side * (CORRIDOR + 0.5), 0.0, z), -90.0 * side)
		z -= 4.0
	var length := south - north
	for side: float in [-1.0, 1.0]:
		solid(Vector3(side * (CORRIDOR + 0.5), 0.0, (south + north) / 2.0), Vector3(1.0, 4.0, length))
	_torch(Vector3(-CORRIDOR, 2.3, (south + north) / 2.0), 90.0)


## Une salle : murs de côté, mur du nord de part et d'autre de la sortie, mur
## du sud de part et d'autre du couloir, et deux torches.
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
