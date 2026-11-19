class_name HeroRites
extends RefCounted
## L'exécution des rites de combat par le héros (état CAST) : le geste, le
## moment où il porte, son effet. Les valeurs viennent de `RiteData`, les
## animations de `HeroClasses` (`rite_animations`).

var hero: Hero
var id: StringName = &""
var _data: Dictionary
var _anim: Dictionary
var _time := 0.0
var _length := 0.0
var _impact := 0.0
var _fired := false
var _tick := 0.0
var _hits := 0
var _direction := Vector3.FORWARD
var _target: Enemy
var _touched := {}
var _start := Vector3.ZERO
var _landing := Vector3.ZERO
## Les morts que le héros traverse pendant la ruée ou le bond.
var _passing: Array[Node] = []


func _init(owner: Hero) -> void:
	hero = owner


## Pourquoi le rite ne peut pas partir maintenant (« » s'il le peut).
func check(rite_id: StringName) -> String:
	var data := RiteData.get_rite(rite_id)
	match rite_id:
		&"requiem", &"litanie":
			if _nearest_enemy(float(data["range"]) + 0.6) == null:
				return "Aucun mort à portée."
		&"rappel":
			if hero.last_rest_time < 0.0 or hero.clock - hero.last_rest_time > float(data["memory"]):
				return "Donne d'abord le Repos à un mort."
	return ""


func start(rite_id: StringName) -> void:
	id = rite_id
	_data = RiteData.get_rite(rite_id)
	_anim = (hero.class_data().get("rite_animations", {}) as Dictionary).get(rite_id, {})
	_time = 0.0
	_fired = false
	_tick = 0.0
	_hits = 0
	_touched.clear()
	_start = hero.global_position
	var wish := hero.wish()
	_direction = wish.normalized() if wish.length() > 0.1 else hero.facing()
	var speed := float(_anim.get("speed", 1.0))
	var length := hero.play_once(String(_anim.get("animation", "")), speed)
	_length = length / speed if length > 0.0 else 0.8
	_impact = _length * float(_anim.get("impact", 0.45))
	match id:
		&"linceul":
			hero.play_loop(String(_anim.get("animation", "")), speed)
			_length = float(_data["duration"])
		&"cortege":
			var target := _nearest_enemy(9.0)
			if wish.length() <= 0.1 and target != null:
				_direction = _flat(target.global_position - hero.global_position).normalized()
			_length = float(_data["time"]) + 0.15
			Audio.play(&"dodge")
		&"tombee":
			_landing = _cluster_point()
			_direction = _flat(_landing - _start).normalized() if _flat(_landing - _start).length() > 0.1 else _direction
			_length = float(_data["air_time"]) + 0.25
			Audio.play(&"dodge")
		&"requiem", &"litanie":
			_target = _nearest_enemy(float(_data["range"]) + 0.6)
			if _target != null:
				_direction = _flat(_target.global_position - hero.global_position).normalized()
			if id == &"litanie":
				_length = float(_data["interval"]) * float(_data["hits"]) + 0.25
		&"absoute":
			var target := _nearest_enemy(float(_data["range"]))
			if wish.length() <= 0.1 and target != null:
				_direction = _flat(target.global_position - hero.global_position).normalized()
	hero.face(_direction)
	Audio.play(&"swing_heavy")
	# La ruée et le bond passent à travers les morts (les murs arrêtent
	# toujours le héros).
	if id == &"cortege" or id == &"tombee":
		for node in hero.get_tree().get_nodes_in_group(&"hittable"):
			if node is PhysicsBody3D:
				hero.add_collision_exception_with(node)
				_passing.append(node)


## Vrai pendant les instants où le héros ne peut pas être touché (ruée, bond).
func untouchable() -> bool:
	match id:
		&"cortege":
			return _time < float(_data["time"])
		&"tombee":
			return _time < float(_data["air_time"])
	return false


