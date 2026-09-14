@tool
extends RefCounted
## FTEW v1 compiler. Godot evaluates scene resources; FTE reads native data only.
const EntityType = preload("nodes/entity.gd")
const MeshType = preload("nodes/mesh.gd")
const WorldType = preload("nodes/world.gd")
const ConnectionType = preload("nodes/connection.gd")
const EnvironmentExport = preload("environment_export.gd")
var ambient_tint := Color.WHITE
var environment_nodes: Array[WorldEnvironment] = []
var sky_name: String = ""
var world_bounds: AABB
var have_world_bounds := false
var sun_records: Array[Dictionary] = []
var errors: Array[String] = []
var warnings: Array[String] = []
var materials: Array[String] = []
var meshes: Array[Dictionary] = []
var instances: Array[Dictionary] = []
var colliders: Array[Dictionary] = []
var entities: Array[Dictionary] = []
var files: Dictionary = {}
var mesh_cache: Dictionary = {}
var ids: Dictionary = {}
var root: Node3D
var scale_units: float = 32.0
var model_count: int = 1
var map_name: String

func digest_bytes(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()

func fail(node: Node, message: String) -> void:
	errors.append("%s: %s" % [root.get_path_to(node), message])

func position(v: Vector3) -> Vector3:
	return Vector3(v.x, -v.z, v.y) * scale_units

func valid_transform(t: Transform3D) -> bool:
	if not t.is_finite(): return false
	# Test axis independence, not volume: valid import unit scales can be tiny.
	var b := t.basis
	if b.x.length_squared() == 0 or b.y.length_squared() == 0 or b.z.length_squared() == 0: return false
	return absf(Basis(b.x.normalized(), b.y.normalized(), b.z.normalized()).determinant()) >= 0.000001

func native_transform(t: Transform3D) -> Array:
	# Mesh coordinates are already in FTE units. Convert a basis by C * B * C^-1.
	return [position(t.basis.x) / scale_units, -position(t.basis.z) / scale_units,
		position(t.basis.y) / scale_units, position(t.origin)]

func vec_text(v: Vector3) -> String:
	return "%.6f %.6f %.6f" % [v.x, v.y, v.z]

func safe_text(value: String) -> bool:
	for i in range(value.length()):
		if value.unicode_at(i) < 32: return false
	return not (value.contains('"') or value.contains("\\"))

func node_id(node: Node) -> String:
	if ids.has(node): return ids[node]
	var value: String = node.entity_id if node is EntityType else ""
	if value.is_empty(): value = "fte_" + str(root.get_path_to(node)).sha256_text().substr(0, 16)
	if not value.is_valid_identifier(): fail(node, "Entity ID must contain only letters, numbers and underscores, and not start with a number.")
	if ids.values().has(value): fail(node, "Duplicate entity ID: " + value)
	ids[node] = value
	return value

func material_for(node: Node, material: Material, native: String) -> int:
	var path: String = native
	if path.is_empty():
		var color := Color(0.65, 0.7, 0.76)
		var texture: Texture2D
		var unlit := false
		if material is StandardMaterial3D:
			color = material.albedo_color
			texture = material.albedo_texture
			unlit = material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
			if material.normal_enabled or material.emission_enabled or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				fail(node, "This first exporter supports opaque albedo materials. Use fte_material for an existing richer native material.")
		elif material != null:
			fail(node, "Use a StandardMaterial3D or an explicit fte_material override.")
		var img: Image
		if texture:
			img = texture.get_image()
			if img == null or img.is_empty():
				fail(node, "Cannot read material texture.")
				return 0
			if img.is_compressed(): img.decompress()
			img.convert(Image.FORMAT_RGBA8)
		else:
			img = Image.create(2, 2, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
		# Bake tint into the generated texture for simple native materials.
		if color != Color.WHITE:
			for y in range(img.get_height()):
				for x in range(img.get_width()): img.set_pixel(x, y, img.get_pixel(x, y) * color)
		var png := img.save_png_to_buffer()
		var digest := digest_bytes(png).substr(0, 16)
		path = "textures/fteworld/" + digest + ("_u" if unlit else "_vl")
		files[path + ".png"] = png
		# Vertex-lit path does not require a BSP lightmap. Native rtlight passes are selected by FTE.
		var program := "unlit" if unlit else "defaultwall#VERTEXLIT"
		var stage := "" if unlit else " {\n  map $diffuse\n  rgbgen vertex\n  alphagen vertex\n }\n"
		files[path + ".mat"] = ("{\n program %s\n diffusemap %s.png\n%s}\n" % [program, path, stage]).to_utf8_buffer()
	if path.to_ascii_buffer().get_string_from_ascii() != path or path.length() >= 64 or not safe_text(path) or path.contains("..") or path.contains(":") or path.contains(";") or path.begins_with("/") or path.contains(" "):
		fail(node, "Native material must be a game-relative path shorter than 64 characters.")
	if not materials.has(path): materials.append(path)
	return materials.find(path)

func add_mesh(node: Node3D, mesh: Mesh, transform: Transform3D, flags: int, native: String = "", override: Material = null) -> void:
	if not valid_transform(transform):
		fail(node, "Mesh transform is non-finite or collapsed (zero scale or dependent axes); check this node and its parents.")
		return
	for surface in range(mesh.get_surface_count()):
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			fail(node, "Only triangle mesh surfaces are supported.")
			continue
		var material: Material = override if override != null else mesh.surface_get_material(surface)
		if node is MeshInstance3D and override == null:
			material = node.get_active_material(surface)
		var mi := material_for(node, material, native)
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in range(vertices.size()): indices.append(i)
		if vertices.size() < 3 or vertices.size() > 65535 or indices.is_empty() or indices.size() % 3 != 0:
			fail(node, "Split surfaces exceeding 65535 vertices; indices must form triangles.")
			continue
		if (not uv.is_empty() and uv.size() != vertices.size()) or (not colors.is_empty() and colors.size() != vertices.size()):
			fail(node,"Vertex attribute count mismatch.");continue
		for index in indices:
			if index < 0 or index >= vertices.size(): fail(node,"Mesh index out of range.")
		var vertex_data := StreamPeerBuffer.new()
		for i in range(vertices.size()):
			var world_vertex := position(transform * vertices[i])
			if not have_world_bounds:
				world_bounds = AABB(world_vertex,Vector3.ZERO);have_world_bounds = true
			else: world_bounds = world_bounds.expand(world_vertex)
			var v := position(vertices[i])
			var tex := uv[i] if not uv.is_empty() else Vector2.ZERO
			var color := colors[i] if not colors.is_empty() else Color.WHITE
			if native.is_empty() and not (material is StandardMaterial3D and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED): color *= ambient_tint
			if not v.is_finite() or not tex.is_finite() or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a): fail(node,"Non-finite mesh vertex.")
			for f in [v.x,v.y,v.z,tex.x,tex.y,color.r,color.g,color.b,color.a]: vertex_data.put_float(f)
		var index_data := StreamPeerBuffer.new()
		for i in range(0, indices.size(), 3):
			# FTE's BIH and renderer also use clockwise front faces.
			# Coordinate conversion preserves handedness, so preserve winding.
			for j in [0,1,2]: index_data.put_u32(indices[i+j])
		var cache_key := str(mi) + ":" + vertex_data.data_array.hex_encode().sha256_text() + index_data.data_array.hex_encode().sha256_text()
		var mesh_id: int
		if mesh_cache.has(cache_key): mesh_id = mesh_cache[cache_key]
		else:
			mesh_id = meshes.size()
			mesh_cache[cache_key] = mesh_id
			meshes.append({"material":mi,"vertices":vertices.size(),"indices":indices.size(),"v":vertex_data.data_array,"idx":index_data.data_array})
		instances.append({"mesh":mesh_id,"model":0,"flags":flags,"transform":native_transform(transform),"source":str(root.get_path_to(node))})

func add_box(node: CollisionShape3D, model: int, offset: Vector3) -> void:
	if not node.shape is BoxShape3D:
		fail(node, "This first exporter supports BoxShape3D collision volumes.")
		return
	var half: Vector3 = node.shape.size * 0.5
	var t := node.global_transform
	if not valid_transform(t):
		fail(node, "Collider transform is non-finite or collapsed (zero scale or dependent axes); check this node and its parents.")
		return
	var corners: Array[Vector3] = []
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]: corners.append(position(t * (half * Vector3(x,y,z))) - offset)
	var mins := corners[0]
	var maxs := corners[0]
	for corner in corners: mins = mins.min(corner); maxs = maxs.max(corner)
	var planes: Array = []
	for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
		for sign_value in [-1,1]:
			var n: Vector3 = (t.basis.inverse().transposed() * axis * sign_value).normalized()
			var nf := position(n).normalized()
			var point := position(t * (half * axis * sign_value)) - offset
			planes.append([nf.x,nf.y,nf.z,nf.dot(point)])
	# Axial bevels improve swept player-box collision on rotated volumes.
	for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
		for sign_value in [-1,1]:
			var n: Vector3 = axis * sign_value
			var d := -INF
			for corner in corners: d = maxf(d, n.dot(corner))
			planes.append([n.x,n.y,n.z,d])
	colliders.append({"model":model,"mins":mins,"maxs":maxs,"planes":planes})

