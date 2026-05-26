extends Node3D
class_name TreeGenerator3D

signal branch_pruned(branch_index: int)

@export var axiom: String = "X"
@export var rule_X: String = "F[+X][-X]FX"
@export var rule_F: String = "FF"
@export var iterations: int = 5

@export var segment_length: float = 0.25
@export var angle_deg: float = 22.0
@export var branch_thickness: float = 0.35
@export var thickness_taper: float = 0.03

@export var base_branch_offset: float = 0.35
@export var vertical_falloff: float = 1.2
@export var branch_length_scale: float = 0.85

@export_enum("Capsule", "Sphere") var collision_shape_type: int = 0
@export var enable_self_collision: bool = false
@export var capsule_wind_multiplier: float = 1.5
@export var stiffness: float = 80.0
@export var damping: float = 12.0

@export var wind_strength: float = 1.5
@export var wind_scale: float = 0.3
@export var wind_speed: float = 0.4

@export var seed: int = 1
@export var dead_branch_ratio: float = 0.2

var rng := RandomNumberGenerator.new()
var branches: Array = []
var debug_meshes: Array = []
var show_debug: bool = false
var time_accum := 0.0

var tree_material: StandardMaterial3D
var debug_material: StandardMaterial3D
var diseased_materials: Array[StandardMaterial3D] = []
var wind_noise: FastNoiseLite

func expand() -> String:
	var s := axiom
	for i in range(iterations):
		var next := ""
		for c in s:
			if c == "X":
				next += rule_X
			elif c == "F":
				next += rule_F
			else:
				next += c
		s = next
	return s

func validate_rule(rule: String) -> String:
	var valid_chars = "FX+-[]"
	var bracket_depth := 0
	for i in range(rule.length()):
		var c = rule[i]
		if valid_chars.find(c) == -1:
			return "Invalid char '%s' at pos %d" % [c, i]
		if c == "[":
			bracket_depth += 1
		elif c == "]":
			bracket_depth -= 1
			if bracket_depth < 0:
				return "Unmatched ']' at pos %d" % i
	if bracket_depth != 0:
		return "Unmatched '[' (%d unclosed)" % bracket_depth
	if rule.length() == 0:
		return "Rule cannot be empty"
	return ""

func randomize_rule_x() -> String:
	var max_attempts = 50
	for attempt in range(max_attempts):
		var candidate = _generate_random_rule()
		var count = estimate_branch_count(candidate)
		if count >= 30 and count <= 3000:
			return candidate
	return "F-[[X]+X]+F[+FX]-X"

func estimate_branch_count(rule: String) -> int:
	var s := axiom
	for i in range(iterations):
		var next := ""
		for c in s:
			if c == "X":
				next += rule
			elif c == "F":
				next += rule_F
			else:
				next += c
		s = next
		if s.length() > 100000:
			return 99999
	var count := 0
	for c in s:
		if c == "[":
			count += 1
	return count

func _generate_random_rule() -> String:
	var parts := []
	var num_segments = rng.randi_range(3, 7)
	for i in range(num_segments):
		var r = rng.randf()
		if r < 0.3:
			parts.append("F")
		elif r < 0.5:
			var sign = ["+", "-"][rng.randi_range(0, 1)]
			var inner = ""
			var inner_len = rng.randi_range(1, 3)
			for j in range(inner_len):
				inner += ["F", "X", sign][rng.randi_range(0, 2)]
			parts.append("[" + sign + inner + "]")
		elif r < 0.7:
			parts.append(["+", "-"][rng.randi_range(0, 1)])
		elif r < 0.85:
			parts.append("X")
		else:
			var sign1 = ["+", "-"][rng.randi_range(0, 1)]
			var sign2 = ["+", "-"][rng.randi_range(0, 1)]
			parts.append("[" + sign1 + "[X]" + sign2 + "X]")
	return "".join(parts)

func _ready():
	tree_material = StandardMaterial3D.new()
	tree_material.albedo_color = Color(0.2, 0.5, 0.2)
	tree_material.roughness = 0.9
	
	debug_material = StandardMaterial3D.new()
	debug_material.albedo_color = Color(0.0, 1.0, 1.0, 0.3)
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var colors = [
		Color(0.45, 0.25, 0.08),
		Color(0.85, 0.45, 0.1),
		Color(0.65, 0.1, 0.15)
	]
	for c in colors:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = c
		mat.roughness = 0.9
		diseased_materials.append(mat)
		
	wind_noise = FastNoiseLite.new()
	wind_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	wind_noise.frequency = 0.015
	
	call_deferred("regenerate_tree", seed)

