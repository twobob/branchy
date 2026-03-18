extends Node3D
class_name TreeGenerator3D

# ---------- L-SYSTEM ----------
@export var axiom: String = "X"
@export var rule_X: String = "F-[[X]+X]+F[+FX]-X"
@export var rule_F: String = "FF"
@export var iterations: int = 5

# ---------- SHAPE ----------
@export var segment_length: float = 0.6
@export var angle_deg: float = 25.0
@export var branch_thickness: float = 0.25
@export var thickness_taper: float = 0.05

@export var base_branch_offset: float = 0.2
@export var vertical_falloff: float = 1.6
@export var branch_length_scale: float = 0.7

# ---------- PHYSICS ----------
@export_enum("Capsule", "Sphere") var collision_shape_type: int = 0
@export var enable_self_collision: bool = false
@export var capsule_wind_multiplier: float = 5.0
@export var stiffness: float = 18.0
@export var damping: float = 3.5

# ---------- WIND ----------
@export var wind_strength: float = 12.0
@export var wind_scale: float = 0.5
@export var wind_speed: float = 0.6

# ---------- RANDOM ----------
@export var seed: int = 1

var rng := RandomNumberGenerator.new()
var branches: Array = []
var debug_meshes: Array = []
var show_debug: bool = true
var time_accum := 0.0

var tree_material: StandardMaterial3D
var debug_material: StandardMaterial3D
var wind_noise: FastNoiseLite

# ---------------------------------------
# L-SYSTEM
# ---------------------------------------
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
	# Fallback to a known-good rule if nothing passed
	return "F-[[X]+X]+F[+FX]-X"

func estimate_branch_count(rule: String) -> int:
	# Dry-run expand with the candidate rule and count '[' as branch markers
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
		# Early exit if string is exploding
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
			# Branching with rotation
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
			# Nested branch
			var sign1 = ["+", "-"][rng.randi_range(0, 1)]
			var sign2 = ["+", "-"][rng.randi_range(0, 1)]
			parts.append("[" + sign1 + "[X]" + sign2 + "X]")
	return "".join(parts)

# ---------------------------------------
# GENERATION
# ---------------------------------------
func _ready():
	tree_material = StandardMaterial3D.new()
	tree_material.albedo_color = Color(0.2, 0.5, 0.2) # Green
	tree_material.roughness = 0.9
	
	debug_material = StandardMaterial3D.new()
	debug_material.albedo_color = Color(0.0, 1.0, 1.0, 0.3)
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	wind_noise = FastNoiseLite.new()
	wind_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	wind_noise.frequency = 0.015  # Much broader, swooping gusts
	
	regenerate_tree(seed)

func regenerate_tree(new_seed: int):
	seed = new_seed
	rng.seed = seed
	wind_noise.seed = seed
	
	# Clear out the old tree
	for child in get_children():
		child.queue_free()
	branches.clear()
	debug_meshes.clear()
	time_accum = 0.0
	
	generate_tree()

func generate_tree():
	var commands := expand()
	var stack := []

	var pos := Vector3.ZERO
	var dir := Vector3.UP

	# The L-System effectively defines the "trunk" path. Give it its own physics branch!
	var current_branch_root = Node3D.new()
	add_child(current_branch_root)
	
	# We structure the tree as a series of connected RigidBodies for the trunk,
	# OR we build the trunk as one large static object, and leaf-branches are rigid bodies.
	# "Each branch = one rigid body + one joint"
	# Let's create the root trunk as the first static branch geometry, but rigid bodies for sub-branches.
	
	var trunk_height := estimate_height(commands)
	var current_height := 0.0
	
	var branch_paths := []
	var path_thicknesses := []
	
	var current_path := [pos]
	var current_thicknesses := [branch_thickness]
	
	# Let's extract L-system into pure continuous paths.
	for c in commands:
		match c:
			"F":
				var next_pos = pos + dir * segment_length
				current_height = pos.y / trunk_height
				
				# Taper logic: Thinnest at top
				var t = 1.0 - clamp(pos.y / trunk_height, 0.0, 1.0)
				var current_t = branch_thickness * t + thickness_taper
				
				# Build path
				current_path.append(next_pos)
				current_thicknesses.append(current_t)
				
				# Spawn secondary detached branches
				if should_spawn_branch(current_height):
					create_branch(pos, dir, current_height, true)
					
				pos = next_pos
				
			"+":
				dir = dir.rotated(Vector3.FORWARD, deg_to_rad(angle_deg))
				# Also add a slight random twist so it's fully 3D
				dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(30, 150)))
			"-":
				dir = dir.rotated(Vector3.FORWARD, deg_to_rad(-angle_deg))
				dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-150, -30)))
			"[":
				stack.append({"pos": pos, "dir": dir, "path": current_path.duplicate(), "thick": current_thicknesses.duplicate()})
				current_path = [pos] # Sub-branch starts here
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

	if current_path.size() > 1:
		branch_paths.append(current_path)
		path_thicknesses.append(current_thicknesses)
		
	# Now generate the STATIC TRUNK paths so it exists visually!
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
	if h < base_branch_offset:
		return false
	var falloff = pow(1.0 - h, vertical_falloff)
	# Increased branch chance slightly
	return rng.randf() < (falloff * 2.0)


