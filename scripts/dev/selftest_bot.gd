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
## Avec `--selftest --only=<niveau>` : ne traverse que ce niveau (mise au point).
var only_level: StringName = &""
var _drinks := 0
var start_checkpoint := 0

var _allow_rest := true
var _passive := false
## Maintient REPOS pendant un essai passif (le Repos d'un Noyé).
var _hold_rite := false
var _attack_timer := 0.0
var _rose := false
var _checkpoint := 0
var _completed := false
var _victory_seen := false
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
	controls.simulated_rite = _hold_rite
	if hero.is_dead() or _passive:
		return
	_dodge_if_needed(level, hero, controls)
	# Agrippé par un Noyé : on esquive vers l'intérieur si on peut, sinon on le frappe.
	if hero.is_held():
		var away := hero.global_position - hero.held_by.global_position
		controls.simulated_move = Vector2(away.x, away.z).normalized()
		if hero._dodge_cooldown <= 0.0:
			controls.press_dodge()
		else:
			controls.simulated_move = -Vector2(away.x, away.z).normalized() * 0.25
			controls.press_attack()
		return
	if _levy_step(level, hero, controls):
		return
	_drink_if_needed(level, hero, controls)
	if _use_rite(level, hero, controls, delta):
		return

	# Un Noyé tombé tout près : on lui donne le Repos avant qu'il ne glisse à
	# l'eau, même en plein combat.
	if _allow_rest:
		for node in get_tree().get_nodes_in_group(&"bodies"):
			var drowned := node as DrownedEnemy
			if drowned == null or not drowned.is_down() or drowned.distance_to_body(hero.global_position) > 4.0:
				continue
			var to_body := drowned.body_position() - hero.global_position
			if Vector2(to_body.x, to_body.z).length() > 1.4:
				controls.simulated_move = Vector2(to_body.x, to_body.z).normalized()
			else:
				controls.simulated_rite = true
			return

	var target := _choose_target(hero)
	if target != null:
		var offset := target.global_position - hero.global_position
		var direction := Vector2(offset.x, offset.z).normalized()
		var striking := target is Enemy and bool((target as Enemy)._type.get("armor", false)) \
				and (target as Enemy).state == Enemy.State.WINDUP and not (target as Enemy)._struck
		if offset.length() > 2.1:
			controls.simulated_move = direction
		elif striking:
			# Un mort à armure arme son coup : on recule et on attend qu'il ait fini,
			# au lieu d'échanger les coups.
			controls.simulated_move = -direction
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
		if enemy is ButcherEnemy and enemy._phase == ButcherEnemy.Phase.CHARGE \
				and enemy.global_position.distance_to(hero.global_position) < 4.0:
			var charge_side := Vector2(enemy._charge_direction.x, enemy._charge_direction.z).orthogonal()
			controls.simulated_move = charge_side
			controls.press_dodge()
			return
		if enemy is ArcherEnemy and enemy.state == Enemy.State.SPECIAL:
			threat = enemy._state_time > float(enemy._type["aim_time"]) - 0.2 and not enemy._fired
		elif enemy is DrownedEnemy and enemy.is_reaching():
			# L'Étreinte annoncée : comme un coup, une fois sur quatre il se laisse prendre.
			threat = enemy._state_time > enemy._grab_windup - 0.25 and enemy.spawn_index % 4 != 0 \
				and enemy.global_position.distance_to(hero.global_position) < 2.8
		elif enemy is GaffeurEnemy and enemy.state == Enemy.State.SPECIAL:
			threat = enemy._state_time > float(enemy._type["hook_windup"]) - 0.2 and not enemy._thrown
		elif enemy is Burrower and enemy.state == Enemy.State.SPECIAL:
			threat = enemy._phase == Burrower.Phase.WARNING and enemy._state_time > 0.35
		elif enemy is SonneurEnemy and enemy.is_quaking():
			# L'onde du Sonneur : on esquive quand son front arrive.
			var gap := absf(enemy.wave_radius() - enemy.global_position.distance_to(hero.global_position))
			threat = gap < 2.4
		elif enemy is PrevotEnemy:
			# Son coup est annoncé : on esquive. La levée, elle, s'évite en
			# rejoignant le cercle (voir `_levy_step`).
			threat = enemy.state == Enemy.State.WINDUP and not enemy._struck \
				and enemy.global_position.distance_to(hero.global_position) < float(enemy._type["attack_range"]) + 0.5 \
				and enemy._state_time > float(enemy._type["attack_windup"]) - 0.25
		elif enemy is PeseurEnemy:
			# Ses poids sont annoncés au sol : on s'écarte juste avant qu'ils ne
			# tombent ; son coup, comme celui des autres.
			for weight: Dictionary in enemy._weights:
				var at: Vector3 = weight["at"]
				var gap := Vector2(at.x - hero.global_position.x, at.z - hero.global_position.z).length()
				if float(weight["time"]) > float(enemy._type["weight_windup"]) - 0.35 and gap < float(enemy._type["weight_radius"]) + 0.8:
					var out := Vector2(hero.global_position.x - at.x, hero.global_position.z - at.z).normalized()
					controls.simulated_move = out
					controls.press_dodge()
					return
			threat = enemy.state == Enemy.State.WINDUP and not enemy._struck \
				and enemy.global_position.distance_to(hero.global_position) < float(enemy._type["attack_range"]) + 0.5 \
				and enemy._state_time > float(enemy._type["attack_windup"]) - 0.25
		elif enemy is FossoyeuseEnemy:
			# Ses gestes sont annoncés : on esquive juste avant qu'ils ne portent.
			threat = enemy.danger_time(hero.global_position) < 0.3
		elif enemy.state == Enemy.State.WINDUP and not enemy._struck:
			var close := enemy.global_position.distance_to(hero.global_position) < maxf(2.6, float(enemy._type["attack_range"]) + 0.4)
			threat = close and enemy._state_time > float(enemy._type["attack_windup"]) - 0.25 \
				and (enemy.spawn_index % 4 != 0 or bool(enemy._type.get("armor", false)))
		if threat:
			var away := hero.global_position - enemy.global_position
			var side := Vector2(away.x, away.z).normalized().orthogonal()
			controls.simulated_move = side
			controls.press_dodge()
			return


## Les rites lancés par le joueur automatique, par rite (bilan des essais).
var rites_cast := {}
var _rite_wait := 0.0


## Lance un rite de combat quand la situation s'y prête : encerclé (Glas,
## Linceul, Cortège), un groupe au loin (Tombée), une cible précise ou à
## armure (Requiem, Litanie), un archer (Absoute), des corps qui vont se
## relever près d'une cloche ou d'un boss (Cierge). Renvoie vrai s'il en lance un.
func _use_rite(level: Level, hero: Hero, controls: TouchControls, delta: float) -> bool:
	_rite_wait -= delta
	if _rite_wait > 0.0 or (hero.state != Hero.State.MOVE and hero.state != Hero.State.ATTACK):
		return false
	_rite_wait = 0.5
	var near := 0
	var far := 0
	var precise := false
	var armored := false
	var archer := false
	var boss := false
	for enemy in level.enemies():
		if not enemy.is_standing():
			continue
		var distance := enemy.global_position.distance_to(hero.global_position)
		if distance < 4.2:
			near += 1
		elif distance < 9.0:
			far += 1
		if distance < 3.0 and (enemy is CrierEnemy or enemy is Widow or enemy is BellRinger):
			precise = true
		if distance < 3.0 and (bool(enemy._type.get("armor", false)) or enemy.is_boss()):
			armored = true
		if enemy is ArcherEnemy and distance < 13.0:
			archer = true
		if enemy.is_boss():
			boss = true
	var bodies := get_tree().get_nodes_in_group(&"bodies").size()
	var want := {
		&"glas": near >= 3, &"linceul": near >= 2, &"cortege": near >= 3, &"tombee": far >= 3,
		&"requiem": armored, &"litanie": precise, &"absoute": archer and near == 0,
		&"cierge": bodies >= 2 and boss and get_tree().get_nodes_in_group(&"candles").is_empty(),
		&"rappel": near >= 2,
	}
	for slot in hero.rite_slots.size():
		var rite_id := hero.rite_slots[slot]
		if rite_id != &"" and want.get(rite_id, false) and hero.embers >= RiteData.cost(rite_id):
			controls.press_slot(slot)
			if hero.state == Hero.State.CAST:
				rites_cast[rite_id] = int(rites_cast.get(rite_id, 0)) + 1
				return true
	return false


## Un joueur boit une fiole quand sa vie est basse et qu'aucun coup n'est armé
## tout près de lui (boire laisse sans défense 0,85 s).
func _drink_if_needed(level: Level, hero: Hero, controls: TouchControls) -> void:
	if hero.flasks <= 0 or hero.health * 100 > hero.max_health * 45 or hero.state != Hero.State.MOVE:
		return
	for enemy in level.enemies():
		if enemy.is_standing() and enemy.state == Enemy.State.WINDUP \
				and enemy.global_position.distance_to(hero.global_position) < 4.0:
			return
	_drinks += 1
	controls.flask_pressed.emit()


## La levée du Prévôt : le joueur rejoint le cercle d'or et s'y tient jusqu'au
## coup. Renvoie vrai quand il s'en occupe.
func _levy_step(level: Level, hero: Hero, controls: TouchControls) -> bool:
	for enemy in level.enemies():
		if enemy is PrevotEnemy and enemy.levy_pending:
			var offset: Vector3 = enemy.levy_center - hero.global_position
			offset.y = 0.0
			if offset.length() > enemy.safe_radius() - 0.7:
				controls.simulated_move = Vector2(offset.x, offset.z).normalized()
				return true
			return enemy.levy_time_left() < 2.2
	return false


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
		if enemy is ArcherEnemy or enemy is BellRinger or enemy is Widow or enemy is CrierEnemy:
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
	if only_level != &"":
		# Le héros arrive comme dans la traversée complète : les niveaux
		# d'avant sont faits (rites ouverts) et il a gagné leurs souvenirs.
		var index := WorldData.level_index(only_level)
		for i in maxi(index, 0):
			Progress.mark_completed(WorldData.level_at(i)["id"])
		var hero_level := clampi(2 + index, 1, 12)
		Progress.add_memories(maxi(Progression.threshold(hero_level) - Progress.memories, 0))
		var result := await _traverse(only_level)
		print("ESSAI SEUL %s : %s (fioles bues : %d, restantes : %d)" % [only_level, "réussi" if result else "échec", _drinks, Progress.flasks])
		get_tree().quit(0 if result else 1)
		return
	if not await _arena_tests():
		return
	if not await _progress_tests():
		return
	if not await _gear_effect_tests():
		return
	if not await _supplies_tests():
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
	if not await _crier_tests():
		return
	if not await _butcher_tests():
		return
	if not await _harbor_tests():
		return
	if not await _peseur_tests():
		return
	if not await _prevot_tests():
		return
	if not await _rite_tests():
		return
	if not await _trigger_tests():
		return
	if not await _reach_tests():
		return
	if not await _visible_walls_tests():
		return
	if not await _pause_tests():
		return
	if not await _camera_tests():
		return
	if not await _peace_hint_tests():
		return
	if not await _stone_tests():
		return
	for type_id: StringName in EnemyTypes.TYPES:
		if not Progress.has_met(type_id):
			return _fail("%s a été vu mais n'est pas au bestiaire" % type_id)
		if not ResourceLoader.exists(BestiaryScreen.PORTRAITS + "%s.png" % type_id):
			return _fail("le portrait de %s manque" % type_id)
		if not EnemyTypes.get_type(type_id).has("bestiary"):
			return _fail("la fiche de %s manque" % type_id)
	for type_id: StringName in EnemyTypes.TYPES:
		if not BestiaryScreen.ORDER.has(type_id):
			return _fail("%s n'est pas dans la liste du bestiaire" % type_id)
	if BestiaryScreen.ORDER.size() != EnemyTypes.TYPES.size():
		return _fail("la liste du bestiaire ne correspond pas aux types déclarés")
	print("test réussi : les %d types de morts ont leur fiche et leur portrait, et sont au bestiaire" % EnemyTypes.TYPES.size())
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
	if not await _traverse(&"la_porte_des_halles"):
		return
	if not await _traverse(&"les_etals"):
		return
	if not await _traverse(&"la_balance"):
		return
	if not await _traverse(&"les_caves"):
		return
	if not await _traverse(&"la_halle_du_prevot"):
		return
	if not await _traverse(&"le_quai_des_fuyards"):
		return
	if not await _traverse(&"les_barges"):
		return
	if not await _map_tests():
		return
	if not await _map_life_tests():
		return
	if not await _refuge_tests():
		return
	if not await _training_tests():
		return
	if not await _menu_tests():
		return
	if not _audio_tests():
		return
	print("SELFTEST OK")
	get_tree().quit(0)


## Tous les sons déclarés existent, ceux que le test a provoqués ont été joués,
## et les volumes se gardent.
func _audio_tests() -> bool:
	for id: StringName in Audio.EVENTS:
		var event: Dictionary = Audio.EVENTS[id]
		for file: String in event["files"]:
			var path: String = (Audio.KEN if event.get("kenney", false) else Audio.SFX) + file + ".ogg"
			if not ResourceLoader.exists(path):
				return _fail("le son %s manque : %s" % [id, path])
	for id: StringName in Audio.TRACKS:
		var path: String = Audio.MUSIC + String(Audio.TRACKS[id]["file"]) + ".ogg"
		if not ResourceLoader.exists(path):
			return _fail("la musique %s manque : %s" % [id, path])
	# Un bouton du thème joue son clic.
	var probe := Button.new()
	Theatre.pill(probe, 20)
	probe.pressed.emit()
	probe.free()
	var expected: Array[StringName] = [&"step", &"swing_light", &"swing_heavy", &"hit_flesh", &"hit_heavy",
		&"dodge", &"hurt", &"rest_done", &"enemy_fall", &"enemy_rise", &"drink", &"heal", &"twang",
		&"bell_toll", &"bell_small", &"bell_crash", &"rope_snap", &"quake", &"scream", &"dig",
		&"level_done", &"gate", &"coins", &"book_open", &"book_close", &"ui_click",
		&"music:title", &"music:map", &"music:cemetery", &"music:underground", &"music:boss", &"music:refuge"]
	for id in expected:
		if int(Audio.heard.get(id, 0)) == 0:
			return _fail("le son %s n'a jamais été joué pendant le test" % id)
	Audio.set_music_volume(0.35)
	Audio.set_sfx_volume(0.0)
	Audio.save_settings()
	Audio.set_music_volume(0.9)
	Audio.set_sfx_volume(0.9)
	Audio.load_settings()
	if absf(Audio.music_volume - 0.35) > 0.001 or Audio.sfx_volume != 0.0:
		return _fail("les volumes n'ont pas été relus (%.2f, %.2f)" % [Audio.music_volume, Audio.sfx_volume])
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index("Sons")):
		return _fail("le volume nul ne coupe pas le bus des sons")
	Audio.set_music_volume(0.7)
	Audio.set_sfx_volume(0.9)
	print("test réussi : sons et musiques présents, joués aux bons moments, volumes gardés")
	return true


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
	for id: StringName in [&"depouille", &"porte_cloche", &"fouisseur", &"archer_creux", &"boucher", &"noye", &"gaffeur"]:
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


