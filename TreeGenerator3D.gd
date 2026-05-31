extends Node3D
class_name TreeGenerator3D

signal branch_pruned(branch_index: int)

@export var axiom: String = "X"
@export var rule_X: String = "F-[[X]+X]+F[+FX]-X"
@export var rule_F: String = "FF"
@export var iterations: int = 4

@export var segment_length: float = 0.4
@export var angle_deg: float = 22.0
@export var branch_thickness: float = 0.15
@export var thickness_taper: float = 0.03

@export var base_branch_offset: float = 0.15
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

var tree_material: Material
var debug_material: StandardMaterial3D
var diseased_materials: Array[Material] = []
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
	tree_material = ShaderMaterial.new()
	var wind_shader = Shader.new()
	wind_shader.code = _get_wind_shader_code()
	tree_material.shader = wind_shader
	tree_material.set_shader_parameter("albedo_color", Color(0.35, 0.22, 0.12))
	tree_material.set_shader_parameter("wind_strength", wind_strength)
	tree_material.set_shader_parameter("wind_speed", wind_speed)
	
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
		var mat = ShaderMaterial.new()
		var dshader = Shader.new()
		dshader.code = _get_wind_shader_code()
		mat.shader = dshader
		mat.set_shader_parameter("albedo_color", c)
		mat.set_shader_parameter("wind_strength", wind_strength)
		mat.set_shader_parameter("wind_speed", wind_speed)
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
		
	for i in range(branch_paths.size()):
		create_static_branch(branch_paths[i], path_thicknesses[i])

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
	if branches.size() >= 200:
		return false
	if h < base_branch_offset:
		return false
	var falloff = pow(1.0 - clamp(h, 0.0, 0.99), vertical_falloff)
	return rng.randf() < clamp(falloff * 0.85, 0.25, 0.7)

func create_static_branch(path: Array, thicknesses: Array):
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	body.name = "Trunk"
	body.set_meta("path", path)
	body.set_meta("thicknesses", thicknesses)

	var mesh_node = MeshInstance3D.new()
	body.add_child(mesh_node)
	mesh_node.material_override = tree_material
	mesh_node.mesh = generate_tube_array(path, thicknesses)

	for i in range(path.size() - 1):
		var col = CollisionShape3D.new()
		var cap = CapsuleShape3D.new()
		var seg_dir = (path[i + 1] - path[i])
		var seg_len = seg_dir.length()
		var thick = thicknesses[i] if i < thicknesses.size() else 0.1
		cap.radius = max(thick, 0.05)
		cap.height = max(seg_len, 0.1)
		col.shape = cap
		var mid = (path[i] + path[i + 1]) * 0.5
		col.position = mid
		var up = seg_dir.normalized()
		if up.length() > 0.001:
			var right = up.cross(Vector3.RIGHT).normalized()
			if right.length() < 0.01:
				right = up.cross(Vector3.FORWARD).normalized()
			var fwd = right.cross(up).normalized()
			col.basis = Basis(right, up, fwd)
		body.add_child(col)

