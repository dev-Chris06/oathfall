extends Node
## Point d'entrée. Le jeu s'ouvre sur l'écran-titre (continuer, nouvelle
## partie, options), puis sur la carte d'Orvana, où l'on choisit un niveau ou
## le refuge ; la fin d'un niveau, ou son abandon depuis le carnet, ramène à la
## carte. Un héros qui tombe se relève au dernier point de reprise du niveau.
##
## Arguments, après `--` :
##   --selftest            un joueur automatique livre les combats d'essai,
##                         traverse les niveaux et essaie la carte
##   --capture=DOSSIER     même chose, en enregistrant des images
##   --portraits           fabrique les portraits du bestiaire (outil)
##   --icons               fabrique les icônes des objets (outil)
##   --terrain             fabrique le relief de la carte (outil)
##   --map                 avec --capture : photographie la carte
##   --arena               lance la salle d'essai au lieu de l'écran-titre
##   --level=ID            lance ce niveau (la_grille, les_allees…)
##   --checkpoint=N        commence au point de reprise N
##
##   godot --headless --path . --fixed-fps 60 -- --selftest

signal level_loaded(level: Level)

const LEVELS := {
	&"arena": preload("res://scripts/levels/arena.gd"),
	&"la_grille": preload("res://scripts/levels/la_grille.gd"),
	&"les_allees": preload("res://scripts/levels/les_allees.gd"),
	&"la_chapelle": preload("res://scripts/levels/la_chapelle.gd"),
	&"l_ossuaire": preload("res://scripts/levels/l_ossuaire.gd"),
	&"la_fosse": preload("res://scripts/levels/la_fosse.gd"),
	&"la_porte_des_halles": preload("res://scripts/levels/la_porte_des_halles.gd"),
	&"les_etals": preload("res://scripts/levels/les_etals.gd"),
	&"la_balance": preload("res://scripts/levels/la_balance.gd"),
	&"les_caves": preload("res://scripts/levels/les_caves.gd"),
	&"la_halle_du_prevot": preload("res://scripts/levels/la_halle_du_prevot.gd"),
	&"le_quai_des_fuyards": preload("res://scripts/levels/le_quai_des_fuyards.gd"),
	&"les_barges": preload("res://scripts/levels/les_barges.gd"),
	&"refuge": preload("res://scripts/levels/refuge.gd"),
	&"cour_d_armes": preload("res://scripts/levels/cour_d_armes.gd"),
}

## Lieux qui ne sont pas des niveaux de la route : ni repas, ni point de
## reprise, ni fin enregistrée.
const CALM_PLACES := [&"refuge", &"cour_d_armes"]

var level: Level
var world_map: WorldMap
var title_screen: TitleScreen
var opening: OpeningScreen
var level_id := &"la_grille"
var scripted := false

var _checkpoint := 0


func _ready() -> void:
	var capture_dir := ""
	var capture_map := false
	var only_level: StringName = &""
	var direct := false
	var forced_checkpoint := -1
	var camera_mode := GameCamera.Mode.CLASSIC
	for arg in OS.get_cmdline_user_args():
		if arg == "--selftest":
			scripted = true
		elif arg.begins_with("--capture="):
			scripted = true
			capture_dir = arg.trim_prefix("--capture=")
		elif arg.begins_with("--camera="):
			# Vue des captures : 0 classique, 1 épaule, 2 première personne.
			camera_mode = clampi(int(arg.trim_prefix("--camera=")), 0, GameCamera.Mode.size() - 1) as GameCamera.Mode
		elif arg == "--map":
			capture_map = true
		elif arg.begins_with("--only="):
			only_level = StringName(arg.trim_prefix("--only="))
		elif arg == "--portraits" or arg == "--icons":
			var tool := PortraitTool.new()
			add_child(tool)
			tool.call_deferred("run" if arg == "--portraits" else "run_icons")
			return
		elif arg == "--terrain":
			var plan := MapScene.new()
			var error := MapTerrain.bake(plan.route)
			plan.free()
			get_tree().quit(0 if error == OK else 1)
			return
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
		# Le hasard du jeu (monticules de la Fossoyeuse, apparitions) est fixé :
		# un test qui réussit une fois réussit toujours, le build ne dépend pas
		# de la chance.
		seed(20261116)
		# Les tests ne touchent pas à la vraie partie du joueur.
		Progress.save_path = "user://essai.json"
		Progress.delete_save()
		Progress.reset()
		Audio.use_test_settings()
		# Les tests et captures ne dépendent pas de la vue choisie par le joueur.
		GameCamera.mode = camera_mode
		# Le joueur automatique choisit lui-même les niveaux.
		var bot := SelftestBot.new()
		bot.main = self
		bot.capture_dir = capture_dir
		bot.capture_map = capture_map
		bot.only_level = only_level
		bot.start_checkpoint = maxi(forced_checkpoint, 0)
		add_child(bot)
		return

	Progress.load_save()
	if direct and LEVELS.has(level_id):
		load_level(level_id, maxi(forced_checkpoint, 0))
	else:
		show_title()