## Les effets de l'équipement : garde à genoux, pointes, vitesse des coups.
func _gear_effect_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	_passive = true
	hero.heal(1000)

	# La garde ne joue qu'à genoux (Repos, corde).
	hero.guard = 0.5
	hero.state = Hero.State.MOVE
	var before := hero.health
	hero.take_damage(20, hero.global_position + Vector3.FORWARD)
	if before - hero.health != 20:
		return _fail("la garde réduit des dégâts reçus debout (%d)" % (before - hero.health))
	hero.state = Hero.State.RITE
	before = hero.health
	hero.take_damage(20, hero.global_position + Vector3.FORWARD)
	hero.state = Hero.State.MOVE
	if before - hero.health != 10:
		return _fail("la garde de 50 %% n'a pas réduit 20 dégâts à 10 (%d)" % (before - hero.health))
	hero.guard = 0.0
	print("test réussi : la garde réduit les dégâts reçus à genoux")

	# Les pointes blessent celui qui frappe de près.
	hero.heal(1000)
	hero.thorns = 8
	var attacker := arena.spawn(&"depouille", hero.global_position + Vector3(1.4, 0.0, 0.0), false)
	var health := attacker.health
	hero.take_damage(5, attacker.global_position, attacker)
	hero.thorns = 0
	if health - attacker.health != 8:
		return _fail("les pointes n'ont pas rendu 8 dégâts (%d)" % (health - attacker.health))
	attacker.take_hit(hero.global_position, 100000)
	print("test réussi : les pointes blessent celui qui frappe de près")

	# La hache ralentit les coups.
	hero.attack_speed_scale = 1.0
	hero.state = Hero.State.MOVE
	hero._start_attack(0)
	var fast: float = hero._attack_duration
	hero.state = Hero.State.MOVE
	hero.attack_speed_scale = 0.8
	hero._start_attack(0)
	var slow: float = hero._attack_duration
	hero.attack_speed_scale = 1.0
	hero.state = Hero.State.MOVE
	if absf(slow / fast - 1.25) > 0.02:
		return _fail("une vitesse de coups de 0,8 n'allonge pas le coup de 25 %% (%.2f)" % (slow / fast))
	print("test réussi : la vitesse des coups suit l'équipement")
	_passive = false
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 120.0):
		return _fail("le mort de l'essai des pointes n'a pas été mis au repos")
	return true


## Fioles et vivres : achats, boire (soin, interruption), ceinture, repas.
func _supplies_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	var saved_gold := Progress.gold
	var saved_flasks := Progress.flasks
	Progress.flasks = 0
	Progress.gold = 500
	for i in 3:
		if not Progress.buy_flask():
			return _fail("la fiole %d n'a pas pu être achetée" % (i + 1))
	if Progress.buy_flask() or Progress.flask_blocker() != "pleines":
		return _fail("on peut porter plus de 3 fioles")
	if Progress.gold != 500 - 3 * int(Supplies.FLASK["cost"]):
		return _fail("les fioles n'ont pas coûté leur prix (or %d)" % Progress.gold)
	print("test réussi : on achète jusqu'à 3 fioles")

	# Les fioles se voient à la ceinture.
	await _frames(3)
	var belt := hero._model.find_child("FlaskBelt", true, false)
	var shown := 0
	if belt != null:
		for bottle in belt.get_children():
			if (bottle as Node3D).visible:
				shown += 1
	if shown != 3:
		return _fail("%d fioles visibles à la ceinture au lieu de 3" % shown)

	# Boire : un instant sans défense, puis la vie revient et la fiole disparaît.
	_passive = true
	var max_life := hero.max_health
	hero.health = 30
	hero.health_changed.emit(30, max_life)
	arena.controls.flask_pressed.emit()
	if hero.state != Hero.State.DRINK:
		return _fail("le héros ne boit pas quand on touche FIOLE")
	await _frames(70)
	if Progress.flasks != 2 or hero.health != 30 + int(Supplies.FLASK["heal"]):
		return _fail("boire n'a pas soigné de %d ni retiré une fiole (vie %d, fioles %d)" % [int(Supplies.FLASK["heal"]), hero.health, Progress.flasks])
	var left := hero._model.find_child("FlaskBelt", true, false)
	await _frames(2)
	var after := 0
	for bottle in left.get_children():
		if (bottle as Node3D).visible:
			after += 1
	if after != 2:
		return _fail("la ceinture montre %d fioles après en avoir bu une" % after)
	print("test réussi : boire une fiole soigne, en retire une, et la ceinture suit")

	# Un coup pendant qu'on boit annule : la fiole est gardée.
	hero.health = 30
	arena.controls.flask_pressed.emit()
	hero.take_damage(5, hero.global_position + Vector3.FORWARD)
	await _frames(70)
	if Progress.flasks != 2 or hero.health > 30:
		return _fail("un coup n'a pas annulé la fiole (fioles %d, vie %d)" % [Progress.flasks, hero.health])
	# Une esquive aussi.
	hero.health = 30
	hero.state = Hero.State.MOVE
	hero._dodge_cooldown = 0.0
	arena.controls.flask_pressed.emit()
	arena.controls.press_dodge()
	await _frames(70)
	if Progress.flasks != 2 or hero.health != 30:
		return _fail("une esquive n'a pas annulé la fiole (fioles %d, vie %d)" % [Progress.flasks, hero.health])
	# Et on ne boit pas à pleine vie.
	hero.heal(1000)
	arena.controls.flask_pressed.emit()
	if hero.state == Hero.State.DRINK:
		return _fail("le héros boit alors qu'il est en pleine forme")
	print("test réussi : un coup ou une esquive annule la fiole, pas de fiole à pleine vie")

	# Armure d'élan : hors Repos, corde et fiole, un coup blesse sans arrêter.
	hero.heal(1000)
	hero.state = Hero.State.MOVE
	arena.controls.attack_pressed.emit()
	if hero.state != Hero.State.ATTACK:
		return _fail("le héros ne frappe pas pour l'essai de l'élan")
	var life_before := hero.health
	hero.take_damage(5, hero.global_position + Vector3.FORWARD)
	if hero.state != Hero.State.ATTACK or hero.health != life_before - 5:
		return _fail("un coup reçu a interrompu le coup du héros (état %d)" % hero.state)
	await _frames(60)
	hero.state = Hero.State.MOVE
	hero.take_damage(5, hero.global_position + Vector3.FORWARD)
	if hero.state != Hero.State.MOVE:
		return _fail("un coup reçu arrête le héros qui court")
	print("test réussi : le héros garde son élan sous les coups")

	# Point de reprise : au moins 60 % de la vie revient, jamais moins.
	hero.health = 10
	arena.mark_checkpoint(0)
	var floor_health := int(ceil(float(hero.max_health) * Supplies.CHECKPOINT_HEALTH))
	if hero.health != floor_health:
		return _fail("le point de reprise rend %d de vie au lieu de remonter à %d" % [hero.health, floor_health])
	hero.health = hero.max_health - 1
	arena.mark_checkpoint(0)
	if hero.health != hero.max_health - 1:
		return _fail("le point de reprise a soigné un héros déjà vaillant")
	print("test réussi : le point de reprise rend au moins 60 % de la vie")

	# Fiole tombée d'un corps : ramassée en passant, laissée si on est plein.
	Progress.flasks = 1
	var pickup := arena.drop_flask(hero.global_position + Vector3(4.0, 0.0, 0.0))
	await _frames(3)
	if Progress.flasks != 1:
		return _fail("une fiole lointaine a été ramassée")
	hero.global_position = pickup.global_position
	await _frames(3)
	if Progress.flasks != 2 or is_instance_valid(pickup):
		return _fail("la fiole tombée n'a pas été ramassée (fioles %d)" % Progress.flasks)
	Progress.flasks = 3
	var spare := arena.drop_flask(hero.global_position)
	await _frames(3)
	if Progress.flasks != 3 or not is_instance_valid(spare):
		return _fail("une fiole a été ramassée au-delà de 3")
	spare.queue_free()
	Progress.flasks = 2
	print("test réussi : une fiole tombée se ramasse, jamais au-delà de 3")

	# Une partie neuve commence avec deux fioles.
	Progress.save()
	var kept_save := FileAccess.get_file_as_string(Progress.save_path)
	Progress.new_game()
	if Progress.flasks != Supplies.START_FLASKS or not Progress.has_progress():
		return _fail("une partie neuve commence avec %d fioles" % Progress.flasks)
	var restore := FileAccess.open(Progress.save_path, FileAccess.WRITE)
	restore.store_string(kept_save)
	restore.close()
	Progress.load_save()
	print("test réussi : une partie neuve commence avec %d fioles" % Supplies.START_FLASKS)

	# Les repas : un seul à la fois, valables pour le niveau.
	Progress.gold = 200
	Progress.packed_meal = &""
	Progress.active_meal = &""
	if not Progress.pack_meal(&"ragout") or Progress.gold != 200 - 60:
		return _fail("le ragoût n'a pas pu être emballé pour 60 or")
	if Progress.pack_meal(&"pain") or Progress.meal_blocker(&"pain") != "deja":
		return _fail("on peut emballer deux repas à la fois")
	var base := Progress.hero_stats()
	Progress.start_level_meal()
	var fed := Progress.hero_stats()
	if Progress.packed_meal != &"" or Progress.active_meal != &"ragout":
		return _fail("le repas emballé n'est pas devenu le repas du niveau")
	if int(fed["max_health"]) != int(base["max_health"]) + 30 or int(fed["rest_heal"]) != int(base["rest_heal"]) + 3:
		return _fail("le ragoût ne donne pas +30 de vie et +3 par Repos")
	Progress.end_level_meal()
	if int(Progress.hero_stats()["max_health"]) != int(base["max_health"]):
		return _fail("le repas ne disparaît pas à la fin du niveau")
	for id: StringName in Supplies.MEALS:
		if not ResourceLoader.exists(ShopScreen.ICONS + "%s.png" % Supplies.MEALS[id]["icon"]):
			return _fail("l'icône de %s manque" % id)
	if not ResourceLoader.exists(ShopScreen.ICONS + "%s.png" % Supplies.FLASK["icon"]):
		return _fail("l'icône de la fiole manque")
	print("test réussi : un repas à la fois, valable pour le niveau, avec ses effets")

	# La sauvegarde garde fioles et sac.
	Progress.pack_meal(&"fromage")
	Progress.save()
	var kept_flasks := Progress.flasks
	Progress.flasks = 0
	Progress.packed_meal = &""
	Progress.load_save()
	if Progress.flasks != kept_flasks or Progress.packed_meal != &"fromage":
		return _fail("fioles ou repas emballé non relus de la sauvegarde")
	Progress.packed_meal = &""
	Progress.gold = saved_gold
	Progress.flasks = saved_flasks
	Progress.changed.emit()
	_passive = false
	return true


func _grille_tests() -> bool:
	main.load_level(&"la_grille")
	_watch(_level())

	# Le Repos reste caché jusqu'à ce que le premier mort se soit relevé.
	var intro := _level() as LaGrille
	var leaked := [false]
	var hidden := await _until(func() -> bool:
		return not intro.hero.rite_enabled, 120.0)
	if not hidden:
		return _fail("le bouton REPOS n'est pas caché au début de la Grille")
	var learned := await _until(func() -> bool:
		if intro.hero.rite_enabled:
			return true
		if intro.controls.rite_available:
			leaked[0] = true
		return false, 120.0)
	if leaked[0]:
		return _fail("le bouton REPOS est apparu avant que le mort se relève")
	if not learned or not intro._first_rose:
		return _fail("le Repos n'a pas été enseigné après le relèvement du premier mort")
	print("test réussi : le Repos n'apparaît qu'après avoir vu un mort se relever")

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
	if not _victory_seen:
		return _fail("la Grille se ferme sans bandeau de victoire")
	print("test 11 réussi : la Grille est terminée, vie %d, niveau %d, %d d'or, %d chute(s)" % [
		_level().hero.health, Progress.hero_level, Progress.gold, falls[0]])
	return true


## Les lignes de déclenchement : franchir la ligne suffit, même loin du point,
## et un héros resté en arrière ne déclenche rien.
func _trigger_tests() -> bool:
	var level := Level.new()
	main.add_child(level)
	await _frames(3)
	var target := Vector3(0.0, 0.0, -10.0)
	var state := {"done": false}
	var waiter := func() -> void:
		await level.reach(target, 2.0)
		state["done"] = true
	waiter.call()
	level.hero.global_position = Vector3(6.0, 0.0, -2.0)
	await _frames(10)
	if state["done"]:
		level.queue_free()
		return _fail("la zone s'est déclenchée alors que le héros était encore en arrière")
	if level.objective == null:
		level.queue_free()
		return _fail("l'objectif n'est pas posé pendant l'attente")
	# Le héros court sur le côté et dépasse la ligne sans passer près du point.
	level.hero.global_position = Vector3(7.0, 0.0, -12.0)
	await _frames(10)
	var triggered: bool = state["done"] and level.objective == null
	level.queue_free()
	if not triggered:
		return _fail("franchir la ligne loin du point n'a pas déclenché la suite")
	print("test réussi : une zone se déclenche dès que sa ligne est franchie")
	return true


## Aucun niveau ne laisse sortir le héros : depuis le départ, toutes les grilles
## ouvertes (sauf le portail du moulin), la zone qu'il peut atteindre reste
## celle du niveau. Une fuite (un coin non fermé, un passage entre deux murs)
## la ferait déborder sur le noir qui entoure le décor.
func _reach_tests() -> bool:
	# Le niveau des essais précédents est retiré : ses murs fausseraient la mesure.
	main._drop_level()
	await _frames(4)
	for id: StringName in [&"la_grille", &"les_allees", &"la_chapelle", &"l_ossuaire",
			&"la_fosse", &"la_porte_des_halles", &"les_etals", &"la_balance", &"les_caves", &"la_halle_du_prevot", &"le_quai_des_fuyards", &"les_barges", &"refuge",
			&"cour_d_armes"]:
		var level := main.LEVELS[id].new() as Level
		main.add_child(level)
		await _frames(4)
		if not id in main.CALM_PLACES:
			level.open_gates_before(99)
		await _frames(3)
		var zone := _reachable_zone(level)
		level.queue_free()
		await _frames(2)
		if zone["area"] > 2200.0 or zone["min_x"] < -22.0 or zone["max_x"] > 22.0 or zone["min_z"] < -110.0:
			return _fail("le héros sort du niveau %s : %.0f m² atteignables (x %.1f à %.1f, z %.1f à %.1f)" % [
				id, zone["area"], zone["min_x"], zone["max_x"], zone["min_z"], zone["max_z"]])
	print("test réussi : aucun niveau ne laisse sortir le héros")
	return true


