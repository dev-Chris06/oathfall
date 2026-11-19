class_name LesEtals
extends Level
## Niveau 7 — Les Étals.
##
## Chapitre II. La rue des bouchers : une longue ruelle bordée d'étals où
## pendent encore des carcasses. Le joueur y rencontre le Boucher, lent et
## lourd, et le Crieur, dont le cri presse tous les morts debout.
##
##   z =   3 : entrée, depuis la Porte des halles
##   z = -28 : première barrière
##   z = -56 : seconde barrière
##   z = -88 : sortie, vers la Balance

const HALF_WIDTH := 6.2
const GATE_Z: Array[float] = [-28.0, -56.0]
const STALL_Z: Array[float] = [-6.0, -18.0, -30.0, -42.0, -54.0, -66.0, -78.0]
const EXIT := Vector3(0.0, 0.0, -85.0)
const CLOTHS: Array[Color] = [Color(0.38, 0.07, 0.06), Color(0.3, 0.1, 0.08), Color(0.22, 0.08, 0.1)]


func _init() -> void:
	title = "Les Étals"
	chapter = 2
	play_area = Rect2(-6.6, -89.0, 13.2, 99.0)
	next_level = &"la_balance"


func _checkpoint_position(index: int) -> Vector3:
	match index:
		1:
			return Vector3(0.0, 0.0, -31.0)
		2:
			return Vector3(0.0, 0.0, -59.0)
	return Vector3(0.0, 0.0, 6.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _first_stretch()
	if checkpoint <= 1:
		await _crier_stretch()
	await _last_stretch()
	await _leave()


## Les premiers étals : un Boucher, seul d'abord.
func _first_stretch() -> void:
	await say("LES ÉTALS", 2.5)
	hud.show_message("La rue des bouchers.\nLes crochets sont encore chargés.", 4.0)
	await reach(Vector3(0.0, 0.0, -3.0), 3.0)
	spawn(&"boucher", Vector3(0.0, 0.0, -18.0))
	hud.show_message("Un Boucher. Son coup est lent et lourd :\nesquive quand il lève le hachoir.", 5.0)
	await wait_until(func() -> bool: return standing_count() == 0 or enemies_left() == 0)
	spawn_group(&"depouille", [Vector3(-3.0, 0.0, -21.0), Vector3(3.0, 0.0, -23.0)])
	await until_peace()
	hud.show_message("La barrière s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


## Le Crieur, et les morts qu'il presse.
func _crier_stretch() -> void:
	spawn(&"crieur", Vector3(0.0, 0.0, -50.0))
	spawn_group(&"depouille", [Vector3(-3.0, 0.0, -41.0), Vector3(3.0, 0.0, -43.0), Vector3(0.0, 0.0, -45.0)])
	hud.show_message("Un Crieur. Son cri presse les morts debout.\nFrappe-le quand il prend son souffle.", 5.5)
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"archer_creux", Vector3(-4.5, 0.0, -52.0))
	spawn(&"boucher", Vector3(2.0, 0.0, -48.0))
	await until_peace()
	hud.show_message("La dernière barrière s'ouvre.", 2.5)
	open_gate(1)
	await reach(_checkpoint_position(2), 3.0)
	mark_checkpoint(2)


## Toute la boucherie : deux Bouchers, un Crieur, des archers.
func _last_stretch() -> void:
	hud.show_message("Ils tiennent le fond de la rue.", 3.5)
	spawn(&"crieur", Vector3(0.0, 0.0, -82.0))
	spawn(&"boucher", Vector3(-3.0, 0.0, -70.0))
	spawn_group(&"depouille", [Vector3(3.0, 0.0, -68.0), Vector3(-2.0, 0.0, -73.0)], 15.0)
	await wait_until(func() -> bool: return standing_count() <= 2)
	spawn(&"archer_creux", Vector3(4.5, 0.0, -78.0))
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"boucher", Vector3(3.0, 0.0, -75.0))
	await until_peace()


