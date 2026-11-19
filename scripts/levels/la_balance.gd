class_name LaBalance
extends Level
## Niveau 8 — La Balance : le Peseur.
##
## Chapitre II, boss intermédiaire. Une grande place close, où trône la balance
## publique : deux plateaux, un fléau. Une première partie de morts du marché,
## une barrière, puis le Peseur. Sa balance compare les morts debout et les
## corps au sol ; le joueur la règle en abattant les uns et en mettant les
## autres au repos (voir `PeseurEnemy`).
##
##   z =   3 : entrée, depuis les Étals
##   z = -12 : barrière de l'arène
##   z = -44 : le fond, la balance publique ; sortie au nord

const HALF := 14.0
const GATE_Z := -12.0
const CENTER := Vector3(0.0, 0.0, -29.0)
const EXIT := Vector3(0.0, 0.0, -41.0)
## La balance publique est basse et proche : la caméra regarde vers le bas et ne
## verrait rien de plus haut, au loin.
const BEAM_HEIGHT := 3.4
const ARM := 5.0
const HANG := 2.0
const MONUMENT_Z := -39.5

var boss: PeseurEnemy

var _beam: MeshInstance3D
var _pans: Array[MeshInstance3D] = []
var _chains: Array[MeshInstance3D] = []
var _tilt := 0.0
var _heights := [0.0, 0.0]
var _spawned_standing := false
var _first_balance := true


func _init() -> void:
	title = "La Balance"
	chapter = 2
	play_area = Rect2(-14.6, -46.5, 29.2, 56.5)
	next_level = &"les_caves"


