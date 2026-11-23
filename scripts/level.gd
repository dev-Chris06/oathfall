class_name Level
extends Node3D
## Base commune des niveaux.
##
## Un niveau construit son décor (`_build`), puis déroule son scénario
## (`_run`) à partir d'un point de reprise. Il fournit le héros, la caméra,
## l'affichage, l'apparition des morts et quelques outils d'écriture :
## attendre, parler, attendre qu'une zone soit atteinte ou en paix.
##
## Le héros qui tombe se relève au dernier point de reprise : c'est `Main`
## qui recharge alors le niveau avec `start_checkpoint`.

## Le niveau est terminé.
signal completed
## Le héros a atteint un nouveau point de reprise.
signal checkpoint_reached(index: int)
## Le héros est tombé ; `Main` décide de la suite.
signal failed
## Le joueur quitte le niveau pour revenir à la carte.
signal quit_requested
## Émis à chaque image de physique ; les scénarios l'attendent plutôt qu'un
## signal de l'arbre, pour s'arrêter net si le niveau est libéré.
signal ticked

const DUNGEON := "res://assets/kaykit/dungeon/"
const GRAVEYARD := "res://assets/kaykit/halloween/"

## Nom affiché à l'entrée du niveau.
var title := ""
## Sous terre : ni lune ni ombre portée, la lumière vient des torches.
var underground := false
## Niveau suivant, s'il existe déjà.
var next_level: StringName = &""
## Point de reprise où commence le scénario.
var start_checkpoint := 0
## Vrai quand un joueur automatique tient les commandes : le niveau ne se
## recharge pas seul et laisse le test décider.
var scripted := false
## Musique du niveau (vide : selon le décor, souterrain ou cimetière).
var music_track: StringName = &""
## Chapitre du niveau : il règle la difficulté des morts (`Enemy.apply_chapter`).
var chapter := 1
## Terrain jouable (x, z, largeur, profondeur), pour habiller ses abords.
var play_area := Rect2()
## Décor des abords (voir `Scenery`) : cimetière par défaut.
var scenery: StringName = &""
## Bord de l'eau, le long du quai (x), ou INF sans eau. Voir `water_edge`.
var water_x := INF
## Étendue du sol dallé, notée par `pave()`.
var floor_bounds := Rect2()

var hero: Hero
var controls: TouchControls
var hud: Hud

## Point que le héros doit rejoindre, s'il y en a un. Sert au joueur
## automatique et au repère affiché dans le décor et à l'écran.
var objective = null
## Entraînement (la cour d'armes) : rien ne se gagne ni ne se dépense pour de
## vrai. Le Repos ne rapporte ni souvenirs, ni or, ni braise de la partie ; les
## braises et les fioles du héros sont prêtées et ne touchent pas à la partie.
var practice := false
## Chance qu'une fiole tombe d'un corps mis au repos (l'arène d'essai la coupe).
var flask_drop_chance := Supplies.FLASK_DROP_CHANCE
## Le carnet des compétences, tant qu'il est ouvert.
var book: SkillBook
## Le menu de pause, tant qu'il est ouvert.
var pause_menu: PauseMenu

var _camera: GameCamera
var _env: Environment
## Vue pour laquelle la brume est réglée (elle s'épaissit en vue libre).
var _env_mode := -1
## Repère d'or au-dessus du mort verrouillé.
var _lock_marker: Node3D
var _guide: Node3D
var _enemies: Array[Enemy] = []
## Morts apparus depuis le début du niveau (numéro d'apparition).
var _spawned := 0
var _lights: Array[OmniLight3D] = []
var _light_base: Array[float] = []
var _time := 0.0
var _hud_timer := 0.0
## Le brouillard du fleuve : il monte tant qu'un Noyé est debout.
var _mist: MeshInstance3D
var _mist_material: StandardMaterial3D
var _mist_amount := 0.0
var _mist_target := 0.0
var _mist_drift := Vector2.ZERO
var _finished := false
var _crier_called := false
## Ce que le niveau a rapporté (souvenirs, or), montré à la victoire.
var _gained_memories := 0
var _gained_gold := 0
var _solids: StaticBody3D
## Les vantaux de chaque grille, et l'obstacle qui la ferme.
var _gates: Array[Dictionary] = []


