class_name Progression
extends RefCounted
## La progression du héros : paliers de niveau et compétences.
##
## Les souvenirs rendus par les morts mis au repos servent d'expérience.
## Chaque niveau gagné donne de la vie et un point de compétence.

## Souvenirs cumulés qu'il faut avoir pour atteindre chaque niveau : l'indice
## 0 correspond au niveau 1. Au-delà du tableau, chaque niveau coûte
## `LATE_STEP` de plus que le précédent.
const LEVEL_THRESHOLDS: Array[int] = [0, 40, 100, 180, 280, 400, 540, 700, 880, 1080]
const LATE_STEP := 220

const HEALTH_PER_LEVEL := 8
const POINTS_PER_LEVEL := 1

## Valeurs du héros avant toute compétence.
const BASE_STATS := {
	# Multiplie les dégâts de chaque coup.
	"damage_scale": 1.0,
	# Secondes de rite nécessaires pour donner le Repos.
	"rite_time": 1.0,
	# Secondes entre deux esquives.
	"dodge_cooldown": 0.8,
	# Vie rendue au héros à chaque Repos donné.
	"rest_heal": 0,
}

## Compétences de chaque classe. Chaque rang donne la valeur finale des
## caractéristiques qu'il touche, et coûte `cost` points.
const SKILLS := {
	&"porte_glaive": [
		{
			"id": &"priere_breve",
			"name": "Prière brève",
			"text": "Le Repos se donne plus vite.",
			"ranks": [
				{"cost": 1, "stats": {"rite_time": 0.75}, "text": "Rite en 0,75 s"},
				{"cost": 2, "stats": {"rite_time": 0.55}, "text": "Rite en 0,55 s"},
			],
		},
		{
			"id": &"souffle_rendu",
			"name": "Souffle rendu",
			"text": "Chaque Repos donné rend de la vie.",
			"ranks": [
				{"cost": 1, "stats": {"rest_heal": 5}, "text": "+5 vie par Repos"},
				{"cost": 2, "stats": {"rest_heal": 10}, "text": "+10 vie par Repos"},
			],
		},
		{
			"id": &"tranchant",
			"name": "Tranchant",
			"text": "Les coups portent plus lourd.",
			"ranks": [
				{"cost": 1, "stats": {"damage_scale": 1.15}, "text": "Dégâts +15 %"},
				{"cost": 2, "stats": {"damage_scale": 1.3}, "text": "Dégâts +30 %"},
			],
		},
		{
			"id": &"pas_de_cote",
			"name": "Pas de côté",
			"text": "L'esquive revient plus vite.",
			"ranks": [
				{"cost": 1, "stats": {"dodge_cooldown": 0.6}, "text": "Esquive toutes les 0,6 s"},
				{"cost": 2, "stats": {"dodge_cooldown": 0.4}, "text": "Esquive toutes les 0,4 s"},
			],
		},
	],
}


## Souvenirs cumulés nécessaires pour atteindre `level`.
static func threshold(level: int) -> int:
	if level <= 1:
		return 0
	var index := level - 1
	if index < LEVEL_THRESHOLDS.size():
		return LEVEL_THRESHOLDS[index]
	var last := LEVEL_THRESHOLDS.size() - 1
	var step := LEVEL_THRESHOLDS[last] - LEVEL_THRESHOLDS[last - 1]
	var total := LEVEL_THRESHOLDS[last]
	for i in index - last:
		step += LATE_STEP
		total += step
	return total


## Niveau atteint avec `memories` souvenirs cumulés.
static func level_for(memories: int) -> int:
	var level := 1
	while memories >= threshold(level + 1):
		level += 1
	return level


static func skills_for(class_id: StringName) -> Array:
	return SKILLS.get(class_id, [])


static func find_skill(class_id: StringName, skill_id: StringName) -> Dictionary:
	for skill: Dictionary in skills_for(class_id):
		if skill["id"] == skill_id:
			return skill
	return {}
