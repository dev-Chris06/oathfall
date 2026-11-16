class_name FossoyeuseEnemy
extends Enemy
## La Fossoyeuse, boss de la Fosse. Elle n'enterre plus, elle déterre.
##
## Trois phases, selon sa vie restante :
##   1. Elle poursuit le héros à coups de pelle lents et lourds, et de larges
##      balayages. Un secteur rouge au sol annonce chaque coup.
##   2. Elle s'enfonce dans la terre et ressort ailleurs (la zone où elle
##      jaillit est marquée au sol), déterre des Dépouilles qu'il faut mettre
##      au repos, puis charge en ligne droite.
##   3. Elle arrache des pierres tombales et les lance (leur chute est marquée
##      au sol), puis un cri relève tous les corps laissés sans repos.
##
## Elle ne se laisse pas ébranler sans cesse : pendant un geste, ou juste après
## avoir été ébranlée, un coup la blesse sans l'interrompre. Sous terre, ou
## pendant le cri qui change de phase, elle est intouchable.
##
## `danger_time()` dit au joueur automatique quand son geste en cours peut
## toucher un point donné.

## Une nouvelle phase commence.
signal stage_changed(stage: int)
## Elle a déterré des Dépouilles, aux points donnés (des Vector3).
signal dug(points: Array)
## Son cri a relevé `count` corps.
signal raised(count: int)
## Elle a lancé une pierre.
signal thrown(stone: GraveStone)
## Un choc : le niveau secoue la caméra.
signal shook(amount: float)

enum Act { NONE, INTRO, SWING, SWEEP, RECOVER, CHANGE, DIVE, UNDER, EMERGE,
	CHARGE_TELE, CHARGE, CHARGE_END, THROW_TELE, THROW_END, RAISE_TELE, RAISE_END }

const BURIED_Y := -2.4

## Les monticules d'où elle peut jaillir, donnés par le niveau.
var mounds: Array[Vector3] = []
## Les pierres tombales du décor qu'elle peut arracher.
var props: Array[Node3D] = []

var _act := Act.NONE
var _stage := 1
var _pending := 1
var _poise := 0.0
var _attacks := 0
var _charges_left := 0
var _throws_left := 0
var _raise_timer := 9.0
var _hit_done := false
var _invulnerable := false
var _dir := Vector3.FORWARD
var _travel := 0.0
var _target := Vector3.ZERO
var _under_time := 1.4
var _warn: MeshInstance3D
var _mound: MeshInstance3D
var _glow: OmniLight3D


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	add_to_group(&"boss")
	_raise_timer = float(_type["raise_interval"]) * 0.7
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.6, 0.75, 1.0)
	_glow.light_energy = 0.0
	_glow.omni_range = 9.0
	_glow.position.y = 2.8
	add_child(_glow)
	# Le monticule qui avance quand elle file sous terre.
	var dome := SphereMesh.new()
	dome.radius = 1.3
	dome.height = 1.2
	dome.is_hemisphere = true
	_mound = MeshInstance3D.new()
	_mound.mesh = dome
	_mound.material_override = Fx.flat(Color(0.2, 0.15, 0.11))
	_mound.visible = false
	add_child(_mound)


func _physics_process(delta: float) -> void:
	_poise = maxf(0.0, _poise - delta)
	_raise_timer = maxf(0.0, _raise_timer - delta)
	super._physics_process(delta)


# --- L'entrée en scène ---------------------------------------------------------

## Elle jaillit du sol au centre de la fosse, sans blesser.
func intro() -> void:
	_model.position.y = BURIED_Y
	_begin(Act.INTRO)
	Fx.ring(get_parent(), global_position, Color(0.45, 0.33, 0.22, 0.7), 6.0, 1.0)


# --- Le choix du geste suivant -------------------------------------------------

func _chase() -> void:
	if _hero == null or _hero.is_dead():
		velocity = Vector3.ZERO
		_loop(_animation("idle"))
		return
	var offset := _to_hero()
	var distance := offset.length()
	if distance > 0.05:
		_facing = offset / distance
	if _pending > _stage:
		_begin(Act.CHANGE)
		_invulnerable = true
		_play_fit("roar", 1.6)
		_glow.light_energy = 3.0
		Fx.ring(get_parent(), global_position, Color(0.7, 0.8, 1.0, 0.6), 12.0, 1.4)
		return
	match _stage:
		1:
			_melee_or_approach(distance)
		2:
			velocity = Vector3.ZERO
			_loop(_animation("idle"))
			if _cooldown <= 0.0:
				_begin_dive()
		_:
			_stage_three(distance)