func add_entity(node: Node3D) -> void:
	var record: Dictionary = node.properties.duplicate()
	record["classname"] = node.classname
	record["targetname"] = node_id(node)
	var origin := position(node.global_position)
	record["origin"] = vec_text(origin)
	var forward := position(-node.global_basis.z).normalized()
	record["angles"] = "%.6f %.6f 0" % [-rad_to_deg(asin(clampf(forward.z,-1,1))), rad_to_deg(atan2(forward.y,forward.x))]
	var shapes: Array[Node] = []
	for child in node.get_children():
		if child is CollisionShape3D: shapes.append(child)
		elif child is Area3D:
			for shape in child.get_children():
				if shape is CollisionShape3D: shapes.append(shape)
	if not shapes.is_empty():
		record["model"] = "*%d" % model_count
		# Collider coordinates already include the node's rotation.
		record["angles"] = "0 0 0"
		for shape in shapes:
			if not shape.disabled: add_box(shape, model_count, origin)
		model_count += 1
	for connection in node.outputs:
		if not connection is ConnectionType:
			fail(node, "Outputs must be FTEConnection resources.")
			continue
		if connection.target.is_empty() or connection.event.is_empty() or connection.action.is_empty() or not is_finite(connection.delay) or connection.delay < 0 or connection.fire_count < -1:
			fail(node,"Output needs a target, event, action, valid delay and fire count.");continue
		var target := node.get_node_or_null(connection.target)
		if target == null or not (target is EntityType or target is OmniLight3D or target is DirectionalLight3D or target is AudioStreamPlayer):
			fail(node, "Output target does not reference an exported entity: " + str(connection.target))
			continue
		for value in [connection.event, connection.action, connection.parameter]:
			if str(value).contains(",") or str(value).contains(";") or not safe_text(str(value)): fail(node, "Invalid output field.")
		var output := "%s,%s,%s,%.6f,%d" % [node_id(target),connection.action,connection.parameter,connection.delay,connection.fire_count]
		if record.has(connection.event): fail(node, "One connection per event is supported in this first exporter; use a relay for fan-out.")
		record[connection.event] = output
	entities.append(record)

