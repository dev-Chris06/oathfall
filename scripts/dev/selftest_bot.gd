class_name SelftestBot
extends Node
## Joueur automatique, pour vérifier le jeu sans intervention.
##
## Il joue comme un joueur simple : il court vers le mort le plus proche, le
## frappe, donne le Repos aux corps, puis rejoint l'objectif du niveau.
##
## Dans l'arène, il vérifie les mécaniques :
##   1. une vague de deux Dépouilles peut être abattue et mise au repos ;
##   2. un corps laissé sans Repos se relève ;
##   3. le mort relevé peut à son tour être abattu et mis au repos ;
##   4. un mort frappe bien un héros qui ne bouge pas.
## Puis la progression :
##   5. les souvenirs font gagner un niveau, de la vie et un point ;
##   6. le carnet met le jeu en pause et apprend une compétence ;
##   7. le Repos soigne le héros qui a appris « Souffle rendu » ;
##   8. la sauvegarde relue rend la même progression.
## Puis il traverse la Grille :
##   9. il atteint le premier point de reprise, qui est sauvegardé ;
##  10. tombé exprès, le héros revient à ce point, sans rien perdre ;
##  11. il termine le niveau, et la fin est enregistrée.
## Enfin la carte :
##  12. états des niveaux, entrée dans un niveau, abandon depuis le carnet.
## Enfin le moulin et les menus :
##  13. boutique (achats, prérequis, bonus), conversations, rites appris
##      seulement chez Anselme, entrée et sortie du moulin ;
##  14. écran-titre, nouvelle partie, texte d'ouverture, retour à la carte.
## Avec `capture_dir`, il ne joue que la Grille et enregistre des images.

var main: Node
var capture_dir := ""
var capture_map := false
var start_checkpoint := 0

var _allow_rest := true
var _passive := false
var _attack_timer := 0.0
var _rose := false
var _checkpoint := 0
var _completed := false
var _last_position := Vector3.ZERO
var _stuck_time := 0.0
var _detour_time := 0.0
var _detour_side := 1.0


func _ready() -> void:
	if capture_dir.is_empty():
		_run()
	else:
		_capture()


func _level() -> Level:
	return main.level


func _physics_process(delta: float) -> void:
	var level := _level()
	if level == null or level.hero == null:
		return
	var hero := level.hero
	var controls := level.controls
	controls.simulated_move = Vector2.ZERO
	controls.simulated_rite = false
	if hero.is_dead() or _passive:
		return
	_dodge_if_needed(level, hero, controls)

	var target := _choose_target(hero)
	if target != null:
		var offset := target.global_position - hero.global_position
		var direction := Vector2(offset.x, offset.z).normalized()
		if offset.length() > 2.1:
			controls.simulated_move = direction
		else:
			controls.simulated_move = direction * 0.25
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack_timer = 0.22
				controls.press_attack()
		_avoid_obstacles(hero, controls, delta)
		return

	var rope := _nearest(&"ropes", hero) as BellRope
	if rope != null and _allow_rest and hero.global_position.distance_to(rope.global_position) < 14.0:
		var to_rope := rope.global_position - hero.global_position
		if Vector2(to_rope.x, to_rope.z).length() > 1.6:
			controls.simulated_move = Vector2(to_rope.x, to_rope.z).normalized()
			_avoid_obstacles(hero, controls, delta)
		else:
			controls.simulated_rite = true
		return

	var body := _nearest(&"bodies", hero) as Enemy if _allow_rest else null
	if body != null:
		var offset := body.body_position() - hero.global_position
		if body.global_position.distance_to(hero.global_position) < offset.length():
			offset = body.global_position - hero.global_position
		if offset.length() > 1.4:
			controls.simulated_move = Vector2(offset.x, offset.z).normalized()
		else:
			controls.simulated_rite = true
		return

	if level.objective != null:
		var offset: Vector3 = level.objective - hero.global_position
		if Vector2(offset.x, offset.z).length() > 0.5:
			controls.simulated_move = Vector2(offset.x, offset.z).normalized()
	_avoid_obstacles(hero, controls, delta)


## Esquive comme un joueur attentif : au tir d'un archer, au jaillissement
## d'un Fouisseur, et une fois sur deux devant un coup armé tout près.
func _dodge_if_needed(level: Level, hero: Hero, controls: TouchControls) -> void:
	# Une pierre lancée : on esquive juste avant qu'elle ne retombe sur soi.
	for node in get_tree().get_nodes_in_group(&"stones"):
		var stone := node as GraveStone
		var landing := Vector3(stone.target.x - hero.global_position.x, 0.0, stone.target.z - hero.global_position.z)
		if stone.time_left() < 0.3 and landing.length() < stone.radius + 0.6:
			controls.simulated_move = Vector2(-landing.x, -landing.z).normalized()
			controls.press_dodge()
			return
	for enemy in level.enemies():
		var threat := false
		if enemy is ArcherEnemy and enemy.state == Enemy.State.SPECIAL:
			threat = enemy._state_time > float(enemy._type["aim_time"]) - 0.2 and not enemy._fired
		elif enemy is Burrower and enemy.state == Enemy.State.SPECIAL:
			threat = enemy._phase == Burrower.Phase.WARNING and enemy._state_time > 0.35
		elif enemy is SonneurEnemy and enemy.is_quaking():
			# L'onde du Sonneur : on esquive quand son front arrive.
			var gap := absf(enemy.wave_radius() - enemy.global_position.distance_to(hero.global_position))
			threat = gap < 2.4
		elif enemy is FossoyeuseEnemy:
			# Ses gestes sont annoncés : on esquive juste avant qu'ils ne portent.
			threat = enemy.danger_time(hero.global_position) < 0.3
		elif enemy.state == Enemy.State.WINDUP and not enemy._struck:
			var close := enemy.global_position.distance_to(hero.global_position) < maxf(2.6, float(enemy._type["attack_range"]) + 0.4)
			threat = close and enemy._state_time > float(enemy._type["attack_windup"]) - 0.25 \
				and enemy.get_instance_id() % 2 == 0
		if threat:
			var away := hero.global_position - enemy.global_position
			var side := Vector2(away.x, away.z).normalized().orthogonal()
			controls.simulated_move = side
			controls.press_dodge()
			return


