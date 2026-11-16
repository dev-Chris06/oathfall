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
	changed.emit()


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


## Les caractéristiques du héros, compétences et niveau compris.
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
	changed.emit()
	return true


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