func _ready() -> void:
	Enemy.mist_hides = false
	Engine.time_scale = 1.0
	_solids = StaticBody3D.new()
	add_child(_solids)
	_build_environment()
	_build()
	_flush_batches()
	if play_area.has_area():
		Scenery.dress(self, Scenery.UNDERGROUND if underground else (scenery if scenery != &"" else Scenery.CEMETERY),
			floor_bounds if floor_bounds.has_area() else play_area, play_area)
	if music_track == &"":
		music_track = &"underground" if underground else &"cemetery"
	Audio.level_track = music_track
	Audio.music(music_track)

	controls = TouchControls.new()
	add_child(controls)

	hero = Hero.new()
	hero.position = _checkpoint_position(start_checkpoint)
	add_child(hero)
	hero.setup(Progress.class_id, controls)
	hero.apply_stats(Progress.hero_stats())

	_camera = GameCamera.new()
	add_child(_camera)
	_camera.follow(hero)
	controls.lock_pressed.connect(toggle_lock)
	_build_lock_marker()

	hud = Hud.new()
	add_child(hud)
	hud.set_health(hero.health, hero.max_health)
	_build_guide()

	hero.hit_landed.connect(_on_hit_landed)
	hero.health_changed.connect(hud.set_health)
	hero.hurt.connect(_on_hero_hurt)
	hero.died.connect(_on_hero_died)
	controls.book_pressed.connect(open_book)
	controls.pause_pressed.connect(open_pause)
	hero.flask_drunk.connect(_on_flask_drunk)
	hero.rite_cast.connect(_on_rite_cast)
	hero.rite_denied.connect(_on_rite_denied)
	Progress.leveled_up.connect(_on_leveled_up)
	Progress.skill_learned.connect(_on_skill_learned)
	Progress.changed.connect(_refresh_progress)
	_refresh_progress()

	_run.call_deferred(start_checkpoint)


func _physics_process(_delta: float) -> void:
	ticked.emit()


func _process(delta: float) -> void:
	_time += delta
	for i in _lights.size():
		var flicker := sin(_time * 9.0 + i * 1.7) * 0.25 + sin(_time * 23.0 + i * 4.1) * 0.12
		_lights[i].light_energy = _light_base[i] + flicker

	_update_view()
	_update_guide()
	_update_mist(delta)

	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.25
		hud.set_counts(standing_count(), get_tree().get_nodes_in_group(&"bodies").size())
		_mist_target = 1.0 if drowned_standing() > 0 else 0.0
		hud.set_debug("Oathfall %s — %s — %d images/s" % [
			ProjectSettings.get_setting("application/config/version", "?"),
			title, Engine.get_frames_per_second()])


# --- Brouillard du fleuve -----------------------------------------------------

const MIST_ALPHA := 0.75


## Noyés debout et hors de l'eau : ce sont eux qui font monter la brume.
func drowned_standing() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"hittable"):
		var drowned := node as DrownedEnemy
		if drowned != null and drowned.is_standing() and not drowned.is_sunk():
			count += 1
	return count


## Vrai quand la brume est assez épaisse pour cacher les corps.
func mist_thick() -> bool:
	return _mist_amount > 0.5


## Une nappe de brume au ras du sol, qui suit le héros : les morts debout la
## dépassent, les corps couchés y disparaissent, et leurs repères s'effacent.
func _update_mist(delta: float) -> void:
	if _mist_target <= 0.0 and _mist_amount <= 0.0:
		return
	_mist_amount = move_toward(_mist_amount, _mist_target, delta / 2.5)
	if _mist == null:
		_build_mist()
	_mist.visible = _mist_amount > 0.0
	_mist.global_position = Vector3(hero.global_position.x, 0.55, hero.global_position.z)
	_mist_material.albedo_color.a = MIST_ALPHA * _mist_amount
	# Le motif reste posé sur le monde (la nappe suit le héros) et dérive lentement.
	_mist_drift += Vector2(0.012, 0.004) * delta
	var tile := 70.0 / 5.0
	_mist_material.uv1_offset = Vector3(hero.global_position.x / tile + _mist_drift.x,
		hero.global_position.z / tile + _mist_drift.y, 0.0)
	Enemy.mist_hides = mist_thick()


func _build_mist() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.13, 0.16, 0.22, 0.6))
	ramp.set_color(1, Color(0.24, 0.29, 0.36, 1.0))
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	_mist_material = Fx.glow(Color(1.0, 1.0, 1.0, 0.0))
	_mist_material.albedo_texture = texture
	_mist_material.uv1_scale = Vector3(5.0, 5.0, 1.0)
	_mist_material.uv1_world_triplanar = false
	var plane := PlaneMesh.new()
	plane.size = Vector2(70.0, 70.0)
	_mist = MeshInstance3D.new()
	_mist.mesh = plane
	_mist.material_override = _mist_material
	_mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mist)


# --- Vue et cible ----------------------------------------------------------------

## Distance à laquelle on peut verrouiller un mort, et au-delà de laquelle il
## est relâché.
const LOCK_RANGE := 14.0
const LOCK_KEEP := 18.0


