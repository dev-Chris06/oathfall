class_name LaChapelle
extends Level
## Niveau 3 — La Chapelle des cendres : le Sonneur.
##
## Un porche étroit, puis la nef et ses bancs, puis le chœur où pend la grosse
## cloche. Le Sonneur ne se bat presque pas : il sonne, et chaque coup relève
## d'un coup tous les corps sans repos. On lui répond en donnant le Repos aux
## corps entre deux coups, ou en coupant les trois cordes qui
## retiennent la cloche (bouton COUPER près d'une corde, sans défense).
## Tant que la cloche sonne, de nouveaux morts se couchent dans le chœur.
##
##   z =   5 … -14 : le porche               grille z = -14
##   z = -14 … -46 : la nef, ses bancs       grille z = -46
##   z = -46 … -80 : le chœur, la cloche en z = -66, l'autel au fond

const NARTHEX := 5.0
const NAVE := 8.0
const CHOIR := 10.0
const GATES_Z: Array[float] = [-14.0, -46.0]
const BELL_AT := Vector3(0.0, 0.0, -66.0)
const EXIT := Vector3(0.0, 0.0, -75.0)
## Où les morts se couchent dans le chœur.
const CORPSE_SPOTS: Array[Vector3] = [
	Vector3(-6.0, 0.0, -58.0), Vector3(6.0, 0.0, -58.0), Vector3(-4.5, 0.0, -71.0),
	Vector3(4.5, 0.0, -71.0), Vector3(-8.0, 0.0, -64.0), Vector3(8.0, 0.0, -64.0),
]

var boss: SonneurEnemy

var _bell: GreatBell
var _tolls := 0
var _enraged_said := false
var _first_warning := true
var _first_quake := true


func _init() -> void:
	title = "La Chapelle des cendres"
	play_area = Rect2(-10.0, -82.0, 20.0, 88.0)
	underground = true
	next_level = &"l_ossuaire"


func _checkpoint_position(index: int) -> Vector3:
	match index:
		1:
			return Vector3(0.0, 0.0, -18.0)
		2:
			return Vector3(0.0, 0.0, -50.0)
	return Vector3(0.0, 0.0, 2.0)


# --- Scénario -----------------------------------------------------------------

func _run(checkpoint: int) -> void:
	open_gates_before(checkpoint)
	if checkpoint <= 0:
		await _porch()
	if checkpoint <= 1:
		await _nave()
	await _boss_fight()
	await _leave()


## Le porche : de quoi se mettre en jambes.
func _porch() -> void:
	await say("LA CHAPELLE DES CENDRES", 2.8)
	hud.show_message("Des cendres jusque sur les dalles.", 3.5)
	await reach(Vector3(0.0, 0.0, -2.0), 3.0)
	spawn_group(&"depouille", [Vector3(-2.5, 0.0, -8.0), Vector3(2.5, 0.0, -9.0), Vector3(0.0, 0.0, -12.0)])
	await until_peace()
	hud.show_message("La grille de la nef s'ouvre.", 2.5)
	open_gate(0)
	await reach(_checkpoint_position(1), 3.0)
	mark_checkpoint(1)


## La nef : les bancs se vident, puis une cloche de plus petite taille.
func _nave() -> void:
	await reach(Vector3(0.0, 0.0, -22.0), 3.0)
	hud.show_message("Les bancs se vident.", 3.0)
	spawn_group(&"depouille", [Vector3(-5.5, 0.0, -30.0), Vector3(5.5, 0.0, -31.0), Vector3(-5.0, 0.0, -39.5)])
	spawn(&"archer_creux", Vector3(6.0, 0.0, -44.0))
	await wait_until(func() -> bool: return standing_count() <= 1)
	hud.show_message("Une cloche, et des corps qui se relèvent.\nAbats-la d'abord.", 4.5)
	spawn(&"porte_cloche", Vector3(0.0, 0.0, -41.0))
	spawn(&"depouille", Vector3(-6.0, 0.0, -26.0))
	await until_peace()
	hud.show_message("La grille du chœur s'ouvre.", 2.5)
	open_gate(1)
	await reach(_checkpoint_position(2), 3.0)
	mark_checkpoint(2)


