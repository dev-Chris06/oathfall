class_name CourDArmes
extends Level
## La cour d'armes, hors des murs, près du moulin : l'entraînement, facultatif.
## Le vieux Hugues, un soldat de la légion, y propose deux choses :
##
## - **le parcours** : se déplacer, frapper, donner le Repos, esquiver, boire,
##   verrouiller une cible, lancer un rite, et (si on l'a déjà rencontré)
##   affronter un mort à armure ;
## - **l'entraînement libre** : faire venir un mort déjà rencontré (jamais un
##   inconnu, rien de la suite n'est dévoilé), reprendre braises et fioles.
##
## Rien ne s'y gagne ni ne s'y perd (`Level.practice`) : ni souvenirs, ni or,
## ni braise de la partie, et le héros n'y tombe pas. La route au sud (PARTIR)
## ramène à la carte. Ces textes sont publics : rien du scénario caché.

const START := Vector3(0.0, 0.0, 6.0)
const EXIT := Vector3(0.0, 0.0, 9.5)
const EXIT_REACH := 2.8
const HUGUES_AT := Vector3(-5.0, 0.0, 1.0)
## Là où les morts de l'entraînement se présentent.
const RING := Vector3(0.0, 0.0, -9.0)
## Morts qu'on peut faire venir : les boss ont besoin de leur propre lieu.
const SPARRING := [&"depouille", &"archer_creux", &"porte_cloche", &"fouisseur", &"veuve", &"boucher", &"crieur"]
const NAME := "Le vieux Hugues"

const GREETING := [
	"Un soldat de la légion. Approche. Je suis Hugues : j'ai appris l'épée à plus de recrues que tu n'as vu de morts.",
	"Ici, personne ne meurt pour de bon. Ni toi, ni eux. On s'entraîne, rien de plus : ce que tu gagnes ici ne compte pas là-haut.",
]
const AGAIN := [
	"Encore toi. Bien. La main oublie vite.",
	"La cour est à toi. Choisis.",
	"Mieux vaut suer ici que tomber là-haut.",
]

var _npc: Npc
var _busy := false
var _visits := 0
## Vrai pendant le parcours guidé.
var course_running := false
## Étapes du parcours franchies (pour le test).
var course_steps: Array[StringName] = []
var dialogue: DialogueBox
var _drunk := false
var _cast := false


func _init() -> void:
	title = "La cour d'armes"
	scenery = Scenery.RIVER
	play_area = Rect2(-14.8, -22.0, 29.6, 33.5)
	practice = true
	flask_drop_chance = 0.0


func _checkpoint_position(_index: int) -> Vector3:
	return START


# --- Scénario -----------------------------------------------------------------

func _run(_checkpoint: int) -> void:
	hero.interacted.connect(_on_interacted)
	hero.flask_drunk.connect(func() -> void: _drunk = true)
	hero.rite_cast.connect(func(_id: StringName, _cost: int) -> void: _cast = true)
	# Des braises et des fioles prêtées : elles ne touchent pas à la partie.
	_refill()
	await say("LA COUR D'ARMES", 2.4)
	hud.show_message("Le vieux Hugues t'attend. Approche-toi et touche PARLER.", 4.0)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if hero == null:
		return
	# On n'en meurt pas : Hugues relève qui flanche.
	if not hero.is_dead() and hero.health < int(hero.max_health * 0.3):
		hero.heal(hero.max_health)
		hud.show_message("Hugues te relève : « Debout. Encore. »", 2.0)
	if course_running or _busy:
		hero.interaction_label = ""
	elif _near_hugues():
		hero.interaction_label = "PARLER"
	elif Vector2(hero.global_position.x - EXIT.x, hero.global_position.z - EXIT.z).length() <= EXIT_REACH:
		hero.interaction_label = "PARTIR"
	else:
		hero.interaction_label = ""


func _near_hugues() -> bool:
	var offset := _npc.global_position - hero.global_position
	offset.y = 0.0
	return offset.length() <= Npc.REACH