func add_audio(node: AudioStreamPlayer) -> void:
	var audio := node.stream
	if audio == null:
		fail(node,"AudioStreamPlayer needs an audio stream.");return
	var bytes := PackedByteArray()
	var extension := ""
	var loops := false
	if audio is AudioStreamMP3:
		# Decode with Godot; the minimal native runtime does not reliably decode MP3.
		# Keep the authored MP3 untouched and package stereo PCM for native playback.
		extension = "mp3.wav";loops = audio.loop
		if audio.loop_offset != 0: fail(node,"Audio loop offsets are not supported yet; use a whole-file loop.")
		var source := audio.duplicate() as AudioStreamMP3
		source.loop = false
		var playback := source.instantiate_playback()
		var rate := int(AudioServer.get_mix_rate())
		var remaining := int(ceil(source.get_length()*rate))
		if remaining <= 0 or remaining > rate*1800:
			fail(node,"MP3 duration must be between zero and 30 minutes.");return
		var pcm := StreamPeerBuffer.new()
		playback.start()
		while remaining > 0:
			var count := mini(4096,remaining)
			var frames := playback.mix_audio(1.0,count)
			for frame in frames:
				pcm.put_16(int(clampf(frame.x,-1.0,1.0)*32767))
				pcm.put_16(int(clampf(frame.y,-1.0,1.0)*32767))
			remaining -= count
			# Compressed duration estimates can exceed the final decoded block.
			if frames.size() < count: break
		playback.stop()
		if pcm.get_size() == 0: fail(node,"MP3 decoder returned no audio samples.");return
		var wave := StreamPeerBuffer.new()
		wave.put_data("RIFF".to_ascii_buffer());wave.put_u32(36+pcm.get_size())
		wave.put_data("WAVEfmt ".to_ascii_buffer());wave.put_u32(16)
		wave.put_u16(1);wave.put_u16(2);wave.put_u32(rate);wave.put_u32(rate*4)
		wave.put_u16(4);wave.put_u16(16)
		wave.put_data("data".to_ascii_buffer());wave.put_u32(pcm.get_size());wave.put_data(pcm.data_array)
		bytes = wave.data_array
	elif audio is AudioStreamOggVorbis:
		extension = "ogg";loops = audio.loop
		if audio.loop_offset != 0: fail(node,"Audio loop offsets are not supported yet; use a whole-file loop.")
		if audio.resource_path.get_extension().to_lower() == "ogg": bytes = FileAccess.get_file_as_bytes(audio.resource_path)
		else: fail(node,"Ogg streams must reference an imported .ogg source file.")
	elif audio is AudioStreamWAV:
		extension = "wav";loops = audio.loop_mode != AudioStreamWAV.LOOP_DISABLED
		if loops and (audio.loop_mode != AudioStreamWAV.LOOP_FORWARD or audio.loop_begin != 0 or absf(float(audio.loop_end)/audio.mix_rate - audio.get_length()) > 1.0/audio.mix_rate):
			fail(node,"WAV audio currently supports only whole-file forward loops.")
		# Export decoded resource settings, including import-time conversion.
		var temporary := ProjectSettings.globalize_path("res://build/audio-export.wav")
		DirAccess.make_dir_recursive_absolute(temporary.get_base_dir())
		if audio.save_to_wav(temporary) == OK: bytes = FileAccess.get_file_as_bytes(temporary)
		else: fail(node,"WAV export failed; use PCM WAV, Ogg or MP3.")
	else:
		fail(node,"AudioStreamPlayer supports MP3, Ogg Vorbis and WAV streams; composite streams are not mapped yet.");return
	if bytes.is_empty(): fail(node,"Audio stream has no readable sample data.");return
	if not is_finite(node.volume_db) or not is_finite(node.pitch_scale) or node.pitch_scale <= 0:
		fail(node,"Audio volume and pitch must be finite, with positive pitch.");return
	if node.max_polyphony != 1: fail(node,"AudioStreamPlayer currently supports one voice per node; use separate nodes for overlapping sounds.")
	if node.bus != &"Master": warnings.append("%s: Audio bus '%s' is not mapped; native playback uses FTE's master sound volume." % [root.get_path_to(node),node.bus])
	var path := "fteworld/" + digest_bytes(bytes).substr(0,16) + "." + extension
	files["sound/" + path] = bytes
	entities.append({"classname":"ambient_generic","targetname":node_id(node),"origin":"0 0 0","message":path,"volume":str(db_to_linear(node.volume_db)),"pitch":str(node.pitch_scale*100.0),"_nonpositional":"1","_autoplay":"1" if node.autoplay else "0","_loop":"1" if loops else "0"})

