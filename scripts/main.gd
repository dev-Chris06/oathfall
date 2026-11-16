extends Node
## Point d'entrée. Le jeu s'ouvre sur la carte d'Orvana, où l'on choisit un
## niveau ; la fin d'un niveau, ou son abandon depuis le carnet, ramène à la
## carte. Un héros qui tombe se relève au dernier point de reprise du niveau.
##
## Arguments, après `--` :
##   --selftest            un joueur automatique livre les combats d'essai,
##                         traverse les niveaux et essaie la carte
##   --capture=DOSSIER     même chose, en enregistrant des images
##   --map                 avec --capture : photographie la carte
##   --arena               lance la salle d'essai au lieu de la carte
##   --level=ID            lance ce niveau (la_grille, les_allees…)
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
var world_map: WorldMap
var level_id := &"la_grille"
var scripted := false

var _checkpoint := 0


func _ready() -> void:
	var capture_dir := ""
	var capture_map := false
	var direct := false
	var forced_checkpoint := -1
	for arg in OS.get_cmdline_user_args():
		if arg == "--selftest":
			scripted = true
		elif arg.begins_with("--capture="):
			scripted = true
			capture_dir = arg.trim_prefix("--capture=")
		elif arg == "--map":
			capture_map = true
		elif arg == "--arena":
			level_id = &"arena"
			direct = true
		elif arg.begins_with("--level="):
			level_id = StringName(arg.trim_prefix("--level="))
			direct = true
		elif arg.begins_with("--checkpoint="):
			forced_checkpoint = arg.trim_prefix("--checkpoint=").to_int()
			direct = true

	if scripted:
		# Les tests ne touchent pas à la vraie partie du joueur.
		Progress.save_path = "user://essai.json"
		Progress.delete_save()
		Progress.reset()
		# Le joueur automatique choisit lui-même les niveaux.
		var bot := SelftestBot.new()
		bot.main = self
		bot.capture_dir = capture_dir
		bot.capture_map = capture_map
		bot.start_checkpoint = maxi(forced_checkpoint, 0)
		add_child(bot)
		return

	Progress.load_save()
	if direct and LEVELS.has(level_id):
		load_level(level_id, maxi(forced_checkpoint, 0))
	else:
		show_map()


## Les niveaux construits, hors salle d'essai.
func ready_levels() -> Array:
	var ids: Array = []
	for id: StringName in LEVELS:
		if id != &"arena":
			ids.append(id)
	return ids


## Affiche la carte. Le niveau en cours, s'il y en a un, est abandonné.
func show_map() -> void:
	_drop_level()
	_drop_map()
	Engine.time_scale = 1.0
	get_tree().paused = false
	world_map = WorldMap.new()
	world_map.available = ready_levels()
	world_map.level_chosen.connect(_on_level_chosen)
	add_child(world_map)


## Charge un niveau, à partir d'un point de reprise.
func load_level(id: StringName, checkpoint := 0) -> void:
	_drop_level()
	_drop_map()
	level_id = id
	_checkpoint = checkpoint
	Engine.time_scale = 1.0

	level = LEVELS[id].new()
	level.start_checkpoint = checkpoint
	level.scripted = scripted
	level.checkpoint_reached.connect(_on_checkpoint)
	level.failed.connect(_on_failed)
	level.completed.connect(_on_completed)
	level.quit_requested.connect(show_map)
	add_child(level)
	level_loaded.emit(level)


func _drop_level() -> void:
	if level != null:
		remove_child(level)
		level.queue_free()
		level = null


func _drop_map() -> void:
	if world_map != null:
		remove_child(world_map)
		world_map.queue_free()
		world_map = null


func _on_level_chosen(id: StringName) -> void:
	load_level(id, 0)


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
	Progress.mark_completed(level_id)
	Progress.set_resume_point(level_id, 0)
	done.hud.show_message("%s\nLes morts reposent.\nNiveau %d — Or : %d" % [
		done.title.to_upper(), Progress.hero_level, Progress.gold], 5.0)
	if scripted:
		return
	await _pause(5.5)
	if level == done:
		show_map()


## Attente qui ignore l'arrêt sur image des coups.
func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
