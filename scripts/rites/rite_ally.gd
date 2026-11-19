class_name RiteAlly
extends Node3D
## Le mort rappelé : il se relève, doré, du côté du héros, va au mort debout
## le plus proche et le frappe, puis retourne au repos quand son temps est fini.
## Il n'est pas « hittable » : les morts ne s'en prennent qu'au héros.

var duration := 12.0
var damage := 16
var interval := 1.1
var speed := 4.5
var _time := 0.0
var _cooldown := 0.4
var _anim: AnimationPlayer
## Coups portés (pour les essais).
var strikes := 0


func _ready() -> void:
	var model := (load("res://assets/kaykit/skeletons/Skeleton_Minion.glb") as PackedScene).instantiate() as Node3D
	add_child(model)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.78, 0.45)
	gold.emission_enabled = true
	gold.emission = Color(0.9, 0.65, 0.3)
	gold.emission_energy_multiplier = 1.2
	for mesh: Node in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = gold
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var aura := Fx.disc(0.9, Color(0.91, 0.69, 0.38, 0.35))
	add_child(aura)
	Fx.ring(get_parent(), global_position, Color(0.91, 0.69, 0.38, 0.9), 2.5, 0.7)
	_play(&"Walking_D_Skeletons", true)


func _physics_process(delta: float) -> void:
	_time += delta
	_cooldown -= delta
	if _time >= duration:
		Fx.ring(get_parent(), global_position, Color(0.62, 0.82, 1.0, 0.8), 2.0, 0.8)
		queue_free()
		return
	var target := _nearest()
	if target == null:
		_play(&"Idle_Combat", true)
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	rotation.y = atan2(offset.x, offset.z)
	if offset.length() > 1.6:
		global_position += offset.normalized() * speed * delta
		_play(&"Walking_D_Skeletons", true)
	elif _cooldown <= 0.0:
		_cooldown = interval
		strikes += 1
		_play(&"Unarmed_Melee_Attack_Punch_A", false)
		target.call(&"take_hit", global_position, damage)


func _nearest() -> Node3D:
	var best: Node3D = null
	var best_distance := 18.0
	for node in get_tree().get_nodes_in_group(&"hittable"):
		var target := node as Node3D
		if target == null or not target.has_method(&"take_hit"):
			continue
		var distance := target.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = target
	return best


func _play(anim_name: StringName, looped: bool) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if looped and _anim.current_animation == anim_name:
		return
	_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	_anim.play(anim_name, 0.1)