func visit(node: Node) -> void:
	if node != root and node.get_meta("fte_ignore",false): return
	if node is EntityType: add_entity(node)
	elif node is AudioStreamPlayer: add_audio(node)
	elif node is MeshInstance3D and node.mesh:
		var ancestor := node.get_parent()
		while ancestor != root and ancestor != null:
			if ancestor is EntityType: fail(node,"Moving entity meshes are not supported yet; mesh children would remain static.");return
			ancestor = ancestor.get_parent()
		var mode: int = node.export_mode if node is MeshType else 0
		add_mesh(node,node.mesh,node.global_transform,[3,1,2][mode],node.fte_material if node is MeshType else "",node.material_override)
	elif node is CSGShape3D:
		if node.is_root_shape():
			var result: Array = node.get_meshes()
			if result.size() == 2: add_mesh(node,result[1],node.global_transform * result[0],3 if node.use_collision else 1)
			else: fail(node,"CSG did not produce an evaluated mesh.")
		return
	elif node is OmniLight3D or node is DirectionalLight3D:
		var c: Color = node.light_color
		var record := {"classname":"light_dynamic","targetname":node_id(node),"origin":vec_text(position(node.global_position)),"_light":"%d %d %d" % [c.r8,c.g8,c.b8],"brightness":str(node.light_energy),"start_active":"1" if node.is_visible_in_tree() else "0","_cone":"0","_shadows":"1" if node.shadow_enabled else "0"}
		if node is DirectionalLight3D:
			# Godot emits along local -Z; FTE's light axis is local +X.
			var direction := position(-node.global_basis.z).normalized()
			if not direction.is_finite() or direction.length_squared() < 0.99:
				fail(node,"Directional light needs a finite, nonzero forward direction.")
			record["angles"] = vec_text(Vector3(rad_to_deg(atan2(-direction.z,Vector2(direction.x,direction.y).length())),rad_to_deg(atan2(direction.y,direction.x)),0))
			record["origin"] = "0 0 0" # Directional lights are independent of node position.
			record["_directional"] = "1"
			record["distance"] = str(maxf(node.directional_shadow_max_distance,1.0)*scale_units)
			sun_records.append(record)
			warnings.append("Directional light uses native parallel rays and a single camera-following shadow map. Cascades, shadow bias, sky-only mode and light masks are not mapped.")
		else: record["distance"] = str(node.omni_range*scale_units)
		entities.append(record)
	elif node is CollisionShape3D:
		if node.get_parent() is StaticBody3D and not node.disabled: add_box(node,0,Vector3.ZERO)
		elif not node.get_parent() is EntityType and not (node.get_parent() is Area3D and node.get_parent().get_parent() is EntityType):
			fail(node,"Collision shape needs StaticBody3D or FTEEntity3D ownership.")
	elif node is Camera3D or node is WorldEnvironment:
		pass # editor preview only
	elif node != root and node.get_script() != null:
		fail(node,"Unsupported script; use native FTE entities or mark this node fte_ignore.")
	elif node != root and node.get_class() not in ["Node3D","Marker3D","StaticBody3D","Area3D"]:
		fail(node,"Unsupported node type: " + node.get_class())
	for child in node.get_children(): visit(child)

