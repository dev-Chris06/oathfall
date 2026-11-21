class_name LesAllees
extends Level
## Niveau 2 — Les Allées.
##
## Une longue allée entre deux rangées de mausolées, fermée de grilles entre
## les tombeaux. Les Archers creux se postent au bord de l'allée. Le joueur y apprend à
## choisir ses cibles : l'archer qui tire de loin, puis le Porte-cloche dont
## la cloche presse tous les corps de se relever.
##
##   z =   4 : entrée, depuis la Grille
##   z = -26 : première grille
##   z = -52 : seconde grille
##   z = -80 : sortie, vers la Chapelle des cendres

const HALF_WIDTH := 6.0
const GATE_Z: Array[float] = [-26.0, -52.0]
## Centre des mausolées le long de l'allée, de chaque côté.
const CRYPT_Z: Array[float] = [-6.0, -16.0, -32.0, -42.0, -58.0, -68.0]
const EXIT := Vector3(0.0, 0.0, -77.0)


func _init() -> void:
	title = "Les Allées"
	play_area = Rect2(-6.4, -81.0, 12.8, 91.0)
	next_level = &"la_chapelle"


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
		await _archers()
	if checkpoint <= 1:
		await _first_bell()
	await _last_stretch()
	await _leave()


## Les archers : les premiers morts qui frappent de loin.
func _archers() -> void:
	await say("LES ALLÉES", 2.5)
	await reach(Vector3(0.0, 0.0, -3.0), 3.0)
	spawn_group(&"depouille", [Vector3(-2.0, 0.0, -13.0), Vector3(2.0, 0.0, -15.0)])
	spawn(&"archer_creux", Vector3(-5.0, 0.0, -11.0))
	hud.show_message("Un archer, entre les tombeaux.\nUn trait rouge : il va tirer. ESQUIVE.", 5.0)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"archer_creux", Vector3(5.0, 0.0, -21.5))
	spawn(&"depouille", Vector3(-3.0, 0.0, -21.0))
	await until_peace()
	hud.show_message("La grille s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


## Le premier Porte-cloche, au milieu des Dépouilles.
func _first_bell() -> void:
	spawn(&"porte_cloche", Vector3(0.0, 0.0, -45.0))
	spawn_group(&"depouille", [Vector3(-3.0, 0.0, -36.0), Vector3(3.0, 0.0, -38.0),
		Vector3(5.0, 0.0, -47.0)])
	hud.show_message("Une cloche. Tant qu'elle sonne,\nles corps se relèvent plus vite.", 5.0)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"depouille", Vector3(-2.0, 0.0, -31.0))
	await until_peace()
	hud.show_message("La dernière grille s'ouvre.", 2.5)
	open_gate(1)
	await reach(_checkpoint_position(2), 3.0)
	mark_checkpoint(2)


## Tout ensemble : archers, cloche, et des corps qui se relèvent vite.
func _last_stretch() -> void:
	hud.show_message("Choisis bien qui frapper d'abord.", 3.5)
	spawn(&"archer_creux", Vector3(-5.0, 0.0, -63.0))
	spawn(&"porte_cloche", Vector3(0.0, 0.0, -70.0))
	spawn_group(&"depouille", [Vector3(-2.0, 0.0, -60.0), Vector3(2.0, 0.0, -61.0)], 15.0)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"archer_creux", Vector3(5.0, 0.0, -73.0))
	spawn_group(&"depouille", [Vector3(-3.0, 0.0, -66.0), Vector3(3.0, 0.0, -67.0)], 15.0)
	await until_peace()


