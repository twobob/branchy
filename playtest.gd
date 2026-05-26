extends Node

func _ready():
	print("=== PLAYTEST START ===")
	
	await get_tree().create_timer(0.5).timeout
	
	var scene = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	
	var tg = scene.get_node_or_null("TreeGenerator3D") if scene else null
	var cam = scene.get_node_or_null("Camera3D") if scene else null
	var gc = scene.get_node_or_null("GameController") if scene else null
	
	if tg: print("PASS: TreeGenerator3D exists")
	else: print("FAIL: TreeGenerator3D missing")
	
	if cam: print("PASS: Camera3D exists")
	else: print("FAIL: Camera3D missing")
	
	if gc: print("PASS: GameController exists")
	else: print("FAIL: GameController missing")
	
	if tg and tg.branches.size() > 0:
		print("PASS: %d branches generated" % tg.branches.size())
		var b = tg.branches[0]
		if b.has("segments"):
			print("PASS: Multi-segment branches (%d segs)" % b.segments.size())
		else:
			print("FAIL: No segments field - branches wont bend")
		
		if b.has("tip") and is_instance_valid(b.tip):
			print("PASS: Branch tip valid")
			if b.tip.has_meta("branch_idx"):
				print("PASS: Branch tip has branch_idx meta (cut-anywhere)")
			else:
				print("FAIL: Branch tip missing branch_idx meta")
		
		var unsevered = 0
		for br in tg.branches:
			if not br.severed: unsevered += 1
		
		if tg.branches.size() > 1:
			tg.sever_branch(tg.branches[1].segments[0] if tg.branches[1].has("segments") else tg.branches[1].tip, Vector3.ZERO, Vector3.UP)
			if tg.branches[1].severed:
				print("PASS: Branch severed successfully")
			else:
				print("FAIL: Branch sever failed")
	else:
		print("FAIL: No branches generated")
	
	var tc = null
	if cam:
		for child in cam.get_children():
			if child.has_method("set_active_tool"):
				tc = child
				break
	if tc:
		print("PASS: ToolController found")
		tc.set_active_tool("chainsaw")
		if is_instance_valid(tc.current_model):
			print("PASS: Chainsaw model loaded")
		else:
			print("FAIL: Chainsaw model NOT loaded")
		tc.set_active_tool("mini_sierra")
		if is_instance_valid(tc.current_model):
			print("PASS: Mini sierra model loaded")
		else:
			print("FAIL: Mini sierra model NOT loaded")
	else:
		print("FAIL: ToolController not found")
	
	if cam and cam.global_position.y < 50:
		print("PASS: Camera height OK (%.1f)" % cam.global_position.y)
	elif cam:
		print("FAIL: Camera too high (%.1f)" % cam.global_position.y)
	
	var tree_mat_color = Color(0.35, 0.22, 0.12)
	if tg:
		var mat = tg.tree_material
		if mat and mat is StandardMaterial3D:
			var c = mat.albedo_color
			if c.r > 0.2 and c.g < 0.3 and c.b < 0.2:
				print("PASS: Bark color is brown (%.2f, %.2f, %.2f)" % [c.r, c.g, c.b])
			else:
				print("FAIL: Bark color wrong (%.2f, %.2f, %.2f) - expected brown" % [c.r, c.g, c.b])
	
	print("=== PLAYTEST END ===")
	get_tree().quit()
