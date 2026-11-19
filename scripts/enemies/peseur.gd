class_name PeseurEnemy
extends Enemy
## Le Peseur, boss de la Balance.
##
## Sa balance compare les morts debout et les corps au sol (sans repos) :
##   - plus de morts debout que de corps (de 2 ou plus) : il est protégé,
##     il ne subit qu'une part des coups ;
##   - plus de corps que de morts debout (de 2 ou plus) : ses poids tombent
##     plus vite ;
##   - à l'équilibre : il est vulnérable et ses poids tombent plus lentement.
## Abattre un mort debout en fait un corps ; donner le Repos à un corps le
## retire : le joueur règle la balance avec les deux gestes de tout le jeu.
##
## Ses poids : un disque rouge sur le sol annonce l'endroit, puis un poids de
## fonte s'abat. Il blesse celui qu'il écrase, sauf s'il esquive à ce moment.

enum Balance { EVEN, STANDING, LYING }

## La balance a changé de côté.
signal balance_changed(state: int)
## Un poids est annoncé à cet endroit.
signal weight_marked(at: Vector3)
## Un poids s'est abattu ; `hit` dit s'il a touché le héros.
signal weight_fell(at: Vector3, hit: bool)

var balance_state := Balance.EVEN

var _weights: Array[Dictionary] = []
var _weight_timer := 4.0
var _check_timer := 0.0


func setup(type_id: StringName, hero: Hero) -> void:
	super.setup(type_id, hero)
	add_to_group(&"boss")
	_weight_timer = float(_type["weight_interval"]) * 0.6


func _physics_process(delta: float) -> void:
	if is_standing():
		_check_timer -= delta
		if _check_timer <= 0.0:
			_check_timer = 0.25
			evaluate_balance()
		# Le minuteur des poids court tant qu'il se bat, qu'on le harcèle ou non.
		_weight_timer = maxf(0.0, _weight_timer - delta)
		if _weight_timer <= 0.0 and _hero != null and not _hero.is_dead():
			drop_weight_at(_hero.global_position + _hero.velocity * 0.35)
			_weight_timer = weight_interval()
	_update_weights(delta)
	super._physics_process(delta)


## Morts debout et corps au sol (les siens exclus).
func balance_counts() -> Vector2i:
	var standing := 0
	for node in get_tree().get_nodes_in_group(&"hittable"):
		var other := node as Enemy
		if other != null and other != self and other.is_standing():
			standing += 1
	var bodies := 0
	for node in get_tree().get_nodes_in_group(&"bodies"):
		if node != self:
			bodies += 1
	return Vector2i(standing, bodies)


## Recalcule le côté où penche la balance.
func evaluate_balance() -> int:
	var counts := balance_counts()
	var difference := counts.x - counts.y
	var next := Balance.EVEN
	if difference >= 2:
		next = Balance.STANDING
	elif difference <= -2:
		next = Balance.LYING
	if next != balance_state:
		balance_state = next
		balance_changed.emit(next)
	return balance_state


func weight_interval() -> float:
	var interval := float(_type["weight_interval"])
	match balance_state:
		Balance.LYING:
			return interval * 0.6
		Balance.EVEN:
			return interval * 1.5
	return interval


## Part des dégâts qu'il subit, selon la balance.
func damage_factor() -> float:
	match balance_state:
		Balance.STANDING:
			return float(_type["shield_factor"])
		Balance.EVEN:
			return float(_type["even_factor"])
	return 1.0


func take_hit(from: Vector3, damage: int) -> void:
	if state == State.DOWN or state == State.RISING or state == State.RESTED:
		return
	var scaled := maxi(1, int(round(float(damage) * damage_factor())))
	super.take_hit(from, scaled)


## Annonce un poids à cet endroit : un disque rouge, puis il s'abat.
func drop_weight_at(at: Vector3) -> void:
	var radius := float(_type["weight_radius"])
	var marker := Fx.disc(radius, Color(1.0, 0.25, 0.1, 0.1))
	marker.position = Vector3(at.x, 0.09, at.z)
	get_parent().add_child(marker)
	_weights.append({"at": Vector3(at.x, 0.0, at.z), "time": 0.0, "marker": marker})
	weight_marked.emit(at)


func _update_weights(delta: float) -> void:
	var windup := float(_type["weight_windup"])
	var done: Array[Dictionary] = []
	for weight in _weights:
		weight["time"] += delta
		var marker := weight["marker"] as MeshInstance3D
		if is_instance_valid(marker):
			(marker.material_override as StandardMaterial3D).albedo_color.a = 0.1 + 0.4 * clampf(weight["time"] / windup, 0.0, 1.0)
		if weight["time"] >= windup:
			done.append(weight)
	for weight in done:
		_weights.erase(weight)
		_land(weight)


func _land(weight: Dictionary) -> void:
	var at: Vector3 = weight["at"]
	var marker := weight["marker"] as MeshInstance3D
	if is_instance_valid(marker):
		marker.queue_free()
	Audio.play(&"quake", -2.0)
	Fx.ring(get_parent(), at, Color(0.8, 0.5, 0.25, 0.8), float(_type["weight_radius"]) + 0.6, 0.5)
	var hit := false
	if _hero != null and not _hero.is_dead() and not _hero.is_dodging():
		var offset := _hero.global_position - at
		offset.y = 0.0
		if offset.length() <= float(_type["weight_radius"]):
			hit = true
			_hero.take_damage(int(_type["weight_damage"]), at)
	weight_fell.emit(at, hit)


func _on_fall() -> void:
	for weight in _weights:
		var marker := weight["marker"] as MeshInstance3D
		if is_instance_valid(marker):
			marker.queue_free()
	_weights.clear()


## Une balance à main : un manche, un fléau et deux petits plateaux.
func _build_prop(kind: String) -> Node3D:
	if kind != "scales":
		return null
	var scales := Node3D.new()
	var metal := Fx.flat(Color(0.5, 0.36, 0.16), 0.7, 0.45)
	var staff := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.radial_segments = 8
	rod.top_radius = 0.04
	rod.bottom_radius = 0.05
	rod.height = 1.3
	staff.mesh = rod
	staff.material_override = metal
	staff.position.y = 0.5
	scales.add_child(staff)
	var beam := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.9, 0.06, 0.06)
	beam.mesh = bar
	beam.material_override = metal
	beam.position.y = 1.15
	scales.add_child(beam)
	for side: float in [-1.0, 1.0]:
		var pan := MeshInstance3D.new()
		var dish := CylinderMesh.new()
		dish.radial_segments = 12
		dish.top_radius = 0.22
		dish.bottom_radius = 0.18
		dish.height = 0.05
		pan.mesh = dish
		pan.material_override = metal
		pan.position = Vector3(side * 0.45, 0.8, 0.0)
		scales.add_child(pan)
		var chain := MeshInstance3D.new()
		var cord := CylinderMesh.new()
		cord.radial_segments = 4
		cord.top_radius = 0.01
		cord.bottom_radius = 0.01
		cord.height = 0.35
		chain.mesh = cord
		chain.material_override = metal
		chain.position = Vector3(side * 0.45, 0.98, 0.0)
		scales.add_child(chain)
	return scales