## Un joueur qui bute contre une tombe la contourne : s'il n'avance plus, il
## part un moment de côté.
func _avoid_obstacles(hero: Hero, controls: TouchControls, delta: float) -> void:
	var moved := hero.global_position.distance_to(_last_position)
	_last_position = hero.global_position
	if _detour_time > 0.0:
		_detour_time -= delta
		controls.simulated_move = controls.simulated_move.orthogonal() * _detour_side \
			+ controls.simulated_move * 0.3
		return
	if controls.simulated_move.length() > 0.9 and moved < 0.02:
		_stuck_time += delta
		if _stuck_time > 0.4:
			_stuck_time = 0.0
			_detour_time = 0.7
			_detour_side = -_detour_side
	else:
		_stuck_time = 0.0


## Comme un joueur qui a compris le niveau : l'archer, la cloche et la
## Veuve passent avant les Dépouilles, s'ils ne sont pas trop loin.
func _choose_target(hero: Hero) -> Node3D:
	var best: Node3D = null
	var boss: Enemy = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"hittable"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if enemy is SonneurEnemy:
			boss = enemy
			continue
		var score := hero.global_position.distance_to(enemy.global_position)
		if enemy is ArcherEnemy or enemy is BellRinger or enemy is Widow:
			score -= 7.0
		if score < best_score:
			best_score = score
			best = enemy
	# Le Sonneur ne se bat presque pas : on l'attaque quand il n'y a plus de
	# corps à mettre au repos ni de corde à couper.
	if best == null and boss != null and get_tree().get_nodes_in_group(&"bodies").is_empty() \
			and get_tree().get_nodes_in_group(&"ropes").is_empty():
		best = boss
	return best


func _nearest(group: StringName, hero: Hero) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(group):
		var candidate := node as Node3D
		if candidate == null:
			continue
		var distance := hero.global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _run() -> void:
	if not await _arena_tests():
		return
	if not await _progress_tests():
		return
	if not await _bestiary_tests():
		return
	if not await _boss_tests():
		return
	if not await _quake_tests():
		return
	if not await _fossoyeuse_tests():
		return
	if not await _blow_alignment_tests():
		return
	if not await _grille_tests():
		return
	if not await _traverse(&"les_allees"):
		return
	if not await _traverse(&"la_chapelle"):
		return
	if not await _traverse(&"l_ossuaire"):
		return
	if not await _traverse(&"la_fosse"):
		return
	if not await _map_tests():
		return
	if not await _refuge_tests():
		return
	if not await _menu_tests():
		return
	print("SELFTEST OK")
	get_tree().quit(0)


func _arena_tests() -> bool:
	main.load_level(&"arena")
	var arena := _level() as Arena
	var hero := arena.hero
	await get_tree().create_timer(0.5).timeout

	# 1. Une vague de deux morts, abattus puis mis au repos.
	arena.spawn_wave(2)
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 90.0):
		return _fail("la vague de deux morts n'a pas été mise au repos")
	print("test 1 réussi : deux morts abattus et mis au repos, vie du héros %d" % hero.health)

	# 2. Un corps laissé sans Repos doit se relever.
	_allow_rest = false
	arena.spawn_wave(1, 1.5)
	var enemy: Enemy = arena.enemies()[0]
	enemy.rose.connect(func(_e: Enemy) -> void: _rose = true)
	if not await _until(func() -> bool: return _rose, 60.0):
		return _fail("le mort laissé sans Repos ne s'est pas relevé")
	print("test 2 réussi : le mort s'est relevé, avec %d points de vie" % enemy.health)

	# 3. Le mort relevé est abattu de nouveau, puis mis au repos.
	enemy.rise_delay = 20.0
	_allow_rest = true
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 90.0):
		return _fail("le mort relevé n'a pas été mis au repos")
	print("test 3 réussi : le mort relevé repose")

	# 4. Un héros immobile doit être frappé.
	_passive = true
	arena.spawn_wave(1)
	if not await _until(func() -> bool: return hero.health < hero.max_health, 30.0):
		return _fail("le mort n'a pas réussi à frapper un héros immobile")
	print("test 4 réussi : le héros immobile a été frappé, vie %d" % hero.health)
	_passive = false
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 90.0):
		return _fail("le dernier mort n'a pas été mis au repos")
	return true


func _progress_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero

	# 5. Gagner un niveau.
	var before_max := hero.max_health
	Progress.add_memories(Progression.threshold(2) - Progress.memories)
	if Progress.hero_level != 2 or Progress.skill_points != 1:
		return _fail("niveau %d et %d points après le premier palier" % [Progress.hero_level, Progress.skill_points])
	if hero.max_health != before_max + Progression.HEALTH_PER_LEVEL:
		return _fail("la vie maximale n'a pas augmenté (%d)" % hero.max_health)
	print("test 5 réussi : niveau 2, vie maximale %d" % hero.max_health)

	# 6. Le carnet : pause, apprentissage, refus faute de points.
	arena.open_book()
	if not get_tree().paused or arena.book == null:
		return _fail("le carnet n'a pas mis le jeu en pause")
	if not arena.book.learn(&"priere_breve"):
		return _fail("« Prière brève » n'a pas pu être apprise")
	if not is_equal_approx(hero.rite_time, 0.75):
		return _fail("le rite dure %.2f s au lieu de 0,75 s" % hero.rite_time)
	if arena.book.learn(&"priere_breve"):
		return _fail("une compétence a été apprise sans points")
	arena.book.close_book()
	if get_tree().paused:
		return _fail("le jeu est resté en pause après la fermeture du carnet")
	print("test 6 réussi : carnet ouvert, rite en %.2f s" % hero.rite_time)

	# 7. Le Repos soigne.
	Progress.skill_points += 1
	Progress.learn(&"souffle_rendu")
	var heals := [0]
	var last := [hero.health]
	hero.health_changed.connect(func(health: int, _max: int) -> void:
		if health > last[0]:
			heals[0] += 1
		last[0] = health)
	hero.take_damage(30, hero.global_position + Vector3.FORWARD)
	last[0] = hero.health
	var gold_before := Progress.gold
	arena.spawn_wave(1)
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 90.0):
		return _fail("le mort du test de soin n'a pas été mis au repos")
	if heals[0] == 0:
		return _fail("le Repos n'a pas soigné le héros")
	if Progress.gold <= gold_before:
		return _fail("le mort mis au repos n'a pas laissé d'or")
	print("test 7 réussi : le Repos soigne, %d d'or" % Progress.gold)

	# 8. Sauvegarde et relecture.
	Progress.save()
	var saved := [Progress.memories, Progress.hero_level, Progress.skill_points, Progress.gold,
		Progress.rank_of(&"priere_breve"), Progress.rank_of(&"souffle_rendu")]
	Progress.reset()
	if not Progress.load_save():
		return _fail("la sauvegarde n'a pas pu être relue")
	var loaded := [Progress.memories, Progress.hero_level, Progress.skill_points, Progress.gold,
		Progress.rank_of(&"priere_breve"), Progress.rank_of(&"souffle_rendu")]
	if loaded != saved:
		return _fail("sauvegarde %s relue comme %s" % [saved, loaded])
	print("test 8 réussi : sauvegarde relue à l'identique %s" % [loaded])
	return true


