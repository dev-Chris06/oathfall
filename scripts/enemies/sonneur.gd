class_name SonneurEnemy
extends Enemy
## Le Sonneur, boss de la Chapelle des cendres.
##
## Il ne se bat presque pas : il sonne. Il reste sous sa cloche, ne poursuit
## personne, et ne repousse d'un geste que celui qui se colle à lui. À
## intervalles, s'il y a des corps sans repos, il lève les bras : la cloche se
## balance (c'est le moment de réagir), puis elle sonne et relève d'un coup
## tous les corps. Deux réponses : donner le Repos aux corps avant le coup, ou
## grimper couper les cordes. Chaque corde coupée espace les coups ; la
## troisième fait tomber la cloche sur lui, ce qui lui coûte une part de sa
## vie et l'étourdit, et la cloche ne sonne plus.
##
## Un coup ne l'ébranle pas pendant qu'il prépare un coup de cloche, ni juste
## après avoir été ébranlé : sans cela, un enchaînement le tiendrait sans fin.

## Le coup de cloche a sonné ; `raised` corps se sont relevés.
signal tolled(raised: int)
## Il lève les bras : le coup de cloche arrive.
signal tolling_soon

enum Phase { TELEGRAPH, TOLL, STUN }

## La cloche, donnée par le niveau.
var bell: GreatBell
## Là où il se tient : sous la cloche.
var home := Vector3.ZERO

var _phase := Phase.TELEGRAPH
var _toll_timer := 5.0
var _poise := 0.0
var _bell_alive := true
var _ropes_cut := 0
var _glow: OmniLight3D


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	home = global_position
	add_to_group(&"boss")
	_toll_timer = float(_type["toll_interval"]) * 0.55
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.7, 0.35)
	_glow.light_energy = 0.0
	_glow.omni_range = 8.0
	_glow.position.y = 2.6
	add_child(_glow)


func _physics_process(delta: float) -> void:
	_poise = maxf(0.0, _poise - delta)
	# Le minuteur de la cloche court tant qu'il est actif, qu'il frappe ou
	# non : s'il ne descendait qu'entre deux coups, la cloche ne sonnerait
	# presque jamais face à un héros qui le harcèle.
	if state == State.CHASE or state == State.WINDUP or state == State.STAGGER:
		_toll_timer = maxf(0.0, _toll_timer - delta)
	super._physics_process(delta)


func _chase() -> void:
	if _hero == null or _hero.is_dead():
		velocity = Vector3.ZERO
		_loop(_animation("idle"))
		return
	var offset := _to_hero()
	if offset.length() > 0.05:
		_facing = offset.normalized()
	# Un geste pour repousser qui s'approche trop, rien de plus.
	if offset.length() <= float(_type["attack_range"]) and _cooldown <= 0.0:
		state = State.WINDUP
		_state_time = 0.0
		_struck = false
		velocity = Vector3.ZERO
		var speed := float(_type["attack_speed"])
		var length := _once(_animation("attack"), speed)
		_attack_duration = maxf(length / speed, float(_type["attack_windup"]) + 0.2)
		return
	# Il ne poursuit personne : si on l'a repoussé, il regagne sa place.
	var back := home - global_position
	back.y = 0.0
	if back.length() > 0.6:
		_facing = back.normalized()
		velocity = _facing * float(_type["move_speed"])
		_loop(_animation("walk"))
	else:
		velocity = Vector3.ZERO
		_loop(_animation("idle"))
	if _bell_alive and _toll_timer <= 0.0:
		if _bodies_waiting() > 0:
			_begin_telegraph()
		else:
			# Rien à relever : la cloche se tait.
			_toll_timer = 1.0


func _begin_telegraph() -> void:
	_phase = Phase.TELEGRAPH
	_begin_special()
	_once(_animation("toll"), 0.9)
	tolling_soon.emit()