## Phase 1 : elle s'approche, puis frappe : deux coups de pelle, un balayage.
func _melee_or_approach(distance: float) -> void:
	if distance > float(_type["swing_range"]) - 0.4:
		velocity = _facing * float(_type["move_speed"])
		_loop(_animation("walk"))
		return
	velocity = Vector3.ZERO
	_loop(_animation("idle"))
	if _cooldown <= 0.0:
		_start_melee()


func _start_melee() -> void:
	Audio.play(&"swing_heavy")
	_attacks += 1
	if _attacks % 3 == 0:
		_begin(Act.SWEEP)
		_play_blow("sweep", float(_type["sweep_windup"]), float(_type["sweep_impact"]))
		_show_sector(float(_type["sweep_range"]), float(_type["sweep_arc"]), Color(1.0, 0.45, 0.1, 0.3))
	else:
		_begin(Act.SWING)
		_play_blow("swing", float(_type["swing_windup"]), float(_type["swing_impact"]))
		_show_sector(float(_type["swing_range"]), float(_type["swing_arc"]), Color(1.0, 0.2, 0.1, 0.35))
	_hit_done = false


## Phase 3 : de loin, des pierres ; de près, la pelle ; de temps en temps, le cri.
func _stage_three(distance: float) -> void:
	velocity = Vector3.ZERO
	_loop(_animation("idle"))
	if _cooldown > 0.0:
		return
	if _raise_timer <= 0.0 and _bodies_waiting() > 0:
		_begin_raise()
	elif distance <= float(_type["swing_range"]) - 0.4:
		_start_melee()
	else:
		_throws_left = int(_type["throws"])
		_begin_throw()


func _bodies_waiting() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"bodies"):
		if node != self:
			count += 1
	return count


# --- Les gestes ---------------------------------------------------------------

func _special(delta: float) -> void:
	match _act:
		Act.INTRO:
			velocity = Vector3.ZERO
			_model.position.y = lerpf(BURIED_Y, 0.0, clampf(_state_time / 1.4, 0.0, 1.0))
			if _state_time >= 1.4:
				_end_act(0.8)
		Act.SWING, Act.SWEEP:
			_do_melee()
		Act.RECOVER:
			pass
		Act.CHANGE:
			_do_change()
		Act.DIVE:
			_do_dive()
		Act.UNDER:
			_do_under(delta)
		Act.EMERGE:
			_do_emerge()
		Act.CHARGE_TELE:
			_do_charge_tele()
		Act.CHARGE:
			_do_charge(delta)
		Act.CHARGE_END:
			velocity = Vector3.ZERO
			if _state_time >= float(_type["charge_recover"]):
				if _charges_left > 1:
					_charges_left -= 1
					_begin_charge_tele()
				else:
					_end_act(1.1)
		Act.THROW_TELE:
			_do_throw_tele()
		Act.THROW_END:
			velocity = Vector3.ZERO
			if _state_time >= 0.55:
				_throws_left -= 1
				if _throws_left > 0:
					_begin_throw()
				else:
					_end_act(1.8)
		Act.RAISE_TELE:
			_do_raise_tele()
		Act.RAISE_END:
			velocity = Vector3.ZERO
			if _state_time >= 0.8:
				_end_act(1.2)


func _begin(act: Act) -> void:
	_act = act
	_begin_special()


func _end_act(cooldown: float) -> void:
	_act = Act.NONE
	state = State.CHASE
	_cooldown = cooldown
	_clear_marker()


## Joue une animation de façon qu'elle dure `duration`.
func _play_fit(key: String, duration: float) -> void:
	var anim_name := _animation(key)
	var length := 1.2
	if _anim != null and _anim.has_animation(anim_name):
		length = _anim.get_animation(anim_name).length
	_once(anim_name, length / maxf(duration, 0.1))


# --- Coup de pelle et balayage -------------------------------------------------

func _do_melee() -> void:
	velocity = Vector3.ZERO
	var sweep := _act == Act.SWEEP
	var windup := float(_type["sweep_windup" if sweep else "swing_windup"])
	if _state_time < windup * 0.7:
		var offset := _to_hero()
		if offset.length() > 0.05:
			_facing = offset.normalized()
	if _warn != null:
		_warn.rotation.y = atan2(_facing.x, _facing.z)
	var range_name := "sweep_range" if sweep else "swing_range"
	var damage := int(_type["sweep_damage" if sweep else "swing_damage"])
	if not _hit_done and _state_time >= windup:
		# Le moment de l'impact : la pelle touche le sol à l'écran (voir
		# `_play_blow`) et, au même instant, les dégâts sont appliqués. La
		# zone flashe pour montrer où le coup a porté.
		_hit_done = true
		if _warn != null:
			_warn.material_override.albedo_color = Color(1.0, 0.92, 0.7, 0.65)
		if _in_arc(float(_type[range_name]), float(_type["sweep_arc" if sweep else "swing_arc"])):
			_hurt_hero(damage)
		Fx.ring(get_parent(), global_position + _facing * float(_type[range_name]) * 0.55,
			Color(0.55, 0.42, 0.28, 0.7), 3.0, 0.4)
		shook.emit(0.8)
	if _hit_done and _warn != null and _state_time >= windup + 0.18:
		_clear_marker()
	if _hit_done and _state_time >= windup + float(_type["recover"]):
		_end_act(float(_type["attack_gap"]))