## Chaque mort fait ce qu'il doit. Le héros reste passif le temps de la
## vérification, puis abat et met au repos tout le monde.
func _bestiary_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero

	# Archer creux : son carreau touche un héros immobile.
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	_passive = true
	arena.spawn(&"archer_creux", Vector3(0.0, 0.0, -6.0), false)
	if not await _until(func() -> bool: return hero.health < hero.max_health, 20.0):
		return _fail("l'Archer creux n'a pas touché le héros")
	print("test bestiaire réussi : l'Archer creux tire, vie %d" % hero.health)
	_passive = false
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 120.0):
		return _fail("l'Archer creux n'a pas été mis au repos")

	# Porte-cloche : un corps à portée de sa cloche se relève plus vite.
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	_passive = true
	var body := arena.spawn(&"depouille", Vector3(4.0, 0.0, 3.0), false)
	body.take_hit(hero.global_position, 1000)
	var ringer := arena.spawn(&"porte_cloche", Vector3(-5.0, 0.0, 3.0), false)
	await get_tree().physics_frame
	if body.rise_rate() <= 1.0:
		return _fail("la cloche n'accélère pas le relèvement (%.1f)" % body.rise_rate())
	print("test bestiaire réussi : la cloche presse les corps (x%.1f)" % body.rise_rate())
	ringer.take_hit(hero.global_position, 1000)
	await get_tree().physics_frame
	if body.rise_rate() > 1.0:
		return _fail("la cloche sonne encore, Porte-cloche abattu")
	_passive = false
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 120.0):
		return _fail("le Porte-cloche n'a pas été mis au repos")

	# Veuve : son cri relève un corps.
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	_passive = true
	_allow_rest = false
	var fallen := arena.spawn(&"depouille", Vector3(3.0, 0.0, 5.0), false)
	fallen.take_hit(hero.global_position, 1000)
	var widow := arena.spawn(&"veuve", Vector3(-6.0, 0.0, -2.0), false) as Widow
	var raised := [-1]
	widow.screamed.connect(func(count: int) -> void: raised[0] = count)
	if not await _until(func() -> bool: return raised[0] >= 0, 25.0):
		return _fail("la Veuve n'a pas crié")
	if raised[0] < 1:
		return _fail("le cri de la Veuve n'a relevé aucun corps")
	print("test bestiaire réussi : le cri de la Veuve relève %d corps" % raised[0])
	_passive = false
	_allow_rest = true
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 120.0):
		return _fail("la Veuve n'a pas été mise au repos")

	# Fouisseur : il file sous terre et jaillit près du héros.
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	_passive = true
	var burrower := arena.spawn(&"fouisseur", Vector3(8.0, 0.0, -4.0)) as Burrower
	if not burrower.is_burrowed():
		return _fail("le Fouisseur n'est pas parti sous terre")
	if not await _until(func() -> bool: return not burrower.is_burrowed(), 20.0):
		return _fail("le Fouisseur n'a pas jailli")
	var distance := burrower.global_position.distance_to(hero.global_position)
	if distance > 3.0:
		return _fail("le Fouisseur a jailli loin du héros (%.1f)" % distance)
	print("test bestiaire réussi : le Fouisseur jaillit à %.1f du héros" % distance)
	_passive = false
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 120.0):
		return _fail("le Fouisseur n'a pas été mis au repos")
	return true


## Le Sonneur : son coup de cloche relève les corps, couper les cordes fait
## tomber la cloche sur lui.
func _boss_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	_passive = true
	_allow_rest = false

	var body := arena.spawn(&"depouille", Vector3(5.0, 0.0, 3.0), false)
	body.take_hit(hero.global_position, 1000)
	var sonneur := arena.spawn(&"sonneur", Vector3(0.0, 0.0, -7.0), false) as SonneurEnemy
	var tolls := [-1]
	sonneur.tolled.connect(func(raised: int) -> void: tolls[0] = raised)
	if not await _until(func() -> bool: return tolls[0] >= 0, 60.0):
		return _fail("le Sonneur n'a pas sonné la cloche")
	if tolls[0] < 1:
		return _fail("le coup de cloche n'a relevé aucun corps")
	if body.state != Enemy.State.RISING and body.state != Enemy.State.CHASE:
		return _fail("le corps ne se relève pas au coup de cloche (état %d)" % body.state)
	print("test boss réussi : le coup de cloche relève %d corps" % tolls[0])

	# Les trois cordes coupées : la cloche tombe, le boss perd 35 % et s'étourdit.
	var bell := GreatBell.new()
	bell.position = Vector3(0.0, 0.0, -2.0)
	arena.add_child(bell)
	await get_tree().process_frame
	bell.rope_cut.connect(func(remaining: int) -> void: sonneur.on_rope_cut(bell.ropes.size() - remaining))
	var fallen := [false]
	bell.fell.connect(func() -> void:
		sonneur.bell_fell()
		fallen[0] = true)
	var before := sonneur.health
	for rope in bell.ropes:
		rope.cut_now()
	if bell.ropes_cut() != 3:
		return _fail("les cordes n'ont pas cédé (%d sur 3)" % bell.ropes_cut())
	if not await _until(func() -> bool: return fallen[0], 10.0):
		return _fail("la cloche n'est pas tombée")
	var lost := before - sonneur.health
	var expected := int(320.0 * 0.35)
	if absi(lost - expected) > 1:
		return _fail("la cloche a coûté %d points au Sonneur au lieu de %d" % [lost, expected])
	if sonneur.state != Enemy.State.SPECIAL:
		return _fail("le Sonneur n'est pas étourdi par la chute")
	var type := EnemyTypes.get_type(&"sonneur")
	var wanted := float(type["toll_interval"]) + 3.0 * float(type["toll_rope_delay"])
	if absf(sonneur.toll_interval() - wanted) > 0.01:
		return _fail("les cordes coupées espacent les coups de %.1f s au lieu de %.1f s" % [sonneur.toll_interval(), wanted])
	print("test boss réussi : la cloche tombée coûte %d points au Sonneur" % lost)

	# Le boss tombe : il faut aussi lui donner le Repos.
	bell.queue_free()
	_passive = false
	_allow_rest = true
	sonneur.take_hit(hero.global_position, 100000)
	if not sonneur.is_down():
		return _fail("le Sonneur vaincu ne tombe pas")
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 120.0):
		return _fail("le Sonneur n'a pas été mis au repos")
	print("test boss réussi : le Sonneur reçoit le Repos")

	# Couper : le héros qui maintient le bouton près d'une corde la coupe.
	var tower := GreatBell.new()
	tower.position = Vector3.ZERO
	arena.add_child(tower)
	await get_tree().process_frame
	var seen := [false]
	var done := await _until(func() -> bool:
		if arena.controls.rite_label == "COUPER":
			seen[0] = true
		return tower.ropes_cut() == 3, 60.0)
	if not done:
		return _fail("le héros n'a coupé que %d corde(s) sur 3 en les coupant" % tower.ropes_cut())
	if not seen[0]:
		return _fail("le bouton n'a jamais affiché COUPER près d'une corde")
	if not await _until(func() -> bool: return tower.is_fallen, 10.0):
		return _fail("la cloche n'est pas tombée après la troisième corde")
	print("test boss réussi : le héros coupe les trois cordes")
	tower.queue_free()
	return true