func _special(_delta: float) -> void:
	velocity = Vector3.ZERO
	match _phase:
		Phase.TELEGRAPH:
			var offset := _to_hero()
			if offset.length() > 0.05:
				_facing = offset.normalized()
			var progress := clampf(_state_time / float(_type["toll_windup"]), 0.0, 1.0)
			_glow.light_energy = 5.0 * progress
			if bell != null:
				bell.build_up(progress)
			if _state_time >= float(_type["toll_windup"]):
				_toll()
		Phase.TOLL:
			if _state_time >= 0.8:
				state = State.CHASE
				_cooldown = 0.5
		Phase.STUN:
			if _state_time >= float(_type["stun_time"]):
				state = State.CHASE
				_cooldown = 0.8


func _toll() -> void:
	var raised := 0
	for node in get_tree().get_nodes_in_group(&"bodies"):
		var body := node as Enemy
		if body != null and body != self:
			body.force_rise()
			raised += 1
	_glow.light_energy = 0.0
	if bell != null:
		bell.ring()
		Fx.ring(get_parent(), bell.global_position, Color(0.85, 0.62, 0.3, 0.6), 30.0, 1.3)
	_phase = Phase.TOLL
	_state_time = 0.0
	_once(_animation("toll_end"), 1.0)
	_toll_timer = toll_interval()
	tolled.emit(raised)


## Secondes entre deux coups : plus longues par corde coupée, plus courtes
## quand il est blessé à moitié.
func toll_interval() -> float:
	var interval := float(_type["toll_interval"]) + float(_type["toll_rope_delay"]) * _ropes_cut
	if health * 2 <= int(_type["health"]):
		interval *= 0.75
	return interval


func is_enraged() -> bool:
	return health * 2 <= int(_type["health"])


func _bodies_waiting() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"bodies"):
		if node != self:
			count += 1
	return count


## Une corde vient d'être coupée : les coups suivants seront plus espacés.
## Le coup déjà en route n'est pas repoussé : couper les cordes sans que la
## cloche sonne jamais ne coûterait rien.
func on_rope_cut(total_cut: int) -> void:
	_ropes_cut = total_cut


## La cloche lui tombe dessus.
func bell_fell() -> void:
	_bell_alive = false
	_glow.light_energy = 0.0
	if state == State.DOWN or state == State.RISING or state == State.RESTED:
		return
	var damage := int(float(_type["health"]) * float(_type["bell_fall_damage"]))
	health -= damage
	health_changed.emit(health, int(_type["health"]))
	if health <= 0:
		_fall()
		return
	_phase = Phase.STUN
	_begin_special()
	_once(_animation("stun"), 0.8)


func take_hit(from: Vector3, damage: int) -> void:
	if state == State.DOWN or state == State.RISING or state == State.RESTED:
		return
	# Pendant sa préparation, son étourdissement ou juste après avoir été
	# ébranlé, un coup le blesse sans l'interrompre.
	if state == State.SPECIAL or _poise > 0.0:
		health -= damage
		health_changed.emit(health, int(_type["health"]))
		if health <= 0:
			_fall()
		return
	_poise = float(_type["poise_time"])
	super.take_hit(from, damage)


func _on_fall() -> void:
	_glow.light_energy = 0.0


## Le maillet : un manche et une tête de fer.
func _build_prop(kind: String) -> Node3D:
	if kind != "maul":
		return null
	var maul := Node3D.new()
	var shaft := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.05
	rod.bottom_radius = 0.06
	rod.height = 1.5
	shaft.mesh = rod
	shaft.material_override = Fx.flat(Color(0.25, 0.16, 0.1))
	shaft.position.y = 0.5
	maul.add_child(shaft)
	var head := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(0.5, 0.34, 0.34)
	head.mesh = block
	head.material_override = Fx.flat(Color(0.17, 0.16, 0.15), 0.6, 0.5)
	head.position.y = 1.2
	maul.add_child(head)
	return maul
