class_name Fx
extends RefCounted
## Effets visuels simples, partagés par les morts et les niveaux.


## Une onde qui s'élargit au sol puis s'efface : coup de cloche, cri.
## Avec `linear`, l'onde s'élargit à vitesse constante : c'est le cas de celles
## qui blessent, dont le front doit correspondre à ce que voit le joueur.
static func ring(parent: Node, at: Vector3, color: Color, radius: float, duration := 0.9, linear := false) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	var mesh := MeshInstance3D.new()
	mesh.mesh = torus
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = at + Vector3(0.0, 0.15, 0.0)
	mesh.scale = Vector3(0.05, 1.0, 0.05) if linear else Vector3(0.5, 1.0, 0.5)
	var tween := mesh.create_tween()
	tween.set_parallel(true)
	var growth := tween.tween_property(mesh, "scale", Vector3(radius, 1.0, radius), duration)
	if linear:
		growth.set_trans(Tween.TRANS_LINEAR)
	else:
		growth.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh.queue_free)


## Matériau simple, sans texture.
static func flat(color: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


## Matériau lumineux et transparent (visées, lueurs).
static func glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Un secteur plat posé au sol, ouvert vers +Z : l'avertissement d'un coup qui
## balaie. À orienter avec `rotation.y = atan2(direction.x, direction.z)`.
static func sector(radius: float, angle_deg: float, color: Color) -> MeshInstance3D:
	var steps := 20
	var vertices := PackedVector3Array([Vector3.ZERO])
	for i in steps + 1:
		var a := deg_to_rad(-angle_deg / 2.0 + angle_deg * float(i) / float(steps))
		vertices.append(Vector3(sin(a), 0.0, cos(a)) * radius)
	var indices := PackedInt32Array()
	for i in steps:
		indices.append_array([0, i + 1, i + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = glow(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position.y = 0.09
	return node


## Un disque plat posé au sol : une zone qui va être frappée.
static func disc(radius: float, color: Color) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.radial_segments = 12
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.02
	cylinder.radial_segments = 36
	cylinder.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = cylinder
	node.material_override = glow(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position.y = 0.09
	return node