# BRANCH CREATION


func create_static_branch(path: Array, thicknesses: Array):
	# Creates a static visual branch for the structural trunk lines
	var mesh_node = MeshInstance3D.new()
	add_child(mesh_node)
	mesh_node.material_override = tree_material
	
	# Create tube mesh
	mesh_node.mesh = generate_tube_array(path, thicknesses)

func create_branch(origin: Vector3, trunk_dir: Vector3, height_ratio: float, dynamic: bool):
	var branch_root = Node3D.new()
	add_child(branch_root)
	branch_root.global_position = origin

	var angle = deg_to_rad(30 + rng.randf_range(-20,20))
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

	var tip = RigidBody3D.new()
	branch_root.add_child(tip)
	
	if not enable_self_collision:
		# Disable collision with other objects on Layer 1
		tip.collision_mask = 0
		tip.collision_layer = 0
	
	tip.mass = length * 0.5
	tip.gravity_scale = 0.0
	tip.position = dir * length

	var joint = Generic6DOFJoint3D.new()
	branch_root.add_child(joint)
	joint.node_a = anchor.get_path()
	joint.node_b = tip.get_path()

	for axis_i in ["x","y","z"]:
		joint.set("linear_limit_%s_enabled" % axis_i, true)
		joint.set("linear_limit_%s_lower" % axis_i, 0.0)
		joint.set("linear_limit_%s_upper" % axis_i, 0.0)

	for axis_i in ["x","y","z"]:
		joint.set("angular_spring_%s_enabled" % axis_i, true)
		joint.set("angular_spring_%s_stiffness" % axis_i, stiffness)
		joint.set("angular_spring_%s_damping" % axis_i, damping)

	# Offset mesh to start from anchor but move with tip
	var visual = MeshInstance3D.new()
	tip.add_child(visual)
	visual.material_override = tree_material
	
	# Generate static tube mesh from anchor(0,0,0 local) to tip position (in tip's local space)
	var local_rest_pos = -dir * length
	var static_path = [local_rest_pos, Vector3.ZERO]
	var generated_mesh = generate_tube(static_path, thick, thickness_taper)
	visual.mesh = generated_mesh
	
	# Extract structural collision shape
	# OPTIMIZATION: create_convex_shape on a tube mesh generates a highly complex triangulated hull.
	# With 100+ branches, simulating that many convex hulls completely crashes Jolt performance.
	# We must use simple mathematical primitives scaled to match the geometry.
	var tip_col = CollisionShape3D.new()
	
	if collision_shape_type == 0: # Capsule
		var tip_capsule = CapsuleShape3D.new()
		tip_capsule.radius = thick
		tip_capsule.height = length + (thick * 2.0)
		tip_col.shape = tip_capsule
		
		# Rotate and position capsule to match visual mesh
		tip_col.position = -dir * (length * 0.5)
		
		var up = Vector3.UP
		if abs(dir.dot(up)) > 0.99: up = Vector3.RIGHT
		var x_axis = dir.cross(up).normalized()
		var z_axis = x_axis.cross(dir).normalized()
		tip_col.basis = Basis(x_axis, dir, z_axis)
	else: # Sphere
		var tip_sphere = SphereShape3D.new()
		tip_sphere.radius = thick * 0.5
		tip_col.shape = tip_sphere

	tip.add_child(tip_col)
	
	var anchor_col = CollisionShape3D.new()
	var anchor_sphere = SphereShape3D.new()
	anchor_sphere.radius = thick
	anchor_col.shape = anchor_sphere
	anchor.add_child(anchor_col)
	
	branches.append({
		"anchor": anchor,
		"tip": tip
	})
	
	# Create debug visualization mesh matching the collision shape
	var debug_vis = MeshInstance3D.new()
	debug_vis.material_override = debug_material
	debug_vis.visible = show_debug
	
	if collision_shape_type == 0: # Capsule
		var cap_mesh = CapsuleMesh.new()
		cap_mesh.radius = thick
		cap_mesh.height = length + (thick * 2.0)
		cap_mesh.rings = 4
		cap_mesh.radial_segments = 8
		debug_vis.mesh = cap_mesh
		debug_vis.position = tip_col.position
		debug_vis.basis = tip_col.basis
	else: # Sphere
		var sph_mesh = SphereMesh.new()
		sph_mesh.radius = thick
		sph_mesh.height = thick * 2.0
		sph_mesh.rings = 8
		sph_mesh.radial_segments = 12
		debug_vis.mesh = sph_mesh
	
	tip.add_child(debug_vis)
	debug_meshes.append(debug_vis)
	
	# Anchor debug sphere
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

