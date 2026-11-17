class_name LaFosse
extends Level
## Niveau 5 — La Fosse : la Fossoyeuse.
##
## Un chemin étroit et clos mène à une grande fosse ronde, à ciel ouvert,
## parsemée de monticules de terre et de pierres tombales. La Fossoyeuse y
## attend, en trois phases (voir `FossoyeuseEnemy`) : la pelle, puis la terre,
## puis les pierres.
##
##   z =   6 … -12 : le chemin, puis une grille à z = -12
##   z = -12 … -19 : l'entrée de la fosse
##   fosse : centre (0, -34), rayon 15 ; la sortie, au nord, vers z = -50

const CENTER := Vector3(0.0, 0.0, -34.0)
const RADIUS := 15.0
const GATE_Z := -12.0
const EXIT := Vector3(0.0, 0.0, -47.5)

var boss: FossoyeuseEnemy

var _mounds: Array[Vector3] = []
var _stones: Array[Node3D] = []
var _tends_corpses := false


func _init() -> void:
	title = "La Fosse"
	# Les monticules d'où elle jaillit, en couronne autour du centre.
	for i in 6:
		var angle := deg_to_rad(30.0 + 60.0 * i)
		_mounds.append(CENTER + Vector3(sin(angle), 0.0, cos(angle)) * 9.5)


