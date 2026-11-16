class_name Refuge
extends Level
## Le moulin, hors des murs : le refuge. Trois vivants y survivent : Maud, la
## meunière, qui tient la boutique ; frère Anselme, qui enseigne les rites ;
## et Tibert, qui pose des questions. On s'en approche et on touche le bouton
## PARLER ; la route, au sud, ramène à la carte (bouton PARTIR).
##
## Il n'y a ni morts ni combat : c'est le seul endroit calme du jeu.

const START := Vector3(0.0, 0.0, 5.0)
const EXIT := Vector3(0.0, 0.0, 9.5)
const EXIT_REACH := 2.8

var _npcs: Array[Npc] = []
var _busy := false
var _visits := {}
var _rotor: Node3D


func _init() -> void:
	title = "Le moulin"


func _checkpoint_position(_index: int) -> Vector3:
	return START


# --- Scénario -----------------------------------------------------------------

func _run(_checkpoint: int) -> void:
	hud.hide_counts()
	hero.interacted.connect(_on_interacted)
	await say("LE MOULIN", 2.4)
	hud.show_message("Hors des murs, la nuit est plus calme.", 4.0)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if hero == null:
		return
	if _near_npc() != null:
		hero.interaction_label = "PARLER"
	elif Vector2(hero.global_position.x - EXIT.x, hero.global_position.z - EXIT.z).length() <= EXIT_REACH:
		hero.interaction_label = "PARTIR"
	else:
		hero.interaction_label = ""


func _process(delta: float) -> void:
	super._process(delta)
	if _rotor != null:
		_rotor.rotation.z += delta * 0.35


func _near_npc() -> Npc:
	var best: Npc = null
	var best_distance := Npc.REACH
	for npc in _npcs:
		var offset := npc.global_position - hero.global_position
		offset.y = 0.0
		if offset.length() <= best_distance:
			best_distance = offset.length()
			best = npc
	return best


# --- Les conversations --------------------------------------------------------

func _on_interacted() -> void:
	if _busy:
		return
	var npc := _near_npc()
	if npc != null:
		_talk(npc)
	elif hero.interaction_label == "PARTIR":
		quit_requested.emit()


## Parle au personnage le plus proche : sa prochaine conversation, ou une
## phrase de repli s'il n'a rien de neuf, puis son service (boutique, rites).
func talk_to_nearest() -> void:
	var npc := _near_npc()
	if npc != null and not _busy:
		_talk(npc)


func _talk(npc: Npc) -> void:
	_busy = true
	var data: Dictionary = RefugeTexts.NPCS[npc.id]
	var conversation := RefugeTexts.next_conversation(npc.id)
	var lines: Array = []
	if conversation.is_empty():
		var visit: int = _visits.get(npc.id, 0)
		_visits[npc.id] = visit + 1
		lines = [RefugeTexts.idle_line(npc.id, visit)]
	else:
		lines = conversation["lines"]
	var actions: Array = data["services"].duplicate()
	actions.append({"id": &"leave", "label": "Partir"})

	dialogue = DialogueBox.new()
	add_child(dialogue)
	dialogue.open(data["name"], lines, actions)
	var action: StringName = await dialogue.finished
	if not conversation.is_empty():
		Progress.hear(conversation["id"])
	if action == &"shop":
		shop = ShopScreen.new()
		add_child(shop)
		await shop.closed
	elif action == &"forget":
		await _forget_rites()
	elif action == &"advanced":
		advanced_screen = AdvancedRitesScreen.new()
		add_child(advanced_screen)
		await advanced_screen.closed
	elif action == &"bestiary":
		bestiary = BestiaryScreen.new()
		add_child(bestiary)
		await bestiary.closed
	_busy = false


## Frère Anselme aide à désapprendre : après confirmation, tous les rites
## s'oublient et leurs points reviennent.
func _forget_rites() -> void:
	var ask := DialogueBox.new()
	add_child(ask)
	dialogue = ask
	ask.open("Frère Anselme", ["Veux-tu vraiment oublier tout ce que tu as appris ? Tu retrouveras tous tes points, et tu pourras choisir autrement."],
		[{"id": &"forget_yes", "label": "Oui, oublier"}, {"id": &"leave", "label": "Non"}])
	var answer: StringName = await ask.finished
	if answer != &"forget_yes":
		return
	var refunded := Progress.forget_skills()
	var done := DialogueBox.new()
	add_child(done)
	dialogue = done
	done.open("Frère Anselme", ["C'est fait. %d point%s te sont rendus. Ce qu'on oublie peut toujours s'apprendre de nouveau." % [
		refunded, "s" if refunded > 1 else ""]])
	await done.finished


