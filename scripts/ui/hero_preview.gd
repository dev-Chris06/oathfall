class_name HeroPreview
extends SubViewportContainer
## Le héros qui tourne lentement sur lui-même, avec exactement l'équipement
## donné : le même modèle et les mêmes pièces que dans le jeu. Sert dans le
## carnet et dans la boutique (essayer un objet avant de l'acheter).

var _viewport: SubViewport
var _model: Node3D
var _equipped := {}


func _init(preview_size := Vector2(230.0, 340.0)) -> void:
	custom_minimum_size = preview_size
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.8)
	environment.ambient_light_energy = 0.9
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 1.5
	key.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.65, 1.0)
	rim.light_energy = 0.7
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	_viewport.add_child(rim)

	var data := HeroClasses.get_class_data(Progress.class_id)
	_model = (load(data["model"]) as PackedScene).instantiate() as Node3D
	_viewport.add_child(_model)
	for part_name: String in data.get("hidden_parts", []):
		var part := _model.find_child(part_name, true, false) as Node3D
		if part != null:
			part.visible = false
	var player := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation(data["animations"]["idle"]):
		var idle: String = data["animations"]["idle"]
		player.get_animation(idle).loop_mode = Animation.LOOP_LINEAR
		player.play(idle)
	var camera := Camera3D.new()
	camera.fov = 28.0
	camera.position = Vector3(0.0, 1.15, 4.3)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.current = true
	show_gear(_equipped if not _equipped.is_empty() else Progress.equipped_map())


## Montre ce que porterait le héros avec cet équipement.
func show_gear(equipped: Dictionary, flask_count := -1) -> void:
	_equipped = equipped
	if _model != null:
		Gear.apply(_model, equipped)
		Supplies.apply_belt(_model, Progress.flasks if flask_count < 0 else flask_count)


func _process(delta: float) -> void:
	if _model != null:
		_model.rotation.y += delta * 0.7
