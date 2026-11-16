extends Node3D
## Étape 1 — salle d'entraînement.
##
## Le héros se déplace, enchaîne trois coups et esquive, face à des morts
## immobiles qui encaissent. La salle est construite par code ; elle sera
## remplacée par les vrais niveaux.
##
## Vérification sans intervention :
##   godot --path . -- --capture=/chemin/vers/un/dossier
## joue une courte démonstration, enregistre des images, puis quitte.

const DUNGEON := "res://assets/kaykit/dungeon/"
const SKELETON_MINION := "res://assets/kaykit/skeletons/Skeleton_Minion.glb"
const SKELETON_WARRIOR := "res://assets/kaykit/skeletons/Skeleton_Warrior.glb"

## Les dalles et les murs du pack font 4 unités de côté.
const TILE := 4.0
const COLS := 7
const ROWS := 5
const WALL_HEIGHT := 4.0

var _torches: Array[OmniLight3D] = []
var _hero: Hero
var _camera: GameCamera
var _controls: TouchControls
var _label: Label
var _time := 0.0
var _hud_timer := 0.0
var _hits_landed := 0


func _ready() -> void:
	_build_environment()
	_build_room()

	_controls = TouchControls.new()
	add_child(_controls)

	_hero = Hero.new()
	add_child(_hero)
	_hero.setup(HeroClasses.DEFAULT, _controls)
	_hero.hit_landed.connect(_on_hit_landed)

	_spawn_target(SKELETON_WARRIOR, Vector3(0.0, 0.0, -5.0), 0.0)
	_spawn_target(SKELETON_MINION, Vector3(-4.5, 0.0, -3.0), 40.0)
	_spawn_target(SKELETON_MINION, Vector3(4.5, 0.0, -3.0), -40.0)

	_camera = GameCamera.new()
	add_child(_camera)
	_camera.follow(_hero)

	_build_hud()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_run_capture(arg.trim_prefix("--capture="))
		elif arg == "--selftest":
			# Même démonstration, sans images : utilisable sans affichage.
			_run_capture("")


func _process(delta: float) -> void:
	_time += delta
	for i in _torches.size():
		var flicker := sin(_time * 9.0 + i * 1.7) * 0.25 + sin(_time * 23.0 + i * 4.1) * 0.12
		_torches[i].light_energy = 2.6 + flicker

	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.5
		_label.text = "Oathfall %s — %d images/s" % [
			ProjectSettings.get_setting("application/config/version", "?"),
			Engine.get_frames_per_second()]


func _on_hit_landed(heavy: bool) -> void:
	_hits_landed += 1
	_camera.shake(0.9 if heavy else 0.45)
	# Bref arrêt sur image : c'est lui qui donne l'impression que le coup pèse.
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.09 if heavy else 0.05, true, false, true).timeout
	Engine.time_scale = 1.0


# --- Ambiance -----------------------------------------------------------------

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


# --- Décor --------------------------------------------------------------------

