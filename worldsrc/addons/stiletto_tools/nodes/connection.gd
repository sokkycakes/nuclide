@tool
extends Resource
class_name FTEConnection
## Target paths are relative to the entity that owns this connection.
@export var event: String = "OnStartTouch"
@export_node_path("Node3D") var target: NodePath
@export var action: String = "Toggle"
@export var parameter: String = ""
@export_range(0.0, 3600.0) var delay: float = 0.0
@export var fire_count: int = -1
