class_name LaPorteDesHalles
extends Level
## Niveau 6 — La Porte des halles.
##
## Chapitre II. Une grande place de marché, étals de part et d'autre, que
## des marchands morts tiennent encore. Les morts du chapitre I reviennent ici
## en foule, plus nombreux, répartis entre les étals.
##
##   z =   4 : entrée, depuis la route
##   z = -26 : première barrière
##   z = -52 : seconde barrière
##   z = -80 : sortie, vers les Étals

const HALF_WIDTH := 9.0
const GATE_Z: Array[float] = [-26.0, -52.0]
const STALL_Z: Array[float] = [-8.0, -17.0, -34.0, -43.0, -60.0, -69.0]
const EXIT := Vector3(0.0, 0.0, -77.0)
const CLOTHS: Array[Color] = [Color(0.32, 0.08, 0.07), Color(0.28, 0.2, 0.08), Color(0.12, 0.16, 0.2), Color(0.22, 0.1, 0.16)]


func _init() -> void:
	title = "La Porte des halles"
	chapter = 2
	play_area = Rect2(-9.4, -80.0, 18.8, 89.0)
	next_level = &"les_etals"


func _checkpoint_position(index: int) -> Vector3:
	match index:
		1:
			return Vector3(0.0, 0.0, -29.0)
		2:
			return Vector3(0.0, 0.0, -55.0)
	return Vector3(0.0, 0.0, 6.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _first_crowd()
	if checkpoint <= 1:
		await _behind_the_stalls()
	await _last_stretch()
	await _leave()


## Les marchands : des Dépouilles, derrière leurs étals.
func _first_crowd() -> void:
	await say("LES HALLES", 2.5)
	await reach(Vector3(0.0, 0.0, -3.0), 3.0)
	hud.show_message("Les marchands tiennent encore leurs étals.\nIls ne vendront plus rien.", 4.5)
	spawn_group(&"depouille", [Vector3(-5.0, 0.0, -11.0), Vector3(5.0, 0.0, -13.0), Vector3(-4.0, 0.0, -18.0)])
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn_group(&"depouille", [Vector3(4.0, 0.0, -21.0), Vector3(-2.0, 0.0, -22.0)])
	await until_peace()
	hud.show_message("La barrière s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


## Des archers postés entre les étals.
func _behind_the_stalls() -> void:
	spawn(&"archer_creux", Vector3(-6.5, 0.0, -38.0))
	spawn(&"archer_creux", Vector3(6.5, 0.0, -46.0))
	spawn_group(&"depouille", [Vector3(-2.0, 0.0, -36.0), Vector3(3.0, 0.0, -40.0), Vector3(0.0, 0.0, -45.0)])
	hud.show_message("Des archers, entre les étals.\nTraverse la place d'un abri à l'autre.", 5.0)
	await wait_until(func() -> bool: return standing_count() <= 2)
	spawn_group(&"depouille", [Vector3(-4.0, 0.0, -32.0), Vector3(4.0, 0.0, -33.0)])
	await until_peace()
	hud.show_message("La dernière barrière s'ouvre.", 2.5)
	open_gate(1)
	await reach(_checkpoint_position(2), 3.0)
	mark_checkpoint(2)


## Toute la foule du marché, et sa cloche.
func _last_stretch() -> void:
	hud.show_message("Une cloche appelle la foule.", 3.5)
	spawn(&"porte_cloche", Vector3(0.0, 0.0, -71.0))
	spawn(&"archer_creux", Vector3(-6.5, 0.0, -64.0))
	spawn_group(&"depouille", [Vector3(-3.0, 0.0, -60.0), Vector3(3.0, 0.0, -61.0), Vector3(0.0, 0.0, -66.0)], 15.0)
	await wait_until(func() -> bool: return standing_count() <= 2)
	spawn(&"archer_creux", Vector3(6.5, 0.0, -73.0))
	spawn_group(&"depouille", [Vector3(-4.0, 0.0, -67.0), Vector3(4.0, 0.0, -68.0)], 15.0)
	await until_peace()


func _leave() -> void:
	await say("La place est silencieuse.", 2.5)
	hud.show_message("Plus loin, les étals de la rue des bouchers.", 4.0)
	await reach(EXIT, 2.5)
	finish()


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	var cells: Array[Vector2] = []
	for col in range(-6, 7):
		for row in range(-22, 3):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(GRAVEYARD + "floor_dirt.gltf", cells)
	var stones: Array[Vector2] = []
	for row in range(-39, 3):
		for x: float in [-2.0, 0.0, 2.0]:
			stones.append(Vector2(x, row * 2.0))
	pave(GRAVEYARD + "path_A.gltf", stones)

	# Les étals, face à la place, et un réverbère entre deux.
	for i in STALL_Z.size():
		var z := STALL_Z[i]
		stall(Vector3(-7.4, 0.0, z), 90.0, CLOTHS[i % CLOTHS.size()])
		stall(Vector3(7.4, 0.0, z - 3.0), -90.0, CLOTHS[(i + 2) % CLOTHS.size()])
		if i % 2 == 0:
			var side := -1.0 if i % 4 == 0 else 1.0
			grave_piece("post_lantern", Vector3(side * 4.6, 0.0, z - 5.0))
			flame(Vector3(side * 4.6, 2.6, z - 4.6), 2.2, 10.0)
	for z: float in [-12.5, -38.5, -64.5]:
		place("barrel_large.glb", Vector3(-8.4, 0.0, z), 20.0)
		place("barrel_small_stack.glb", Vector3(8.3, 0.0, z - 6.0), -30.0)

	# Les deux barrières : fermées sur toute la largeur de la place.
	for gz in GATE_Z:
		for x: float in [-4.1, 4.1, -8.3, 8.3]:
			grave_piece("fence", Vector3(x, 0.0, gz))
		for x: float in [-2.1, 2.1]:
			grave_piece("fence_pillar", Vector3(x, 0.0, gz))
		for x: float in [-5.55, 5.55]:
			solid(Vector3(x, 0.0, gz), Vector3(6.9, 4.0, 0.6))
	add_gate(Vector3(0.0, 0.0, GATE_Z[0]), 1)
	add_gate(Vector3(0.0, 0.0, GATE_Z[1]), 2)

	# Porte d'entrée et de sortie.
	for z: float in [3.0, -80.0]:
		grave_piece("arch", Vector3(0.0, 0.0, z))
		for x: float in [-4.1, 4.1, -8.3, 8.3]:
			grave_piece("fence", Vector3(x, 0.0, z))
	flame(Vector3(-3.0, 2.6, -78.1), 2.4, 10.0)
	grave_piece("post_lantern", Vector3(-3.0, 0.0, -78.5))

	# Les bords de la place.
	# Le chemin d'arrivée est clos de clôtures (les murs latéraux laissaient
	# un passage de 1,2 dans les coins du fond).
	for side: float in [-1.0, 1.0]:
		grave_piece("fence", Vector3(side * HALF_WIDTH, 0.0, 7.0), 90.0)
		grave_piece("fence_pillar", Vector3(side * HALF_WIDTH, 0.0, 9.5))
	for x: float in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		grave_piece("fence", Vector3(x, 0.0, 9.5))
	# Des clôtures bordent la place de part et d'autre, d'un bout à l'autre.
	for side: float in [-1.0, 1.0]:
		var z := 8.0
		while z > -80.5:
			grave_piece("fence", Vector3(side * (HALF_WIDTH + 0.2), 0.0, z), 90.0)
			z -= 4.0
	solid(Vector3(-HALF_WIDTH - 0.3, 0.0, -37.1), Vector3(0.6, 4.0, 93.8))
	solid(Vector3(HALF_WIDTH + 0.3, 0.0, -37.1), Vector3(0.6, 4.0, 93.8))
	solid(Vector3(0.0, 0.0, 9.5), Vector3(2.0 * HALF_WIDTH, 4.0, 0.6))
	solid(Vector3(0.0, 0.0, -80.5), Vector3(2.0 * HALF_WIDTH, 4.0, 0.6))
	for x: float in [-5.55, 5.55]:
		solid(Vector3(x, 0.0, 3.0), Vector3(6.9, 4.0, 0.6))
