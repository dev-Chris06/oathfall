class_name WorldData
extends RefCounted
## La carte d'Orvana : les chapitres et leurs niveaux, dans l'ordre où la
## route les traverse. La route compte dix chapitres ; ceux qui ne sont pas
## écrits restent fermés.

const LEVELS_PER_CHAPTER := 5
## Les chapitres de la ville, un par voie de la route : trois dans la ville
## basse, trois à la citadelle, trois à la cathédrale, un au palais. Les deux
## derniers du scénario sont sous la ville, derrière la porte des fondations.
const ROUTE_CHAPTERS := 10
const UNDER_CHAPTERS := 2

## Les quatre sceaux qui tiennent le serment, un par étage : chacun se brise
## avec le dernier chapitre de son étage.
const SEALS := [
	{"name": "Sceau des Corps", "act": 0, "chapter": 3},
	{"name": "Sceau des Armes", "act": 1, "chapter": 6},
	{"name": "Sceau des Noms", "act": 2, "chapter": 9},
	{"name": "Sceau du Roi", "act": 3, "chapter": 10},
]

## Les quatre étages de la ville, de bas en haut.
const ACTS := [
	{"name": "La ville basse", "title": "Acte I"},
	{"name": "La citadelle", "title": "Acte II"},
	{"name": "La cathédrale", "title": "Acte III"},
	{"name": "Le palais", "title": "Acte IV"},
]

## Chaque niveau nomme les morts qu'on y croise (`dead`, types de
## `EnemyTypes`) : la fiche du lieu, sur la carte, montre leurs portraits.
const CHAPTER_1 := {
	"title": "Les Faubourgs muets",
	"levels": [
		{"id": &"la_grille", "name": "La Grille", "dead": [&"depouille"]},
		{"id": &"les_allees", "name": "Les Allées", "dead": [&"depouille", &"archer_creux", &"porte_cloche"]},
		{"id": &"la_chapelle", "name": "La Chapelle des cendres", "dead": [&"depouille", &"archer_creux", &"porte_cloche", &"sonneur"]},
		{"id": &"l_ossuaire", "name": "L'Ossuaire", "dead": [&"depouille", &"archer_creux", &"porte_cloche", &"fouisseur", &"veuve"]},
		{"id": &"la_fosse", "name": "La Fosse", "dead": [&"depouille", &"fouisseur", &"fossoyeuse"]},
	],
}

const CHAPTER_2 := {
	"title": "Le Marché aux absents",
	"levels": [
		{"id": &"la_porte_des_halles", "name": "La Porte des halles", "dead": [&"depouille", &"archer_creux", &"porte_cloche"]},
		{"id": &"les_etals", "name": "Les Étals", "dead": [&"depouille", &"archer_creux", &"boucher", &"crieur"]},
		{"id": &"la_balance", "name": "La Balance", "dead": [&"depouille", &"archer_creux", &"crieur", &"peseur"]},
		{"id": &"les_caves", "name": "Les Caves du marché", "dead": [&"depouille", &"porte_cloche", &"fouisseur", &"veuve", &"boucher", &"crieur"]},
		{"id": &"la_halle_du_prevot", "name": "La Halle du Prévôt", "dead": [&"depouille", &"archer_creux", &"boucher", &"crieur", &"prevot"]},
	],
}

## Le chapitre III s'écrit niveau par niveau : seuls ceux qui sont construits
## sont nommés ici.
const CHAPTER_3 := {
	"title": "Les Quais noirs",
	"levels": [
		{"id": &"le_quai_des_fuyards", "name": "Le Quai des fuyards", "dead": [&"depouille", &"archer_creux", &"fouisseur", &"veuve"]},
		{"id": &"les_barges", "name": "Les Barges", "dead": [&"depouille", &"archer_creux", &"noye", &"gaffeur"]},
	],
}

const CHAPTERS := [CHAPTER_1, CHAPTER_2, CHAPTER_3]


## Le niveau placé au `index`-ième point de la route, ou un dictionnaire vide.
static func level_at(index: int) -> Dictionary:
	var levels := chapter_levels()
	if index < 0 or index >= levels.size():
		return {}
	return levels[index]


## Place d'un niveau sur la route, ou -1 s'il n'y figure pas.
static func level_index(id: StringName) -> int:
	var levels := chapter_levels()
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


## Tous les niveaux construits, chapitre après chapitre, dans l'ordre de la route.
static func chapter_levels() -> Array:
	var all: Array = []
	for chapter: Dictionary in CHAPTERS:
		all.append_array(chapter["levels"])
	return all


## Numéro (à partir de 1) du chapitre où se trouve le `index`-ième niveau.
static func chapter_of(index: int) -> int:
	return clampi(index / LEVELS_PER_CHAPTER + 1, 1, CHAPTERS.size())


static func chapter_title(number: int) -> String:
	if number < 1 or number > CHAPTERS.size():
		return ""
	return CHAPTERS[number - 1]["title"]
