@tool
extends Node3D
class_name FTEWorld3D
@export var map_name: String = "editor_lab"
@export var title: String = "Stiletto editor lab"
## Native QuakeC source, compiled to maps/<map_name>.dat.
@export_file("*.qc") var map_script: String = ""
@export var world_properties: Dictionary[String, String] = {}
## Optional FTE sky override, e.g. env/fteworld/day. Empty exports WorldEnvironment.
@export var native_sky: String = ""