func find_environment(node: Node) -> void:
	if node != root and node.get_meta("fte_ignore",false): return
	if node is WorldEnvironment and node.environment != null: environment_nodes.append(node)
	for child in node.get_children(): find_environment(child)

func serialize_entities() -> PackedByteArray:
	var result := ""
	for record in entities:
		result += "{\n"
		var keys: Array = record.keys()
		keys.sort()
		for key in keys:
			var value := str(record[key])
			if not safe_text(str(key)) or not safe_text(value): errors.append("Entity key/value contains unsupported quoting or control characters: " + str(key))
			result += '"%s" "%s"\n' % [key,value]
		result += "}\n"
	# The terminator is binary, not text. Editor script reload/serialization can
	# replace a NUL string literal with U+FFFD, producing an invalid ENTS section.
	var bytes := result.to_utf8_buffer()
	bytes.append(0)
	return bytes

func binary() -> PackedByteArray:
	var sections: Array = []
	var stream := StreamPeerBuffer.new()
	for material in materials:
		var bytes := material.to_utf8_buffer()
		stream.put_u32(bytes.size()); stream.put_data(bytes)
	sections.append(["MATL",stream.data_array,materials.size()])
	stream = StreamPeerBuffer.new()
	for mesh in meshes:
		stream.put_u32(mesh.material);stream.put_u32(mesh.vertices);stream.put_u32(mesh.indices)
		stream.put_data(mesh.v);stream.put_data(mesh.idx)
	sections.append(["MESH",stream.data_array,meshes.size()])
	stream = StreamPeerBuffer.new()
	for instance in instances:
		stream.put_u32(instance.mesh);stream.put_u32(instance.model);stream.put_u32(instance.flags)
		for v in instance.transform:
			for f in [v.x,v.y,v.z]: stream.put_float(f)
	sections.append(["INST",stream.data_array,instances.size()])
	stream = StreamPeerBuffer.new()
	for collider in colliders:
		stream.put_u32(collider.model);stream.put_u32(1)
		for v in [collider.mins,collider.maxs]:
			for f in [v.x,v.y,v.z]: stream.put_float(f)
		stream.put_u32(collider.planes.size())
		for plane in collider.planes:
			for f in plane: stream.put_float(f)
	sections.append(["COLL",stream.data_array,colliders.size()])
	sections.append(["ENTS",serialize_entities(),1])
	var total := 96
	for section in sections: total += section[1].size()
	stream = StreamPeerBuffer.new()
	stream.put_data("FTEW".to_ascii_buffer());stream.put_u32(1);stream.put_u32(total);stream.put_u32(model_count)
	var offset := 96
	for section in sections:
		stream.put_data(section[0].to_ascii_buffer());stream.put_u32(offset);stream.put_u32(section[1].size());stream.put_u32(section[2])
		offset += section[1].size()
	for section in sections: stream.put_data(section[1])
	return stream.data_array