## Chaque image : la vue suit le doigt, le joystick suit la vue, la cible est
## tenue ou relâchée, la brume suit la vue choisie.
func _update_view() -> void:
	_camera.look(controls.take_look())
	controls.look_enabled = GameCamera.is_free()
	controls.view_yaw = _camera.view_yaw()
	hero.view_forward = _camera.view_forward() if GameCamera.is_free() else Vector3.ZERO
	if _env_mode != GameCamera.mode:
		_apply_view_environment()

	var target := hero.lock_target
	if target != null and (not is_instance_valid(target) or not target.is_standing()
			or target.global_position.distance_to(hero.global_position) > LOCK_KEEP):
		# La cible tombe ou s'éloigne : on passe au mort le plus proche, s'il y en a.
		var was_valid := target != null and is_instance_valid(target)
		set_lock(pick_lock_target(10.0) if was_valid and not target.is_standing() else null)
	target = hero.lock_target
	_lock_marker.visible = target != null
	if target != null:
		_lock_marker.global_position = target.global_position + Vector3(0.0, 4.6 if target.is_boss() else 2.5, 0.0)
		_lock_marker.rotation.y += get_process_delta_time() * 2.5


## Bouton CIBLE : verrouille le mort le plus en vue, ou relâche la cible.
func toggle_lock() -> void:
	if hero.lock_target != null:
		set_lock(null)
	else:
		set_lock(pick_lock_target(LOCK_RANGE))
		if hero.lock_target == null:
			hud.show_message("Aucun mort debout à portée.", 1.2)


func set_lock(target: Enemy) -> void:
	hero.lock_target = target
	_camera.lock_target = target
	controls.lock_active = target != null