## Tout obstacle se voit : un mur que le héros touche sans le voir est un
## défaut (jeu invisible). On échantillonne chaque obstacle le long de sa plus
## grande dimension, à hauteur de héros, et il faut un objet visible à moins de
## 0,35 pour plus de la moitié des points.
func _visible_walls_tests() -> bool:
	main._drop_level()
	await _frames(3)
	for id: StringName in [&"la_grille", &"les_allees", &"la_chapelle", &"l_ossuaire",
			&"la_fosse", &"la_porte_des_halles", &"les_etals", &"la_balance", &"les_caves", &"la_halle_du_prevot", &"le_quai_des_fuyards", &"les_barges", &"refuge",
			&"cour_d_armes"]:
		var level := main.LEVELS[id].new() as Level
		main.add_child(level)
		await _frames(3)
		var boxes := level.visible_boxes()
		for node in level._solids.get_children():
			var shape := node as CollisionShape3D
			if shape == null or not shape.shape is BoxShape3D:
				continue
			var size: Vector3 = (shape.shape as BoxShape3D).size
			var along := Vector3.RIGHT if size.x >= size.z else Vector3.BACK
			var length := maxf(size.x, size.z)
			var uncovered := 0
			var samples := 0
			var d := -length / 2.0 + 0.25
			while d <= length / 2.0 - 0.2:
				var p := shape.global_transform.origin + shape.global_transform.basis * (along * d)
				p.y = 0.5
				samples += 1
				var seen := false
				for box in boxes:
					if box.grow(0.35).has_point(p):
						seen = true
						break
				if not seen:
					uncovered += 1
				d += 0.5
			if samples > 0 and float(uncovered) / samples > 0.5:
				var at := shape.global_transform.origin
				level.queue_free()
				return _fail("mur invisible dans %s : obstacle en (%.1f, %.1f), %.1f x %.1f, %d %% sans objet visible" % [
					id, at.x, at.z, size.x, size.z, int(100.0 * uncovered / samples)])
		level.queue_free()
		await _frames(2)
	print("test réussi : tout obstacle de chaque niveau a un objet visible")
	return true


## Le menu de pause : le bouton l'ouvre, le jeu s'arrête, Reprendre le ferme,
## Quitter demande confirmation puis ramène à la carte.
func _pause_tests() -> bool:
	var level := main.LEVELS[&"la_grille"].new() as Level
	main.add_child(level)
	await _frames(4)
	var left := [false]
	level.quit_requested.connect(func() -> void: left[0] = true)
	level.controls.pause_pressed.emit()
	await _frames(2)
	if level.pause_menu == null or not get_tree().paused:
		level.queue_free()
		return _fail("le bouton pause n'ouvre pas le menu ou n'arrête pas le jeu")
	level.open_book()
	if level.book != null and is_instance_valid(level.book):
		level.queue_free()
		return _fail("le carnet s'ouvre par-dessus le menu de pause")
	level.pause_menu.close_menu()
	await _frames(2)
	if get_tree().paused:
		level.queue_free()
		return _fail("Reprendre ne relance pas le jeu")
	level.open_pause()
	await _frames(2)
	level.pause_menu._ask()
	if not level.pause_menu.is_asking() or left[0]:
		level.queue_free()
		return _fail("quitter ne demande pas de confirmation")
	level.pause_menu._cancel()
	if level.pause_menu.is_asking():
		level.queue_free()
		return _fail("Non ne referme pas la confirmation")
	level.pause_menu._ask()
	level.pause_menu.confirm_leave()
	await _frames(2)
	var ok: bool = left[0] and not get_tree().paused
	level.queue_free()
	await _frames(2)
	if not ok:
		return _fail("confirmer ne quitte pas le niveau")
	print("test réussi : le menu de pause ouvre, reprend et quitte après confirmation")
	return true


## Les trois vues de la caméra et le verrouillage : la vue choisie est gardée
## dans les réglages ; dans chaque vue, « haut » au joystick va droit devant la
## caméra ; la vue épaule tourne au doigt sans jamais passer derrière un mur ;
## à la première personne le modèle du héros est caché ; CIBLE verrouille le
## mort le plus en vue, les coups partent vers lui, et il est relâché quand il
## tombe.
func _camera_tests() -> bool:
	var saved_mode := GameCamera.mode
	GameCamera.mode = GameCamera.Mode.SHOULDER
	Audio.save_settings()
	GameCamera.mode = GameCamera.Mode.CLASSIC
	Audio.load_settings()
	if GameCamera.mode != GameCamera.Mode.SHOULDER:
		GameCamera.mode = saved_mode
		return _fail("la vue de la caméra n'est pas gardée dans les réglages")

	var level := main.LEVELS[&"la_grille"].new() as Level
	main.add_child(level)
	await _frames(4)
	var problem := ""
	var camera := level._camera
	var hero := level.hero
	for mode: int in [GameCamera.Mode.CLASSIC, GameCamera.Mode.SHOULDER, GameCamera.Mode.FIRST]:
		GameCamera.mode = mode as GameCamera.Mode
		for turn in 4:
			level.controls.simulate_look(Vector2(410.0, 0.0))
			await _frames(3)
			level.controls._stick_vector = Vector2(0.0, -1.0)
			await _frames(2)
			var forward := -camera.global_transform.basis.z
			forward = Vector3(forward.x, 0.0, forward.z).normalized()
			var wish := Vector3(level.controls.move.x, 0.0, level.controls.move.y)
			level.controls._stick_vector = Vector2.ZERO
			if wish.normalized().dot(forward) < 0.97:
				problem = "en vue %s, « haut » au joystick ne va pas devant la caméra" % GameCamera.mode_name(mode)
			if mode == GameCamera.Mode.SHOULDER:
				# Rien de solide entre la tête du héros et la caméra.
				var query := PhysicsRayQueryParameters3D.create(
					hero.global_position + Vector3(0.0, GameCamera.SHOULDER_HEIGHT, 0.0), camera.global_position)
				query.exclude = [hero.get_rid()]
				var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty() and not (hit["collider"] is CharacterBody3D):
					problem = "la vue épaule passe derrière un mur"
		var shadow_only := 0
		for node in hero._model.find_children("*", "GeometryInstance3D", true, false):
			if (node as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				shadow_only += 1
		if (mode == GameCamera.Mode.FIRST) != (shadow_only > 0):
			problem = "le modèle du héros est mal caché ou montré en vue %s" % GameCamera.mode_name(mode)
		if problem != "":
			break
	# Retour à la vue classique : la caméra reprend ses angles fixes.
	GameCamera.mode = GameCamera.Mode.CLASSIC
	await _frames(40)
	var offset := camera.global_position - hero.global_position
	if problem == "" and offset.distance_to(GameCamera.OFFSET) > 0.6:
		problem = "la vue classique ne revient pas à sa place (%s)" % offset

	# Verrouillage : le mort devant le héros plutôt que celui derrière.
	if problem == "":
		var ahead := level.spawn(&"depouille", hero.global_position + Vector3(-1.5, 0.0, -5.0), false)
		var behind := level.spawn(&"depouille", hero.global_position + Vector3(1.0, 0.0, 4.0), false)
		# Immobiles : ils ne doivent ni bouger ni frapper pendant l'essai.
		ahead.process_mode = Node.PROCESS_MODE_DISABLED
		behind.process_mode = Node.PROCESS_MODE_DISABLED
		hero.face(Vector3(0.0, 0.0, -1.0))
		level.controls.press_lock()
		await _frames(2)
		if hero.lock_target != ahead or not level.controls.lock_active:
			problem = "CIBLE ne verrouille pas le mort devant le héros"
		else:
			hero.face(Vector3(1.0, 0.0, 0.0))
			level.controls.press_attack()
			await _frames(2)
			var to := ahead.global_position - hero.global_position
			if hero.facing().dot(Vector3(to.x, 0.0, to.z).normalized()) < 0.95:
				problem = "le coup ne part pas vers le mort verrouillé"
			ahead.take_hit(hero.global_position, 999)
			await _frames(3)
			if hero.lock_target == ahead:
				problem = "le mort abattu reste verrouillé"
			elif hero.lock_target != behind:
				problem = "la cible ne passe pas au mort suivant quand la première tombe"
			level.controls.press_lock()
			await _frames(2)
			if problem == "" and (hero.lock_target != null or level.controls.lock_active):
				problem = "CIBLE ne relâche pas la cible"
	GameCamera.mode = saved_mode
	Audio.save_settings()
	level.queue_free()
	await _frames(2)
	if problem != "":
		return _fail(problem)
	print("test réussi : trois vues de caméra (joystick, murs, héros caché), réglage gardé, verrouillage")
	return true


## Un corps oublié n'arrête pas un niveau en silence : quand il ne reste que
## des corps au sol, le repère montre le plus proche, puis s'efface quand tous
## reposent.
func _peace_hint_tests() -> bool:
	main.load_level(&"arena")
	var arena := _level() as Arena
	await get_tree().create_timer(0.5).timeout
	_passive = true
	arena.spawn_wave(1, 60.0)
	var enemy: Enemy = arena.enemies()[0]
	await _frames(2)
	enemy.take_hit(enemy.global_position + Vector3(0.0, 0.0, 1.0), 999)
	var done := [false]
	var watch := func() -> void:
		await arena.until_peace()
		done[0] = true
	watch.call()
	await get_tree().create_timer(Level.BODY_HINT_DELAY + 1.0).timeout
	var problem := ""
	if not (arena.objective is Vector3) or (arena.objective as Vector3).distance_to(enemy.body_position()) > 0.5:
		problem = "le corps oublié n'est pas montré par le repère"
	enemy.give_rest()
	await get_tree().create_timer(0.3).timeout
	if problem == "" and (not done[0] or arena.objective != null):
		problem = "le repère reste après le dernier Repos"
	_passive = false
	_clear_arena(arena)
	await _frames(2)
	if problem != "":
		return _fail(problem)
	print("test réussi : un corps oublié est montré, la paix efface le repère")
	return true


## Les pierres du cercle de la Fosse arrêtent le passage, et la Fossoyeuse les
## arrache avec leur obstacle.
func _stone_tests() -> bool:
	var level := main.LEVELS[&"la_fosse"].new() as Level
	main.add_child(level)
	await _frames(4)
	var fosse := level as LaFosse
	var space := level.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.exclude = [level.hero.get_rid()]
	var blocked := func(at: Vector3) -> bool:
		query.transform = Transform3D(Basis(), Vector3(at.x, 0.9, at.z))
		return not space.intersect_shape(query, 1).is_empty()
	for stone: Node3D in fosse._stones:
		if not blocked.call(stone.global_position):
			level.queue_free()
			return _fail("une pierre du cercle de la Fosse se traverse (%s)" % stone.global_position)
	var first: Node3D = fosse._stones[0]
	var blocker := first.get_meta("blocker", null) as Node
	if blocker == null:
		level.queue_free()
		return _fail("la pierre n'a pas d'obstacle lié")
	blocker.queue_free()
	await _frames(2)
	var freed: bool = not blocked.call(first.global_position)
	level.queue_free()
	await _frames(2)
	if not freed:
		return _fail("l'obstacle d'une pierre arrachée reste en place")
	print("test réussi : les pierres du cercle arrêtent le passage et partent avec leur obstacle")
	return true


## La zone que le héros atteint à pied depuis son départ, sans qu'aucune
## image de jeu ne passe : on sonde les obstacles avec sa capsule.
func _reachable_zone(level: Level) -> Dictionary:
	const STEP := 0.1
	const LIMIT := Vector2(-115.0, 30.0)
	const WIDTH := 45.0
	var space := level.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	# Un peu plus mince que le héros (0,5) : un passage tout juste praticable
	# doit être vu, c'est ainsi qu'un coin des Allées avait échappé au test.
	shape.radius = 0.42
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	var exclude: Array[RID] = [level.hero.get_rid()]
	for enemy in level.enemies():
		exclude.append(enemy.get_rid())
	query.exclude = exclude
	var nx := int(2.0 * WIDTH / STEP) + 1
	var nz := int((LIMIT.y - LIMIT.x) / STEP) + 1
	var seen := PackedByteArray()
	seen.resize(nx * nz)
	var start := level.hero.global_position
	var first := int(round((start.x + WIDTH) / STEP)) * nz + int(round((start.z - LIMIT.x) / STEP))
	var queue := PackedInt32Array([first])
	seen[first] = 1
	var head := 0
	var zone := {"area": 0.0, "min_x": 1e9, "max_x": -1e9, "min_z": 1e9, "max_z": -1e9}
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var x := -WIDTH + (cell / nz) * STEP
		var z := LIMIT.x + (cell % nz) * STEP
		zone["area"] += STEP * STEP
		zone["min_x"] = minf(zone["min_x"], x)
		zone["max_x"] = maxf(zone["max_x"], x)
		zone["min_z"] = minf(zone["min_z"], z)
		zone["max_z"] = maxf(zone["max_z"], z)
		if zone["area"] > 3500.0:
			return zone
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ix: int = cell / nz + step.x
			var iz: int = cell % nz + step.y
			if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
				continue
			var next := ix * nz + iz
			if seen[next] == 1:
				continue
			seen[next] = 1
			query.transform = Transform3D(Basis(), Vector3(-WIDTH + ix * STEP, 0.9, LIMIT.x + iz * STEP))
			if space.intersect_shape(query, 1).is_empty():
				queue.append(next)
	return zone


## Le Crieur : il ne crie que si au moins deux morts se battent contre le héros,
## son cri rend les morts plus rapides et plus forts, seul il appelle du renfort,
## et le frapper pendant qu'il prend son souffle interrompt son cri.
func _crier_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 0.0)
	_passive = true
	var crier := arena.spawn(&"crieur", Vector3(0.0, 0.0, -9.0), false) as CrierEnemy
	var shouted := [false]
	var called := [0]
	crier.shouted.connect(func(_n: int) -> void: shouted[0] = true)
	crier.call_requested.connect(func(n: int) -> void: called[0] += n)
	# Seul, il ne crie pas (personne ne se bat) : il n'appelle qu'après un temps.
	crier._shout_timer = 0.0
	await _frames(40)
	if shouted[0]:
		return _fail("le Crieur crie alors qu'aucun mort ne se bat")
	# Deux morts sur le héros : il crie, et ils sont pressés et plus forts.
	var first := arena.spawn(&"depouille", Vector3(2.0, 0.0, -2.0), false)
	var second := arena.spawn(&"depouille", Vector3(-2.0, 0.0, -2.0), false)
	crier._shout_timer = 0.0
	if not await _until(func() -> bool: return shouted[0], 12.0):
		return _fail("le Crieur ne crie pas alors que deux morts se battent")
	if first.haste_time <= 0.0 or first._haste_aura == null or not first._haste_aura.visible:
		return _fail("le cri du Crieur ne presse pas les morts qui se battent (ni anneau rouge)")
	if first.damage_of(10) != 14:
		return _fail("un mort pressé ne frappe pas plus fort (%d au lieu de 14)" % first.damage_of(10))
	# Interrompu, il ne crie pas.
	shouted[0] = false
	await _frames(5)
	crier._shout_timer = 0.0
	await _frames(3)
	if crier.state != Enemy.State.SPECIAL:
		return _fail("le Crieur ne prend pas son souffle")
	crier.take_hit(hero.global_position, 1)
	await _frames(70)
	if shouted[0]:
		return _fail("frapper le Crieur n'interrompt pas son cri")
	# Les morts tombés, il appelle du renfort.
	first.take_hit(hero.global_position, 100000)
	second.take_hit(hero.global_position, 100000)
	await _frames(3)
	first.give_rest()
	second.give_rest()
	var before := arena.enemies_left()
	crier._call_timer = 0.0
	crier._shout_timer = 1000.0
	if not await _until(func() -> bool: return called[0] > 0, 12.0):
		return _fail("seul, le Crieur n'appelle pas de renfort")
	await _frames(5)
	if arena.enemies_left() < before + 1:
		return _fail("l'appel du Crieur ne fait surgir personne")
	print("test réussi : le Crieur presse ceux qui se battent, appelle du renfort seul, et se laisse interrompre")
	_passive = false
	_allow_rest = true
	crier.take_hit(hero.global_position, 100000)
	await _frames(3)
	crier.give_rest()
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 240.0):
		return _fail("les morts de l'essai du Crieur n'ont pas été mis au repos")
	return true