## Fait avancer le rite ; renvoie vrai quand il est fini.
func update(delta: float) -> bool:
	_time += delta
	hero.velocity = Vector3.ZERO
	match id:
		&"glas":
			if not _fired and _time >= _impact:
				_fired = true
				_shockwave(float(_data["radius"]), int(_data["boss_damage"]), Color(1.0, 0.54, 0.35, 0.9))
		&"linceul":
			hero.velocity = hero.wish() * float(_data["move_speed"])
			_tick -= delta
			if _tick <= 0.0:
				_tick = float(_data["tick"])
				if _strike_around(float(_data["radius"]), _damage(int(_data["damage"]))) > 0:
					hero.hit_landed.emit(false)
				Audio.play(&"swing_light")
		&"cortege":
			var dash_time := float(_data["time"])
			if _time < dash_time:
				hero.velocity = _direction * float(_data["distance"]) / dash_time
				for enemy in _enemies_within(float(_data["width"])):
					if not _touched.has(enemy):
						_touched[enemy] = true
						enemy.take_hit(hero.global_position, _damage(int(_data["damage"])))
						hero.hit_landed.emit(false)
		&"tombee":
			var air := float(_data["air_time"])
			if _time < air:
				var span := _flat(_landing - _start)
				hero.velocity = span / air
				hero.lift(sin(_time / air * PI) * 1.6)
			elif not _fired:
				_fired = true
				hero.lift(0.0)
				_shockwave(float(_data["radius"]), int(_data["boss_damage"]), Color(1.0, 0.54, 0.35, 0.9))
		&"requiem":
			if not _fired and _time >= _impact:
				_fired = true
				if is_instance_valid(_target) and _target.is_standing():
					_target.take_hit(hero.global_position, _damage(int(_data["damage"])))
					if _target.is_standing():
						_target.rend(float(_data["rend_time"]))
					Fx.ring(hero.get_parent(), _target.global_position, Color(0.91, 0.69, 0.38, 0.95), 1.6, 0.4)
					hero.hit_landed.emit(true)
					Audio.play(&"clang")
		&"litanie":
			var interval := float(_data["interval"])
			var due := mini(int(_time / interval), int(_data["hits"]))
			while _hits < due:
				_hits += 1
				if not is_instance_valid(_target) or not _target.is_standing():
					break
				if _hits % 2 == 0:
					hero.play_once(String(_anim.get("alternate", _anim.get("animation", ""))), float(_anim.get("speed", 1.0)))
				else:
					hero.play_once(String(_anim.get("animation", "")), float(_anim.get("speed", 1.0)))
				if _hits < int(_data["hits"]):
					_target.take_hit(hero.global_position, _damage(int(_data["damage"])))
					hero.hit_landed.emit(false)
				else:
					_target.knock_down(hero.global_position, _damage(int(_data["boss_damage"])))
					hero.hit_landed.emit(true)
				Audio.play(&"hit_flesh")
		&"cierge":
			if not _fired and _time >= _impact:
				_fired = true
				var candle := RiteCandle.new()
				candle.radius = float(_data["radius"])
				candle.slow = float(_data["slow"])
				candle.duration = float(_data["duration"])
				hero.get_parent().add_child(candle)
				candle.global_position = hero.global_position + hero.facing() * 0.6
				Audio.play(&"rest_done")
		&"absoute":
			if not _fired and _time >= _impact:
				_fired = true
				var blade := RiteBlade.new()
				blade.direction = _direction
				blade.speed = float(_data["speed"])
				blade.reach = float(_data["range"])
				blade.width = float(_data["width"])
				blade.damage = _damage(int(_data["damage"]))
				hero.get_parent().add_child(blade)
				blade.global_position = hero.global_position + _direction * 0.8
				Audio.play(&"swing_heavy")
		&"rappel":
			if not _fired and _time >= _impact:
				_fired = true
				var ally := RiteAlly.new()
				ally.duration = float(_data["duration"])
				ally.damage = _damage(int(_data["damage"]))
				ally.interval = float(_data["interval"])
				ally.speed = float(_data["speed"])
				hero.get_parent().add_child(ally)
				ally.global_position = hero.last_rest_position
				hero.last_rest_time = -1.0
				Audio.play(&"enemy_rise")
	if _time >= _length:
		finish()
		return true
	return false


## Fin du rite (ou interruption) : le héros reprend pied et redevient solide.
func finish() -> void:
	hero.lift(0.0)
	for node in _passing:
		if is_instance_valid(node):
			hero.remove_collision_exception_with(node)
	_passing.clear()


# --- Outils -------------------------------------------------------------------

func _damage(base: int) -> int:
	return int(round(float(base) * hero.damage_scale))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Les morts debout à moins de `radius` du héros.
func _enemies_within(radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in hero.get_tree().get_nodes_in_group(&"hittable"):
		var enemy := node as Enemy
		if enemy != null and enemy.is_standing() and _flat(enemy.global_position - hero.global_position).length() <= radius:
			found.append(enemy)
	return found


func _nearest_enemy(radius: float) -> Enemy:
	var best: Enemy = null
	var best_distance := radius
	for enemy in _enemies_within(radius):
		var distance := _flat(enemy.global_position - hero.global_position).length()
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best


## Frappe tout ce qui peut l'être autour du héros ; renvoie le nombre touché.
func _strike_around(radius: float, damage: int) -> int:
	var count := 0
	for node in hero.get_tree().get_nodes_in_group(&"hittable"):
		var target := node as Node3D
		if target == null or not target.has_method(&"take_hit"):
			continue
		if _flat(target.global_position - hero.global_position).length() <= radius:
			target.call(&"take_hit", hero.global_position, damage)
			count += 1
	return count


## L'onde du Glas et de la Tombée : renverse les morts autour du héros.
func _shockwave(radius: float, boss_damage: int, color: Color) -> void:
	Fx.ring(hero.get_parent(), hero.global_position, color, radius, 0.5, true)
	Audio.play(&"quake")
	for enemy in _enemies_within(radius):
		enemy.knock_down(hero.global_position, _damage(boss_damage))
	hero.hit_landed.emit(true)


## Le point de chute de la Tombée : là où les morts sont le plus serrés, à
## portée de bond ; à défaut, droit devant.
func _cluster_point() -> Vector3:
	var reach := float(_data["reach"])
	var radius := float(_data["radius"])
	var best := hero.global_position + _direction * minf(reach, 5.0)
	var best_count := 0
	var candidates := _enemies_within(reach)
	for enemy in candidates:
		var count := 0
		for other in candidates:
			if _flat(other.global_position - enemy.global_position).length() <= radius:
				count += 1
		if count > best_count:
			best_count = count
			best = enemy.global_position
	return Vector3(best.x, hero.global_position.y, best.z)
