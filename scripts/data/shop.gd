class_name Shop
extends RefCounted
## La boutique de Maud : des améliorations permanentes, payées en or. Chacune
## a un ou deux rangs, achetés dans l'ordre ; `requires` demande d'abord un
## autre achat. Les bonus s'ajoutent à ce que donnent le niveau et les rites
## (voir `Progress.hero_stats`).

const ITEMS := [
	{
		"id": &"gambison",
		"name": "Gambison renforcé",
		"text": "Du cuir doublé de laine. Il amortit les coups.",
		"ranks": [
			{"cost": 100, "bonus": {"max_health": 20}, "text": "+20 de vie"},
		],
	},
	{
		"id": &"cotte",
		"name": "Cotte de mailles",
		"text": "Des anneaux de fer sous le tabard.",
		"requires": {"gambison": 1},
		"ranks": [
			{"cost": 260, "bonus": {"max_health": 35}, "text": "+35 de vie"},
		],
	},
	{
		"id": &"lame",
		"name": "Lame affûtée",
		"text": "Maud connaît encore la pierre et le fil.",
		"ranks": [
			{"cost": 120, "bonus": {"damage_scale": 0.10}, "text": "Dégâts +10 %"},
			{"cost": 320, "bonus": {"damage_scale": 0.15}, "text": "Dégâts +15 % de plus"},
		],
	},
	{
		"id": &"bottes",
		"name": "Bottes de marche",
		"text": "Ressemelées dans le moulin.",
		"ranks": [
			{"cost": 160, "bonus": {"speed_scale": 0.08}, "text": "Vitesse +8 %"},
		],
	},
	{
		"id": &"bandages",
		"name": "Bandages propres",
		"text": "Pour le soldat qui reste près des corps.",
		"ranks": [
			{"cost": 150, "bonus": {"rest_heal": 3}, "text": "+3 de vie par Repos"},
		],
	},
]


static func find(id: StringName) -> Dictionary:
	for item: Dictionary in ITEMS:
		if item["id"] == id:
			return item
	return {}
