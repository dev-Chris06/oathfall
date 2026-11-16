extends Node
## Ce que le héros garde d'un niveau à l'autre : souvenirs, niveau, or,
## compétences, et l'endroit où reprendre. Chargé en permanence sous le nom
## `Progress`, et écrit sur le téléphone dans un fichier JSON.

## Un nouveau niveau du héros est atteint.
signal leveled_up(level: int)
## Une valeur a changé (souvenirs, or, points, compétences).
signal changed
## Une compétence a été apprise ou renforcée.
signal skill_learned(skill_id: StringName, rank: int)

const SAVE_VERSION := 1

var save_path := "user://sauvegarde.json"

var class_id: StringName = HeroClasses.DEFAULT
## Souvenirs cumulés depuis le début : ils ne se dépensent pas.
var memories := 0
var hero_level := 1
var skill_points := 0
var gold := 0
## Rang atteint dans chaque compétence (identifiant → rang, 0 si absente).
var ranks := {}
## Où reprendre la partie.
var level_id: StringName = &"la_grille"
var checkpoint := 0
## Les niveaux terminés (identifiant → vrai). Ils restent rejouables.
var completed := {}
## Les fioles portées, et le repas emballé pour le prochain niveau ; le repas
## « actif » est celui du niveau en cours (il disparaît quand on le quitte).
var flasks := 0
var packed_meal: StringName = &""
var active_meal: StringName = &""

## L'équipement : les objets achetés (identifiant → vrai ; ceux de base sont
## toujours possédés) et celui qu'on porte dans chaque emplacement.
var owned := {}
var equipped := {}
## Les conversations du refuge déjà entendues (identifiant → vrai).
var heard := {}
## Les types de morts rencontrés (identifiant → vrai), et combien de chacun
## ont reçu le Repos : c'est ce que le bestiaire de Tibert raconte.
var met := {}
var rests := {}


func reset() -> void:
	class_id = HeroClasses.DEFAULT
	memories = 0
	hero_level = 1
	skill_points = 0
	gold = 0
	ranks = {}
	level_id = &"la_grille"
	checkpoint = 0
	completed = {}
	owned = {}
	equipped = {}
	flasks = 0
	packed_meal = &""
	active_meal = &""
	heard = {}
	met = {}
	rests = {}
	changed.emit()


## Une partie neuve : tout est remis à zéro, et la sauvegarde écrasée.
func new_game() -> void:
	reset()
	save()


## Vrai s'il y a une partie à continuer.
func has_progress() -> bool:
	return memories > 0 or gold > 0 or not completed.is_empty() or not owned.is_empty() or flasks > 0


func is_completed(id: StringName) -> bool:
	return completed.has(String(id))


func mark_completed(id: StringName) -> void:
	completed[String(id)] = true
	changed.emit()
	save()


func add_memories(amount: int) -> void:
	memories += amount
	var reached := Progression.level_for(memories)
	while hero_level < reached:
		hero_level += 1
		skill_points += Progression.POINTS_PER_LEVEL
		leveled_up.emit(hero_level)
	changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


## Part du chemin parcourue vers le niveau suivant, de 0 à 1.
func level_progress() -> float:
	var low := Progression.threshold(hero_level)
	var high := Progression.threshold(hero_level + 1)
	return clampf(float(memories - low) / float(maxi(high - low, 1)), 0.0, 1.0)


func rank_of(skill_id: StringName) -> int:
	return int(ranks.get(String(skill_id), 0))


## Le rang suivant d'une compétence, ou un dictionnaire vide si elle est au
## plus haut.
func next_rank(skill_id: StringName) -> Dictionary:
	var skill := Progression.find_skill(class_id, skill_id)
	if skill.is_empty():
		return {}
	var rank_list: Array = skill["ranks"]
	var rank := rank_of(skill_id)
	return rank_list[rank] if rank < rank_list.size() else {}


## Désapprend tous les rites et rend leurs points. Renvoie le nombre de points
## rendus.
func forget_skills() -> int:
	var refunded := 0
	for skill: Dictionary in Progression.skills_for(class_id):
		var rank := rank_of(skill["id"])
		for i in rank:
			refunded += int(skill["ranks"][i]["cost"])
	ranks = {}
	skill_points += refunded
	changed.emit()
	save()
	return refunded


func can_learn(skill_id: StringName) -> bool:
	var next := next_rank(skill_id)
	return not next.is_empty() and skill_points >= int(next["cost"])


