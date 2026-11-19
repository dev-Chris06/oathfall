class_name RiteData
extends RefCounted
## Les rites de combat : les attaques spéciales du héros.
##
## Ils ne se rechargent pas avec le temps. Chaque corps mis au repos allume
## une braise (cinq au plus) ; un rite coûte une, deux ou trois braises. On en
## porte trois à la fois, un par bouton autour de FRAPPER, choisis dans le
## carnet. Un rite s'ouvre quand le niveau nommé par `unlock` est terminé (ou,
## pour le Rappel, quand le Sceau des Armes est brisé).
##
## Les valeurs de combat vivent ici ; les animations de chaque rite sont dans
## `HeroClasses` (`rite_animations`).

const MAX_EMBERS := 5
const SLOTS := 3

## Dans l'ordre où on les découvre.
const ORDER := [&"glas", &"linceul", &"cortege", &"tombee", &"requiem", &"litanie", &"cierge", &"absoute", &"rappel"]

const RITES := {
	&"glas": {
		"name": "Glas", "cost": 3, "kind": "Onde autour",
		"text": "Le héros frappe le sol : une onde renverse tous les morts debout autour de lui.",
		"use": "Encerclé. Ensuite, il faut mettre tous ces corps au repos.",
		"unlock": {"level": &"la_grille"},
		"radius": 4.6, "boss_damage": 30,
	},
	&"linceul": {
		"name": "Linceul", "cost": 2, "kind": "Tourbillon",
		"text": "Le héros tourne sur lui-même, lame tendue, et frappe tout ce qui l'entoure à chaque tour.",
		"use": "Au milieu d'un groupe. On avance en tournant.",
		"unlock": {"level": &"la_grille"},
		"duration": 2.0, "radius": 2.7, "damage": 9, "tick": 0.3, "move_speed": 3.2,
	},
	&"cortege": {
		"name": "Cortège", "cost": 1, "kind": "Charge",
		"text": "Une ruée en ligne droite qui traverse les morts : chacun sur le chemin est frappé.",
		"use": "Sortir d'un encerclement en frappant, rejoindre un Archer.",
		"unlock": {"level": &"la_grille"},
		"distance": 7.0, "time": 0.32, "width": 1.5, "damage": 22,
	},
	&"tombee": {
		"name": "Tombée", "cost": 2, "kind": "Bond",
		"text": "Un bond sur le groupe le plus serré : l'impact renverse tout autour du point de chute.",
		"use": "Aller chercher un groupe au loin, une Veuve qui va crier.",
		"unlock": {"level": &"les_allees"},
		"reach": 9.0, "radius": 3.2, "air_time": 0.6, "boss_damage": 25,
	},
	&"requiem": {
		"name": "Requiem", "cost": 2, "kind": "Brise-garde",
		"text": "Un coup lourd fend la garde d'un mort : pendant 4 s, le coup suivant l'abat.",
		"use": "Contre les morts à armure et les boss (pour eux, le coup suivant porte double).",
		"unlock": {"level": &"la_chapelle"},
		"range": 3.2, "damage": 25, "rend_time": 4.0,
	},
	&"litanie": {
		"name": "Litanie", "cost": 2, "kind": "Rafale",
		"text": "Cinq coups rapides sur un seul mort ; le dernier l'abat et le projette.",
		"use": "Abattre vite une cible précise : Crieur, Porte-cloche.",
		"unlock": {"level": &"l_ossuaire"},
		"range": 3.0, "hits": 5, "interval": 0.15, "damage": 8, "boss_damage": 22,
	},
	&"cierge": {
		"name": "Cierge", "cost": 1, "kind": "Zone au sol",
		"text": "Le héros plante un cierge : dans sa lueur, aucun corps ne se relève, et les morts avancent deux fois moins vite.",
		"use": "Contre le Sonneur et la Fossoyeuse, qui relèvent les corps.",
		"unlock": {"level": &"la_fosse"},
		"radius": 4.5, "duration": 10.0, "slow": 0.5,
	},
	&"absoute": {
		"name": "Absoute", "cost": 1, "kind": "Lame à distance",
		"text": "Une lame de lumière part du fer et file droit devant ; elle frappe tous les morts qu'elle traverse.",
		"use": "Contre les Archers creux, qui reculent quand on approche.",
		"unlock": {"level": &"les_etals"},
		"speed": 17.0, "range": 14.0, "width": 1.4, "damage": 26,
	},
	&"rappel": {
		"name": "Rappel", "cost": 3, "kind": "Allié",
		"text": "Le dernier mort mis au repos se relève une fois, à tes côtés, et se bat pour toi.",
		"use": "Pour souffler dans un long combat. Il faut avoir donné un Repos peu avant.",
		"unlock": {"chapter": 6},
		"duration": 12.0, "damage": 16, "interval": 1.1, "speed": 4.5, "memory": 20.0,
	},
}


static func get_rite(id: StringName) -> Dictionary:
	return RITES.get(id, {})


static func cost(id: StringName) -> int:
	return int(RITES.get(id, {}).get("cost", 0))


## Ce qu'il faut faire pour ouvrir un rite, en clair.
static func unlock_text(id: StringName) -> String:
	var unlock: Dictionary = RITES[id]["unlock"]
	if unlock.has("chapter"):
		return "S'ouvre quand le Sceau des Armes est brisé (chapitre %s)." % WorldData.roman(int(unlock["chapter"]))
	var level := WorldData.level_at(WorldData.level_index(unlock["level"]))
	return "S'ouvre après « %s »." % level.get("name", unlock["level"])
