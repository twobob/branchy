extends Node
class_name MeshSlicer

func slice_mesh(slice_transform: Transform3D, mesh: Mesh, cross_section_material: Material = null) -> Array[ArrayMesh]:
	if not is_inside_tree():
		push_error("MeshSlicer must be in scene tree")
		return [ArrayMesh.new(), ArrayMesh.new()]

	var combiner = CSGCombiner3D.new()
	var obj_csg = CSGMesh3D.new()
	obj_csg.mesh = mesh
	var slicer_csg = CSGMesh3D.new()
	slicer_csg.mesh = BoxMesh.new()
	if cross_section_material:
		slicer_csg.mesh.material = cross_section_material

	add_child(combiner)
	combiner.add_child(obj_csg)
	combiner.add_child(slicer_csg)
	slicer_csg.transform = slice_transform

	var max_at = Vector3(-INF, -INF, -INF)
	var min_at = Vector3(INF, INF, INF)
	for v in mesh.get_faces():
		var lv = slicer_csg.to_local(v)
		max_at = max_at.max(lv)
		min_at = min_at.min(lv)
	min_at.z = 0.0
	slicer_csg.position = slicer_csg.to_global((max_at + min_at) / 2.0)
	slicer_csg.mesh.size = (max_at - min_at)

	var out_mesh: Mesh
	var out_mesh2: Mesh

	slicer_csg.operation = CSGShape3D.OPERATION_SUBTRACTION
	combiner._update_shape()
	var meshes = combiner.get_meshes()
	if meshes:
		out_mesh = meshes[1]

	slicer_csg.operation = CSGShape3D.OPERATION_INTERSECTION
	combiner._update_shape()
	meshes = combiner.get_meshes()
	if meshes:
		out_mesh2 = meshes[1]

	combiner.queue_free()
	return [out_mesh, out_mesh2]
