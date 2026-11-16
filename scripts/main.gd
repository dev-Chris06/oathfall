extends Node
## Point d'entrée : charge les niveaux et les recharge au dernier point de
## reprise quand le héros tombe.
##
## Arguments, après `--` :
##   --selftest            un joueur automatique livre les combats d'essai,
##                         puis traverse la Grille
##   --capture=DOSSIER     même chose, en enregistrant des images
##   --arena               lance la salle d'essai au lieu du chapitre
##   --checkpoint=N        commence au point de reprise N
##
##   godot --headless --path . --fixed-fps 60 -- --selftest

signal level_loaded(level: Level)

const LEVELS := {
	&"arena": preload("res://scripts/levels/arena.gd"),
	&"la_grille": preload("res://scripts/levels/la_grille.gd"),
}

var level: Level
var level_id := &"la_grille"
var scripted := false

var _checkpoint := 0
var _memories_at_checkpoint := 0


func _ready() -> void:
	var capture_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--selftest":
			scripted = true
		elif arg.begins_with("--capture="):
			scripted = true
			capture_dir = arg.trim_prefix("--capture=")
		elif arg == "--arena":
			level_id = &"arena"
		elif arg.begins_with("--checkpoint="):
			_checkpoint = arg.trim_prefix("--checkpoint=").to_int()

	if scripted:
		# Le joueur automatique choisit lui-même les niveaux.
		var bot := SelftestBot.new()
		bot.main = self
		bot.capture_dir = capture_dir
		bot.start_checkpoint = _checkpoint
		add_child(bot)
		return
	load_level(level_id, _checkpoint)


## Charge un niveau, à partir d'un point de reprise.
func load_level(id: StringName, checkpoint := 0) -> void:
	if level != null:
		remove_child(level)
		level.queue_free()
	level_id = id
	_checkpoint = checkpoint
	Engine.time_scale = 1.0

	level = LEVELS[id].new()
	level.start_checkpoint = checkpoint
	level.memories = _memories_at_checkpoint
	level.scripted = scripted
	level.checkpoint_reached.connect(_on_checkpoint)
	level.failed.connect(_on_failed)
	level.completed.connect(_on_completed)
	add_child(level)
	level_loaded.emit(level)


func _on_checkpoint(index: int) -> void:
	_checkpoint = index
	_memories_at_checkpoint = level.memories


func _on_failed() -> void:
	var fallen := level
	await _pause(4.0)
	if level == fallen:
		load_level(level_id, _checkpoint)


func _on_completed() -> void:
	var done := level
	done.hud.show_message("%s\nLes morts de la cour reposent.\nSouvenirs : %d\n\nÀ suivre : les Allées." % [
		done.title.to_upper(), done.memories], 8.0)
	if scripted:
		return
	await _pause(9.0)
	if level == done:
		_memories_at_checkpoint = done.memories
		load_level(level_id, 0)


## Attente qui ignore l'arrêt sur image des coups.
func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
