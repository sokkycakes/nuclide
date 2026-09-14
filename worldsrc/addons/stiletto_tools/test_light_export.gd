extends SceneTree
const Exporter = preload("exporter.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := (load("res://maps/editor_lab.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.map_name = "ftew_light_probe"
	for child in scene.get_children():
		if child is Light3D and child.name != "TestLight": child.set_meta("fte_ignore",true)
	scene.get_node("TestLight").visible = true
	scene.get_node("LightTrigger").set_meta("fte_ignore",true)
	var errors: Array[String] = []
	for energy in [0.0,0.25,4.0,1.0]:
		scene.get_node("TestLight").light_energy = energy
		var exporter := Exporter.new()
		var result: Dictionary = exporter.export_world(scene,ProjectSettings.globalize_path("res://build/light-export"))
		if not result.ok: errors.append(str(result.errors))
		var found := false
		for entity in exporter.entities:
			if entity.classname == "light_dynamic":
				found = true
				if float(entity.brightness) != energy: errors.append("Energy lost during export")
		if not found: errors.append("Missing dynamic light")
	# Publish the isolated fixture with its content-addressed dependencies.
	if errors.is_empty():
		var published: Dictionary = Exporter.new().export_world(scene,ProjectSettings.globalize_path("res://../base"))
		if not published.get("ok",false): errors.append(str(published))
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors}))
	scene.free()
	quit(0 if errors.is_empty() else 1)