func _on_interacted() -> void:
	if _busy or course_running:
		return
	if _near_hugues():
		talk()
	elif hero.interaction_label == "PARTIR":
		quit_requested.emit()


## Hugues propose le parcours, l'entraînement libre, ou de partir.
func talk() -> void:
	_busy = true
	var lines: Array = GREETING if _visits == 0 else [AGAIN[(_visits - 1) % AGAIN.size()]]
	_visits += 1
	dialogue = DialogueBox.new()
	add_child(dialogue)
	dialogue.open(NAME, lines, [
		{"id": &"course", "label": "Le parcours"},
		{"id": &"free", "label": "Entraînement libre"},
		{"id": &"leave", "label": "Partir"}])
	var action: StringName = await dialogue.finished
	_busy = false
	if action == &"course":
		run_course()
	elif action == &"free":
		free_training()


# --- Le parcours ----------------------------------------------------------------

## Le parcours guidé, étape par étape. Chaque étape attend que le joueur ait
## fait le geste ; rien ne presse.
func run_course() -> void:
	course_running = true
	course_steps.clear()
	_clear_ring()
	_refill()

	await say("Le parcours. Fais ce que je dis, quand je le dis.", 3.0)

	# 1. Se déplacer.
	hud.show_message("Avance jusqu'à la lueur : le joystick, à gauche.", 4.0)
	await reach(RING + Vector3(0.0, 0.0, 5.0), 2.0)
	course_steps.append(&"move")

	# 2. Frapper, puis 3. le Repos.
	var first := spawn(&"depouille", RING, false)
	first.rise_delay = 40.0
	hud.show_message("Un mort. Frappe-le : bouton FRAPPER.\nTouche plusieurs fois pour enchaîner.", 5.0)
	await wait_until(func() -> bool: return not is_instance_valid(first) or not first.is_standing())
	course_steps.append(&"strike")
	await say("Il est tombé. Il se relèvera.", 2.5)
	hud.show_message("Tiens-toi près du corps et maintiens REPOS,\njusqu'à ce que l'anneau soit plein.", 6.0)
	await until_peace()
	course_steps.append(&"rest")

	# 4. Esquiver.
	await say("Bien. Celui qui repose ne se relève plus.", 2.5)
	var second := spawn(&"depouille", RING, false)
	second.rise_delay = 40.0
	hud.show_message("Quand un mort lève le bras, ESQUIVE :\nle bouton du bond, sous FRAPPER.", 5.0)
	await wait_until(func() -> bool: return hero.is_dodging())
	course_steps.append(&"dodge")
	hud.show_message("C'est ça. Maintenant, abats-le et donne-lui le Repos.", 4.0)
	await until_peace()

	# 5. Boire une fiole.
	hero.flasks = maxi(hero.flasks, 1)
	hero.take_damage(int(hero.max_health * 0.25), hero.global_position + Vector3(0.0, 0.0, -1.0))
	_drunk = false
	hud.show_message("Une blessure. Bois une fiole : bouton FIOLE.\nTu ne te défends pas pendant que tu bois.", 5.0)
	await wait_until(func() -> bool: return _drunk)
	course_steps.append(&"flask")

	# 6. Verrouiller une cible.
	await say("Contre plusieurs, choisis ta cible.", 2.5)
	for x: float in [-2.5, 2.5]:
		spawn(&"depouille", RING + Vector3(x, 0.0, 0.0), false).rise_delay = 40.0
	hud.show_message("Touche CIBLE, le viseur à droite :\ntes coups iront vers le mort marqué d'or.", 5.0)
	await wait_until(func() -> bool: return hero.lock_target != null)
	course_steps.append(&"lock")
	hud.show_message("Abats-les et donne-leur le Repos.", 3.5)
	await until_peace()

	# 7. Les rites, si le joueur en porte.
	if _has_rites():
		_refill()
		_cast = false
		for x: float in [-2.0, 0.0, 2.0]:
			spawn(&"depouille", RING + Vector3(x, 0.0, -1.0), false).rise_delay = 40.0
		hud.show_message("Chaque Repos allume une braise. Les rites les dépensent :\nles boutons autour de FRAPPER. Lances-en un.", 6.0)
		await wait_until(func() -> bool: return _cast)
		course_steps.append(&"rite")
		hud.show_message("Finis-les.", 2.5)
		await until_peace()
	else:
		await say("Les rites de combat viendront avec tes premiers niveaux.", 3.5)

	# 8. Le mort à armure, si on l'a déjà vu.
	if Progress.has_met(&"boucher"):
		await say("Un Boucher. Il ne plie pas sous tes coups.", 3.0)
		var brute := spawn(&"boucher", RING, false)
		brute.rise_delay = 40.0
		hud.show_message("Esquive son coup, puis frappe pendant qu'il reste ouvert.", 5.0)
		await until_peace()
		course_steps.append(&"armor")

	await say("La vue de la caméra se change dans le menu PAUSE.", 3.5)
	course_running = false
	course_steps.append(&"done")
	hud.show_message("Parcours achevé. Reviens quand tu veux.", 4.0)


