class_name TrainingTarget
extends StaticBody3D
## Cible d'entraînement : un mort immobile qui encaisse les coups.
## Sert à régler les sensations de frappe avant d'écrire les vrais ennemis.

var _model: Node3D
var _anim: AnimationPlayer
var _idle := "Idle_Combat"


func setup(model_path: String, idle_animation: String) -> void:
	add_to_group(&"hittable")
	_idle = idle_animation

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)

	var scene := load(model_path) as PackedScene
	if scene == null:
		push_error("Modèle de cible introuvable : " + model_path)
		return
	_model = scene.instantiate() as Node3D
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		_anim.animation_finished.connect(_on_animation_finished)
	_play_idle()


func take_hit(from: Vector3, _damage: int) -> void:
	if _model == null:
		return
	# Recul bref du modèle dans la direction du coup.
	var push := global_position - from
	push.y = 0.0
	push = push.normalized() * 0.35
	var tween := create_tween()
	tween.tween_property(_model, "position", push, 0.05)
	tween.tween_property(_model, "position", Vector3.ZERO, 0.18)

	if _anim != null and _anim.has_animation("Hit_A"):
		_anim.get_animation("Hit_A").loop_mode = Animation.LOOP_NONE
		_anim.stop()
		_anim.play("Hit_A", 0.03, 1.4)


func _on_animation_finished(_anim_name: StringName) -> void:
	_play_idle()


func _play_idle() -> void:
	if _anim == null or not _anim.has_animation(_idle):
		return
	_anim.get_animation(_idle).loop_mode = Animation.LOOP_LINEAR
	_anim.play(_idle, 0.2)
