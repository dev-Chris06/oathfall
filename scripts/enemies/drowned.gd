class_name DrownedEnemy
extends Enemy
## Le Noyé : sorti du fleuve, il y retourne, et veut y emmener le héros.
##
## - **Le corps glisse** : abattu, il glisse vers le bord de l'eau
##   (`Level.water_edge`) ; s'il l'atteint avant d'avoir reçu le Repos, il
##   coule, puis remonte un peu plus loin, debout, sans rien laisser. Le corps
##   ne glisse pas pendant qu'on lui donne le Repos, ni sous un cierge.
## - **L'Étreinte** : quand le héros est près du bord, le Noyé ne frappe plus,
##   il l'agrippe (geste annoncé par une flaque qui s'éclaire sous lui) et le
##   traîne vers l'eau, en le blessant peu à peu. Arrivé au bord, il plonge en
##   le meurtrissant. Frapper le Noyé ou esquiver libère le héros.
## - **La main** : un Noyé coulé guette sous l'eau ; si le héros s'approche du
##   bord, il en sort d'un coup et l'agrippe.
## - Tant qu'un Noyé est debout, le brouillard du fleuve monte et cache les
##   corps (`Level._update_mist`).

enum Grab { NONE, WINDUP, HOLD }

var _sunk := false
var _surfaced_at := Vector3.ZERO
var _grab := Grab.NONE
var _grab_windup := 0.0
var _grab_timer := 0.0
var _hold_time := 0.0
var _tick := 0.0
var _puddle: MeshInstance3D
var _puddle_material: StandardMaterial3D


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	_grab_timer = randf_range(0.5, 1.5)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.02
	disc.radial_segments = 16
	disc.rings = 1
	_puddle_material = Fx.glow(Color(0.35, 0.7, 0.85, 0.0))
	_puddle = MeshInstance3D.new()
	_puddle.mesh = disc
	_puddle.material_override = _puddle_material
	_puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Au-dessus de la brume du fleuve, pour que le geste reste annoncé.
	_puddle.position.y = 0.62
	_puddle.visible = false
	add_child(_puddle)


## Vrai tant que le Noyé est sous l'eau, entre deux remontées.
func is_sunk() -> bool:
	return _sunk


## Vrai pendant qu'il tient le héros.
func is_holding() -> bool:
	return state == State.SPECIAL and _grab == Grab.HOLD


## Vrai pendant qu'il arme son Étreinte.
func is_reaching() -> bool:
	return state == State.SPECIAL and _grab == Grab.WINDUP


func _physics_process(delta: float) -> void:
	_grab_timer = maxf(0.0, _grab_timer - delta)
	super._physics_process(delta)
	if state == State.DOWN and _state_time >= float(_type["slide_delay"]):
		_slide(delta)


func _level() -> Level:
	return get_parent() as Level


## Distance du héros au bord de l'eau (INF sans eau), et le point du bord.
func _hero_edge() -> Variant:
	var level := _level()
	if level == null or _hero == null:
		return null
	return level.water_edge(_hero.global_position)


func _hero_to_edge() -> float:
	var edge: Variant = _hero_edge()
	if edge == null:
		return INF
	var to: Vector3 = (edge as Vector3) - _hero.global_position
	to.y = 0.0
	return to.length()


func _can_grab_hero() -> bool:
	return _hero != null and not _hero.is_dead() and not _hero.is_held()


# --- Debout : l'Étreinte ------------------------------------------------------

func _chase() -> void:
	if _can_grab_hero() and _cooldown <= 0.0 and _grab_timer <= 0.0 \
			and _hero_to_edge() <= float(_type["grab_edge"]) \
			and _to_hero().length() <= float(_type["grab_range"]):
		_begin_grab(float(_type["grab_windup"]))
		return
	super._chase()


func _begin_grab(windup: float) -> void:
	var offset := _to_hero()
	if offset.length() > 0.05:
		_facing = offset.normalized()
	_begin_special()
	_grab = Grab.WINDUP
	_grab_windup = windup
	_puddle.visible = true
	_play_blow("grab", windup, float(_type["grab_impact"]))


func _special(delta: float) -> void:
	velocity = Vector3.ZERO
	if _sunk:
		_under_water()
		return
	match _grab:
		Grab.WINDUP:
			var offset := _to_hero()
			if offset.length() > 0.05:
				_facing = offset.normalized()
			_puddle_material.albedo_color.a = 0.15 + 0.55 * clampf(_state_time / _grab_windup, 0.0, 1.0)
			if _state_time >= _grab_windup:
				_seize()
		Grab.HOLD:
			_hold(delta)
		_:
			state = State.CHASE


