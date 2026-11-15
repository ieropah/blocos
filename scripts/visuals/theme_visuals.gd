class_name ThemeVisuals
extends RefCounted
## Toy-like matte material palette, warm workspace environment, and mobile-friendly studio lighting.

const CORAL_RED: Color = Color(0.90, 0.37, 0.32)
const SUNNY_YELLOW: Color = Color(0.95, 0.74, 0.23)
const COBALT_BLUE: Color = Color(0.24, 0.55, 0.83)
const SAGE_GREEN: Color = Color(0.33, 0.73, 0.53)
const TERRACOTTA: Color = Color(0.93, 0.53, 0.25)
const PLUM_PURPLE: Color = Color(0.62, 0.44, 0.78)

const PLATFORM_TILE_LIGHT: Color = Color(0.91, 0.86, 0.78)
const PLATFORM_TILE_ALT: Color = Color(0.87, 0.81, 0.72)
const PLATFORM_FRAME_WOOD: Color = Color(0.76, 0.62, 0.46)
const STUDIO_BLUE: Color = Color("#3B73B5")
const STUDIO_AMBIENT: Color = Color("#749FD1")
const BACKGROUND_WARM: Color = STUDIO_BLUE

const PREVIEW_VALID_COLOR: Color = Color(0.20, 0.78, 0.42, 0.72)
const PREVIEW_INVALID_COLOR: Color = Color(0.92, 0.24, 0.24, 0.72)
const SELECTION_HIGHLIGHT_COLOR: Color = Color(1.0, 0.88, 0.28, 0.92)


static func get_piece_palette() -> Array[Color]:
	return [
		CORAL_RED,
		SUNNY_YELLOW,
		COBALT_BLUE,
		SAGE_GREEN,
		TERRACOTTA,
		PLUM_PURPLE,
	]


static func create_toy_material(color: Color, roughness: float = 0.62) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.metallic_specular = 0.35
	return mat


static func create_contact_shadow_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.render_priority = 1
	mat.no_depth_test = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


static func create_preview_material(_is_valid: bool, base_color: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.80
	mat.metallic = 0.0
	mat.metallic_specular = 0.22
	mat.emission_enabled = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	mat.render_priority = 2
	return mat


static func create_footprint_indicator_material(is_valid: bool) -> StandardMaterial3D:
	var indicator_color: Color = (
		Color(0.16, 0.86, 0.40, 0.88)
		if is_valid
		else Color(0.95, 0.22, 0.22, 0.88)
	)
	return _create_unshaded_overlay_material(indicator_color, 3)


static func create_selection_material() -> StandardMaterial3D:
	return _create_unshaded_overlay_material(SELECTION_HIGHLIGHT_COLOR, 3)


static func _create_unshaded_overlay_material(color: Color, priority: int = 3) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = priority
	return mat


static func create_workspace_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = STUDIO_BLUE
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = STUDIO_AMBIENT
	env.ambient_light_energy = 0.55
	env.ssao_enabled = false
	env.glow_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	return env


static func setup_studio_lighting(parent: Node3D) -> void:
	if parent == null:
		return

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_color = Color("#FFF8EE")
	key_light.light_energy = 1.15
	key_light.shadow_enabled = true
	key_light.shadow_bias = 0.015
	key_light.shadow_normal_bias = 1.0
	key_light.shadow_blur = 2.8
	key_light.shadow_opacity = 0.65
	key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key_light.directional_shadow_max_distance = 18.0
	key_light.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	parent.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_color = Color("#B5D6FF")
	fill_light.light_energy = 0.42
	fill_light.shadow_enabled = false
	fill_light.rotation_degrees = Vector3(-30.0, 140.0, 0.0)
	parent.add_child(fill_light)
