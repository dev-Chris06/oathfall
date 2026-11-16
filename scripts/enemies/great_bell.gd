class_name GreatBell
extends Node3D
## La grosse cloche de la Chapelle des cendres, suspendue à sa poutre, et les
## trois cordes qui la retiennent. Elle oscille quand le Sonneur se prépare,
## sonne, et tombe quand les trois cordes sont coupées.

## Une corde vient d'être coupée ; `remaining` en reste combien.
signal rope_cut(remaining: int)
## La cloche s'est écrasée au sol.
signal fell

const BRONZE := Color(0.55, 0.38, 0.16)
const HANG_HEIGHT := 5.0

var ropes: Array[BellRope] = []
var is_fallen := false

var _bell: Node3D
var _flash: OmniLight3D
var _amount := 0.0
var _target := 0.0
var _time := 0.0


func _ready() -> void:
	# La poutre et les chaînes.
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(18.0, 0.55, 0.6)
	beam.mesh = box
	beam.material_override = Fx.flat(Color(0.2, 0.13, 0.08))
	beam.position = Vector3(0.0, 7.4, 0.0)
	add_child(beam)
	for dx in [-0.5, 0.5]:
		var chain := MeshInstance3D.new()
		var link := CylinderMesh.new()
		link.top_radius = 0.05
		link.bottom_radius = 0.05
		link.height = 1.3
		chain.mesh = link
		chain.material_override = Fx.flat(Color(0.12, 0.11, 0.1), 0.6, 0.5)
		chain.position = Vector3(dx, 6.75, 0.0)
		add_child(chain)

	# La cloche : un corps évasé, un couronnement, un battant.
	_bell = Node3D.new()
	_bell.position = Vector3(0.0, 6.2, 0.0)
	add_child(_bell)
	var body := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.45
	cone.bottom_radius = 1.45
	cone.height = 2.2
	cone.radial_segments = 20
	body.mesh = cone
	body.material_override = Fx.flat(BRONZE, 0.7, 0.45)
	body.position.y = -1.2
	_bell.add_child(body)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.38
	ring.outer_radius = 1.55
	rim.mesh = ring
	rim.material_override = body.material_override
	rim.position.y = -2.3
	_bell.add_child(rim)
	var clapper := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.22
	ball.height = 0.44
	clapper.mesh = ball
	clapper.material_override = Fx.flat(Color(0.14, 0.12, 0.11), 0.5, 0.6)
	clapper.position.y = -2.1
	_bell.add_child(clapper)

	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.75, 0.4)
	_flash.light_energy = 0.0
	_flash.omni_range = 14.0
	_flash.position = Vector3(0.0, 4.5, 0.0)
	add_child(_flash)

	# Trois cordes, du pied de la cloche vers le sol.
	var anchors := [Vector3(-4.6, 0.0, 2.4), Vector3(4.6, 0.0, 2.4), Vector3(0.0, 0.0, -5.0)]
	for anchor: Vector3 in anchors:
		var rope := BellRope.new()
		rope.position = anchor
		add_child(rope)
		rope.setup(to_global(Vector3(anchor.x * 0.12, 5.2, anchor.z * 0.12)))
		rope.cut.connect(_on_rope_cut)
		ropes.append(rope)


func _process(delta: float) -> void:
	_time += delta
	_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 6.0)
	if is_fallen:
		return
	_amount = move_toward(_amount, _target, delta * 1.6)
	_bell.rotation.z = sin(_time * 7.0) * 0.3 * _amount


## La cloche se balance de plus en plus, à mesure que le coup approche.
## `progress` va de 0 à 1.
func build_up(progress: float) -> void:
	_target = clampf(progress, 0.0, 1.0)
	_amount = maxf(_amount, _target)


## Le coup : un éclair, une oscillation ample qui retombe.
func ring() -> void:
	_amount = 1.0
	_target = 0.0
	_flash.light_energy = 7.0


func ropes_cut() -> int:
	var count := 0
	for rope in ropes:
		if rope.is_cut:
			count += 1
	return count


func _on_rope_cut(_rope: BellRope) -> void:
	var remaining := ropes.size() - ropes_cut()
	rope_cut.emit(remaining)
	if remaining == 0:
		_fall()


func _fall() -> void:
	is_fallen = true
	_bell.rotation.z = 0.0
	var tween := create_tween()
	# Elle s'enfonce à moitié dans les dalles : tombée tout entière, elle
	# cacherait la moitié de l'écran.
	tween.tween_property(_bell, "position:y", 1.5, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		_flash.light_energy = 9.0
		Fx.ring(get_parent(), global_position, Color(0.85, 0.62, 0.3, 0.7), 12.0, 0.9)
		fell.emit())
