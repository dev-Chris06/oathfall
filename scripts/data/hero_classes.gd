class_name HeroClasses
extends RefCounted
## Les quatre postes de la dernière légion d'Orvana.
##
## Les quatre classes sont déclarées dès le départ pour que le reste du jeu
## soit écrit autour d'elles. Seul le Porte-glaive est jouable pour l'instant :
## les autres le deviendront une fois le chapitre 1 terminé.
##
## Chaque classe nomme ses animations ici, pour que le code du héros ne dépende
## jamais des noms propres à un pack de modèles : changer de modèle revient à
## changer ce tableau.

const DEFAULT := &"porte_glaive"

const CLASSES := {
	&"porte_glaive": {
		"name": "Porte-glaive",
		"weapon": "Épée et bouclier",
		"summary": "Équilibré. Pare les coups, même pendant le rite du Repos.",
		"model": "res://assets/kaykit/adventurers/Knight.glb",
		"available": true,
		# Le modèle porte toutes ses armes à la fois : on masque les autres.
		"hidden_parts": ["1H_Sword_Offhand", "2H_Sword", "Badge_Shield", "Round_Shield", "Spike_Shield"],
		"move_speed": 6.0,
		"animations": {
			"idle": "Idle",
			"run": "Running_A",
			"dodge": "Dodge_Forward",
			"hit": "Hit_A",
			"death": "Death_A",
			"block": "Blocking",
			"rite": "Interact",
			"drink": "Use_Item",
		},
		# Enchaînement de base : chaque coup a ses dégâts et sa vitesse.
		"attacks": [
			{"animation": "1H_Melee_Attack_Slice_Diagonal", "damage": 10, "speed": 1.5},
			{"animation": "1H_Melee_Attack_Slice_Horizontal", "damage": 12, "speed": 1.5},
			{"animation": "1H_Melee_Attack_Chop", "damage": 20, "speed": 1.3},
		],
	},
	&"briseur": {
		"name": "Briseur",
		"weapon": "Arme à deux mains",
		"summary": "Lent. Frappe plusieurs ennemis, dont les corps tardent à se relever.",
		"model": "",
		"available": false,
	},
	&"eclaireur": {
		"name": "Éclaireur",
		"weapon": "Dagues et arc",
		"summary": "Rapide et fragile. Donne le Repos très vite, mais de tout près.",
		"model": "",
		"available": false,
	},
	&"aumonier": {
		"name": "Aumônier",
		"weapon": "Bâton",
		"summary": "Combat à distance. Donne le Repos de loin, mais lentement.",
		"model": "",
		"available": false,
	},
}


static func get_class_data(id: StringName) -> Dictionary:
	return CLASSES.get(id, CLASSES[DEFAULT])


static func available_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in CLASSES:
		if CLASSES[id]["available"]:
			ids.append(id)
	return ids
