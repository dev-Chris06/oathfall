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
##  11. il termine le niveau.
## Avec `capture_dir`, il ne joue que la Grille et enregistre des images.

var main: Node
var capture_dir := ""
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

	var body := _nearest(&"bodies", hero) as Enemy if _allow_rest else null
	if body != null:
		var offset := body.body_position() - hero.global_position
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
	for enemy in level.enemies():
		var threat := false
		if enemy is ArcherEnemy and enemy.state == Enemy.State.SPECIAL:
			threat = enemy._state_time > float(enemy._type["aim_time"]) - 0.2 and not enemy._fired
		elif enemy is Burrower and enemy.state == Enemy.State.SPECIAL:
			threat = enemy._phase == Burrower.Phase.WARNING and enemy._state_time > 0.35
		elif enemy.state == Enemy.State.WINDUP and not enemy._struck:
			var close := enemy.global_position.distance_to(hero.global_position) < 2.6
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
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"hittable"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var score := hero.global_position.distance_to(enemy.global_position)
		if enemy is ArcherEnemy or enemy is BellRinger or enemy is Widow:
			score -= 7.0
		if score < best_score:
			best_score = score
			best = enemy
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
	if not await _grille_tests():
		return
	if not await _traverse(&"les_allees"):
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
	print("test réussi : %s terminé, niveau %d, %d oboles, %d chute(s)" % [
		_level().title, Progress.hero_level, Progress.gold, falls[0]])
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