func _in_arc(reach: float, arc_deg: float) -> bool:
	var offset := _to_hero()
	if offset.length() > reach:
		return false
	return offset.length() <= 0.3 or _facing.angle_to(offset) <= deg_to_rad(arc_deg / 2.0)


func _hurt_hero(damage: int) -> bool:
	if _hero == null or _hero.is_dead() or _hero.is_dodging():
		return false
	_hero.take_damage(damage, global_position, self)
	return true


# --- Changement de phase -------------------------------------------------------

func _do_change() -> void:
	velocity = Vector3.ZERO
	if _state_time >= 1.6:
		_stage = _pending
		_invulnerable = false
		_glow.light_energy = 0.0
		stage_changed.emit(_stage)
		_check_stage()
		if _stage == 2:
			_end_act(0.2)
		else:
			_end_act(0.6)


## La phase que sa vie restante demande ; on les franchit une à une.
func _check_stage() -> void:
	var ratio := float(health) / float(_type["health"])
	var wanted := 1
	if ratio <= float(_type["stage2_at"]):
		wanted = 2
	if ratio <= float(_type["stage3_at"]):
		wanted = 3
	if wanted > _stage and _pending <= _stage:
		_pending = _stage + 1


func current_stage() -> int:
	return _stage


# --- Phase 2 : sous terre ------------------------------------------------------

func _begin_dive() -> void:
	Audio.play(&"dig")
	_begin(Act.DIVE)
	_invulnerable = true
	remove_from_group(&"hittable")
	_shape.set_deferred("disabled", true)
	Fx.ring(get_parent(), global_position, Color(0.45, 0.33, 0.22, 0.7), 4.0, 0.8)


func _do_dive() -> void:
	velocity = Vector3.ZERO
	var t := clampf(_state_time / float(_type["dive_time"]), 0.0, 1.0)
	_model.position.y = lerpf(0.0, BURIED_Y, t)
	if t >= 1.0:
		_model.visible = false
		_start_under()


func _start_under() -> void:
	_target = _pick_mound()
	_begin(Act.UNDER)
	_mound.visible = true
	# La zone où elle va jaillir est marquée : c'est le moment de s'écarter.
	var radius := float(_type["emerge_radius"])
	_clear_marker()
	_warn = Fx.disc(radius, Color(1.0, 0.25, 0.1, 0.3))
	_warn.top_level = true
	add_child(_warn)
	_warn.global_position = Vector3(_target.x, 0.09, _target.z)
	var distance := global_position.distance_to(_target)
	_under_time = maxf(1.4, distance / float(_type["burrow_speed"]) + 0.6)


## Un monticule loin du héros : elle ne jaillit pas sous ses pieds.
func _pick_mound() -> Vector3:
	if mounds.is_empty():
		return global_position
	var far: Array[Vector3] = []
	for point in mounds:
		var flat := Vector3(point.x - _hero.global_position.x, 0.0, point.z - _hero.global_position.z)
		if flat.length() > 6.0 and point.distance_to(global_position) > 3.0:
			far.append(point)
	if far.is_empty():
		far.assign(mounds)
	return far[randi() % far.size()]


func _do_under(delta: float) -> void:
	velocity = Vector3.ZERO
	var to_target := _target - global_position
	to_target.y = 0.0
	var step := float(_type["burrow_speed"]) * delta
	if to_target.length() > step:
		global_position += to_target.normalized() * step
		_mound.position.y = sin(_state_time * 14.0) * 0.05
	else:
		global_position = Vector3(_target.x, global_position.y, _target.z)
	if _state_time >= _under_time:
		_emerge()


