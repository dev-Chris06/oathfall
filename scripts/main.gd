extends Node3D
## Étape 0 — salle de test.
##
## Construit par code une crypte éclairée par des torches, y pose le chevalier
## et trois squelettes, fait tourner la caméra et affiche les images par
## seconde. Sert à vérifier que la 3D tourne correctement sur téléphone avant
## d'écrire le jeu. Cette scène sera remplacée par les vrais niveaux.

const DUNGEON := "res://assets/kaykit/dungeon/"
const KNIGHT := "res://assets/kaykit/adventurers/Knight.glb"
const SKELETON_MINION := "res://assets/kaykit/skeletons/Skeleton_Minion.glb"
const SKELETON_WARRIOR := "res://assets/kaykit/skeletons/Skeleton_Warrior.glb"

## Les dalles et les murs du pack font 4 unités de côté.
const TILE := 4.0
const COLS := 5
const ROWS := 4

## Le chevalier du pack porte toutes ses armes à la fois : on ne garde que
## l'épée à une main et le bouclier rectangulaire du Porte-glaive.
const KNIGHT_HIDDEN_PARTS: Array[String] = [
	"1H_Sword_Offhand", "2H_Sword", "Badge_Shield", "Round_Shield", "Spike_Shield",
]

var _torches: Array[OmniLight3D] = []
var _pivot: Node3D
var _label: Label
var _time := 0.0
var _hud_timer := 0.0


func _ready() -> void:
	_build_environment()
	_build_room()
	_spawn_characters()
	_build_camera()
	_build_hud()


func _process(delta: float) -> void:
	_time += delta
	_pivot.rotation.y += deg_to_rad(8.0) * delta

	# Vacillement des torches.
	for i in _torches.size():
		var flicker := sin(_time * 9.0 + i * 1.7) * 0.25 + sin(_time * 23.0 + i * 4.1) * 0.12
		_torches[i].light_energy = 2.6 + flicker

	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.5
		_update_hud()


# --- Ambiance -----------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.45)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_density = 0.02
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Une lune froide, pour contraster avec le feu des torches.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.25
	moon.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	moon.shadow_enabled = true
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
		# Murs nord et sud. Une porte au milieu du mur nord.
		var north := "wall_doorway.glb" if c == COLS / 2 else "wall.glb"
		_place(north, Vector3(x, 0.0, -half_z - 0.5))
		_place("wall.glb", Vector3(x, 0.0, half_z + 0.5), 180.0)

	for r in ROWS:
		var z := (r - (ROWS - 1) / 2.0) * TILE
		_place("wall.glb", Vector3(-half_x - 0.5, 0.0, z), 90.0)
		_place("wall.glb", Vector3(half_x + 0.5, 0.0, z), -90.0)

	# Un pilier à chaque angle cache la jonction des murs.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_place("pillar.glb", Vector3(sx * (half_x + 0.5), 0.0, sz * (half_z + 0.5)))

	_place("barrel_large.glb", Vector3(-half_x + 1.4, 0.0, half_z - 1.4))
	_place("barrel_small_stack.glb", Vector3(-half_x + 3.2, 0.0, half_z - 1.2), 25.0)
	_place("rubble_large.glb", Vector3(half_x - 3.5, 0.0, half_z - 1.8), 200.0)

	# Quatre torches murales, deux par grand mur.
	for tx: float in [-6.0, 6.0]:
		_add_torch(Vector3(tx, 2.3, -half_z), 0.0)
		_add_torch(Vector3(tx, 2.3, half_z), 180.0)


func _add_torch(pos: Vector3, yaw_deg: float) -> void:
	var torch := _place("torch_mounted.glb", pos, yaw_deg)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 2.6
	light.omni_range = 10.0
	light.omni_attenuation = 1.4
	# La lumière est placée devant la flamme, côté salle.
	var forward := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	light.position = pos + forward * 0.7 + Vector3(0.0, 0.6, 0.0)
	add_child(light)
	_torches.append(light)
	if torch == null:
		push_warning("Torche sans modèle : seule la lumière est posée.")


func _place(file: String, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	return _instantiate(DUNGEON + file, pos, yaw_deg)


func _instantiate(path: String, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Modèle introuvable : " + path)
		return null
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	add_child(node)
	return node


# --- Personnages --------------------------------------------------------------

func _spawn_characters() -> void:
	var knight := _instantiate(KNIGHT, Vector3(0.0, 0.0, 0.0), 0.0)
	if knight != null:
		for part_name in KNIGHT_HIDDEN_PARTS:
			var part := knight.find_child(part_name, true, false) as Node3D
			if part != null:
				part.visible = false
		_play(_animation_player(knight), "Idle", true)

	var warrior := _instantiate(SKELETON_WARRIOR, Vector3(-3.0, 0.0, 3.5), 140.0)
	if warrior != null:
		_play(_animation_player(warrior), "Idle_Combat", true)

	var minion := _instantiate(SKELETON_MINION, Vector3(3.2, 0.0, 3.0), -140.0)
	if minion != null:
		_play(_animation_player(minion), "Taunt", true)

	# Aperçu du Repos : ce squelette tombe, puis se relève, en boucle.
	var restless := _instantiate(SKELETON_MINION, Vector3(0.5, 0.0, 5.0), 180.0)
	if restless != null:
		_restless_loop(_animation_player(restless))


func _animation_player(root: Node) -> AnimationPlayer:
	return root.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _play(player: AnimationPlayer, anim_name: String, looping: bool) -> bool:
	if player == null or not player.has_animation(anim_name):
		push_warning("Animation introuvable : " + anim_name)
		return false
	var anim := player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	player.play(anim_name, 0.2)
	return true


func _restless_loop(player: AnimationPlayer) -> void:
	if player == null:
		return
	while is_inside_tree():
		_play(player, "Idle_Combat", true)
		await get_tree().create_timer(3.0).timeout
		if _play(player, "Death_C_Skeletons", false):
			await player.animation_finished
		await get_tree().create_timer(3.0).timeout
		if _play(player, "Death_C_Skeletons_Resurrect", false):
			await player.animation_finished


# --- Caméra et affichage ------------------------------------------------------

func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, 1.0, 1.5)
	add_child(_pivot)

	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.position = Vector3(0.0, 5.5, 8.5)
	_pivot.add_child(camera)
	camera.look_at(_pivot.global_position, Vector3.UP)
	camera.current = true


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_label = Label.new()
	_label.position = Vector2(24.0, 18.0)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	_update_hud()


func _update_hud() -> void:
	var size := get_viewport().get_visible_rect().size
	var version: String = ProjectSettings.get_setting("application/config/version", "?")
	_label.text = "OATHFALL %s — étape 0 : salle de test\n%d images/s\n%s\n%d × %d" % [
		version,
		Engine.get_frames_per_second(),
		RenderingServer.get_video_adapter_name(),
		int(size.x), int(size.y),
	]
