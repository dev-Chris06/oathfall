extends Node3D
## Étapes 2 et 3 — l'arène du Repos.
##
## Des Dépouilles attaquent par vagues. Abattues, elles restent au sol puis
## se relèvent, sauf si le héros leur donne le Repos. Une vague n'est finie
## que lorsque tous les morts reposent. La salle est construite par code ;
## elle sera remplacée par les vrais niveaux.
##
## Vérification sans intervention :
##   godot --headless --path . --fixed-fps 60 -- --selftest
##   godot --path . -- --capture=/chemin/vers/un/dossier

signal wave_cleared

const DUNGEON := "res://assets/kaykit/dungeon/"

## Les dalles et les murs du pack font 4 unités de côté.
const TILE := 4.0
const COLS := 7
const ROWS := 5
const WALL_HEIGHT := 4.0

var hero: Hero
var controls: TouchControls

var _torches: Array[OmniLight3D] = []
var _enemies: Array[Enemy] = []
var _camera: GameCamera
var _hud: Hud
var _time := 0.0
var _hud_timer := 0.0
var _wave := 0
var _memories := 0
var _scripted := false


func _ready() -> void:
	Engine.time_scale = 1.0
	_build_environment()
	_build_room()

	controls = TouchControls.new()
	add_child(controls)

	hero = Hero.new()
	add_child(hero)
	hero.setup(HeroClasses.DEFAULT, controls)

	_camera = GameCamera.new()
	add_child(_camera)
	_camera.follow(hero)

	_hud = Hud.new()
	add_child(_hud)
	_hud.set_health(hero.health, hero.max_health)

	hero.hit_landed.connect(_on_hit_landed)
	hero.health_changed.connect(_hud.set_health)
	hero.hurt.connect(_on_hero_hurt)
	hero.died.connect(_on_hero_died)

	for arg in OS.get_cmdline_user_args():
		if arg == "--selftest" or arg.begins_with("--capture="):
			_scripted = true
			var bot := SelftestBot.new()
			bot.main = self
			bot.capture_dir = arg.trim_prefix("--capture=") if arg.begins_with("--capture=") else ""
			add_child(bot)

	if not _scripted:
		_hud.show_message("Les morts se relèvent.\nReste près d'un corps et maintiens REPOS.", 6.0)
		_next_wave()


func _process(delta: float) -> void:
	_time += delta
	for i in _torches.size():
		var flicker := sin(_time * 9.0 + i * 1.7) * 0.25 + sin(_time * 23.0 + i * 4.1) * 0.12
		_torches[i].light_energy = 2.6 + flicker

	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.25
		_hud.set_counts(
			get_tree().get_nodes_in_group(&"hittable").size(),
			get_tree().get_nodes_in_group(&"bodies").size(),
			_memories)
		_hud.set_debug("Oathfall %s — vague %d — %d images/s" % [
			ProjectSettings.get_setting("application/config/version", "?"),
			_wave, Engine.get_frames_per_second()])


# --- Vagues -------------------------------------------------------------------

## Fait entrer `count` Dépouilles. `rise_delay` remplace, s'il est positif, le
## délai de relèvement du type (utilisé par les tests).
func spawn_wave(count: int, rise_delay := -1.0) -> void:
	var half_x := COLS * TILE / 2.0 - 1.5
	var half_z := ROWS * TILE / 2.0 - 1.5
	var start := randf() * TAU
	for i in count:
		var angle := start + TAU * i / count
		var pos := hero.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 8.5
		pos.x = clampf(pos.x, -half_x, half_x)
		pos.z = clampf(pos.z, -half_z, half_z)
		pos.y = 0.0
		var enemy := Enemy.new()
		enemy.position = pos
		add_child(enemy)
		enemy.setup(&"depouille", hero)
		if rise_delay > 0.0:
			enemy.rise_delay = rise_delay
		enemy.rested.connect(_on_enemy_rested)
		enemy.rose.connect(_on_enemy_rose)
		_enemies.append(enemy)


func enemies() -> Array[Enemy]:
	return _enemies


func enemies_left() -> int:
	return _enemies.size()


func _next_wave() -> void:
	_wave += 1
	spawn_wave(mini(2 + _wave, 8))


func _on_enemy_rose(_enemy: Enemy) -> void:
	if not _scripted:
		_hud.show_message("Il se relève.", 1.6)


func _on_enemy_rested(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	_memories += int(EnemyTypes.get_type(&"depouille")["memories"])
	if not _enemies.is_empty():
		return
	wave_cleared.emit()
	if _scripted:
		return
	_hud.show_message("La salle est en paix.", 3.0)
	await get_tree().create_timer(3.5).timeout
	if not hero.is_dead():
		_next_wave()


# --- Réactions ----------------------------------------------------------------

func _on_hit_landed(heavy: bool) -> void:
	_camera.shake(0.9 if heavy else 0.45)
	# Bref arrêt sur image : c'est lui qui donne l'impression que le coup pèse.
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.09 if heavy else 0.05, true, false, true).timeout
	Engine.time_scale = 1.0


func _on_hero_hurt() -> void:
	_camera.shake(0.7)
	_hud.flash_damage()


func _on_hero_died() -> void:
	if _scripted:
		return
	_hud.show_message("Nul ne meurt en Orvana.\nTu te relèves.", 3.5)
	await get_tree().create_timer(4.0, true, false, true).timeout
	get_tree().reload_current_scene()


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

	# Murs invisibles : personne ne sort de la salle.
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