func _emerge() -> void:
	Audio.play(&"dig")
	_clear_marker()
	_mound.visible = false
	_model.visible = true
	_model.position.y = BURIED_Y
	_begin(Act.EMERGE)
	_play_fit("emerge", 1.0)
	_shape.set_deferred("disabled", false)
	add_to_group(&"hittable")
	_invulnerable = false
	var radius := float(_type["emerge_radius"])
	if _to_hero().length() <= radius:
		_hurt_hero(int(_type["emerge_damage"]))
	Fx.ring(get_parent(), global_position, Color(0.5, 0.36, 0.24, 0.8), radius * 1.4, 0.5)
	shook.emit(1.2)
	# Elle déterre des Dépouilles autour d'elle.
	var points: Array = []
	var count := int(_type["dig_count"])
	for i in count:
		var angle := TAU * float(i) / float(count) + randf() * 0.6
		points.append(global_position + Vector3(cos(angle), 0.0, sin(angle)) * 3.6)
	dug.emit(points)


func _do_emerge() -> void:
	velocity = Vector3.ZERO
	var t := clampf(_state_time / float(_type["emerge_time"]), 0.0, 1.0)
	_model.position.y = lerpf(BURIED_Y, 0.0, t)
	if t >= 1.0:
		_charges_left = int(_type["charges"])
		_begin_charge_tele()


# --- Phase 2 : la charge -------------------------------------------------------

func _begin_charge_tele() -> void:
	_begin(Act.CHARGE_TELE)
	_hit_done = false
	var offset := _to_hero()
	_dir = offset.normalized() if offset.length() > 0.05 else _facing
	_play_fit("roar", float(_type["charge_windup"]))
	_clear_marker()
	var length := float(_type["charge_max"])
	var line := BoxMesh.new()
	line.size = Vector3(float(_type["charge_width"]), 0.02, length)
	_warn = MeshInstance3D.new()
	_warn.mesh = line
	_warn.material_override = Fx.glow(Color(1.0, 0.2, 0.1, 0.3))
	_warn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warn.top_level = true
	add_child(_warn)
	_place_line()


func _place_line() -> void:
	var length := float(_type["charge_max"])
	_warn.global_position = global_position + _dir * length / 2.0 + Vector3(0.0, 0.09, 0.0)
	_warn.rotation.y = atan2(_dir.x, _dir.z)


func _do_charge_tele() -> void:
	velocity = Vector3.ZERO
	var windup := float(_type["charge_windup"])
	if _state_time < windup * 0.7:
		var offset := _to_hero()
		if offset.length() > 0.05:
			_dir = offset.normalized()
	_facing = _dir
	_place_line()
	if _state_time >= windup:
		_clear_marker()
		_begin(Act.CHARGE)
		_travel = 0.0
		_hit_done = false
		_once(_animation("charge"), 1.4)


func _do_charge(delta: float) -> void:
	velocity = _dir * float(_type["charge_speed"])
	_facing = _dir
	_travel += float(_type["charge_speed"]) * delta
	if not _hit_done and _to_hero().length() < 1.9:
		_hit_done = true
		_hurt_hero(int(_type["charge_damage"]))
	var blocked := _state_time > 0.15 and get_slide_collision_count() > 0
	if _travel >= float(_type["charge_max"]) or blocked:
		_begin(Act.CHARGE_END)
		_once(_animation("stun"), 0.8)
		shook.emit(1.0)


# --- Phase 3 : les pierres et le cri -------------------------------------------

func _begin_throw() -> void:
	_begin(Act.THROW_TELE)
	_play_blow("throw", float(_type["throw_windup"]), float(_type["throw_impact"]))
	_arrache_stone()


## Elle arrache une pierre tombale du décor, la plus proche d'elle.
func _arrache_stone() -> void:
	var best: Node3D = null
	var best_distance := INF
	for prop in props:
		if not is_instance_valid(prop):
			continue
		var distance := prop.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = prop
	if best != null:
		props.erase(best)
		Fx.ring(get_parent(), best.global_position, Color(0.5, 0.36, 0.24, 0.8), 3.0, 0.5)
		best.queue_free()


func _do_throw_tele() -> void:
	velocity = Vector3.ZERO
	var offset := _to_hero()
	if offset.length() > 0.05:
		_facing = offset.normalized()
	if _state_time >= float(_type["throw_windup"]):
		_launch_stone()
		_begin(Act.THROW_END)


func _launch_stone() -> void:
	Audio.play(&"swing_heavy")
	var stone := GraveStone.new()
	stone.hero = _hero
	stone.start = global_position + Vector3(0.0, 3.2, 0.0) + _facing * 0.8
	stone.target = Vector3(_hero.global_position.x, 0.0, _hero.global_position.z)
	stone.flight = float(_type["throw_flight"])
	stone.radius = float(_type["throw_radius"])
	stone.damage = int(_type["throw_damage"])
	get_parent().add_child(stone)
	thrown.emit(stone)


