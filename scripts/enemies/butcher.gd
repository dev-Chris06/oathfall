class_name ButcherEnemy
extends Enemy
## Le Boucher des halles : lent, solide, à armure (voir `Enemy.take_hit`). Il
## enchaîne parfois deux coups. Quand le héros est loin, il piétine puis
## charge en ligne droite ; s'il s'écrase contre un mur, il est assommé et
## reste ouvert. Sous la moitié de sa vie, il enrage : plus vite, plus fort.

enum Phase { NONE, STOMP, CHARGE, STUN }

## La charge s'est écrasée contre un mur.
signal crashed

var _phase := Phase.NONE
var _charge_timer := 5.0
var _charge_direction := Vector3.ZERO
var _charge_hit := false
var _line: MeshInstance3D
var _line_material: StandardMaterial3D


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	_charge_timer = float(_type["charge_interval"]) * 0.6
	_line_material = Fx.glow(Color(1.0, 0.2, 0.1, 0.0))
	var strip := BoxMesh.new()
	strip.size = Vector3(1.3, 0.02, 1.0)
	_line = MeshInstance3D.new()
	_line.mesh = strip
	_line.material_override = _line_material
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.visible = false
	_line.top_level = true
	add_child(_line)


func _physics_process(delta: float) -> void:
	if state == State.CHASE or state == State.WINDUP or state == State.STAGGER:
		_charge_timer = maxf(0.0, _charge_timer - delta)
	# Sous la moitié de sa vie, il enrage : la hâte et la force d'un cri, en
	# permanence (l'anneau rouge sous ses pieds le dit).
	if is_standing() and health * 2 <= max_health():
		hasten(0.3)
	super._physics_process(delta)


func _chase() -> void:
	super._chase()
	if state != State.CHASE or _charge_timer > 0.0 or _hero == null or _hero.is_dead():
		return
	var distance := _to_hero().length()
	if distance >= float(_type["charge_min"]) and distance <= float(_type["charge_max"]):
		_begin_stomp()
	elif distance < float(_type["charge_min"]):
		_charge_timer = 0.8


func _begin_stomp() -> void:
	_phase = Phase.STOMP
	_begin_special()
	var offset := _to_hero()
	_charge_direction = offset.normalized() if offset.length() > 0.05 else _facing
	_facing = _charge_direction
	_line.visible = true
	_place_line(float(_type["charge_max"]) * 0.7)
	Audio.play(&"swing_light", -2.0)


func _special(_delta: float) -> void:
	match _phase:
		Phase.STOMP:
			velocity = Vector3.ZERO
			var progress := clampf(_state_time / float(_type["stomp_time"]), 0.0, 1.0)
			_line_material.albedo_color.a = 0.15 + 0.45 * progress
			if _state_time >= float(_type["stomp_time"]):
				_phase = Phase.CHARGE
				_state_time = 0.0
				_charge_hit = false
				Audio.play(&"swing_light", -2.0)
		Phase.CHARGE:
			velocity = _charge_direction * float(_type["charge_speed"])
			_facing = _charge_direction
			if not _charge_hit and _hero != null and not _hero.is_dead() and not _hero.is_dodging() \
					and _to_hero().length() <= 1.7:
				_charge_hit = true
				_hero.take_damage(damage_of(int(_type["charge_damage"])), global_position, self)
			if _state_time > 0.25 and _hit_wall():
				_crash()
			elif _state_time >= float(_type["charge_time"]):
				_end_charge()
		Phase.STUN:
			velocity = Vector3.ZERO
			if _state_time >= float(_type["stun_time"]):
				_phase = Phase.NONE
				state = State.CHASE
				_cooldown = 0.8


## Un mur (et pas le héros) a arrêté la charge.
func _hit_wall() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is StaticBody3D:
			return true
	return false


func _crash() -> void:
	_line.visible = false
	_phase = Phase.STUN
	_state_time = 0.0
	velocity = Vector3.ZERO
	_open_time = float(_type["stun_time"]) + 0.4
	_charge_timer = float(_type["charge_interval"])
	Fx.ring(get_parent(), global_position, Color(0.8, 0.55, 0.3, 0.8), 3.0, 0.5)
	Audio.play(&"quake", -4.0)
	crashed.emit()


func _end_charge() -> void:
	_line.visible = false
	_phase = Phase.NONE
	state = State.CHASE
	_cooldown = 0.9
	_charge_timer = float(_type["charge_interval"])
	_open_time = float(_type.get("open_time", 1.2))


func _place_line(length: float) -> void:
	_line.global_position = global_position + _charge_direction * length * 0.5 + Vector3(0.0, 0.08, 0.0)
	_line.look_at(global_position + _charge_direction * length + Vector3(0.0, 0.08, 0.0), Vector3.UP)
	_line.scale = Vector3(1.0, 1.0, length)


func _on_fall() -> void:
	_line.visible = false
	_phase = Phase.NONE