## Le geste arrive au bout : le héros est pris, s'il est encore à portée.
func _seize() -> void:
	var in_reach := _to_hero().length() <= float(_type["grab_range"]) + 0.6
	if not in_reach or not _can_grab_hero() or not _hero.grab(self):
		_end_grab()
		return
	Audio.play(&"splash", -6.0)
	_grab = Grab.HOLD
	_hold_time = 0.0
	_tick = 0.0
	_puddle.visible = false
	_shape.set_deferred("disabled", true)
	_loop(_animation("drag"))
	var level := _level()
	if level != null and not level.has_meta(&"grab_told"):
		level.set_meta(&"grab_told", true)
		level.hud.show_message("Un Noyé t'agrippe et t'entraîne vers l'eau.\nFrappe-le, ou esquive pour te dégager.", 4.5)


func _hold(delta: float) -> void:
	if _hero == null or _hero.is_dead() or _hero.held_by != self:
		_end_grab()
		return
	_hold_time += delta
	var edge: Variant = _hero_edge()
	if edge == null or _hold_time > float(_type["hold_max"]):
		_end_grab()
		return
	var to: Vector3 = (edge as Vector3) - _hero.global_position
	to.y = 0.0
	if to.length() <= float(_type["plunge_at"]):
		_plunge()
		return
	var dir := to.normalized()
	_hero.held_drag = dir * float(_type["drag_speed"])
	# Il recule vers l'eau en tenant le héros, face à lui.
	global_position = _hero.global_position + dir * 0.8
	_facing = -dir
	_tick += delta
	if _tick >= float(_type["grab_tick"]):
		_tick = 0.0
		_hero.take_damage(damage_of(int(_type["grab_damage"])), global_position, self)


## Au bord : il plonge, le héros est meurtri et lâché ; le Noyé coule.
func _plunge() -> void:
	_hero.release(self)
	_hero.take_damage(damage_of(int(_type["plunge_damage"])), global_position, self)
	_grab = Grab.NONE
	remove_from_group(&"hittable")
	_go_under()


func _end_grab() -> void:
	if _hero != null:
		_hero.release(self)
	if _grab == Grab.HOLD:
		_shape.set_deferred("disabled", false)
	_grab = Grab.NONE
	_puddle.visible = false
	_grab_timer = float(_type["grab_cooldown"])
	_cooldown = 0.8
	if state == State.SPECIAL and not _sunk:
		state = State.CHASE


func take_hit(from: Vector3, damage: int) -> void:
	if state == State.SPECIAL and _grab != Grab.NONE:
		_end_grab()
	super.take_hit(from, damage)


func _on_fall() -> void:
	if _grab != Grab.NONE:
		_end_grab()
	_puddle.visible = false


# --- Au sol : le corps glisse --------------------------------------------------

func _slide(delta: float) -> void:
	var level := _level()
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
	_on_fall()
	remove_from_group(&"bodies")
	_go_under()


## Disparaît sous l'eau, et y guette.
func _go_under() -> void:
	Audio.play(&"splash")
	Fx.ring(get_parent(), body_position() if state == State.DOWN else global_position,
		Color(0.45, 0.6, 0.75, 0.7), 1.8, 0.7)
	_sunk = true
	_shape.set_deferred("disabled", true)
	_marker.visible = false
	_model.visible = false
	_puddle.visible = false
	_begin_special()


# --- Sous l'eau ---------------------------------------------------------------

func _under_water() -> void:
	# La main : le héros s'approche du bord, le Noyé en jaillit et l'agrippe.
	if _state_time >= float(_type["hand_delay"]) and _can_grab_hero() and not _hero.is_dodging() \
			and _hero_to_edge() <= float(_type["hand_reach"]):
		var edge: Vector3 = _hero_edge()
		var to := edge - _hero.global_position
		to.y = 0.0
		var dir := to.normalized() if to.length() > 0.05 else Vector3.RIGHT
		_surface(_hero.global_position + dir * minf(0.9, to.length() + 0.3), true)
		_begin_grab(float(_type["hand_windup"]))
		return
	if _state_time < float(_type["sunk_time"]):
		return
	# Sinon il remonte sur le quai, près du héros, du côté de l'eau.
	var level := _level()
	var near: Vector3 = _hero.global_position if _hero != null else global_position
	var edge_point: Variant = level.water_edge(near) if level != null else null
	var at := near
	if edge_point != null:
		var inland := near - (edge_point as Vector3)
		inland.y = 0.0
		at = (edge_point as Vector3) + (inland.normalized() if inland.length() > 0.1 else Vector3.ZERO) * 1.2
		at.z += randf_range(-3.0, 3.0)
	_surface(at, false)
	_start_rising()


## Sort de l'eau en `at`. Avec `standing` (la main), il est aussitôt debout,
## sans se relever : il compte comme relevé.
func _surface(at: Vector3, standing: bool) -> void:
	global_position = Vector3(at.x, 0.0, at.z)
	_surfaced_at = global_position
	_sunk = false
	_model.visible = true
	Audio.play(&"splash", -4.0)
	Fx.ring(get_parent(), global_position, Color(0.45, 0.6, 0.75, 0.7), 1.8, 0.7)
	if standing:
		_shape.set_deferred("disabled", false)
		add_to_group(&"hittable")
		health = int(ceil(float(max_health()) * float(_type["rise_health"])))
		health_changed.emit(health, max_health())
		rose.emit(self)