## La frappe sismique : l'onde blesse celui qu'elle traverse, sauf s'il esquive.
func _quake_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	var type := EnemyTypes.get_type(&"sonneur")
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 2.0)
	_passive = true

	var sonneur := arena.spawn(&"sonneur", Vector3(0.0, 0.0, -5.0), false) as SonneurEnemy
	var result := [-1]
	sonneur.quaked.connect(func(hit: bool) -> void: result[0] = 1 if hit else 0)
	sonneur._quake_timer = 0.2

	# Un héros immobile reçoit l'onde.
	var before := hero.health
	if not await _until(func() -> bool: return result[0] >= 0, 30.0):
		return _fail("le Sonneur n'a pas lancé la frappe sismique")
	if result[0] != 1:
		return _fail("l'onde n'a pas touché un héros immobile à portée")
	var lost := before - hero.health
	if lost != int(type["quake_damage"]):
		return _fail("l'onde a coûté %d points au lieu de %d" % [lost, int(type["quake_damage"])])
	print("test boss réussi : la frappe sismique coûte %d points à un héros immobile" % lost)

	# Un héros qui esquive quand le front de l'onde arrive ne perd rien.
	hero.heal(1000)
	before = hero.health
	result[0] = -1
	sonneur._quake_timer = 0.2
	var pressed := [false]
	var finished := await _until(func() -> bool:
		if sonneur.is_quaking() and not pressed[0]:
			var gap := absf(sonneur.wave_radius() - sonneur.global_position.distance_to(hero.global_position))
			if gap < 2.4:
				arena.controls.press_dodge()
				pressed[0] = true
		return result[0] >= 0, 30.0)
	if not finished:
		return _fail("la seconde frappe sismique n'a pas eu lieu")
	if result[0] != 0 or hero.health < before:
		return _fail("l'esquive ne protège pas de l'onde (touché : %s, vie %d sur %d)" % [result[0] == 1, hero.health, before])
	print("test boss réussi : l'esquive évite la frappe sismique")

	# Hors de portée de l'onde, il ne la lance pas.
	hero.global_position = Vector3(0.0, 0.0, 9.0)
	result[0] = -1
	sonneur._quake_timer = 0.2
	await get_tree().create_timer(2.5).timeout
	if result[0] != -1 or sonneur.is_quaking() or sonneur.state == Enemy.State.SPECIAL:
		return _fail("le Sonneur lance la frappe sismique sur un héros hors de portée")
	print("test boss réussi : pas de frappe sismique hors de portée")

	_passive = false
	sonneur.take_hit(hero.global_position, 100000)
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 120.0):
		return _fail("le Sonneur de l'essai n'a pas été mis au repos")
	return true