## Le mort debout le plus en vue : proche, et devant le regard (ou devant le
## héros en vue classique).
func pick_lock_target(reach: float) -> Enemy:
	var forward := _camera.view_forward() if GameCamera.is_free() else hero.facing()
	var best: Enemy = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"hittable"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_standing():
			continue
		var to := enemy.global_position - hero.global_position
		to.y = 0.0
		var distance := to.length()
		if distance > reach:
			continue
		var angle := forward.angle_to(to) if distance > 0.1 else 0.0
		var score := distance * (1.0 + angle / PI * 1.5)
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _build_lock_marker() -> void:
	_lock_marker = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.28
	cone.bottom_radius = 0.0
	cone.height = 0.5
	cone.radial_segments = 4
	cone.rings = 1
	(_lock_marker as MeshInstance3D).mesh = cone
	(_lock_marker as MeshInstance3D).material_override = Fx.glow(Color(0.95, 0.72, 0.32, 0.9))
	(_lock_marker as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lock_marker.visible = false
	add_child(_lock_marker)


## En vue libre, la caméra voit au loin : une brume plus épaisse, de la couleur
## du fond, efface les bords du terrain et ce qui est trop loin pour le téléphone.
func _apply_view_environment() -> void:
	_env_mode = GameCamera.mode
	if _env == null:
		return
	if GameCamera.is_free():
		_env.background_color = _env.fog_light_color
		_env.fog_density = 0.06
	else:
		_env.background_color = Color(0.015, 0.015, 0.03)
		_env.fog_density = 0.025


# --- Repère de l'objectif -----------------------------------------------------

## Repère posé sur l'objectif : une pointe d'or au-dessus d'une colonne de
## lueur. Quand l'objectif sort de l'écran, une flèche le montre sur le bord.
func _build_guide() -> void:
	_guide = Node3D.new()
	_guide.visible = false
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = 0.0
	cone.height = 0.9
	cone.radial_segments = 4
	cone.rings = 1
	tip.mesh = cone
	tip.material_override = Fx.glow(Color(0.95, 0.72, 0.32, 0.85))
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_guide.add_child(tip)
	var beam := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 0.1
	column.bottom_radius = 0.1
	column.height = 7.0
	column.radial_segments = 6
	column.rings = 1
	beam.mesh = column
	beam.material_override = Fx.glow(Color(0.95, 0.72, 0.32, 0.18))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = -3.8
	_guide.add_child(beam)
	add_child(_guide)


func _update_guide() -> void:
	if _guide == null or _camera == null:
		return
	if objective == null:
		_guide.visible = false
		hud.set_guide(false, Vector2.ZERO, 0.0)
		return
	var target: Vector3 = objective
	_guide.visible = true
	_guide.position = target + Vector3(0.0, 4.6 + sin(_time * 3.0) * 0.25, 0.0)
	_guide.rotation.y = _time * 1.5
	var view := get_viewport().get_visible_rect().size
	var behind := _camera.is_position_behind(target)
	var screen := _camera.unproject_position(target)
	var margin := 70.0
	var inside := not behind and Rect2(Vector2(margin, margin), view - Vector2(margin, margin) * 2.0).has_point(screen)
	if inside:
		hud.set_guide(false, Vector2.ZERO, 0.0)
		return
	var centre := view * 0.5
	var direction := screen - centre
	if behind:
		direction = -direction
	if direction.length() < 1.0:
		direction = Vector2.UP
	direction = direction.normalized()
	# Sur le bord de l'écran, dans la direction de l'objectif.
	var reach_x := (view.x * 0.5 - margin) / maxf(absf(direction.x), 0.001)
	var reach_y := (view.y * 0.5 - margin) / maxf(absf(direction.y), 0.001)
	var at := centre + direction * minf(reach_x, reach_y)
	hud.set_guide(true, at, direction.angle() + PI * 0.5)


# --- À écrire par chaque niveau -----------------------------------------------

## Construit le décor.
func _build() -> void:
	pass


## Déroule le scénario à partir du point de reprise donné.
func _run(_checkpoint: int) -> void:
	pass


## Où se tient le héros au début, ou quand il revient à un point de reprise.
func _checkpoint_position(_index: int) -> Vector3:
	return Vector3.ZERO


# --- Outils d'écriture des scénarios ------------------------------------------

## Attend `seconds` secondes de jeu.
## Le bord de l'eau le plus proche de `from`, ou null s'il n'y a pas d'eau
## dans le niveau. Les corps des Noyés y glissent. Au chapitre III, le fleuve
## longe le quai du côté +X : son bord est la ligne x = `water_x`.
func water_edge(from: Vector3) -> Variant:
	if is_inf(water_x):
		return null
	return Vector3(water_x, 0.0, from.z)


func wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(seconds)
	await timer.timeout
	timer.queue_free()


## Attend que `condition` devienne vraie.
func wait_until(condition: Callable) -> void:
	while not condition.call():
		await ticked


## Affiche un texte et attend qu'il ait été lu.
func say(text: String, seconds := 3.0) -> void:
	hud.show_message(text, seconds)
	await wait(seconds)


## Attend que le héros atteigne la zone de `where` : il en est à moins de
## `radius`, ou il a franchi sa ligne (les niveaux avancent vers -Z). Courir
## sans passer au point exact suffit donc à déclencher la suite.
func reach(where: Vector3, radius := 2.5) -> void:
	objective = where
	await wait_until(func() -> bool: return crossed(where, radius))
	objective = null


## Vrai si le héros est près de `where` ou a dépassé sa ligne vers -Z.
func crossed(where: Vector3, radius: float) -> bool:
	var offset := hero.global_position - where
	offset.y = 0.0
	return offset.length() <= radius or hero.global_position.z <= where.z


## Attend que tous les morts du niveau reposent.
## Attend que tous les morts reposent. Quand il ne reste que des corps au sol
## (le joueur ne les voit peut-être pas : derrière une pierre, au bord de la
## fosse), le repère montre le plus proche et un message dit combien il en
## reste : le niveau n'attend jamais un corps sans dire où il est.
func until_peace() -> void:
	var quiet := [0.0, 0.0]
	await wait_until(func() -> bool:
		if _enemies.is_empty():
			return true
		var delta := get_physics_process_delta_time()
		if standing_count() > 0:
			quiet[0] = 0.0
			if objective is Vector3 and quiet[1] > 0.0:
				objective = null
			quiet[1] = 0.0
			return false
		quiet[0] += delta
		if quiet[0] >= BODY_HINT_DELAY:
			var nearest := _nearest_body_left()
			objective = nearest.body_position() if nearest != null else null
			quiet[1] -= delta
			if quiet[1] <= 0.0:
				quiet[1] = 9.0
				var left := _enemies.size()
				hud.show_message("Il reste %d corps sans repos." % left if left > 1 \
					else "Il reste un corps sans repos.", 3.0)
		return false)
	objective = null


## Délai, sans mort debout, avant de montrer les corps qui attendent le Repos.
const BODY_HINT_DELAY := 5.0


func _nearest_body_left() -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := enemy.body_position().distance_to(hero.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## Fin du niveau : le bandeau de victoire, puis le niveau se ferme et ramène à
## la carte. `line` est la phrase sous le nom du niveau.
const VICTORY_TIME := 4.0


func victory(line := "") -> void:
	objective = null
	controls.visible = false
	Audio.play(&"level_done")
	var gains := "+%d souvenirs    +%d or" % [_gained_memories, _gained_gold] \
		if _gained_memories > 0 or _gained_gold > 0 else ""
	hud.show_victory(title, line, gains)
	await wait(VICTORY_TIME)
	finish()


func mark_checkpoint(index: int) -> void:
	# Le héros reprend son souffle : il retrouve au moins une part de sa vie.
	var floor_health := int(ceil(float(hero.max_health) * Supplies.CHECKPOINT_HEALTH))
	if not hero.is_dead() and hero.health < floor_health:
		hero.heal(floor_health - hero.health)
		hud.show_message("Tu reprends ton souffle.", 2.0)
	checkpoint_reached.emit(index)


func finish() -> void:
	if _finished:
		return
	var celebrated := hud != null and hud.victory_shown()
	_finished = true
	if not celebrated:
		Audio.play(&"level_done")
	completed.emit()


## Morts encore debout, ou en train de sortir de terre.
func standing_count() -> int:
	var count := 0
	for enemy in _enemies:
		if not enemy.is_down():
			count += 1
	return count


## Fait apparaître plusieurs morts du même type ; `rise_delay` positif
## remplace leur délai de relèvement.
func spawn_group(type_id: StringName, points: Array, rise_delay := -1.0) -> void:
	for point: Vector3 in points:
		var enemy := spawn(type_id, point)
		if rise_delay > 0.0:
			enemy.rise_delay = rise_delay


# --- Grilles ------------------------------------------------------------------

## Pose une grille fermée (modèle du pack de cimetière à deux vantaux).
## Elle bloque le passage jusqu'à `open_gate`. `checkpoint` est le point de
## reprise qui se trouve après elle : au retour à ce point, elle est ouverte.
func add_gate(at: Vector3, checkpoint: int, model := "fence_gate", yaw_deg := 0.0, width := 4.2) -> int:
	var node := grave_piece(model, at, yaw_deg)
	var size := Vector3(width, 4.0, 1.4)
	if absf(yaw_deg) > 45.0:
		size = Vector3(1.4, 4.0, width)
	_gates.append({
		"open": false,
		"leaves": [node.find_child("*_left", true, false), node.find_child("*_right", true, false)],
		"blocker": solid(at, size),
		"checkpoint": checkpoint,
	})
	return _gates.size() - 1


func open_gate(index: int, instant := false) -> void:
	var gate := _gates[index]
	if gate["open"]:
		return
	gate["open"] = true
	if not instant:
		Audio.play(&"gate")
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


## Au retour à un point de reprise, les grilles déjà franchies sont ouvertes.
func open_gates_before(checkpoint: int) -> void:
	for i in _gates.size():
		if checkpoint > 0 and int(_gates[i]["checkpoint"]) <= checkpoint:
			open_gate(i, true)


# --- Les morts ----------------------------------------------------------------

## Fait apparaître un mort. Avec `from_grave`, il sort de terre avant
## d'attaquer.
func spawn(type_id: StringName, where: Vector3, from_grave := true) -> Enemy:
	var enemy := Enemy.create(type_id)
	enemy.spawn_index = _spawned
	_spawned += 1
	enemy.position = Vector3(where.x, 0.0, where.z)
	add_child(enemy)
	enemy.setup(type_id, hero)
	enemy.apply_chapter(chapter)
	enemy.rested.connect(_on_enemy_rested)
	enemy.rose.connect(_on_enemy_rose)
	if enemy is CrierEnemy:
		(enemy as CrierEnemy).call_requested.connect(_on_crier_call.bind(enemy))
	_enemies.append(enemy)
	Progress.meet(type_id)
	if from_grave:
		enemy.emerge()
	return enemy


## Un Crieur appelle du renfort : des Dépouilles sortent de terre près de lui,
## sans dépasser neuf morts à la fois.
func _on_crier_call(count: int, crier: Enemy) -> void:
	if not is_instance_valid(crier) or enemies_left() >= 9:
		return
	if not _crier_called:
		_crier_called = true
		hud.show_message("Le Crieur appelle du renfort.\nAbats-le en premier.", 3.5)
	# Du côté du héros : une barrière fermée ne doit jamais isoler un renfort.
	var toward := hero.global_position - crier.global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.1 else Vector3(0.0, 0.0, 1.0)
	var side := toward.cross(Vector3.UP)
	var placed := 0
	for attempt in 16:
		if placed >= count:
			break
		var at := crier.global_position + toward * randf_range(2.0, 4.0) + side * randf_range(-2.5, 2.5)
		if not play_area.has_area() or play_area.grow(-1.2).has_point(Vector2(at.x, at.z)):
			if at.distance_to(hero.global_position) > 2.5:
				spawn(&"depouille", at)
				placed += 1


func enemies() -> Array[Enemy]:
	return _enemies


func enemies_left() -> int:
	return _enemies.size()


func _on_enemy_rose(_enemy: Enemy) -> void:
	hud.show_message("Il se relève.", 1.6)


func _on_enemy_rested(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	if practice:
		# Une braise prêtée, pour essayer les rites.
		hero.embers = mini(hero.embers + 1, RiteData.MAX_EMBERS)
		hud.set_embers(hero.embers)
		return
	_gained_memories += enemy.memories_given()
	_gained_gold += enemy.gold_given()
	Progress.note_rest(enemy.type_id_name)
	Progress.add_memories(enemy.memories_given())
	Progress.add_gold(enemy.gold_given())
	# Chaque Repos donné allume une braise pour les rites de combat.
	Progress.add_ember()
	# Parfois, une fiole tombe du corps apaisé.
	if randf() < flask_drop_chance:
		drop_flask(enemy.body_position())


## Pose une fiole à ramasser au sol.
func drop_flask(where: Vector3) -> FlaskPickup:
	var pickup := FlaskPickup.new()
	pickup.hero = hero
	pickup.position = Vector3(where.x, 0.0, where.z)
	pickup.picked.connect(func() -> void: hud.show_message("Une fiole de baume.", 1.6))
	add_child(pickup)
	return pickup


# --- Progression --------------------------------------------------------------

## Ouvre le carnet des compétences ; le jeu reste en pause tant qu'il est ouvert.
func open_book() -> void:
	if hero.is_dead() or _finished or get_tree().paused:
		return
	book = SkillBook.new()
	book.can_leave = true
	book.in_level = true
	book.leave_requested.connect(_on_leave)
	add_child(book)


## Ouvre le menu de pause ; le jeu s'arrête tant qu'il est ouvert.
func open_pause() -> void:
	if hero.is_dead() or _finished or get_tree().paused:
		return
	pause_menu = PauseMenu.new()
	pause_menu.leave_requested.connect(func() -> void: quit_requested.emit())
	add_child(pause_menu)


func _on_leave() -> void:
	book.close_book()
	quit_requested.emit()


func _refresh_progress() -> void:
	# Un achat ou un rite appris change les caractéristiques tout de suite.
	hero.apply_stats(Progress.hero_stats())
	# À l'entraînement, braises et fioles sont prêtées : la partie ne les écrase pas.
	if not practice:
		hero.flasks = Progress.flasks
		hero.embers = Progress.embers
	hero.rite_slots = Progress.rite_slots.duplicate()
	hud.set_embers(hero.embers)
	hero.apply_gear(Progress.equipped_map())
	hud.set_progress(Progress.hero_level, Progress.level_progress(), Progress.gold)
	controls.book_alert = Progress.skill_points > 0


func _on_rite_cast(_rite_id: StringName, cost: int) -> void:
	if practice:
		hud.set_embers(hero.embers)
		return
	Progress.spend_embers(cost)


func _on_rite_denied(slot: int, reason: String) -> void:
	controls.deny_slot(slot)
	hud.show_message(reason, 1.6)


func _on_flask_drunk() -> void:
	if practice:
		hero.flasks = maxi(hero.flasks - 1, 0)
		hero.heal(int(Supplies.FLASK["heal"]))
		return
	if Progress.use_flask():
		hero.heal(int(Supplies.FLASK["heal"]))


func _on_leveled_up(level: int) -> void:
	hero.apply_stats(Progress.hero_stats())
	hud.show_message("Les souvenirs affluent. Niveau %d.\nUn point de compétence : ouvre le CARNET." % level, 3.5)


func _on_skill_learned(_skill_id: StringName, _rank: int) -> void:
	hero.apply_stats(Progress.hero_stats())


# --- Réactions ----------------------------------------------------------------

func _on_hit_landed(heavy: bool) -> void:
	_camera.shake(0.9 if heavy else 0.45)
	# Bref arrêt sur image : c'est lui qui donne l'impression que le coup pèse.
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.09 if heavy else 0.05, true, false, true).timeout
	Engine.time_scale = 1.0


## Secoue la caméra (coup de cloche, chute).
func shake(amount: float) -> void:
	_camera.shake(amount)


func _on_hero_hurt() -> void:
	_camera.shake(0.7)
	hud.flash_damage()


func _on_hero_died() -> void:
	if scripted:
		var near := []
		for enemy in _enemies:
			if enemy.is_standing():
				near.append("%s %.1f (%d pv)" % [enemy.type_id_name, enemy.global_position.distance_to(hero.global_position), enemy.health])
		print("chute du héros en %s, morts debout : %s" % [hero.global_position.snapped(Vector3.ONE * 0.1), near])
	objective = null
	hud.show_message("Nul ne meurt en Orvana.\nTu te relèves.", 3.5)
	failed.emit()


# --- Décor --------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.015, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.42)
	env.ambient_light_energy = 0.42 if underground else 0.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.09)
	env.fog_density = 0.025
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	_env = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	if underground:
		return
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.22
	moon.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	moon.shadow_enabled = true
	# Une seule passe d'ombre à portée réduite : quatre fois moins coûteux que
	# le réglage par défaut.
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)


