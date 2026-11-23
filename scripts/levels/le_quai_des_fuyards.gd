class_name LeQuaiDesFuyards
extends Level
## Niveau 11 — Le Quai des fuyards.
##
## Chapitre III, « Les Quais noirs ». Le port fluvial de la ville basse : un
## long quai de pierre, le fleuve en contrebas du côté de la caméra (+X), où
## les barges des fuyards sont encore amarrées, et les entrepôts de l'autre
## côté (-X). Les morts du chapitre I et II reviennent, plus solides.
##
##   z =   6 : entrée, depuis la ville basse
##   z = -26 : première barricade
##   z = -52 : seconde barricade
##   z = -80 : mur du fond, vers les barges

const HALF_WIDTH := 8.6
const GATE_Z: Array[float] = [-26.0, -52.0]


func _init() -> void:
	title = "Le Quai des fuyards"
	chapter = 3
	scenery = Scenery.RIVER
	water_x = HALF_WIDTH - 0.6
	play_area = Rect2(-HALF_WIDTH, -80.0, 2.0 * HALF_WIDTH, 88.0)
	next_level = &""


func _checkpoint_position(index: int) -> Vector3:
	match index:
		1:
			return Vector3(0.0, 0.0, -29.0)
		2:
			return Vector3(0.0, 0.0, -55.0)
	return Vector3(0.0, 0.0, 5.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _the_quay()
	if checkpoint <= 1:
		await _the_crates()
	await _the_last_barges()
	await _leave()


## Les fuyards, descendus des barges : des Dépouilles, et ce qui sort des planches.
func _the_quay() -> void:
	await say("LES QUAIS NOIRS", 2.5)
	await reach(Vector3(0.0, 0.0, -2.0), 3.0)
	hud.show_message("Les barges des fuyards sont encore à quai.\nCeux qui en sont descendus attendent toujours.", 5.0)
	spawn_group(&"depouille", [Vector3(-4.0, 0.0, -10.0), Vector3(3.0, 0.0, -12.0), Vector3(-1.0, 0.0, -16.0)])
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"fouisseur", Vector3(6.0, 0.0, -14.0))
	spawn_group(&"depouille", [Vector3(4.0, 0.0, -20.0), Vector3(-4.0, 0.0, -21.0)])
	await until_peace()
	hud.show_message("La barricade s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


## Des archers postés derrière les caisses.
func _the_crates() -> void:
	spawn(&"archer_creux", Vector3(-6.5, 0.0, -42.0))
	spawn(&"archer_creux", Vector3(6.0, 0.0, -47.0))
	spawn_group(&"depouille", [Vector3(-2.0, 0.0, -35.0), Vector3(3.0, 0.0, -38.0), Vector3(0.0, 0.0, -44.0)])
	hud.show_message("Des archers, derrière les caisses.", 4.0)
	await wait_until(func() -> bool: return standing_count() <= 2)
	spawn(&"fouisseur", Vector3(-5.0, 0.0, -33.0))
	spawn_group(&"depouille", [Vector3(4.0, 0.0, -33.0), Vector3(-3.0, 0.0, -48.0)])
	await until_peace()
	hud.show_message("La dernière barricade s'ouvre.", 2.5)
	open_gate(1)
	await reach(_checkpoint_position(2), 3.0)
	mark_checkpoint(2)


## Le bout du quai : une Veuve veille sur les derniers débarqués.
func _the_last_barges() -> void:
	hud.show_message("Une Veuve veille au bout du quai.", 3.5)
	spawn(&"veuve", Vector3(-4.0, 0.0, -74.0))
	spawn(&"archer_creux", Vector3(6.0, 0.0, -70.0))
	spawn_group(&"depouille", [Vector3(-3.0, 0.0, -62.0), Vector3(3.0, 0.0, -63.0), Vector3(0.0, 0.0, -67.0)], 15.0)
	await wait_until(func() -> bool: return standing_count() <= 2)
	spawn_group(&"depouille", [Vector3(-5.0, 0.0, -69.0), Vector3(5.0, 0.0, -66.0)], 15.0)
	await until_peace()


func _leave() -> void:
	await victory("Le quai se tait. Le fleuve, lui, coule encore.")


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	var cells: Array[Vector2] = []
	for col in range(-2, 3):
		for row in range(-20, 3):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(DUNGEON + "floor_tile_large.glb", cells)

	# Le bord du quai, côté fleuve, et ce qui flotte en contrebas.
	Docks.quay_edge(self, HALF_WIDTH, 8.0, -80.0)
	Docks.piles(self, HALF_WIDTH + 1.4, 6.0, -80.0, 5.0)
	for z: float in [-4.0, -19.0, -37.0, -58.0, -73.0]:
		Docks.barge(self, Vector3(HALF_WIDTH + 4.6, 0.0, z), 11.0, 0.0, int(z) % 2 == 0)
	Docks.barge(self, Vector3(HALF_WIDTH + 10.5, 0.0, -30.0), 9.0, 8.0, false)

	# Les entrepôts, de l'autre côté : un long mur, des torches, des tonneaux.
	var z := 6.0
	while z > -80.5:
		place("wall.glb", Vector3(-HALF_WIDTH, 0.0, z), 90.0)
		z -= 4.0
	solid(Vector3(-HALF_WIDTH, 0.0, -37.0), Vector3(1.0, 4.0, 90.0))
	for tz: float in [-6.0, -20.0, -36.0, -48.0, -62.0, -76.0]:
		wall_torch(Vector3(-HALF_WIDTH + 0.5, 1.8, tz), 90.0, 2.4, 11.0)
	for bz: float in [-13.0, -40.0, -67.0]:
		place("barrel_large.glb", Vector3(-7.3, 0.0, bz), 25.0)
		place("barrel_small_stack.glb", Vector3(-7.2, 0.0, bz - 2.0), -15.0)

	# Des caisses débarquées, en abri, et des réverbères.
	Docks.crates(self, Vector3(-4.5, 0.0, -9.0), 10.0)
	Docks.crates(self, Vector3(4.6, 0.0, -17.0), -8.0, true)
	Docks.crates(self, Vector3(-3.8, 0.0, -38.5), 0.0, true)
	Docks.crates(self, Vector3(3.6, 0.0, -43.0), 14.0)
	Docks.crates(self, Vector3(-5.2, 0.0, -46.0), -6.0)
	Docks.crates(self, Vector3(4.2, 0.0, -66.0), 6.0, true)
	for lz: float in [-1.0, -31.0, -58.0]:
		grave_piece("post_lantern", Vector3(6.6, 0.0, lz))
		flame(Vector3(6.6, 2.6, lz + 0.4), 2.2, 10.0)

	# Les deux barricades : des caisses sur toute la largeur, une barrière au milieu.
	for gz in GATE_Z:
		for x: float in [-3.4, -5.7, -8.0, 3.4, 5.7, 8.0]:
			Docks.crates(self, Vector3(x, 0.0, gz), 0.0, absf(x) > 5.0)
		for x: float in [-2.1, 2.1]:
			grave_piece("fence_pillar", Vector3(x, 0.0, gz))
		for x: float in [-5.4, 5.4]:
			solid(Vector3(x, 0.0, gz), Vector3(6.6, 4.0, 0.8))
	add_gate(Vector3(0.0, 0.0, GATE_Z[0]), 1)
	add_gate(Vector3(0.0, 0.0, GATE_Z[1]), 2)

	# Le fond : un muret derrière le héros au départ (la caméra est derrière),
	# le mur haut au nord.
	for x: float in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		place("wall.glb", Vector3(x, 0.0, 8.0), 0.0, 0.35)
	solid(Vector3(0.0, 0.0, 8.0), Vector3(2.0 * HALF_WIDTH + 1.0, 4.0, 1.0))
	place("wall_doorway.glb", Vector3(0.0, 0.0, -80.5), 0.0, 1.0, true)
	for x: float in [-4.0, 4.0, -8.0, 8.0]:
		place("wall.glb", Vector3(x, 0.0, -80.5), 0.0, 1.0, true)
	solid(Vector3(0.0, 0.0, -80.5), Vector3(2.0 * HALF_WIDTH + 1.0, 4.0, 1.0))