## Les niveaux construits, hors salle d'essai.
func ready_levels() -> Array:
	var ids: Array = []
	for id: StringName in LEVELS:
		if id != &"arena" and id != &"cour_d_armes":
			ids.append(id)
	return ids


## L'écran-titre : continuer, nouvelle partie, options.
func show_title() -> void:
	_drop_level()
	_drop_map()
	_drop_screens()
	Engine.time_scale = 1.0
	get_tree().paused = false
	Audio.music(&"title")
	title_screen = TitleScreen.new()
	title_screen.continue_pressed.connect(show_map)
	title_screen.new_game_pressed.connect(start_new_game)
	title_screen.training_pressed.connect(func() -> void: load_level(&"cour_d_armes"))
	add_child(title_screen)


## Une partie neuve : tout est remis à zéro, puis le texte d'ouverture, puis la
## carte.
func start_new_game() -> void:
	Progress.new_game()
	_drop_screens()
	opening = OpeningScreen.new()
	opening.finished.connect(show_map)
	add_child(opening)


## Affiche la carte. Le niveau en cours, s'il y en a un, est abandonné.
func show_map() -> void:
	# La caméra de la carte recule depuis le niveau qu'on quitte.
	var came_from: StringName = level_id if level != null else &""
	Progress.end_level_meal()
	_drop_level()
	_drop_map()
	_drop_screens()
	Engine.time_scale = 1.0
	get_tree().paused = false
	Audio.music(&"map")
	world_map = WorldMap.new()
	world_map.available = ready_levels()
	# Les essais ne regardent pas les mouvements de caméra.
	world_map.cinematics = not scripted
	world_map.arrived_from = came_from
	world_map.level_chosen.connect(_on_level_chosen)
	world_map.menu_requested.connect(show_title)
	world_map.training_requested.connect(func() -> void: load_level(&"cour_d_armes"))
	add_child(world_map)


## Charge un niveau, à partir d'un point de reprise.
func load_level(id: StringName, checkpoint := 0) -> void:
	_drop_level()
	_drop_map()
	_drop_screens()
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


func _drop_screens() -> void:
	if title_screen != null:
		remove_child(title_screen)
		title_screen.queue_free()
		title_screen = null
	if opening != null:
		remove_child(opening)
		opening.queue_free()
		opening = null


func _drop_map() -> void:
	if world_map != null:
		remove_child(world_map)
		world_map.queue_free()
		world_map = null


func _on_level_chosen(id: StringName) -> void:
	# Un repas emballé se mange en partant pour un niveau (pas pour le moulin).
	if not id in CALM_PLACES:
		Progress.start_level_meal()
	load_level(id, 0)


func _on_checkpoint(index: int) -> void:
	_checkpoint = index
	if level_id != &"arena" and not level_id in CALM_PLACES:
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
	# Le bandeau de victoire a déjà été montré : le niveau se ferme aussitôt.
	var celebrated := done.hud.victory_shown()
	if not celebrated:
		done.hud.show_message("%s\nLes morts reposent.\nNiveau %d — Or : %d" % [
			done.title.to_upper(), Progress.hero_level, Progress.gold], 5.0)
	if scripted:
		return
	await _pause(0.4 if celebrated else 5.5)
	if level == done:
		show_map()


## Attente qui ignore l'arrêt sur image des coups.
func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
