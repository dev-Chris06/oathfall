class_name EnemyTypes
extends RefCounted
## Les morts d'Orvana. Chaque type nomme son modèle, ses valeurs de combat et
## ses animations, pour que le code des ennemis ne dépende pas d'un pack.

const TYPES := {
	# La Dépouille : lente, au corps à corps, dangereuse en groupe.
	&"depouille": {
		"name": "Dépouille",
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Un mort qui marche encore. Lent, il frappe au corps à corps et arrive en groupe.",
			"tip": "Une fois tombée, elle se relève au bout d'un moment : tiens-toi près d'elle et maintiens REPOS.",
		},
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
		# Part de l'animation où le coup frappe (voir Enemy._play_attack).
		"attack_impact": 0.40,
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
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Fragile, il tire de loin et recule quand on s'approche.",
			"tip": "Un trait rouge le relie à toi avant qu'il tire : esquive, puis fonce sur lui.",
		},
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
		"attack_impact": 0.47,
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
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Rare et robuste. Tant qu'il est debout, les corps se relèvent bien plus vite autour de lui.",
			"tip": "Abats-le en premier, avant de t'occuper des corps.",
		},
		"behavior": "bell",
		# Le portrait le montre du côté de la main qui porte la cloche.
		"portrait_side": -1.0,
		"model": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
		"hidden_parts": ["Skeleton_Warrior_Helmet"],
		"props": [{"kind": "bell", "bone": "handslot.r", "offset": Vector3(0.0, -0.1, 0.0), "scale": 1.15}],
		"tint": Color(0.85, 0.8, 0.72),
		"scale": 1.15,
		"health": 75,
		"move_speed": 1.8,
		"attack_range": 2.1,
		"attack_damage": 14,
		"attack_windup": 0.8,
		"attack_cooldown": 1.8,
		"attack_speed": 0.9,
		"attack_impact": 0.68,
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
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Il file sous terre : un monticule avance vers toi.",
			"tip": "Quand le monticule s'arrête et tremble, esquive : il va jaillir à tes pieds.",
		},
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
		"attack_windup": 0.6,
		"attack_cooldown": 1.3,
		"attack_speed": 1.1,
		"attack_impact": 0.42,
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
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Elle ne frappe pas. Son cri relève d'un coup tous les corps sans repos.",
			"tip": "Frappe-la quand elle prend son souffle : cela interrompt son cri.",
		},
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
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Il ne se bat presque pas : il sonne. Chaque coup de sa cloche relève tous les corps.",
			"tip": "Donne le Repos entre deux coups, ou coupe les trois cordes de la cloche. Esquive l'onde de son maillet.",
		},
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
		"attack_impact": 0.52,
		"quake_impact": 0.52,
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
	# La Fossoyeuse, boss de la Fosse, en trois phases (sa vie en fixe les
	# seuils). Phase 1 : coups de pelle lents et lourds, larges balayages.
	# Phase 2 : elle s'enfonce dans la terre, ressort ailleurs et déterre des
	# Dépouilles pendant qu'elle charge. Phase 3 : elle arrache des pierres
	# tombales et les lance ; les corps sans repos se relèvent tous ensemble.
	&"fossoyeuse": {
		"name": "La Fossoyeuse",
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Elle n'enterre plus, elle déterre. Trois phases : la pelle, la terre, les pierres.",
			"tip": "Une zone rouge annonce chaque coup. Sous terre, elle est intouchable : mets au repos les morts qu'elle déterre.",
		},
		"behavior": "fossoyeuse",
		"boss": true,
		"model": "res://assets/kaykit/skeletons/Skeleton_Rogue.glb",
		"tint": Color(0.6, 0.52, 0.45),
		"scale": 1.85,
		"props": [{"kind": "spade", "bone": "handslot.r"}],
		"health": 800,
		"move_speed": 2.4,
		"attack_range": 3.0,
		"attack_damage": 0,
		"attack_windup": 1.0,
		"attack_cooldown": 1.0,
		"attack_speed": 1.0,
		# Les seuils de phase, en part de vie restante.
		"stage2_at": 0.66,
		"stage3_at": 0.33,
		# Un coup de pelle : lent, étroit, lourd. Un balayage : large.
		"swing_windup": 1.15,
		"swing_range": 3.1,
		"swing_arc": 70.0,
		"swing_damage": 26,
		"swing_impact": 0.52,
		"sweep_windup": 1.45,
		"sweep_range": 3.9,
		"sweep_arc": 200.0,
		"sweep_damage": 20,
		"sweep_impact": 0.52,
		"recover": 0.9,
		"attack_gap": 0.7,
		# Phase 2 : plongée, trajet sous terre, jaillissement (qui blesse), puis
		# des charges en ligne droite après un temps d'annonce.
		"dive_time": 1.0,
		"burrow_speed": 9.0,
		"emerge_time": 0.8,
		"emerge_radius": 3.4,
		"emerge_damage": 18,
		"dig_count": 3,
		"charges": 2,
		"charge_windup": 0.95,
		"charge_speed": 13.0,
		"charge_max": 14.0,
		"charge_width": 2.4,
		"charge_damage": 28,
		"charge_recover": 1.7,
		# Phase 3 : des pierres lancées (leur chute est annoncée au sol), puis
		# un cri qui relève tous les corps.
		"throws": 3,
		"throw_windup": 0.9,
		"throw_flight": 1.15,
		"throw_radius": 2.3,
		"throw_damage": 22,
		"throw_impact": 0.53,
		"raise_windup": 1.5,
		"raise_interval": 14.0,
		"poise_time": 2.0,
		"rise_delay": 50.0,
		"rise_health": 0.25,
		"memories": 140,
		"gold": 80,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"swing": "2H_Melee_Attack_Chop",
			"sweep": "2H_Melee_Attack_Spin",
			"charge": "Running_B",
			"stun": "Hit_B",
			"throw": "Throw",
			"raise": "Spellcast_Raise",
			"roar": "Taunt",
			"emerge": "Spawn_Ground_Skeletons",
			"hit": "Hit_A",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
}


static func get_type(id: StringName) -> Dictionary:
	return TYPES[id]
