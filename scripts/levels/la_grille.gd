class_name LaGrille
extends Level
## Niveau 1 — La Grille.
##
## Le héros pousse la grille du cimetière et traverse trois cours séparées
## par des grilles. Chaque cour ne s'ouvre que lorsque ses morts reposent.
## Le joueur y apprend à frapper, à esquiver, puis voit son premier mort se
## relever, et apprend le Repos.
##
## Le niveau avance vers -Z, dos à la caméra.
##   z =   0 : la grille du cimetière
##   z = -20 : la grille de la cour intérieure
##   z = -40 : la grille du caveau
##   z = -64 : le caveau, sortie vers les Allées

const HALF_WIDTH := 10.0
const GATE_Z: Array[float] = [0.0, -20.0, -40.0]
const EXIT := Vector3(0.0, 0.0, -57.0)

## Les vantaux de chaque grille, et l'obstacle qui la ferme.
var _gates: Array[Dictionary] = []
var _first_rose := false


func _init() -> void:
	title = "La Grille"


func _checkpoint_position(index: int) -> Vector3:
	match index:
		1:
			return Vector3(0.0, 0.0, -23.0)
		2:
			return Vector3(0.0, 0.0, -43.0)
	return Vector3(0.0, 0.0, 8.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	for i in GATE_Z.size():
		if checkpoint > 0 and i <= checkpoint:
			open_gate(i, true)

	if checkpoint <= 0:
		await _outer_yard()
	if checkpoint <= 1:
		await _inner_yard()
	await _vault_yard()
	await _leave()


## La grille, puis la première cour : frapper, voir un mort se relever,
## apprendre le Repos, puis esquiver.
func _outer_yard() -> void:
	await say("LA GRILLE\nLes Faubourgs muets", 3.5)
	hud.show_message("La grille du cimetière. Pousse-la.", 4.0)
	await reach(Vector3(0.0, 0.0, 1.8), 2.2)
	open_gate(0)
	await reach(Vector3(0.0, 0.0, -6.0), 3.0)

	var first := spawn(&"depouille", Vector3(-2.0, 0.0, -12.0))
	first.rise_delay = 4.0
	first.rose.connect(func(_e: Enemy) -> void: _first_rose = true, CONNECT_ONE_SHOT)
	hud.show_message("Un mort sort de terre.\nFrappe-le : bouton FRAPPER.", 4.0)
	await wait_until(func() -> bool: return _first_rose or enemies_left() == 0)
	if _first_rose:
		# Il laisse cette fois le temps d'apprendre le rite.
		first.rise_delay = 40.0
		await wait(1.6)
		hud.show_message("FRÈRE ANSELME, derrière le mur :\n« Soldat ! Ici, les morts se relèvent.\n"
			+ "Abats-le, tiens-toi près du corps\net maintiens REPOS ! »", 7.0)
	await until_peace()
	await say("Il repose. Ce qu'il portait te revient :\nun souvenir.", 3.0)

	spawn(&"depouille", Vector3(-6.0, 0.0, -14.0))
	spawn(&"depouille", Vector3(6.0, 0.0, -15.0))
	hud.show_message("Quand un mort arme son coup, ESQUIVE.", 4.0)
	await until_peace()
	hud.show_message("La grille de la cour intérieure s'ouvre.", 3.0)
	open_gate(1)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


## La cour intérieure : les tombes s'ouvrent autour du héros.
func _inner_yard() -> void:
	hud.show_message("Les tombes s'ouvrent.", 3.0)
	spawn(&"depouille", Vector3(-8.0, 0.0, -28.0))
	spawn(&"depouille", Vector3(8.0, 0.0, -32.0))
	spawn(&"depouille", Vector3(0.0, 0.0, -33.0))
	await wait_until(func() -> bool: return _standing() <= 1)
	spawn(&"depouille", Vector3(-8.0, 0.0, -36.0))
	spawn(&"depouille", Vector3(7.5, 0.0, -26.5))
	await until_peace()
	hud.show_message("La grille du caveau s'ouvre.", 3.0)
	open_gate(2)
	await reach(_checkpoint_position(2), 3.0)
	mark_checkpoint(2)


## Devant le caveau : deux vagues, des corps qui se relèvent plus vite.
func _vault_yard() -> void:
	hud.show_message("Ils sont nombreux.\nNe laisse aucun corps sans repos.", 4.0)
	for pos: Vector3 in [Vector3(-5.0, 0.0, -49.0), Vector3(5.0, 0.0, -49.0),
			Vector3(-2.0, 0.0, -53.0), Vector3(2.0, 0.0, -53.0)]:
		spawn(&"depouille", pos).rise_delay = 14.0
	await wait_until(func() -> bool: return _standing() <= 1)
	for pos: Vector3 in [Vector3(-8.0, 0.0, -44.0), Vector3(8.0, 0.0, -44.0),
			Vector3(0.0, 0.0, -55.0)]:
		spawn(&"depouille", pos).rise_delay = 14.0
	await until_peace()


func _leave() -> void:
	await say("La cour est en paix.", 2.5)
	hud.show_message("Le passage derrière le caveau\nmène aux Allées.", 4.0)
	await reach(EXIT, 2.5)
	finish()


## Morts encore debout ou en train de sortir de terre.
func _standing() -> int:
	var count := 0
	for enemy in enemies():
		if not enemy.is_down():
			count += 1
	return count


# --- Grilles ------------------------------------------------------------------

func open_gate(index: int, instant := false) -> void:
	var gate := _gates[index]
	if gate["open"]:
		return
	gate["open"] = true
	(gate["blocker"] as CollisionShape3D).set_deferred("disabled", true)
	for side: int in [0, 1]:
		var leaf := gate["leaves"][side] as Node3D
		if leaf == null:
			continue
		var angle := deg_to_rad(105.0) * (1.0 if side == 0 else -1.0)
		if instant:
			leaf.rotation.y = angle
		else:
			var tween := create_tween()
			tween.tween_property(leaf, "rotation:y", angle, 1.6) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_gate(z: float, model: String) -> void:
	var node := grave_piece(model, Vector3(0.0, 0.0, z))
	_gates.append({
		"open": false,
		"leaves": [node.find_child("*_left", true, false), node.find_child("*_right", true, false)],
		"blocker": solid(Vector3(0.0, 0.0, z), Vector3(4.2, 4.0, 0.8)),
	})


# --- Décor --------------------------------------------------------------------

## Fosses ouvertes : c'est d'elles que sortent les morts.
const PITS: Array[Vector2] = [
	Vector2(-8.0, -12.0), Vector2(8.0, -16.0), Vector2(-8.0, -28.0), Vector2(8.0, -32.0),
	Vector2(-8.0, -48.0), Vector2(8.0, -48.0),
]


func _build() -> void:
	# Le sol : de la terre, avec quelques fosses ouvertes.
	var cells: Array[Vector2] = []
	for col in range(-3, 4):
		for row in range(-17, 4):
			var cell := Vector2(col * 4.0, row * 4.0)
			if not PITS.has(cell):
				cells.append(cell)
	pave(GRAVEYARD + "floor_dirt.gltf", cells)
	for pit in PITS:
		grave_piece("floor_dirt_grave", Vector3(pit.x, 0.0, pit.y), 90.0)

	# Les clôtures de chaque côté, et les trois grilles.
	for z_index in range(0, 17):
		var z := -2.0 - z_index * 4.0
		for side: float in [-1.0, 1.0]:
			var broken := (z_index * 7 + int(side + 1.0)) % 5 == 0
			grave_piece("fence_broken" if broken else "fence", Vector3(side * HALF_WIDTH, 0.0, z), 90.0)
	for gz in GATE_Z:
		for x: float in [-8.0, -4.0, 4.0, 8.0]:
			grave_piece("fence", Vector3(x, 0.0, gz))
		if gz != GATE_Z[0]:
			for x: float in [-2.1, 2.1]:
				grave_piece("fence_pillar", Vector3(x, 0.0, gz))
	_add_gate(GATE_Z[0], "arch_gate")
	_add_gate(GATE_Z[1], "fence_gate")
	_add_gate(GATE_Z[2], "fence_gate")

	# Le chemin qui mène à la grille, hors des murs.
	for z: float in [10.0, 6.0, 2.0]:
		grave_piece("path_A" if int(z) % 4 == 2 else "path_B", Vector3(0.0, 0.0, z))
	for pos: Vector3 in [Vector3(-6.5, 0.0, 9.0), Vector3(7.0, 0.0, 5.0), Vector3(-7.5, 0.0, 3.0)]:
		grave_piece("tree_dead_large", pos, pos.x * 20.0)
	grave_piece("tree_dead_small", Vector3(5.0, 0.0, 10.5), 40.0)
	grave_piece("post_lantern", Vector3(-3.2, 0.0, 1.2))
	grave_piece("post_lantern", Vector3(3.2, 0.0, 1.2))
	flame(Vector3(-3.2, 2.6, 1.6), 2.2, 9.0)
	flame(Vector3(3.2, 2.6, 1.6), 2.2, 9.0)

	# Première cour : tombes basses et stèles.
	_grave_row(-6.0, -6.5)
	_grave_row(6.0, -7.0)
	_grave_row(-6.0, -17.0)
	_grave_row(6.0, -11.0)
	grave_piece("gravestone", Vector3(-3.5, 0.0, -9.0), 10.0)
	grave_piece("gravemarker_A", Vector3(3.0, 0.0, -14.5), -15.0)
	grave_piece("bone_A", Vector3(1.0, 0.05, -8.0), 40.0)
	grave_piece("bone_B", Vector3(-1.5, 0.05, -16.0), 160.0)
	grave_piece("lantern_standing", Vector3(-8.5, 0.0, -18.5))
	flame(Vector3(-8.5, 1.0, -18.0), 1.8, 8.0)

	# Cour intérieure : des tombes partout, un banc de pierre renversé.
	_grave_row(-4.0, -25.0)
	_grave_row(4.0, -26.5)
	_grave_row(-5.0, -36.0)
	_grave_row(5.0, -37.5)
	grave_piece("grave_A_destroyed", Vector3(-1.5, 0.0, -30.0), 15.0)
	grave_piece("coffin", Vector3(7.2, 0.0, -22.6), 80.0)
	solid(Vector3(7.2, 0.0, -22.6), Vector3(3.0, 1.4, 2.0))
	grave_piece("gravemarker_B", Vector3(2.5, 0.0, -34.0), 20.0)
	grave_piece("ribcage", Vector3(-6.0, 0.3, -32.0), 70.0)
	grave_piece("tree_dead_medium", Vector3(-8.2, 0.0, -22.5), 120.0)
	grave_piece("shrine_candles", Vector3(8.3, 0.0, -38.5), -30.0)
	flame(Vector3(8.0, 1.6, -38.0), 2.0, 9.0)

	# Devant le caveau.
	grave_piece("crypt", Vector3(0.0, 0.0, -64.0))
	solid(Vector3(0.0, 0.0, -64.0), Vector3(6.0, 6.0, 8.0))
	grave_piece("pillar", Vector3(-4.5, 0.0, -59.5))
	grave_piece("pillar", Vector3(4.5, 0.0, -59.5))
	solid(Vector3(-4.5, 0.0, -59.5), Vector3(1.0, 4.0, 1.0))
	solid(Vector3(4.5, 0.0, -59.5), Vector3(1.0, 4.0, 1.0))
	grave_piece("gravestone", Vector3(-6.5, 0.0, -54.0), -10.0)
	grave_piece("gravestone", Vector3(6.5, 0.0, -55.0), 12.0)
	grave_piece("post_skull", Vector3(-8.6, 0.0, -51.5), 90.0)
	grave_piece("tree_dead_large", Vector3(8.0, 0.0, -57.5), -60.0)
	grave_piece("tree_dead_medium", Vector3(-8.0, 0.0, -58.0), 30.0)
	grave_piece("lantern_standing", Vector3(-2.2, 0.0, -59.0))
	grave_piece("lantern_standing", Vector3(2.2, 0.0, -59.0))
	flame(Vector3(0.0, 1.4, -58.0), 2.6, 11.0)

	# Les bords : le héros ne quitte pas le cimetière.
	solid(Vector3(-HALF_WIDTH - 0.3, 0.0, -30.0), Vector3(0.6, 4.0, 80.0))
	solid(Vector3(HALF_WIDTH + 0.3, 0.0, -30.0), Vector3(0.6, 4.0, 80.0))
	solid(Vector3(0.0, 0.0, 13.0), Vector3(2.0 * HALF_WIDTH, 4.0, 0.6))
	for gz in GATE_Z:
		for x: float in [-6.1, 6.1]:
			solid(Vector3(x, 0.0, gz), Vector3(8.0, 4.0, 0.6))


## Deux tombes côte à côte, avec leur obstacle.
func _grave_row(x: float, z: float) -> void:
	grave_piece("grave_A", Vector3(x - 1.2, 0.0, z), 90.0)
	grave_piece("grave_B", Vector3(x + 1.2, 0.0, z), 90.0)
	solid(Vector3(x, 0.0, z), Vector3(3.4, 1.5, 2.0))
