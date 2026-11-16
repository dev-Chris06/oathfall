class_name WorldData
extends RefCounted
## La carte d'Orvana : les chapitres et leurs niveaux, dans l'ordre où la
## route les traverse. Seul le chapitre 1 est écrit ; la route compte
## cependant dix chapitres, les suivants restent fermés.

const LEVELS_PER_CHAPTER := 5
const ROUTE_CHAPTERS := 10

## Les quatre étages de la ville, de bas en haut.
const ACTS := [
	{"name": "La ville basse", "title": "Acte I"},
	{"name": "La citadelle", "title": "Acte II"},
	{"name": "La cathédrale", "title": "Acte III"},
	{"name": "Le palais", "title": "Acte IV"},
]

const CHAPTER_1 := {
	"title": "Les Faubourgs muets",
	"levels": [
		{"id": &"la_grille", "name": "La Grille"},
		{"id": &"les_allees", "name": "Les Allées"},
		{"id": &"la_chapelle", "name": "La Chapelle des cendres"},
		{"id": &"l_ossuaire", "name": "L'Ossuaire"},
		{"id": &"la_fosse", "name": "La Fosse"},
	],
}


## Le niveau placé au `index`-ième point de la route, ou un dictionnaire vide.
static func level_at(index: int) -> Dictionary:
	var levels: Array = CHAPTER_1["levels"]
	if index < 0 or index >= levels.size():
		return {}
	return levels[index]


## Place d'un niveau sur la route, ou -1 s'il n'y figure pas.
static func level_index(id: StringName) -> int:
	var levels: Array = CHAPTER_1["levels"]
	for i in levels.size():
		if levels[i]["id"] == id:
			return i
	return -1


## Le numéro d'un chapitre en chiffres romains : le « 1 » de la police
## gothique se lit comme un « i ».
static func roman(number: int) -> String:
	var table := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var text := ""
	for pair in table:
		while number >= pair[0]:
			text += pair[1]
			number -= pair[0]
	return text


static func chapter_levels() -> Array:
	return CHAPTER_1["levels"]
