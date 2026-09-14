extends SceneTree
const Exporter = preload("exporter.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("Usage: godot --headless --path worldsrc --script addons/stiletto_tools/cli.gd -- res://maps/editor_lab.tscn OUTPUT_GAMEDIR")
		quit(2);return
	var packed := load(args[0]) as PackedScene
	if packed == null: quit(2);return
	var scene := packed.instantiate()
	root.add_child(scene)
	# CSG requires an in-tree evaluation before exporting baked surfaces.
	await process_frame
	await process_frame
	var result: Dictionary = Exporter.new().export_world(scene,args[1])
	print(JSON.stringify(result))
	scene.queue_free()
	quit(0 if result.ok else 1)