## Pose un modèle. `file` est un chemin complet ou un nom de fichier du pack
## Dungeon.
## `cap` pose un bloc de pierre au-dessus d'un mur : c'est automatique pour les
## murs latéraux (lacet ±90°), à demander pour un mur du fond. Jamais pour un
## mur en travers qui peut se trouver entre la caméra et le héros : le bloc
## cacherait le héros.
func place(file: String, pos: Vector3, yaw_deg := 0.0, height_scale := 1.0, cap := false) -> Node3D:
	var path := file if file.begins_with("res://") else DUNGEON + file
	if underground and height_scale >= 0.99 and (cap or absf(sin(deg_to_rad(yaw_deg))) > 0.7) \
			and (path.ends_with("/wall.glb") or path.ends_with("/wall_doorway.glb")):
		# Un bloc de pierre au-dessus du mur, plus haut que la caméra : on ne
		# voit jamais ce qu'il y a derrière.
		_caps.append(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis.from_scale(Vector3(4.02, 8.0, 1.02)),
			pos + Vector3(0.0, 8.0, 0.0)))
	if BATCHED.any(func(name: String) -> bool: return path.ends_with("/" + name)):
		# Les pièces répétées (clôtures, murs) sont regroupées : une commande de
		# dessin par partie de modèle, au lieu d'une par pièce.
		if not _batches.has(path):
			_batches[path] = []
		_batches[path].append(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis.from_scale(Vector3(1.0, height_scale, 1.0)), pos))
		var stub := Node3D.new()
		stub.position = pos
		stub.rotation_degrees.y = yaw_deg
		add_child(stub)
		return stub
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Modèle introuvable : " + path)
		return null
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	add_child(node)
	return node