func regenerate_tree(new_seed: int):
	seed = new_seed
	rng.seed = seed
	wind_noise.seed = seed
	
	var old_ch = get_children().duplicate()
	old_ch.reverse()
	for c in old_ch:
		remove_child(c)
		c.free()
	branches.clear()
	debug_meshes.clear()
	time_accum = 0.0
	
	generate_tree()

func generate_tree():
	var commands := expand()
	var stack := []

	var pos := Vector3.ZERO
	var dir := Vector3.UP

	var current_branch_root = Node3D.new()
	add_child(current_branch_root)
	
	var trunk_height := estimate_height(commands)
	var current_height := 0.0
	
	var branch_paths := []
	var path_thicknesses := []
	
	var current_path := [pos]
	var current_thicknesses := [branch_thickness]
	
	var current_branch_idx: int = -1
	
	for c in commands:
		match c:
			"F":
				var next_pos = pos + dir * segment_length
				current_height = pos.y / trunk_height
				
				var t = 1.0 - clamp(pos.y / trunk_height, 0.0, 1.0)
				var current_t = branch_thickness * t + thickness_taper
				
				current_path.append(next_pos)
				current_thicknesses.append(current_t)
				
				if should_spawn_branch(current_height):
					current_branch_idx = create_branch(pos, dir, current_height, true, current_branch_idx)
					
				pos = next_pos
				
			"+":
				dir = dir.rotated(Vector3.FORWARD, deg_to_rad(angle_deg))
				dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(30, 150)))
			"-":
				dir = dir.rotated(Vector3.FORWARD, deg_to_rad(-angle_deg))
				dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-150, -30)))
			"[":
				stack.append({
					"pos": pos,
					"dir": dir,
					"path": current_path.duplicate(),
					"thick": current_thicknesses.duplicate(),
					"parent_idx": current_branch_idx
				})
				current_path = [pos]
				current_thicknesses = [current_thicknesses.back()]
			"]":
				if current_path.size() > 1:
					branch_paths.append(current_path)
					path_thicknesses.append(current_thicknesses)
				
				var s = stack.pop_back()
				pos = s.pos
				dir = s.dir
				current_path = s.path
				current_thicknesses = s.thick
				current_branch_idx = s.parent_idx

	if current_path.size() > 1:
		branch_paths.append(current_path)
		path_thicknesses.append(current_thicknesses)
		
	# for i in range(branch_paths.size()):
	# 	create_static_branch(branch_paths[i], path_thicknesses[i])

func estimate_height(cmd: String) -> float:
	var max_y := 0.0
	var pos := Vector3.ZERO
	var dir := Vector3.UP
	var stack := []
	for c in cmd:
		match c:
			"F":
				pos += dir * segment_length
				if pos.y > max_y: max_y = pos.y
			"+":
				dir = dir.rotated(Vector3.FORWARD, deg_to_rad(angle_deg))
			"-":
				dir = dir.rotated(Vector3.FORWARD, deg_to_rad(-angle_deg))
			"[":
				stack.append([pos, dir])
			"]":
				var s = stack.pop_back()
				pos = s[0]
				dir = s[1]
	return max(max_y, 0.001)

func should_spawn_branch(h: float) -> bool:
	if branches.size() >= 80:
		return false
	if h < base_branch_offset:
		return false
	var falloff = pow(1.0 - clamp(h, 0.0, 0.99), vertical_falloff)
	return rng.randf() < clamp(falloff * 0.6, 0.1, 0.5)

func create_static_branch(path: Array, thicknesses: Array):
	var mesh_node = MeshInstance3D.new()
	add_child(mesh_node)
	mesh_node.material_override = tree_material
	mesh_node.mesh = generate_tube_array(path, thicknesses)