## La Fossoyeuse : ses trois phases, une par une.
func _fossoyeuse_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	var type := EnemyTypes.get_type(&"fossoyeuse")
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	_passive = true
	_allow_rest = false

	var damages: Array[int] = []
	var last := [hero.health]
	hero.health_changed.connect(func(health: int, _max: int) -> void:
		if health < last[0]:
			damages.append(last[0] - health)
		last[0] = health)

	var boss := arena.spawn(&"fossoyeuse", Vector3(0.0, 0.0, -7.0), false) as FossoyeuseEnemy
	boss.mounds = [Vector3(-10.0, 0.0, -5.0), Vector3(10.0, 0.0, -5.0), Vector3(-10.0, 0.0, 5.0)]
	var stage := [1]
	boss.stage_changed.connect(func(value: int) -> void: stage[0] = value)

	# Phase 1 : la pelle blesse un héros immobile (un coup de pelle ou un balayage).
	if not await _until(func() -> bool:
		hero.heal(1000)
		return damages.has(int(type["swing_damage"])) or damages.has(int(type["sweep_damage"])), 40.0):
		return _fail("la Fossoyeuse n'a pas touché un héros immobile à la pelle (dégâts : %s)" % [damages])
	print("test fossoyeuse réussi : la pelle blesse (%s)" % [damages])

	# Elle bascule en phase 2 quand sa vie passe sous le seuil.
	boss.take_hit(hero.global_position, int(type["health"]) - int(float(type["health"]) * float(type["stage2_at"])) + 10)
	if not await _until(func() -> bool:
		hero.heal(1000)
		return stage[0] == 2, 20.0):
		return _fail("la Fossoyeuse n'est pas passée en phase 2 (phase %d, vie %d)" % [stage[0], boss.health])
	print("test fossoyeuse réussi : phase 2 à %d points de vie" % boss.health)

	# Phase 2 : elle plonge, ressort et déterre des Dépouilles.
	var dug_points := [0]
	boss.dug.connect(func(points: Array) -> void: dug_points[0] = points.size())
	damages.clear()
	if not await _until(func() -> bool:
		hero.heal(1000)
		return dug_points[0] > 0, 40.0):
		return _fail("la Fossoyeuse n'a pas déterré de Dépouilles")
	if dug_points[0] != int(type["dig_count"]):
		return _fail("elle a déterré %d Dépouilles au lieu de %d" % [dug_points[0], int(type["dig_count"])])
	print("test fossoyeuse réussi : elle jaillit du sol et déterre %d Dépouilles" % dug_points[0])

	# Puis elle charge : un héros immobile dans la ligne est touché.
	if not await _until(func() -> bool:
		hero.heal(1000)
		var line := boss.global_position - hero.global_position
		if boss.state == Enemy.State.SPECIAL and line.length() > 8.0:
			hero.global_position = boss.global_position + Vector3(0.0, 0.0, 6.0)
		return damages.has(int(type["charge_damage"])), 60.0):
		return _fail("la charge de la Fossoyeuse n'a pas touché le héros (dégâts : %s)" % [damages])
	print("test fossoyeuse réussi : la charge blesse (%d)" % int(type["charge_damage"]))

	# Phase 3 : à bas niveau de vie, elle arrache et lance des pierres.
	boss.take_hit(hero.global_position, boss.health - int(float(type["health"]) * float(type["stage3_at"])) + 10)
	var stones := [0]
	var landed_hit := [-1]
	boss.thrown.connect(func(stone: GraveStone) -> void:
		stones[0] += 1
		stone.landed.connect(func(hit: bool) -> void: landed_hit[0] = 1 if hit else 0))
	if not await _until(func() -> bool:
		hero.heal(1000)
		return stage[0] == 3, 40.0):
		return _fail("la Fossoyeuse n'est pas passée en phase 3 (phase %d, vie %d)" % [stage[0], boss.health])
	hero.global_position = Vector3(0.0, 0.0, 8.0)
	damages.clear()
	if not await _until(func() -> bool:
		hero.heal(1000)
		return landed_hit[0] >= 0, 40.0):
		return _fail("la Fossoyeuse n'a pas lancé de pierre")
	if landed_hit[0] != 1 or not damages.has(int(type["throw_damage"])):
		return _fail("la pierre n'a pas blessé le héros immobile (dégâts : %s)" % [damages])
	print("test fossoyeuse réussi : une pierre lancée retombe et blesse (%d)" % int(type["throw_damage"]))

	# Son cri relève tous les corps.
	var body := arena.spawn(&"depouille", Vector3(-4.0, 0.0, 6.0), false)
	body.take_hit(hero.global_position, 1000)
	body.rise_delay = 90.0
	var raised_count := [-1]
	boss.raised.connect(func(count: int) -> void: raised_count[0] = count)
	boss._raise_timer = 0.1
	if not await _until(func() -> bool:
		hero.heal(1000)
		return raised_count[0] >= 0, 40.0):
		return _fail("la Fossoyeuse n'a pas poussé son cri")
	if raised_count[0] < 1:
		return _fail("son cri n'a relevé aucun corps")
	print("test fossoyeuse réussi : son cri relève %d corps" % raised_count[0])

	# Elle tombe : il faut lui donner le Repos.
	_passive = false
	_allow_rest = true
	boss.take_hit(hero.global_position, 100000)
	if not boss.is_down():
		return _fail("la Fossoyeuse vaincue ne tombe pas")
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 180.0):
		return _fail("la Fossoyeuse n'a pas été mise au repos")
	print("test fossoyeuse réussi : la Fossoyeuse reçoit le Repos")
	return true


## Le coup visible tombe au moment des dégâts : pour chaque geste, l'instant où
## l'animation frappe (la part `impact` de sa durée, à la vitesse jouée) doit
## être celui où les dégâts sont appliqués (`windup`). Sans cela, on voit le
## coup toucher, puis les dégâts n'arrivent que plus tard.
func _blow_alignment_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	_passive = true
	_allow_rest = false

	# Les gestes dont on déclenche l'animation à la main.
	var boss := arena.spawn(&"fossoyeuse", Vector3(0.0, 0.0, -8.0), false) as FossoyeuseEnemy
	var type := EnemyTypes.get_type(&"fossoyeuse")
	boss._start_melee()
	if not _check_blow("coup de pelle", boss, float(type["swing_windup"]), float(type["swing_impact"])):
		return false
	boss._attacks = 2
	boss._start_melee()
	if not _check_blow("balayage", boss, float(type["sweep_windup"]), float(type["sweep_impact"])):
		return false
	boss._begin_throw()
	if not _check_blow("lancer de pierre", boss, float(type["throw_windup"]), float(type["throw_impact"])):
		return false
	boss.take_hit(hero.global_position, 100000)

	var sonneur := arena.spawn(&"sonneur", Vector3(0.0, 0.0, -8.0), false) as SonneurEnemy
	sonneur._begin_quake()
	var sonneur_type := EnemyTypes.get_type(&"sonneur")
	if not _check_blow("frappe sismique", sonneur, float(sonneur_type["quake_windup"]), float(sonneur_type["quake_impact"])):
		return false
	sonneur.take_hit(hero.global_position, 100000)

	# Les morts du chapitre : on attend qu'ils arment leur coup au corps à corps.
	for id: StringName in [&"depouille", &"porte_cloche", &"fouisseur", &"archer_creux"]:
		var enemy := arena.spawn(id, hero.global_position + Vector3(1.3, 0.0, 0.0), false)
		enemy._cooldown = 0.0
		var armed := await _until(func() -> bool:
			hero.heal(1000)
			return enemy.state == Enemy.State.WINDUP, 20.0)
		if not armed:
			return _fail("%s n'a pas armé de coup au corps à corps" % id)
		var data := EnemyTypes.get_type(id)
		if not _check_blow(String(id), enemy, float(data["attack_windup"]), float(data["attack_impact"])):
			return false
		enemy.take_hit(hero.global_position, 100000)

	print("test réussi : le coup visible tombe au moment des dégâts, pour tous les gestes")
	_passive = false
	_allow_rest = true
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 240.0):
		return _fail("les morts de l'essai d'alignement n'ont pas été mis au repos")
	return true


func _check_blow(label: String, enemy: Enemy, windup: float, impact: float) -> bool:
	var player: AnimationPlayer = enemy._anim
	var anim := player.get_animation(player.current_animation)
	var visible := anim.length * impact / player.get_playing_speed()
	if absf(visible - windup) > 0.03:
		_fail("%s : le coup frappe à %.2f s à l'écran, mais les dégâts tombent à %.2f s" % [label, visible, windup])
		return false
	return true