func _build_room() -> void:
	var half_x := COLS * TILE / 2.0
	var half_z := ROWS * TILE / 2.0

	for c in COLS:
		var x := (c - (COLS - 1) / 2.0) * TILE
		for r in ROWS:
			var z := (r - (ROWS - 1) / 2.0) * TILE
			_place("floor_tile_large.glb", Vector3(x, 0.0, z))
		var north := "wall_doorway.glb" if c == COLS / 2 else "wall.glb"
		_place(north, Vector3(x, 0.0, -half_z - 0.5))
		# Pas de mur au sud : il se trouverait entre la caméra et le héros.

	for r in ROWS:
		var z := (r - (ROWS - 1) / 2.0) * TILE
		_place("wall.glb", Vector3(-half_x - 0.5, 0.0, z), 90.0)
		_place("wall.glb", Vector3(half_x + 0.5, 0.0, z), -90.0)

	for sx: float in [-1.0, 1.0]:
		_place("pillar.glb", Vector3(sx * (half_x + 0.5), 0.0, -half_z - 0.5))

	_place("barrel_large.glb", Vector3(-half_x + 1.4, 0.0, -half_z + 1.4))
	_place("barrel_small_stack.glb", Vector3(half_x - 1.6, 0.0, -half_z + 1.3), 25.0)

	for tx: float in [-8.0, 8.0]:
		_add_torch(Vector3(tx, 2.3, -half_z), 0.0)
	_add_torch(Vector3(-half_x, 2.3, 2.0), 90.0)
	_add_torch(Vector3(half_x, 2.3, 2.0), -90.0)

	# Murs invisibles : le héros ne sort pas de la salle.
	var bounds := StaticBody3D.new()
	add_child(bounds)
	_add_wall_collider(bounds, Vector3(0.0, 0.0, -half_z - 0.5), Vector3(COLS * TILE + 2.0, WALL_HEIGHT, 1.0))
	_add_wall_collider(bounds, Vector3(0.0, 0.0, half_z + 0.5), Vector3(COLS * TILE + 2.0, WALL_HEIGHT, 1.0))
	_add_wall_collider(bounds, Vector3(-half_x - 0.5, 0.0, 0.0), Vector3(1.0, WALL_HEIGHT, ROWS * TILE + 2.0))
	_add_wall_collider(bounds, Vector3(half_x + 0.5, 0.0, 0.0), Vector3(1.0, WALL_HEIGHT, ROWS * TILE + 2.0))


func _add_wall_collider(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos + Vector3(0.0, size.y / 2.0, 0.0)
	body.add_child(shape)


func _add_torch(pos: Vector3, yaw_deg: float) -> void:
	_place("torch_mounted.glb", pos, yaw_deg)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.26)
	light.light_energy = 2.6
	light.omni_range = 11.0
	light.omni_attenuation = 1.4
	var forward := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	light.position = pos + forward * 0.7 + Vector3(0.0, 0.6, 0.0)
	add_child(light)
	_torches.append(light)


func _place(file: String, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	var scene := load(DUNGEON + file) as PackedScene
	if scene == null:
		push_warning("Modèle introuvable : " + file)
		return null
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	add_child(node)
	return node


func _spawn_target(model_path: String, pos: Vector3, yaw_deg: float) -> void:
	var target := TrainingTarget.new()
	target.position = pos
	target.rotation_degrees.y = yaw_deg
	add_child(target)
	target.setup(model_path, "Idle_Combat")


# --- Affichage ----------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20.0, 14.0)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75, 0.8))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)


# --- Démonstration enregistrée ------------------------------------------------

func _run_capture(dir: String) -> void:
	await _wait(1.0)
	await _snapshot(dir, "1_repos")

	# Course vers la cible du fond.
	_controls.simulated_move = Vector2(0.0, -1.0)
	await _wait(0.45)
	await _snapshot(dir, "2_course")
	await _wait(0.2)
	_controls.simulated_move = Vector2.ZERO

	# Enchaînement de trois coups.
	_controls.press_attack()
	await _wait(0.2)
	await _snapshot(dir, "3_coup_1")
	_controls.press_attack()
	await _wait(0.45)
	_controls.press_attack()
	await _wait(0.55)
	await _snapshot(dir, "4_coup_3")
	await _wait(0.8)

	# Esquive vers la droite.
	_controls.simulated_move = Vector2(1.0, 0.3)
	await _wait(0.05)
	_controls.press_dodge()
	await _wait(0.2)
	await _snapshot(dir, "5_esquive")
	_controls.simulated_move = Vector2.ZERO
	await _wait(0.6)
	await _snapshot(dir, "6_fin")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _snapshot(dir: String, shot_name: String) -> void:
	var saved := "sans image"
	if not dir.is_empty():
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		saved = error_string(image.save_png("%s/%s.png" % [dir, shot_name]))
	print("étape %s : %s — héros en %s, état %s, coups portés %d, vitesse du temps %.2f" % [
		shot_name, saved, _hero.global_position.snapped(Vector3.ONE * 0.1),
		Hero.State.keys()[_hero.state], _hits_landed, Engine.time_scale])
