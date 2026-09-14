extends SceneTree
const Compiler = preload("environment_export.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void:
	var output := ProjectSettings.globalize_path("res://../base/env/fteworld")
	DirAccess.make_dir_recursive_absolute(output)
	for preset in ["day","dusk"]:
		var environment := load("res://environments/"+preset+".tres") as Environment
		var result: Dictionary = Compiler.compile(environment,"")
		check(result.errors.is_empty(),"Preset compile: " + preset)
		var ambient: Color = environment.ambient_light_color * environment.ambient_light_energy
		ambient.a = 1.0
		check(result.ambient.is_equal_approx(ambient),"Ambient energy mapping")
		if result.files.size() == 1:
			var file := FileAccess.open(output.path_join(preset+".png"),FileAccess.WRITE)
			file.store_buffer(result.files.values()[0]);file.close()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.2,0.3,0.4)
	var color_result: Dictionary = Compiler.compile(environment,"")
	var img := Image.new()
	img.load_png_from_buffer(color_result.files.values()[0])
	check(img.get_pixel(10,10).is_equal_approx(img.get_pixel(200,100)),"Color background must be uniform")
	check(Compiler.compile(environment,"../bad").errors.size()>0,"Reject sky traversal")
	check(Compiler.compile(environment,"env/fteworld/day").keys.skyname == "env/fteworld/day","Native override takes precedence")
	check(color_result.sky.begins_with("env/fteworld/"),"Nested sky lookup needs the complete game-relative path")
	var panorama := Image.create(8,4,false,Image.FORMAT_RGBA8)
	for x in range(8):
		for y in range(4): panorama.set_pixel(x,y,Color(float(x)/7,0,0))
	# FTE forward +X maps to Godot panorama's quarter turn, not its half turn.
	check(absf(Compiler.sample_panorama(panorama,Vector3.RIGHT).r-1.5/7)<0.01,"Panorama coordinate alignment")
	check(Compiler.native_direction(0.5,0.5).distance_to(Vector3.RIGHT)<0.0001,"Native sky coordinate conversion")
	print(JSON.stringify({"ok":failures.is_empty(),"errors":failures,"presets":["env/fteworld/day","env/fteworld/dusk"]}))
	quit(0 if failures.is_empty() else 1)