## Modèles posés en grand nombre, regroupés par `place()`.
const BATCHED := ["fence.gltf", "fence_broken.gltf", "fence_pillar.gltf", "wall.glb"]

## Les pièces regroupées : chemin du modèle -> transformations.
var _batches := {}
## Les blocs posés au-dessus des murs sous terre.
var _caps: Array[Transform3D] = []
## Étendue de chaque modèle regroupé, pour le contrôle des murs visibles.
var _batch_bounds := {}


## Décors du cimetière qui arrêtent le héros et les morts, avec la part de
## l'emprise du modèle qui sert d'obstacle (un tronc est plus étroit que sa
## ramure). Les autres (os, bougies, carreaux) se traversent.
const OBSTACLES := {
	"gravestone": 0.8, "gravemarker_A": 0.8, "gravemarker_B": 0.8, "grave_A_destroyed": 0.8,
	"tree_dead_large": 0.3, "tree_dead_medium": 0.3, "tree_dead_small": 0.3,
	"post_lantern": 0.6, "lantern_standing": 0.6, "post_skull": 0.6,
	"shrine_candles": 0.8, "bench": 0.8,
}


## Pose un modèle du pack de cimetière. S'il est solide (`OBSTACLES`), il
## arrête le passage ; `collide` faux pour ce qui doit bouger (pierres lancées).
func grave_piece(file: String, pos: Vector3, yaw_deg := 0.0, collide := true) -> Node3D:
	var node := place(GRAVEYARD + file + ".gltf", pos, yaw_deg)
	if collide and node != null and OBSTACLES.has(file):
		_add_obstacle(node, float(OBSTACLES[file]))
	return node


