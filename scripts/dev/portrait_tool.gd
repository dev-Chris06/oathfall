class_name PortraitTool
extends Node
## Fabrique les portraits du bestiaire : chaque type de mort, rendu depuis le
## vrai modèle (avec ses accessoires, sa teinte et son échelle), debout dans sa
## pose d'attente, sur fond transparent. Les images vont dans
## `res://assets/ui/portraits/` et sont versionnées : ce sont des rendus des
## modèles KayKit (CC0).
##
##   godot --path . --resolution 800x600 -- --portraits

const OUT_DIR := "res://assets/ui/portraits/"
const SIZE := 512


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for type_id: StringName in EnemyTypes.TYPES:
		await _render(type_id)
	print("portraits écrits dans %s" % OUT_DIR)
	get_tree().quit(0)


func _render(type_id: StringName) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.8)
	environment.ambient_light_energy = 0.9
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 1.5
	key.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.65, 1.0)
	rim.light_energy = 0.7
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	viewport.add_child(rim)

	# Le mort lui-même, créé comme dans le jeu, sans héros à poursuivre.
	var enemy := Enemy.create(type_id)
	viewport.add_child(enemy)
	enemy.setup(type_id, null)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: AnimationPlayer = enemy._anim
	if player != null:
		var idle := enemy._animation("idle")
		if player.has_animation(idle):
			player.play(idle)
			player.seek(0.35, true)
			player.pause()
	await get_tree().process_frame

	var box := _bounds(enemy)
	var center := box.get_center()
	var camera := Camera3D.new()
	camera.fov = 26.0
	viewport.add_child(camera)
	var reach := maxf(box.size.y, box.size.x * 1.15) * 0.5
	var distance := reach / tan(deg_to_rad(camera.fov / 2.0)) * 1.12
	camera.position = center + Vector3(0.45, 0.25, 1.0).normalized() * distance
	camera.look_at(center, Vector3.UP)
	camera.current = true

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + "%s.png" % type_id)
	image.save_png(path)
	print("portrait : %s" % path)
	viewport.queue_free()


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var b := mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