## Le Sonneur.
func _boss_fight() -> void:
	await say("Au fond, une cloche immense,\net trois cordes qui la tiennent.", 4.0)
	await reach(Vector3(0.0, 0.0, -55.0), 3.0)

	boss = spawn(&"sonneur", BELL_AT + Vector3(0.0, 0.0, 5.0), false) as SonneurEnemy
	boss.bell = _bell
	hud.show_boss("Le Sonneur", boss.health, 320)
	boss.health_changed.connect(_on_boss_health)
	boss.tolling_soon.connect(_on_tolling_soon)
	boss.tolled.connect(_on_tolled)
	boss.quaking_soon.connect(_on_quaking_soon)
	boss.slammed.connect(func() -> void: shake(1.2))
	boss.fell.connect(_on_boss_fell)
	_bell.rope_cut.connect(_on_rope_cut)
	_bell.fell.connect(_on_bell_fell)
	# Des corps gisent dans le chœur : la cloche les relèvera tous d'un coup.
	for at: Vector3 in CORPSE_SPOTS.slice(0, 4):
		_lay_corpse(at)
	hud.show_message("Le Sonneur ne se bat presque pas : il sonne.\nChaque coup relève tous les corps.", 5.5)
	_keep_corpses()

	await until_peace()
	hud.hide_boss()
	await say("Le Sonneur repose. La cloche se tait.", 3.0)


func _leave() -> void:
	hud.show_message("Derrière l'autel, la porte du caveau.", 4.0)
	await reach(EXIT, 2.5)
	finish()


# --- Le combat ----------------------------------------------------------------

func _on_boss_health(health: int, max_health: int) -> void:
	hud.set_boss(health, max_health)
	if boss.is_enraged() and not _enraged_said and health > 0 and not _bell.is_fallen:
		_enraged_said = true
		hud.show_message("Il sonne plus vite.", 3.0)


func _on_tolling_soon() -> void:
	if _first_warning:
		_first_warning = false
		hud.show_message("La cloche va sonner.\nDonne le Repos aux corps, ou coupe les cordes.", 5.5)


func _on_quaking_soon() -> void:
	if _first_quake:
		_first_quake = false
		hud.show_message("Il lève son maillet.\nEsquive quand l'onde t'atteint.", 4.0)


func _on_tolled(raised: int) -> void:
	_tolls += 1
	shake(1.0)
	if raised > 0:
		hud.show_message("Les corps se relèvent.", 2.0)


func _on_rope_cut(remaining: int) -> void:
	boss.on_rope_cut(_bell.ropes.size() - remaining)
	if remaining > 0:
		hud.show_message("Une corde cède. Encore %d." % remaining, 2.5)


func _on_bell_fell() -> void:
	boss.bell_fell()
	shake(1.5)
	hud.show_message("La cloche s'écrase sur le Sonneur.", 3.5)


## Un mort tombé, qui attend la cloche.
func _lay_corpse(at: Vector3) -> void:
	var corpse := spawn(&"depouille", at, false)
	corpse.rise_delay = 30.0
	corpse.take_hit(boss.global_position, 1000)


## Tant que la cloche sonne, de nouveaux morts se couchent dans le chœur :
## sans eux, la cloche n'aurait plus rien à relever.
func _keep_corpses() -> void:
	while is_instance_valid(boss) and not _bell.is_fallen:
		await wait(5.0)
		if not is_instance_valid(boss) or not boss.is_standing():
			continue
		if enemies_left() - 1 >= 3:
			continue
		var spots := CORPSE_SPOTS.duplicate()
		spots.shuffle()
		var laid := 0
		for at: Vector3 in spots:
			if laid >= 2:
				break
			if at.distance_to(hero.global_position) > 4.0:
				_lay_corpse(at)
				laid += 1