func _grille_tests() -> bool:
	main.load_level(&"la_grille")
	_watch(_level())

	# 9. Le premier point de reprise, sauvegardé.
	if not await _until(func() -> bool: return _checkpoint >= 1, 300.0):
		return _fail("le premier point de reprise n'a pas été atteint")
	var memories: int = Progress.memories
	Progress.reset()
	Progress.load_save()
	if Progress.checkpoint != 1 or Progress.level_id != &"la_grille" or Progress.memories != memories:
		return _fail("le point de reprise n'a pas été sauvegardé")
	print("test 9 réussi : première cour traversée et sauvegardée, %d souvenirs" % memories)

	# 10. Le héros tombe : il doit revenir au point de reprise.
	var fallen := _level().get_instance_id()
	_level().hero.take_damage(100000, _level().hero.global_position + Vector3.FORWARD)
	if not await _until(func() -> bool: return _level().get_instance_id() != fallen, 20.0, false):
		return _fail("le niveau n'a pas été rechargé après la chute du héros")
	var grille := _level() as LaGrille
	_watch(grille)
	await get_tree().physics_frame
	var expected := grille._checkpoint_position(1)
	if grille.hero.global_position.distance_to(expected) > 1.0:
		return _fail("le héros n'est pas revenu au point de reprise (%s)" % grille.hero.global_position)
	if Progress.memories < memories:
		return _fail("des souvenirs ont été perdus (%d au lieu de %d)" % [Progress.memories, memories])
	if grille.hero.max_health != int(Progress.hero_stats()["max_health"]):
		return _fail("le héros relevé n'a pas sa vie maximale")
	print("test 10 réussi : le héros se relève au point de reprise")

	# 11. La fin du niveau. Le joueur automatique n'esquive pas : il peut
	# tomber, et doit alors reprendre au point de reprise, comme un joueur.
	var falls := [0]
	var on_load := func(level: Level) -> void:
		falls[0] += 1
		_watch(level)
	main.level_loaded.connect(on_load)
	var finished := await _until(func() -> bool: return _completed or falls[0] > 6, 1200.0, false)
	main.level_loaded.disconnect(on_load)
	if not finished:
		return _fail("la Grille n'a pas été terminée")
	if not _completed:
		return _fail("le joueur automatique est tombé plus de six fois")
	if not Progress.is_completed(&"la_grille"):
		return _fail("la fin de la Grille n'a pas été enregistrée")
	print("test 11 réussi : la Grille est terminée, vie %d, niveau %d, %d d'or, %d chute(s)" % [
		_level().hero.health, Progress.hero_level, Progress.gold, falls[0]])
	return true


## Traverse un niveau de bout en bout. Le joueur automatique peut tomber :
## il reprend alors au point de reprise, comme un joueur.
func _traverse(id: StringName) -> bool:
	_completed = false
	_checkpoint = 0
	var falls := [0]
	var on_load := func(level: Level) -> void:
		falls[0] += 1
		_watch(level)
	main.level_loaded.connect(on_load)
	main.load_level(id)
	falls[0] = 0
	var done := await _until(func() -> bool: return _completed or falls[0] > 6, 1500.0, false)
	main.level_loaded.disconnect(on_load)
	if not done or not _completed:
		return _fail("%s n'a pas été terminé (%d chutes)" % [id, falls[0]])
	if not Progress.is_completed(id):
		return _fail("la fin de %s n'a pas été enregistrée" % id)
	print("test réussi : %s terminé, niveau %d, %d d'or, %d chute(s)" % [
		_level().title, Progress.hero_level, Progress.gold, falls[0]])
	return true


