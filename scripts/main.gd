extends Node
## Point d'entrée : charge les niveaux et les recharge au dernier point de
## reprise quand le héros tombe.
##
## Arguments, après `--` :
##   --selftest            un joueur automatique livre les combats d'essai,
##                         puis traverse la Grille
##   --capture=DOSSIER     même chose, en enregistrant des images
##   --arena               lance la salle d'essai au lieu du chapitre
##   --level=ID            commence par ce niveau (la_grille, les_allees…)
##   --checkpoint=N        commence au point de reprise N
##
##   godot --headless --path . --fixed-fps 60 -- --selftest

signal level_loaded(level: Level)

const LEVELS := {
	&"arena": preload("res://scripts/levels/arena.gd"),
	&"la_grille": preload("res://scripts/levels/la_grille.gd"),
	&"les_allees": preload("res://scripts/levels/les_allees.gd"),
	&"l_ossuaire": preload("res://scripts/levels/l_ossuaire.gd"),
}

var level: Level
var level_id := &"la_grille"
var scripted := false

var _checkpoint := 0


func _ready() -> void:
	var capture_dir := ""
	var forced_checkpoint := -1
	for arg in OS.get_cmdline_user_args():
		if arg == "--selftest":
			scripted = true
		elif arg.begins_with("--capture="):
			scripted = true
			capture_dir = arg.trim_prefix("--capture=")
		elif arg == "--arena":
			level_id = &"arena"
		elif arg.begins_with("--level="):
			level_id = StringName(arg.trim_prefix("--level="))
		elif arg.begins_with("--checkpoint="):
			forced_checkpoint = arg.trim_prefix("--checkpoint=").to_int()

	if scripted:
		# Les tests ne touchent pas à la vraie partie du joueur.
		Progress.save_path = "user://essai.json"
		Progress.delete_save()
		Progress.reset()
		# Le joueur automatique choisit lui-même les niveaux.
		var bot := SelftestBot.new()
		bot.main = self
		bot.capture_dir = capture_dir
		bot.start_checkpoint = maxi(forced_checkpoint, 0)
		add_child(bot)
		return

	Progress.load_save()
	if level_id == &"arena":
		load_level(level_id, 0)
	elif forced_checkpoint >= 0 or level_id != &"la_grille":
		load_level(level_id, maxi(forced_checkpoint, 0))
	elif LEVELS.has(Progress.level_id):
		load_level(Progress.level_id, Progress.checkpoint)
	else:
		load_level(&"la_grille", 0)


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
	level.scripted = scripted
	level.checkpoint_reached.connect(_on_checkpoint)
	level.failed.connect(_on_failed)
	level.completed.connect(_on_completed)
	add_child(level)
	level_loaded.emit(level)


func _on_checkpoint(index: int) -> void:
	_checkpoint = index
	if level_id != &"arena":
		Progress.set_resume_point(level_id, index)


func _on_failed() -> void:
	var fallen := level
	await _pause(4.0)
	if level == fallen:
		load_level(level_id, _checkpoint)


func _on_completed() -> void:
	var done := level
	done.hud.show_message("%s\nLes morts de la cour reposent.\nNiveau %d — Or : %d\n\nÀ suivre : les Allées." % [
		done.title.to_upper(), Progress.hero_level, Progress.gold], 8.0)
	# Les Allées n'existent pas encore : la partie reprendra à la Grille.
	Progress.set_resume_point(level_id, 0)
	if scripted:
		return
	await _pause(9.0)
	if level == done:
		load_level(level_id, 0)


## Attente qui ignore l'arrêt sur image des coups.
func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