func _on_boss_fell(_enemy: Enemy) -> void:
	hud.show_message("Le Sonneur tombe.\nDonne-lui le Repos avant qu'il ne se relève.", 4.5)


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	var cells: Array[Vector2] = []
	for col in range(-3, 4):
		for row in range(-20, 2):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(DUNGEON + "floor_tile_large.glb", cells)

	_side_walls(NARTHEX, 4.0, -14.0)
	_side_walls(NAVE, -14.0, -46.0)
	_side_walls(CHOIR, -46.0, -80.0)
	_cross_wall(-14.0, 2.1, NAVE)
	_cross_wall(-46.0, 2.1, CHOIR)
	for gz in GATES_Z:
		for x: float in [-2.1, 2.1]:
			grave_piece("fence_pillar", Vector3(x, 0.0, gz))
	add_gate(Vector3(0.0, 0.0, GATES_Z[0]), 1)
	add_gate(Vector3(0.0, 0.0, GATES_Z[1]), 2)

	# Le fond : un mur derrière le héros au départ, le mur du chevet au nord.
	solid(Vector3(0.0, 0.0, 5.5), Vector3(2.0 * NARTHEX, 4.0, 1.0))
	place("wall_doorway.glb", Vector3(0.0, 0.0, -80.5))
	for x: float in [-4.0, 4.0, -8.0, 8.0]:
		place("wall.glb", Vector3(x, 0.0, -80.5))
	solid(Vector3(0.0, 0.0, -81.5), Vector3(2.0 * CHOIR + 2.0, 4.0, 1.0))

	# La nef : des piliers le long des murs, deux rangées de bancs.
	for z: float in [-20.0, -28.0, -36.0, -44.0]:
		for side: float in [-1.0, 1.0]:
			place("pillar.glb", Vector3(side * 7.0, 0.0, z))
			solid(Vector3(side * 7.0, 0.0, z), Vector3(1.5, 4.0, 1.5))
	for z: float in [-22.0, -27.0, -32.0, -37.0, -42.0]:
		for side: float in [-1.0, 1.0]:
			var pew := grave_piece("bench", Vector3(side * 3.8, 0.0, z))
			pew.scale = Vector3.ONE * 1.4
			solid(Vector3(side * 3.8, 0.0, z), Vector3(2.8, 0.7, 1.1))
	for z: float in [-22.0, -32.0, -42.0]:
		grave_piece("candle_triple", Vector3(-2.2, 0.0, z + 0.9))
		grave_piece("candle_melted", Vector3(2.2, 0.0, z - 0.9))

	# Le chœur : la cloche et sa poutre, l'autel, les cercueils.
	_bell = GreatBell.new()
	_bell.position = BELL_AT
	add_child(_bell)
	for side: float in [-1.0, 1.0]:
		var post := place("pillar.glb", Vector3(side * 9.0, 0.0, BELL_AT.z))
		post.scale = Vector3(1.0, 1.9, 1.0)
		solid(Vector3(side * 9.0, 0.0, BELL_AT.z), Vector3(1.5, 4.0, 1.5))
		grave_piece("coffin_decorated", Vector3(side * 8.8, 0.0, -57.0), 90.0)
		solid(Vector3(side * 8.8, 0.0, -57.0), Vector3(3.0, 1.2, 2.0))
	var altar := grave_piece("shrine_candles", Vector3(0.0, 0.0, -78.4))
	altar.scale = Vector3.ONE * 1.8
	solid(Vector3(0.0, 0.0, -78.4), Vector3(2.2, 2.0, 2.2))
	flame(Vector3(0.0, 2.2, -77.0), 2.2, 10.0)
	for x: float in [-5.0, 5.0]:
		grave_piece("plaque_candles", Vector3(x, 0.0, -78.0))
		solid(Vector3(x, 0.0, -78.0), Vector3(2.0, 1.1, 2.0))

	# Les torches.
	wall_torch(Vector3(-NARTHEX, 2.3, -6.0), 90.0)
	wall_torch(Vector3(-NAVE, 2.3, -26.0), 90.0)
	wall_torch(Vector3(NAVE, 2.3, -38.0), -90.0)
	wall_torch(Vector3(-CHOIR, 2.3, -53.0), 90.0)
	wall_torch(Vector3(CHOIR, 2.3, -62.0), -90.0)
	wall_torch(Vector3(-CHOIR, 2.3, -73.0), 90.0)

	# Des os et des cendres.
	for at: Vector3 in [Vector3(-2.0, 0.0, -4.0), Vector3(2.5, 0.0, -10.0), Vector3(0.0, 0.0, -34.0),
			Vector3(-6.0, 0.0, -60.0), Vector3(6.5, 0.0, -50.0), Vector3(-3.0, 0.0, -72.0)]:
		grave_piece("skull", at, at.z * 13.0).scale = Vector3.ONE * 0.45
		grave_piece("bone_A", at + Vector3(0.6, 0.05, 0.4), at.z * 31.0)
		grave_piece("bone_B", at + Vector3(-0.5, 0.05, -0.3), at.z * 7.0)


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
