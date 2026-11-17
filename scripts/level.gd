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
## Terrain jouable (x, z, largeur, profondeur), pour habiller ses abords.
var play_area := Rect2()
## Décor des abords (voir `Scenery`) : cimetière par défaut.
var scenery: StringName = &""
## Étendue du sol dallé, notée par `pave()`.
var floor_bounds := Rect2()

var hero: Hero
var controls: TouchControls
var hud: Hud

## Point que le héros doit rejoindre, s'il y en a un. Sert au joueur
## automatique et au repère affiché dans le décor et à l'écran.
var objective = null
## Le carnet des compétences, tant qu'il est ouvert.
var book: SkillBook
## Le menu de pause, tant qu'il est ouvert.
var pause_menu: PauseMenu

var _camera: GameCamera
var _guide: Node3D
var _enemies: Array[Enemy] = []
var _lights: Array[OmniLight3D] = []
var _light_base: Array[float] = []
var _time := 0.0
var _hud_timer := 0.0
var _finished := false
var _solids: StaticBody3D
## Les vantaux de chaque grille, et l'obstacle qui la ferme.
var _gates: Array[Dictionary] = []


func _ready() -> void:
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

	_update_guide()

	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.25
		hud.set_counts(standing_count(), get_tree().get_nodes_in_group(&"bodies").size())
		hud.set_debug("Oathfall %s — %s — %d images/s" % [
			ProjectSettings.get_setting("application/config/version", "?"),
			title, Engine.get_frames_per_second()])


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
func until_peace() -> void:
	await wait_until(func() -> bool: return _enemies.is_empty())


func mark_checkpoint(index: int) -> void:
	checkpoint_reached.emit(index)


func finish() -> void:
	if _finished:
		return
	_finished = true
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
	enemy.position = Vector3(where.x, 0.0, where.z)
	add_child(enemy)
	enemy.setup(type_id, hero)
	enemy.rested.connect(_on_enemy_rested)
	enemy.rose.connect(_on_enemy_rose)
	_enemies.append(enemy)
	Progress.meet(type_id)
	if from_grave:
		enemy.emerge()
	return enemy


func enemies() -> Array[Enemy]:
	return _enemies


func enemies_left() -> int:
	return _enemies.size()


func _on_enemy_rose(_enemy: Enemy) -> void:
	hud.show_message("Il se relève.", 1.6)


func _on_enemy_rested(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	Progress.note_rest(enemy.type_id_name)
	Progress.add_memories(enemy.memories_given())
	Progress.add_gold(enemy.gold_given())


# --- Progression --------------------------------------------------------------

## Ouvre le carnet des compétences ; le jeu reste en pause tant qu'il est ouvert.
func open_book() -> void:
	if hero.is_dead() or _finished or get_tree().paused:
		return
	book = SkillBook.new()
	book.can_leave = true
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
	hero.flasks = Progress.flasks
	hero.apply_gear(Progress.equipped_map())
	hud.set_progress(Progress.hero_level, Progress.level_progress(), Progress.gold)
	controls.book_alert = Progress.skill_points > 0


func _on_flask_drunk() -> void:
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
				near.append("%s %.1f" % [enemy.type_id_name, enemy.global_position.distance_to(hero.global_position)])
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
func place(file: String, pos: Vector3, yaw_deg := 0.0, height_scale := 1.0) -> Node3D:
	var path := file if file.begins_with("res://") else DUNGEON + file
	if underground and height_scale >= 0.99 and (path.ends_with("/wall.glb") or path.ends_with("/wall_doorway.glb")):
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
