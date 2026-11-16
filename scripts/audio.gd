extends Node
## Le son du jeu : bruitages et musiques. Chargé en permanence sous le nom
## `Audio`. Deux bus (« Musique » et « Sons ») sont créés au démarrage, avec
## leurs volumes réglables dans les options et gardés dans `user://reglages.json`.
##
## Les événements sont déclarés dans `EVENTS` (identifiant → fichiers, volume,
## variation de hauteur) : le reste du jeu ne connaît que `Audio.play(&"clang")`
## et `Audio.music(&"cemetery")`. Les bruitages lourds et les musiques sont
## fabriqués par `tools/audio/generate.py` ; les pas, le tissu et les pièces
## viennent du pack Kenney (CC0).

const SFX := "res://assets/audio/sfx/"
const KEN := "res://assets/audio/kenney/"
const MUSIC := "res://assets/audio/music/"

## Identifiant → { files, db (volume), pitch (variation aléatoire) }.
const EVENTS := {
	&"step": {"files": ["footstep00", "footstep01", "footstep02", "footstep03", "footstep04"], "kenney": true, "db": -12.0, "pitch": 0.1},
	&"swing_light": {"files": ["whoosh_light"], "db": -6.0, "pitch": 0.12},
	&"swing_heavy": {"files": ["whoosh_heavy"], "db": -4.0, "pitch": 0.08},
	&"hit_flesh": {"files": ["impact_flesh"], "db": -3.0, "pitch": 0.12},
	&"hit_heavy": {"files": ["impact_heavy"], "db": -2.0, "pitch": 0.08},
	&"clang": {"files": ["clang"], "db": -6.0, "pitch": 0.1},
	&"dodge": {"files": ["cloth1", "cloth3"], "kenney": true, "db": -6.0, "pitch": 0.1},
	&"hurt": {"files": ["impact_flesh"], "db": 0.0, "pitch": -0.2},
	&"hero_die": {"files": ["hero_die"], "db": -2.0},
	&"rest_done": {"files": ["rest_done"], "db": -3.0},
	&"enemy_fall": {"files": ["bones_fall"], "db": -4.0, "pitch": 0.1},
	&"enemy_rise": {"files": ["bones_rise"], "db": -6.0, "pitch": 0.1},
	&"drink": {"files": ["drink"], "db": -3.0},
	&"heal": {"files": ["heal"], "db": -4.0},
	&"twang": {"files": ["twang"], "db": -5.0, "pitch": 0.1},
	&"bell_toll": {"files": ["bell_toll"], "db": -2.0},
	&"bell_small": {"files": ["bell_small"], "db": -5.0, "pitch": 0.05},
	&"bell_crash": {"files": ["bell_crash"], "db": 0.0},
	&"rope_snap": {"files": ["rope_snap"], "db": -2.0},
	&"quake": {"files": ["quake"], "db": 0.0},
	&"scream": {"files": ["scream"], "db": -2.0},
	&"dig": {"files": ["dig"], "db": -3.0, "pitch": 0.1},
	&"level_done": {"files": ["level_done"], "db": -2.0},
	&"ui_click": {"files": ["ui_click"], "db": -4.0},
	&"ui_select": {"files": ["ui_select"], "db": -4.0},
	&"book_open": {"files": ["bookOpen"], "kenney": true, "db": -4.0},
	&"book_close": {"files": ["bookClose"], "kenney": true, "db": -4.0},
	&"page": {"files": ["bookFlip1"], "kenney": true, "db": -6.0, "pitch": 0.1},
	&"coins": {"files": ["handleCoins"], "kenney": true, "db": -4.0},
	&"equip": {"files": ["clothBelt", "metalLatch"], "kenney": true, "db": -5.0},
	&"gate": {"files": ["creak1", "creak2"], "kenney": true, "db": -2.0},
	&"gate_shut": {"files": ["doorClose_1"], "kenney": true, "db": -2.0},
}

## Musique de chaque ambiance (identifiant → fichier, volume).
const TRACKS := {
	&"title": {"file": "title", "db": -4.0},
	&"map": {"file": "map", "db": -5.0},
	&"cemetery": {"file": "cemetery", "db": -4.0},
	&"underground": {"file": "underground", "db": -4.0},
	&"refuge": {"file": "refuge", "db": -5.0},
	&"boss": {"file": "boss", "db": -3.0},
}