## Le Boucher : l'armure, l'enchaînement, la fenêtre ouverte, la charge et l'assommement.
func _butcher_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 0.0)
	_passive = true
	var butcher := arena.spawn(&"boucher", Vector3(1.4, 0.0, 0.0), false) as ButcherEnemy
	var data := EnemyTypes.get_type(&"boucher")
	butcher._charge_timer = 1000.0
	butcher._cooldown = 0.0
	if not await _until(func() -> bool:
		hero.heal(1000)
		return butcher.state == Enemy.State.WINDUP, 20.0):
		return _fail("le Boucher n'arme pas son coup")
	var life := butcher.health
	butcher.take_hit(hero.global_position, 10)
	if butcher.state != Enemy.State.WINDUP or butcher.health >= life:
		return _fail("le Boucher est interrompu en plein coup (ou n'est pas blessé)")
	# Son coup fini, il reste ouvert : il subit plus.
	if not await _until(func() -> bool:
		hero.heal(1000)
		return butcher.state != Enemy.State.WINDUP, 10.0):
		return _fail("le coup du Boucher ne finit pas")
	var combo_pending := butcher._combo > 0
	if not combo_pending and butcher._open_time <= 0.0:
		return _fail("le Boucher n'est pas ouvert après son coup")
	butcher._combo = 0
	butcher._open_time = 1.0
	life = butcher.health
	butcher.take_hit(hero.global_position, 40)
	if life - butcher.health != 60:
		return _fail("ouvert, le Boucher a subi %d au lieu de 60" % (life - butcher.health))
	# Ébranlé une fois, il ne l'est pas deux fois de suite.
	butcher._open_time = 0.0
	butcher.state = Enemy.State.CHASE
	butcher._cooldown = 100.0
	butcher._stagger_guard = 0.0
	butcher.take_hit(hero.global_position, 5)
	if butcher.state != Enemy.State.STAGGER:
		return _fail("le Boucher n'est pas ébranlé par un coup hors de son geste")
	await _frames(30)
	butcher.take_hit(hero.global_position, 5)
	if butcher.state == Enemy.State.STAGGER:
		return _fail("le Boucher est ébranlé deux fois de suite")
	# La charge : annoncée, puis il fonce ; un mur l'assomme et l'ouvre.
	butcher._cooldown = 100.0
	hero.global_position = Vector3(0.0, 0.0, 20.0)
	butcher.global_position = Vector3(0.0, 0.0, 8.0)
	butcher._charge_timer = 0.0
	await _frames(3)
	if butcher._phase != ButcherEnemy.Phase.STOMP:
		return _fail("le Boucher ne piétine pas avant de charger")
	await _frames(int(float(data["stomp_time"]) * 60.0) + 8)
	if butcher._phase != ButcherEnemy.Phase.CHARGE:
		return _fail("le Boucher ne charge pas après son piétinement")
	butcher._crash()
	if butcher._phase != ButcherEnemy.Phase.STUN or butcher._open_time < float(data["stun_time"]):
		return _fail("le Boucher qui s'écrase n'est ni assommé ni ouvert")
	await _frames(int(float(data["stun_time"]) * 60.0) + 10)
	if butcher.state == Enemy.State.SPECIAL:
		return _fail("le Boucher reste assommé trop longtemps")
	# Sous la moitié de sa vie, il enrage.
	butcher.health = int(float(data["health"]) * 0.4)
	await _frames(3)
	if butcher.haste_time <= 0.0:
		return _fail("le Boucher n'enrage pas sous la moitié de sa vie")
	print("test réussi : le Boucher a une armure, s'ouvre après son coup, charge, s'assomme et enrage")
	butcher.take_hit(hero.global_position, 100000)
	await _frames(3)
	butcher.give_rest()
	_passive = false
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 60.0):
		return _fail("les morts de l'essai du Boucher n'ont pas été mis au repos")
	return true


## Les morts du port (chapitre III). Le Noyé : son corps glisse vers l'eau,
## coule, et remonte debout plus loin ; il ne glisse pas pendant le Repos. Le
## Gaffeur : son jet, annoncé, tire le héros à lui ; l'esquive y échappe ;
## le frapper pendant qu'il vise l'interrompt.
func _harbor_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	hero.heal(1000)
	_passive = true
	_allow_rest = false
	arena.water_x = 6.0
	hero.global_position = Vector3(-8.0, 0.0, 8.0)
	var noye := arena.spawn(&"noye", Vector3(0.0, 0.0, 0.0), false) as DrownedEnemy
	var noye_data := EnemyTypes.get_type(&"noye")
	await _frames(2)
	var risen := [0]
	noye.rose.connect(func(_e: Enemy) -> void: risen[0] += 1)
	noye.take_hit(hero.global_position, 100000)
	var start := noye.body_position()
	await _frames(int(float(noye_data["slide_delay"]) * 60.0) + 40)
	if noye.body_position().x <= start.x + 0.2:
		arena.water_x = INF
		return _fail("le corps du Noyé ne glisse pas vers l'eau")
	if not await _until(func() -> bool: return noye.is_sunk(), 20.0):
		arena.water_x = INF
		return _fail("le corps du Noyé n'atteint pas l'eau")
	if noye.is_in_group(&"bodies") or noye.is_down():
		arena.water_x = INF
		return _fail("le Noyé coulé reste un corps qu'on peut mettre au repos")
	if not await _until(func() -> bool:
		hero.heal(1000)
		return noye.is_standing() and not noye.is_sunk() and noye.state == Enemy.State.CHASE, float(noye_data["sunk_time"]) + 8.0):
		arena.water_x = INF
		return _fail("le Noyé coulé ne remonte pas")
	if risen[0] != 1:
		arena.water_x = INF
		return _fail("le Noyé qui remonte ne compte pas comme un mort relevé")
	# Agenouillé près de lui, le corps ne glisse plus, et le Repos aboutit.
	# (Il est remonté près du bord : on l'abat loin de l'eau.)
	noye.global_position = Vector3(-3.0, 0.0, 0.0)
	await _frames(2)
	noye.take_hit(hero.global_position, 100000)
	await _frames(int(float(noye_data["slide_delay"]) * 60.0) + 20)
	var body := noye.body_position()
	hero.global_position = body + Vector3(-0.9, 0.0, 0.0)
	_hold_rite = true
	await _frames(6)
	if hero.state != Hero.State.RITE:
		_hold_rite = false
		arena.water_x = INF
		return _fail("le héros ne s'agenouille pas près du Noyé (état %d, corps à %.2f, à terre %s, REPOS %s)" % [hero.state, noye.distance_to_body(hero.global_position), noye.is_down(), hero.controls.rite_held])
	var kneel := noye.body_position()
	await _frames(30)
	if noye.body_position().distance_to(kneel) > 0.05:
		_hold_rite = false
		arena.water_x = INF
		return _fail("le corps du Noyé glisse pendant qu'on lui donne le Repos")
	var rested := await _until(func() -> bool: return noye.state == Enemy.State.RESTED or not is_instance_valid(noye), 4.0)
	_hold_rite = false
	arena.water_x = INF
	if not rested:
		return _fail("le Noyé ne reçoit pas le Repos")
	print("test réussi : le corps du Noyé glisse, coule et remonte debout ; il ne glisse pas pendant le Repos")

	if not await _embrace_tests():
		return false

	# Le Gaffeur : il vise, lance, et tire le héros à lui.
	hero.heal(1000)
	hero.state = Hero.State.MOVE
	hero.global_position = Vector3(0.0, 0.0, 6.0)
	var gaffeur := arena.spawn(&"gaffeur", Vector3(0.0, 0.0, 0.0), false) as GaffeurEnemy
	var data := EnemyTypes.get_type(&"gaffeur")
	await _frames(2)
	gaffeur._hook_timer = 0.0
	gaffeur._cooldown = 0.0
	if not await _until(func() -> bool:
		hero.global_position = Vector3(0.0, 0.0, 6.0)
		if gaffeur.state != Enemy.State.SPECIAL:
			gaffeur.global_position = Vector3.ZERO
		return gaffeur.state == Enemy.State.SPECIAL, 5.0):
		return _fail("le Gaffeur ne vise pas un héros à mi-distance")
	if not _check_blow("jet de gaffe", gaffeur, float(data["hook_windup"]), float(data["hook_impact"])):
		return false
	await _frames(2)
	if not gaffeur._line.visible:
		return _fail("le jet du Gaffeur n'est pas annoncé")
	if not await _until(func() -> bool: return gaffeur._thrown, 3.0):
		return _fail("le Gaffeur ne lance pas sa gaffe")
	await _frames(30)
	var pulled := hero.global_position.distance_to(gaffeur.global_position)
	if pulled > 2.6:
		return _fail("la gaffe n'a pas tiré le héros (il est à %.1f du Gaffeur)" % pulled)
	# En esquivant au moment du jet, on y échappe.
	await _frames(40)
	hero.heal(1000)
	hero.state = Hero.State.MOVE
	hero._dodge_cooldown = 0.0
	gaffeur.state = Enemy.State.CHASE
	gaffeur._hook_timer = 0.0
	gaffeur._cooldown = 0.0
	if not await _until(func() -> bool:
		hero.global_position = Vector3(0.0, 0.0, 6.0)
		if gaffeur.state != Enemy.State.SPECIAL:
			gaffeur.global_position = Vector3.ZERO
		return gaffeur.state == Enemy.State.SPECIAL, 5.0):
		return _fail("le Gaffeur ne vise pas une seconde fois")
	await _until(func() -> bool: return gaffeur._state_time >= float(data["hook_windup"]) - 0.12, 3.0)
	var life := hero.health
	hero._on_dodge_pressed()
	await _frames(8)
	if hero.health != life:
		return _fail("la gaffe blesse un héros qui esquive")
	# Frappé pendant qu'il vise, il lâche prise.
	await _frames(40)
	gaffeur.state = Enemy.State.CHASE
	gaffeur._hook_timer = 0.0
	gaffeur._cooldown = 0.0
	if not await _until(func() -> bool:
		hero.global_position = Vector3(0.0, 0.0, 6.0)
		if gaffeur.state != Enemy.State.SPECIAL:
			gaffeur.global_position = Vector3.ZERO
		return gaffeur.state == Enemy.State.SPECIAL, 5.0):
		return _fail("le Gaffeur ne vise pas une troisième fois")
	gaffeur.take_hit(hero.global_position, 5)
	if gaffeur.state == Enemy.State.SPECIAL or gaffeur._line.visible:
		return _fail("frappé pendant qu'il vise, le Gaffeur ne lâche pas prise")
	print("test réussi : la gaffe est annoncée, tire le héros, l'esquive y échappe, un coup l'interrompt")
	gaffeur.take_hit(hero.global_position, 100000)
	_passive = false
	_allow_rest = true
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 60.0):
		return _fail("les morts de l'essai du port n'ont pas été mis au repos")
	return true


## L'Étreinte du Noyé, sa main sous l'eau, et le brouillard du fleuve.
func _embrace_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	var data := EnemyTypes.get_type(&"noye")
	hero.heal(1000)
	hero.state = Hero.State.MOVE
	_passive = true
	_allow_rest = false
	arena.water_x = 6.0
	var spot := Vector3(3.5, 0.0, 0.0)
	hero.global_position = spot
	var noye := arena.spawn(&"noye", Vector3(3.5, 0.0, -1.5), false) as DrownedEnemy
	var other := arena.spawn(&"depouille", Vector3(-3.0, 0.0, 3.0), false)
	await _frames(2)
	other.take_hit(hero.global_position, 100000)
	noye._grab_timer = 0.0
	noye._cooldown = 0.0
	if not await _until(func() -> bool:
		hero.heal(1000)
		hero.global_position = spot
		return noye.is_reaching(), 5.0):
		arena.water_x = INF
		return _fail("le Noyé n'agrippe pas un héros près du bord")
	await _frames(2)
	if not noye._puddle.visible:
		arena.water_x = INF
		return _fail("l'Étreinte du Noyé n'est pas annoncée")
	if not _check_blow("étreinte", noye, float(data["grab_windup"]), float(data["grab_impact"])):
		arena.water_x = INF
		return false
	if not await _until(func() -> bool: return noye.is_holding(), 3.0) or not hero.is_held():
		arena.water_x = INF
		return _fail("l'Étreinte du Noyé ne tient pas le héros")
	var life := hero.health
	await _frames(40)
	if hero.global_position.x < spot.x + 0.4:
		arena.water_x = INF
		return _fail("le Noyé ne traîne pas le héros vers l'eau (x = %.2f)" % hero.global_position.x)
	if hero.health >= life:
		arena.water_x = INF
		return _fail("l'Étreinte ne blesse pas le héros")
	# Le brouillard : un Noyé debout cache les corps.
	if not await _until(func() -> bool: return arena.mist_thick(), 5.0):
		arena.water_x = INF
		return _fail("le brouillard du fleuve ne monte pas quand un Noyé est debout")
	await _frames(2)
	if other._marker.visible:
		arena.water_x = INF
		return _fail("le brouillard du fleuve ne cache pas le repère d'un corps")
	# L'esquive dégage le héros.
	hero._dodge_cooldown = 0.0
	hero._on_dodge_pressed()
	await _frames(2)
	if hero.is_held() or noye.is_holding():
		arena.water_x = INF
		return _fail("l'esquive ne dégage pas le héros de l'Étreinte")
	# Un coup aussi.
	await _frames(30)
	hero.heal(1000)
	noye._grab_timer = 0.0
	noye._cooldown = 0.0
	if not await _until(func() -> bool:
		hero.heal(1000)
		if not noye.is_holding():
			hero.global_position = spot
			if noye.state != Enemy.State.SPECIAL:
				noye.global_position = spot + Vector3(0.0, 0.0, -1.5)
		return noye.is_holding(), 6.0):
		arena.water_x = INF
		return _fail("le Noyé n'agrippe pas une seconde fois")
	noye.take_hit(hero.global_position, 5)
	if hero.is_held() or noye.is_holding():
		arena.water_x = INF
		return _fail("frappé, le Noyé ne lâche pas le héros")
	# Laissé faire, il traîne le héros jusqu'au bord et plonge.
	await _frames(30)
	hero.heal(1000)
	noye._grab_timer = 0.0
	noye._cooldown = 0.0
	if not await _until(func() -> bool:
		if not noye.is_holding():
			hero.heal(1000)
			hero.global_position = spot
			if noye.state != Enemy.State.SPECIAL:
				noye.global_position = spot + Vector3(0.0, 0.0, -1.5)
		return noye.is_holding(), 6.0):
		arena.water_x = INF
		return _fail("le Noyé n'agrippe pas une troisième fois")
	life = hero.health
	if not await _until(func() -> bool: return noye.is_sunk(), 6.0):
		arena.water_x = INF
		return _fail("le Noyé ne plonge pas au bord de l'eau")
	if life - hero.health < int(data["plunge_damage"]) or hero.is_held():
		arena.water_x = INF
		return _fail("le plongeon du Noyé ne meurtrit pas le héros, ou ne le lâche pas")
	# La main : sous l'eau, il guette le héros qui s'approche du bord.
	hero.heal(1000)
	hero.global_position = Vector3(4.6, 0.0, 4.0)
	if not await _until(func() -> bool:
		hero.global_position = Vector3(4.6, 0.0, 4.0)
		return not noye.is_sunk(), float(data["hand_delay"]) + 2.0):
		arena.water_x = INF
		return _fail("le Noyé sous l'eau ne sort pas quand le héros s'approche du bord")
	if not noye.is_reaching() or not noye.is_in_group(&"hittable"):
		arena.water_x = INF
		return _fail("la main du Noyé n'agrippe pas en sortant de l'eau")
	noye.take_hit(hero.global_position, 100000)
	arena.water_x = INF
	if not await _until(func() -> bool: return not arena.mist_thick(), 6.0):
		return _fail("le brouillard du fleuve ne retombe pas")
	await _frames(2)
	if not other._marker.visible:
		return _fail("le repère du corps ne revient pas quand la brume retombe")
	print("test réussi : l'Étreinte est annoncée, traîne et blesse ; esquive et coup libèrent ; le plongeon, la main, le brouillard")
	_passive = false
	_allow_rest = true
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 60.0):
		return _fail("les morts de l'essai de l'Étreinte n'ont pas été mis au repos")
	_passive = true
	_allow_rest = false
	return true


