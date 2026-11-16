class_name Gear
extends RefCounted
## L'équipement que le héros peut porter, par emplacement. Chaque objet est une
## vraie pièce du modèle du chevalier (ou un modèle posé à sa main) : ce qui
## s'affiche sur le héros, dans le carnet, dans la boutique et dans les icônes
## est donc toujours le même objet.
##
## Un objet peut donner : `max_health`, `damage_scale`, `speed_scale`,
## `attack_speed`, `dodge_cooldown` (en plus), `guard` (part de dégâts évitée
## quand le héros est agenouillé : Repos ou corde) et `thorns` (dégâts rendus à
## celui qui le frappe au corps à corps).

const SLOTS: Array[StringName] = [&"shield", &"weapon"]
const SLOT_NAMES := {&"shield": "Bouclier", &"weapon": "Arme"}
const DEFAULTS := {&"shield": &"ecu_rectangle", &"weapon": &"epee"}

## Les pièces du modèle qui sont de l'équipement : toutes cachées, puis on
## montre celles qu'on porte.
const PARTS: Array[String] = ["Rectangle_Shield", "Badge_Shield", "Round_Shield", "Spike_Shield",
	"1H_Sword", "2H_Sword", "1H_Sword_Offhand"]
const EXTRA_NAME := "GearExtra"

const ITEMS := {
	&"ecu_rectangle": {
		"slot": &"shield", "name": "Écu rectangulaire", "part": "Rectangle_Shield", "cost": 0,
		"text": "L'écu de la légion. Il couvre quand on s'agenouille près d'un corps.",
		"stats": {"guard": 0.20},
	},
	&"ecu_insigne": {
		"slot": &"shield", "name": "Écu à l'insigne", "part": "Badge_Shield", "cost": 140,
		"text": "Un écu frappé d'un insigne : un peu plus de fer, un peu plus de souffle.",
		"stats": {"max_health": 25},
	},
	&"rondache": {
		"slot": &"shield", "name": "Rondache", "part": "Round_Shield", "cost": 220,
		"text": "Large et lourde. Elle protège bien celui qui reste à genoux, mais ralentit.",
		"stats": {"guard": 0.40, "speed_scale": -0.05},
	},
	&"ecu_pointes": {
		"slot": &"shield", "name": "Écu à pointes", "part": "Spike_Shield", "cost": 260,
		"text": "Qui frappe de près se blesse sur les pointes.",
		"stats": {"thorns": 8},
	},
	&"epee": {
		"slot": &"weapon", "name": "Épée", "part": "1H_Sword", "cost": 0,
		"text": "L'épée de la légion. Rapide, sûre.",
		"stats": {},
	},
	&"lame_longue": {
		"slot": &"weapon", "name": "Lame longue", "part": "2H_Sword", "cost": 300,
		"text": "Plus longue et plus lourde. Elle fend davantage, mais l'esquive revient plus lentement.",
		"stats": {"damage_scale": 0.25, "dodge_cooldown": 0.2},
	},
	&"hache": {
		"slot": &"weapon", "name": "Hache", "model": "res://assets/kaykit/skeletons/Skeleton_Axe.gltf",
		"hand": "handslot_r", "cost": 280,
		"text": "Un gros coup, un geste plus lent.",
		"stats": {"damage_scale": 0.45, "attack_speed": -0.2},
	},
}

const STAT_TEXT := {
	"max_health": "%+d de vie",
	"damage_scale": "Dégâts %+d %%",
	"speed_scale": "Vitesse %+d %%",
	"attack_speed": "Vitesse des coups %+d %%",
	"dodge_cooldown": "Esquive %+.1f s plus lente",
	"guard": "Garde : −%d %% de dégâts au Repos et en coupant",
	"thorns": "Rend %d dégâts à qui te frappe de près",
}


## Les effets d'un objet, en phrases.
static func describe(id: StringName) -> Array[String]:
	var lines: Array[String] = []
	var stats: Dictionary = ITEMS[id]["stats"]
	for key: String in stats:
		var value: float = stats[key]
		match key:
			"max_health", "thorns":
				lines.append(STAT_TEXT[key] % int(value))
			"damage_scale", "speed_scale", "attack_speed", "guard":
				lines.append(STAT_TEXT[key] % int(round(value * 100.0)))
			"dodge_cooldown":
				lines.append(STAT_TEXT[key] % value)
	if lines.is_empty():
		lines.append("Aucun effet particulier.")
	return lines


## Montre sur un modèle de chevalier exactement ce qu'il porte : `equipped` est
## {emplacement → objet} ; ce qui manque prend la valeur par défaut.
static func apply(model: Node3D, equipped: Dictionary) -> void:
	for part_name in PARTS:
		var part := model.find_child(part_name, true, false) as Node3D
		if part != null:
			part.visible = false
	var old := model.find_child(EXTRA_NAME, true, false)
	if old != null:
		old.get_parent().remove_child(old)
		old.queue_free()
	for slot in SLOTS:
		var id: StringName = equipped.get(slot, equipped.get(String(slot), DEFAULTS[slot]))
		var item: Dictionary = ITEMS[id]
		if item.has("part"):
			var part := model.find_child(item["part"], true, false) as Node3D
			if part != null:
				part.visible = true
		elif item.has("model"):
			var hand := model.find_child(item["hand"], true, false) as Node3D
			var scene := load(item["model"]) as PackedScene
			if hand != null and scene != null:
				var extra := scene.instantiate() as Node3D
				extra.name = EXTRA_NAME
				hand.add_child(extra)


static func items_in(slot: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in ITEMS:
		if ITEMS[id]["slot"] == slot:
			ids.append(id)
	return ids
