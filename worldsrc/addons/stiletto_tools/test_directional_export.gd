extends SceneTree
const Exporter = preload("exporter.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func sun_record(exporter: RefCounted) -> Dictionary:
	for record in exporter.entities:
		if record.get("_directional","") == "1": return record
	return {}

func run() -> void:
	var scene := (load("res://maps/editor_lab.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.map_name = "ftew_sun_probe"
	for child in scene.get_children():
		if child is Light3D or child.name == "LightTrigger": child.set_meta("fte_ignore",true)
	var sun := DirectionalLight3D.new()
	sun.name = "ProbeSun"
	sun.rotation_degrees = Vector3(-45,-45,0)
	sun.light_color = Color(1,0.8,0.6)
	sun.light_energy = 2
	sun.shadow_enabled = true
	scene.add_child(sun)
	await process_frame
	await process_frame
	var exporter := Exporter.new()
	var destination := ProjectSettings.globalize_path("res://build/sun-export-test")
	var result: Dictionary = exporter.export_world(scene,destination)
	var record := sun_record(exporter)
	if not result.get("ok",false) or record.is_empty():
		print(JSON.stringify(result));quit(1);return
	var angles := str(record.angles).split(" ")
	if absf(float(angles[0])-45)>0.001 or absf(float(angles[1])-45)>0.001: failures.append("Godot -Z must map to the correct FTE ray direction")
	if record.brightness != "2.0" or record._shadows != "1" or record.start_active != "1": failures.append("Energy, shadows or visibility lost")
	var first_hash: String = result.sha256
	sun.position = Vector3(10000,5000,-9000)
	result = exporter.export_world(scene,destination)
	if result.get("sha256","") != first_hash: failures.append("Moving the sun must not affect exported illumination")
	sun.visible = false
	sun.shadow_enabled = false
	result = exporter.export_world(scene,destination)
	record = sun_record(exporter)
	if record.start_active != "0" or record._shadows != "0": failures.append("Hidden or shadowless sun lost")
	sun.visible = true
	sun.shadow_enabled = true
	# Publish an isolated world and all its content-addressed dependencies.
	result = exporter.export_world(scene,ProjectSettings.globalize_path("res://../base"))
	if not result.get("ok",false): failures.append(str(result))
	print(JSON.stringify({"ok":failures.is_empty(),"errors":failures,"sun":sun_record(exporter)}))
	scene.free()
	quit(0 if failures.is_empty() else 1)
