class_name EnemyTypes
extends RefCounted
## Les morts d'Orvana. Chaque type nomme son modèle, ses valeurs de combat et
## ses animations, pour que le code des ennemis ne dépende pas d'un pack.

const TYPES := {
	# La Dépouille : lente, au corps à corps, dangereuse en groupe.
	&"depouille": {
		"name": "Dépouille",
		"model": "res://assets/kaykit/skeletons/Skeleton_Minion.glb",
		"health": 40,
		"move_speed": 2.5,
		"attack_range": 1.9,
		"attack_damage": 10,
		# Temps entre le début du geste et le moment où le coup porte :
		# c'est la fenêtre laissée au joueur pour esquiver.
		"attack_windup": 0.55,
		"attack_cooldown": 1.3,
		"attack_speed": 1.0,
		# Secondes passées au sol avant de se relever, et part de vie retrouvée.
		"rise_delay": 20.0,
		"rise_health": 0.6,
		# Souvenirs rendus au héros quand le corps reçoit le Repos.
		"memories": 5,
		# Or laissé par le corps mis au repos : l'obole qu'on lui avait confiée.
		"gold": 3,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"attack": "Unarmed_Melee_Attack_Punch_A",
			"hit": "Hit_A",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
}


static func get_type(id: StringName) -> Dictionary:
	return TYPES[id]
