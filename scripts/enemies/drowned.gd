class_name DrownedEnemy
extends Enemy
## Le Noyé : sorti du fleuve, il y retourne. Abattu, son corps glisse vers le
## bord de l'eau (`Level.water_edge`) ; s'il l'atteint avant d'avoir reçu le
## Repos, il coule, puis remonte sur le quai un peu plus loin, debout, sans
## rien laisser au héros. Le corps ne glisse pas pendant qu'on lui donne le
## Repos, ni dans la lueur d'un cierge.

var _sunk := false
var _surfaced_at := Vector3.ZERO


## Vrai tant que le Noyé est sous l'eau, entre deux remontées.
func is_sunk() -> bool:
	return _sunk


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DOWN and _state_time >= float(_type["slide_delay"]):
		_slide(delta)


func _slide(delta: float) -> void:
	var level := get_parent() as Level
	if level == null or rise_rate() <= 0.0:
		return
	if _hero != null and _hero.state == Hero.State.RITE and _hero._rite_target == self:
		return
	var edge: Variant = level.water_edge(body_position())
	if edge == null:
		return
	var to: Vector3 = (edge as Vector3) - body_position()
	to.y = 0.0
	if to.length() <= 0.35:
		_sink()
		return
	global_position += to.normalized() * minf(float(_type["slide_speed"]) * delta, to.length())


func _sink() -> void:
	Audio.play(&"splash")
	Fx.ring(get_parent(), body_position(), Color(0.45, 0.6, 0.75, 0.7), 1.8, 0.7)
	_sunk = true
	_on_fall()
	remove_from_group(&"bodies")
	_marker.visible = false
	_model.visible = false
	_begin_special()


func _special(_delta: float) -> void:
	velocity = Vector3.ZERO
	if not _sunk:
		state = State.CHASE
		return
	if _state_time < float(_type["sunk_time"]):
		return
	# Il remonte sur le quai, près du héros, du côté de l'eau.
	var level := get_parent() as Level
	var near: Vector3 = _hero.global_position if _hero != null else global_position
	var edge: Variant = level.water_edge(near) if level != null else null
	var at := near
	if edge != null:
		var inland := near - (edge as Vector3)
		inland.y = 0.0
		at = (edge as Vector3) + (inland.normalized() if inland.length() > 0.1 else Vector3.ZERO) * 1.2
		at.z += randf_range(-3.0, 3.0)
	global_position = Vector3(at.x, 0.0, at.z)
	_surfaced_at = global_position
	_sunk = false
	_model.visible = true
	Audio.play(&"splash", -4.0)
	Fx.ring(get_parent(), global_position, Color(0.45, 0.6, 0.75, 0.7), 1.8, 0.7)
	_start_rising()