## La boîte de dialogue et la boutique ouvertes, pour les essais.
var dialogue: DialogueBox
var shop: ShopScreen
var bestiary: BestiaryScreen
var advanced_screen: AdvancedRitesScreen


# --- Décor --------------------------------------------------------------------

func _build() -> void:
	music_track = &"refuge"
	var cells: Array[Vector2] = []
	for col in range(-4, 5):
		for row in range(-7, 3):
			cells.append(Vector2(col * 4.0, row * 4.0))
	pave(GRAVEYARD + "floor_dirt.gltf", cells)
	var stones: Array[Vector2] = []
	for row in range(-10, 7):
		stones.append(Vector2(0.0, row * 2.0))
	pave(GRAVEYARD + "path_A.gltf", stones)

	_build_fence()
	_build_mill()
	_build_fire()
	_build_stall()
	_build_shrine()
	_build_scenery()
	_add_npc(&"maud", Vector3(7.0, 0.0, -9.8), "res://assets/kaykit/adventurers/Barbarian.glb",
		["1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Barbarian_Hat"], 1.0, Color.WHITE, 0.0)
	_add_npc(&"anselme", Vector3(-7.4, 0.0, -9.6), "res://assets/kaykit/adventurers/Mage.glb",
		["Spellbook_open", "1H_Wand", "2H_Staff", "Mage_Hat"], 1.0, Color(0.72, 0.64, 0.54), 15.0)
	_add_npc(&"tibert", Vector3(-2.6, 0.0, -13.0), "res://assets/kaykit/adventurers/Rogue_Hooded.glb",
		["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"], 0.72, Color(0.95, 0.9, 0.85), -20.0)


func _add_npc(id: StringName, at: Vector3, model: String, hidden: Array, scale_value: float, color: Color, yaw: float) -> void:
	var npc := Npc.new()
	npc.id = id
	npc.display_name = RefugeTexts.NPCS[id]["name"]
	npc.model_path = model
	npc.hidden_parts = hidden
	npc.model_scale = scale_value
	npc.tint = color
	npc.yaw_deg = yaw
	npc.position = at
	add_child(npc)
	_npcs.append(npc)
	solid(at, Vector3(1.0, 2.0, 1.0))


## La clôture de la cour : une ouverture au sud, sur la route.
func _build_fence() -> void:
	for x in range(-16, 17, 4):
		grave_piece("fence", Vector3(x, 0.0, -26.0))
		if absf(x) >= 6:
			grave_piece("fence", Vector3(x, 0.0, 11.0))
	for z in range(-24, 11, 4):
		grave_piece("fence_broken" if z % 12 == 0 else "fence", Vector3(-16.0, 0.0, z), 90.0)
		grave_piece("fence", Vector3(16.0, 0.0, z), 90.0)
	for side: float in [-1.0, 1.0]:
		grave_piece("fence_pillar", Vector3(side * 4.2, 0.0, 11.0))
		grave_piece("post_lantern", Vector3(side * 3.2, 0.0, 10.0))
		flame(Vector3(side * 3.2, 2.6, 10.4), 2.2, 9.0)
	solid(Vector3(-16.4, 0.0, -7.0), Vector3(0.8, 4.0, 40.0))
	solid(Vector3(16.4, 0.0, -7.0), Vector3(0.8, 4.0, 40.0))
	solid(Vector3(0.0, 0.0, -26.4), Vector3(34.0, 4.0, 0.8))
	for side: float in [-1.0, 1.0]:
		solid(Vector3(side * 10.0, 0.0, 11.4), Vector3(12.0, 4.0, 0.8))
	solid(Vector3(0.0, 0.0, 13.0), Vector3(10.0, 4.0, 0.8))


