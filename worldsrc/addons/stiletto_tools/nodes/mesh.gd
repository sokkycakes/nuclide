@tool
extends MeshInstance3D
class_name FTEWorldMesh3D
@export_enum("Visual and collision", "Visual only", "Collision only") var export_mode: int = 0
## Native material path, e.g. textures/concrete/wall. Leave empty to convert.
@export var fte_material: String = ""
