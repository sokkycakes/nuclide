extends SceneTree
const Exporter = preload("exporter.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := (load("res://maps/editor_lab.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var destination := ProjectSettings.globalize_path("res://build/export-test")
	var exporter := Exporter.new()
	var first: Dictionary = exporter.export_world(scene,destination)
	check(first.ok,"Fixture must export")
	var bytes := FileAccess.get_file_as_bytes(destination.path_join("maps/editor_lab.ftew"))
	check(bytes[-1] == 0,"Entity section must end in a binary zero byte")
	var unicode_exporter := Exporter.new()
	unicode_exporter.entities.append({"classname":"worldspawn","message":"Café 世界"})
	var entity_bytes := unicode_exporter.serialize_entities()
	check(entity_bytes[-1] == 0 and entity_bytes.count(0) == 1,"Entity text must have exactly one binary terminator")
	check(entity_bytes.slice(0,-1).get_string_from_utf8().contains("Café 世界"),"UTF-8 entity values must survive serialization")
	var second: Dictionary = exporter.export_world(scene,destination)
	check(second.ok and first.sha256 == second.sha256,"Repeated exports must be deterministic and reset compiler state")
	scene.get_node("SpawnB").entity_id = "spawn_a"
	check(not exporter.export_world(scene,destination).ok,"Duplicate entity IDs must fail")
	scene.get_node("SpawnB").entity_id = "spawn_b"
	var connection: Resource = scene.get_node("LightTrigger").outputs[0]
	connection.target = NodePath("../MissingLight")
	check(not exporter.export_world(scene,destination).ok,"Broken connections must fail")
	connection.target = NodePath("../TestLight")
	var unsupported := GPUParticles3D.new()
	scene.add_child(unsupported)
	check(not exporter.export_world(scene,destination).ok,"Unsupported gameplay nodes must fail rather than disappear")
	scene.remove_child(unsupported);unsupported.free()
	scene.get_node("CrateA").scale = Vector3.ZERO
	check(not exporter.export_world(scene,destination).ok,"Singular transforms must fail")
	check(bytes == FileAccess.get_file_as_bytes(destination.path_join("maps/editor_lab.ftew")),"Failed exports must preserve the last published world")
	print(JSON.stringify({"ok":failures.is_empty(),"errors":failures,"fixture_sha256":first.get("sha256","")}))
	scene.free()
	quit(0 if failures.is_empty() else 1)
