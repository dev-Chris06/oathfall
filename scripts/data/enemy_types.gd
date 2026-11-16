class_name EnemyTypes
extends RefCounted
## Les morts d'Orvana. Chaque type nomme son modèle, ses valeurs de combat et
## ses animations, pour que le code des ennemis ne dépende pas d'un pack.

const TYPES := {
	# La Dépouille : lente, au corps à corps, dangereuse en groupe.
	&"depouille": {
		"name": "Dépouille",
		"behavior": "melee",
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
		# Or laissé par le corps mis au repos.
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
	# L'Archer creux : fragile, tire de loin, recule quand on approche.
	&"archer_creux": {
		"name": "Archer creux",
		"behavior": "archer",
		"model": "res://assets/kaykit/skeletons/Skeleton_Rogue.glb",
		"props": [{"model": "res://assets/kaykit/skeletons/Skeleton_Crossbow.gltf", "bone": "handslot.r"}],
		"health": 22,
		"move_speed": 3.0,
		# Il garde le héros entre ces deux distances.
		"keep_min": 6.5,
		"keep_max": 12.0,
		"attack_range": 1.6,
		"attack_damage": 6,
		"attack_windup": 0.5,
		"attack_cooldown": 1.5,
		"attack_speed": 1.0,
		# Le carreau : temps de visée (la fenêtre pour esquiver), dégâts, vitesse.
		"aim_time": 0.9,
		"bolt_damage": 7,
		"bolt_speed": 15.0,
		"shot_cooldown": 2.8,
		"rise_delay": 18.0,
		"rise_health": 0.6,
		"memories": 6,
		"gold": 4,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_A",
			"retreat": "Walking_Backwards",
			"aim": "2H_Ranged_Aiming",
			"shoot": "2H_Ranged_Shoot",
			"attack": "Unarmed_Melee_Attack_Kick",
			"hit": "Hit_B",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
	# Le Porte-cloche : rare et lent. Tant qu'il est debout, sa cloche presse
	# les corps alentour de se relever.
	&"porte_cloche": {
		"name": "Porte-cloche",
		"behavior": "bell",
		"model": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
		"hidden_parts": ["Skeleton_Warrior_Helmet"],
		"props": [{"kind": "bell", "bone": "handslot.r", "offset": Vector3(0.0, -0.1, 0.0)}],
		"tint": Color(0.85, 0.8, 0.72),
		"scale": 1.15,
		"health": 75,
		"move_speed": 1.8,
		"attack_range": 2.1,
		"attack_damage": 14,
		"attack_windup": 0.8,
		"attack_cooldown": 1.8,
		"attack_speed": 0.9,
		# Secondes entre deux coups de cloche (visibles au sol).
		"ring_interval": 2.6,
		"rise_delay": 22.0,
		"rise_health": 0.5,
		"memories": 14,
		"gold": 9,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"attack": "1H_Melee_Attack_Chop",
			"hit": "Hit_A",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
	# Le Fouisseur : file sous terre et jaillit au pied du héros.
	&"fouisseur": {
		"name": "Fouisseur",
		"behavior": "burrower",
		"model": "res://assets/kaykit/skeletons/Skeleton_Minion.glb",
		"tint": Color(0.62, 0.5, 0.38),
		"health": 34,
		"move_speed": 3.2,
		# Vitesse sous terre, distance où il jaillit, temps d'alerte avant.
		"burrow_speed": 5.0,
		"burst_distance": 1.6,
		"burst_warning": 0.7,
		"burst_damage": 12,
		# Secondes passées à la surface avant de replonger.
		"surface_time": 7.0,
		"attack_range": 1.9,
		"attack_damage": 9,
		"attack_windup": 0.5,
		"attack_cooldown": 1.3,
		"attack_speed": 1.1,
		"rise_delay": 18.0,
		"rise_health": 0.6,
		"memories": 7,
		"gold": 4,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"attack": "Unarmed_Melee_Attack_Punch_B",
			"burst": "Spawn_Ground_Skeletons",
			"dig": "Lie_Down",
			"hit": "Hit_A",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
	# La Veuve : ne frappe pas, mais relève tous les corps d'un cri.
	&"veuve": {
		"name": "Veuve",
		"behavior": "widow",
		"model": "res://assets/kaykit/skeletons/Skeleton_Mage.glb",
		"hidden_parts": ["Skeleton_Mage_Hat"],
		"tint": Color(0.7, 0.72, 0.85),
		"health": 48,
		"move_speed": 2.4,
		"keep_min": 7.0,
		"keep_max": 11.0,
		# Le cri : préparation (frapper la Veuve l'interrompt), intervalle.
		"scream_windup": 1.6,
		"scream_interval": 9.0,
		"attack_range": 0.0,
		"attack_damage": 0,
		"attack_windup": 0.5,
		"attack_cooldown": 1.0,
		"attack_speed": 1.0,
		"rise_delay": 24.0,
		"rise_health": 0.6,
		"memories": 12,
		"gold": 8,
		"animations": {
			"idle": "Idle_B",
			"walk": "Walking_C",
			"retreat": "Walking_Backwards",
			"scream": "Spellcast_Raise",
			"hit": "Hit_B",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
	# Le Sonneur, boss de la Chapelle des cendres. Chaque coup de sa cloche
	# relève d'un coup tous les corps sans repos. Trois cordes retiennent la
	# cloche : les couper la fait tomber sur lui.
	&"sonneur": {
		"name": "Le Sonneur",
		"behavior": "sonneur",
		"boss": true,
		"model": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
		"tint": Color(0.62, 0.57, 0.52),
		"scale": 1.7,
		"props": [{"kind": "maul", "bone": "handslot.r"}],
		"health": 320,
		# Il ne poursuit personne : il regagne sa place sous la cloche. Son
		# seul coup est un geste pour repousser celui qui se colle à lui.
		"move_speed": 2.0,
		"attack_range": 2.4,
		"attack_damage": 8,
		"attack_windup": 0.7,
		"attack_cooldown": 3.0,
		"attack_speed": 1.0,
		# Secondes entre deux coups de cloche, préparation (le moment de
		# réagir), et secondes de plus par corde coupée.
		"toll_interval": 7.0,
		"toll_windup": 1.7,
		"toll_rope_delay": 3.5,
		# Part de sa vie que lui coûte la chute de la cloche, et étourdissement.
		"bell_fall_damage": 0.35,
		"stun_time": 3.5,
		# Après un coup qui l'ébranle, il n'est plus ébranlé pendant ce temps.
		"poise_time": 2.5,
		# La frappe sismique : il lève son maillet (un disque rouge au sol
		# avertit), frappe le sol, et une onde s'élargit jusqu'à `quake_radius`.
		# Elle blesse celui qu'elle traverse, sauf s'il esquive. Il ne la lance
		# que si le héros est à portée.
		"quake_interval": 8.0,
		"quake_windup": 1.3,
		"quake_radius": 9.5,
		"quake_speed": 14.0,
		"quake_width": 1.8,
		"quake_damage": 24,
		"rise_delay": 40.0,
		"rise_health": 0.3,
		"memories": 60,
		"gold": 40,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"attack": "2H_Melee_Attack_Chop",
			"toll": "Spellcast_Raise",
			"toll_end": "Spellcast_Shoot",
			"quake": "2H_Melee_Attack_Chop",
			"stun": "Hit_B",
			"hit": "Hit_A",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
}


static func get_type(id: StringName) -> Dictionary:
	return TYPES[id]
