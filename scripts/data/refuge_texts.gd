class_name RefugeTexts
extends RefCounted
## Les trois vivants du moulin et ce qu'ils disent. Chacun a des conversations
## qui s'ouvrent à mesure que le joueur termine des niveaux (`needs`), et que
## le joueur n'entend qu'une fois, dans l'ordre. Quand il n'y a plus rien de
## neuf, le personnage répète une des phrases de `idle`.
##
## Le héros ne parle pas. Ces textes sont dans un dépôt public : ils s'en
## tiennent à ce que le jeu montre lui-même.

const NPCS := {
	&"maud": {
		"name": "Maud",
		"service": &"shop",
		"service_label": "Voir la boutique",
		"conversations": [
			{
				"id": &"maud_1",
				"needs": [],
				"lines": [
					"Un soldat de la légion. Tu es le premier que je vois depuis sept ans.",
					"Je suis Maud, la meunière. Les bateaux sont venus chercher les fuyards. Moi, j'ai fermé ma porte et gardé ma meule.",
					"Ce que les morts laissent derrière eux, ça se ramasse. Là-haut, ça ne vaut plus rien. Ici, ça s'échange contre du cuir, du fer et du pain.",
				],
			},
			{
				"id": &"maud_2",
				"needs": [&"la_grille"],
				"lines": [
					"Tu as passé la Grille. Alors tu sais qu'ils ne restent pas couchés.",
					"Reviens me voir avec de l'or. J'ai de quoi te rendre un peu plus difficile à abattre.",
				],
			},
			{
				"id": &"maud_3",
				"needs": [&"la_chapelle"],
				"lines": [
					"On entend la grosse cloche d'ici, quand elle sonne. Les chiens se couchent.",
					"Ce soir, elle s'est tue. Je n'avais pas entendu un tel silence depuis le serment.",
				],
			},
			{
				"id": &"maud_4",
				"needs": [&"la_fosse"],
				"lines": [
					"La fosse est calme. Pour la première fois depuis sept ans, je n'entends plus personne creuser.",
					"Mange quelque chose avant de repartir. On ne monte pas en ville le ventre vide.",
				],
			},
		],
		"idle": [
			"Dis-moi ce qu'il te faut.",
			"Le pain est chaud, le fer ne l'est pas. Je vends les deux.",
			"Regarde, ne te gêne pas.",
		],
	},
	&"anselme": {
		"name": "Frère Anselme",
		"service": &"forget",
		"service_label": "Oublier mes rites",
		"conversations": [
			{
				"id": &"anselme_1",
				"needs": [],
				"lines": [
					"Te voilà, soldat. Je t'ai crié le rite par-dessus le mur. J'espérais que tu m'entendrais.",
					"Je suis frère Anselme. Je n'ai plus d'ordre ni d'église, mais je connais encore le rite du Repos.",
					"On ne frappe pas un mort pour le faire taire. On se tient près de lui, on attend, et on le laisse partir. Le reste n'est que de l'acier.",
				],
			},
			{
				"id": &"anselme_2",
				"needs": [&"la_grille"],
				"lines": [
					"Ils ne te haïssent pas, tu l'as vu. Ils défendent un serment qu'ils n'ont pas prêté.",
					"Chaque corps que tu mets au repos te rend un peu de ce qu'il portait. Ce sont des souvenirs : ils ne sont pas à toi, mais ils t'apprennent.",
					"Si tu t'es trompé de rite, je peux t'aider à tout désapprendre : tu retrouveras tes points.",
				],
			},
			{
				"id": &"anselme_3",
				"needs": [&"les_allees"],
				"lines": [
					"Choisis tes cibles. Un archer ou une cloche font plus de mal debout que dix corps à terre.",
				],
			},
			{
				"id": &"anselme_4",
				"needs": [&"la_chapelle"],
				"lines": [
					"Le Sonneur ne se battait pas : il sonnait. On ne règle pas tout à coups d'épée. Parfois, il faut couper la corde.",
				],
			},
			{
				"id": &"anselme_5",
				"needs": [&"la_fosse"],
				"lines": [
					"La Fossoyeuse creusait encore. Elle n'enterrait plus personne : elle déterrait.",
					"Tu as bien fait de lui donner le Repos. C'est la seule façon de rendre à la terre ce qu'elle a rendu.",
				],
			},
		],
		"idle": [
			"Un rite mal choisi peut se désapprendre. Dis-le-moi.",
			"Tiens-toi près d'eux, et attends. C'est tout le secret.",
			"Le Repos n'est pas un coup. C'est un adieu.",
		],
	},
	&"tibert": {
		"name": "Tibert",
		"service": &"bestiary",
		"service_label": "Montrer ce que j'ai vu",
		"conversations": [
			{
				"id": &"tibert_1",
				"needs": [],
				"lines": [
					"Tu es un soldat ? Un vrai ? Papa disait que la dernière légion ne rentrerait jamais.",
					"Moi, je suis né après le serment. Je n'ai jamais vu personne mourir. Maud dit que c'est une chance. Frère Anselme dit que c'est le contraire.",
					"Je note tout ce que tu rencontres, et Frère Anselme me répond. Viens me montrer ce que tu as vu : j'en ferai un livre.",
				],
			},
			{
				"id": &"tibert_2",
				"needs": [&"la_grille"],
				"lines": [
					"C'est vrai que tu touches les morts qui sont par terre ? Pourquoi ? Ça leur fait mal ?",
					"Frère Anselme dit que c'est un adieu. Moi, je trouve que ça ressemble à un coup.",
				],
			},
			{
				"id": &"tibert_3",
				"needs": [&"les_allees"],
				"lines": [
					"Il y en a qui tirent à l'arbalète ? Et d'autres qui sonnent des cloches ? Mais pourquoi ils font ça ?",
					"Ils ne détestent personne, non ? Alors pourquoi ils veulent te faire du mal ?",
				],
			},
			{
				"id": &"tibert_4",
				"needs": [&"l_ossuaire"],
				"lines": [
					"L'Ossuaire... Il paraît qu'il y fait noir comme dans un four. Tu as eu peur ?",
				],
			},
			{
				"id": &"tibert_5",
				"needs": [&"la_fosse"],
				"lines": [
					"Alors c'est fini, pour la ville basse ? Tu vas monter plus haut ?",
					"Moi, je n'ai jamais vu la ville de près. Tu me raconteras ?",
				],
			},
		],
		"idle": [
			"Tu reviens bientôt ?",
			"Maud dit que je pose trop de questions. Moi, je dis que je n'en pose pas assez.",
			"Tu crois que les morts rêvent ?",
		],
	},
}


## La prochaine conversation que ce personnage peut tenir : la première qui
## n'a pas été entendue et dont les niveaux sont terminés. Un dictionnaire
## vide s'il n'y a rien de neuf.
static func next_conversation(npc_id: StringName) -> Dictionary:
	var npc: Dictionary = NPCS.get(npc_id, {})
	for conversation: Dictionary in npc.get("conversations", []):
		if Progress.has_heard(conversation["id"]):
			continue
		var ready := true
		for level_id: StringName in conversation["needs"]:
			if not Progress.is_completed(level_id):
				ready = false
		if ready:
			return conversation
	return {}


## Une phrase de repli, qui change à chaque visite.
static func idle_line(npc_id: StringName, visit: int) -> String:
	var lines: Array = NPCS.get(npc_id, {}).get("idle", [])
	if lines.is_empty():
		return "…"
	return lines[visit % lines.size()]
