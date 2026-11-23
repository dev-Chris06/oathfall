class_name LesBarges
extends Level
## Niveau 12 — Les Barges.
##
## Chapitre III. Un long ponton de bois s'avance sur le fleuve, entre les
## barges amarrées de part et d'autre. L'eau est des deux côtés : les Noyés en
## sortent, et leurs corps y retournent. Arrivée du Noyé et du Gaffeur.
##
##   z =   6 : entrée, depuis le quai
##   z = -26 : première barricade
##   z = -52 : seconde barricade
##   z = -80 : bout du ponton

const HALF_WIDTH := 6.0
const GATE_Z: Array[float] = [-26.0, -52.0]

var _first_noye_down := false


func _init() -> void:
	title = "Les Barges"
	chapter = 3
	scenery = Scenery.RIVER
	play_area = Rect2(-HALF_WIDTH, -80.0, 2.0 * HALF_WIDTH, 88.0)


func _checkpoint_position(index: int) -> Vector3:
	match index:
		1:
			return Vector3(0.0, 0.0, -29.0)
		2:
			return Vector3(0.0, 0.0, -55.0)
	return Vector3(0.0, 0.0, 5.0)


## L'eau est des deux côtés du ponton : le bord le plus proche.
func water_edge(from: Vector3) -> Variant:
	var edge := HALF_WIDTH - 0.5
	return Vector3(edge if from.x >= 0.0 else -edge, 0.0, from.z)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _the_drowned()
	if checkpoint <= 1:
		await _the_boatmen()
	await _the_end_of_the_pier()
	await _leave()


## Le fleuve rend ses noyés.
func _the_drowned() -> void:
	await say("LES BARGES", 2.5)
	await reach(Vector3(0.0, 0.0, -2.0), 3.0)
	hud.show_message("Le fleuve rend ceux qu'il a pris.", 4.0)
	var first := spawn(&"noye", Vector3(-4.0, 0.0, -11.0))
	spawn(&"noye", Vector3(4.0, 0.0, -14.0))
	spawn(&"depouille", Vector3(0.0, 0.0, -16.0))
	first.fell.connect(func(_e: Enemy) -> void:
		if not _first_noye_down:
			_first_noye_down = true
			hud.show_message("Son corps glisse vers l'eau.\nDonne-lui le Repos avant qu'il n'y tombe.", 5.0))
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn_group(&"noye", [Vector3(4.5, 0.0, -20.0), Vector3(-4.5, 0.0, -21.0)])
	spawn(&"depouille", Vector3(0.0, 0.0, -22.0))
	await until_peace()
	hud.show_message("La barricade s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


## Les bateliers et leurs gaffes.
func _the_boatmen() -> void:
	spawn(&"gaffeur", Vector3(0.0, 0.0, -40.0))
	spawn_group(&"depouille", [Vector3(-3.0, 0.0, -35.0), Vector3(3.0, 0.0, -37.0)])
	hud.show_message("Un Gaffeur. Quand le trait orangé paraît, esquive :\nsa gaffe te tirerait à lui.", 5.0)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"gaffeur", Vector3(-3.0, 0.0, -47.0))
	spawn(&"noye", Vector3(4.5, 0.0, -44.0))
	spawn(&"depouille", Vector3(2.0, 0.0, -46.0))
	await until_peace()
	hud.show_message("La dernière barricade s'ouvre.", 2.5)
	open_gate(1)
	await reach(_checkpoint_position(2), 3.0)
	mark_checkpoint(2)


## Le bout du ponton : tout ce que le port a gardé.
func _the_end_of_the_pier() -> void:
	spawn(&"gaffeur", Vector3(3.0, 0.0, -72.0))
	spawn(&"archer_creux", Vector3(-4.0, 0.0, -75.0))
	spawn_group(&"noye", [Vector3(-4.5, 0.0, -62.0), Vector3(4.5, 0.0, -64.0)], 15.0)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"noye", Vector3(4.5, 0.0, -68.0))
	spawn(&"depouille", Vector3(-2.0, 0.0, -70.0))
	await until_peace()


func _leave() -> void:
	await victory("Les barges dérivent, vides.")


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	# Le ponton : un plancher, posé sur des pieux, l'eau des deux côtés.
	floor_bounds = Rect2(-HALF_WIDTH - 0.4, -81.0, 2.0 * HALF_WIDTH + 0.8, 90.0)
	Docks.deck(self, floor_bounds)
	for side: float in [-1.0, 1.0]:
		Docks.rail(self, side * HALF_WIDTH, 8.5, -80.5)
		Docks.piles(self, side * (HALF_WIDTH + 0.9), 7.0, -80.0, 4.0)
	# Les barges amarrées, à gauche et à droite.
	for z: float in [-6.0, -22.0, -41.0, -60.0, -75.0]:
		Docks.barge(self, Vector3(HALF_WIDTH + 3.4, 0.0, z), 12.0, 0.0, int(z) % 2 == 0)
	for z: float in [-12.0, -31.0, -50.0, -68.0]:
		Docks.barge(self, Vector3(-HALF_WIDTH - 3.4, 0.0, z), 12.0, 180.0, int(z) % 4 == 0)

	# Des caisses débarquées, contre la lisse : pas de couloir étroit entre les
	# deux, où le héros se coincerait. Des lanternes sur des poteaux.
	var flush := HALF_WIDTH - 0.3 - 1.2
	Docks.crates(self, Vector3(-flush, 0.0, -7.0), 3.0)
	Docks.crates(self, Vector3(flush, 0.0, -18.5), -3.0, true)
	Docks.crates(self, Vector3(-flush, 0.0, -42.0), 4.0, true)
	Docks.crates(self, Vector3(flush, 0.0, -63.0), -2.0)
	for lz: float in [-2.0, -33.0, -58.0]:
		for side: float in [-1.0, 1.0]:
			grave_piece("post_lantern", Vector3(side * (HALF_WIDTH - 0.9), 0.0, lz + side * 6.0))
			flame(Vector3(side * (HALF_WIDTH - 0.9), 2.6, lz + side * 6.0 + 0.4), 2.2, 10.0)

	# Les deux barricades.
	for gz in GATE_Z:
		for x: float in [-3.4, -5.0, 3.4, 5.0]:
			Docks.crates(self, Vector3(x, 0.0, gz), 0.0, absf(x) > 4.0)
		for x: float in [-2.1, 2.1]:
			grave_piece("fence_pillar", Vector3(x, 0.0, gz))
		for x: float in [-4.1, 4.1]:
			solid(Vector3(x, 0.0, gz), Vector3(3.9, 4.0, 0.8))
	add_gate(Vector3(0.0, 0.0, GATE_Z[0]), 1)
	add_gate(Vector3(0.0, 0.0, GATE_Z[1]), 2)

	# L'entrée, derrière le héros (basse : la caméra est derrière elle), et le
	# bout du ponton, fermé de caisses et d'un portique.
	Docks.rail_across(self, 8.5, -HALF_WIDTH, HALF_WIDTH)
	for x: float in [-4.6, -2.3, 0.0, 2.3, 4.6]:
		Docks.crates(self, Vector3(x, 0.0, -80.0), 0.0, true)
	solid(Vector3(0.0, 0.0, -80.3), Vector3(2.0 * HALF_WIDTH, 4.0, 1.0))
	grave_piece("arch", Vector3(0.0, 0.0, -78.8))
	flame(Vector3(-2.5, 2.6, -78.0), 2.4, 10.0)
