class_name LaHalleDuPrevot
extends Level
## Niveau 10 — La Halle du Prévôt.
##
## Chapitre II, boss. Une grande halle voûtée, des piliers, une table de
## comptes au fond. Un antichambre de morts du marché, une barrière, puis le
## Prévôt, qui continue de lever l'impôt (voir `PrevotEnemy`) : un cercle d'or
## est annoncé, la levée frappe toute la salle sauf ce cercle.
##
##   z =   4 : entrée, depuis les Caves
##   z = -16 : barrière de la halle
##   z = -57 : le fond, la table des comptes ; sortie au nord

const ANTE := 5.0
const HALL := 10.0
const GATE_Z := -16.0
const CENTER := Vector3(0.0, 0.0, -40.0)
const EXIT := Vector3(0.0, 0.0, -53.0)
## Où se tiennent les percepteurs convoqués.
const COLLECTORS: Array[Vector3] = [
	Vector3(-8.0, 0.0, -30.0), Vector3(8.0, 0.0, -31.0), Vector3(-8.0, 0.0, -48.0), Vector3(8.0, 0.0, -49.0),
]

var boss: PrevotEnemy

var _first_levy := true
var _first_stage := true


func _init() -> void:
	title = "La Halle du Prévôt"
	chapter = 2
	play_area = Rect2(-10.6, -60.0, 21.2, 66.0)
	underground = true