## Le Peseur : la balance règle les dégâts qu'il subit, ses poids sont annoncés.
func _peseur_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 30.0)
	_passive = true
	_allow_rest = false
	var boss := arena.spawn(&"peseur", Vector3(0.0, 0.0, -8.0), false) as PeseurEnemy
	var data := EnemyTypes.get_type(&"peseur")
	var adds: Array[Enemy] = []
	for i in 3:
		adds.append(arena.spawn(&"depouille", Vector3(-6.0 + 3.0 * i, 0.0, -14.0), false))
	await _frames(3)
	boss._weight_timer = 1000.0

	var hit := func(amount: int) -> int:
		var before := boss.health
		boss.take_hit(hero.global_position, amount)
		return before - boss.health

	if boss.evaluate_balance() != PeseurEnemy.Balance.STANDING:
		return _fail("trois morts debout et aucun corps : la balance ne penche pas de leur côté")
	var shielded: int = hit.call(100)
	if absi(shielded - int(round(100.0 * float(data["shield_factor"])))) > 1:
		return _fail("protégé par la balance, le Peseur a subi %d au lieu de 35" % shielded)
	# Abattus, ils deviennent des corps : la balance penche de l'autre côté.
	for add in adds:
		add.take_hit(hero.global_position, 100000)
	await _frames(3)
	if boss.evaluate_balance() != PeseurEnemy.Balance.LYING:
		return _fail("trois corps et aucun mort debout : la balance ne penche pas du côté des corps")
	var normal: int = hit.call(100)
	if absi(normal - 100) > 1:
		return _fail("côté corps, le Peseur a subi %d au lieu de 100" % normal)
	if boss.weight_interval() >= float(data["weight_interval"]):
		return _fail("côté corps, ses poids ne tombent pas plus vite")
	# Deux Repos : un seul corps reste, c'est l'équilibre.
	adds[0].give_rest()
	adds[1].give_rest()
	await _frames(3)
	if boss.evaluate_balance() != PeseurEnemy.Balance.EVEN:
		return _fail("un corps et aucun mort debout : la balance n'est pas à l'équilibre")
	if not boss.is_stunned():
		return _fail("l'équilibre n'assomme pas le Peseur")
	var vulnerable: int = hit.call(100)
	if absi(vulnerable - int(round(100.0 * float(data["even_factor"])))) > 1:
		return _fail("à l'équilibre, le Peseur a subi %d au lieu de 140" % vulnerable)

	# Un poids est annoncé, puis tombe sur le héros immobile.
	var life := hero.health
	boss.drop_weight_at(hero.global_position)
	if boss._weights.size() != 1:
		return _fail("un poids annoncé n'est pas marqué au sol")
	await _frames(40)
	if hero.health != life:
		return _fail("le poids a blessé le héros avant la fin de l'annonce")
	await _frames(70)
	if hero.health >= life:
		return _fail("le poids n'a pas blessé le héros resté dans la zone")
	life = hero.health
	boss.drop_weight_at(hero.global_position + Vector3(12.0, 0.0, 0.0))
	await _frames(110)
	if hero.health != life:
		return _fail("un poids tombé loin du héros l'a blessé")

	# Les motifs de poids : rouleau (5), paire (2) ; trois à la fois s'il y a trop de corps.
	boss._weights.clear()
	boss.balance_state = PeseurEnemy.Balance.EVEN
	boss._pattern = 2
	boss.drop_pattern()
	if boss._weights.size() != 5:
		return _fail("le rouleau de poids n'en compte pas cinq (%d)" % boss._weights.size())
	boss._pattern = 1
	boss.drop_pattern()
	if boss._weights.size() != 7:
		return _fail("la paire de poids n'en ajoute pas deux")
	boss.balance_state = PeseurEnemy.Balance.LYING
	boss.drop_pattern()
	if boss._weights.size() != 10:
		return _fail("trop de corps : le Peseur ne lance pas trois poids à la fois")
	await _frames(3)
	boss.evaluate_balance()
	if boss.balance_state != PeseurEnemy.Balance.EVEN and boss.haste_time <= 0.0 and boss.state != Enemy.State.SPECIAL:
		pass
	print("test réussi : la balance du Peseur règle ses dégâts, ses poids sont annoncés et blessent")
	boss.take_hit(hero.global_position, 100000)
	adds[2].take_hit(hero.global_position, 100000)
	await _frames(3)
	boss.give_rest()
	adds[2].give_rest()
	_passive = false
	_allow_rest = true
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 60.0):
		return _fail("les morts de l'essai du Peseur n'ont pas été mis au repos")
	return true


## Le Prévôt : la levée frappe hors du cercle d'or seulement et reprend les
## corps qui n'y sont pas ; à chaque tiers de sa vie il décrète, intouchable un
## instant, le cercle rétrécit, et au dernier tiers un faux cercle paraît.
func _prevot_tests() -> bool:
	var arena := _level() as Arena
	var hero := arena.hero
	hero.heal(1000)
	hero.global_position = Vector3(0.0, 0.0, 30.0)
	_passive = true
	_allow_rest = false
	var boss := arena.spawn(&"prevot", Vector3(0.0, 0.0, -8.0), false) as PrevotEnemy
	var data := EnemyTypes.get_type(&"prevot")
	boss._levy_timer = 1000.0
	await _frames(3)

	# Un corps loin du cercle : la levée le relève.
	var corpse := arena.spawn(&"depouille", Vector3(11.0, 0.0, -20.0), false)
	corpse.take_hit(hero.global_position, 100000)
	await _frames(3)
	# Dans le cercle d'or : la levée ne blesse pas.
	boss._begin_levy()
	if not boss.levy_pending or boss.levy_time_left() <= 0.0:
		return _fail("la levée n'est pas annoncée")
	hero.global_position = boss.levy_center
	var life := hero.health
	var windup := boss.levy_windup()
	await _frames(int(windup * 60.0) + 25)
	if boss.levy_pending or hero.health != life:
		return _fail("la levée a blessé le héros qui se tenait dans le cercle d'or")
	if corpse.state == Enemy.State.DOWN:
		return _fail("la levée n'a pas relevé un corps hors du cercle")
	# Hors du cercle : elle frappe.
	boss._levy_timer = 1000.0
	boss._begin_levy()
	hero.global_position = boss.levy_center + Vector3(boss.safe_radius() + 4.0, 0.0, 0.0)
	life = hero.health
	await _frames(int(boss.levy_windup() * 60.0) + 25)
	if hero.health >= life:
		return _fail("la levée n'a pas blessé le héros hors du cercle")

	# Un nouveau tiers de sa vie : il décrète, intouchable, puis redevient vulnérable.
	var stages := [0]
	boss.stage_changed.connect(func(_s: int) -> void: stages[0] += 1)
	var radius_one := boss.safe_radius()
	boss.health = int(float(data["health"]) * 0.6)
	await _frames(4)
	if boss.stage() != 2 or stages[0] != 1:
		return _fail("le Prévôt ne décrète pas au deuxième tiers de sa vie")
	var before := boss.health
	boss.take_hit(hero.global_position, 50)
	if boss.health != before:
		return _fail("le Prévôt est blessé pendant qu'il décrète")
	await _frames(int(float(data["edict_time"]) * 60.0) + 15)
	boss.take_hit(hero.global_position, 50)
	if boss.health >= before:
		return _fail("le Prévôt reste intouchable après avoir décrété")
	if boss.levy_interval() >= float(data["levy_interval"]):
		return _fail("la levée ne se rapproche pas au deuxième tiers")
	if boss.safe_radius() >= radius_one:
		return _fail("le cercle d'or ne rétrécit pas au deuxième tiers")
	# Dernier tiers : un faux cercle accompagne le vrai.
	boss.health = int(float(data["health"]) * 0.25)
	await _frames(4)
	await _frames(int(float(data["edict_time"]) * 60.0) + 15)
	boss._levy_timer = 1000.0
	boss._begin_levy()
	if not boss.has_fake() or boss.levy_fake == Vector3.ZERO:
		return _fail("aucun faux cercle au dernier tiers de la vie du Prévôt")
	if boss.levy_fake.distance_to(boss.levy_center) < 2.0 * boss.safe_radius():
		return _fail("le faux cercle est confondu avec le vrai")

	print("test réussi : la levée du Prévôt épargne le cercle d'or, relève les corps hors du cercle, le cercle rétrécit et se double d'un faux")
	boss.take_hit(hero.global_position, 100000)
	corpse.take_hit(hero.global_position, 100000)
	await _frames(3)
	boss.give_rest()
	if corpse.state == Enemy.State.DOWN:
		corpse.give_rest()
	_passive = false
	_allow_rest = true
	hero.global_position = Vector3(0.0, 0.0, 3.0)
	if not await _until(func() -> bool: return arena.enemies_left() == 0, 90.0):
		return _fail("les morts de l'essai du Prévôt n'ont pas été mis au repos")
	return true


## Traverse un niveau de bout en bout. Le joueur automatique peut tomber :
## il reprend alors au point de reprise, comme un joueur.
func _traverse(id: StringName) -> bool:
	_completed = false
	_checkpoint = 0
	# Un joueur emporte ses fioles : le robot en a trois, comme après un achat.
	Progress.flasks = 3
	# Au chapitre II, un joueur s'est équipé avec l'or du premier chapitre : le
	# robot achète la lame longue et la rondache.
	if WorldData.level_index(id) >= WorldData.LEVELS_PER_CHAPTER:
		Progress.add_gold(900)
		Progress.buy_gear(&"lame_longue")
		Progress.buy_gear(&"rondache")
	var falls := [0]
	var on_load := func(level: Level) -> void:
		falls[0] += 1
		_watch(level)
	main.level_loaded.connect(on_load)
	main.load_level(id)
	falls[0] = 0
	# Le joueur automatique n'a pas de fiole : un combat de boss du chapitre II
	# lui est permis plus de chutes (il reprend alors au point de reprise).
	var limit := 12 if id in [&"la_balance", &"la_halle_du_prevot"] else 6
	var done := await _until(func() -> bool: return _completed or falls[0] > limit, 1500.0, false)
	main.level_loaded.disconnect(on_load)
	if not done or not _completed:
		var stuck := _level()
		var left: Array[String] = []
		for enemy in stuck.enemies():
			left.append("%s état %d en %s" % [enemy.type_id_name, enemy.state, enemy.global_position.snapped(Vector3.ONE * 0.1)])
		print("bloqué : héros en %s (état %d), objectif %s, morts : %s, corps : %d" % [
			stuck.hero.global_position.snapped(Vector3.ONE * 0.1), stuck.hero.state, stuck.objective,
			left, get_tree().get_nodes_in_group(&"bodies").size()])
		return _fail("%s n'a pas été terminé (%d chutes)" % [id, falls[0]])
	if not Progress.is_completed(id):
		return _fail("la fin de %s n'a pas été enregistrée" % id)
	if not _victory_seen:
		return _fail("%s se ferme sans bandeau de victoire" % id)
	print("test réussi : %s terminé, niveau %d, %d d'or, %d chute(s), rites lancés : %s" % [
		_level().title, Progress.hero_level, Progress.gold, falls[0], rites_cast])
	rites_cast.clear()
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
	Progress.add_gold(100)
	Progress.pack_meal(&"pain")
	map.select_level(&"les_allees")
	map.enter_selected()
	await get_tree().process_frame
	if chosen[0] != &"les_allees" or main.level == null or main.world_map != null:
		return _fail("le niveau choisi sur la carte ne s'est pas ouvert")
	if Progress.active_meal != &"pain" or Progress.packed_meal != &"":
		return _fail("le repas emballé n'est pas mangé en partant pour un niveau")
	print("test 12 réussi : la carte ouvre le niveau choisi, refuse celui qui n'existe pas")

	# Abandon depuis le carnet : retour à la carte.
	var level := _level()
	level.open_book()
	level.book.leave_requested.emit()
	await get_tree().process_frame
	if main.level != null or main.world_map == null or get_tree().paused:
		return _fail("quitter le niveau depuis le carnet ne ramène pas à la carte")
	if Progress.active_meal != &"":
		return _fail("le repas du niveau n'est pas fini en revenant à la carte")
	print("test 12 réussi : quitter le niveau ramène à la carte")

	# Le moulin est petit et un niveau proche passe avant lui : un toucher sur
	# la Grille, même à côté du point, ne choisit jamais le moulin.
	map = main.world_map
	var grille: Vector2 = map._scene.node_positions[0]
	for offset: Vector2 in [Vector2.ZERO, Vector2(-45.0, 0.0), Vector2(0.0, 40.0), Vector2(30.0, -30.0)]:
		map._tap(map.screen_of(grille + offset))
		if map.selected_id() != &"la_grille":
			return _fail("un toucher à %s de la Grille a choisi « %s »" % [offset, map.selected_id()])
	map._tap(map.screen_of(WorldMap.MILL_POINT))
	if map.selected_id() != &"refuge":
		return _fail("un toucher sur le moulin ne le choisit pas")
	print("test 12 réussi : la Grille et le moulin ne se disputent plus les touchers")

	# La carte est aérée : niveaux d'un chapitre bien espacés, moulin loin de
	# tout niveau, un chapitre par voie, et l'eau est bien animée.
	var positions: PackedVector2Array = map._scene.node_positions
	# Les chapitres écrits seulement : les voies hautes, plus étroites, attendent leur tour.
	for i in WorldData.CHAPTERS.size() * WorldData.LEVELS_PER_CHAPTER:
		if positions[i].distance_to(WorldMap.MILL_POINT) < 150.0:
			return _fail("le niveau %d est collé au moulin" % (i + 1))
		if i % WorldData.LEVELS_PER_CHAPTER != 0 and positions[i].distance_to(positions[i - 1]) < 150.0:
			return _fail("les niveaux %d et %d sont trop serrés sur la carte" % [i, i + 1])
		if absf(positions[i].y - positions[i / WorldData.LEVELS_PER_CHAPTER * WorldData.LEVELS_PER_CHAPTER].y) > 1.0:
			return _fail("le niveau %d n'est pas sur la voie de son chapitre" % (i + 1))
	if map._scene.river == null or not is_instance_valid(map._scene.river):
		return _fail("la rive animée manque sur la carte")
	var before: float = map._scene.river.time
	await _frames(20)
	if map._scene.river.time <= before:
		return _fail("l'eau de la carte ne s'anime pas")
	print("test 12 réussi : carte aérée, chapitres sur leurs voies, moulin à l'écart, eau animée")

	# Un chapitre est accompli quand ses cinq niveaux sont faits.
	for level_data: Dictionary in WorldData.CHAPTER_1["levels"]:
		Progress.mark_completed(level_data["id"])
	map.refresh()
	if map._scene.chapters_done.size() != WorldData.ROUTE_CHAPTERS or not map._scene.chapters_done[0]:
		return _fail("le chapitre I n'est pas accompli quand ses cinq niveaux sont faits")
	if map._scene.chapters_done.has(true) and map._scene.chapters_done.count(true) != 1 + (1 if Progress.is_completed(&"la_porte_des_halles") and Progress.is_completed(&"les_etals") and Progress.is_completed(&"la_balance") and Progress.is_completed(&"les_caves") and Progress.is_completed(&"la_halle_du_prevot") else 0):
		return _fail("un chapitre inachevé passe pour accompli")
	# Les sceaux : chacun se brise avec le dernier chapitre de son étage ; la
	# porte des fondations s'ouvre quand les quatre le sont.
	if map._scene.lane_segments.size() != WorldData.ROUTE_CHAPTERS:
		return _fail("la route compte %d voies pour %d chapitres" % [map._scene.lane_segments.size(), WorldData.ROUTE_CHAPTERS])
	var saved_done := map._scene.chapters_done.duplicate()
	var world: MapWorld = map._world
	map._scene.chapters_done.fill(false)
	map._scene.chapters_done[2] = true
	if not world.seal_broken(0) or world.seal_broken(1) or world.gate_open():
		return _fail("le Sceau des Corps ne suit pas le chapitre III")
	map._scene.chapters_done.fill(true)
	world.set_states(map._scene.states, map._scene.ready_flags)
	if not world.gate_open() or not world._gate_glow.visible:
		return _fail("la porte des fondations ne s'ouvre pas quand les quatre sceaux sont brisés")
	map._scene.chapters_done = saved_done
	map.refresh()
	if world.gate_open() or world._gate_glow.visible:
		return _fail("la porte des fondations reste ouverte")
	print("test 12 réussi : chapitres accomplis, sceaux et porte des fondations")

	# Le moulin se choisit comme un niveau, mais ne consomme pas le repas.
	Progress.add_gold(100)
	Progress.pack_meal(&"fromage")
	map.select_refuge()
	if map.selected_id() != &"refuge":
		return _fail("le moulin ne se choisit pas sur la carte")
	map.enter_selected()
	await get_tree().process_frame
	if main.level == null or main.level.title != "Le moulin":
		return _fail("le moulin ne s'ouvre pas depuis la carte")
	if Progress.packed_meal != &"fromage" or Progress.active_meal != &"":
		return _fail("aller au moulin a consommé le repas emballé")
	print("test 12 réussi : le moulin s'ouvre depuis la carte")
	return true