func create_branch(origin: Vector3, trunk_dir: Vector3, height_ratio: float, _from_trunk: bool = false, parent_index: int = -1) -> int:
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
	var total_length = segment_length * 5.0 * length_scale
	var thick = branch_thickness * 0.6 * length_scale

	var health = "healthy"
	var mat = tree_material
	if rng.randf() < dead_branch_ratio:
		health = "diseased"
		mat = diseased_materials[rng.randi() % diseased_materials.size()]

	# Build a multi-point path for the branch (curved, not segmented)
	var num_points = 8
	var path = []
	var thicknesses = []
	var cur_dir = dir
	var cur_pos = Vector3.ZERO
	for i in range(num_points):
		path.append(cur_pos)
		var t_along = float(i) / (num_points - 1)
		thicknesses.append(lerp(thick, thickness_taper, t_along))
		# Slight random curve
		var bend = Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.02, 0.02), rng.randf_range(-0.05, 0.05))
		cur_dir = (cur_dir + bend).normalized()
		# Gravity droop increases along branch
		cur_dir.y -= 0.02 * t_along
		cur_dir = cur_dir.normalized()
		cur_pos += cur_dir * (total_length / (num_points - 1))

	# Single StaticBody3D for the whole branch
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	branch_root.add_child(body)
	body.name = "BranchBody"

	# Single continuous mesh
	var mesh_node = MeshInstance3D.new()
	body.add_child(mesh_node)
	mesh_node.material_override = mat
	var branch_mesh = generate_tube_array(path, thicknesses) if path.size() > 2 else generate_tube(path, thick, thickness_taper)
	mesh_node.mesh = branch_mesh

	# Collision shapes along the branch
	for i in range(path.size() - 1):
		var col = CollisionShape3D.new()
		var cap = CapsuleShape3D.new()
		var seg_dir_v = (path[i + 1] - path[i])
		var seg_len = seg_dir_v.length()
		var seg_thick = thicknesses[i] if i < thicknesses.size() else 0.05
		cap.radius = max(seg_thick, 0.02)
		cap.height = max(seg_len, 0.05)
		col.shape = cap
		var mid = (path[i] + path[i + 1]) * 0.5
		col.position = mid
		var up_dir = seg_dir_v.normalized()
		if up_dir.length() > 0.001:
			var right = up_dir.cross(Vector3.RIGHT).normalized()
			if right.length() < 0.01:
				right = up_dir.cross(Vector3.FORWARD).normalized()
			var fwd = right.cross(up_dir).normalized()
			col.basis = Basis(right, up_dir, fwd)
		body.add_child(col)

	# Store metadata on the body
	body.set_meta("is_branch_tip", true)
	body.set_meta("is_deadwood", health == "diseased")
	body.set_meta("branch_idx", branch_idx)
	body.set_meta("path", path)
	body.set_meta("thicknesses", thicknesses)

	# Store branch data
	branches.append({
		"root": branch_root,
		"body": body,
		"mesh_node": mesh_node,
		"path": path,
		"thicknesses": thicknesses,
		"material": mat,
		"parent_index": parent_index,
		"children": [],
		"severed": false,
		"health": health,
		"segments": [],
		"joints": [],
		"joint": null,
		"anchor": null
	})

	if parent_index >= 0 and parent_index < branches.size():
		branches[parent_index]["children"].append(branch_idx)

	return branch_idx


func prune_branch(branch_index: int):
	if branch_index < 0 or branch_index >= branches.size():
		return
	var b = branches[branch_index]
	if b.severed:
		return
	b.severed = true

	# Cascade to children first
	for child_idx in b.get("children", []):
		prune_branch(child_idx)

	# Convert the static branch to a falling rigid body
	var body = b.get("body")
	var mesh_node = b.get("mesh_node")
	var root = b.get("root")

	if body and is_instance_valid(body) and mesh_node and is_instance_valid(mesh_node):
		# Create a RigidBody3D replacement
		var rb = RigidBody3D.new()
		rb.name = "FallingBranch_%d" % branch_index
		rb.mass = 1.0
		rb.gravity_scale = 1.0
		rb.collision_layer = 8
		rb.collision_mask = 1 | 8
		rb.linear_damp = 0.5
		rb.angular_damp = 0.8

		# Copy the mesh
		var new_mesh = MeshInstance3D.new()
		new_mesh.mesh = mesh_node.mesh
		new_mesh.material_override = b.get("material", tree_material)
		rb.add_child(new_mesh)

		# Add a simple collision
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		if mesh_node.mesh:
			var aabb = mesh_node.mesh.get_aabb()
			box.size = aabb.size.clamp(Vector3(0.05, 0.05, 0.05), Vector3(3, 3, 3))
			col.position = aabb.get_center()
		else:
			box.size = Vector3(0.2, 0.5, 0.2)
		col.shape = box
		rb.add_child(col)

		# Position at the branch's world position
		if body.is_inside_tree():
			rb.global_position = body.global_position
			rb.global_rotation = body.global_rotation
		else:
			rb.position = body.position
			rb.rotation = body.rotation
		get_parent().add_child(rb)

		# Remove the original static branch
		if root and is_instance_valid(root):
			root.queue_free()

		# Fade out after hitting ground
		rb.contact_monitor = true
		rb.max_contacts_reported = 1
		rb.body_entered.connect(func(other_body):
			if not is_instance_valid(rb) or rb.is_queued_for_deletion():
				return
			if other_body.collision_layer == 1:
				_start_fade_out(rb)
		)

		# Cleanup after 15 seconds regardless
		var tw = rb.create_tween()
		tw.tween_interval(15.0)
		tw.tween_callback(rb.queue_free)

	branch_pruned.emit(branch_index)


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
		var mat = visual.material_override.duplicate()
		visual.material_override = mat
		
		if mat is ShaderMaterial:
			var current_color = mat.get_shader_parameter("albedo_color")
			if current_color == null:
				current_color = Color(0.35, 0.22, 0.12, 1.0)
			
			var tween = tip.create_tween()
			tween.tween_method(
				func(alpha: float):
					var new_col = current_color
					new_col.a = alpha
					mat.set_shader_parameter("albedo_color", new_col),
				current_color.a,
				0.0,
				1.5
			)
			tween.tween_callback(tip.queue_free)
		elif mat is StandardMaterial3D:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var tween = tip.create_tween()
			tween.tween_property(mat, "albedo_color:a", 0.0, 1.5)
			tween.tween_callback(tip.queue_free)
		else:
			var tween = tip.create_tween()
			tween.tween_interval(1.5)
			tween.tween_callback(tip.queue_free)
	else:
		var tween = tip.create_tween()
		tween.tween_interval(1.5)
		tween.tween_callback(tip.queue_free)


