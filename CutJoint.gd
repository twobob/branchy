extends Generic6DOFJoint3D
class_name CutJoint

const CUT_TIME: float = 3.0
const MAX_PARAM: float = 1.0

var _lumber_a: RigidBody3D
var _lumber_b: RigidBody3D
var _is_cutting: bool = false
var _cut_time: float = 0.0
var _initial_dot: float

func setup(a: RigidBody3D, b: RigidBody3D) -> void:
	_lumber_a = a
	_lumber_b = b
	node_a = a.get_path()
	node_b = b.get_path()
	_initial_dot = a.position.dot(b.position)

func cut(value: bool) -> void:
	_is_cutting = value

func _physics_process(delta: float) -> void:
	if _is_cutting:
		_cut_time += delta
		var value: float = (_cut_time / CUT_TIME) * MAX_PARAM
		set_param_x(Generic6DOFJoint3D.Param.PARAM_ANGULAR_LOWER_LIMIT, -value)
		set_param_x(Generic6DOFJoint3D.Param.PARAM_ANGULAR_UPPER_LIMIT, value)

	if _lumber_a and _lumber_b:
		if is_instance_valid(_lumber_a) and is_instance_valid(_lumber_b):
			var current_dot = _lumber_a.position.dot(_lumber_b.position)
			if abs(_initial_dot - current_dot) >= 3.0:
				queue_free()