## La carte : états des niveaux, choix, entrée, abandon.
func _map_tests() -> bool:
	Progress.completed.clear()
	main.show_map()
	await get_tree().process_frame
	var map: WorldMap = main.world_map
	if map == null or main.level != null:
		return _fail("la carte ne s'affiche pas")

	if map.state_of(&"la_grille") != "ici" or map.state_of(&"les_allees") != "ouvert":
		return _fail("états au départ : %s, %s" % [map.state_of(&"la_grille"), map.state_of(&"les_allees")])
	Progress.mark_completed(&"la_grille")
	if map.state_of(&"la_grille") != "fait" or map.state_of(&"les_allees") != "ici":
		return _fail("la Grille faite ne fait pas passer aux Allées")
	Progress.mark_completed(&"les_allees")
	# La Chapelle vient après les Allées ; les autres sont ouverts.
	if map.state_of(&"la_chapelle") != "ici" or map.state_of(&"l_ossuaire") != "ouvert" \
			or map.state_of(&"la_fosse") != "ouvert":
		return _fail("états après les Allées : %s, %s, %s" % [
			map.state_of(&"la_chapelle"), map.state_of(&"l_ossuaire"), map.state_of(&"la_fosse")])
	Progress.mark_completed(&"la_chapelle")
	if map.state_of(&"l_ossuaire") != "ici":
		return _fail("l'Ossuaire ne devient pas le prochain niveau après la Chapelle")
	Progress.completed.erase("la_chapelle")

	# La progression terminée survit à la sauvegarde.
	Progress.save()
	Progress.reset()
	Progress.load_save()
	if not Progress.is_completed(&"la_grille") or not Progress.is_completed(&"les_allees"):
		return _fail("les niveaux terminés ne sont pas relus de la sauvegarde")
	if Progress.is_completed(&"l_ossuaire"):
		return _fail("un niveau non terminé est lu comme terminé")
	print("test 12 réussi : états de la carte et sauvegarde des niveaux terminés")

	# Un niveau non construit ne s'ouvre pas ; un niveau construit, si. Tous
	# ceux du chapitre existent : on en retire un de la carte pour l'essai.
	map.available.erase(&"la_fosse")
	map.refresh()
	if map.state_of(&"la_fosse") != "ferme":
		return _fail("un niveau absent n'est pas fermé sur la carte")
	var chosen := [&""]
	map.level_chosen.connect(func(id: StringName) -> void: chosen[0] = id)
	map.select_level(&"la_fosse")
	map.enter_selected()
	await get_tree().process_frame
	if chosen[0] != &"" or main.level != null:
		return _fail("un niveau pas encore construit s'est ouvert")
	map.select_level(&"les_allees")
	map.enter_selected()
	await get_tree().process_frame
	if chosen[0] != &"les_allees" or main.level == null or main.world_map != null:
		return _fail("le niveau choisi sur la carte ne s'est pas ouvert")
	print("test 12 réussi : la carte ouvre le niveau choisi, refuse celui qui n'existe pas")

	# Abandon depuis le carnet : retour à la carte.
	var level := _level()
	level.open_book()
	level.book.leave_requested.emit()
	await get_tree().process_frame
	if main.level != null or main.world_map == null or get_tree().paused:
		return _fail("quitter le niveau depuis le carnet ne ramène pas à la carte")
	print("test 12 réussi : quitter le niveau ramène à la carte")

	# Le moulin se choisit comme un niveau.
	map = main.world_map
	map.select_refuge()
	if map.selected_id() != &"refuge":
		return _fail("le moulin ne se choisit pas sur la carte")
	map.enter_selected()
	await get_tree().process_frame
	if main.level == null or main.level.title != "Le moulin":
		return _fail("le moulin ne s'ouvre pas depuis la carte")
	print("test 12 réussi : le moulin s'ouvre depuis la carte")
	return true


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Le moulin : la boutique, les conversations, les rites, l'entrée et la sortie.
func _refuge_tests() -> bool:
	# --- La boutique, sans l'écran.
	Progress.reset()
	Progress.add_gold(40)
	if Progress.shop_blocker(&"gambison") != "or" or Progress.buy(&"gambison"):
		return _fail("on peut acheter sans avoir assez d'or")
	if Progress.shop_blocker(&"cotte") != "prerequis":
		return _fail("la cotte de mailles n'exige pas le gambison")
	Progress.add_gold(1000)
	if Progress.buy(&"cotte"):
		return _fail("on a acheté la cotte de mailles sans le gambison")
	var gold := Progress.gold
	if not Progress.buy(&"gambison") or Progress.gold != gold - 100:
		return _fail("l'achat du gambison n'a pas coûté 100 or")
	Progress.buy(&"lame")
	Progress.buy(&"bottes")
	Progress.buy(&"bandages")
	var stats := Progress.hero_stats()
	if int(stats["max_health"]) != 100 + 20:
		return _fail("le gambison n'ajoute pas 20 de vie (vie maximale %d)" % int(stats["max_health"]))
	if not is_equal_approx(float(stats["damage_scale"]), 1.10) or not is_equal_approx(float(stats["speed_scale"]), 1.08) \
			or int(stats["rest_heal"]) != 3:
		return _fail("les bonus de la boutique ne s'appliquent pas : %s" % [stats])
	Progress.buy(&"lame")
	if Progress.shop_blocker(&"lame") != "maitrise":
		return _fail("la lame a plus de deux rangs")
	Progress.save()
	var kept := Progress.purchases.duplicate()
	Progress.reset()
	Progress.load_save()
	if Progress.purchases != kept:
		return _fail("les achats ne sont pas relus de la sauvegarde")
	print("test 13 réussi : boutique (prérequis, manque d'or, bonus, sauvegarde)")

	# --- Les conversations : dans l'ordre, une seule fois chacune.
	Progress.reset()
	if RefugeTexts.next_conversation(&"anselme").get("id", &"") != &"anselme_1":
		return _fail("la première conversation d'Anselme n'est pas la première")
	Progress.hear(&"anselme_1")
	if not RefugeTexts.next_conversation(&"anselme").is_empty():
		return _fail("Anselme a une conversation avant que le joueur ait avancé")
	Progress.mark_completed(&"la_grille")
	if RefugeTexts.next_conversation(&"anselme").get("id", &"") != &"anselme_2":
		return _fail("Anselme ne réagit pas à la Grille terminée")
	if RefugeTexts.idle_line(&"maud", 0) == RefugeTexts.idle_line(&"maud", 1):
		return _fail("la phrase de repli de Maud ne change pas")
	print("test 13 réussi : conversations ouvertes par les niveaux, entendues une fois")

	# --- Dans le moulin.
	Progress.add_gold(500)
	main.load_level(&"refuge")
	var level := _level() as Refuge
	await _frames(4)
	var hero := level.hero
	if hero.interaction_label != "":
		return _fail("une interaction est proposée au départ (« %s »)" % hero.interaction_label)
	hero.global_position = Vector3(7.0, 0.0, -7.0)
	await _frames(3)
	if hero.interaction_label != "PARLER" or level.controls.rite_label != "PARLER":
		return _fail("le bouton ne propose pas PARLER près de Maud")
	level.talk_to_nearest()
	await _frames(2)
	if level.dialogue == null or not get_tree().paused:
		return _fail("la conversation n'a pas ouvert la boîte de dialogue")
	level.dialogue.close(&"shop")
	await _frames(2)
	if level.shop == null:
		return _fail("la boutique ne s'est pas ouverte")
	var before := Progress.gold
	if not level.shop.buy(&"gambison"):
		return _fail("l'achat depuis l'écran de la boutique a échoué")
	level.shop.close()
	await _frames(2)
	if Progress.gold != before - 100 or hero.max_health != int(Progress.hero_stats()["max_health"]):
		return _fail("l'achat n'a pas changé la vie du héros (%d)" % hero.max_health)
	if not Progress.has_heard(&"maud_1") or get_tree().paused:
		return _fail("la conversation n'est pas marquée entendue, ou le jeu reste en pause")
	print("test 13 réussi : on parle à Maud et on achète au moulin")

	# Les rites ne s'apprennent qu'auprès d'Anselme.
	level.open_book()
	if level.book.can_learn:
		return _fail("le carnet ordinaire propose d'apprendre des rites")
	level.book.close_book()
	hero.global_position = Vector3(-7.4, 0.0, -7.4)
	await _frames(3)
	if hero.interaction_label != "PARLER":
		return _fail("le bouton ne propose pas PARLER près d'Anselme")
	level.talk_to_nearest()
	await _frames(2)
	level.dialogue.close(&"skills")
	await _frames(2)
	if level.book == null or not level.book.can_learn:
		return _fail("chez Anselme, le carnet ne propose pas d'apprendre")
	level.book.close_book()
	await _frames(2)
	print("test 13 réussi : les rites s'apprennent seulement chez Anselme")

	# La route, au sud, ramène à la carte.
	hero.global_position = Vector3(0.0, 0.0, 9.5)
	await _frames(3)
	if hero.interaction_label != "PARTIR":
		return _fail("le bouton ne propose pas PARTIR sur la route")
	hero.interacted.emit()
	await _frames(2)
	if main.level != null or main.world_map == null:
		return _fail("la route ne ramène pas à la carte")
	print("test 13 réussi : la route du moulin ramène à la carte")
	return true