## La carte vivante : le relief porte la route, la ville tient dans le budget
## du téléphone, les quartiers perdus sont sous la brume, les niveaux faits
## ont leur brasier, la fiche du lieu montre ses morts, et la plongée mène au
## niveau.
func _map_life_tests() -> bool:
	# Le relief est à jour et la route y est posée, sans flotter ni s'enfoncer.
	var relief := load(MapTerrain.MESH_PATH) as Mesh
	if relief == null or int(relief.get_meta("version", 0)) != MapTerrain.VERSION:
		return _fail("le relief de la carte manque ou n'est pas à jour : relancer -- --terrain")
	Progress.completed.clear()
	main.show_map()
	await get_tree().process_frame
	var map: WorldMap = main.world_map
	var world: MapWorld = map._world
	for p: Vector2 in map._scene.route:
		var gap := absf(world.terrain.height(p) - MapWorld.height_at(p.y))
		if gap > 0.06 and not (p.y > MapScene.RIVER_TOP and p.y < MapScene.RIVER_BOTTOM):
			return _fail("la route quitte le relief en %s (écart %.2f)" % [p, gap])
	if world.city.triangle_count() > 260000:
		return _fail("la ville de la carte est trop lourde : %d triangles" % world.city.triangle_count())
	print("test 12 réussi : la route suit le relief, la ville tient dans le budget (%d triangles)" % world.city.triangle_count())

	# Au début, le quartier du chapitre II est perdu : brume, fenêtres éteintes,
	# morts errants ; celui du chapitre I est atteint.
	var life := world.life
	if life.states[0] != MapLife.ATTEINT or life.states[1] != MapLife.PERDU:
		return _fail("quartiers au départ : %s" % [life.states])
	if life.fog_density(1) < 0.99 or world.city.district_light(1) > 0.0:
		return _fail("le quartier perdu n'est pas sous la brume")
	if life.fog_density(0) > 0.01 or world.city.district_light(0) <= 0.0:
		return _fail("le quartier atteint reste dans la brume ou éteint")
	if not (life._wanderers[0]["node"] as Node3D).visible:
		return _fail("aucun mort n'erre dans les quartiers perdus")
	# Le chapitre I terminé : son quartier est apaisé, celui du II atteint.
	for level_data: Dictionary in WorldData.CHAPTER_1["levels"]:
		Progress.mark_completed(level_data["id"])
	map.refresh()
	if life.states[0] != MapLife.APAISE or life.states[1] != MapLife.ATTEINT:
		return _fail("quartiers après le chapitre I : %s" % [life.states])
	if world.city.district_light(0) < 0.99 or life.fog_density(1) > 0.01 or world.city.district_light(1) <= 0.0:
		return _fail("le chapitre I fini n'éclaire pas la ville basse ou ne lève pas la brume")
	if not (world._nodes[0]["brazier"] as Node3D).visible or (world._nodes[5]["brazier"] as Node3D).visible:
		return _fail("les brasiers ne suivent pas les niveaux faits")
	print("test 12 réussi : brume sur les quartiers perdus, fenêtres et brasiers des niveaux faits")

	# La fiche du lieu : les morts des Allées, en portraits ou en silhouettes.
	map.select_level(&"les_allees")
	if map.portrait_count() != (WorldData.level_at(1)["dead"] as Array).size():
		return _fail("la fiche des Allées montre %d morts" % map.portrait_count())
	for level_data: Dictionary in WorldData.chapter_levels():
		for type_id: StringName in level_data["dead"]:
			if not EnemyTypes.TYPES.has(type_id):
				return _fail("%s nomme un mort inconnu : %s" % [level_data["id"], type_id])
	# Les rites portés se choisissent dans la fiche du lieu, avant d'entrer.
	if map.worn_rites_shown() != RiteData.SLOTS:
		return _fail("la fiche du lieu ne montre pas les trois rites portés (%d)" % map.worn_rites_shown())
	map.open_rite_picker(0)
	if not map.rite_picker_shown():
		return _fail("toucher un rite porté n'ouvre pas la liste des rites")
	if not map.choose_rite(0, &"tombee") or Progress.rite_slots[0] != &"tombee" or map.rite_picker_shown():
		return _fail("choisir la Tombée dans la liste ne la porte pas")
	map.select_refuge()
	if map.worn_rites_shown() != 0:
		return _fail("la fiche du moulin montre des rites à porter")
	map.select_level(&"les_allees")

	# Le pincement reste dans ses bornes.
	map._set_zoom(0.1)
	if not is_equal_approx(map._zoom, WorldMap.ZOOM_MIN):
		return _fail("le pincement rapproche trop la caméra")
	map._set_zoom(1.0)
	print("test 12 réussi : la fiche du lieu montre ses morts, le zoom est borné")

	# Un rite qui vient de s'ouvrir se présente une fois, avec son animation.
	for key: String in Progress.seen.keys():
		if key.begins_with("rite_"):
			Progress.seen.erase(key)
	var pending := map.pending_rites()
	if not pending.has(&"glas"):
		return _fail("le Glas, ouvert par la Grille, ne se présente pas sur la carte")
	var shown := 0
	while map.show_next_rite():
		shown += 1
		if not map.rite_card_shown() or map._rite_card.find_children("*", "RitePreview", true, false).is_empty():
			return _fail("la fiche du rite nouveau n'a pas d'animation")
	if shown != pending.size() or not map.pending_rites().is_empty():
		return _fail("les rites nouveaux ne se présentent pas chacun une fois")
	await get_tree().process_frame
	print("test 12 réussi : chaque rite qui s'ouvre se présente une fois sur la carte")

	# La plongée : le corbeau vole, la caméra plonge, puis le niveau s'ouvre.
	map.cinematics = true
	map.select_level(&"la_grille")
	map.enter_selected()
	await get_tree().process_frame
	if main.level != null or not map.is_moving() or not world.raven.visible:
		return _fail("la plongée vers le niveau ne commence pas")
	var waited := 0.0
	while main.level == null and waited < WorldMap.DIVE_TIME + 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if main.level == null or main.level_id != &"la_grille":
		return _fail("la plongée ne mène pas au niveau")
	print("test 12 réussi : la plongée du corbeau mène au niveau")
	return true


## Les rites de combat : les braises, puis chacun des neuf rites dans l'arène,
## le carnet, les icônes et les animations, la sauvegarde.
func _rite_tests() -> bool:
	main.load_level(&"arena")
	await get_tree().process_frame
	var arena := _level() as Arena
	var hero := arena.hero
	_passive = true
	await _frames(10)

	# Les rites s'ouvrent avec les niveaux, et prennent les emplacements libres.
	Progress.completed.clear()
	Progress.rite_slots = [&"", &"", &""]
	if not Progress.unlocked_rites().is_empty():
		return _fail("des rites sont ouverts sans niveau terminé")
	Progress.mark_completed(&"la_grille")
	if Progress.rite_slots != [&"glas", &"linceul", &"cortege"]:
		return _fail("les rites de la Grille ne prennent pas les emplacements : %s" % [Progress.rite_slots])
	if Progress.rite_unlocked(&"rappel"):
		return _fail("le Rappel s'ouvre avant le Sceau des Armes")

	# Un Repos donné allume une braise ; sans braise, pas de rite.
	Progress.embers = 0
	var first := arena.spawn(&"depouille", Vector3(0.0, 0.0, -3.0), false)
	first.take_hit(hero.global_position, 999)
	first.give_rest()
	await _frames(2)
	if Progress.embers != 1 or hero.embers != 1 or arena.hud.embers_shown() != 1:
		return _fail("un Repos n'allume pas de braise (%d)" % Progress.embers)
	Progress.embers = 0
	Progress.add_ember()
	Progress.embers = 0
	await _frames(1)
	if hero.cast_slot(0):
		return _fail("le Glas part sans braises")

	var checks := {
		&"glas": func() -> String:
			var foes: Array[Enemy] = []
			for k in 3:
				foes.append(arena.spawn(&"depouille", Vector3(cos(k * 2.1) * 2.5, 0.0, sin(k * 2.1) * 2.5), false))
			if not _cast(hero, &"glas"):
				return "il ne part pas"
			await get_tree().create_timer(1.4).timeout
			for foe in foes:
				if not foe.is_down():
					return "un mort à 2,5 m reste debout"
			if Progress.embers != RiteData.MAX_EMBERS - 3:
				return "il ne coûte pas trois braises (%d)" % Progress.embers
			return "",
		&"linceul": func() -> String:
			var foes: Array[Enemy] = [arena.spawn(&"depouille", Vector3(1.8, 0.0, 0.0), false), arena.spawn(&"depouille", Vector3(-1.8, 0.0, 0.0), false)]
			if not _cast(hero, &"linceul"):
				return "il ne part pas"
			await get_tree().create_timer(2.3).timeout
			for foe in foes:
				if foe.is_standing() and foe.health >= foe.max_health():
					return "un mort tout près n'est pas touché"
			return "",
		&"cortege": func() -> String:
			var foe := arena.spawn(&"depouille", Vector3(0.0, 0.0, -4.0), false)
			var start := hero.global_position
			hero.face(Vector3(0.0, 0.0, -1.0))
			if not _cast(hero, &"cortege"):
				return "il ne part pas"
			if not hero._rites.untouchable():
				return "la ruée n'est pas intouchable"
			await get_tree().create_timer(0.7).timeout
			if hero.global_position.distance_to(start) < 4.0:
				return "la ruée n'avance pas (%.1f m)" % hero.global_position.distance_to(start)
			if foe.is_standing() and foe.health >= foe.max_health():
				return "le mort sur le chemin n'est pas frappé"
			return "",
		&"tombee": func() -> String:
			var foes: Array[Enemy] = []
			for offset: Vector3 in [Vector3(0.0, 0.0, -7.0), Vector3(1.0, 0.0, -7.5), Vector3(-1.0, 0.0, -6.5)]:
				foes.append(arena.spawn(&"depouille", offset, false))
			if not _cast(hero, &"tombee"):
				return "il ne part pas"
			await get_tree().create_timer(1.1).timeout
			if hero.global_position.distance_to(Vector3(0.0, 0.0, -7.0)) > 3.0:
				return "le bond ne mène pas au groupe"
			for foe in foes:
				if not foe.is_down():
					return "un mort du groupe reste debout"
			return "",
		&"requiem": func() -> String:
			var foe := arena.spawn(&"boucher", Vector3(0.0, 0.0, -2.2), false)
			# Figé : il ne charge ni ne frappe pendant l'essai.
			foe.set_physics_process(false)
			if not _cast(hero, &"requiem"):
				return "il ne part pas"
			await get_tree().create_timer(1.1).timeout
			if not foe.is_rent():
				return "la garde du Boucher n'est pas fendue"
			foe.take_hit(hero.global_position, 1)
			if not foe.is_down():
				return "le coup suivant n'abat pas le mort fendu"
			return "",
		&"litanie": func() -> String:
			var foe := arena.spawn(&"crieur", Vector3(0.0, 0.0, -2.0), false)
			if not _cast(hero, &"litanie"):
				return "il ne part pas"
			await get_tree().create_timer(1.3).timeout
			if not foe.is_down():
				return "le Crieur n'est pas abattu par la rafale"
			return "",
		&"cierge": func() -> String:
			var foe := arena.spawn(&"depouille", Vector3(1.5, 0.0, 0.0), false)
			foe.take_hit(hero.global_position, 999)
			foe.rise_delay = 1.0
			if not _cast(hero, &"cierge"):
				return "il ne part pas"
			await get_tree().create_timer(2.5).timeout
			if not foe.is_down() or foe.rise_rate() != 0.0:
				return "le corps dans la lueur se relève"
			for candle in get_tree().get_nodes_in_group(&"candles"):
				candle.queue_free()
			await _frames(2)
			foe.give_rest()
			return "",
		&"absoute": func() -> String:
			var foe := arena.spawn(&"depouille", Vector3(0.0, 0.0, -9.0), false)
			hero.face(Vector3(0.0, 0.0, -1.0))
			if not _cast(hero, &"absoute"):
				return "il ne part pas"
			await get_tree().create_timer(1.2).timeout
			if foe.is_standing() and foe.health >= foe.max_health():
				return "la lame n'a pas touché le mort à 9 m"
			return "",
		&"rappel": func() -> String:
			hero.last_rest_time = -1.0
			Progress.embers = RiteData.MAX_EMBERS
			Progress.rite_slots = [&"rappel", &"", &""]
			hero.embers = RiteData.MAX_EMBERS
			hero.rite_slots = Progress.rite_slots.duplicate()
			if hero.cast_slot(0):
				return "il part sans Repos donné"
			hero.last_rest_position = hero.global_position + Vector3(1.0, 0.0, 0.0)
			hero.last_rest_time = hero.clock
			var foe := arena.spawn(&"depouille", Vector3(5.0, 0.0, 0.0), false)
			if not _cast(hero, &"rappel"):
				return "il ne part pas"
			if not await _until(func() -> bool: return not get_tree().get_nodes_in_group(&"hittable").has(foe) or foe.health < foe.max_health(), 6.0):
				return "le mort rappelé ne frappe pas"
			return "",
	}
	for rite_id: StringName in RiteData.ORDER:
		_clear_arena(arena)
		await _frames(3)
		hero.global_position = Vector3.ZERO
		hero.heal(1000)
		hero.state = Hero.State.MOVE
		var problem: String = await (checks[rite_id] as Callable).call()
		if problem != "":
			return _fail("rite %s : %s" % [RiteData.RITES[rite_id]["name"], problem])
		await get_tree().create_timer(0.6).timeout
	_clear_arena(arena)
	await _frames(3)
	print("test réussi : les braises, et les neuf rites de combat (%s)" % ", ".join(RiteData.ORDER.map(func(id: StringName) -> String: return RiteData.RITES[id]["name"])))

	# Les boutons : ni chevauchement, ni sortie d'écran, ni nom de rite qui
	# touche un bouton, sur le téléphone de l'auteur (19,5:9) comme en 16:9.
	for screen: Vector2 in [Vector2(1560.0, 720.0), Vector2(1280.0, 720.0)]:
		var problems := arena.controls.layout_problems(screen)
		if not problems.is_empty():
			return _fail("disposition des boutons en %s : %s" % [screen, ", ".join(problems)])

	# Requiem sans cible : refusé, sans rien coûter.
	Progress.embers = RiteData.MAX_EMBERS
	Progress.rite_slots = [&"requiem", &"", &""]
	hero.embers = RiteData.MAX_EMBERS
	hero.rite_slots = Progress.rite_slots.duplicate()
	if hero.cast_slot(0) or Progress.embers != RiteData.MAX_EMBERS:
		return _fail("le Requiem part, ou coûte, sans mort à portée")

	# Le carnet : on voit un rite, on le porte ; l'animation tourne même en pause.
	for level_id: StringName in [&"la_grille", &"les_allees", &"la_chapelle", &"l_ossuaire", &"la_fosse", &"les_etals"]:
		Progress.mark_completed(level_id)
	arena.open_book()
	await get_tree().process_frame
	var book := arena.book
	book.show_rite(&"litanie")
	var worn_before := Progress.rite_slots.duplicate()
	if book.wear_rite(1) or Progress.rite_slots != worn_before:
		return _fail("en plein niveau, le carnet change les rites portés")
	book.in_level = false
	if not book.wear_rite(1) or Progress.rite_slots[1] != &"litanie":
		return _fail("le carnet ne porte pas la Litanie à l'emplacement 2")
	book.show_rite(&"rappel")
	if book.wear_rite(2):
		return _fail("le carnet porte un rite encore fermé")
	var previews := book.find_children("*", "RitePreview", true, false)
	if previews.is_empty():
		return _fail("le carnet ne montre pas l'animation du rite")
	var preview := previews[0] as RitePreview
	var before := preview.phase()
	await _frames(20)
	if is_equal_approx(preview.phase(), before):
		return _fail("l'animation du rite ne tourne pas, carnet ouvert")
	book.close_book()
	await get_tree().process_frame

	# Chaque rite a son animation et son icône (elles se dessinent sans erreur).
	var canvas := Control.new()
	canvas.size = Vector2(400.0, 300.0)
	arena.hud.add_child(canvas)
	canvas.draw.connect(func() -> void:
		for k in RiteData.ORDER.size():
			RiteIcons.draw(canvas, RiteData.ORDER[k], Vector2(40.0 + 40.0 * k, 40.0), 18.0))
	for rite_id: StringName in RiteData.ORDER:
		var anim := RitePreview.new(Vector2(160.0, 90.0))
		anim.rite = rite_id
		canvas.add_child(anim)
	canvas.queue_redraw()
	await _frames(10)
	canvas.queue_free()

	# Braises et emplacements sont gardés par la sauvegarde.
	Progress.embers = 4
	Progress.rite_slots = [&"tombee", &"glas", &"absoute"]
	Progress.save()
	Progress.reset()
	Progress.load_save()
	if Progress.embers != 4 or Progress.rite_slots != [&"tombee", &"glas", &"absoute"]:
		return _fail("braises ou rites portés perdus à la sauvegarde : %d, %s" % [Progress.embers, Progress.rite_slots])
	_passive = false
	print("test réussi : le carnet porte les rites, animations et icônes, sauvegarde")
	return true


