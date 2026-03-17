extends SceneTree
func _init():
	var t = preload("res://TreeGenerator3D.gd").new()
	var root = Node3D.new()
	var main_scene = load("res://main.tscn").instantiate()
	root.add_child(main_scene)
	root.add_child(t)
	t._ready()
	print("Branches generated: ", t.branches.size())
	for b in t.branches:
		print("Branch pos: ", b.anchor.global_position, " to tip: ", b.tip.global_position)
	quit()