## Le moulin, au fond : une tour, un toit, des ailes qui tournent.
func _build_mill() -> void:
	var mill := Node3D.new()
	mill.position = Vector3(0.0, 0.0, -20.0)
	add_child(mill)
	var tower := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 2.3
	body.bottom_radius = 3.4
	body.height = 9.0
	body.radial_segments = 16
	tower.mesh = body
	tower.material_override = Fx.flat(Color(0.3, 0.29, 0.3), 0.0, 0.9)
	tower.position.y = 4.5
	mill.add_child(tower)
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 3.1
	cone.height = 3.4
	cone.radial_segments = 16
	roof.mesh = cone
	roof.material_override = Fx.flat(Color(0.14, 0.09, 0.07))
	roof.position.y = 10.7
	mill.add_child(roof)
	var door := MeshInstance3D.new()
	var plank := BoxMesh.new()
	plank.size = Vector3(1.5, 2.5, 0.3)
	door.mesh = plank
	door.material_override = Fx.flat(Color(0.2, 0.12, 0.08))
	door.position = Vector3(0.0, 1.25, 3.3)
	mill.add_child(door)
	for y: float in [4.6, 7.4]:
		var window := MeshInstance3D.new()
		var pane := BoxMesh.new()
		pane.size = Vector3(0.7, 1.0, 0.3)
		window.mesh = pane
		window.material_override = Fx.glow(Color(1.0, 0.72, 0.3, 1.0))
		window.position = Vector3(0.0, y, 2.55 - (y - 4.6) * 0.1)
		mill.add_child(window)
	# Les ailes.
	_rotor = Node3D.new()
	_rotor.position = Vector3(0.0, 8.2, 3.5)
	mill.add_child(_rotor)
	for i in 4:
		var arm := Node3D.new()
		arm.rotation.z = deg_to_rad(90.0 * i)
		_rotor.add_child(arm)
		var beam := MeshInstance3D.new()
		var spar := BoxMesh.new()
		spar.size = Vector3(0.3, 7.4, 0.14)
		beam.mesh = spar
		beam.material_override = Fx.flat(Color(0.17, 0.11, 0.08))
		beam.position.y = 3.7
		arm.add_child(beam)
		var sail := MeshInstance3D.new()
		var cloth := BoxMesh.new()
		cloth.size = Vector3(1.3, 4.2, 0.06)
		sail.mesh = cloth
		sail.material_override = Fx.flat(Color(0.55, 0.5, 0.42))
		sail.position = Vector3(0.75, 4.2, 0.0)
		arm.add_child(sail)
	flame(Vector3(0.0, 5.0, -16.0), 2.6, 11.0)
	solid(Vector3(0.0, 0.0, -20.0), Vector3(7.0, 4.0, 7.0))


## Le feu, au milieu de la cour.
func _build_fire() -> void:
	var at := Vector3(0.0, 0.0, -4.0)
	for i in 8:
		var angle := TAU * i / 8.0
		var rock := MeshInstance3D.new()
		var block := BoxMesh.new()
		block.size = Vector3(0.5, 0.3, 0.4)
		rock.mesh = block
		rock.material_override = Fx.flat(Color(0.25, 0.24, 0.24))
		rock.position = at + Vector3(cos(angle), 0.15, sin(angle)) * 1.0
		rock.rotation.y = -angle
		add_child(rock)
	for yaw: float in [20.0, 100.0]:
		var log := MeshInstance3D.new()
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.09
		trunk.bottom_radius = 0.11
		trunk.height = 1.3
		log.mesh = trunk
		log.material_override = Fx.flat(Color(0.2, 0.12, 0.07))
		log.position = at + Vector3(0.0, 0.2, 0.0)
		log.rotation = Vector3(0.0, deg_to_rad(yaw), deg_to_rad(90.0))
		add_child(log)
	var fire := MeshInstance3D.new()
	var flame_cone := CylinderMesh.new()
	flame_cone.top_radius = 0.0
	flame_cone.bottom_radius = 0.42
	flame_cone.height = 1.1
	fire.mesh = flame_cone
	fire.material_override = Fx.glow(Color(1.0, 0.55, 0.2, 0.9))
	fire.position = at + Vector3(0.0, 0.7, 0.0)
	add_child(fire)
	flame(at + Vector3(0.0, 1.2, 0.0), 3.4, 13.0)
	solid(at, Vector3(2.0, 0.8, 2.0))