## L'écran-titre, la nouvelle partie, le texte d'ouverture.
func _menu_tests() -> bool:
	Progress.reset()
	main.show_title()
	await get_tree().process_frame
	var title: TitleScreen = main.title_screen
	if title == null:
		return _fail("l'écran-titre ne s'affiche pas")
	if title.has_continue():
		return _fail("« Continuer » est proposé sans partie")
	Progress.add_gold(10)
	title.refresh()
	if not title.has_continue():
		return _fail("« Continuer » n'est pas proposé avec une partie")
	title.press_new_game()
	if not title.is_confirming() or Progress.gold != 10:
		return _fail("« Nouvelle partie » n'a pas demandé confirmation, ou a effacé avant")
	title.confirm_new_game()
	await get_tree().process_frame
	if Progress.has_progress():
		return _fail("la nouvelle partie n'a pas remis la progression à zéro")
	if main.opening == null or main.title_screen != null:
		return _fail("le texte d'ouverture ne se lance pas après « Nouvelle partie »")
	main.opening.skip_all()
	await get_tree().process_frame
	if main.world_map == null or main.opening != null:
		return _fail("la carte n'apparaît pas après le texte d'ouverture")
	main.world_map.menu_requested.emit()
	await get_tree().process_frame
	if main.title_screen == null:
		return _fail("le bouton Menu de la carte ne ramène pas à l'écran-titre")
	Progress.add_gold(5)
	main.title_screen.refresh()
	main.title_screen.press_continue()
	await get_tree().process_frame
	if main.world_map == null or Progress.gold != 5:
		return _fail("« Continuer » ne reprend pas la partie")
	print("test 14 réussi : écran-titre, nouvelle partie confirmée, ouverture, menu, continuer")
	return true


func _watch(level: Level) -> void:
	level.checkpoint_reached.connect(func(index: int) -> void: _checkpoint = index)
	level.completed.connect(func() -> void: _completed = true)


## Attend que `condition` soit vraie. Renvoie faux si le délai (en temps de
## jeu) est dépassé ou, sauf avis contraire, si le héros meurt.
func _until(condition: Callable, timeout: float, stop_on_death := true) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if stop_on_death and _level().hero.is_dead():
			return false
		if condition.call():
			return true
	return false


func _fail(reason: String) -> bool:
	var level := _level()
	print("SELFTEST ÉCHEC — %s (vie du héros : %d)" % [reason, level.hero.health if level else -1])
	if level != null:
		print("  héros en %s, objectif %s, morts restants %d" % [
			level.hero.global_position.snapped(Vector3.ONE * 0.1), level.objective, level.enemies_left()])
		for enemy in level.enemies():
			print("  %s en %s, état %d, vie %d" % [enemy.type_id_name,
				enemy.global_position.snapped(Vector3.ONE * 0.1), enemy.state, enemy.health])
	get_tree().quit(1)
	return false


## Photographie la carte : le bas, un niveau choisi, le milieu, le haut, le carnet.
func _capture_map() -> void:
	Progress.mark_completed(&"la_grille")
	Progress.mark_completed(&"les_allees")
	Progress.add_memories(110)
	main.show_map()
	await get_tree().create_timer(0.6).timeout
	var map: WorldMap = main.world_map
	await _shoot("map_01_depart")
	map.select_level(&"l_ossuaire")
	await get_tree().create_timer(0.4).timeout
	await _shoot("map_02_choix")
	map.select_level(&"la_chapelle")
	await get_tree().create_timer(0.3).timeout
	await _shoot("map_03_ferme")
	for step in [[1700.0, "map_04_citadelle"], [1100.0, "map_05_cathedrale"], [400.0, "map_06_palais"]]:
		map.scroll_to(step[0], 0.5)
		await get_tree().create_timer(0.3).timeout
		await _shoot(step[1])
	map.scroll_to(2300.0)
	map.open_book()
	await get_tree().create_timer(0.4).timeout
	await _shoot("map_07_carnet")
	get_tree().quit(0)


## L'écran-titre, la demande de confirmation, le texte d'ouverture.
func _capture_title() -> void:
	Progress.mark_completed(&"la_grille")
	Progress.mark_completed(&"les_allees")
	Progress.add_memories(120)
	main.show_title()
	await get_tree().create_timer(0.6).timeout
	await _shoot("titre_01")
	main.title_screen.press_new_game()
	await get_tree().create_timer(0.4).timeout
	await _shoot("titre_02_confirmation")
	main.title_screen.confirm_new_game()
	await get_tree().create_timer(2.2).timeout
	await _shoot("titre_03_ouverture")
	get_tree().quit(0)


## Une visite du moulin : l'arrivée, chaque personnage, la boutique, le carnet.
func _capture_refuge() -> void:
	Progress.mark_completed(&"la_grille")
	Progress.mark_completed(&"les_allees")
	Progress.add_gold(700)
	Progress.add_memories(300)
	main.load_level(&"refuge")
	var level := _level() as Refuge
	await get_tree().create_timer(0.8).timeout
	await _shoot("refuge_01_arrivee")
	for stop in [[Vector3(0.0, 0.0, -6.5), "refuge_02_cour"], [Vector3(6.6, 0.0, -7.0), "refuge_03_maud"]]:
		level.objective = stop[0]
		await get_tree().create_timer(2.6).timeout
		await _shoot(stop[1])
	level.talk_to_nearest()
	await get_tree().create_timer(1.8).timeout
	await _shoot("refuge_04_dialogue")
	level.dialogue.close(&"shop")
	await get_tree().create_timer(0.5).timeout
	await _shoot("refuge_05_boutique")
	level.shop.close()
	level.objective = Vector3(-7.4, 0.0, -7.4)
	await get_tree().create_timer(4.0).timeout
	await _shoot("refuge_06_anselme")
	level.talk_to_nearest()
	await get_tree().create_timer(0.3).timeout
	level.dialogue.close(&"skills")
	await get_tree().create_timer(0.5).timeout
	await _shoot("refuge_07_rites")
	level.book.close_book()
	level.objective = Vector3(-2.6, 0.0, -10.4)
	await get_tree().create_timer(3.4).timeout
	await _shoot("refuge_08_tibert")
	get_tree().quit(0)


func _shoot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [capture_dir, file])


## Ouvre le carnet avec un point à dépenser, l'enregistre, puis le ferme.
func _capture_book() -> void:
	Progress.add_memories(Progression.threshold(Progress.hero_level + 1) - Progress.memories)
	_level().open_book()
	_level().book.learn(&"tranchant")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/carnet.png" % capture_dir)
	_level().book.close_book()


## Joue la Grille en enregistrant une image toutes les 1,3 seconde.
func _capture() -> void:
	if capture_map:
		await _capture_map()
		return
	if main.level_id == &"refuge":
		await _capture_refuge()
		return
	if main.level_id == &"title":
		await _capture_title()
		return
	main.load_level(main.level_id, start_checkpoint)
	_watch(_level())
	for shot in range(1, 31):
		await get_tree().create_timer(1.3).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%02d.png" % [capture_dir, shot])
		if shot == 3:
			await _capture_book()
		if _completed:
			break
	get_tree().quit(0)
