extends SceneTree
const Exporter = preload("exporter.gd")
const World = preload("nodes/world.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := World.new()
	scene.map_name = "import_transform_test"
	root.add_child(scene)
	var parent := Node3D.new()
	scene.add_child(parent)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	parent.add_child(mesh)
	var body := StaticBody3D.new()
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	var exporter := Exporter.new()
	var destination := ProjectSettings.globalize_path("res://build/import-transform-test")
	for size in [Vector3.ONE * 0.001724,Vector3(-0.0001,0.002,2.0),Vector3.ONE]:
		parent.scale = size
		parent.rotation_degrees = Vector3(80,10,25)
		var result: Dictionary = exporter.export_world(scene,destination)
		if not result.ok: failures.append("Valid nested scale rejected: " + str(result))
		else:
			var t: Array = exporter.instances[0].transform
			var native_point: Vector3 = t[0]*32 + t[3]
			if not native_point.is_equal_approx(exporter.position(mesh.global_transform * Vector3.RIGHT)):
				failures.append("Nested placement was changed")
	parent.scale = Vector3(0,1,1)
	if exporter.export_world(scene,destination).ok: failures.append("Zero scale must fail")
	var dependent := Transform3D(Basis(Vector3.RIGHT,Vector3.RIGHT,Vector3.BACK),Vector3.ZERO)
	if exporter.valid_transform(dependent): failures.append("Dependent axes must fail")
	print(JSON.stringify({"ok":failures.is_empty(),"errors":failures}))
	scene.free()
	quit(0 if failures.is_empty() else 1)