## L'étal de Maud, à droite : une table, un auvent, des sacs et des tonneaux.
func _build_stall() -> void:
	var table := MeshInstance3D.new()
	var top := BoxMesh.new()
	top.size = Vector3(3.4, 0.14, 1.4)
	table.mesh = top
	table.material_override = Fx.flat(Color(0.22, 0.14, 0.09))
	table.position = Vector3(7.0, 0.95, -8.4)
	add_child(table)
	for dx: float in [-1.5, 1.5]:
		var leg := MeshInstance3D.new()
		var post := BoxMesh.new()
		post.size = Vector3(0.16, 0.95, 0.16)
		leg.mesh = post
		leg.material_override = table.material_override
		leg.position = Vector3(7.0 + dx, 0.47, -8.4)
		add_child(leg)
	solid(Vector3(7.0, 0.0, -8.4), Vector3(3.6, 1.2, 1.6))
	for dx: float in [-1.9, 1.9]:
		var pole := MeshInstance3D.new()
		var mast := CylinderMesh.new()
		mast.top_radius = 0.07
		mast.bottom_radius = 0.09
		mast.height = 2.7
		pole.mesh = mast
		pole.material_override = Fx.flat(Color(0.2, 0.13, 0.08))
		pole.position = Vector3(7.0 + dx, 1.35, -10.6)
		add_child(pole)
	var awning := MeshInstance3D.new()
	var cloth := BoxMesh.new()
	cloth.size = Vector3(4.4, 0.1, 1.8)
	awning.mesh = cloth
	awning.material_override = Fx.flat(Color(0.4, 0.14, 0.1))
	# Derrière Maud et au-dessus : de la caméra, il ne la cache pas.
	awning.position = Vector3(7.0, 2.85, -11.0)
	awning.rotation.x = deg_to_rad(-14.0)
	add_child(awning)
	for at: Vector3 in [Vector3(5.6, 1.1, -8.4), Vector3(6.4, 1.1, -8.3), Vector3(8.4, 1.1, -8.5)]:
		var sack := MeshInstance3D.new()
		var bag := SphereMesh.new()
		bag.radius = 0.28
		bag.height = 0.5
		sack.mesh = bag
		sack.material_override = Fx.flat(Color(0.5, 0.44, 0.33))
		sack.position = at
		add_child(sack)
	place("barrel_large.glb", Vector3(10.2, 0.0, -10.4))
	solid(Vector3(10.2, 0.0, -10.4), Vector3(1.8, 2.0, 1.8))
	place("barrel_small_stack.glb", Vector3(4.2, 0.0, -10.8), 30.0)
	grave_piece("candle_melted", Vector3(7.8, 1.02, -8.3))
	grave_piece("lantern_standing", Vector3(5.0, 0.0, -7.0))
	flame(Vector3(5.0, 1.0, -7.0), 2.2, 9.0)


## Le coin de frère Anselme, à gauche : des bougies, un banc.
func _build_shrine() -> void:
	var altar := grave_piece("shrine_candles", Vector3(-10.2, 0.0, -11.8))
	altar.scale = Vector3.ONE * 1.6
	solid(Vector3(-10.2, 0.0, -11.8), Vector3(2.0, 2.0, 2.0))
	var plaque := grave_piece("plaque_candles", Vector3(-4.8, 0.0, -12.0))
	plaque.scale = Vector3.ONE * 1.1
	solid(Vector3(-4.8, 0.0, -12.0), Vector3(2.2, 1.2, 2.2))
	var bench := grave_piece("bench", Vector3(-11.2, 0.0, -7.6), 90.0)
	bench.scale = Vector3.ONE * 1.5
	solid(Vector3(-11.2, 0.0, -7.6), Vector3(1.2, 0.7, 3.0))
	flame(Vector3(-7.6, 1.7, -11.4), 2.2, 10.0)


## Autour : des arbres morts, la rivière à l'est.
func _build_scenery() -> void:
	for at: Vector3 in [Vector3(-19.0, 0.0, -10.0), Vector3(-18.0, 0.0, 4.0), Vector3(19.0, 0.0, -18.0),
			Vector3(-14.0, 0.0, -30.0), Vector3(12.0, 0.0, -30.0), Vector3(-12.0, 0.0, 15.0), Vector3(14.0, 0.0, 15.0)]:
		grave_piece("tree_dead_large" if int(absf(at.x)) % 2 == 0 else "tree_dead_medium", at, at.x * 17.0)
	var river := MeshInstance3D.new()
	var water := PlaneMesh.new()
	water.size = Vector2(14.0, 70.0)
	river.mesh = water
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.09, 0.2, 0.92)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.5
	material.roughness = 0.2
	river.material_override = material
	river.position = Vector3(26.0, -0.05, -8.0)
	add_child(river)