## Transformation d'un nœud par rapport à la racine de son modèle (hors arbre).
func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var t := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		t = (parent as Node3D).transform * t
		parent = parent.get_parent()
	return t


## Crée les MultiMesh des pièces regroupées, et les blocs au-dessus des murs.
func _flush_batches() -> void:
	for path: String in _batches:
		var model := (load(path) as PackedScene).instantiate() as Node3D
		var transforms: Array = _batches[path]
		var bounds := AABB()
		var first := true
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var part := node as MeshInstance3D
			if part.mesh == null:
				continue
			var local := _relative(part, model)
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = part.mesh
			multimesh.instance_count = transforms.size()
			for i in transforms.size():
				multimesh.set_instance_transform(i, (transforms[i] as Transform3D) * local)
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			add_child(instance)
			var b := local * part.mesh.get_aabb()
			bounds = b if first else bounds.merge(b)
			first = false
		_batch_bounds[path] = bounds
		model.free()
	if _caps.is_empty():
		return
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3.ONE
	var cap := MultiMesh.new()
	cap.transform_format = MultiMesh.TRANSFORM_3D
	cap.mesh = cap_mesh
	cap.instance_count = _caps.size()
	for i in _caps.size():
		cap.set_instance_transform(i, _caps[i])
	var cap_instance := MultiMeshInstance3D.new()
	cap_instance.multimesh = cap
	var material := Fx.flat(Color(0.13, 0.12, 0.15), 0.0, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.13, 0.12, 0.15)
	material.emission_energy_multiplier = 0.8
	cap_instance.material_override = material
	cap_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cap_instance)


## Les boîtes de tout ce qui se voit et se dresse (pas le sol), pièces
## regroupées comprises : sert au contrôle « tout obstacle est visible ».
func visible_boxes() -> Array[AABB]:
	var boxes: Array[AABB] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null:
			continue
		if part.get_parent() == self and part.material_override is StandardMaterial3D \
				and (part.material_override as StandardMaterial3D).emission_enabled:
			continue
		var b := part.global_transform * part.mesh.get_aabb()
		if b.size.y >= 0.25 and b.size.x <= 100.0 and b.size.z <= 100.0:
			boxes.append(b)
	for path: String in _batches:
		if not _batch_bounds.has(path):
			continue
		for t: Transform3D in _batches[path]:
			boxes.append(t * (_batch_bounds[path] as AABB))
	return boxes


