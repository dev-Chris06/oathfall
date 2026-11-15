extends Node3D
## Étape 0 — salle de test et banc de mesure.
##
## Construit par code une crypte éclairée par des torches, y pose le chevalier
## et trois squelettes, fait tourner la caméra et affiche les images par
## seconde. Les boutons à droite coupent un à un les effets coûteux, pour
## savoir ce qui pèse sur un téléphone donné. Cette scène sera remplacée par
## les vrais niveaux.

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

const RESOLUTION_STEPS: Array[float] = [1.0, 0.75, 0.5]
const TORCH_STEPS: Array[int] = [4, 2, 0]
const FPS_STEPS: Array[int] = [0, 60, 30]

var _torches: Array[OmniLight3D] = []
var _characters: Array[Node3D] = []
var _env: Environment
var _moon: DirectionalLight3D
var _pivot: Node3D
var _label: Label
var _time := 0.0
var _hud_timer := 0.0

# Mesure : moyenne et pire image sur la dernière demi-seconde.
var _frame_count := 0
var _frame_sum := 0.0
var _frame_worst := 0.0
var _avg_ms := 0.0
var _worst_ms := 0.0

# État des réglages du banc de mesure.
var _shadows_on := true
var _fog_on := true
var _characters_on := true
var _camera_turning := true
var _resolution_index := 0
var _torch_index := 0
var _fps_index := 0


func _ready() -> void:
	_build_environment()
	_build_room()
	_spawn_characters()
	_build_camera()
	_build_hud()


func _process(delta: float) -> void:
	_time += delta
	if _camera_turning:
		_pivot.rotation.y += deg_to_rad(8.0) * delta

	# Vacillement des torches.
	for i in _torches.size():
		var flicker := sin(_time * 9.0 + i * 1.7) * 0.25 + sin(_time * 23.0 + i * 4.1) * 0.12
		_torches[i].light_energy = 2.6 + flicker

	_frame_count += 1
	_frame_sum += delta
	_frame_worst = maxf(_frame_worst, delta)

	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.5
		_avg_ms = _frame_sum / maxi(_frame_count, 1) * 1000.0
		_worst_ms = _frame_worst * 1000.0
		_frame_count = 0
		_frame_sum = 0.0
		_frame_worst = 0.0
		_update_hud()


# --- Ambiance -----------------------------------------------------------------

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.02, 0.04)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.25, 0.3, 0.45)
	_env.ambient_light_energy = 0.35
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.05, 0.06, 0.1)
	_env.fog_density = 0.02
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	# Une lune froide, pour contraster avec le feu des torches.
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.55, 0.65, 1.0)
	_moon.light_energy = 0.25
	_moon.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	_moon.shadow_enabled = true
	add_child(_moon)


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
	var knight := _spawn_character(KNIGHT, Vector3(0.0, 0.0, 0.0), 0.0)
	if knight != null:
		for part_name in KNIGHT_HIDDEN_PARTS:
			var part := knight.find_child(part_name, true, false) as Node3D
			if part != null:
				part.visible = false
		_play(_animation_player(knight), "Idle", true)

	var warrior := _spawn_character(SKELETON_WARRIOR, Vector3(-3.0, 0.0, 3.5), 140.0)
	if warrior != null:
		_play(_animation_player(warrior), "Idle_Combat", true)

	var minion := _spawn_character(SKELETON_MINION, Vector3(3.2, 0.0, 3.0), -140.0)
	if minion != null:
		_play(_animation_player(minion), "Taunt", true)

	# Aperçu du Repos : ce squelette tombe, puis se relève, en boucle.
	var restless := _spawn_character(SKELETON_MINION, Vector3(0.5, 0.0, 5.0), 180.0)
	if restless != null:
		_restless_loop(_animation_player(restless))


func _spawn_character(path: String, pos: Vector3, yaw_deg: float) -> Node3D:
	var node := _instantiate(path, pos, yaw_deg)
	if node != null:
		_characters.append(node)
	return node


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


# --- Caméra -------------------------------------------------------------------

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


# --- Affichage et banc de mesure ----------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_label = Label.new()
	_label.position = Vector2(24.0, 18.0)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.position = Vector2(-24.0, 18.0)
	column.add_theme_constant_override("separation", 8)
	layer.add_child(column)

	_add_toggle(column, func() -> String:
		return "Ombres : " + _on_off(_shadows_on),
		func() -> void:
			_shadows_on = not _shadows_on
			_moon.shadow_enabled = _shadows_on)

	_add_toggle(column, func() -> String:
		return "Torches : %d" % TORCH_STEPS[_torch_index],
		func() -> void:
			_torch_index = (_torch_index + 1) % TORCH_STEPS.size()
			for i in _torches.size():
				_torches[i].visible = i < TORCH_STEPS[_torch_index])

	_add_toggle(column, func() -> String:
		return "Brouillard : " + _on_off(_fog_on),
		func() -> void:
			_fog_on = not _fog_on
			_env.fog_enabled = _fog_on)

	_add_toggle(column, func() -> String:
		return "Résolution : %d %%" % int(RESOLUTION_STEPS[_resolution_index] * 100.0),
		func() -> void:
			_resolution_index = (_resolution_index + 1) % RESOLUTION_STEPS.size()
			get_viewport().scaling_3d_scale = RESOLUTION_STEPS[_resolution_index])

	_add_toggle(column, func() -> String:
		return "Personnages : " + _on_off(_characters_on),
		func() -> void:
			_characters_on = not _characters_on
			for character in _characters:
				character.visible = _characters_on)

	_add_toggle(column, func() -> String:
		var cap := FPS_STEPS[_fps_index]
		return "Limite : " + ("aucune" if cap == 0 else "%d img/s" % cap),
		func() -> void:
			_fps_index = (_fps_index + 1) % FPS_STEPS.size()
			Engine.max_fps = FPS_STEPS[_fps_index])

	_add_toggle(column, func() -> String:
		return "Caméra : " + ("tourne" if _camera_turning else "fixe"),
		func() -> void:
			_camera_turning = not _camera_turning)

	_update_hud()


## Ajoute un bouton dont le texte reflète toujours l'état du réglage.
func _add_toggle(parent: Control, text_of: Callable, action: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(250.0, 52.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.text = text_of.call()
	button.pressed.connect(func() -> void:
		action.call()
		button.text = text_of.call())
	parent.add_child(button)


func _on_off(value: bool) -> String:
	return "oui" if value else "non"


func _update_hud() -> void:
	var size := get_viewport().get_visible_rect().size
	var version: String = ProjectSettings.get_setting("application/config/version", "?")
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var triangles := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_label.text = "\n".join([
		"OATHFALL %s — banc de mesure" % version,
		"%d images/s" % Engine.get_frames_per_second(),
		"image : %.1f ms en moyenne, %.1f ms au pire" % [_avg_ms, _worst_ms],
		"écran : %d Hz, %d × %d" % [
			int(round(DisplayServer.screen_get_refresh_rate())), int(size.x), int(size.y)],
		"%d appels de dessin, %d triangles" % [draw_calls, triangles],
		RenderingServer.get_video_adapter_name(),
	])