func _leave() -> void:
	await victory("Les Allées se taisent.")


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	var cells: Array[Vector2] = []
	for col in range(-4, 5):
		for row in range(-21, 3):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(GRAVEYARD + "floor_dirt.gltf", cells)

	# Le chemin dallé au milieu de l'allée.
	var stones: Array[Vector2] = []
	for row in range(-39, 3):
		stones.append(Vector2(0.0, row * 2.0))
	pave(GRAVEYARD + "path_A.gltf", stones)

	# Les mausolées, portes tournées vers l'allée, et des grilles entre eux.
	for i in CRYPT_Z.size():
		var z := CRYPT_Z[i]
		for side: float in [-1.0, 1.0]:
			grave_piece("crypt", Vector3(side * 10.0, 0.0, z), -90.0 * side)
			grave_piece("fence", Vector3(side * 6.3, 0.0, z - 5.0), 90.0)
		# Une lanterne à la porte d'un mausolée sur deux.
		if i % 2 == 0:
			var side := -1.0 if i % 4 == 0 else 1.0
			grave_piece("lantern_standing", Vector3(side * 5.5, 0.0, z + 2.0))
			flame(Vector3(side * 5.5, 1.0, z + 2.3), 2.0, 9.0)
	for z: float in [1.0, -21.5, -47.5, -73.5]:
		for side: float in [-1.0, 1.0]:
			grave_piece("fence", Vector3(side * 6.3, 0.0, z), 90.0)

	# Derrière les grilles, des stèles et des os.
	for z: float in [-11.0, -37.0, -63.0]:
		grave_piece("gravestone", Vector3(-8.5, 0.0, z), 90.0)
		grave_piece("gravemarker_A", Vector3(8.6, 0.0, z - 10.0), -90.0)
	grave_piece("ribcage", Vector3(8.5, 0.3, -48.0), 40.0)
	grave_piece("bone_A", Vector3(-2.5, 0.05, -40.0), 10.0)
	grave_piece("bone_B", Vector3(3.0, 0.05, -64.0), 80.0)

	# L'entrée, depuis la Grille.
	grave_piece("arch", Vector3(0.0, 0.0, 3.0))
	for x: float in [-4.1, 4.1]:
		grave_piece("fence", Vector3(x, 0.0, 3.0))
	grave_piece("tree_dead_large", Vector3(-9.5, 0.0, 6.5), 30.0)
	grave_piece("tree_dead_medium", Vector3(9.0, 0.0, 7.0), -50.0)

	# Les deux grilles.
	for gz in GATE_Z:
		for x: float in [-4.1, 4.1]:
			grave_piece("fence", Vector3(x, 0.0, gz))
		for x: float in [-2.1, 2.1]:
			grave_piece("fence_pillar", Vector3(x, 0.0, gz))
		for x: float in [-4.2, 4.2]:
			solid(Vector3(x, 0.0, gz), Vector3(4.2, 4.0, 0.6))
	add_gate(Vector3(0.0, 0.0, GATE_Z[0]), 1)
	add_gate(Vector3(0.0, 0.0, GATE_Z[1]), 2)

	# La sortie, vers la Chapelle des cendres.
	grave_piece("arch", Vector3(0.0, 0.0, -80.0))
	for x: float in [-4.1, 4.1]:
		grave_piece("fence", Vector3(x, 0.0, -80.0))
	grave_piece("post_lantern", Vector3(-3.0, 0.0, -78.5))
	flame(Vector3(-3.0, 2.6, -78.1), 2.4, 10.0)
	grave_piece("tree_dead_large", Vector3(9.0, 0.0, -82.0), 120.0)

	# Les bords : l'allée est fermée de part et d'autre.
	# Le chemin d'arrivée est clos de clôtures (les murs latéraux laissaient
	# un passage de 1,2 dans les coins du fond).
	for side: float in [-1.0, 1.0]:
		grave_piece("fence", Vector3(side * HALF_WIDTH, 0.0, 7.0), 90.0)
		grave_piece("fence_pillar", Vector3(side * HALF_WIDTH, 0.0, 9.5))
	for x: float in [-4.0, 0.0, 4.0]:
		grave_piece("fence", Vector3(x, 0.0, 9.5))
	solid(Vector3(-HALF_WIDTH - 0.3, 0.0, -37.1), Vector3(0.6, 4.0, 93.8))
	solid(Vector3(HALF_WIDTH + 0.3, 0.0, -37.1), Vector3(0.6, 4.0, 93.8))
	solid(Vector3(0.0, 0.0, 9.5), Vector3(2.0 * HALF_WIDTH, 4.0, 0.6))
	solid(Vector3(0.0, 0.0, -80.5), Vector3(2.0 * HALF_WIDTH, 4.0, 0.6))
	for x: float in [-4.2, 4.2]:
		solid(Vector3(x, 0.0, 3.0), Vector3(4.2, 4.0, 0.6))