func create_branch(origin: Vector3, trunk_dir: Vector3, height_ratio: float, dynamic: bool, parent_index: int) -> int:
	var branch_idx = branches.size()
	
	var branch_root = Node3D.new()
	add_child(branch_root)
	branch_root.name = "BranchRoot_%d" % branch_idx
	branch_root.position = origin

	var angle = deg_to_rad(30 + rng.randf_range(-20, 20))
	var side = -1 if rng.randf() < 0.5 else 1
	var axis = trunk_dir.cross(Vector3.UP).normalized()
	if axis.length() < 0.01:
		axis = Vector3.RIGHT

	var dir = trunk_dir.rotated(axis, angle * side).normalized()

	var length_scale = lerp(1.0, branch_length_scale, height_ratio)
	var length = segment_length * 5.0 * length_scale
	var thick = branch_thickness * 0.6 * length_scale

	var anchor = StaticBody3D.new()
	branch_root.add_child(anchor)
	anchor.name = "Anchor"

	var tip = RigidBody3D.new()
	branch_root.add_child(tip)
	tip.name = "Tip"
	

	tip.collision_layer = 2
	tip.collision_mask = 0
	
	tip.mass = length * 0.5
	tip.gravity_scale = 0.0
	tip.position = dir * length

	var joint = Generic6DOFJoint3D.new()
	branch_root.add_child(joint)
	joint.name = "Joint"
	
	if parent_index >= 0 and parent_index < branches.size():
		joint.node_a = NodePath("../../BranchRoot_%d/Tip" % parent_index)
	else:
		joint.node_a = NodePath("../Anchor")
	joint.node_b = NodePath("../Tip")

	for axis_i in ["x", "y", "z"]:
		joint.set("linear_limit_%s_enabled" % axis_i, true)
		joint.set("linear_limit_%s_lower" % axis_i, 0.0)
		joint.set("linear_limit_%s_upper" % axis_i, 0.0)

	for axis_i in ["x", "y", "z"]:
		joint.set("angular_spring_%s_enabled" % axis_i, true)
		joint.set("angular_spring_%s_stiffness" % axis_i, stiffness)
		joint.set("angular_spring_%s_damping" % axis_i, damping)

	var health = "healthy"
	var mat = tree_material
	if rng.randf() < dead_branch_ratio:
		health = "diseased"
		mat = diseased_materials[rng.randi() % diseased_materials.size()]

	var visual = MeshInstance3D.new()
	tip.add_child(visual)
	visual.material_override = mat
	
	var local_rest_pos = -dir * length
	var static_path = [local_rest_pos, Vector3.ZERO]
	var generated_mesh = generate_tube(static_path, thick, thickness_taper)
	visual.mesh = generated_mesh
	
	var tip_col = CollisionShape3D.new()
	
	if collision_shape_type == 0:
		var tip_capsule = CapsuleShape3D.new()
		tip_capsule.radius = thick
		tip_capsule.height = length + (thick * 2.0)
		tip_col.shape = tip_capsule
		tip_col.position = -dir * (length * 0.5)
		
		var up = Vector3.UP
		if abs(dir.dot(up)) > 0.99: up = Vector3.RIGHT
		var x_axis = dir.cross(up).normalized()
		var z_axis = x_axis.cross(dir).normalized()
		tip_col.basis = Basis(x_axis, dir, z_axis)
	else:
		var tip_sphere = SphereShape3D.new()
		tip_sphere.radius = thick * 0.5
		tip_col.shape = tip_sphere

	tip.add_child(tip_col)
	
	var anchor_col = CollisionShape3D.new()
	var anchor_sphere = SphereShape3D.new()
	anchor_sphere.radius = thick
	anchor_col.shape = anchor_sphere
	anchor.add_child(anchor_col)
	
	tip.set_meta("is_branch_tip", true)
	if health == "diseased":
		tip.set_meta("is_deadwood", true)
	else:
		tip.set_meta("is_deadwood", false)

	branches.append({
		"anchor": anchor,
		"tip": tip,
		"joint": joint,
		"parent_index": parent_index,
		"children": [],
		"severed": false,
		"health": health
	})
	
	if parent_index >= 0 and parent_index < branches.size() - 1:
		branches[parent_index].children.append(branch_idx)
	
	var debug_vis = MeshInstance3D.new()
	debug_vis.material_override = debug_material
	debug_vis.visible = show_debug
	
	if collision_shape_type == 0:
		var cap_mesh = CapsuleMesh.new()
		cap_mesh.radius = thick
		cap_mesh.height = length + (thick * 2.0)
		cap_mesh.rings = 4
		cap_mesh.radial_segments = 8
		debug_vis.mesh = cap_mesh
		debug_vis.position = tip_col.position
		debug_vis.basis = tip_col.basis
	else:
		var sph_mesh = SphereMesh.new()
		sph_mesh.radius = thick
		sph_mesh.height = thick * 2.0
		sph_mesh.rings = 8
		sph_mesh.radial_segments = 12
		debug_vis.mesh = sph_mesh
	
	tip.add_child(debug_vis)
	debug_meshes.append(debug_vis)
	
	var anchor_debug = MeshInstance3D.new()
	var anc_mesh = SphereMesh.new()
	anc_mesh.radius = thick
	anc_mesh.height = thick * 2.0
	anc_mesh.rings = 4
	anc_mesh.radial_segments = 8
	anchor_debug.mesh = anc_mesh
	anchor_debug.material_override = debug_material
	anchor_debug.visible = show_debug
	anchor.add_child(anchor_debug)
	debug_meshes.append(anchor_debug)
	
	return branch_idx