func sever_branch(hit_collider: Node, hit_pos: Vector3, _hit_normal: Vector3):
	# Cut at the exact point the tool touches
	if hit_collider.name == "Trunk" or hit_collider.name.begins_with("Trunk"):
		_cut_trunk(hit_pos)
		return

	if not hit_collider.has_meta("branch_idx"):
		return
	var branch_idx = hit_collider.get_meta("branch_idx")
	if branch_idx < 0 or branch_idx >= branches.size():
		return
	var b = branches[branch_idx]
	if b.severed:
		return

	var mesh_node = b.get("mesh_node")
	var path = b.get("path", [])
	var thicknesses = b.get("thicknesses", [])

	if not mesh_node or not is_instance_valid(mesh_node) or path.size() < 2:
		prune_branch(branch_idx)
		return

	# Find where along the branch path the cut happened
	var local_hit = hit_collider.to_local(hit_pos)
	var best_seg = 0
	var best_t = 0.5
	var best_dist = INF

	for i in range(path.size() - 1):
		var a = path[i]
		var seg_b = path[i + 1]
		var seg_vec = seg_b - a
		var seg_len = seg_vec.length()
		if seg_len < 0.001:
			continue
		var param = clampf((local_hit - a).dot(seg_vec) / (seg_len * seg_len), 0.0, 1.0)
		var closest = a + seg_vec * param
		var d = closest.distance_to(local_hit)
		if d < best_dist:
			best_dist = d
			best_seg = i
			best_t = param

	# Split point index (which path point to split at)
	var split_idx = best_seg + 1
	if split_idx <= 0:
		split_idx = 1
	if split_idx >= path.size() - 1:
		# Cut near the tip - just prune the whole thing
		prune_branch(branch_idx)
		return

	# Create stub mesh (lower part stays)
	var stub_path = path.slice(0, split_idx + 1)
	var stub_thick = thicknesses.slice(0, split_idx + 1)
	var stub_mesh = generate_tube_array(stub_path, stub_thick) if stub_path.size() > 2 else generate_tube(stub_path, stub_thick[0], stub_thick[-1])
	if stub_mesh:
		mesh_node.mesh = stub_mesh

	# Create falling piece (upper part falls)
	var fall_path = path.slice(split_idx)
	var fall_thick = thicknesses.slice(split_idx)

	if fall_path.size() >= 2:
		var fall_mesh = generate_tube_array(fall_path, fall_thick) if fall_path.size() > 2 else generate_tube(fall_path, fall_thick[0], fall_thick[-1])
		if fall_mesh:
			var rb = RigidBody3D.new()
			rb.name = "CutBranch_%d" % branch_idx
			rb.mass = 0.5
			rb.gravity_scale = 1.0
			rb.collision_layer = 8
			rb.collision_mask = 1 | 8
			rb.linear_damp = 0.5
			rb.angular_damp = 0.8

			var vis = MeshInstance3D.new()
			vis.mesh = fall_mesh
			vis.material_override = b.get("material", tree_material)
			rb.add_child(vis)

			var col = CollisionShape3D.new()
			var box = BoxShape3D.new()
			var aabb = fall_mesh.get_aabb()
			box.size = aabb.size.clamp(Vector3(0.05, 0.05, 0.05), Vector3(3, 3, 3))
			col.shape = box
			col.position = aabb.get_center()
			rb.add_child(col)

			# Position at the cut point world space
			if hit_collider.is_inside_tree():
				rb.global_position = hit_collider.to_global(path[split_idx])
				rb.global_rotation = hit_collider.global_rotation
			else:
				rb.position = path[split_idx]
				rb.rotation = hit_collider.rotation
			get_parent().add_child(rb)

			# Cleanup
			var tw = rb.create_tween()
			tw.tween_interval(12.0)
			tw.tween_callback(rb.queue_free)

	# Prune child branches
	for child_idx in b.get("children", []):
		prune_branch(child_idx)