func _has_rites() -> bool:
	for id: StringName in hero.rite_slots:
		if id != &"":
			return true
	return false


# --- L'entraînement libre -------------------------------------------------------

## Les morts qu'on peut faire venir : ceux déjà rencontrés, sauf les boss. La
## Dépouille est toujours là : c'est le premier mort du jeu.
func sparring_types() -> Array[StringName]:
	var types: Array[StringName] = []
	for id: StringName in SPARRING:
		if id == &"depouille" or Progress.has_met(id):
			types.append(id)
	return types


func free_training() -> void:
	_busy = true
	var actions: Array = []
	for id: StringName in sparring_types():
		actions.append({"id": StringName("spawn_" + String(id)), "label": String(EnemyTypes.get_type(id)["name"])})
	actions.append({"id": &"refill", "label": "Braises et fioles"})
	actions.append({"id": &"clear", "label": "Renvoyer les morts"})
	actions.append({"id": &"leave", "label": "Fermer"})
	dialogue = DialogueBox.new()
	add_child(dialogue)
	dialogue.open(NAME, ["Qui veux-tu affronter ? Seulement ceux que tu as déjà vus : je ne t'apprendrai pas à craindre ce que tu ne connais pas."], actions)
	var action: StringName = await dialogue.finished
	_busy = false
	choose(action)


## Applique un choix de l'entraînement libre.
func choose(action: StringName) -> void:
	var text := String(action)
	if text.begins_with("spawn_"):
		var id := StringName(text.trim_prefix("spawn_"))
		if id in sparring_types():
			var enemy := spawn(id, RING + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-2.0, 1.0)), false)
			enemy.rise_delay = 30.0
			hud.show_message("%s. À toi." % EnemyTypes.get_type(id)["name"], 2.0)
	elif action == &"refill":
		_refill()
		hud.show_message("Braises et fioles rendues.", 2.0)
	elif action == &"clear":
		_clear_ring()


## Braises au plus haut, fioles pleines : prêtées, pas prises sur la partie.
func _refill() -> void:
	hero.embers = RiteData.MAX_EMBERS
	hero.flasks = int(Supplies.FLASK["max"])
	hud.set_embers(hero.embers)


func _clear_ring() -> void:
	for enemy in _enemies.duplicate():
		_enemies.erase(enemy)
		enemy.queue_free()


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	music_track = &"refuge"
	var cells: Array[Vector2] = []
	for col in range(-3, 4):
		for row in range(-5, 3):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(GRAVEYARD + "floor_dirt.gltf", cells)
	var stones: Array[Vector2] = []
	for row in range(-1, 6):
		stones.append(Vector2(0.0, row * 2.0))
	pave(GRAVEYARD + "path_A.gltf", stones)
	_build_fence()
	_build_yard()
	_npc = Npc.new()
	_npc.id = &"hugues"
	_npc.display_name = NAME
	_npc.model_path = "res://assets/kaykit/adventurers/Knight.glb"
	# Un vieux soldat : pas d'écu, l'épée longue, le gris des années.
	_npc.hidden_parts = ["1H_Sword_Offhand", "1H_Sword", "Badge_Shield", "Round_Shield", "Spike_Shield", "Rectangle_Shield"]
	_npc.tint = Color(0.68, 0.66, 0.64)
	_npc.yaw_deg = 40.0
	_npc.position = HUGUES_AT
	add_child(_npc)
	solid(HUGUES_AT, Vector3(1.0, 2.0, 1.0))


