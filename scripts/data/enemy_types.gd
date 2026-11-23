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
	# Le Boucher des halles : lent, solide, un coup de hachoir qui fait mal.
	&"boucher": {
		"name": "Boucher",
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Il tient encore son étal. Robuste, il frappe d'un grand coup de hachoir, parfois deux. Il n'est pas arrêté en plein geste.",
			"tip": "Esquive son coup, puis frappe-le quand il a fini : il reste ouvert un instant. S'il charge, écarte-toi : un mur l'assomme.",
		},
		"behavior": "butcher",
		"model": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
		"hidden_parts": ["Skeleton_Warrior_Helmet"],
		"props": [{"model": "res://assets/kaykit/skeletons/Skeleton_Axe.gltf", "bone": "handslot.r", "scale": 1.3}],
		"tint": Color(0.78, 0.58, 0.5),
		"scale": 1.3,
		"health": 150,
		"move_speed": 1.9,
		"attack_range": 2.4,
		"attack_damage": 22,
		"attack_windup": 0.9,
		"attack_cooldown": 2.0,
		"attack_speed": 1.0,
		"attack_impact": 0.52,
		# Armure : son coup n'est pas interrompu, il n'est pas ébranlé deux fois
		# de suite ; après un coup, il reste ouvert un moment. Il enchaîne.
		"armor": true,
		"open_time": 1.3,
		"stagger_guard": 3.0,
		"combo_chance": 0.55,
		"combo_gap": 0.35,
		# La charge : il piétine (annoncé par une bande rouge), puis fonce ; un
		# mur l'assomme. Elle part quand le héros est entre `charge_min` et
		# `charge_max`.
		"charge_interval": 9.0,
		"charge_min": 6.0,
		"charge_max": 13.0,
		"stomp_time": 0.9,
		"charge_speed": 8.5,
		"charge_time": 1.1,
		"charge_damage": 26,
		"stun_time": 2.2,
		"rise_delay": 26.0,
		"rise_health": 0.5,
		"memories": 16,
		"gold": 10,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"attack": "2H_Melee_Attack_Chop",
			"hit": "Hit_A",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
	# Le Crieur : il ne frappe pas, mais son cri presse les morts debout.
	&"crieur": {
		"name": "Crieur",
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Il ne frappe pas. Son cri presse les morts qui te combattent : ils vont plus vite et frappent plus fort. Seul, il appelle du renfort.",
			"tip": "Les morts pressés ont un anneau rouge aux pieds. Abats le Crieur en premier, ou frappe-le quand il prend son souffle.",
		},
		"behavior": "crier",
		"model": "res://assets/kaykit/skeletons/Skeleton_Rogue.glb",
		"props": [{"kind": "horn", "bone": "handslot.r", "offset": Vector3(0.0, 0.0, 0.0), "rotation": Vector3(90.0, 0.0, 0.0)}],
		"tint": Color(0.85, 0.72, 0.55),
		"health": 52,
		"move_speed": 2.4,
		"keep_min": 6.0,
		"keep_max": 10.0,
		# Le cri : préparation (le frapper l'interrompt), intervalle, portée,
		# durée de la hâte qu'il donne.
		"shout_windup": 1.2,
		"shout_interval": 7.0,
		"shout_radius": 16.0,
		"engage_radius": 9.0,
		"haste_time": 6.0,
		# L'appel : seul (moins de trois morts debout), il fait surgir du renfort.
		"call_interval": 16.0,
		"call_count": 2,
		"attack_range": 0.0,
		"attack_damage": 0,
		"attack_windup": 0.5,
		"attack_cooldown": 1.0,
		"attack_speed": 1.0,
		"rise_delay": 24.0,
		"rise_health": 0.6,
		"memories": 14,
		"gold": 9,
		"animations": {
			"idle": "Idle_B",
			"walk": "Walking_C",
			"retreat": "Walking_Backwards",
			"shout": "Spellcast_Raise",
			"hit": "Hit_B",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
	# Le Noyé (chapitre III) : abattu, son corps glisse vers l'eau ; s'il
	# l'atteint sans avoir reçu le Repos, il coule et remonte plus loin, debout.
	&"noye": {
		"name": "Noyé",
		"bestiary": {
			"text": "Un fuyard que le fleuve a rendu, et qui veut y emmener les vivants. Près du bord, il agrippe et traîne vers l'eau ; abattu, son corps y glisse et remonte plus loin. Tant qu'il est debout, la brume du fleuve cache les corps.",
			"tip": "Reste loin du bord. Pris, frappe-le ou esquive. Donne-lui le Repos sans tarder : agenouillé près de lui, il ne glisse plus.",
		},
		"behavior": "drowned",
		"model": "res://assets/kaykit/skeletons/Skeleton_Minion.glb",
		"tint": Color(0.52, 0.66, 0.7),
		"health": 44,
		"move_speed": 2.3,
		"attack_range": 1.9,
		"attack_damage": 11,
		"attack_windup": 0.55,
		"attack_cooldown": 1.4,
		"attack_speed": 1.0,
		"attack_impact": 0.40,
		# Le corps commence à glisser après `slide_delay`, à `slide_speed` ; il
		# reste `sunk_time` sous l'eau avant de remonter.
		"slide_delay": 1.2,
		"slide_speed": 0.8,
		"sunk_time": 5.0,
		# L'Étreinte : quand le héros est à moins de `grab_edge` de l'eau, il
		# l'agrippe au lieu de frapper, puis le traîne à `drag_speed` en le
		# blessant toutes les `grab_tick` ; au bord (`plunge_at`), il plonge.
		"grab_edge": 3.0,
		"grab_range": 1.9,
		"grab_windup": 0.7,
		"grab_impact": 0.40,
		"grab_cooldown": 4.0,
		"grab_tick": 0.5,
		"grab_damage": 3,
		"drag_speed": 1.5,
		"plunge_at": 1.0,
		"plunge_damage": 16,
		"hold_max": 5.0,
		# La main : sous l'eau, il guette un héros à moins de `hand_reach` du bord.
		"hand_delay": 1.5,
		"hand_reach": 1.8,
		"hand_windup": 0.5,
		"rise_delay": 24.0,
		"rise_health": 0.7,
		"memories": 8,
		"gold": 5,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"attack": "Unarmed_Melee_Attack_Punch_A",
			"hit": "Hit_A",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
			"grab": "Unarmed_Melee_Attack_Punch_B",
			"drag": "Walking_Backwards",
		},
	},
	# Le Haleur, boss du Halage : enchaîné à sa barge, qui le suit le long du
	# quai. Son coup de collier balaie la ligne de sa chaîne et relève les
	# corps qu'elle traverse ; chaque fois, la barge débarque des morts.
	&"haleur": {
		"name": "Le Haleur",
		"bestiary": {
			"text": "Il tire encore sa barge à contre-courant, enchaîné à elle. Quand il donne le coup de collier, sa chaîne balaie le chemin jusqu'à l'eau : elle jette le vivant vers le fleuve et relève les corps qu'elle traverse. La barge, chaque fois, débarque des morts.",
			"tip": "Quand la bande rouge s'allume sous sa chaîne, sors-en ou esquive. Donne le Repos aux corps qui gisent sur sa ligne, ou attire-le ailleurs. Sous la moitié de sa vie, il tire plus souvent.",
		},
		"behavior": "haleur",
		"boss": true,
		"model": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
		"hidden_parts": ["Skeleton_Warrior_Helmet"],
		"props": [{"kind": "croc", "bone": "handslot.r", "rotation": Vector3(0.0, 0.0, 0.0), "scale": 0.6}],
		"tint": Color(0.7, 0.8, 0.82),
		"scale": 1.9,
		"health": 720,
		"move_speed": 1.5,
		"attack_range": 2.8,
		"attack_damage": 22,
		"attack_windup": 1.0,
		"attack_cooldown": 2.6,
		"attack_speed": 1.0,
		"attack_impact": 0.52,
		"armor": true,
		"open_time": 1.4,
		"stagger_guard": 3.5,
		"combo_chance": 0.25,
		# Le coup de collier : intervalle (puis enragé), annonce, largeur de
		# la bande, dégâts. La barge le suit à `barge_speed`.
		"haul_interval": 8.0,
		"haul_interval_enraged": 6.0,
		"haul_windup": 1.4,
		"haul_impact": 0.53,
		"haul_width": 2.0,
		"haul_damage": 28,
		"barge_speed": 1.2,
		"enrage_at": 0.5,
		"rise_delay": 40.0,
		"rise_health": 0.3,
		"memories": 90,
		"gold": 60,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"attack": "2H_Melee_Attack_Chop",
			"haul": "Throw",
			"hit": "Hit_A",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
	# Le Gaffeur (chapitre III) : de près il frappe de sa gaffe ; à
	# mi-distance, il la lance et tire le héros à lui.
	&"gaffeur": {
		"name": "Gaffeur",
		"bestiary": {
			"text": "Un batelier mort, armé de sa gaffe. De loin, il la lance et te tire à lui, au milieu des autres.",
			"tip": "Un trait orangé le relie à toi avant le jet : esquive. Frappe-le pendant qu'il vise, il lâche prise.",
		},
		"behavior": "hook",
		"model": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
		"hidden_parts": ["Skeleton_Warrior_Helmet"],
		"props": [{"kind": "gaffe", "bone": "handslot.r", "rotation": Vector3(0.0, 0.0, 0.0)}],
		"tint": Color(0.7, 0.66, 0.6),
		"health": 52,
		"move_speed": 2.6,
		"attack_range": 2.4,
		"attack_damage": 12,
		"attack_windup": 0.8,
		"attack_cooldown": 1.7,
		"attack_speed": 0.9,
		"attack_impact": 0.68,
		# Le jet de gaffe : entre `hook_min` et `hook_range` du héros ; temps de
		# visée (la fenêtre pour esquiver) et part de l'animation où il lâche.
		"hook_min": 3.5,
		"hook_range": 8.0,
		"hook_windup": 0.9,
		"hook_impact": 0.53,
		"hook_damage": 6,
		"hook_cooldown": 6.0,
		"rise_delay": 20.0,
		"rise_health": 0.6,
		"memories": 10,
		"gold": 6,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"attack": "1H_Melee_Attack_Chop",
			"throw": "Throw",
			"hit": "Hit_A",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
	# Le Peseur, boss de la Balance. Sa balance juge combien de morts sont
	# debout et combien gisent : trop de morts debout, il est protégé ; trop de
	# corps, ses poids tombent plus vite ; à l'équilibre, il est vulnérable.
	# Ses poids tombent sur une zone que le sol annonce.
	&"peseur": {
		"name": "Le Peseur",
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Il juge tout sur sa balance. Trop de morts debout, il est protégé par la fonte ; trop de corps, il s'emballe et lance trois poids à la fois ; à l'équilibre, il est assommé.",
			"tip": "Garde l'équilibre : abats les morts debout, donne le Repos aux corps. À l'équilibre, frappe sans attendre. Des zones rouges annoncent ses poids, visés, par paires ou en rouleau.",
		},
		"behavior": "peseur",
		"boss": true,
		"model": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
		"hidden_parts": ["Skeleton_Warrior_Helmet"],
		"props": [{"kind": "scales", "bone": "handslot.r", "offset": Vector3(0.0, 0.2, 0.0)}],
		"tint": Color(0.82, 0.68, 0.45),
		"scale": 1.75,
		"health": 560,
		"move_speed": 1.6,
		"attack_range": 2.7,
		"attack_damage": 20,
		"attack_windup": 1.0,
		"attack_cooldown": 2.8,
		"attack_speed": 1.0,
		"attack_impact": 0.52,
		"armor": true,
		"open_time": 1.4,
		"stagger_guard": 3.5,
		"combo_chance": 0.3,
		# Les poids : intervalle, délai d'annonce, rayon, dégâts.
		"weight_interval": 6.0,
		"weight_windup": 1.15,
		"weight_radius": 2.4,
		"weight_damage": 22,
		# Part des dégâts reçus selon la balance : protégé (trop de morts
		# debout) et à l'équilibre (assommé). Plus de corps que de morts
		# debout : il s'emballe (hâte permanente) et lance trois poids à la fois.
		"shield_factor": 0.35,
		"even_factor": 2.0,
		"stun_time": 3.0,
		"stun_cooldown": 9.0,
		"rise_delay": 40.0,
		"rise_health": 0.3,
		"memories": 70,
		"gold": 45,
		"animations": {
			"stun": "Hit_B",
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"attack": "2H_Melee_Attack_Chop",
			"hit": "Hit_A",
			"fall": "Death_C_Skeletons",
			"rise": "Death_C_Skeletons_Resurrect",
		},
	},
	# Le Prévôt des halles, boss de la Halle. Il continue de lever l'impôt :
	# un cercle d'or est annoncé sur le sol, et quelques secondes plus tard la
	# levée frappe toute la salle, sauf qui se tient dans le cercle. À chaque
	# tiers de sa vie, il convoque ses percepteurs et la levée se rapproche.
	&"prevot": {
		"name": "Le Prévôt",
		# La fiche du bestiaire de Tibert.
		"bestiary": {
			"text": "Il lève encore l'impôt. Un cercle d'or paraît au sol et dérive : quelques secondes plus tard, la levée frappe toute la salle et relève les corps qui n'y sont pas.",
			"tip": "Tiens-toi dans le cercle d'or (le vrai brille, le faux est terne) avant que la levée ne tombe. Donne le Repos aux corps avant. À chaque tiers de sa vie, il convoque ses percepteurs.",
		},
		"behavior": "prevot",
		"boss": true,
		"model": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
		"hidden_parts": ["Skeleton_Warrior_Helmet"],
		"props": [{"kind": "mace", "bone": "handslot.r", "offset": Vector3(0.0, 0.1, 0.0)}],
		"tint": Color(0.92, 0.75, 0.42),
		"scale": 1.8,
		"health": 560,
		"move_speed": 2.0,
		"attack_range": 3.0,
		"attack_damage": 18,
		"attack_windup": 1.0,
		"attack_cooldown": 2.4,
		"attack_speed": 1.0,
		"attack_impact": 0.52,
		"armor": true,
		"open_time": 1.9,
		"stagger_guard": 3.5,
		"combo_chance": 0.25,
		# La levée : annonce, rayon du cercle sûr (un par tiers de sa vie, de plus en
		# plus petit), intervalle, dégâts. Le cercle dérive pendant l'annonce ; au
		# dernier tiers un faux cercle l'accompagne. Les corps hors du cercle se
		# relèvent. Les percepteurs arrivent à `edict_time` secondes
		# d'immobilité du Prévôt.
		"levy_windup": [2.2, 2.0, 1.8],
		"levy_interval": 14.0,
		"safe_radius": [2.2, 1.9, 1.6],
		"circle_drift": 0.9,
		"levy_damage": 26,
		"edict_time": 1.6,
		"stage2_at": 0.66,
		"stage3_at": 0.33,
		"rise_delay": 45.0,
		"rise_health": 0.3,
		"memories": 90,
		"gold": 60,
		"animations": {
			"idle": "Idle_Combat",
			"walk": "Walking_D_Skeletons",
			"attack": "2H_Melee_Attack_Chop",
			"levy": "Spellcast_Raise",
			"edict": "Spellcast_Raise",
			"hit": "Hit_A",
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