func _cut_trunk(cut_pos: Vector3) -> void:
	var cut_y = cut_pos.y
	for i in range(branches.size()):
		var b = branches[i]
		if b.severed:
			continue
		var anchor = b.get("anchor")
		if anchor and is_instance_valid(anchor):
			if anchor.global_position.y >= cut_y - 0.3:
				prune_branch(i)


func _release_segment(seg: RigidBody3D) -> void:
	# Just enable gravity and collision. No impulse. Gravity does the work.
	seg.freeze = false
	seg.gravity_scale = 1.0
	seg.collision_layer = 8
	seg.collision_mask = 1 | 8
	seg.linear_damp = 0.5
	seg.angular_damp = 0.8
	seg.can_sleep = true


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
	# Check for orphaned branches every 60 frames
	if Engine.get_physics_frames() % 60 == 0:
		_check_orphaned_branches()


func _check_orphaned_branches():
	for i in range(branches.size()):
		var b = branches[i]
		if b.severed:
			continue
		if not _is_branch_connected(i):
			prune_branch(i)

func _is_branch_connected(branch_idx: int) -> bool:
	var b = branches[branch_idx]
	if b.severed:
		return false
	# Check all joints in this branch - if the first joint is gone, disconnected
	var jts = b.get("joints", [])
	if jts.size() > 0:
		if not is_instance_valid(jts[0]):
			return false
	# Check root joint that connects to parent/trunk
	var root_jt = b.get("joint")
	if root_jt and not is_instance_valid(root_jt):
		return false
	# Check if parent branch is still connected (recursive)
	var parent_idx = b.get("parent_index", -1)
	if parent_idx >= 0 and parent_idx < branches.size():
		var parent_b = branches[parent_idx]
		if parent_b.severed:
			return false
		# Check if the parent segment we attach to has been released (has gravity)
		var parent_segs = parent_b.get("segments", [])
		for seg in parent_segs:
			if is_instance_valid(seg) and seg.gravity_scale > 0.5:
				return false
	return true



func generate_tube_array(path: Array, thicknesses: Array) -> ArrayMesh:
	if path.size() < 2 or thicknesses.size() < 2:
		return null
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

func _get_wind_shader_code() -> String:
	return """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo_color : source_color = vec4(0.35, 0.22, 0.12, 1.0);
uniform float wind_strength = 1.5;
uniform float wind_speed = 0.4;
uniform float roughness_val = 0.9;

void vertex() {
	// Wind displacement increases with height (world Y)
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height_factor = clamp(world_pos.y * 0.15, 0.0, 1.0);
	float time = TIME * wind_speed;
	
	// Two overlapping sine waves for organic feel
	float sway_x = sin(time * 1.3 + world_pos.y * 0.5 + world_pos.z * 0.3) * wind_strength * 0.03;
	float sway_z = sin(time * 0.9 + world_pos.y * 0.7 + world_pos.x * 0.4) * wind_strength * 0.02;
	
	// Higher branches sway more
	VERTEX.x += sway_x * height_factor;
	VERTEX.z += sway_z * height_factor;
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness_val;
}
"""

func generate_tube(path: Array, start_thickness: float, end_thickness: float) -> ArrayMesh:
	if path.size() < 2:
		return null
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