func learn(skill_id: StringName) -> bool:
	if not can_learn(skill_id):
		return false
	skill_points -= int(next_rank(skill_id)["cost"])
	var rank := rank_of(skill_id) + 1
	ranks[String(skill_id)] = rank
	skill_learned.emit(skill_id, rank)
	changed.emit()
	save()
	return true


func has_met(type_id: StringName) -> bool:
	return met.has(String(type_id))


## Un type de mort apparaît : le bestiaire s'en souvient.
func meet(type_id: StringName) -> void:
	if not has_met(type_id):
		met[String(type_id)] = true


func note_rest(type_id: StringName) -> void:
	rests[String(type_id)] = int(rests.get(String(type_id), 0)) + 1


func rest_count(type_id: StringName) -> int:
	return int(rests.get(String(type_id), 0))


func has_heard(conversation_id: StringName) -> bool:
	return heard.has(String(conversation_id))


func hear(conversation_id: StringName) -> void:
	heard[String(conversation_id)] = true
	save()


# --- Fioles et vivres -----------------------------------------------------------

## Pourquoi on ne peut pas acheter une fiole : « », « pleines » ou « or ».
func flask_blocker() -> String:
	if flasks >= int(Supplies.FLASK["max"]):
		return "pleines"
	if gold < int(Supplies.FLASK["cost"]):
		return "or"
	return ""


func buy_flask() -> bool:
	if flask_blocker() != "":
		return false
	gold -= int(Supplies.FLASK["cost"])
	flasks += 1
	changed.emit()
	save()
	return true


## Boit une fiole (le héros est soigné par `Level`). Renvoie faux s'il n'en reste pas.
func use_flask() -> bool:
	if flasks <= 0:
		return false
	flasks -= 1
	changed.emit()
	save()
	return true


## Pourquoi on ne peut pas emballer un repas : « », « deja » ou « or ».
func meal_blocker(meal_id: StringName) -> String:
	if packed_meal != &"":
		return "deja"
	if gold < int(Supplies.MEALS[meal_id]["cost"]):
		return "or"
	return ""


func pack_meal(meal_id: StringName) -> bool:
	if meal_blocker(meal_id) != "":
		return false
	gold -= int(Supplies.MEALS[meal_id]["cost"])
	packed_meal = meal_id
	changed.emit()
	save()
	return true


## On part en niveau : le repas emballé devient le repas du niveau.
func start_level_meal() -> void:
	active_meal = packed_meal
	packed_meal = &""
	changed.emit()


## On quitte le niveau : son repas est fini.
func end_level_meal() -> void:
	if active_meal != &"":
		active_meal = &""
		changed.emit()


# --- L'équipement ---------------------------------------------------------------

func owns(item_id: StringName) -> bool:
	return int(Gear.ITEMS[item_id]["cost"]) == 0 or owned.has(String(item_id))


func equipped_id(slot: StringName) -> StringName:
	return StringName(equipped.get(String(slot), String(Gear.DEFAULTS[slot])))


## L'équipement porté : {emplacement → objet}.
func equipped_map() -> Dictionary:
	var map := {}
	for slot in Gear.SLOTS:
		map[slot] = equipped_id(slot)
	return map


## Pourquoi on ne peut pas acheter : « », « possede » ou « or ».
func gear_blocker(item_id: StringName) -> String:
	if owns(item_id):
		return "possede"
	if gold < int(Gear.ITEMS[item_id]["cost"]):
		return "or"
	return ""


## Achète un objet et l'équipe tout de suite.
func buy_gear(item_id: StringName) -> bool:
	if gear_blocker(item_id) != "":
		return false
	gold -= int(Gear.ITEMS[item_id]["cost"])
	owned[String(item_id)] = true
	equip(item_id)
	return true


func equip(item_id: StringName) -> bool:
	if not owns(item_id):
		return false
	equipped[String(Gear.ITEMS[item_id]["slot"])] = String(item_id)
	changed.emit()
	save()
	return true


## Les caractéristiques du héros : niveau, rites et équipement porté.
func hero_stats() -> Dictionary:
	var stats := Progression.BASE_STATS.duplicate()
	var data := HeroClasses.get_class_data(class_id)
	stats["max_health"] = int(data.get("health", 100)) \
		+ Progression.HEALTH_PER_LEVEL * (hero_level - 1)
	for skill: Dictionary in Progression.skills_for(class_id):
		var rank := rank_of(skill["id"])
		if rank > 0:
			var rank_data: Dictionary = skill["ranks"][rank - 1]
			stats.merge(rank_data["stats"], true)
	# Le repas du niveau en cours.
	if active_meal != &"":
		var meal_bonus: Dictionary = Supplies.MEALS[active_meal]["stats"]
		for key: String in meal_bonus:
			stats[key] = stats.get(key, 0) + meal_bonus[key]
	# L'équipement porté s'ajoute.
	for slot in Gear.SLOTS:
		var bonus: Dictionary = Gear.ITEMS[equipped_id(slot)]["stats"]
		for key: String in bonus:
			stats[key] = stats.get(key, 0) + bonus[key]
	return stats