## La palissade : trois côtés fermés, et au sud le portail de la route, d'où
## l'on part par le bouton PARTIR.
func _build_fence() -> void:
	for x in range(-14, 15, 4):
		grave_piece("fence", Vector3(x, 0.0, -22.0))
		if absf(x) >= 6:
			grave_piece("fence", Vector3(x, 0.0, 11.0))
	for z in range(-20, 11, 4):
		grave_piece("fence", Vector3(-14.0, 0.0, z), 90.0)
		grave_piece("fence", Vector3(14.0, 0.0, z), 90.0)
	for side: float in [-1.0, 1.0]:
		grave_piece("fence_pillar", Vector3(side * 2.1, 0.0, 11.0))
		grave_piece("fence", Vector3(side * 4.1, 0.0, 11.0))
		solid(Vector3(side * 3.2, 0.0, 11.0), Vector3(2.4, 4.0, 1.0))
		grave_piece("post_lantern", Vector3(side * 3.6, 0.0, 9.6))
		flame(Vector3(side * 3.6, 2.6, 10.0), 2.2, 9.0)
	add_gate(Vector3(0.0, 0.0, 11.0), 0)
	solid(Vector3(-14.4, 0.0, -5.5), Vector3(0.8, 4.0, 34.0))
	solid(Vector3(14.4, 0.0, -5.5), Vector3(0.8, 4.0, 34.0))
	solid(Vector3(0.0, 0.0, -22.4), Vector3(30.0, 4.0, 0.8))
	for side: float in [-1.0, 1.0]:
		solid(Vector3(side * 9.0, 0.0, 11.4), Vector3(10.0, 4.0, 0.8))


## La cour : des poteaux d'exercice, des bancs, des lanternes.
func _build_yard() -> void:
	for at: Vector3 in [Vector3(-9.0, 0.0, -14.0), Vector3(9.0, 0.0, -14.0), Vector3(-9.0, 0.0, -4.0), Vector3(9.0, 0.0, -4.0)]:
		_post(at)
	grave_piece("bench", Vector3(-11.0, 0.0, 5.0), 90.0)
	grave_piece("bench", Vector3(11.0, 0.0, 5.0), -90.0)
	for at: Vector3 in [Vector3(-12.0, 0.0, -19.0), Vector3(12.0, 0.0, -19.0)]:
		grave_piece("lantern_standing", at)
		flame(at + Vector3(0.0, 1.6, 0.0), 2.0, 9.0)
	grave_piece("tree_dead_medium", Vector3(-11.5, 0.0, -9.0))
	grave_piece("tree_dead_small", Vector3(11.5, 0.0, 1.0))


## Un poteau d'exercice : un pieu, une traverse, des entailles d'épée.
func _post(at: Vector3) -> void:
	var wood := Fx.flat(Color(0.24, 0.16, 0.1))
	var pole := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.16
	shaft.bottom_radius = 0.2
	shaft.height = 2.0
	shaft.radial_segments = 8
	shaft.rings = 1
	pole.mesh = shaft
	pole.material_override = wood
	pole.position = at + Vector3(0.0, 1.0, 0.0)
	add_child(pole)
	var arm := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(1.3, 0.16, 0.16)
	arm.mesh = bar
	arm.material_override = wood
	arm.position = at + Vector3(0.0, 1.45, 0.0)
	add_child(arm)
	solid(at, Vector3(0.6, 2.0, 0.6))