const SETTINGS_PATH := "user://reglages.json"
const VOICES := 14
const FADE := 1.6

## Volumes de 0 à 1.
var music_volume := 0.7
var sfx_volume := 0.9
## Les derniers événements joués (le test automatique les relit).
var log: Array[StringName] = []
## Combien de fois chaque événement a été joué depuis le début.
var heard := {}
var current_track: StringName = &""
## Musique du niveau en cours, que l'on retrouve après un combat de boss.
var level_track: StringName = &""

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _last_played := {}
var _settings_path := SETTINGS_PATH
## En test, les événements sont comptés mais rien n'est joué : le moteur garde
## les lectures en cours à la fermeture et signale alors des fuites.
var _silent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Musique", "Sons"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = "Sons"
		add_child(voice)
		_voices.append(voice)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Musique"
		player.volume_db = -80.0
		add_child(player)
		_music.append(player)
	load_settings()


## À la fermeture, rien ne doit garder un son en mémoire (Godot signale sinon
## des ressources encore utilisées, ce qui fait échouer le build).
func _exit_tree() -> void:
	for voice in _voices:
		voice.stop()
		voice.stream = null
	for player in _music:
		player.stop()
		player.stream = null
	_streams.clear()


## Joue un événement. `db` s'ajoute au volume de l'événement.
func play(id: StringName, db := 0.0) -> void:
	log.append(id)
	heard[id] = int(heard.get(id, 0)) + 1
	if log.size() > 200:
		log = log.slice(100)
	var event: Dictionary = EVENTS.get(id, {})
	if event.is_empty():
		push_warning("Son inconnu : %s" % id)
		return
	if _silent:
		return
	# Un même son ne se répète pas dans la même image (coups simultanés).
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(id, -1000)) < 40:
		return
	_last_played[id] = now
	var files: Array = event["files"]
	var file: String = files[randi() % files.size()]
	var stream := _load((KEN if event.get("kenney", false) else SFX) + file + ".ogg")
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = stream
	voice.volume_db = float(event.get("db", 0.0)) + db
	var spread := float(event.get("pitch", 0.0))
	voice.pitch_scale = 1.0 + (randf() * 2.0 - 1.0) * spread if spread > 0.0 else 1.0 + spread
	voice.play()


## Lance une musique en fondu enchaîné ; la même musique ne redémarre pas.
func music(id: StringName) -> void:
	if id == current_track:
		return
	current_track = id
	log.append(StringName("music:" + String(id)))
	heard[StringName("music:" + String(id))] = int(heard.get(StringName("music:" + String(id)), 0)) + 1
	if _silent:
		return
	var old := _music[_active]
	var tween := create_tween().set_parallel(true)
	tween.tween_property(old, "volume_db", -80.0, FADE)
	tween.chain().tween_callback(old.stop)
	if id == &"" or not TRACKS.has(id):
		return
	var track: Dictionary = TRACKS[id]
	var stream := _load(MUSIC + String(track["file"]) + ".ogg")
	if stream == null:
		return
	_active = 1 - _active
	var player := _music[_active]
	player.stream = stream
	player.volume_db = -80.0
	player.play()
	create_tween().tween_property(player, "volume_db", float(track["db"]), FADE)


func stop_music() -> void:
	music(&"")


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volume("Musique", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volume("Sons", sfx_volume)


func save_settings() -> void:
	var file := FileAccess.open(_settings_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"music": music_volume, "sfx": sfx_volume}))


func load_settings() -> void:
	if FileAccess.file_exists(_settings_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(_settings_path))
		if parsed is Dictionary:
			music_volume = clampf(float(parsed.get("music", music_volume)), 0.0, 1.0)
			sfx_volume = clampf(float(parsed.get("sfx", sfx_volume)), 0.0, 1.0)
	_apply_volume("Musique", music_volume)
	_apply_volume("Sons", sfx_volume)


## Les tests écrivent ailleurs que dans les vrais réglages.
func use_test_settings() -> void:
	_settings_path = "user://reglages_essai.json"
	_silent = true


func _apply_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
		AudioServer.set_bus_mute(index, value <= 0.001)


func _load(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_warning("Fichier audio introuvable : " + path)
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis and path.begins_with(MUSIC):
		(stream as AudioStreamOggVorbis).loop = true
	_streams[path] = stream
	return stream