## Retient l'endroit où reprendre, et l'écrit.
func set_resume_point(id: StringName, index: int) -> void:
	level_id = id
	checkpoint = index
	save()


# --- Fichier ------------------------------------------------------------------

func save() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"class_id": String(class_id),
		"memories": memories,
		"hero_level": hero_level,
		"skill_points": skill_points,
		"gold": gold,
		"ranks": ranks,
		"level_id": String(level_id),
		"checkpoint": checkpoint,
		"completed": completed.keys(),
		"flasks": flasks,
		"packed_meal": String(packed_meal),
		"active_meal": String(active_meal),
		"owned": owned.keys(),
		"equipped": equipped,
		"heard": heard.keys(),
		"met": met.keys(),
		"rests": rests,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## Relit la sauvegarde. Renvoie faux s'il n'y en a pas ou si elle est
## illisible ; la progression est alors remise à zéro.
func load_save() -> bool:
	reset()
	if not FileAccess.file_exists(save_path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Sauvegarde illisible, nouvelle partie.")
		return false
	var data: Dictionary = parsed
	class_id = StringName(data.get("class_id", String(HeroClasses.DEFAULT)))
	memories = int(data.get("memories", 0))
	hero_level = maxi(1, int(data.get("hero_level", 1)))
	skill_points = int(data.get("skill_points", 0))
	gold = int(data.get("gold", 0))
	ranks = {}
	var saved_ranks = data.get("ranks", {})
	if typeof(saved_ranks) == TYPE_DICTIONARY:
		for key in saved_ranks:
			ranks[String(key)] = int(saved_ranks[key])
	level_id = StringName(data.get("level_id", "la_grille"))
	checkpoint = int(data.get("checkpoint", 0))
	completed = {}
	var saved_done = data.get("completed", [])
	if typeof(saved_done) == TYPE_ARRAY:
		for id in saved_done:
			completed[String(id)] = true
	flasks = clampi(int(data.get("flasks", 0)), 0, int(Supplies.FLASK["max"]))
	var saved_packed := StringName(data.get("packed_meal", ""))
	packed_meal = saved_packed if Supplies.MEALS.has(saved_packed) else &""
	var saved_active := StringName(data.get("active_meal", ""))
	active_meal = saved_active if Supplies.MEALS.has(saved_active) else &""
	owned = {}
	var saved_owned = data.get("owned", [])
	if typeof(saved_owned) == TYPE_ARRAY:
		for id in saved_owned:
			if Gear.ITEMS.has(StringName(id)):
				owned[String(id)] = true
	equipped = {}
	var saved_equipped = data.get("equipped", {})
	if typeof(saved_equipped) == TYPE_DICTIONARY:
		for slot in saved_equipped:
			if Gear.ITEMS.has(StringName(saved_equipped[slot])) and owns(StringName(saved_equipped[slot])):
				equipped[String(slot)] = String(saved_equipped[slot])
	_refund_old_purchases(data.get("purchases", {}))
	heard = {}
	var saved_heard = data.get("heard", [])
	if typeof(saved_heard) == TYPE_ARRAY:
		for id in saved_heard:
			heard[String(id)] = true
	met = {}
	var saved_met = data.get("met", [])
	if typeof(saved_met) == TYPE_ARRAY:
		for id in saved_met:
			met[String(id)] = true
	rests = {}
	var saved_rests = data.get("rests", {})
	if typeof(saved_rests) == TYPE_DICTIONARY:
		for key in saved_rests:
			rests[String(key)] = int(saved_rests[key])
	changed.emit()
	return true


## Les anciens achats de la boutique (gambison, cotte, lame, bottes, bandages)
## n'existent plus : leur prix est rendu en or.
const OLD_PRICES := {
	"gambison": [100], "cotte": [260], "lame": [120, 320], "bottes": [160], "bandages": [150],
}


func _refund_old_purchases(old) -> void:
	if typeof(old) != TYPE_DICTIONARY:
		return
	for key in old:
		var prices: Array = OLD_PRICES.get(String(key), [])
		for i in mini(int(old[key]), prices.size()):
			gold += int(prices[i])


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
