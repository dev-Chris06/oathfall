class_name Npc
extends Node3D
## Un personnage du refuge : un modèle qui attend, et son nom au-dessus de la
## tête. C'est `Refuge` qui gère les conversations.

const REACH := 3.2

var id: StringName
var display_name := ""
var model_path := ""
## Les parties du modèle à masquer (il porte toutes ses armes à la fois).
var hidden_parts: Array = []
var model_scale := 1.0
var tint := Color.WHITE
var yaw_deg := 0.0


func _ready() -> void:
	var scene := load(model_path) as PackedScene
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = deg_to_rad(yaw_deg)
	add_child(model)
	for part_name: String in hidden_parts:
		var part := model.find_child(part_name, true, false) as Node3D
		if part != null:
			part.visible = false
	if tint != Color.WHITE:
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			for i in mesh_instance.get_surface_override_material_count():
				var base := mesh_instance.get_active_material(i) as StandardMaterial3D
				if base != null:
					var tinted := base.duplicate() as StandardMaterial3D
					tinted.albedo_color = tinted.albedo_color * tint
					mesh_instance.set_surface_override_material(i, tinted)
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation("Idle"):
		player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		player.play("Idle")

	var plate := Label3D.new()
	plate.text = display_name
	plate.font = GameFonts.text()
	plate.font_size = 56
	plate.pixel_size = 0.0065
	plate.outline_size = 12
	plate.modulate = Theatre.CREAM
	plate.outline_modulate = Color(0.0, 0.0, 0.02, 0.9)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.no_depth_test = true
	plate.position.y = 2.55 * model_scale + 0.2
	add_child(plate)
