extends SceneTree
const Exporter = preload("exporter.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Model a live editor instance with an unset newly introduced property.
	# Change only the loaded script resource in this test process, never its file.
	var world_script: GDScript = load("res://addons/stiletto_tools/nodes/world.gd")
	var original := world_script.source_code
	world_script.source_code = original.replace('@export var native_sky: String = ""','var native_sky: Variant = null')
	if world_script.reload(true) != OK:
		quit(1);return
	var scene := (load("res://maps/editor_lab.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var failures: Array[String] = []
	var destination := ProjectSettings.globalize_path("res://build/hot-reload-test")
	if scene.get("native_sky") != null: failures.append("Fixture must reproduce the unset field")
	var result: Dictionary = Exporter.new().export_world(scene,destination)
	if not result.get("ok",false): failures.append("Unset Native Sky must export the environment")
	scene.world_properties["skyname"] = "env/fteworld/day"
	result = Exporter.new().export_world(scene,destination)
	if not result.get("ok",false) or result.get("sky","") != "env/fteworld/day": failures.append("Unset Native Sky must preserve the world-property fallback")
	scene.set("native_sky","env/fteworld/dusk")
	result = Exporter.new().export_world(scene,destination)
	if not result.get("ok",false) or result.get("sky","") != "env/fteworld/dusk": failures.append("Explicit Native Sky must still take precedence")
	scene.free()
	world_script.source_code = original
	world_script.reload(true)
	print(JSON.stringify({"ok":failures.is_empty(),"errors":failures}))
	quit(0 if failures.is_empty() else 1)