func set_debug_visible(on: bool) -> void:
	show_debug = on
	for m in debug_meshes:
		if is_instance_valid(m):
			m.visible = on

func get_tree_bounds() -> AABB:
	var bounds = AABB(global_position, Vector3.ZERO)  # Start from trunk base
	for b in branches:
		for key in ["anchor", "tip"]:
			var node: Node3D = b[key]
			if is_instance_valid(node):
				var p = node.global_position
				bounds = bounds.expand(p)
	return bounds


# DYNAMIC VISUAL UPDATE

func _physics_process(delta):
	time_accum += delta
	for b in branches:
		apply_wind(b, delta)

func apply_wind(b, delta):
	var tip: RigidBody3D = b.tip
	var p = tip.global_position * wind_scale
	
	# Sample FastNoiseLite in 3D space, offset by time to simulate wind moving through the tree
	# We offset the Y and Z coordinates slightly per axis so they don't perfectly correlate
	var time_offset = time_accum * wind_speed * 5.0
	var nx = wind_noise.get_noise_3d(p.x, p.y, p.z + time_offset)
	var ny = wind_noise.get_noise_3d(p.x + 100.0, p.y + time_offset, p.z)
	var nz = wind_noise.get_noise_3d(p.x, p.y + 200.0, p.z + time_offset)
	
	# Boost the wind force so the broad sweeping gusts are noticeably strong
	var wind = Vector3(nx, ny * 0.5, nz) * wind_strength * 2.5
	if collision_shape_type == 0: # Capsule
		wind *= capsule_wind_multiplier
	tip.apply_central_force(wind)


# TUBE GENERATION

func generate_tube_array(path: Array, thicknesses: Array) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var radial_segments = 6 # Low poly for performance
	
	for i in range(path.size()):
		var pt = path[i]
		var next_pt = path[i+1] if i < path.size()-1 else pt + (pt - path[i-1]).normalized()
		var dir = (next_pt - pt).normalized()
		if dir.length() < 0.001: dir = Vector3.UP
		
		# Build a transform looking along dir
		var up = Vector3.UP
		if abs(dir.dot(up)) > 0.99: up = Vector3.RIGHT
		
		var x_axis = dir.cross(up).normalized()
		var y_axis = x_axis.cross(dir).normalized()
		
		var r = thicknesses[i]
		
		# Generate ring
		for s in range(radial_segments + 1):
			var angle = (float(s) / radial_segments) * PI * 2.0
			var ring_pos = pt + (x_axis * cos(angle) + y_axis * sin(angle)) * r
			st.set_normal((ring_pos - pt).normalized())
			st.set_uv(Vector2(float(s)/radial_segments, float(i)/path.size()))
			st.add_vertex(ring_pos)

	# Connect rings
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
	
	var radial_segments = 6 # Low poly for performance
	
	for i in range(path.size()):
		var pt = path[i]
		var next_pt = path[i+1] if i < path.size()-1 else pt + (pt - path[i-1]).normalized()
		var dir = (next_pt - pt).normalized()
		if dir.length() < 0.001: dir = Vector3.UP
		
		# Build a transform looking along dir
		var up = Vector3.UP
		if abs(dir.dot(up)) > 0.99: up = Vector3.RIGHT
		
		var x_axis = dir.cross(up).normalized()
		var y_axis = x_axis.cross(dir).normalized()
		
		var t = 0.0
		if path.size() > 1:
			t = float(i) / (path.size() - 1)
			
		var r = lerp(start_thickness, end_thickness, t)
		
		# Generate ring
		for s in range(radial_segments + 1):
			var angle = float(s) / radial_segments * TAU
			var local_pos = (x_axis * cos(angle) + y_axis * sin(angle)) * r
			var uv = Vector2(float(s)/radial_segments, t)
			
			st.set_uv(uv)
			st.set_normal(local_pos.normalized())
			st.add_vertex(pt + local_pos)
			
	# Generate indices
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