func _checkpoint_position(index: int) -> Vector3:
	if index == 1:
		return Vector3(0.0, 0.0, -22.0)
	return Vector3(0.0, 0.0, 4.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _approach()
	await _boss_fight()
	await _leave()


## Le chemin : les derniers morts avant la fosse.
func _approach() -> void:
	await say("LA FOSSE", 2.5)
	hud.show_message("Le chemin descend vers la fosse.", 3.0)
	await reach(Vector3(0.0, 0.0, -1.0), 3.0)
	spawn_group(&"depouille", [Vector3(-2.5, 0.0, -6.0), Vector3(2.5, 0.0, -8.0), Vector3(0.0, 0.0, -10.0)])
	await until_peace()
	hud.show_message("La grille s'ouvre.", 2.5)
	open_gate(0)
	await reach(Vector3(0.0, 0.0, -16.0), 3.0)
	spawn(&"fouisseur", Vector3(-3.0, 0.0, -20.0))
	spawn_group(&"depouille", [Vector3(3.0, 0.0, -19.0), Vector3(0.0, 0.0, -23.0)])
	await until_peace()
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


## La Fossoyeuse.
func _boss_fight() -> void:
	await say("Une grande fosse, des monticules de terre.\nLa terre y a été remuée.", 4.0)
	await reach(Vector3(0.0, 0.0, -25.0), 3.0)

	boss = spawn(&"fossoyeuse", CENTER, false) as FossoyeuseEnemy
	boss.mounds = _mounds
	boss.props = _stones.duplicate()
	boss.stage_changed.connect(_on_stage)
	boss.dug.connect(_on_dug)
	boss.raised.connect(_on_raised)
	boss.shook.connect(shake)
	boss.fell.connect(_on_boss_fell)
	boss.health_changed.connect(hud.set_boss)
	boss.intro()
	hud.show_boss("La Fossoyeuse", boss.health, int(EnemyTypes.get_type(&"fossoyeuse")["health"]))
	hud.show_message("La Fossoyeuse.\nSes coups de pelle sont lents et lourds : esquive.", 5.0)

	await until_peace()
	hud.hide_boss()
	await say("La Fossoyeuse repose.\nLe chapitre s'achève.", 3.5)


func _leave() -> void:
	hud.show_message("Au nord, la sortie de la fosse.", 3.5)
	await reach(EXIT, 2.5)
	finish()


# --- Les trois phases ---------------------------------------------------------

func _on_stage(stage: int) -> void:
	if stage == 2:
		hud.show_message("Elle s'enfonce dans la terre.\nMets au repos les morts qu'elle déterre.", 5.0)
	elif stage == 3:
		hud.show_message("Elle arrache les pierres tombales.\nLes corps sans repos se relèveront tous ensemble.", 5.5)
		if not _tends_corpses:
			_tends_corpses = true
			_keep_corpses()


## Phase 2 : elle déterre des Dépouilles, qui gisent d'abord.
func _on_dug(points: Array) -> void:
	for point: Vector3 in points:
		_lay_corpse(point)


func _on_raised(count: int) -> void:
	if count > 0:
		hud.show_message("Les corps se relèvent.", 2.0)


func _on_boss_fell(_enemy: Enemy) -> void:
	hud.show_message("La Fossoyeuse tombe.\nDonne-lui le Repos avant qu'elle ne se relève.", 4.5)


func _lay_corpse(at: Vector3) -> void:
	var corpse := spawn(&"depouille", at, false)
	corpse.rise_delay = 16.0
	corpse.take_hit(boss.global_position, 1000)


## Phase 3 : tant qu'elle tient, de nouveaux morts se couchent dans la fosse,
## sans quoi son cri n'aurait plus rien à relever.
func _keep_corpses() -> void:
	while is_instance_valid(boss) and not boss.is_down():
		await wait(6.0)
		if not is_instance_valid(boss) or not boss.is_standing() or enemies_left() - 1 >= 3:
			continue
		var spots := _mounds.duplicate()
		spots.shuffle()
		var laid := 0
		for at: Vector3 in spots:
			if laid >= 2:
				break
			if at.distance_to(hero.global_position) > 4.0:
				_lay_corpse(at)
				laid += 1


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	# Le sol : de la terre, sur la fosse et sur le chemin.
	var cells: Array[Vector2] = []
	for col in range(-6, 7):
		for row in range(-15, 3):
			var cell := Vector2(col * 4.0, row * 4.0)
			var in_pit := Vector2(cell.x - CENTER.x, cell.y - CENTER.z).length() < 19.0
			if in_pit or (absf(cell.x) <= 8.0 and cell.y > -22.0):
				cells.append(cell)
	pave(GRAVEYARD + "floor_dirt.gltf", cells)

	_build_path()
	_build_pit()

	# Les monticules : de la terre remuée, où elle peut s'enfoncer.
	for mound in _mounds:
		var dome := MeshInstance3D.new()
		var half := SphereMesh.new()
		half.radius = 1.6
		half.height = 1.2
		half.is_hemisphere = true
		dome.mesh = half
		dome.material_override = Fx.flat(Color(0.18, 0.13, 0.1))
		dome.position = mound
		dome.scale = Vector3(1.0, 0.55, 1.0)
		add_child(dome)

	# Des pierres tombales dans la fosse : celles qu'elle arrachera.
	for i in 6:
		var angle := deg_to_rad(60.0 * i)
		var at := CENTER + Vector3(sin(angle), 0.0, cos(angle)) * 6.0
		var stone := grave_piece("gravestone", at, rad_to_deg(angle) + 180.0)
		stone.scale = Vector3.ONE * 1.5
		_stones.append(stone)


## Le chemin du départ, clos de clôtures, jusqu'à l'entrée de la fosse.
func _build_path() -> void:
	for side: float in [-1.0, 1.0]:
		var z := 4.0
		var k := 0
		while z > -21.0:
			grave_piece("fence_broken" if k % 5 == 3 else "fence", Vector3(side * 4.4, 0.0, z), 90.0)
			z -= 4.0
			k += 1
		solid(Vector3(side * 4.8, 0.0, -7.5), Vector3(0.6, 4.0, 29.0))
	solid(Vector3(0.0, 0.0, 7.5), Vector3(10.0, 4.0, 1.0))
	# La grille tient entre deux piliers, et des panneaux de clôture la
	# prolongent jusqu'aux murs du chemin : plus de vide sur les côtés.
	for x: float in [-2.1, 2.1]:
		grave_piece("fence_pillar", Vector3(x, 0.0, GATE_Z))
	for x: float in [-4.1, 4.1]:
		grave_piece("fence", Vector3(x, 0.0, GATE_Z))
	for x: float in [-3.45, 3.45]:
		solid(Vector3(x, 0.0, GATE_Z), Vector3(2.7, 4.0, 0.6))
	add_gate(Vector3(0.0, 0.0, GATE_Z), 1)
	grave_piece("post_lantern", Vector3(-3.2, 0.0, 2.0))
	grave_piece("post_lantern", Vector3(3.2, 0.0, 2.0))
	flame(Vector3(-3.2, 2.6, 2.4), 2.2, 9.0)
	flame(Vector3(3.2, 2.6, 2.4), 2.2, 9.0)
	grave_piece("tree_dead_large", Vector3(-8.5, 0.0, 4.0), 25.0)
	grave_piece("tree_dead_medium", Vector3(8.5, 0.0, -3.0), -60.0)
	grave_piece("tree_dead_large", Vector3(9.0, 0.0, -16.0), 140.0)


## La fosse : une couronne de terre remuée, de pierres et de clôtures ; deux
## ouvertures, l'entrée au sud et la sortie au nord.
func _build_pit() -> void:
	for k in 36:
		var degrees := k * 10.0
		var near_south := k <= 2 or k >= 34
		var near_north := absi(k - 18) <= 2
		var angle := deg_to_rad(degrees)
		var at := CENTER + Vector3(sin(angle), 0.0, cos(angle)) * (RADIUS + 1.5)
		if not near_south and not near_north:
			solid(CENTER + Vector3(sin(angle), 0.0, cos(angle)) * (RADIUS + 0.6), Vector3(3.4, 4.0, 1.2), degrees)
			# Le bord : une levée de terre, des pierres, des clôtures.
			var rim := MeshInstance3D.new()
			var bank := SphereMesh.new()
			bank.radius = 2.0
			bank.height = 2.0
			bank.is_hemisphere = true
			rim.mesh = bank
			rim.material_override = Fx.flat(Color(0.15, 0.11, 0.08))
			rim.position = at
			rim.scale = Vector3(1.4, 0.7, 1.0)
			rim.rotation.y = angle
			add_child(rim)
			if k % 2 == 0:
				grave_piece("gravestone", at + Vector3(sin(angle), 0.0, cos(angle)) * 1.6, degrees + 180.0)
			elif k % 4 == 1:
				grave_piece("grave_A_destroyed", at + Vector3(sin(angle), 0.0, cos(angle)) * 2.0, degrees + 90.0)
		if k % 6 == 0 and not near_south and not near_north:
			grave_piece("tree_dead_large", CENTER + Vector3(sin(angle), 0.0, cos(angle)) * (RADIUS + 6.0), degrees)
	# Des lanternes sur le bord, de quoi y voir quelque chose.
	for degrees: float in [45.0, 135.0, 225.0, 315.0]:
		var angle := deg_to_rad(degrees)
		var at := CENTER + Vector3(sin(angle), 0.0, cos(angle)) * (RADIUS - 1.2)
		grave_piece("lantern_standing", at)
		flame(at + Vector3(0.0, 1.0, 0.0), 2.4, 12.0)
	# La sortie, au nord.
	grave_piece("arch", Vector3(0.0, 0.0, -50.5))
	# Les murs de la sortie rejoignent le cercle de monticules des deux côtés :
	# on ne peut plus contourner la fosse par le nord.
	for x: float in [-8.1, -4.1, 4.1, 8.1]:
		grave_piece("fence", Vector3(x, 0.0, -50.5))
	solid(Vector3(0.0, 0.0, -52.5), Vector3(14.0, 4.0, 1.0))
	for x: float in [-6.5, 6.5]:
		solid(Vector3(x, 0.0, -50.5), Vector3(6.0, 4.0, 0.6))
	for side: float in [-1.0, 1.0]:
		grave_piece("fence", Vector3(side * 9.9, 0.0, -49.6), 90.0)
		grave_piece("fence_pillar", Vector3(side * 9.9, 0.0, -47.6))
		solid(Vector3(side * 9.7, 0.0, -49.6), Vector3(0.8, 4.0, 2.6))
	for at: Vector3 in [Vector3(-3.0, 0.0, -8.0), Vector3(2.0, 0.0, -15.0), CENTER + Vector3(4.0, 0.0, 3.0)]:
		grave_piece("skull", at, at.z * 13.0).scale = Vector3.ONE * 0.45
		grave_piece("bone_A", at + Vector3(0.6, 0.05, 0.4), at.z * 31.0)