func export_world(scene: Node3D, output_dir: String) -> Dictionary:
	errors.clear();warnings.clear();materials.clear();meshes.clear();instances.clear()
	colliders.clear();entities.clear();files.clear();mesh_cache.clear();ids.clear();model_count=1
	environment_nodes.clear();ambient_tint=Color.WHITE;sky_name=""
	sun_records.clear();have_world_bounds=false
	root = scene
	if not root is WorldType:
		return {"ok":false,"errors":["Scene root must be FTEWorld3D."],"warnings":[]}
	scale_units = float(ProjectSettings.get_setting("stiletto/units_per_meter",32.0))
	map_name = root.map_name
	if not map_name.is_valid_identifier() or map_name.length()>32 or not is_finite(scale_units) or scale_units<=0:
		return {"ok":false,"errors":["Invalid map name or unit scale."],"warnings":[]}
	var world_record: Dictionary = root.world_properties.duplicate()
	world_record.merge({"classname":"worldspawn","message":root.title},true)
	find_environment(root)
	if environment_nodes.size() > 1: errors.append("Export requires one active WorldEnvironment; mark unused environment subtrees fte_ignore.")
	var environment: Environment = environment_nodes[0].environment if not environment_nodes.is_empty() else null
	# Existing editor instances can retain Nil for a newly added property after
	# a tool-script hot reload, even when its declaration has a String default.
	var native_sky: Variant = root.get("native_sky")
	var sky_override: String = native_sky if native_sky is String and not native_sky.is_empty() else str(world_record.get("skyname",""))
	var environment_result: Dictionary = EnvironmentExport.compile(environment,sky_override)
	errors.append_array(environment_result.errors);warnings.append_array(environment_result.warnings)
	files.merge(environment_result.files);world_record.merge(environment_result.keys,true)
	ambient_tint=environment_result.ambient;sky_name=environment_result.sky
	entities.append(world_record)
	visit(root)
	# Keep every authored surface in the sun's render volume, regardless of
	# its distance from the light node. Native shadows use the same volume.
	for sun in sun_records:
		sun["distance"] = str(maxf(float(sun.distance),world_bounds.size.length()*2.0 if have_world_bounds else 32.0))
	var data := binary()
	var tris := 0
	for instance in instances: tris += int(meshes[instance.mesh].indices / 3)
	if tris>50000 or meshes.size()>4096 or instances.size()>16384 or model_count>1024: errors.append("FTEW v1 resource budget exceeded.")
	if not errors.is_empty(): return {"ok":false,"errors":errors,"warnings":warnings}
	files["maps/%s.ftew" % map_name] = data
	# Generated textures are content-addressed; publish the world last.
	var paths: Array = files.keys()
	paths.sort()
	paths.erase("maps/%s.ftew" % map_name)
	paths.append("maps/%s.ftew" % map_name)
	for path in paths:
		var destination := output_dir.path_join(path)
		if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK: errors.append("Cannot create " + destination.get_base_dir());break
		var file := FileAccess.open(destination + ".tmp",FileAccess.WRITE)
		if file == null: errors.append("Cannot write " + destination);break
		file.store_buffer(files[path]);file.close()
		if DirAccess.rename_absolute(destination + ".tmp",destination) != OK: errors.append("Cannot publish " + destination);break
	var report := {"ok":errors.is_empty(),"errors":errors,"warnings":warnings,"map":map_name,"meshes":meshes.size(),"instances":instances.size(),"triangles":tris,"colliders":colliders.size(),"entities":entities.size(),"models":model_count,"files":paths,"sha256":digest_bytes(data)}
	report["sky"] = sky_name
	return report