## Lance un rite comme le ferait le joueur, avec toutes les braises.
func _cast(hero: Hero, rite_id: StringName) -> bool:
	Progress.embers = RiteData.MAX_EMBERS
	Progress.rite_slots = [rite_id, &"", &""]
	hero.embers = RiteData.MAX_EMBERS
	hero.rite_slots = Progress.rite_slots.duplicate()
	return hero.cast_slot(0)


func _clear_arena(arena: Arena) -> void:
	for enemy in arena.enemies().duplicate():
		arena._enemies.erase(enemy)
		enemy.queue_free()
	for group: StringName in [&"bodies", &"candles"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	for node in arena.get_children():
		if node is RiteAlly or node is RiteBlade:
			node.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Le moulin : la boutique, les conversations, les rites, l'entrée et la sortie.
## La cour d'armes : le parcours guidé va jusqu'au bout (le joueur automatique
## se bat, le test fait les gestes demandés), rien de la partie ne change
## (souvenirs, or, braises, fioles), le héros n'y tombe pas, l'entraînement
## libre ne fait venir que des morts déjà rencontrés, hors boss.
func _training_tests() -> bool:
	var before := [Progress.memories, Progress.gold, Progress.embers, Progress.flasks, Progress.hero_level]
	main.load_level(&"cour_d_armes")
	var yard := _level() as CourDArmes
	await get_tree().create_timer(0.5).timeout
	var hero := yard.hero
	hero.rite_slots = [&"glas", &"", &""]
	yard.run_course()
	var finished := await _until(func() -> bool:
		var steps := yard.course_steps
		if &"rest" in steps and not &"dodge" in steps:
			yard.controls.press_dodge()
		elif &"dodge" in steps and not &"flask" in steps and hero.state == Hero.State.MOVE:
			yard.controls.flask_pressed.emit()
		elif &"flask" in steps and not &"lock" in steps and hero.lock_target == null and yard.standing_count() > 0:
			yard.controls.press_lock()
		elif &"lock" in steps and not &"rite" in steps and yard.standing_count() > 0:
			hero.cast_slot(0)
		return &"done" in steps, 400.0)
	if not finished:
		return _fail("le parcours de la cour d'armes ne va pas au bout (étapes : %s)" % [yard.course_steps])
	for step: StringName in [&"move", &"strike", &"rest", &"dodge", &"flask", &"lock", &"rite"]:
		if not step in yard.course_steps:
			return _fail("le parcours saute l'étape %s" % step)
	if Progress.has_met(&"boucher") and not &"armor" in yard.course_steps:
		return _fail("le parcours oublie le mort à armure déjà rencontré")
	var after := [Progress.memories, Progress.gold, Progress.embers, Progress.flasks, Progress.hero_level]
	if after != before:
		return _fail("l'entraînement change la partie : %s devient %s" % [before, after])
	if Progress.is_completed(&"cour_d_armes"):
		return _fail("la cour d'armes est enregistrée comme un niveau")

	# L'entraînement libre : un mort rencontré vient, un boss ou un inconnu non.
	var count := yard.enemies_left()
	yard.choose(&"spawn_depouille")
	yard.choose(&"spawn_le_sonneur")
	yard.choose(&"spawn_sonneur")
	if yard.enemies_left() != count + 1:
		return _fail("l'entraînement libre fait venir un boss, ou pas la Dépouille")
	for id: StringName in yard.sparring_types():
		if id != &"depouille" and not Progress.has_met(id):
			return _fail("l'entraînement libre propose %s, jamais rencontré" % id)
	yard.choose(&"clear")
	await _frames(2)
	if yard.enemies_left() != 0:
		return _fail("Renvoyer les morts ne vide pas la cour")
	print("test réussi : la cour d'armes (parcours de %d étapes, aucun gain, entraînement libre)" % yard.course_steps.size())
	return true


func _refuge_tests() -> bool:
	# --- L'équipement, sans l'écran.
	Progress.reset()
	Progress.add_gold(100)
	if Progress.gear_blocker(&"rondache") != "or" or Progress.buy_gear(&"rondache"):
		return _fail("on peut acheter sans avoir assez d'or")
	if Progress.equipped_id(&"shield") != &"ecu_rectangle" or Progress.equipped_id(&"weapon") != &"epee":
		return _fail("l'équipement de départ n'est pas l'écu rectangulaire et l'épée")
	if Progress.gear_blocker(&"epee") != "possede":
		return _fail("l'épée de base devrait déjà être possédée")
	Progress.add_gold(2000)
	var gold := Progress.gold
	if not Progress.buy_gear(&"ecu_insigne") or Progress.gold != gold - 140:
		return _fail("l'achat de l'écu à l'insigne n'a pas coûté 140 or")
	if Progress.equipped_id(&"shield") != &"ecu_insigne":
		return _fail("un objet acheté n'est pas équipé tout de suite")
	if int(Progress.hero_stats()["max_health"]) != 100 + 25:
		return _fail("l'écu à l'insigne n'ajoute pas 25 de vie")
	Progress.equip(&"ecu_rectangle")
	if int(Progress.hero_stats()["max_health"]) != 100 or absf(float(Progress.hero_stats()["guard"]) - 0.2) > 0.001:
		return _fail("changer d'écu ne change pas les effets")
	Progress.buy_gear(&"rondache")
	Progress.buy_gear(&"ecu_pointes")
	Progress.buy_gear(&"lame_longue")
	Progress.buy_gear(&"hache")
	var stats := Progress.hero_stats()
	if not is_equal_approx(float(stats["damage_scale"]), 1.45) or not is_equal_approx(float(stats["attack_speed"]), 0.8) \
			or int(stats["thorns"]) != 8:
		return _fail("les effets de la hache et de l'écu à pointes ne s'appliquent pas : %s" % [stats])
	Progress.equip(&"rondache")
	if absf(float(Progress.hero_stats()["guard"]) - 0.4) > 0.001 or not is_equal_approx(float(Progress.hero_stats()["speed_scale"]), 0.95):
		return _fail("la rondache n'a pas ses effets")
	Progress.save()
	var kept := Progress.owned.duplicate()
	var kept_equipped := Progress.equipped.duplicate()
	Progress.reset()
	Progress.load_save()
	if Progress.owned != kept or Progress.equipped != kept_equipped:
		return _fail("l'équipement n'est pas relu de la sauvegarde")
	print("test 13 réussi : équipement (achat, effets, sauvegarde)")

	# Les anciens achats de la boutique sont remboursés.
	Progress.reset()
	var legacy := FileAccess.open(Progress.save_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 1, "gold": 10, "purchases": {"gambison": 1, "lame": 2, "bottes": 1}}))
	legacy.close()
	Progress.load_save()
	if Progress.gold != 10 + 100 + 120 + 320 + 160:
		return _fail("les anciens achats ne sont pas remboursés (or : %d)" % Progress.gold)
	print("test 13 réussi : les anciens achats sont remboursés")

	# Le modèle montre exactement ce qui est équipé.
	var preview := Gear.PARTS
	var knight := (load("res://assets/kaykit/adventurers/Knight.glb") as PackedScene).instantiate() as Node3D
	add_child(knight)
	Gear.apply(knight, {&"shield": &"ecu_pointes", &"weapon": &"hache"})
	var shown: Array[String] = []
	for part_name in preview:
		if (knight.find_child(part_name, true, false) as Node3D).visible:
			shown.append(part_name)
	if shown != ["Spike_Shield"] or knight.find_child(Gear.EXTRA_NAME, true, false) == null:
		return _fail("le chevalier ne montre pas l'écu à pointes et la hache (pièces : %s)" % [shown])
	Gear.apply(knight, {&"shield": &"rondache", &"weapon": &"lame_longue"})
	shown.clear()
	for part_name in preview:
		if (knight.find_child(part_name, true, false) as Node3D).visible:
			shown.append(part_name)
	if shown != ["Round_Shield", "2H_Sword"] or knight.find_child(Gear.EXTRA_NAME, true, false) != null:
		return _fail("changer d'équipement ne remplace pas les pièces visibles (%s)" % [shown])
	knight.queue_free()
	for id: StringName in Gear.ITEMS:
		if not ResourceLoader.exists(ShopScreen.ICONS + "%s.png" % id):
			return _fail("l'icône de %s manque" % id)
	print("test 13 réussi : les pièces visibles sur le héros suivent l'équipement, chaque objet a son icône")

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

	# --- Les rites supérieurs, sans l'écran.
	Progress.reset()
	Progress.skill_points = 10
	if Progress.advanced_blocker(&"garde_ferme") != "niveau" or Progress.learn_advanced(&"garde_ferme"):
		return _fail("un rite supérieur s'apprend sans avoir terminé son niveau")
	Progress.mark_completed(&"la_chapelle")
	Progress.mark_completed(&"l_ossuaire")
	Progress.mark_completed(&"la_fosse")
	var plain := Progress.hero_stats()
	if not Progress.learn_advanced(&"garde_ferme") or not Progress.learn_advanced(&"veillee") or not Progress.learn_advanced(&"elan"):
		return _fail("les rites supérieurs n'ont pas pu être appris")
	if Progress.skill_points != 10 - 2 - 2 - 3:
		return _fail("les rites supérieurs n'ont pas coûté leurs points (%d restants)" % Progress.skill_points)
	if Progress.learn_advanced(&"elan") or Progress.advanced_blocker(&"elan") != "appris":
		return _fail("un rite supérieur peut être appris deux fois")
	var trained := Progress.hero_stats()
	if absf(float(trained["guard"]) - float(plain["guard"]) - 0.15) > 0.001 or int(trained["rest_heal"]) != int(plain["rest_heal"]) + 8 \
			or absf(float(trained["dodge_extra"]) - 0.12) > 0.001:
		return _fail("les effets des rites supérieurs ne s'ajoutent pas : %s" % [trained])
	Progress.save()
	Progress.advanced = {}
	Progress.load_save()
	if not Progress.has_advanced(&"veillee"):
		return _fail("les rites supérieurs ne sont pas relus de la sauvegarde")
	if Progress.forget_skills() != 7 or Progress.skill_points != 10 or not Progress.advanced.is_empty():
		return _fail("oublier les rites ne rend pas les points des rites supérieurs (%d)" % Progress.skill_points)
	if Progress.advanced_blocker(&"elan") != "":
		return _fail("un rite oublié ne peut pas être réappris")
	print("test 13 réussi : rites supérieurs (déblocage, coût, effets, sauvegarde, remboursement)")

	# --- Dans le moulin.
	Progress.reset()
	Progress.add_gold(500)
	main.load_level(&"refuge")
	var level := _level() as Refuge
	await _frames(4)
	var hero := level.hero
	if hero.interaction_label != "":
		return _fail("une interaction est proposée au départ (« %s »)" % hero.interaction_label)
	# Le héros qui force vers le sud bute sur le portail, sur le sol du moulin :
	# il ne marche jamais dans le noir au-delà.
	level.objective = Vector3(0.0, 0.0, 20.0)
	await _frames(150)
	level.objective = null
	await _frames(3)
	if hero.global_position.z > 11.0 or hero.global_position.z < 8.0:
		return _fail("le héros n'est pas arrêté par le portail du moulin (z = %.1f)" % hero.global_position.z)
	if hero.interaction_label != "PARTIR":
		return _fail("PARTIR n'est pas proposé devant le portail")
	print("test 13 réussi : le portail du moulin arrête le héros, PARTIR est proposé devant")
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
	if not level.shop.buy(&"ecu_insigne"):
		return _fail("l'achat depuis l'écran de la boutique a échoué")
	var after_gear := Progress.gold
	if after_gear != before - 140:
		return _fail("l'écu à l'insigne n'a pas coûté 140 or (or %d sur %d)" % [after_gear, before])
	level.shop.show_tab(&"fioles")
	Progress.flasks = 1
	if not level.shop.buy_flask() or Progress.flasks != 2 or Progress.gold != after_gear - int(Supplies.FLASK["cost"]):
		return _fail("l'onglet Fioles n'a pas vendu une fiole au bon prix")
	level.shop.show_tab(&"vivres")
	Progress.packed_meal = &""
	var gold_before_meal := Progress.gold
	if not level.shop.pack(&"jambon") or Progress.packed_meal != &"jambon" \
			or Progress.gold != gold_before_meal - int(Supplies.MEALS[&"jambon"]["cost"]):
		return _fail("l'onglet Vivres n'a pas emballé le jambon au bon prix")
	Progress.packed_meal = &""
	Progress.flasks = 0
	Progress.gold = after_gear
	level.shop.close()
	await _frames(3)
	if Progress.gold != after_gear or hero.max_health != int(Progress.hero_stats()["max_health"]) or hero.max_health != 125:
		return _fail("l'achat n'a pas changé la vie du héros (%d)" % hero.max_health)
	if not (hero._model.find_child("Badge_Shield", true, false) as Node3D).visible \
			or (hero._model.find_child("Rectangle_Shield", true, false) as Node3D).visible:
		return _fail("le héros ne porte pas l'écu à l'insigne qu'il vient d'acheter")
	if not Progress.has_heard(&"maud_1") or get_tree().paused:
		return _fail("la conversation n'est pas marquée entendue, ou le jeu reste en pause")
	print("test 13 réussi : on parle à Maud et on achète au moulin")

	# L'onglet Équipement du carnet : on change d'écu, le héros le porte.
	Progress.add_gold(2000)
	Progress.buy_gear(&"rondache")
	Progress.equip(&"ecu_rectangle")
	await _frames(2)
	level.open_book()
	level.book.show_tab(&"equipement")
	if not level.book.equip(&"rondache"):
		return _fail("le carnet n'a pas équipé la rondache")
	await _frames(3)
	if not (hero._model.find_child("Round_Shield", true, false) as Node3D).visible or not is_equal_approx(hero.speed_scale, 0.95):
		return _fail("le héros ne porte pas la rondache, ou n'en a pas la vitesse (%.2f)" % hero.speed_scale)
	level.book.close_book()
	print("test 13 réussi : le carnet change l'équipement, le héros le porte et en a les effets")

	# Le carnet ordinaire apprend les rites, où que l'on soit.
	Progress.skill_points = 3
	level.open_book()
	var learned: bool = level.book.learn(&"priere_breve")
	level.book.close_book()
	if not learned or Progress.rank_of(&"priere_breve") != 1:
		return _fail("le carnet n'apprend plus de rite")
	Progress.learn(&"tranchant")
	if Progress.skill_points != 1:
		return _fail("les points ne sont pas dépensés (%d)" % Progress.skill_points)

	# Anselme fait désapprendre : tous les points reviennent.
	hero.global_position = Vector3(-7.4, 0.0, -7.4)
	await _frames(3)
	if hero.interaction_label != "PARLER":
		return _fail("le bouton ne propose pas PARLER près d'Anselme")
	level.talk_to_nearest()
	await _frames(2)
	level.dialogue.close(&"forget")
	await _frames(2)
	level.dialogue.close(&"leave")
	await _frames(2)
	if Progress.rank_of(&"priere_breve") != 1:
		return _fail("refuser d'oublier a pourtant effacé un rite")
	level.talk_to_nearest()
	await _frames(2)
	level.dialogue.close(&"forget")
	await _frames(2)
	level.dialogue.close(&"forget_yes")
	await _frames(2)
	level.dialogue.close(&"leave")
	await _frames(2)
	if Progress.rank_of(&"priere_breve") != 0 or Progress.rank_of(&"tranchant") != 0 or Progress.skill_points != 3:
		return _fail("oublier les rites ne rend pas tous les points (%d au lieu de 3)" % Progress.skill_points)
	if get_tree().paused:
		return _fail("le jeu est resté en pause après la conversation d'Anselme")
	print("test 13 réussi : le carnet apprend partout, Anselme fait tout désapprendre")

	# Les rites supérieurs, chez Anselme : fermés tant que le niveau n'est pas fait.
	level.talk_to_nearest()
	await _frames(2)
	level.dialogue.close(&"advanced")
	await _frames(2)
	if level.advanced_screen == null:
		return _fail("l'écran des rites supérieurs ne s'ouvre pas chez Anselme")
	if level.advanced_screen.learn(&"garde_ferme"):
		return _fail("un rite supérieur s'apprend sans avoir terminé la Chapelle")
	Progress.mark_completed(&"la_chapelle")
	Progress.skill_points += 3
	if not level.advanced_screen.learn(&"garde_ferme"):
		return _fail("le rite supérieur n'a pas pu être appris une fois la Chapelle terminée")
	level.advanced_screen.close()
	await _frames(3)
	if absf(hero.guard - float(Progress.hero_stats()["guard"])) > 0.001 or get_tree().paused:
		return _fail("le héros n'a pas la garde du rite supérieur, ou le jeu est resté en pause")
	print("test 13 réussi : Anselme enseigne un rite supérieur à qui a terminé le niveau")

	# Tibert montre le bestiaire : seuls les morts rencontrés y figurent.
	Progress.meet(&"depouille")
	Progress.meet(&"sonneur")
	hero.global_position = Vector3(-2.6, 0.0, -10.6)
	await _frames(3)
	if hero.interaction_label != "PARLER":
		return _fail("le bouton ne propose pas PARLER près de Tibert")
	level.talk_to_nearest()
	await _frames(2)
	level.dialogue.close(&"bestiary")
	await _frames(2)
	if level.bestiary == null:
		return _fail("le bestiaire ne s'ouvre pas chez Tibert")
	if level.bestiary.known_count() != 2:
		return _fail("le bestiaire montre %d fiches au lieu de 2" % level.bestiary.known_count())
	level.bestiary.select(&"sonneur")
	if level.bestiary.shown_name() != "Le Sonneur":
		return _fail("la fiche du Sonneur n'affiche pas son nom")
	level.bestiary.select(&"veuve")
	if level.bestiary.shown_name() != "???":
		return _fail("un mort non rencontré apparaît dans le bestiaire")
	level.bestiary.close()
	await _frames(2)
	if get_tree().paused:
		return _fail("le jeu est resté en pause après le bestiaire")
	print("test 13 réussi : Tibert montre le bestiaire, les inconnus restent des silhouettes")

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
	# « Mise à jour » : versions comparées, résultat affiché (sans réseau).
	if not UpdateCheck.is_newer("0.26.1", "0.26.0") or UpdateCheck.is_newer("0.26.0", "0.26.0") \
			or UpdateCheck.is_newer("0.9.0", "0.10.0") or not UpdateCheck.is_newer("1.0", "0.99.9"):
		return _fail("la comparaison des versions se trompe")
	if UpdateCheck.version_from_notes("Version 0.27.0. Build de test automatique") != "0.27.0" \
			or UpdateCheck.version_from_notes("Build de test") != "":
		return _fail("la version n'est pas lue dans les notes de la page")
	title.show_update_result("new", "9.0.0")
	if not title._download_button.visible or not title.update_text().contains("9.0.0"):
		return _fail("une nouvelle version n'est pas proposée au téléchargement")
	title.show_update_result("ok", UpdateCheck.local_version())
	if title._download_button.visible or not title.update_text().contains("à jour"):
		return _fail("un jeu à jour propose quand même un téléchargement")
	title._show_panel(null)
	print("test réussi : le bouton Mise à jour compare les versions")
	Progress.add_gold(10)
	title.refresh()
	if not title.has_continue():
		return _fail("« Continuer » n'est pas proposé avec une partie")
	title.press_new_game()
	if not title.is_confirming() or Progress.gold != 10:
		return _fail("« Nouvelle partie » n'a pas demandé confirmation, ou a effacé avant")
	title.confirm_new_game()
	await get_tree().process_frame
	if Progress.gold != 0 or Progress.memories != 0 or Progress.flasks != Supplies.START_FLASKS:
		return _fail("la nouvelle partie n'a pas remis la progression à zéro (or %d, fioles %d)" % [Progress.gold, Progress.flasks])
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
	level.completed.connect(func() -> void:
		_completed = true
		# Chaque niveau finit sur le bandeau de victoire, puis se ferme.
		_victory_seen = level.hud.victory_shown())


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
	print("carte : %d triangles dessinés, %d commandes de dessin, ville %d triangles en tout" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		map._world.city.triangle_count()])
	map.select_level(&"l_ossuaire")
	await get_tree().create_timer(0.4).timeout
	await _shoot("map_02_choix")
	map.select_level(&"la_chapelle")
	await get_tree().create_timer(0.3).timeout
	await _shoot("map_03_ferme")
	map.scroll_to(2760.0, 0.62)
	await get_tree().create_timer(0.4).timeout
	await _shoot("map_08_moulin")
	for step in [[1700.0, "map_04_citadelle"], [1100.0, "map_05_cathedrale"], [400.0, "map_06_palais"]]:
		map.scroll_to(step[0], 0.5)
		await get_tree().create_timer(0.3).timeout
		await _shoot(step[1])
	map.scroll_to(2300.0)
	map.open_book()
	await get_tree().create_timer(0.4).timeout
	await _shoot("map_07_carnet")
	if map._book != null and is_instance_valid(map._book):
		map._book.close_book()
	await get_tree().create_timer(0.3).timeout
	# De près, et la plongée du corbeau vers un niveau.
	map.scroll_to(2300.0)
	map._set_zoom(0.6)
	await get_tree().create_timer(0.3).timeout
	await _shoot("map_09_pres")
	map._set_zoom(1.0)
	# Les rites : la fiche d'un rite qui s'ouvre, le carnet, les boutons en jeu.
	for level_id: StringName in [&"la_grille", &"les_allees", &"la_chapelle", &"l_ossuaire"]:
		Progress.mark_completed(level_id)
	Progress.embers = 3
	map.show_next_rite()
	await get_tree().create_timer(1.2).timeout
	await _shoot("map_12_rite_nouveau")
	while map.show_next_rite():
		pass
	map.open_book()
	await get_tree().process_frame
	map._book.show_rite(&"tombee")
	await get_tree().create_timer(1.0).timeout
	await _shoot("map_13_carnet_combat")
	map._book.close_book()
	await get_tree().create_timer(0.2).timeout
	map.select_level(&"l_ossuaire")
	await get_tree().create_timer(0.3).timeout
	await _shoot("map_15_fiche_rites")
	map.open_rite_picker(1)
	await get_tree().create_timer(0.3).timeout
	await _shoot("map_16_choix_rite")
	map._close_rite_picker()
	map.cinematics = true
	map.select_level(&"la_chapelle")
	map.enter_selected()
	await get_tree().create_timer(0.7).timeout
	await _shoot("map_10_plongee_a")
	await get_tree().create_timer(0.55).timeout
	await _shoot("map_11_plongee_b")
	await get_tree().create_timer(2.5).timeout
	await _shoot("map_14_jeu_rites")
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
	Progress.mark_completed(&"la_chapelle")
	Progress.skill_points = 4
	Progress.add_gold(700)
	Progress.add_memories(300)
	Progress.flasks = 2
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
	await get_tree().create_timer(0.8).timeout
	level.shop.select(&"ecu_pointes")
	await get_tree().create_timer(0.8).timeout
	await _shoot("refuge_05_boutique")
	level.shop.select(&"hache")
	await get_tree().create_timer(0.8).timeout
	await _shoot("refuge_05b_hache")
	level.shop.show_tab(&"fioles")
	await get_tree().create_timer(0.8).timeout
	await _shoot("refuge_05d_fioles")
	level.shop.show_tab(&"vivres")
	level.shop.selected_meal = &"ragout"
	level.shop.show_tab(&"vivres")
	await get_tree().create_timer(0.5).timeout
	await _shoot("refuge_05e_vivres")
	level.shop.buy(&"hache")
	level.shop.close()
	level.open_book()
	level.book.show_tab(&"equipement")
	await get_tree().create_timer(0.8).timeout
	await _shoot("refuge_05c_carnet")
	level.book.close_book()
	level.objective = Vector3(-7.4, 0.0, -7.4)
	await get_tree().create_timer(4.0).timeout
	await _shoot("refuge_06_anselme")
	level.talk_to_nearest()
	await get_tree().create_timer(0.3).timeout
	level.dialogue.close(&"advanced")
	await get_tree().create_timer(0.8).timeout
	await _shoot("refuge_07_sup")
	level.advanced_screen.close()
	for type_id: StringName in [&"depouille", &"archer_creux", &"porte_cloche", &"fouisseur", &"sonneur"]:
		Progress.meet(type_id)
		Progress.rests[String(type_id)] = 7
	level.objective = Vector3(-2.6, 0.0, -10.4)
	await get_tree().create_timer(3.4).timeout
	level.talk_to_nearest()
	await get_tree().create_timer(0.3).timeout
	level.dialogue.close(&"bestiary")
	await get_tree().create_timer(0.6).timeout
	level.bestiary.select(&"sonneur")
	await get_tree().create_timer(0.3).timeout
	await _shoot("refuge_08_bestiaire")
	level.bestiary.select(&"veuve")
	await get_tree().create_timer(0.3).timeout
	await _shoot("refuge_09_inconnu")
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
