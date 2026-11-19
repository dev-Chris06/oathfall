class_name MapLife
extends Node3D
## Ce qui vit sur la carte et raconte la progression sans un mot.
##
## Chaque voie de la route est le quartier d'un chapitre. Un quartier est
## « perdu » tant qu'aucun de ses niveaux n'est atteint : une brume noire le
## couvre, ses fenêtres sont éteintes, des morts y errent et des corbeaux
## tournent au-dessus. « Atteint », la brume se retire et quelques fenêtres se
## rallument ; « apaisé » (les cinq niveaux faits), toutes.
##
## La première fois qu'un quartier sort de la brume, le joueur le voit se
## dégager (`Progress.mark_seen`) ; ensuite, il est clair d'emblée.

const PERDU := "perdu"
const ATTEINT := "atteint"
const APAISE := "apaise"
## Lumière des fenêtres selon l'état du quartier.
const LIGHT := {PERDU: 0.0, ATTEINT: 0.55, APAISE: 1.0}
## Durée du retrait de la brume, en secondes.
const REVEAL_TIME := 3.5
const WANDERERS := 6
const CROWS := 14

const FOG_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D noise : filter_linear, repeat_enable;
uniform float density = 1.0;
uniform vec2 drift = vec2(0.012, 0.004);
uniform vec3 tint = vec3(0.02, 0.025, 0.05);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float a = texture(noise, world_pos.xz * 0.05 + TIME * drift).r;
	float b = texture(noise, world_pos.xz * 0.11 - TIME * drift * 1.7).r;
	float cloud = smoothstep(0.25, 0.75, a * 0.65 + b * 0.45);
	// Les bords s'effilochent.
	vec2 edge = min(UV, 1.0 - UV);
	float fade = smoothstep(0.0, 0.18, edge.x) * smoothstep(0.0, 0.3, edge.y);
	ALBEDO = tint + vec3(0.05, 0.06, 0.1) * b;
	ALPHA = clamp(cloud * fade * density * 0.92, 0.0, 1.0);
}
"""

const CROW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;

void vertex() {
	float phase = INSTANCE_CUSTOM.r * 6.2831;
	VERTEX.y += sin(TIME * 9.0 + phase) * abs(VERTEX.x) * 0.9;
}

void fragment() {
	ALBEDO = vec3(0.01, 0.01, 0.02);
}
"""

## Pour chaque voie de la route, dans l'ordre : [ordonnée, étage].
var lanes: Array = []
var states: Array[String] = []
var _fog: Array = []
var _density: Array[float] = []
var _target: Array[float] = []
var _city: MapCity
var _crows: MultiMesh
var _crow_flocks: Array = []
var _wanderers: Array = []
var _time := 0.0


func _init() -> void:
	name = "MapLife"
	for i in MapScene.TERRACES.size():
		for lane_y: float in (MapScene.TERRACES[i] as Dictionary)["lanes"]:
			lanes.append([lane_y, i])


## Le quartier (indice de voie) d'un point d'un étage.
static func zone_of(tier: int, p: Vector2) -> int:
	var first := 0
	for i in tier:
		first += ((MapScene.TERRACES[i] as Dictionary)["lanes"] as Array).size()
	var tier_lanes: Array = (MapScene.TERRACES[tier] as Dictionary)["lanes"]
	# Une maison appartient à la première voie au sud d'elle (on la voit
	# derrière cette voie) ; au-delà de la dernière, à la dernière.
	var best := -1
	for j in tier_lanes.size():
		if float(tier_lanes[j]) >= p.y - 1.0:
			best = j
	return first + maxi(best, 0)


## Le chapitre que raconte un quartier.
static func chapter_of_zone(zone: int) -> int:
	return mini(zone, WorldData.ROUTE_CHAPTERS - 1)


func build(city: MapCity) -> void:
	_city = city
	_build_fog()
	_build_crows()
	_build_wanderers()


# --- La brume -----------------------------------------------------------------