func _checkpoint_position(index: int) -> Vector3:
	if index == 1:
		return Vector3(0.0, 0.0, -16.0)
	return Vector3(0.0, 0.0, 6.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _antechamber()
	await _boss_fight()
	await _leave()


## L'avant-place : les marchands venus faire peser leurs marchandises.
func _antechamber() -> void:
	await say("LA BALANCE", 2.5)
	hud.show_message("La place des poids et mesures.\nAu fond, la balance publique.", 4.0)
	await reach(Vector3(0.0, 0.0, -2.0), 3.0)
	spawn_group(&"depouille", [Vector3(-6.0, 0.0, -6.0), Vector3(6.0, 0.0, -7.0)])
	spawn(&"crieur", Vector3(0.0, 0.0, -9.0))
	await wait_until(func() -> bool: return standing_count() <= 1)
	spawn_group(&"depouille", [Vector3(-8.0, 0.0, -4.0), Vector3(8.0, 0.0, -5.0)])
	spawn(&"archer_creux", Vector3(0.0, 0.0, -10.0))
	await until_peace()
	hud.show_message("La barrière de la place s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


func _boss_fight() -> void:
	await say("Le Peseur tient la balance.\nIl juge tout, les corps comme les vivants.", 4.0)
	await reach(Vector3(0.0, 0.0, -20.0), 3.0)

	boss = spawn(&"peseur", CENTER, false) as PeseurEnemy
	boss.health_changed.connect(hud.set_boss)
	boss.balance_changed.connect(_on_balance)
	boss.stunned.connect(func() -> void: hud.show_message("L'équilibre assomme le Peseur.\nFrappe sans attendre !", 3.0))
	boss.weight_marked.connect(_on_weight_marked)
	boss.weight_fell.connect(func(_at: Vector3, _hit: bool) -> void: shake(0.9))
	boss.fell.connect(_on_boss_fell)
	hud.show_boss("Le Peseur", boss.health, int(EnemyTypes.get_type(&"peseur")["health"]))
	hud.show_message("Le Peseur. Sa balance compare les morts debout et les corps.\nÀ l'équilibre, il est assommé.", 6.0)
	for at: Vector3 in [Vector3(-7.0, 0.0, -24.0), Vector3(7.0, 0.0, -25.0)]:
		_lay_corpse(at)
	_feed_balance()

	await until_peace()
	hud.hide_boss()
	hud.hide_balance()
	await say("Le Peseur repose. La balance s'immobilise.", 3.5)


func _leave() -> void:
	hud.show_message("Au nord, la sortie de la place.", 3.5)
	await reach(EXIT, 2.5)
	finish()


func _on_balance(state: int) -> void:
	match state:
		PeseurEnemy.Balance.STANDING:
			hud.show_message("Trop de morts debout : la fonte le protège.\nAbats-les.", 3.5)
		PeseurEnemy.Balance.LYING:
			hud.show_message("Trop de corps : le Peseur s'emballe,\nses poids tombent par trois. Donne le Repos.", 3.5)
		_:
			pass


func _on_weight_marked(_at: Vector3) -> void:
	if _first_weight:
		_first_weight = false
		hud.show_message("Un poids va tomber : sors de la zone rouge.", 3.5)


var _first_weight := true


func _on_boss_fell(_enemy: Enemy) -> void:
	hud.show_message("Le Peseur tombe.\nDonne-lui le Repos avant qu'il ne se relève.", 4.5)


## Un mort tombé qui attend le Repos.
func _lay_corpse(at: Vector3) -> void:
	var corpse := spawn(&"depouille", at, false)
	corpse.rise_delay = 35.0
	corpse.take_hit(boss.global_position, 1000)


## Tant que le Peseur tient, de nouveaux morts arrivent, tantôt debout tantôt
## couchés : la balance ne reste jamais d'elle-même à l'équilibre.
func _feed_balance() -> void:
	while is_instance_valid(boss) and not boss.is_down():
		await wait(8.0)
		if not is_instance_valid(boss) or not boss.is_standing() or enemies_left() - 1 >= 5:
			continue
		for attempt in 12:
			var at := Vector3(randf_range(-10.0, 10.0), 0.0, randf_range(-36.0, -20.0))
			if at.distance_to(hero.global_position) < 5.0 or absf(at.x) < 3.0 and at.z < -33.0:
				continue
			if _spawned_standing:
				_lay_corpse(at)
			else:
				spawn(&"depouille", at)
			_spawned_standing = not _spawned_standing
			break


# --- La balance publique, animée -----------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if _beam == null:
		return
	var counts := Vector2i.ZERO
	if is_instance_valid(boss) and boss.is_standing():
		counts = boss.balance_counts()
		hud.set_balance(counts.x, counts.y)
	# Le côté le plus lourd descend : les morts debout à gauche, les corps à droite.
	var target := deg_to_rad(clampf(float(counts.x - counts.y) * 4.0, -18.0, 18.0))
	_tilt = lerpf(_tilt, target, minf(1.0, delta * 2.5))
	_beam.rotation.z = _tilt
	for side in 2:
		var sign_value := -1.0 if side == 0 else 1.0
		var end := Vector3(sign_value * ARM * cos(_tilt), BEAM_HEIGHT + sign_value * ARM * sin(_tilt), MONUMENT_Z)
		var pan_at := end + Vector3(0.0, -HANG, 0.0)
		_pans[side].position = pan_at
		_chains[side].position = (end + pan_at) / 2.0


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	var cells: Array[Vector2] = []
	for col in range(-4, 5):
		for row in range(-12, 4):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(GRAVEYARD + "floor_dirt.gltf", cells)
	var ring: Array[Vector2] = []
	for row in range(-22, 4):
		ring.append(Vector2(0.0, row * 2.0))
	pave(GRAVEYARD + "path_A.gltf", ring)

	# Les côtés de la place, d'un bout à l'autre.
	for side: float in [-1.0, 1.0]:
		var z := 8.0
		while z > -46.0:
			grave_piece("fence", Vector3(side * (HALF + 0.2), 0.0, z), 90.0)
			z -= 4.0
	# Le fond de départ, derrière la caméra, et le mur nord.
	for side: float in [-1.0, 1.0]:
		grave_piece("fence_pillar", Vector3(side * HALF, 0.0, 9.5))
		grave_piece("fence_pillar", Vector3(side * HALF, 0.0, -44.5))
	for x: float in [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0]:
		grave_piece("fence", Vector3(x, 0.0, 9.5))
		grave_piece("fence", Vector3(x, 0.0, -44.5))
	# La barrière de l'arène.
	for x: float in [-12.1, -8.1, -4.1, 4.1, 8.1, 12.1]:
		grave_piece("fence", Vector3(x, 0.0, GATE_Z))
	for x: float in [-2.1, 2.1]:
		grave_piece("fence_pillar", Vector3(x, 0.0, GATE_Z))
	for side: float in [-1.0, 1.0]:
		solid(Vector3(side * 8.15, 0.0, GATE_Z), Vector3(12.1, 4.0, 0.6))
	add_gate(Vector3(0.0, 0.0, GATE_Z), 1)
	solid(Vector3(-HALF - 0.3, 0.0, -17.35), Vector3(0.6, 4.0, 56.7))
	solid(Vector3(HALF + 0.3, 0.0, -17.35), Vector3(0.6, 4.0, 56.7))
	solid(Vector3(0.0, 0.0, 9.5), Vector3(2.0 * HALF + 1.2, 4.0, 0.6))
	solid(Vector3(0.0, 0.0, -44.5), Vector3(2.0 * HALF + 1.2, 4.0, 0.6))

	# Des lanternes, de quoi voir la place.
	for at: Vector3 in [Vector3(-10.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0), Vector3(-10.0, 0.0, -22.0),
			Vector3(10.0, 0.0, -22.0), Vector3(-10.0, 0.0, -38.0), Vector3(10.0, 0.0, -38.0)]:
		grave_piece("post_lantern", at)
		flame(at + Vector3(0.0, 2.6, 0.4), 2.2, 11.0)
	for at: Vector3 in [Vector3(-12.0, 0.0, -6.0), Vector3(12.0, 0.0, -8.0), Vector3(-12.0, 0.0, -30.0), Vector3(12.0, 0.0, -34.0)]:
		place("barrel_large.glb", at, at.z * 11.0)
		solid(at, Vector3(1.8, 2.0, 1.8))
	_build_balance()


## La balance publique, au fond : un fût, un fléau, deux plateaux pendus.
func _build_balance() -> void:
	var iron := Fx.flat(Color(0.2, 0.16, 0.12), 0.6, 0.5)
	var bronze := Fx.flat(Color(0.5, 0.35, 0.15), 0.7, 0.45)
	var post := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.radial_segments = 10
	shaft.top_radius = 0.3
	shaft.bottom_radius = 0.5
	shaft.height = BEAM_HEIGHT
	post.mesh = shaft
	post.material_override = iron
	post.position = Vector3(0.0, BEAM_HEIGHT / 2.0, MONUMENT_Z)
	add_child(post)
	solid(Vector3(0.0, 0.0, MONUMENT_Z), Vector3(1.4, 4.0, 1.4))
	_beam = MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(2.0 * ARM, 0.4, 0.4)
	_beam.mesh = bar
	_beam.material_override = iron
	_beam.position = Vector3(0.0, BEAM_HEIGHT, MONUMENT_Z)
	add_child(_beam)
	for side in 2:
		var pan := MeshInstance3D.new()
		var dish := CylinderMesh.new()
		dish.radial_segments = 16
		dish.top_radius = 1.8
		dish.bottom_radius = 1.4
		dish.height = 0.3
		pan.mesh = dish
		pan.material_override = bronze
		add_child(pan)
		_pans.append(pan)
		var chain := MeshInstance3D.new()
		var cord := CylinderMesh.new()
		cord.radial_segments = 4
		cord.top_radius = 0.05
		cord.bottom_radius = 0.05
		cord.height = HANG
		chain.mesh = cord
		chain.material_override = iron
		add_child(chain)
		_chains.append(chain)
