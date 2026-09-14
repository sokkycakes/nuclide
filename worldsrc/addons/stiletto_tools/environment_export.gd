@tool
extends RefCounted
## Explicit subset of Godot Environment, compiled to native FTE resources.

static func native_direction(u: float, v: float) -> Vector3:
	var theta := u * TAU
	var latitude := v * PI
	# FTE panorama shader: u=atan(y,-x)/TAU, v=acos(z)/PI.
	# Return the corresponding direction in Godot coordinates.
	return Vector3(-cos(theta)*sin(latitude),cos(latitude),-sin(theta)*sin(latitude))

static func sample_panorama(source: Image, direction: Vector3) -> Color:
	# Godot panorama shader: u=atan(x,-z)/TAU, v=acos(y)/PI.
	var u := fposmod(atan2(direction.x,-direction.z)/TAU,1.0)
	var v := acos(clampf(direction.y,-1,1))/PI
	var x := u*source.get_width()-0.5
	var y := v*source.get_height()-0.5
	var x0 := int(floor(x));var y0 := int(floor(y))
	var a := source.get_pixel(posmod(x0,source.get_width()),clampi(y0,0,source.get_height()-1)).lerp(source.get_pixel(posmod(x0+1,source.get_width()),clampi(y0,0,source.get_height()-1)),x-floor(x))
	var b := source.get_pixel(posmod(x0,source.get_width()),clampi(y0+1,0,source.get_height()-1)).lerp(source.get_pixel(posmod(x0+1,source.get_width()),clampi(y0+1,0,source.get_height()-1)),x-floor(x))
	return a.lerp(b,y-floor(y))

static func gradient_sky(material: ProceduralSkyMaterial, direction: Vector3) -> Color:
	# Static horizon/zenith/ground approximation. Sun and atmosphere are separate.
	var elevation := asin(clampf(absf(direction.y),0,1))/(PI*0.5)
	if direction.y >= 0:
		return material.sky_horizon_color.lerp(material.sky_top_color,pow(elevation,maxf(material.sky_curve,0.01))) * material.sky_energy_multiplier
	return material.ground_horizon_color.lerp(material.ground_bottom_color,pow(elevation,maxf(material.ground_curve,0.01))) * material.ground_energy_multiplier

static func compile(environment: Environment, native_sky: String, width: int = 512) -> Dictionary:
	var result := {"errors":[],"warnings":[],"files":{},"keys":{},"ambient":Color.WHITE,"sky":""}
	if not native_sky.is_empty():
		if native_sky.length() >= 64 or native_sky.begins_with("/") or native_sky.to_ascii_buffer().get_string_from_ascii() != native_sky or not native_sky.replace("/", "_").replace("-","_").is_valid_identifier():
			result.errors.append("Native Sky must be a relative sky basename, e.g. env/fteworld/day.")
		result.keys["skyname"] = native_sky
		result.sky = native_sky
	if environment == null: return result
	if environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR:
		result.ambient = environment.ambient_light_color * environment.ambient_light_energy
		result.ambient.a = 1.0
		result.warnings.append("Ambient Color is baked into static vertex lighting; this is an approximation, not Godot GI or player lighting.")
	elif environment.ambient_light_source != Environment.AMBIENT_SOURCE_DISABLED:
		result.warnings.append("Sky-derived ambient/reflection lighting is not exported yet. Use Ambient Light > Source: Color for a static tint.")
	if environment.fog_enabled:
		result.warnings.append("Godot fog is not exported yet; use native fog from the console or world_properties._fog.")
	if not native_sky.is_empty(): return result
	var panorama: Image
	var material: Material
	if environment.background_mode == Environment.BG_SKY:
		if environment.sky == null or environment.sky.sky_material == null:
			result.errors.append("WorldEnvironment uses Sky but has no sky material.");return result
		material = environment.sky.sky_material
		if material is PanoramaSkyMaterial:
			if material.panorama == null: result.errors.append("PanoramaSkyMaterial needs a panorama texture.");return result
			panorama = material.panorama.get_image()
			if panorama == null or panorama.is_empty(): result.errors.append("Cannot read sky panorama pixels.");return result
			if panorama.is_compressed() and panorama.decompress() != OK: result.errors.append("Cannot decompress sky panorama.");return result
		elif material is ProceduralSkyMaterial:
			result.warnings.append("Procedural sky exports its static color gradient. Sun disks, sky cover and atmospheric scattering are not baked.")
		else:
			result.errors.append("Use PanoramaSkyMaterial, ProceduralSkyMaterial, a Color background, or Native Sky. Custom/Physical sky shaders need a panorama bake first.");return result
	elif environment.background_mode not in [Environment.BG_COLOR,Environment.BG_CLEAR_COLOR]:
		result.errors.append("This WorldEnvironment background mode cannot be exported.");return result
	var output := Image.create(width,width/2,false,Image.FORMAT_RGBA8)
	var rotation := Basis.from_euler(environment.sky_rotation).inverse()
	var background: Color = environment.background_color if environment.background_mode == Environment.BG_COLOR else ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color",Color.BLACK)
	for y in range(output.get_height()):
		for x in range(width):
			var direction := rotation * native_direction((x+0.5)/width,(y+0.5)/output.get_height())
			var color := background
			if panorama != null: color = sample_panorama(panorama,direction)
			elif material is ProceduralSkyMaterial: color = gradient_sky(material,direction)
			color *= environment.background_energy_multiplier
			color.a = 1.0
			output.set_pixel(x,y,color.clamp())
	var bytes := output.save_png_to_buffer()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	# FTE strips directory components when applying fallback search prefixes.
	# Nested panorama names therefore need their full game-relative env/ path.
	var sky := "env/fteworld/" + hash.finish().hex_encode().substr(0,16)
	result.files[sky + ".png"] = bytes
	result.keys["skyname"] = sky
	result.sky = sky
	result.warnings.append("Exported sky is an LDR PNG; HDR values above 1 are clamped. Tonemapping/post-processing are not transferred.")
	return result
