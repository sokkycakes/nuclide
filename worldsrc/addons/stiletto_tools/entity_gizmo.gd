@tool
extends EditorNode3DGizmoPlugin
const EntityType = preload("nodes/entity.gd")
const ConnectionType = preload("nodes/connection.gd")

func _init() -> void:
	create_material("entity",Color(0.3,0.9,0.75))
	create_material("connection",Color(1.0,0.65,0.2))

func _get_gizmo_name() -> String:
	return "FTE entities"

func _has_gizmo(node: Node3D) -> bool:
	return node is EntityType

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	var lines := PackedVector3Array([
		Vector3(-0.35,0,0),Vector3(0.35,0,0),
		Vector3(0,-0.35,0),Vector3(0,0.35,0),
		Vector3(0,0,0.35),Vector3(0,0,-0.8),
		Vector3(-0.18,0,-0.55),Vector3(0,0,-0.8),
		Vector3(0.18,0,-0.55),Vector3(0,0,-0.8)])
	gizmo.add_lines(lines,get_material("entity",gizmo))
	gizmo.add_collision_segments(lines)
	var wires := PackedVector3Array()
	for connection in node.outputs:
		if not connection is ConnectionType: continue
		var target := node.get_node_or_null(connection.target)
		if target is Node3D:
			wires.append(Vector3.ZERO)
			wires.append(node.to_local(target.global_position))
	if not wires.is_empty(): gizmo.add_lines(wires,get_material("connection",gizmo))