func _leave() -> void:
	await say("La rue est vide.", 2.5)
	hud.show_message("Au bout, la salle de la balance.", 4.0)
	await reach(EXIT, 2.5)
	finish()


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	var cells: Array[Vector2] = []
	for col in range(-2, 3):
		for row in range(-23, 4):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(GRAVEYARD + "floor_dirt.gltf", cells)
	var stones: Array[Vector2] = []
	for row in range(-44, 4):
		for x: float in [-2.0, 0.0, 2.0]:
			stones.append(Vector2(x, row * 2.0))
	pave(GRAVEYARD + "path_A.gltf", stones)

	# Les étals de part et d'autre, face à la rue, et leurs carcasses.
	for i in STALL_Z.size():
		var z := STALL_Z[i]
		_butcher_stall(Vector3(-5.0, 0.0, z), 90.0, CLOTHS[i % CLOTHS.size()])
		_butcher_stall(Vector3(5.0, 0.0, z - 6.0), -90.0, CLOTHS[(i + 1) % CLOTHS.size()])
		if i % 2 == 0:
			var side := -1.0 if i % 4 == 0 else 1.0
			grave_piece("post_lantern", Vector3(side * 3.6, 0.0, z - 3.0))
			flame(Vector3(side * 3.6, 2.6, z - 2.6), 2.2, 10.0)

	# Les côtés de la rue : des clôtures d'un bout à l'autre.
	for side: float in [-1.0, 1.0]:
		var z := 8.0
		while z > -90.0:
			grave_piece("fence", Vector3(side * (HALF_WIDTH + 0.2), 0.0, z), 90.0)
			z -= 4.0

	# Les deux barrières, fermées sur toute la largeur de la rue.
	for gz in GATE_Z:
		for x: float in [-4.1, 4.1]:
			grave_piece("fence", Vector3(x, 0.0, gz))
		for x: float in [-2.1, 2.1]:
			grave_piece("fence_pillar", Vector3(x, 0.0, gz))
		for x: float in [-4.15, 4.15]:
			solid(Vector3(x, 0.0, gz), Vector3(4.1, 4.0, 0.6))
	add_gate(Vector3(0.0, 0.0, GATE_Z[0]), 1)
	add_gate(Vector3(0.0, 0.0, GATE_Z[1]), 2)

	# L'entrée, le fond et la sortie : arches et clôtures, fermés derrière.
	grave_piece("arch", Vector3(0.0, 0.0, 3.0))
	for x: float in [-4.1, 4.1]:
		grave_piece("fence", Vector3(x, 0.0, 3.0))
		solid(Vector3(x, 0.0, 3.0), Vector3(4.1, 4.0, 0.6))
	for side: float in [-1.0, 1.0]:
		grave_piece("fence_pillar", Vector3(side * HALF_WIDTH, 0.0, 9.5))
	for x: float in [-4.0, 0.0, 4.0]:
		grave_piece("fence", Vector3(x, 0.0, 9.5))
	grave_piece("arch", Vector3(0.0, 0.0, -88.0))
	for x: float in [-4.1, 4.1]:
		grave_piece("fence", Vector3(x, 0.0, -88.0))
	for x: float in [-4.0, 0.0, 4.0]:
		grave_piece("fence", Vector3(x, 0.0, -89.5))
	grave_piece("post_lantern", Vector3(-3.0, 0.0, -85.5))
	flame(Vector3(-3.0, 2.6, -85.1), 2.4, 10.0)

	# Les bords de la rue (les clôtures ci-dessus les rendent visibles).
	solid(Vector3(-HALF_WIDTH - 0.3, 0.0, -39.35), Vector3(0.6, 4.0, 98.7))
	solid(Vector3(HALF_WIDTH + 0.3, 0.0, -39.35), Vector3(0.6, 4.0, 98.7))
	solid(Vector3(0.0, 0.0, 9.5), Vector3(2.0 * HALF_WIDTH + 1.2, 4.0, 0.6))
	solid(Vector3(0.0, 0.0, -89.5), Vector3(2.0 * HALF_WIDTH + 1.2, 4.0, 0.6))


## Un étal de boucher : l'étal du marché, et des carcasses pendues à son auvent.
func _butcher_stall(pos: Vector3, yaw_deg: float, cloth: Color) -> void:
	stall(pos, yaw_deg, cloth)
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	add_child(root)
	var meat := Fx.flat(Color(0.5, 0.1, 0.09), 0.0, 0.6)
	for x: float in [-0.8, 0.0, 0.8]:
		var piece := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.15
		capsule.height = 0.75
		capsule.radial_segments = 8
		capsule.rings = 3
		piece.mesh = capsule
		piece.material_override = meat
		piece.position = Vector3(x, 1.65, 0.75)
		root.add_child(piece)
