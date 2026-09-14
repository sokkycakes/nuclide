@tool
extends EditorPlugin
const Exporter = preload("exporter.gd")
const WorldType = preload("nodes/world.gd")
const EntityGizmo = preload("entity_gizmo.gd")
var entity_gizmo: EditorNode3DGizmoPlugin
var panel: VBoxContainer
var status: RichTextLabel
var source: CodeEdit
var source_path: String = ""
var dirty := false

func _enter_tree() -> void:
	entity_gizmo = EntityGizmo.new()
	add_node_3d_gizmo_plugin(entity_gizmo)
	panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(450,260)
	var buttons := HBoxContainer.new()
	panel.add_child(buttons)
	for entry in [["Export world",export_current],["Export + Play",play_current],["Open MapC",open_source],["Save + Compile MapC",compile_source]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		buttons.add_child(button)
	status = RichTextLabel.new()
	status.custom_minimum_size.y = 75
	status.text = "Stiletto native world tools\nOpen maps/editor_lab.tscn, export, then play in FTE."
	panel.add_child(status)
	source = CodeEdit.new()
	source.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source.gutters_draw_line_numbers = true
	var syntax := CodeHighlighter.new()
	for word in ["void","float","vector","string","entity","int","if","else","return","for","while"]: syntax.add_keyword_color(word,Color(0.8,0.55,0.95))
	syntax.add_color_region("//","",Color(0.5,0.6,0.55),true)
	syntax.add_color_region("/*","*/",Color(0.5,0.6,0.55))
	syntax.add_color_region('"','"',Color(0.85,0.75,0.4))
	source.syntax_highlighter = syntax
	source.text_changed.connect(func(): dirty=true)
	panel.add_child(source)
	add_control_to_bottom_panel(panel,"Stiletto")
	add_tool_menu_item("Stiletto: Export world",export_current)
	add_tool_menu_item("Stiletto: Export + Play",play_current)

func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(entity_gizmo)
	remove_tool_menu_item("Stiletto: Export world")
	remove_tool_menu_item("Stiletto: Export + Play")
	remove_control_from_bottom_panel(panel)
	panel.queue_free()

func _get_unsaved_status(_for_scene: String) -> String:
	return "Unsaved native MapC changes: " + source_path if dirty else ""

func _save_external_data() -> void:
	if dirty: save_source()

func project_path(setting: String, fallback: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join(str(ProjectSettings.get_setting(setting,fallback))).simplify_path()

func show_status(message: String) -> void:
	status.text = message
	make_bottom_panel_item_visible(panel)
	print("Stiletto: " + message)
	var log_path := ProjectSettings.globalize_path("res://build/editor-actions.log")
	DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
	var log := FileAccess.open(log_path,FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if log != null:
		log.seek_end()
		log.store_line(Time.get_datetime_string_from_system() + " " + message)

func current() -> Node3D:
	var scene := get_editor_interface().get_edited_scene_root()
	if not scene is WorldType:
		show_status("Open a scene with an FTEWorld3D root.")
		return null
	return scene

func export_current() -> Dictionary:
	var scene := current()
	if scene == null: return {"ok":false}
	show_status("Exporting world…")
	var save_error := get_editor_interface().save_scene()
	if save_error != OK:
		var failure := {"ok":false,"errors":["Scene could not be saved: " + error_string(save_error)]}
		show_status(JSON.stringify(failure,"  "))
		return failure
	var result: Dictionary = Exporter.new().export_world(scene,project_path("stiletto/runtime_directory","..").path_join("base"))
	if not result.has("ok"):
		result = {"ok":false,"errors":["Exporter stopped unexpectedly. Check Godot's Output panel for the script error."]}
	show_status(JSON.stringify(result,"  "))
	return result

func play_current() -> void:
	show_status("Preparing Export + Play…")
	var scene := current()
	if scene == null: return
	var engine := project_path("stiletto/engine_executable","../fteqw-world.exe")
	if not FileAccess.file_exists(engine):
		show_status("Build the FTEW-enabled runtime first: Tools/stiletto/build_engine.sh")
		return
	if dirty and not save_source(): return
	var staged_script := ProjectSettings.globalize_path("res://build/play/" + scene.map_name + ".dat")
	if not scene.map_script.is_empty() and not compile_map(scene,staged_script): return
	var result := export_current()
	if not result.get("ok",false): return
	var runtime := project_path("stiletto/runtime_directory","..")
	if not scene.map_script.is_empty():
		var destination := runtime.path_join("base/maps/" + scene.map_name + ".dat")
		if DirAccess.copy_absolute(staged_script,destination + ".tmp") != OK or DirAccess.rename_absolute(destination + ".tmp",destination) != OK:
			show_status("World exported, but native MapC could not be published. Playtest was not launched.");return
	var progs := str(ProjectSettings.get_setting("stiletto/server_progs","maps/ftew_framework.dat"))
	var client_progs := str(ProjectSettings.get_setting("stiletto/client_progs","maps/ftew_client.dat"))
	if not FileAccess.file_exists(runtime.path_join("base").path_join(progs)) or not FileAccess.file_exists(runtime.path_join("base").path_join(client_progs)):
		show_status("Compile the editor gamecode first with Tools/stiletto/build_gamecode.ps1");return
	var pid := OS.create_process(engine,["-basedir",runtime,"-manifest",runtime.path_join("base.fmf"),"-nohome","-window","-width","1280","-height","720","+set","sv_progs",progs,"+set","sv_csqc_progname",client_progs,"+set","cfg_save_auto","0","+set","webcore_hud","0","+set","webcore_menu_enabled","1","+set","sv_public","0","+set","maxclients","4","+map",scene.map_name + ".ftew"])
	if pid < 0: show_status("FTE could not start. Check the executable setting and its runtime libraries.");return
	show_status("Exported %s. FTE process: %d\nUse the FTE window to play; map geometry changes require re-export/reload." % [scene.map_name,pid])

func open_source() -> void:
	var scene := current()
	if scene == null: return
	if dirty and not save_source(): return
	source_path = scene.map_script
	if source_path.is_empty(): status.text="Set Map Script on the world root to a native .qc file.";return
	source.text = FileAccess.get_file_as_string(source_path)
	dirty = false
	status.text = "Native MapC: " + source_path
	make_bottom_panel_item_visible(panel)

func save_source() -> bool:
	if source_path.is_empty(): return false
	var file := FileAccess.open(source_path,FileAccess.WRITE)
	if file == null: status.text="Cannot save " + source_path;return false
	file.store_string(source.text);file.close();dirty=false
	return true

func compile_map(scene: Node3D, staged_output: String = "") -> bool:
	var compiler := project_path("stiletto/compiler_executable","../fteqcc.exe")
	var runtime := project_path("stiletto/runtime_directory","..")
	var output: Array = []
	# FTEQCC resolves #includelist paths relative to the process directory.
	# A small helper handles the working directory without changing Godot's cwd.
	var helper := runtime.path_join("Tools/stiletto/compile_map.ps1")
	var destination := staged_output if not staged_output.is_empty() else runtime.path_join("base/maps/" + scene.map_name + ".dat")
	var code := OS.execute("powershell.exe",["-NoProfile","-ExecutionPolicy","Bypass","-File",helper,"-Compiler",compiler,"-Source",ProjectSettings.globalize_path(scene.map_script),"-Output",destination],output,true)
	show_status("\n".join(output))
	return code == 0

func compile_source() -> void:
	var scene := current()
	if scene == null: return
	if dirty and not save_source(): return
	compile_map(scene)