## Un obstacle à l'emprise du modèle (réduite de `share`), faisant corps avec lui.
func _add_obstacle(node: Node3D, share: float) -> CollisionShape3D:
	var box := AABB()
	var first := true
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var b := (node.global_transform.affine_inverse() * mesh_instance.global_transform) * mesh_instance.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return null
	var scale := node.scale
	var size := Vector3(maxf(box.size.x * share * scale.x, 0.5), clampf(box.size.y * scale.y, 1.0, 4.0), maxf(box.size.z * share * scale.z, 0.5))
	var offset := Vector3(box.get_center().x * scale.x, 0.0, box.get_center().z * scale.z).rotated(Vector3.UP, node.rotation.y)
	return solid(node.position + offset, size, node.rotation_degrees.y)


## Pave le sol d'un même carreau en un seul appel de dessin. `cells` donne
## le centre de chaque carreau sur le plan (x, z).
func pave(file: String, cells: Array[Vector2]) -> void:
	var scene := load(file) as PackedScene
	var model := scene.instantiate() as Node3D
	var source := model.find_child("*", true, false) as MeshInstance3D
	if source == null:
		source = model as MeshInstance3D
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source.mesh
	multimesh.instance_count = cells.size()
	var tile := source.mesh.get_aabb().size
	for i in cells.size():
		multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(cells[i].x, 0.0, cells[i].y)))
		var square := Rect2(cells[i].x - tile.x / 2.0, cells[i].y - tile.z / 2.0, tile.x, tile.z)
		floor_bounds = square if not floor_bounds.has_area() else floor_bounds.merge(square)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	# Le sol ne projette pas d'ombre : il ne ferait que la recevoir.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	model.free()


## Un étal de marché : table, quatre poteaux et une toile tendue de travers.
## Le côté qui sert regarde vers +Z avant rotation de `yaw_deg`.
func stall(pos: Vector3, yaw_deg: float, cloth: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	add_child(root)
	var wood := Fx.flat(Color(0.2, 0.14, 0.1), 0.0, 0.9)
	var parts := [
		[Vector3(2.6, 0.12, 1.1), Vector3(0.0, 0.9, 0.0), wood],
		[Vector3(2.4, 0.9, 0.12), Vector3(0.0, 0.45, -0.4), wood],
		[Vector3(0.14, 2.5, 0.14), Vector3(-1.3, 1.25, -0.55), wood],
		[Vector3(0.14, 2.5, 0.14), Vector3(1.3, 1.25, -0.55), wood],
		[Vector3(0.14, 2.0, 0.14), Vector3(-1.3, 1.0, 0.6), wood],
		[Vector3(0.14, 2.0, 0.14), Vector3(1.3, 1.0, 0.6), wood],
	]
	for part: Array in parts:
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		piece.mesh = box
		piece.position = part[1]
		piece.material_override = part[2]
		root.add_child(piece)
	var awning := MeshInstance3D.new()
	var sheet := BoxMesh.new()
	sheet.size = Vector3(3.0, 0.06, 2.0)
	awning.mesh = sheet
	awning.position = Vector3(0.0, 2.3, 0.0)
	awning.rotation_degrees.x = 11.0
	awning.material_override = Fx.flat(cloth, 0.0, 1.0)
	root.add_child(awning)
	var crate := place("barrel_small_stack.glb", pos + Vector3(0.0, 1.0, 0.0), yaw_deg)
	if crate != null:
		crate.scale = Vector3.ONE * 0.45
	var footprint := Vector3(2.6, 1.0, 1.2) if absf(fmod(yaw_deg, 180.0)) < 45.0 else Vector3(1.2, 1.0, 2.6)
	solid(pos, footprint)


## Ajoute un obstacle invisible. `size.y` vaut par défaut la hauteur d'un mur.
func solid(center: Vector3, size: Vector3, yaw_deg := 0.0) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(center.x, size.y / 2.0, center.z)
	shape.rotation.y = deg_to_rad(yaw_deg)
	_solids.add_child(shape)
	return shape


## Une torche accrochée au mur, tournée de `yaw_deg`, et sa flamme.
func wall_torch(pos: Vector3, yaw_deg: float, energy := 2.8, reach_range := 12.0) -> void:
	place("torch_mounted.glb", pos, yaw_deg)
	var forward := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	flame(pos + forward * 0.7 + Vector3(0.0, 0.6, 0.0), energy, reach_range)


## Une flamme qui vacille.
func flame(pos: Vector3, energy := 2.6, reach_range := 11.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.26)
	light.light_energy = energy
	light.omni_range = reach_range
	light.omni_attenuation = 1.4
	light.position = pos
	add_child(light)
	_lights.append(light)
	_light_base.append(energy)
	return light
