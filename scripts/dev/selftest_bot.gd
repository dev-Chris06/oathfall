class_name SelftestBot
extends Node
## Joueur automatique, pour vérifier le jeu sans intervention.
##
## Il joue comme un joueur simple : il court vers le mort le plus proche, le
## frappe, puis donne le Repos aux corps. Le scénario vérifie trois choses :
##   1. une vague de deux Dépouilles peut être abattue et mise au repos ;
##   2. un corps laissé sans Repos se relève ;
##   3. le mort relevé peut à son tour être abattu et mis au repos ;
##   4. un mort frappe bien un héros qui ne bouge pas.
## Avec `capture_dir`, il enregistre aussi des images à intervalles réguliers.

var main: Node
var capture_dir := ""

var _allow_rest := true
var _passive := false
var _attack_timer := 0.0
var _rose := false
var _shots := 0


func _ready() -> void:
	_run()
	if not capture_dir.is_empty():
		_capture_loop()


func _physics_process(delta: float) -> void:
	var hero: Hero = main.hero
	var controls: TouchControls = main.controls
	controls.simulated_move = Vector2.ZERO
	controls.simulated_rite = false
	if hero.is_dead() or _passive:
		return

	var target := _nearest(&"hittable", hero)
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
		return

	if not _allow_rest:
		return
	var body := _nearest(&"bodies", hero) as Enemy
	if body != null:
		var offset := body.body_position() - hero.global_position
		if offset.length() > 1.4:
			controls.simulated_move = Vector2(offset.x, offset.z).normalized()
		else:
			controls.simulated_rite = true


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
	await get_tree().create_timer(0.5).timeout
	var hero: Hero = main.hero

	# 1. Une vague de deux morts, abattus puis mis au repos.
	main.spawn_wave(2)
	if not await _until(func() -> bool: return main.enemies_left() == 0, 90.0):
		_fail("la vague de deux morts n'a pas été mise au repos")
		return
	print("test 1 réussi : deux morts abattus et mis au repos, vie du héros %d" % hero.health)

	# 2. Un corps laissé sans Repos doit se relever.
	_allow_rest = false
	main.spawn_wave(1, 1.5)
	var enemy: Enemy = main.enemies()[0]
	enemy.rose.connect(func(_e: Enemy) -> void: _rose = true)
	if not await _until(func() -> bool: return _rose, 60.0):
		_fail("le mort laissé sans Repos ne s'est pas relevé")
		return
	print("test 2 réussi : le mort s'est relevé, avec %d points de vie" % enemy.health)

	# 3. Le mort relevé est abattu de nouveau, puis mis au repos.
	enemy.rise_delay = 20.0
	_allow_rest = true
	if not await _until(func() -> bool: return main.enemies_left() == 0, 90.0):
		_fail("le mort relevé n'a pas été mis au repos")
		return
	print("test 3 réussi : le mort relevé repose")

	# 4. Un héros immobile doit être frappé, et l'esquive doit le protéger.
	_passive = true
	main.spawn_wave(1)
	if not await _until(func() -> bool: return hero.health < hero.max_health, 30.0):
		_fail("le mort n'a pas réussi à frapper un héros immobile")
		return
	print("test 4 réussi : le héros immobile a été frappé, vie %d" % hero.health)
	_passive = false
	if not await _until(func() -> bool: return main.enemies_left() == 0, 90.0):
		_fail("le dernier mort n'a pas été mis au repos")
		return

	print("SELFTEST OK — vie du héros à la fin : %d sur %d" % [hero.health, hero.max_health])
	get_tree().quit(0)


## Attend que `condition` soit vraie. Renvoie faux si le délai (en temps de
## jeu) est dépassé ou si le héros meurt.
func _until(condition: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if main.hero.is_dead():
			return false
		if condition.call():
			return true
	return false


func _fail(reason: String) -> void:
	print("SELFTEST ÉCHEC — %s (vie du héros : %d)" % [reason, main.hero.health])
	get_tree().quit(1)


func _capture_loop() -> void:
	while _shots < 12:
		await get_tree().create_timer(1.3).timeout
		await RenderingServer.frame_post_draw
		_shots += 1
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%02d.png" % [capture_dir, _shots])
