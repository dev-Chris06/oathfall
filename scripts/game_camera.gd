class_name GameCamera
extends Camera3D
## Caméra de jeu, en trois vues au choix du joueur (Options, menu pause) :
##
## - **Classique** : angles repris de Dark Avenger. Fixe, haute et plongeante,
##   de biais (le chemin du niveau, vers -Z, monte en diagonale vers le haut à
##   droite de l'écran).
## - **Épaule** : derrière l'épaule droite du héros ; on la tourne en glissant
##   le doigt sur la moitié droite de l'écran. Elle se rapproche quand un mur
##   passe entre elle et le héros.
## - **Première personne** : à hauteur des yeux ; le modèle du héros est caché.
##
## Le joystick suit la caméra (`view_yaw()`). En vue libre, un mort verrouillé
## (`lock_target`) tire la caméra derrière le héros, face à lui.

enum Mode { CLASSIC, SHOULDER, FIRST }

const MODE_NAMES := {
	Mode.CLASSIC: "Classique",
	Mode.SHOULDER: "Épaule",
	Mode.FIRST: "Première personne",
}

## Vue classique : biais autour de la verticale et plongée, en degrés.
const YAW := 40.0
const PITCH := 52.0
## Distance au point visé (le buste du héros).
const DISTANCE := 11.0
const LOOK_HEIGHT := 1.1
const FOLLOW_SPEED := 7.0

## Vue épaule.
const SHOULDER_DISTANCE := 5.0
const SHOULDER_HEIGHT := 1.55
const SHOULDER_SIDE := 1.0
const SHOULDER_PITCH := 16.0
## Vue à la première personne : hauteur des yeux (le chevalier KayKit est trapu).
const EYE_HEIGHT := 1.45
## Degrés par pixel de glissé.
const LOOK_SENSITIVITY := 0.22
const PITCH_MIN := {Mode.SHOULDER: -10.0, Mode.FIRST: -35.0}
const PITCH_MAX := {Mode.SHOULDER: 55.0, Mode.FIRST: 70.0}
## Vitesse à laquelle un mort verrouillé ramène la caméra face à lui.
const LOCK_TURN := 6.0

## La vue choisie, gardée dans les réglages (`Audio.save_settings`).
static var mode := Mode.CLASSIC
static var OFFSET := offset()

var target: Node3D
## Le mort verrouillé, s'il y en a un.
var lock_target: Node3D
## Orientation de la vue libre (radians) : même convention que la vue
## classique, la caméra se tient du côté (sin yaw, cos yaw) du héros.
var yaw := deg_to_rad(YAW)
## Plongée de la vue libre, en degrés (positif : regarde vers le bas).
var pitch := SHOULDER_PITCH
var _shake := 0.0
var _pivot := Vector3.ZERO
var _applied_mode := -1


func _ready() -> void:
	fov = 48.0
	current = true


static func mode_name(value: int) -> String:
	return MODE_NAMES.get(value, "Classique")


## Passe à la vue suivante (bouton des options).
static func next_mode() -> void:
	mode = ((mode + 1) % Mode.size()) as Mode


func follow(node: Node3D) -> void:
	target = node
	_pivot = node.global_position
	# La vue libre commence dans l'axe du niveau, dos au chemin.
	yaw = 0.0
	pitch = SHOULDER_PITCH if mode == Mode.SHOULDER else 0.0
	_apply_mode()
	_place(1.0)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Vrai si la vue se tourne au doigt.
static func is_free() -> bool:
	return mode != Mode.CLASSIC


## Orientation qui sert au joystick : « haut » va vers le haut de l'écran.
func view_yaw() -> float:
	return deg_to_rad(YAW) if mode == Mode.CLASSIC else yaw


## Direction du regard, à plat (vers où le héros frappe s'il ne bouge pas).
func view_forward() -> Vector3:
	var a := view_yaw()
	return Vector3(-sin(a), 0.0, -cos(a))


## Tourne la vue libre d'un glissé de `pixels`.
func look(pixels: Vector2) -> void:
	if mode == Mode.CLASSIC:
		return
	yaw = wrapf(yaw - deg_to_rad(pixels.x * LOOK_SENSITIVITY), -PI, PI)
	pitch = clampf(pitch + pixels.y * LOOK_SENSITIVITY, PITCH_MIN[mode], PITCH_MAX[mode])


