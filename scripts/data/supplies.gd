class_name Supplies
extends RefCounted
## Les fioles et les vivres de Maud. Une fiole se boit en niveau, sans
## défense : on en porte trois au plus, et on les voit à la ceinture du héros.
## Un repas emballé donne un bonus pour le prochain niveau seulement. Comme
## l'équipement, chaque icône est le rendu du vrai modèle.

const FLASK := {
	"name": "Baume du moulin",
	"text": "Une fiole du baume de Maud. Boire prend un instant, et on ne se défend pas pendant ce temps.",
	"cost": 40,
	"heal": 45,
	"max": 3,
	"icon": "fiole_verte",
	"model": "res://assets/kaykit/items/bottle_green.glb",
}

## Fioles portées au début d'une partie neuve.
const START_FLASKS := 2
## Chance qu'une fiole tombe d'un corps mis au repos (une sur douze).
const FLASK_DROP_CHANCE := 1.0 / 12.0
## Part de la vie au moins retrouvée à chaque point de reprise.
const CHECKPOINT_HEALTH := 0.6

const MEALS := {
	&"pain": {
		"name": "Petit pain", "icon": "pain", "cost": 15,
		"text": "Un pain chaud, sorti du four du moulin.",
		"stats": {"max_health": 20},
	},
	&"fromage": {
		"name": "Fromage", "icon": "fromage", "cost": 30,
		"text": "Un morceau de fromage fort. Ça donne du cœur à l'ouvrage.",
		"stats": {"damage_scale": 0.10},
	},
	&"jambon": {
		"name": "Jambon", "icon": "jambon", "cost": 35,
		"text": "Un jambon cuit. On court plus légèrement le ventre plein.",
		"stats": {"speed_scale": 0.08},
	},
	&"ragout": {
		"name": "Ragoût", "icon": "ragout", "cost": 60,
		"text": "Le ragoût de Maud. Il tient au corps, et réchauffe celui qui se tient près des morts.",
		"stats": {"max_health": 30, "rest_heal": 3},
	},
}

const STAT_TEXT := {
	"max_health": "%+d de vie",
	"damage_scale": "Dégâts %+d %%",
	"speed_scale": "Vitesse %+d %%",
	"rest_heal": "+%d de vie par Repos",
}


static func describe_meal(id: StringName) -> Array[String]:
	var lines: Array[String] = []
	var stats: Dictionary = MEALS[id]["stats"]
	for key: String in stats:
		var value: float = stats[key]
		if key == "max_health" or key == "rest_heal":
			lines.append(STAT_TEXT[key] % int(value))
		else:
			lines.append(STAT_TEXT[key] % int(round(value * 100.0)))
	return lines


## Les fioles à la ceinture du héros : autant de bouteilles que de fioles
## portées. Sert au héros en jeu et à l'aperçu.
static func apply_belt(model: Node3D, count: int) -> void:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var belt := skeleton.find_child("FlaskBelt", false, false) as BoneAttachment3D
	if belt == null:
		belt = BoneAttachment3D.new()
		belt.name = "FlaskBelt"
		belt.bone_name = "hips"
		skeleton.add_child(belt)
		var scene := load(FLASK["model"]) as PackedScene
		var offsets := [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)]
		var slots := [Vector3(-0.32, 0.12, 0.12), Vector3(-0.32, 0.12, -0.04), Vector3(-0.30, 0.12, -0.2)]
		for i in 3:
			var bottle := scene.instantiate() as Node3D
			bottle.scale = Vector3.ONE * 0.5
			bottle.position = slots[i] + offsets[i]
			bottle.visible = false
			belt.add_child(bottle)
	var children := belt.get_children()
	for i in children.size():
		(children[i] as Node3D).visible = i < count