func _build_fog() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	var shader := Shader.new()
	shader.code = FOG_SHADER
	for k in lanes.size():
		var rect := zone_rect(k)
		var tier: int = lanes[k][1]
		var layers: Array = []
		for layer in 2:
			var plane := PlaneMesh.new()
			plane.size = Vector2(rect.size.x * MapWorld.S, rect.size.y * MapWorld.S)
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("noise", texture)
			material.set_shader_parameter("drift", Vector2(0.012, 0.004) * (1.0 if layer == 0 else -0.8))
			# Le calque du dessous est plus sombre, celui du dessus plus pâle.
			if layer == 1:
				material.set_shader_parameter("tint", Vector3(0.05, 0.06, 0.1))
			var node := MeshInstance3D.new()
			node.mesh = plane
			node.material_override = material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var center := MapWorld.to_world(rect.get_center())
			node.position = Vector3(center.x, float(MapWorld.HEIGHTS[tier]) + 0.8 + layer * 1.1, center.z)
			add_child(node)
			layers.append(node)
		_fog.append(layers)
		_density.append(1.0)
		_target.append(1.0)


## L'étendue d'un quartier, dans le plan : la largeur de son étage, de la
## voie au sud jusqu'à la voie suivante au nord.
func zone_rect(k: int) -> Rect2:
	var lane_y: float = lanes[k][0]
	var tier: int = lanes[k][1]
	var terrace: Dictionary = MapScene.TERRACES[tier]
	var tier_lanes: Array = terrace["lanes"]
	var index := tier_lanes.find(lane_y)
	var south := float(terrace["y0"]) if index == 0 else lane_y + 40.0
	var north := lane_y - 150.0
	if index == tier_lanes.size() - 1:
		north = float((MapScene.TERRACES[tier + 1] as Dictionary)["y0"]) if tier + 1 < MapScene.TERRACES.size() else float(terrace["y1"]) - 40.0
	var x0 := float(terrace["x0"]) - 30.0
	var x1 := float(terrace["x1"]) + 30.0
	return Rect2(x0, north, x1 - x0, south - north)


## L'état de chaque quartier. `animate` : un quartier qui quitte la brume pour
## la première fois se dégage lentement sous les yeux du joueur.
func set_states(new_states: Array[String], animate := true) -> void:
	states = new_states
	for k in lanes.size():
		var state: String = states[k] if k < states.size() else PERDU
		var lost := state == PERDU
		_target[k] = 1.0 if lost else 0.0
		var key := StringName("brume_%d" % k)
		if lost:
			_density[k] = 1.0
		elif not animate or Progress.has_seen(key):
			_density[k] = 0.0
		elif _density[k] > 0.0 and not Progress.has_seen(key):
			Progress.mark_seen(key)
		_apply_fog(k)
		if _city != null:
			_city.set_district_light(k, float(LIGHT[state]) * (1.0 - _density[k]))
	_place_wanderers()
	_place_crows()


func is_revealing() -> bool:
	for k in lanes.size():
		if _density[k] > _target[k] + 0.001:
			return true
	return false


func fog_density(k: int) -> float:
	return _density[k]


func _apply_fog(k: int) -> void:
	for node: MeshInstance3D in _fog[k]:
		node.visible = _density[k] > 0.01
		(node.material_override as ShaderMaterial).set_shader_parameter("density", _density[k])


# --- Les corbeaux -------------------------------------------------------------

## Un corbeau : un corps et deux ailes, tourné vers +Z. Le matériau bat des
## ailes.
static func crow_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [Vector3(0.0, 0.0, 0.22), Vector3(-0.05, 0.0, -0.16), Vector3(0.05, 0.0, -0.16),
			Vector3(0.0, 0.0, 0.06), Vector3(-0.32, 0.03, -0.04), Vector3(-0.02, 0.0, -0.08),
			Vector3(0.0, 0.0, 0.06), Vector3(0.02, 0.0, -0.08), Vector3(0.32, 0.03, -0.04)]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(v)
	return surface.commit()