func _process(delta: float) -> void:
	if target == null:
		return
	if _applied_mode != mode:
		_apply_mode()
	_place(1.0 - exp(-FOLLOW_SPEED * delta))
	if mode != Mode.CLASSIC and lock_target != null and is_instance_valid(lock_target):
		var to := lock_target.global_position - target.global_position
		to.y = 0.0
		if to.length() > 0.5:
			var wanted := atan2(-to.x, -to.z)
			yaw = lerp_angle(yaw, wanted, 1.0 - exp(-LOCK_TURN * delta))

	_shake = maxf(0.0, _shake - delta * 2.2)
	var amount := 0.3 if mode == Mode.CLASSIC else 0.08
	h_offset = randf_range(-1.0, 1.0) * _shake * amount
	v_offset = randf_range(-1.0, 1.0) * _shake * amount


## Réglages propres à chaque vue : champ de vision, portée, héros caché.
func _apply_mode() -> void:
	_applied_mode = mode
	match mode:
		Mode.CLASSIC:
			fov = 48.0
			near = 0.05
			far = 120.0
		Mode.SHOULDER:
			fov = 62.0
			near = 0.05
			far = 70.0
		Mode.FIRST:
			fov = 72.0
			near = 0.05
			far = 70.0
	if target != null and target.has_method(&"show_model"):
		target.call(&"show_model", mode != Mode.FIRST)


func _place(weight: float) -> void:
	match mode:
		Mode.CLASSIC:
			var wanted := target.global_position + OFFSET
			global_position = global_position.lerp(wanted, weight)
			# Retour depuis une vue libre : l'orientation fixe est rétablie.
			look_at(global_position - OFFSET + Vector3(0.0, LOOK_HEIGHT, 0.0), Vector3.UP)
		Mode.SHOULDER:
			# Le point suivi glisse vite vers le héros ; l'orientation, elle,
			# répond tout de suite au doigt.
			_pivot = _pivot.lerp(target.global_position, minf(1.0, weight * 2.0))
			var back := _back()
			var right := Vector3(cos(yaw), 0.0, -sin(yaw))
			var head := _pivot + Vector3(0.0, SHOULDER_HEIGHT, 0.0)
			var origin := head + right * SHOULDER_SIDE
			var wanted := origin + back * SHOULDER_DISTANCE
			var reach := _free_distance(head, origin, wanted)
			global_position = origin + back * reach
			look_at(global_position - back, Vector3.UP)
		Mode.FIRST:
			_pivot = target.global_position
			var eye := _pivot + Vector3(0.0, EYE_HEIGHT, 0.0)
			global_position = eye
			look_at(eye - _back(), Vector3.UP)


## Direction du héros vers la caméra pour la vue libre.
func _back() -> Vector3:
	var p := deg_to_rad(pitch)
	return Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p))


## Jusqu'où la caméra peut reculer de `origin` vers `wanted` sans qu'un mur
## s'interpose (les personnages ne comptent pas).
func _free_distance(head: Vector3, origin: Vector3, wanted: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var full := origin.distance_to(wanted)
	# L'épaule elle-même ne doit pas passer dans un mur.
	var side = _ray(space, head, origin)
	if side != null:
		return 0.0
	var hit = _ray(space, origin, wanted)
	if hit == null:
		return full
	return maxf(0.0, origin.distance_to(hit) - 0.3)


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3):
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var exclude: Array[RID] = []
	for attempt in 6:
		query.exclude = exclude
		var result := space.intersect_ray(query)
		if result.is_empty():
			return null
		if result["collider"] is CharacterBody3D:
			exclude.append(result["rid"])
			continue
		return result["position"]
	return null


## Position de la caméra classique par rapport aux pieds du héros.
static func offset() -> Vector3:
	var a := deg_to_rad(YAW)
	var p := deg_to_rad(PITCH)
	var flat := DISTANCE * cos(p)
	return Vector3(sin(a) * flat, LOOK_HEIGHT + DISTANCE * sin(p), cos(a) * flat)