func _checkpoint_position(index: int) -> Vector3:
	if index == 1:
		return Vector3(0.0, 0.0, -20.0)
	return Vector3(0.0, 0.0, 2.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _antechamber()
	await _boss_fight()
	await _leave()


## L'antichambre : les percepteurs du marché.
func _antechamber() -> void:
	await say("LA HALLE DU PRÉVÔT", 2.8)
	hud.show_message("Une grande halle voûtée.\nAu fond, la table des comptes.", 4.0)
	await reach(Vector3(0.0, 0.0, -2.0), 3.0)
	spawn_group(&"depouille", [Vector3(-3.0, 0.0, -8.0), Vector3(3.0, 0.0, -9.0)])
	spawn(&"crieur", Vector3(0.0, 0.0, -13.0))
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn(&"boucher", Vector3(0.0, 0.0, -11.0))
	spawn(&"archer_creux", Vector3(-3.5, 0.0, -13.0))
	await until_peace()
	hud.show_message("La barrière de la halle s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


func _boss_fight() -> void:
	await say("Le Prévôt siège au fond de la halle.\nIl lève encore l'impôt.", 4.0)
	await reach(Vector3(0.0, 0.0, -28.0), 3.0)

	boss = spawn(&"prevot", CENTER, false) as PrevotEnemy
	boss.arena_radius = 12.0
	boss.health_changed.connect(hud.set_boss)
	boss.levy_called.connect(_on_levy_called)
	boss.levied.connect(_on_levied)
	boss.stage_changed.connect(_on_stage)
	boss.fell.connect(_on_boss_fell)
	hud.show_boss("Le Prévôt", boss.health, int(EnemyTypes.get_type(&"prevot")["health"]))
	hud.show_message("Le Prévôt. Il frappe lentement, de sa masse.\nSurveille le sol : la levée est annoncée.", 5.5)

	await until_peace()
	hud.hide_boss()


func _leave() -> void:
	await victory("Le Prévôt repose. La halle se tait.\nLe chapitre s'achève.")


func _on_levy_called(_center: Vector3) -> void:
	if _first_levy:
		_first_levy = false
		hud.show_message("Un cercle d'or paraît au sol, et il dérive.\nTiens-toi dedans avant que la levée ne tombe : elle reprend aussi les corps.", 6.0)


func _on_levied(_hit: bool, raised: int) -> void:
	shake(1.1)
	if raised > 0:
		hud.show_message("La levée reprend les corps : %d se relèvent." % raised, 2.5)


func _on_stage(stage: int) -> void:
	hud.show_message("Le Prévôt décrète : ses percepteurs arrivent.", 3.5)
	if stage == 2:
		spawn(&"boucher", COLLECTORS[0])
		spawn(&"depouille", Vector3(0.0, 0.0, -32.0))
		spawn(&"depouille", Vector3(4.0, 0.0, -34.0))
	else:
		spawn(&"boucher", COLLECTORS[1])
		for at: Vector3 in [Vector3(-3.0, 0.0, -34.0), Vector3(3.0, 0.0, -35.0)]:
			spawn(&"depouille", at)


func _on_boss_fell(_enemy: Enemy) -> void:
	hud.show_message("Le Prévôt tombe.\nDonne-lui le Repos avant qu'il ne se relève.", 4.5)


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	var cells: Array[Vector2] = []
	for col in range(-3, 4):
		for row in range(-15, 2):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(DUNGEON + "floor_tile_large.glb", cells)

	_side_walls(ANTE, 6.0, GATE_Z)
	_side_walls(HALL, GATE_Z, -58.0)
	_cross_wall(GATE_Z, 2.1, HALL)
	for x: float in [-2.1, 2.1]:
		grave_piece("fence_pillar", Vector3(x, 0.0, GATE_Z))
	add_gate(Vector3(0.0, 0.0, GATE_Z), 1)

	# Le fond : un muret derrière le héros au départ, la sortie au nord.
	solid(Vector3(0.0, 0.0, 5.5), Vector3(2.0 * ANTE, 4.0, 1.0))
	for x: float in [-4.0, 0.0, 4.0]:
		place("wall.glb", Vector3(x, 0.0, 5.5), 0.0, 0.35)
	place("wall_doorway.glb", Vector3(0.0, 0.0, -58.5), 0.0, 1.0, true)
	for x: float in [-4.0, 4.0, -8.0, 8.0]:
		place("wall.glb", Vector3(x, 0.0, -58.5), 0.0, 1.0, true)
	solid(Vector3(0.0, 0.0, -58.5), Vector3(2.0 * HALL + 2.0, 4.0, 1.0))
	place("wall.glb", Vector3(0.0, 0.0, -60.0), 0.0, 1.0, true)
	flame(Vector3(0.0, 2.6, -56.5), 2.6, 9.0)

	# Les piliers de la halle, le long des murs ; la table des comptes au fond.
	for z: float in [-24.0, -32.0, -40.0, -48.0]:
		for side: float in [-1.0, 1.0]:
			place("pillar.glb", Vector3(side * 7.0, 0.0, z))
			solid(Vector3(side * 7.0, 0.0, z), Vector3(1.5, 4.0, 1.5))
	for x: float in [-3.0, 3.0]:
		var table := grave_piece("bench", Vector3(x, 0.0, -53.5))
		table.scale = Vector3.ONE * 1.6
		solid(Vector3(x, 0.0, -53.5), Vector3(3.4, 0.8, 1.2))
		grave_piece("candle_triple", Vector3(x, 0.9, -53.5))
	for at: Vector3 in [Vector3(-9.0, 0.0, -20.0), Vector3(9.0, 0.0, -20.0), Vector3(-9.0, 0.0, -54.0), Vector3(9.0, 0.0, -54.0)]:
		place("barrel_large.glb", at, at.x * 13.0)
		solid(at, Vector3(1.8, 2.0, 1.8))
	# Des lanternes près des murs, de quoi voir le centre de la halle.
	for at: Vector3 in [Vector3(-8.6, 0.0, -36.0), Vector3(8.6, 0.0, -44.0), Vector3(-8.6, 0.0, -52.0), Vector3(8.6, 0.0, -28.0)]:
		grave_piece("lantern_standing", at)
		flame(at + Vector3(0.0, 1.0, 0.0), 2.8, 13.0)
	_torch(Vector3(-ANTE, 2.3, -8.0), 90.0)
	_torch(Vector3(ANTE, 2.3, -10.0), -90.0)
	_torch(Vector3(-HALL, 2.3, -28.0), 90.0)
	_torch(Vector3(HALL, 2.3, -36.0), -90.0)
	_torch(Vector3(-HALL, 2.3, -48.0), 90.0)
	_torch(Vector3(HALL, 2.3, -26.0), -90.0)


func _torch(pos: Vector3, yaw_deg: float) -> void:
	place("torch_mounted.glb", pos, yaw_deg)
	var forward := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	flame(pos + forward * 0.7 + Vector3(0.0, 0.6, 0.0), 2.8, 12.0)


## Des murs de chaque côté, d'un bout à l'autre d'une partie.
func _side_walls(half: float, south: float, north: float) -> void:
	var z := south - 2.0
	while z > north + 1.0:
		for side: float in [-1.0, 1.0]:
			place("wall.glb", Vector3(side * (half + 0.5), 0.0, z), -90.0 * side)
		z -= 4.0
	var length := south - north
	for side: float in [-1.0, 1.0]:
		solid(Vector3(side * (half + 0.5), 0.0, (south + north) / 2.0), Vector3(1.0, 4.0, length))


## Un mur en travers, percé d'un passage de `gap_half` de demi-largeur.
func _cross_wall(z: float, gap_half: float, out_half: float) -> void:
	var x := gap_half + 2.0
	while x - 2.0 < out_half:
		for side: float in [-1.0, 1.0]:
			place("wall.glb", Vector3(side * x, 0.0, z))
		x += 4.0
	for side: float in [-1.0, 1.0]:
		solid(Vector3(side * (gap_half + out_half) / 2.0, 0.0, z), Vector3(out_half - gap_half, 4.0, 1.0))