static func crow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = CROW_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _build_crows() -> void:
	var material := crow_material()
	_crows = MultiMesh.new()
	_crows.transform_format = MultiMesh.TRANSFORM_3D
	_crows.use_custom_data = true
	_crows.mesh = crow_mesh()
	_crows.instance_count = CROWS
	_crows.visible_instance_count = 0
	for i in CROWS:
		_crows.set_instance_custom_data(i, Color(randf(), 0.0, 0.0, 0.0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = _crows
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Les corbeaux bougent partout : une boîte assez grande pour ne jamais
	# disparaître du champ.
	node.custom_aabb = AABB(Vector3(-50.0, -10.0, -70.0), Vector3(100.0, 40.0, 140.0))
	add_child(node)


## Deux volées tournent au-dessus des deux premiers quartiers perdus.
func _place_crows() -> void:
	_crow_flocks.clear()
	for k in lanes.size():
		if states.size() > k and states[k] == PERDU and _crow_flocks.size() < 2:
			var rect := zone_rect(k)
			var center := MapWorld.to_world(rect.get_center())
			_crow_flocks.append(Vector3(center.x + (-6.0 if _crow_flocks.is_empty() else 7.0), float(MapWorld.HEIGHTS[lanes[k][1]]) + 4.5, center.z))
	_crows.visible_instance_count = 0 if _crow_flocks.is_empty() else CROWS


func _update_crows() -> void:
	if _crow_flocks.is_empty():
		return
	for i in CROWS:
		var flock: Vector3 = _crow_flocks[i % _crow_flocks.size()]
		var radius := 2.2 + float(i % 4) * 0.7
		var speed := 0.35 + float(i % 5) * 0.05
		var angle := _time * speed + float(i) * 1.7
		var at := flock + Vector3(cos(angle) * radius, sin(_time * 0.6 + i) * 0.4 + float(i % 3) * 0.3, sin(angle) * radius * 0.6)
		var ahead := Vector3(-sin(angle) * radius, 0.0, cos(angle) * radius * 0.6)
		var basis := Basis.looking_at(-ahead.normalized(), Vector3.UP) * Basis.from_scale(Vector3.ONE * 1.1)
		_crows.set_instance_transform(i, Transform3D(basis, at))


# --- Les morts errants --------------------------------------------------------

func _build_wanderers() -> void:
	var scene := load("res://assets/kaykit/skeletons/Skeleton_Minion.glb") as PackedScene
	for i in WANDERERS:
		var body := scene.instantiate() as Node3D
		body.scale = Vector3.ONE * 0.62
		body.visible = false
		add_child(body)
		var player := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null and player.has_animation(&"Walking_D_Skeletons"):
			player.get_animation(&"Walking_D_Skeletons").loop_mode = Animation.LOOP_LINEAR
			player.play(&"Walking_D_Skeletons", -1.0, 0.55)
			player.seek(randf() * 1.5, true)
		_wanderers.append({"node": body, "from": Vector3.ZERO, "to": Vector3.ZERO, "t": randf(), "speed": 0.0})


## Les morts errent le long des voies des premiers quartiers perdus.
func _place_wanderers() -> void:
	var lost: Array[int] = []
	for k in lanes.size():
		if states.size() > k and states[k] == PERDU and lost.size() < 3:
			lost.append(k)
	for i in _wanderers.size():
		var w: Dictionary = _wanderers[i]
		var node := w["node"] as Node3D
		node.visible = not lost.is_empty()
		if lost.is_empty():
			continue
		var k: int = lost[i % lost.size()]
		var terrace: Dictionary = MapScene.TERRACES[lanes[k][1]]
		var lane_y := float(lanes[k][0]) + (14.0 if i % 2 == 0 else -14.0)
		var x0 := float(terrace["x0"]) + 80.0
		var x1 := float(terrace["x1"]) - 80.0
		var a := lerpf(x0, x1, fmod(float(i) * 0.37 + 0.1, 1.0))
		var b := clampf(a + (160.0 if i % 2 == 0 else -160.0), x0, x1)
		w["from"] = MapWorld.to_world(Vector2(a, lane_y))
		w["to"] = MapWorld.to_world(Vector2(b, lane_y))
		w["speed"] = 0.25 / maxf((w["from"] as Vector3).distance_to(w["to"]), 0.5)


func _update_wanderers(delta: float) -> void:
	for w: Dictionary in _wanderers:
		var node := w["node"] as Node3D
		if not node.visible:
			continue
		w["t"] = float(w["t"]) + delta * float(w["speed"])
		# Aller et retour, le long de la voie.
		var phase := fmod(float(w["t"]), 2.0)
		var forward := phase < 1.0
		var u := phase if forward else 2.0 - phase
		var from: Vector3 = w["from"]
		var to: Vector3 = w["to"]
		node.position = from.lerp(to, u)
		var direction := (to - from) * (1.0 if forward else -1.0)
		node.rotation.y = atan2(direction.x, direction.z)


func _process(delta: float) -> void:
	_time += delta
	_update_crows()
	_update_wanderers(delta)
	for k in _density.size():
		if _density[k] > _target[k]:
			_density[k] = maxf(_target[k], _density[k] - delta / REVEAL_TIME)
			_apply_fog(k)
			if _city != null and states.size() > k:
				_city.set_district_light(k, float(LIGHT[states[k]]) * (1.0 - _density[k]))
