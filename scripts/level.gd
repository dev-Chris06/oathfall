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
## Émis à chaque image de physique ; les scénarios l'attendent plutôt qu'un
## signal de l'arbre, pour s'arrêter net si le niveau est libéré.
signal ticked

const DUNGEON := "res://assets/kaykit/dungeon/"
const GRAVEYARD := "res://assets/kaykit/halloween/"

## Nom affiché à l'entrée du niveau.
var title := ""
## Point de reprise où commence le scénario.
var start_checkpoint := 0
## Souvenirs déjà portés par le héros.
var memories := 0
## Vrai quand un joueur automatique tient les commandes : le niveau ne se
## recharge pas seul et laisse le test décider.
var scripted := false

var hero: Hero
var controls: TouchControls
var hud: Hud

## Point que le héros doit rejoindre, s'il y en a un. Sert au joueur
## automatique et, plus tard, à un repère à l'écran.
var objective = null

var _camera: GameCamera
var _enemies: Array[Enemy] = []
var _lights: Array[OmniLight3D] = []
var _light_base: Array[float] = []
var _time := 0.0
var _hud_timer := 0.0
var _finished := false
var _solids: StaticBody3D


func _ready() -> void:
	Engine.time_scale = 1.0
	_solids = StaticBody3D.new()
	add_child(_solids)
	_build_environment()
	_build()

	controls = TouchControls.new()
	add_child(controls)

	hero = Hero.new()
	hero.position = _checkpoint_position(start_checkpoint)
	add_child(hero)
	hero.setup(HeroClasses.DEFAULT, controls)

	_camera = GameCamera.new()
	add_child(_camera)
	_camera.follow(hero)

	hud = Hud.new()
	add_child(hud)
	hud.set_health(hero.health, hero.max_health)

	hero.hit_landed.connect(_on_hit_landed)
	hero.health_changed.connect(hud.set_health)
	hero.hurt.connect(_on_hero_hurt)
	hero.died.connect(_on_hero_died)

	_run.call_deferred(start_checkpoint)


func _physics_process(_delta: float) -> void:
	ticked.emit()


func _process(delta: float) -> void:
	_time += delta
	for i in _lights.size():
		var flicker := sin(_time * 9.0 + i * 1.7) * 0.25 + sin(_time * 23.0 + i * 4.1) * 0.12
		_lights[i].light_energy = _light_base[i] + flicker

	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.25
		hud.set_counts(
			get_tree().get_nodes_in_group(&"hittable").size(),
			get_tree().get_nodes_in_group(&"bodies").size(),
			memories)
		hud.set_debug("Oathfall %s — %s — %d images/s" % [
			ProjectSettings.get_setting("application/config/version", "?"),
			title, Engine.get_frames_per_second()])


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


## Attend que le héros arrive à moins de `radius` du point `where`.
func reach(where: Vector3, radius := 2.5) -> void:
	objective = where
	await wait_until(func() -> bool:
		var offset := hero.global_position - where
		offset.y = 0.0
		return offset.length() <= radius)
	objective = null


## Attend que tous les morts du niveau reposent.
func until_peace() -> void:
	await wait_until(func() -> bool: return _enemies.is_empty())


func mark_checkpoint(index: int) -> void:
	checkpoint_reached.emit(index)


func finish() -> void:
	if _finished:
		return
	_finished = true
	completed.emit()


# --- Les morts ----------------------------------------------------------------

## Fait apparaître un mort. Avec `from_grave`, il sort de terre avant
## d'attaquer.
func spawn(type_id: StringName, where: Vector3, from_grave := true) -> Enemy:
	var enemy := Enemy.new()
	enemy.position = Vector3(where.x, 0.0, where.z)
	add_child(enemy)
	enemy.setup(type_id, hero)
	enemy.rested.connect(_on_enemy_rested)
	enemy.rose.connect(_on_enemy_rose)
	_enemies.append(enemy)
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
	memories += enemy.memories_given()


# --- Réactions ----------------------------------------------------------------

func _on_hit_landed(heavy: bool) -> void:
	_camera.shake(0.9 if heavy else 0.45)
	# Bref arrêt sur image : c'est lui qui donne l'impression que le coup pèse.
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.09 if heavy else 0.05, true, false, true).timeout
	Engine.time_scale = 1.0


func _on_hero_hurt() -> void:
	_camera.shake(0.7)
	hud.flash_damage()


func _on_hero_died() -> void:
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
	env.ambient_light_energy = 0.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.09)
	env.fog_density = 0.025
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

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
func place(file: String, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	var path := file if file.begins_with("res://") else DUNGEON + file
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Modèle introuvable : " + path)
		return null
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	add_child(node)
	return node


## Pose un modèle du pack de cimetière.
func grave_piece(file: String, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	return place(GRAVEYARD + file + ".gltf", pos, yaw_deg)


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
	for i in cells.size():
		multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(cells[i].x, 0.0, cells[i].y)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	# Le sol ne projette pas d'ombre : il ne ferait que la recevoir.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	model.free()


## Ajoute un obstacle invisible. `size.y` vaut par défaut la hauteur d'un mur.
func solid(center: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(center.x, size.y / 2.0, center.z)
	_solids.add_child(shape)
	return shape


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