func prune_branch(branch_index: int):
	if branch_index < 0 or branch_index >= branches.size():
		return
	var b = branches[branch_index]
	if b.severed or not is_instance_valid(b.tip):
		return
	b.severed = true
	if is_instance_valid(b.joint):
		b.joint.queue_free()
	if is_instance_valid(b.tip):
		b.tip.gravity_scale = 1.0

		b.tip.collision_layer = 8
		b.tip.collision_mask = 1
		

		var tip_pos = b.tip.global_position if b.tip.is_inside_tree() else b.tip.position
		var self_pos = global_position if is_inside_tree() else Vector3.ZERO
		var trunk_dir_out = (tip_pos - self_pos).normalized()
		trunk_dir_out.y = 0.2
		var push_dir = (trunk_dir_out + Vector3(rng.randf_range(-0.3, 0.3), 0.1, rng.randf_range(-0.3, 0.3))).normalized()
		b.tip.apply_central_impulse(push_dir * b.tip.mass * 2.0)
		

		b.tip.contact_monitor = true
		b.tip.max_contacts_reported = 2
		b.tip.body_entered.connect(func(body):
			if not is_instance_valid(b.tip) or b.tip.is_queued_for_deletion():
				return
			if body.name == "GroundPlane" or body.collision_layer == 1:
				_start_fade_out(b.tip)
		)
		
	branch_pruned.emit(branch_index)
	for child_idx in b.children:
		prune_branch(child_idx)

func _start_fade_out(tip: RigidBody3D):
	if not is_instance_valid(tip) or tip.is_queued_for_deletion():
		return
	if tip.has_meta("fading"):
		return
	tip.set_meta("fading", true)
	
	var visual: MeshInstance3D = null
	for child in tip.get_children():
		if child is MeshInstance3D:
			visual = child
			break
			
	if visual and visual.material_override:
		var mat: StandardMaterial3D = visual.material_override.duplicate()
		visual.material_override = mat
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		var tween = tip.create_tween()
		tween.tween_property(mat, "albedo_color:a", 0.0, 1.5)
		tween.tween_callback(tip.queue_free)
	else:
		var tween = tip.create_tween()
		tween.tween_interval(1.5)
		tween.tween_callback(tip.queue_free)

func sever_branch(hit_collider: Node, hit_pos: Vector3, hit_normal: Vector3):
	for i in range(branches.size()):
		var b = branches[i]
		if b.tip == hit_collider:
			prune_branch(i)
			break

func set_debug_visible(on: bool) -> void:
	show_debug = on
	for m in debug_meshes:
		if is_instance_valid(m):
			m.visible = on

func get_tree_bounds() -> AABB:
	var start_pos = global_position if is_inside_tree() else Vector3.ZERO
	var bounds = AABB(start_pos, Vector3.ZERO)
	bounds = _expand_bounds_recursive(self, bounds)
	return bounds

