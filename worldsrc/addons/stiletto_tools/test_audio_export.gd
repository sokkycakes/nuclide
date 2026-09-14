extends SceneTree
const Exporter = preload("exporter.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene := (load("res://maps/editor_lab.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.map_name = "ftew_audio_probe"
	var audio := AudioStreamPlayer.new()
	audio.name = "MusicProbe"
	audio.stream = load("res://assets/sound/music/BGM_00000005.mp3")
	audio.autoplay = true
	audio.volume_db = -6
	audio.pitch_scale = 1.25
	scene.add_child(audio)
	var wav := AudioStreamWAV.new()
	wav.mix_rate = 8000
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	var samples := StreamPeerBuffer.new()
	for i in 2000: samples.put_16(int(12000*sin(TAU*440*i/8000.0)))
	wav.data = samples.data_array
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = 2000
	var tone := AudioStreamPlayer.new()
	tone.name = "LoopProbe";tone.stream = wav;tone.autoplay = true;tone.volume_db = -24
	scene.add_child(tone)
	await process_frame
	await process_frame
	var exporter := Exporter.new()
	var destination := ProjectSettings.globalize_path("res://build/audio-export-test")
	var result: Dictionary = exporter.export_world(scene,destination)
	if not result.ok: failures.append(str(result))
	var found := 0
	for record in exporter.entities:
		if record.classname != "ambient_generic": continue
		found += 1
		if record._nonpositional != "1" or record._autoplay != "1": failures.append("Global/autoplay flags lost")
		if record.message.ends_with("mp3.wav"):
			if absf(float(record.volume)-db_to_linear(-6)) > 0.00001 or float(record.pitch) != 125: failures.append("Volume/pitch lost")
			var sample: PackedByteArray = exporter.files["sound/"+record.message]
			if sample.slice(0,4).get_string_from_ascii() != "RIFF" or sample.size()<100000: failures.append("MP3 was not decoded to PCM")
		elif record.message.ends_with("wav") and record._loop != "1": failures.append("Loop lost")
	if found != 2: failures.append("Missing audio entities")
	audio.autoplay = false
	result = exporter.export_world(scene,destination)
	for record in exporter.entities:
		if record.get("message","").ends_with("mp3.wav") and record._autoplay != "0": failures.append("Autoplay off lost")
	audio.autoplay = true
	# An output can target a plain AudioStreamPlayer (which is not Node3D).
	var connection: Resource = scene.get_node("LightTrigger").outputs[0]
	connection.target = NodePath("../MusicProbe");connection.action = "PlaySound"
	result = exporter.export_world(scene,ProjectSettings.globalize_path("res://../base"))
	if not result.ok: failures.append(str(result))
	print(JSON.stringify({"ok":failures.is_empty(),"errors":failures}))
	scene.free()
	quit(0 if failures.is_empty() else 1)
