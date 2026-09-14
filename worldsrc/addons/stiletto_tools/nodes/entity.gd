@tool
extends Node3D
class_name FTEEntity3D
## A native Nuclide entity. Only these exported values run in FTE.
@export var classname: String = "info_player_deathmatch"
## Optional stable identifier; populated fixtures retain identity when renamed.
@export var entity_id: String = ""
@export var properties: Dictionary[String, String] = {}
@export var outputs: Array[Resource] = []
