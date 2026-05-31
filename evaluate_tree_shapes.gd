extends SceneTree

func _init():
	print("=== L-SYSTEM EVALUATOR ===")
	var tree_gen_script = load("res://TreeGenerator3D.gd")
	if not tree_gen_script:
		print("ERROR: Cannot load TreeGenerator3D.gd")
		quit()
		return

	var rules = [
		"F[+X]F[-X]+X",
		"F[+X][-X]FX",
		"F[+X]F[-X]FX",
		"F-[[X]+X]+F[+FX]-X",
		"FF-[+X][-X]+X",
		"F[+X][-X]+X",
		"F-[+X][-X]FX",
		"F[+X]F[-X][X]"
	]

	var seeds = [10, 30, 50]
	
	for rule in rules:
		print("Testing rule: ", rule)
		var total_branches := 0
		var min_branches := 9999
		var max_branches := 0
		var height_sum := 0.0
		
		for s in seeds:
			var tree_gen = tree_gen_script.new()
			tree_gen.axiom = "X"
			tree_gen.rule_X = rule
			tree_gen.rule_F = "FF"
			tree_gen.iterations = 4
			tree_gen.segment_length = 0.4
			tree_gen.branch_thickness = 0.15
			
			get_root().add_child(tree_gen)
			tree_gen._ready() # Force initialization of wind_noise and materials
			tree_gen.regenerate_tree(s)
			
			var count = tree_gen.branches.size()
			total_branches += count
			if count < min_branches: min_branches = count
			if count > max_branches: max_branches = count
			
			# Estimate height
			var h = tree_gen.estimate_height(tree_gen.expand())
			height_sum += h
			
			get_root().remove_child(tree_gen)
			tree_gen.queue_free()
			
		var avg_branches = float(total_branches) / seeds.size()
		var avg_height = height_sum / seeds.size()
		print("  -> Avg branches: ", avg_branches, " (Min: ", min_branches, ", Max: ", max_branches, ")")
		print("  -> Avg height: ", avg_height)

	print("=== EVALUATION COMPLETE ===")
	quit()