func _begin_raise() -> void:
	Audio.play(&"scream")
	_begin(Act.RAISE_TELE)
	_play_fit("raise", float(_type["raise_windup"]) + 0.3)


func _do_raise_tele() -> void:
	velocity = Vector3.ZERO
	var progress := clampf(_state_time / float(_type["raise_windup"]), 0.0, 1.0)
	_glow.light_energy = 5.0 * progress
	if _state_time >= float(_type["raise_windup"]):
		var count := 0
		for node in get_tree().get_nodes_in_group(&"bodies"):
			var body := node as Enemy
			if body != null and body != self:
				body.force_rise()
				count += 1
		_glow.light_energy = 0.0
		Fx.ring(get_parent(), global_position, Color(0.7, 0.8, 1.0, 0.6), 24.0, 1.2)
		_raise_timer = float(_type["raise_interval"])
		_begin(Act.RAISE_END)
		shook.emit(1.0)
		raised.emit(count)


# --- Les coups qu'elle reçoit --------------------------------------------------

func take_hit(from: Vector3, damage: int) -> void:
	if state == State.DOWN or state == State.RISING or state == State.RESTED:
		return
	# Sous terre, ou pendant le cri qui change de phase : intouchable.
	if _invulnerable:
		return
	if state == State.SPECIAL or _poise > 0.0:
		health -= damage
		health_changed.emit(health, int(_type["health"]))
		if health <= 0:
			_fall()
		else:
			_check_stage()
		return
	_poise = float(_type["poise_time"])
	super.take_hit(from, damage)
	if health > 0:
		_check_stage()


func _on_fall() -> void:
	_clear_marker()
	_glow.light_energy = 0.0
	_mound.visible = false
	_model.visible = true
	_model.position.y = 0.0
	_invulnerable = false
	_act = Act.NONE


func _finish_rising() -> void:
	super._finish_rising()
	_act = Act.NONE
	_cooldown = 1.5
	_check_stage()


# --- Pour le joueur automatique ------------------------------------------------

## Dans combien de secondes son geste en cours peut toucher `point` ; une
## très grande valeur si rien ne le menace.
func danger_time(point: Vector3) -> float:
	var offset := point - global_position
	offset.y = 0.0
	match _act:
		Act.SWING, Act.SWEEP:
			var sweep := _act == Act.SWEEP
			var reach := float(_type["sweep_range" if sweep else "swing_range"]) + 0.4
			var windup := float(_type["sweep_windup" if sweep else "swing_windup"])
			if not _hit_done and offset.length() <= reach:
				return maxf(0.0, windup - _state_time)
		Act.UNDER:
			var gap := Vector3(point.x - _target.x, 0.0, point.z - _target.z).length()
			if gap <= float(_type["emerge_radius"]) + 0.8:
				return maxf(0.0, _under_time - _state_time)
		Act.CHARGE_TELE:
			var along := offset.dot(_dir)
			var across := (offset - _dir * along).length()
			if along > 0.0 and along <= float(_type["charge_max"]) and across <= float(_type["charge_width"]):
				return maxf(0.0, float(_type["charge_windup"]) - _state_time) + along / float(_type["charge_speed"])
		Act.CHARGE:
			var along_now := offset.dot(_dir)
			var across_now := (offset - _dir * along_now).length()
			if along_now > 0.0 and across_now <= float(_type["charge_width"]) and not _hit_done:
				return along_now / float(_type["charge_speed"])
	return 9999.0


# --- Marqueurs et accessoires --------------------------------------------------

func _show_sector(radius: float, angle: float, color: Color) -> void:
	_clear_marker()
	_warn = Fx.sector(radius, angle, color)
	add_child(_warn)
	_warn.rotation.y = atan2(_facing.x, _facing.z)


func _clear_marker() -> void:
	if _warn != null and is_instance_valid(_warn):
		_warn.queue_free()
	_warn = null


## La pelle : un manche et un fer plat.
func _build_prop(kind: String) -> Node3D:
	if kind != "spade":
		return null
	var spade := Node3D.new()
	var shaft := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.05
	rod.bottom_radius = 0.06
	rod.height = 1.6
	shaft.mesh = rod
	shaft.material_override = Fx.flat(Color(0.27, 0.18, 0.11))
	shaft.position.y = 0.55
	spade.add_child(shaft)
	var blade := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(0.42, 0.55, 0.05)
	blade.mesh = plate
	blade.material_override = Fx.flat(Color(0.22, 0.2, 0.19), 0.6, 0.5)
	blade.position.y = 1.5
	spade.add_child(blade)
	return spade
