class_name LeHalage
extends Level
## Niveau 13 — Le Halage : le Haleur.
##
## Chapitre III, boss intermédiaire. Le chemin de halage, le long du fleuve
## (du côté de la caméra, +X), au pied du talus de la ville basse (-X). Une
## première partie de chemin, une barricade, puis la grève élargie où le
## Haleur tire encore sa barge (voir `HaleurEnemy`).
##
##   z =   6 : entrée, depuis les Barges
##   z = -24 : barricade
##   z = -64 : le fond de la grève

const HALF_WIDTH := 8.6
const GATE_Z := -24.0
const BOSS_AT := Vector3(-2.0, 0.0, -47.0)

var boss: HaleurEnemy


func _init() -> void:
	title = "Le Halage"
	chapter = 3
	scenery = Scenery.RIVER
	water_x = HALF_WIDTH - 0.6
	play_area = Rect2(-HALF_WIDTH, -64.0, 2.0 * HALF_WIDTH, 72.0)


func _checkpoint_position(index: int) -> Vector3:
	if index == 1:
		return Vector3(0.0, 0.0, -27.0)
	return Vector3(0.0, 0.0, 5.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _the_towpath()
	await _boss_fight()
	await _leave()


## Le chemin : ceux qui tiraient les barges, et ceux qui en sont tombés.
func _the_towpath() -> void:
	await say("LE HALAGE", 2.5)
	await reach(Vector3(0.0, 0.0, -2.0), 3.0)
	hud.show_message("Le chemin de halage. On y tirait les barges\nà contre-courant, à la force des épaules.", 5.0)
	spawn_group(&"noye", [Vector3(5.0, 0.0, -9.0), Vector3(4.0, 0.0, -14.0)])
	spawn(&"depouille", Vector3(-3.0, 0.0, -12.0))
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"gaffeur", Vector3(0.0, 0.0, -20.0))
	spawn_group(&"depouille", [Vector3(-4.0, 0.0, -17.0), Vector3(3.0, 0.0, -18.0)])
	await until_peace()
	hud.show_message("La barricade s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


func _boss_fight() -> void:
	await say("Au bout du chemin, quelqu'un tire encore sa barge.", 3.5)
	await reach(Vector3(0.0, 0.0, -32.0), 3.0)

	boss = spawn(&"haleur", BOSS_AT, false) as HaleurEnemy
	boss.health_changed.connect(hud.set_boss)
	boss.hauled.connect(_on_hauled)
	boss.enraged.connect(func() -> void:
		hud.show_message("Le Haleur enrage : il tire plus souvent,\net le fleuve rend ses Noyés.", 4.0))
	boss.fell.connect(func(_e: Enemy) -> void:
		hud.show_message("Le Haleur tombe.\nDonne-lui le Repos avant qu'il ne se relève.", 4.5))
	hud.show_boss("Le Haleur", boss.health, boss.max_health())
	hud.show_message("Le Haleur. Quand la bande rouge s'allume sous sa chaîne, sors-en :\nles corps qu'elle balaie se relèvent.", 6.0)
	await until_peace()
	hud.hide_boss()


## La chaîne a amené la barge : des morts en débarquent, sur le bord.
func _on_hauled(at: Vector3) -> void:
	if not is_instance_valid(boss) or not boss.is_standing() or enemies_left() - 1 >= 5:
		return
	var kind := &"depouille" if boss.phase == 1 else &"noye"
	for dz: float in [-1.6, 1.6]:
		var z := clampf(at.z + dz, -62.0, -30.0)
		spawn(kind, Vector3(water_x - 1.3, 0.0, z))


func _leave() -> void:
	await victory("Le Haleur repose. Sa barge dérive, enfin libre.")


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	var cells: Array[Vector2] = []
	for col in range(-2, 3):
		for row in range(-16, 3):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(DUNGEON + "floor_tile_large.glb", cells)

	# Le bord du chemin, côté fleuve ; des barges amarrées le long du chemin,
	# avant la grève (celle du Haleur le suit).
	Docks.quay_edge(self, HALF_WIDTH, 8.0, -64.0)
	Docks.piles(self, HALF_WIDTH + 1.4, 6.0, -64.0, 5.0)
	for z: float in [-4.0, -18.0]:
		Docks.barge(self, Vector3(HALF_WIDTH + 4.6, 0.0, z), 11.0, 0.0, int(z) % 4 == 0)

	# Le talus de la ville basse, de l'autre côté : un mur, des torches.
	var z := 6.0
	while z > -64.5:
		place("wall.glb", Vector3(-HALF_WIDTH, 0.0, z), 90.0)
		z -= 4.0
	solid(Vector3(-HALF_WIDTH, 0.0, -29.0), Vector3(1.0, 4.0, 74.0))
	for tz: float in [-6.0, -20.0, -34.0, -46.0, -58.0]:
		wall_torch(Vector3(-HALF_WIDTH + 0.5, 1.8, tz), 90.0, 2.4, 11.0)

	# Sur le chemin : des bittes de halage, des rouleaux de cordage, des caisses
	# contre le talus (pas de couloir étroit derrière).
	for bz: float in [-10.0, -38.0, -54.0]:
		var at := Vector3(-3.0 if bz < -30.0 else 2.0, 0.0, bz)
		Docks.bollard(self, at)
		solid(at, Vector3(0.7, 1.2, 0.7))
	var flush := -HALF_WIDTH + 0.5 + 1.2
	Docks.crates(self, Vector3(flush, 0.0, -14.0), 4.0, true)
	Docks.crates(self, Vector3(flush, 0.0, -42.0), -3.0)
	Docks.crates(self, Vector3(flush, 0.0, -58.0), 2.0, true)
	for lz: float in [-1.0, -36.0, -52.0]:
		grave_piece("post_lantern", Vector3(6.6, 0.0, lz))
		flame(Vector3(6.6, 2.6, lz + 0.4), 2.2, 10.0)

	# La barricade.
	for x: float in [-3.4, -5.7, -8.0, 3.4, 5.7, 8.0]:
		Docks.crates(self, Vector3(x, 0.0, GATE_Z), 0.0, absf(x) > 5.0)
	for x: float in [-2.1, 2.1]:
		grave_piece("fence_pillar", Vector3(x, 0.0, GATE_Z))
	for x: float in [-5.4, 5.4]:
		solid(Vector3(x, 0.0, GATE_Z), Vector3(6.6, 4.0, 0.8))
	add_gate(Vector3(0.0, 0.0, GATE_Z), 1)

	# Derrière le héros, un muret bas ; au fond, le mur haut.
	for x: float in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		place("wall.glb", Vector3(x, 0.0, 8.0), 0.0, 0.35)
	solid(Vector3(0.0, 0.0, 8.0), Vector3(2.0 * HALF_WIDTH + 1.0, 4.0, 1.0))
	for x: float in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		place("wall.glb", Vector3(x, 0.0, -64.5), 0.0, 1.0, true)
	solid(Vector3(0.0, 0.0, -64.5), Vector3(2.0 * HALF_WIDTH + 1.0, 4.0, 1.0))