func _expand_bounds_recursive(node: Node, bounds: AABB) -> AABB:
	if node is MeshInstance3D and node.mesh:
		var mesh_aabb = node.mesh.get_aabb()
		var t = node.global_transform if node.is_inside_tree() else node.transform
		for i in range(8):
			var corner = Vector3(
				mesh_aabb.position.x + mesh_aabb.size.x * (1 if i & 1 else 0),
				mesh_aabb.position.y + mesh_aabb.size.y * (1 if i & 2 else 0),
				mesh_aabb.position.z + mesh_aabb.size.z * (1 if i & 4 else 0)
			)
			bounds = bounds.expand(t * corner)
	for child in node.get_children():
		bounds = _expand_bounds_recursive(child, bounds)
	return bounds

func _physics_process(delta):
	time_accum += delta
	for b in branches:
		apply_wind(b, delta)

func apply_wind(b, delta):
	if b.severed or not is_instance_valid(b.tip):
		return
	var tip: RigidBody3D = b.tip
	var p = tip.global_position * wind_scale
	
	var time_offset = time_accum * wind_speed * 5.0
	var nx = wind_noise.get_noise_3d(p.x, p.y, p.z + time_offset)
	var ny = wind_noise.get_noise_3d(p.x + 100.0, p.y + time_offset, p.z)
	var nz = wind_noise.get_noise_3d(p.x, p.y + 200.0, p.z + time_offset)
	
	var wind = Vector3(nx, ny * 0.3, nz) * wind_strength
	if collision_shape_type == 0:
		wind *= capsule_wind_multiplier
	tip.apply_central_force(wind)

func generate_tube_array(path: Array, thicknesses: Array) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var radial_segments = 6
	
	for i in range(path.size()):
		var pt = path[i]
		var next_pt = path[i+1] if i < path.size()-1 else pt + (pt - path[i-1]).normalized()
		var dir = (next_pt - pt).normalized()
		if dir.length() < 0.001: dir = Vector3.UP
		
		var up = Vector3.UP
		if abs(dir.dot(up)) > 0.99: up = Vector3.RIGHT
		
		var x_axis = dir.cross(up).normalized()
		var y_axis = x_axis.cross(dir).normalized()
		
		var r = thicknesses[i]
		
		for s in range(radial_segments + 1):
			var angle = (float(s) / radial_segments) * PI * 2.0
			var ring_pos = pt + (x_axis * cos(angle) + y_axis * sin(angle)) * r
			st.set_normal((ring_pos - pt).normalized())
			st.set_uv(Vector2(float(s)/radial_segments, float(i)/path.size()))
			st.add_vertex(ring_pos)

	for i in range(path.size() - 1):
		for s in range(radial_segments):
			var a = i * (radial_segments + 1) + s
			var b = a + 1
			var c = a + (radial_segments + 1)
			var d = c + 1
			
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)

	st.generate_normals()
	return st.commit()

func generate_tube(path: Array, start_thickness: float, end_thickness: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var radial_segments = 6
	
	for i in range(path.size()):
		var pt = path[i]
		var next_pt = path[i+1] if i < path.size()-1 else pt + (pt - path[i-1]).normalized()
		var dir = (next_pt - pt).normalized()
		if dir.length() < 0.001: dir = Vector3.UP
		
		var up = Vector3.UP
		if abs(dir.dot(up)) > 0.99: up = Vector3.RIGHT
		
		var x_axis = dir.cross(up).normalized()
		var y_axis = x_axis.cross(dir).normalized()
		
		var t = 0.0
		if path.size() > 1:
			t = float(i) / (path.size() - 1)
			
		var r = lerp(start_thickness, end_thickness, t)
		
		for s in range(radial_segments + 1):
			var angle = float(s) / radial_segments * TAU
			var local_pos = (x_axis * cos(angle) + y_axis * sin(angle)) * r
			var uv = Vector2(float(s)/radial_segments, t)
			
			st.set_uv(uv)
			st.set_normal(local_pos.normalized())
			st.add_vertex(pt + local_pos)
			
	for i in range(path.size() - 1):
		for s in range(radial_segments):
			var curr_ring = i * (radial_segments + 1)
			var next_ring = (i + 1) * (radial_segments + 1)
			
			var a = curr_ring + s
			var b = curr_ring + s + 1
			var c = next_ring + s
			var d = next_ring + s + 1
			
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
			
	return st.commit()
