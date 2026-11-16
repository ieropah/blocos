class_name PlatformController
extends Node3D
## Builds and manages the modular toy building platform with its top surface at y = 0.0.

const ToyMeshBuilder = preload("res://scripts/visuals/toy_mesh_builder.gd")

const _DEFAULT_VISUAL_GRID_SIZE: int = 12
const _FLOOR_SIZE: float = 60.0
const _COLLIDER_HEIGHT: float = 0.2
const _DOT_RADIUS: float = 0.055
const _DOT_HEIGHT: float = 0.002
const _DOT_Y: float = 0.003
const _VOXEL_WORLD_SIZE: float = 160.0
const _VOXEL_WORLD_THICKNESS: float = 2.0
const _VOXEL_WORLD_TOP_Y: float = 0.0
const _VOXEL_PERIMETER_LINE_WIDTH: float = 0.07
const _CLOUD_DRIFT_SPEED: float = 0.55
const _CLOUD_WRAP_LIMIT: float = 60.0

static var _shared_box_meshes: Dictionary = {}
static var _shared_flat_materials: Dictionary = {}
static var _shared_triplanar_materials: Dictionary = {}
static var _shared_blob_shadow_mesh: QuadMesh = null
static var _shared_blob_shadow_mat: StandardMaterial3D = null

var current_theme_id: String = "plastic"

var _board_size: int = _DEFAULT_VISUAL_GRID_SIZE
var _mode_id: String = ""
var _theme_id: String = "plastic"
var _tile_count: int = 0
var _built: bool = false
var _floor_mat: StandardMaterial3D = null
var _board_mat: StandardMaterial3D = null
var _dot_mat: StandardMaterial3D = null
var _floor_instance: MeshInstance3D = null
var _dots_mmi: MultiMeshInstance3D = null
var _mode_stage_root: Node3D = null
var _voxel_world_root: Node3D = null
var _clouds_root: Node3D = null
var _voxel_animals: Array[Dictionary] = []
var _anim_time: float = 0.0

var _target_world_env: WorldEnvironment = null
var _owned_world_env: WorldEnvironment = null
var _default_environment: Environment = null
var _has_captured_default_env: bool = false
var _voxel_environment: Environment = null
var _solid_environment: Environment = null
var _target_dir_light: DirectionalLight3D = null
var _owned_dir_light: DirectionalLight3D = null
var _has_captured_default_light: bool = false
var _default_light_state: Dictionary = {}


func _ready() -> void:
	if not _built:
		build_platform(_board_size)
	set_process(current_theme_id == "voxel")


func _process(delta: float) -> void:
	if current_theme_id != "voxel":
		return
	_anim_time += delta
	if _clouds_root != null and _clouds_root.visible:
		for child in _clouds_root.get_children():
			if child is Node3D:
				var cloud := child as Node3D
				cloud.position.x += _CLOUD_DRIFT_SPEED * delta
				if cloud.position.x > _CLOUD_WRAP_LIMIT:
					cloud.position.x = -_CLOUD_WRAP_LIMIT
	for animal in _voxel_animals:
		var root_node := animal.get("root") as Node3D
		if root_node == null or not is_instance_valid(root_node):
			continue
		var phase: float = float(animal.get("phase", 0.0))
		var speed: float = float(animal.get("speed", 1.8))
		var base_y: float = float(animal.get("base_y", 0.0))
		var base_rot_y: float = float(animal.get("base_rot_y", 0.0))
		var t: float = _anim_time * speed + phase
		var hop: float = maxf(0.0, sin(t))
		root_node.position.y = base_y + hop * hop * 0.055
		root_node.rotation.y = base_rot_y + sin(t * 0.45) * 0.16


## Updates the active theme ("plastic", "voxel", "wood") and refreshes platform and environment visuals.
func set_theme(theme_id: String) -> void:
	var theme_changed: bool = (current_theme_id != theme_id)
	current_theme_id = theme_id
	_theme_id = theme_id
	if theme_changed:
		ToyMeshBuilder.clear_cache()
		_purge_shared_caches()
		_free_voxel_background_nodes()
		if theme_id != "voxel":
			_voxel_environment = null
	if not _built:
		build_platform(_board_size)
		return
	_apply_theme_materials()
	_apply_theme_environment()
	set_process(current_theme_id == "voxel")


static func _purge_shared_caches() -> void:
	_shared_box_meshes.clear()
	_shared_flat_materials.clear()
	_shared_triplanar_materials.clear()
	_shared_blob_shadow_mesh = null
	_shared_blob_shadow_mat = null


func _free_voxel_background_nodes() -> void:
	_voxel_animals.clear()
	if _voxel_world_root != null and is_instance_valid(_voxel_world_root):
		remove_child(_voxel_world_root)
		_voxel_world_root.queue_free()
	_voxel_world_root = null
	if _clouds_root != null and is_instance_valid(_clouds_root):
		remove_child(_clouds_root)
		_clouds_root.queue_free()
	_clouds_root = null


## Applies theme-specific floor and board colors ("plastic", "voxel", "wood").
func set_theme_style(theme_id: String) -> void:
	set_theme(theme_id)


## Dynamically resizes the board surface, collision shape, and grid dots for 8x8, 12x12, or 16x16.
func set_grid_size(size: int) -> void:
	var target_size: int = maxi(size, 1)
	if _built and _board_size == target_size:
		return
	build_platform(target_size)


## Sets the active play mode ("character", "animal", "vehicle", "scenery") and updates stage visuals.
func set_mode(mode_id: String) -> void:
	if _mode_id == mode_id and _built:
		return
	_mode_id = mode_id
	if _built:
		_rebuild_mode_stage()
		_apply_theme_materials()


func get_mode_id() -> String:
	return _resolve_effective_mode_id()


func _resolve_effective_mode_id() -> String:
	if not _mode_id.is_empty():
		return _mode_id
	if _board_size == 12:
		return "vehicle"
	if _board_size >= 16:
		return "scenery"
	return "character"


func build_platform(board_size: int = _DEFAULT_VISUAL_GRID_SIZE) -> void:
	_clear_generated_nodes()
	_board_size = maxi(board_size, 1)
	_tile_count = 0
	var board_world_size: float = float(_board_size) * PieceCatalog.GRID_UNIT_SIZE

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(_FLOOR_SIZE, _FLOOR_SIZE)
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.roughness = 0.95
	_floor_mat.metallic = 0.0
	_floor_mat.metallic_specular = 0.05

	_floor_instance = MeshInstance3D.new()
	_floor_instance.name = "StudioFloor"
	_floor_instance.mesh = floor_mesh
	_floor_instance.material_override = _floor_mat
	_floor_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor_instance.position = Vector3.ZERO
	add_child(_floor_instance)

	var board_mesh := PlaneMesh.new()
	board_mesh.size = Vector2(board_world_size, board_world_size)
	_board_mat = StandardMaterial3D.new()
	_board_mat.roughness = 0.92
	_board_mat.metallic = 0.0
	_board_mat.metallic_specular = 0.06

	var board_instance := MeshInstance3D.new()
	board_instance.name = "BoardSurface"
	board_instance.mesh = board_mesh
	board_instance.material_override = _board_mat
	board_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board_instance.position = Vector3(0.0, 0.001, 0.0)
	add_child(board_instance)

	var collider_body := StaticBody3D.new()
	collider_body.name = "BoardCollider"
	collider_body.position = Vector3(0.0, -_COLLIDER_HEIGHT * 0.5, 0.0)
	var collider_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(board_world_size, _COLLIDER_HEIGHT, board_world_size)
	collider_shape.shape = box_shape
	collider_body.add_child(collider_shape)
	add_child(collider_body)

	var dot_mesh := CylinderMesh.new()
	dot_mesh.top_radius = _DOT_RADIUS
	dot_mesh.bottom_radius = _DOT_RADIUS
	dot_mesh.height = _DOT_HEIGHT
	dot_mesh.radial_segments = 14

	_dot_mat = StandardMaterial3D.new()
	_dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dot_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.16)
	_dot_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_dot_mat.render_priority = 1

	var dot_positions: Array[Vector3] = []
	for gz in range(_board_size):
		for gx in range(_board_size):
			var tile_pos := get_tile_position(gx, gz)
			tile_pos.y = 0.002
			dot_positions.append(tile_pos)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dot_mesh
	multimesh.instance_count = dot_positions.size()
	for i in range(dot_positions.size()):
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, dot_positions[i]))

	_dots_mmi = MultiMeshInstance3D.new()
	_dots_mmi.name = "GridDotMarkers"
	_dots_mmi.multimesh = multimesh
	_dots_mmi.material_override = _dot_mat
	_dots_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dots_mmi)

	if current_theme_id == "voxel":
		_build_voxel_world(board_world_size)
		_build_voxel_clouds()

	_tile_count = dot_positions.size()
	_built = true
	_rebuild_mode_stage()
	_apply_theme_materials()
	_apply_theme_environment()
	set_process(current_theme_id == "voxel")


func get_tile_count() -> int:
	return _tile_count


func get_board_size() -> int:
	return _board_size


func get_tile_position(grid_x: int, grid_z: int) -> Vector3:
	var unit_footprint := Vector3(PieceCatalog.GRID_UNIT_SIZE, _DOT_HEIGHT, PieceCatalog.GRID_UNIT_SIZE)
	var pos := PieceCatalog.grid_to_piece_center_base(
		Vector3i(grid_x, 0, grid_z),
		unit_footprint,
		0,
		_board_size
	)
	pos.y = 0.0
	return pos


func _apply_theme_materials() -> void:
	var is_voxel: bool = (current_theme_id == "voxel")
	var is_solid: bool = (current_theme_id == "solid")
	var effective_mode: String = _resolve_effective_mode_id()
	var floor_col: Color = ThemeVisuals.STUDIO_BLUE
	var board_col: Color = ThemeVisuals.STUDIO_BLUE.lightened(0.06)
	if is_solid:
		floor_col = Color("#08C6F7")
		board_col = Color("#08C6F7")
	elif current_theme_id == "wood":
		floor_col = Color("#B57B4C")
		board_col = Color("#C88E5E")
	if effective_mode == "vehicle" and not is_voxel and not is_solid:
		board_col = Color("#3F444E")

	if _floor_mat != null:
		_floor_mat.albedo_color = floor_col
		_floor_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED if is_solid else BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if _floor_instance != null and is_instance_valid(_floor_instance):
		_floor_instance.visible = not is_voxel

	if _board_mat != null:
		if is_voxel:
			var board_tex_key: String = "voxel_pedestal_grid" if _board_size == 8 else "voxel_grass_board"
			_board_mat.albedo_texture = ToyMeshBuilder.get_voxel_texture(board_tex_key)
			_board_mat.albedo_color = Color.WHITE
			_board_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			_board_mat.uv1_scale = Vector3(float(_board_size), float(_board_size), 1.0)
			_board_mat.roughness = 0.88
			_board_mat.metallic_specular = 0.1
			_board_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		else:
			_board_mat.albedo_texture = null
			_board_mat.albedo_color = board_col
			_board_mat.uv1_scale = Vector3.ONE
			_board_mat.roughness = 0.95 if is_solid else 0.92
			_board_mat.metallic_specular = 0.0 if is_solid else 0.06
			_board_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED if is_solid else BaseMaterial3D.SPECULAR_SCHLICK_GGX

	if _dot_mat != null:
		_dot_mat.albedo_color = Color(0.02, 0.616, 0.769, 0.72) if is_solid else Color(1.0, 1.0, 1.0, 0.16)

	if _dots_mmi != null and is_instance_valid(_dots_mmi):
		_dots_mmi.visible = not is_voxel
	if _mode_stage_root != null and is_instance_valid(_mode_stage_root):
		_mode_stage_root.visible = not is_solid
	if is_voxel:
		if _voxel_world_root == null or not is_instance_valid(_voxel_world_root):
			_build_voxel_world(float(_board_size) * PieceCatalog.GRID_UNIT_SIZE)
		if _clouds_root == null or not is_instance_valid(_clouds_root):
			_build_voxel_clouds()
	else:
		_free_voxel_background_nodes()


func _rebuild_mode_stage() -> void:
	if _mode_stage_root != null and is_instance_valid(_mode_stage_root):
		remove_child(_mode_stage_root)
		_mode_stage_root.queue_free()
	_mode_stage_root = null

	var mode: String = _resolve_effective_mode_id()
	if mode == "scenery":
		return

	_mode_stage_root = Node3D.new()
	_mode_stage_root.name = "ModeStageDecor"
	add_child(_mode_stage_root)

	var board_world_size: float = float(_board_size) * PieceCatalog.GRID_UNIT_SIZE
	var half_board: float = board_world_size * 0.5

	if mode == "character":
		_add_border_frame(
			_mode_stage_root,
			"CharacterPedestal",
			half_board,
			0.32,
			0.12,
			-0.06,
			_get_shared_flat_material(Color("#E2E8F0"))
		)
	elif mode == "animal":
		_add_border_frame(
			_mode_stage_root,
			"AnimalGrassRim",
			half_board,
			0.36,
			0.08,
			-0.04,
			_get_shared_flat_material(Color("#5CB85C"))
		)
		_add_border_frame(
			_mode_stage_root,
			"AnimalEarthBase",
			half_board + 0.10,
			0.32,
			0.14,
			-0.11,
			_get_shared_flat_material(Color("#A1623B"))
		)
	elif mode == "vehicle":
		var asphalt_mat := _get_shared_flat_material(Color("#2D323B"))
		var stripe_mat := _get_shared_flat_material(Color("#F8FAFC"), true)
		var curb_mat := _get_shared_flat_material(Color("#FACC15"))
		_add_border_frame(
			_mode_stage_root,
			"VehicleRoadBorder",
			half_board,
			0.75,
			0.10,
			-0.05,
			asphalt_mat
		)
		# White dashed road stripes along the left and right sides of the 12x12 track
		var stripe_x: float = half_board + 0.36
		var dash_count: int = maxi(4, int(_board_size / 2))
		var span: float = board_world_size + 0.6
		var step_z: float = span / float(dash_count)
		var dash_len: float = step_z * 0.52
		for i in range(dash_count):
			var z_pos: float = -span * 0.5 + (float(i) + 0.5) * step_z
			for side in [-1.0, 1.0]:
				_add_voxel_box(
					_mode_stage_root,
					"RoadStripe_%d_%d" % [i, int(side)],
					Vector3(0.14, 0.01, dash_len),
					Vector3(side * stripe_x, 0.002, z_pos),
					stripe_mat,
					false
				)
		# Subtle yellow start/finish curb bars on front & back edges
		for end_sign in [-1.0, 1.0]:
			_add_voxel_box(
				_mode_stage_root,
				"RoadCurb_%d" % int(end_sign),
				Vector3(board_world_size + 0.2, 0.012, 0.12),
				Vector3(0.0, 0.002, end_sign * (half_board + 0.18)),
				curb_mat,
				false
			)


func _add_border_frame(
	parent: Node3D,
	prefix: String,
	inner_half: float,
	border_width: float,
	height: float,
	center_y: float,
	mat: Material
) -> void:
	var full_span: float = (inner_half + border_width) * 2.0
	var side_len: float = inner_half * 2.0
	var offset: float = inner_half + border_width * 0.5
	_add_voxel_box(parent, prefix + "_North", Vector3(full_span, height, border_width), Vector3(0.0, center_y, -offset), mat, false)
	_add_voxel_box(parent, prefix + "_South", Vector3(full_span, height, border_width), Vector3(0.0, center_y, offset), mat, false)
	_add_voxel_box(parent, prefix + "_West", Vector3(border_width, height, side_len), Vector3(-offset, center_y, 0.0), mat, false)
	_add_voxel_box(parent, prefix + "_East", Vector3(border_width, height, side_len), Vector3(offset, center_y, 0.0), mat, false)


static func _get_shared_box_mesh(size: Vector3) -> BoxMesh:
	var key: String = "%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	if _shared_box_meshes.has(key):
		return _shared_box_meshes[key] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_shared_box_meshes[key] = mesh
	return mesh


static func _get_shared_triplanar_material(texture_key: String, scale: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	var key: String = "%s|%.3f,%.3f,%.3f" % [texture_key, scale.x, scale.y, scale.z]
	if _shared_triplanar_materials.has(key):
		return _shared_triplanar_materials[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ToyMeshBuilder.get_voxel_texture(texture_key)
	mat.albedo_color = Color.WHITE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = scale
	mat.roughness = 0.9
	mat.metallic_specular = 0.08
	_shared_triplanar_materials[key] = mat
	return mat


static func _get_shared_flat_material(
	color: Color,
	unshaded: bool = false,
	transparent: bool = false
) -> StandardMaterial3D:
	var key: String = "%s|%s|%s" % [color.to_html(true), str(unshaded), str(transparent)]
	if _shared_flat_materials.has(key):
		return _shared_flat_materials[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		mat.roughness = 0.85
		mat.metallic = 0.0
		mat.metallic_specular = 0.08
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shared_flat_materials[key] = mat
	return mat


func _add_voxel_box(
	parent: Node3D,
	box_name: String,
	size: Vector3,
	pos: Vector3,
	mat: Material,
	cast_shadows: bool = false
) -> void:
	var mi := MeshInstance3D.new()
	mi.name = box_name
	mi.mesh = _get_shared_box_mesh(size)
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _add_blob_shadow(parent: Node3D, scale_xz: float) -> void:
	if _shared_blob_shadow_mesh == null:
		_shared_blob_shadow_mesh = QuadMesh.new()
		_shared_blob_shadow_mesh.size = Vector2(1.0, 1.0)
	if _shared_blob_shadow_mat == null:
		_shared_blob_shadow_mat = _get_shared_flat_material(Color(0.05, 0.08, 0.03, 0.22), true, true)
	var shadow := MeshInstance3D.new()
	shadow.name = "BlobShadow"
	shadow.mesh = _shared_blob_shadow_mesh
	shadow.material_override = _shared_blob_shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.rotation.x = -PI * 0.5
	shadow.scale = Vector3(scale_xz, scale_xz, 1.0)
	shadow.position = Vector3(0.0, 0.004, 0.0)
	parent.add_child(shadow)


func _build_voxel_world(board_world_size: float) -> void:
	_voxel_animals.clear()
	_voxel_world_root = Node3D.new()
	_voxel_world_root.name = "VoxelWorld"
	_voxel_world_root.visible = (current_theme_id == "voxel")
	add_child(_voxel_world_root)

	if _board_size == 8:
		var cobble_mat := _get_shared_triplanar_material("voxel_cobble")
		var planks_mat := _get_shared_triplanar_material("voxel_planks")
		_add_voxel_box(
			_voxel_world_root,
			"PedestalCore",
			Vector3(board_world_size, 1.0, board_world_size),
			Vector3(0.0, -0.5, 0.0),
			cobble_mat,
			false
		)
		_add_voxel_box(
			_voxel_world_root,
			"PedestalRim",
			Vector3(board_world_size + 0.6, 0.36, board_world_size + 0.6),
			Vector3(0.0, -0.20, 0.0),
			planks_mat,
			false
		)
		return

	# Seamless outer meadow ground at Y = 0.0 (same level as build grid)
	var world_ground_mesh := _get_shared_box_mesh(Vector3(_VOXEL_WORLD_SIZE, _VOXEL_WORLD_THICKNESS, _VOXEL_WORLD_SIZE))
	var world_ground_mat := _get_shared_triplanar_material("voxel_grass_world", Vector3(1.0, 1.0, 1.0))

	var world_ground := MeshInstance3D.new()
	world_ground.name = "VoxelExtendedGround"
	world_ground.mesh = world_ground_mesh
	world_ground.material_override = world_ground_mat
	world_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_ground.position = Vector3(0.0, _VOXEL_WORLD_TOP_Y - _VOXEL_WORLD_THICKNESS * 0.5, 0.0)
	_voxel_world_root.add_child(world_ground)

	# Subtle warm-green/golden perimeter line framing the buildable grid without any wall
	var half: float = board_world_size * 0.5
	var lw: float = _VOXEL_PERIMETER_LINE_WIDTH
	var lh: float = 0.002
	var line_y: float = _VOXEL_WORLD_TOP_Y + 0.0015
	var line_span: float = board_world_size + lw * 2.0
	var line_mat := _get_shared_flat_material(Color("#A8E05F"))
	_add_voxel_box(_voxel_world_root, "PerimeterNorth", Vector3(line_span, lh, lw), Vector3(0.0, line_y, -(half + lw * 0.5)), line_mat)
	_add_voxel_box(_voxel_world_root, "PerimeterSouth", Vector3(line_span, lh, lw), Vector3(0.0, line_y, half + lw * 0.5), line_mat)
	_add_voxel_box(_voxel_world_root, "PerimeterWest", Vector3(lw, lh, board_world_size), Vector3(-(half + lw * 0.5), line_y, 0.0), line_mat)
	_add_voxel_box(_voxel_world_root, "PerimeterEast", Vector3(lw, lh, board_world_size), Vector3(half + lw * 0.5, line_y, 0.0), line_mat)

	var wood_mat := _get_shared_triplanar_material("voxel_wood")
	var leaves_mat := _get_shared_triplanar_material("voxel_leaves")

	# Low leaf bushes around the 4 sides (half_grid + 2.0 to half_grid + 8.0)
	var bush_offsets: Array[Dictionary] = [
		{"pos": Vector2(-(half + 2.5), -(half * 0.55)), "size": Vector3(2.0, 1.0, 2.0)},
		{"pos": Vector2(half + 2.5, half * 0.45), "size": Vector3(2.0, 1.0, 2.0)},
		{"pos": Vector2(-(half * 0.45), half + 2.5), "size": Vector3(2.0, 1.0, 2.0)},
		{"pos": Vector2(half * 0.55, -(half + 2.5)), "size": Vector3(2.0, 1.0, 2.0)},
		{"pos": Vector2(-(half + 4.5), half * 0.7), "size": Vector3(1.0, 1.0, 1.0)},
		{"pos": Vector2(half + 4.0, -(half * 0.6)), "size": Vector3(1.0, 1.0, 1.0)},
		{"pos": Vector2(half * 0.75, half + 4.0), "size": Vector3(1.0, 1.0, 1.0)},
		{"pos": Vector2(-(half * 0.7), -(half + 4.5)), "size": Vector3(1.0, 1.0, 1.0)},
		{"pos": Vector2(-(half + 6.5), -2.0), "size": Vector3(2.0, 1.0, 2.0)},
		{"pos": Vector2(half + 6.5, 2.5), "size": Vector3(2.0, 1.0, 2.0)},
	]
	for idx in range(bush_offsets.size()):
		var b: Dictionary = bush_offsets[idx]
		var bp: Vector2 = b["pos"] as Vector2
		var bsz: Vector3 = b["size"] as Vector3
		_add_voxel_box(
			_voxel_world_root,
			"VoxelBush_%d" % idx,
			bsz,
			Vector3(bp.x, _VOXEL_WORLD_TOP_Y + bsz.y * 0.5, bp.y),
			leaves_mat
		)

	# Classic Minecraft oak trees (3-block trunk + 3x2x3 crown + top cap) outside the build zone
	var tree_positions: Array[Vector3] = [
		Vector3(-(half + 7.5), _VOXEL_WORLD_TOP_Y, -(half + 5.5)),
		Vector3(half + 8.0, _VOXEL_WORLD_TOP_Y, -(half + 6.0)),
		Vector3(-(half + 8.5), _VOXEL_WORLD_TOP_Y, half + 6.5),
		Vector3(half + 7.5, _VOXEL_WORLD_TOP_Y, half + 7.5),
		Vector3(-(half + 13.0), _VOXEL_WORLD_TOP_Y, -2.0),
		Vector3(half + 13.5, _VOXEL_WORLD_TOP_Y, 3.0),
		Vector3(2.5, _VOXEL_WORLD_TOP_Y, -(half + 12.0)),
		Vector3(-3.0, _VOXEL_WORLD_TOP_Y, half + 12.5),
	]
	for idx in range(tree_positions.size()):
		var tp: Vector3 = tree_positions[idx]
		_add_voxel_box(_voxel_world_root, "TreeTrunk_%d" % idx, Vector3(1.0, 3.0, 1.0), tp + Vector3(0.0, 1.5, 0.0), wood_mat, true)
		_add_voxel_box(_voxel_world_root, "TreeLeavesLow_%d" % idx, Vector3(3.0, 2.0, 3.0), tp + Vector3(0.0, 3.5, 0.0), leaves_mat, true)
		_add_voxel_box(_voxel_world_root, "TreeLeavesTop_%d" % idx, Vector3(1.0, 1.0, 1.0), tp + Vector3(0.0, 5.0, 0.0), leaves_mat, false)

	_populate_voxel_flowers_and_tufts(half)
	_populate_voxel_animals(half)


func _populate_voxel_flowers_and_tufts(half: float) -> void:
	var stem_mat := _get_shared_flat_material(Color("#388E3C"))
	var poppy_mat := _get_shared_flat_material(Color("#E53935"))
	var dandelion_mat := _get_shared_flat_material(Color("#FDD835"))
	var tuft_mat := _get_shared_flat_material(Color("#43A047"))

	var stem_mesh := _get_shared_box_mesh(Vector3(0.10, 0.30, 0.10))
	var blossom_mesh := _get_shared_box_mesh(Vector3(0.25, 0.20, 0.25))
	var tuft_mesh := _get_shared_box_mesh(Vector3(0.22, 0.36, 0.10))

	var spots: Array[Vector2] = [
		Vector2(-(half + 1.8), -(half * 0.85)),
		Vector2(-(half + 2.4), -1.2),
		Vector2(-(half + 1.7), half * 0.35),
		Vector2(-(half + 3.6), half * 0.85),
		Vector2(half + 1.8, -(half * 0.75)),
		Vector2(half + 2.6, 0.8),
		Vector2(half + 1.9, half * 0.75),
		Vector2(half + 3.8, -(half * 0.3)),
		Vector2(-(half * 0.8), -(half + 1.8)),
		Vector2(-1.4, -(half + 2.3)),
		Vector2(half * 0.35, -(half + 1.7)),
		Vector2(half * 0.85, -(half + 3.4)),
		Vector2(-(half * 0.75), half + 1.8),
		Vector2(1.2, half + 2.4),
		Vector2(half * 0.45, half + 1.9),
		Vector2(-(half * 0.35), half + 3.5),
		Vector2(-(half + 5.2), -(half + 2.2)),
		Vector2(half + 5.0, -(half + 2.0)),
		Vector2(-(half + 5.0), half + 2.4),
		Vector2(half + 5.2, half + 2.2),
		Vector2(-(half + 9.0), 4.5),
		Vector2(half + 9.0, -4.5),
		Vector2(4.5, -(half + 8.5)),
		Vector2(-4.5, half + 8.5),
	]

	for idx in range(spots.size()):
		var p2: Vector2 = spots[idx]
		var kind: int = idx % 3
		if kind == 2:
			var tuft := Node3D.new()
			tuft.name = "GrassTuft_%d" % idx
			tuft.position = Vector3(p2.x, _VOXEL_WORLD_TOP_Y, p2.y)
			for b in range(2):
				var blade := MeshInstance3D.new()
				blade.mesh = tuft_mesh
				blade.material_override = tuft_mat
				blade.position = Vector3(0.0, 0.18, 0.0)
				blade.rotation.y = (PI * 0.5) * float(b) + float(idx) * 0.3
				blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				tuft.add_child(blade)
			_voxel_world_root.add_child(tuft)
		else:
			var flower := Node3D.new()
			flower.name = "VoxelFlower_%d" % idx
			flower.position = Vector3(p2.x, _VOXEL_WORLD_TOP_Y, p2.y)
			var stem := MeshInstance3D.new()
			stem.mesh = stem_mesh
			stem.material_override = stem_mat
			stem.position = Vector3(0.0, 0.15, 0.0)
			stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flower.add_child(stem)
			var blossom := MeshInstance3D.new()
			blossom.mesh = blossom_mesh
			blossom.material_override = poppy_mat if kind == 0 else dandelion_mat
			blossom.position = Vector3(0.0, 0.38, 0.0)
			blossom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flower.add_child(blossom)
			_voxel_world_root.add_child(flower)


func _populate_voxel_animals(half: float) -> void:
	var eye_mat := _get_shared_flat_material(Color("#212121"))
	var pig_pink := _get_shared_flat_material(Color("#F48FB1"))
	var pig_snout := _get_shared_flat_material(Color("#F06292"))
	var sheep_wool := _get_shared_flat_material(Color("#F5F5F5"))
	var sheep_skin := _get_shared_flat_material(Color("#D7CCC8"))
	var chicken_white := _get_shared_flat_material(Color("#FFFFFF"))
	var chicken_beak := _get_shared_flat_material(Color("#FFC107"))
	var chicken_wattle := _get_shared_flat_material(Color("#E53935"))

	var placements: Array[Dictionary] = [
		{"kind": "pig", "pos": Vector3(-(half + 3.2), _VOXEL_WORLD_TOP_Y, half * 0.15), "rot": 0.9},
		{"kind": "sheep", "pos": Vector3(half + 3.5, _VOXEL_WORLD_TOP_Y, -(half * 0.2)), "rot": -1.1},
		{"kind": "chicken", "pos": Vector3(half * 0.15, _VOXEL_WORLD_TOP_Y, half + 3.0), "rot": 2.7},
		{"kind": "pig", "pos": Vector3(-(half * 0.25), _VOXEL_WORLD_TOP_Y, -(half + 3.3)), "rot": 0.4},
		{"kind": "sheep", "pos": Vector3(-(half + 5.5), _VOXEL_WORLD_TOP_Y, -(half * 0.7)), "rot": 1.3},
		{"kind": "chicken", "pos": Vector3(half + 4.8, _VOXEL_WORLD_TOP_Y, half * 0.65), "rot": -2.1},
		{"kind": "sheep", "pos": Vector3(half * 0.65, _VOXEL_WORLD_TOP_Y, half + 5.2), "rot": 2.4},
		{"kind": "pig", "pos": Vector3(-(half * 0.65), _VOXEL_WORLD_TOP_Y, half + 4.6), "rot": -0.5},
	]

	for idx in range(placements.size()):
		var spec: Dictionary = placements[idx]
		var kind: String = String(spec["kind"])
		var pos: Vector3 = spec["pos"] as Vector3
		var rot_y: float = float(spec["rot"])
		var animal_root := Node3D.new()
		animal_root.name = "VoxelAnimal_%s_%d" % [kind, idx]
		animal_root.position = pos
		animal_root.rotation.y = rot_y
		var head_pivot := Node3D.new()

		if kind == "pig":
			_add_voxel_box(animal_root, "Body", Vector3(0.54, 0.38, 0.82), Vector3(0.0, 0.44, 0.0), pig_pink)
			for lx in [-0.17, 0.17]:
				for lz in [-0.28, 0.28]:
					_add_voxel_box(animal_root, "Leg", Vector3(0.16, 0.25, 0.16), Vector3(lx, 0.125, lz), pig_pink)
			head_pivot.position = Vector3(0.0, 0.56, 0.44)
			_add_voxel_box(head_pivot, "Head", Vector3(0.42, 0.40, 0.40), Vector3(0.0, 0.0, 0.16), pig_pink)
			_add_voxel_box(head_pivot, "Snout", Vector3(0.24, 0.15, 0.08), Vector3(0.0, -0.05, 0.39), pig_snout)
			_add_voxel_box(head_pivot, "EyeL", Vector3(0.06, 0.06, 0.03), Vector3(-0.12, 0.06, 0.37), eye_mat)
			_add_voxel_box(head_pivot, "EyeR", Vector3(0.06, 0.06, 0.03), Vector3(0.12, 0.06, 0.37), eye_mat)
		elif kind == "sheep":
			_add_voxel_box(animal_root, "WoolBody", Vector3(0.62, 0.48, 0.88), Vector3(0.0, 0.52, 0.0), sheep_wool)
			for lx in [-0.18, 0.18]:
				for lz in [-0.28, 0.28]:
					_add_voxel_box(animal_root, "Leg", Vector3(0.16, 0.28, 0.16), Vector3(lx, 0.14, lz), sheep_skin)
			head_pivot.position = Vector3(0.0, 0.64, 0.46)
			_add_voxel_box(head_pivot, "Face", Vector3(0.36, 0.36, 0.36), Vector3(0.0, 0.0, 0.16), sheep_skin)
			_add_voxel_box(head_pivot, "WoolCrown", Vector3(0.40, 0.14, 0.38), Vector3(0.0, 0.16, 0.14), sheep_wool)
			_add_voxel_box(head_pivot, "EyeL", Vector3(0.06, 0.06, 0.03), Vector3(-0.10, 0.04, 0.35), eye_mat)
			_add_voxel_box(head_pivot, "EyeR", Vector3(0.06, 0.06, 0.03), Vector3(0.10, 0.04, 0.35), eye_mat)
		else:
			_add_voxel_box(animal_root, "Body", Vector3(0.32, 0.26, 0.40), Vector3(0.0, 0.31, 0.0), chicken_white)
			_add_voxel_box(animal_root, "WingL", Vector3(0.05, 0.16, 0.28), Vector3(-0.18, 0.32, 0.0), sheep_wool)
			_add_voxel_box(animal_root, "WingR", Vector3(0.05, 0.16, 0.28), Vector3(0.18, 0.32, 0.0), sheep_wool)
			_add_voxel_box(animal_root, "LegL", Vector3(0.06, 0.18, 0.06), Vector3(-0.08, 0.09, 0.0), chicken_beak)
			_add_voxel_box(animal_root, "LegR", Vector3(0.06, 0.18, 0.06), Vector3(0.08, 0.09, 0.0), chicken_beak)
			head_pivot.position = Vector3(0.0, 0.45, 0.16)
			_add_voxel_box(head_pivot, "Head", Vector3(0.22, 0.24, 0.20), Vector3(0.0, 0.10, 0.06), chicken_white)
			_add_voxel_box(head_pivot, "Beak", Vector3(0.14, 0.07, 0.10), Vector3(0.0, 0.08, 0.20), chicken_beak)
			_add_voxel_box(head_pivot, "Wattle", Vector3(0.08, 0.08, 0.06), Vector3(0.0, 0.01, 0.18), chicken_wattle)
			_add_voxel_box(head_pivot, "EyeL", Vector3(0.04, 0.04, 0.02), Vector3(-0.06, 0.13, 0.17), eye_mat)
			_add_voxel_box(head_pivot, "EyeR", Vector3(0.04, 0.04, 0.02), Vector3(0.06, 0.13, 0.17), eye_mat)

		_add_blob_shadow(animal_root, 0.65 if kind == "chicken" else 1.05)
		animal_root.add_child(head_pivot)
		_voxel_world_root.add_child(animal_root)
		_voxel_animals.append({
			"root": animal_root,
			"base_y": pos.y,
			"base_rot_y": rot_y,
			"phase": float(idx) * 1.15,
			"speed": 1.6 + float(idx % 3) * 0.35,
		})


func _build_voxel_clouds() -> void:
	_clouds_root = Node3D.new()
	_clouds_root.name = "VoxelClouds"
	_clouds_root.visible = (current_theme_id == "voxel")
	add_child(_clouds_root)

	var cloud_top_mat := _get_shared_flat_material(Color(1.0, 1.0, 1.0, 0.9), true, true)
	var cloud_shade_mat := _get_shared_flat_material(Color(0.86, 0.92, 0.99, 0.9), true, true)

	var cloud_specs: Array[Dictionary] = [
		{"pos": Vector3(-36.0, 20.0, -34.0), "blocks": [[Vector3.ZERO, Vector3(9.0, 0.9, 4.5), true], [Vector3(1.5, -0.4, 0.5), Vector3(6.0, 0.8, 3.2), false]]},
		{"pos": Vector3(32.0, 22.0, -38.0), "blocks": [[Vector3.ZERO, Vector3(10.0, 0.9, 5.0), true], [Vector3(-1.8, -0.4, -0.4), Vector3(7.0, 0.8, 3.6), false]]},
		{"pos": Vector3(-42.0, 19.0, 18.0), "blocks": [[Vector3.ZERO, Vector3(8.5, 0.9, 4.2), true], [Vector3(1.2, -0.4, -0.5), Vector3(5.8, 0.8, 3.0), false]]},
		{"pos": Vector3(38.0, 21.0, 26.0), "blocks": [[Vector3.ZERO, Vector3(9.2, 0.9, 4.6), true], [Vector3(-1.4, -0.4, 0.5), Vector3(6.4, 0.8, 3.4), false]]},
		{"pos": Vector3(0.0, 24.0, -48.0), "blocks": [[Vector3.ZERO, Vector3(11.0, 1.0, 5.2), true], [Vector3(2.0, -0.4, 0.4), Vector3(7.4, 0.8, 3.8), false]]},
		{"pos": Vector3(-22.0, 21.5, 42.0), "blocks": [[Vector3.ZERO, Vector3(8.8, 0.9, 4.4), true], [Vector3(-1.2, -0.4, -0.4), Vector3(6.0, 0.8, 3.2), false]]},
	]

	for idx in range(cloud_specs.size()):
		var spec: Dictionary = cloud_specs[idx]
		var cluster := Node3D.new()
		cluster.name = "CloudCluster_%d" % idx
		cluster.position = spec["pos"] as Vector3
		var blocks: Array = spec["blocks"] as Array
		for b_idx in range(blocks.size()):
			var b: Array = blocks[b_idx] as Array
			var mi := MeshInstance3D.new()
			mi.mesh = _get_shared_box_mesh(b[1] as Vector3)
			mi.material_override = cloud_top_mat if bool(b[2]) else cloud_shade_mat
			mi.position = b[0] as Vector3
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cluster.add_child(mi)
		_clouds_root.add_child(cluster)


func _apply_theme_environment() -> void:
	var world_env := _ensure_world_environment()
	if world_env == null:
		return

	if current_theme_id == "voxel":
		if _voxel_environment == null:
			var sky_mat := ProceduralSkyMaterial.new()
			sky_mat.sky_top_color = Color("#5CA8FF")
			sky_mat.sky_horizon_color = Color("#A6D8FF")
			sky_mat.ground_horizon_color = Color("#A6D8FF")
			sky_mat.ground_bottom_color = Color("#78B8FF")
			sky_mat.sun_angle_max = 0.0
			sky_mat.sun_curve = 1.0

			var sky := Sky.new()
			sky.sky_material = sky_mat

			_voxel_environment = Environment.new()
			_voxel_environment.background_mode = Environment.BG_SKY
			_voxel_environment.sky = sky
			_voxel_environment.fog_enabled = false
			_voxel_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_voxel_environment.ambient_light_color = Color("#FFFFFF")
			_voxel_environment.ambient_light_energy = 0.65
			_voxel_environment.adjustment_enabled = true
			_voxel_environment.adjustment_saturation = 1.22
			_voxel_environment.adjustment_contrast = 1.08
			_voxel_environment.adjustment_brightness = 1.03
		world_env.environment = _voxel_environment
	elif current_theme_id == "solid":
		if _solid_environment == null:
			_solid_environment = Environment.new()
			_solid_environment.background_mode = Environment.BG_COLOR
			_solid_environment.background_color = Color("#08C6F7")
			_solid_environment.fog_enabled = false
			_solid_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_solid_environment.ambient_light_color = Color("#48D9FF")
			_solid_environment.ambient_light_energy = 0.55
		world_env.environment = _solid_environment
	else:
		world_env.environment = _default_environment
	_apply_theme_lighting()


func _apply_theme_lighting() -> void:
	var dir_light := _ensure_directional_light()
	if dir_light == null:
		return
	if current_theme_id == "solid":
		dir_light.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
		dir_light.shadow_enabled = true
		dir_light.shadow_blur = 1.5
		dir_light.light_energy = 1.15
		dir_light.light_color = Color.WHITE
	elif _has_captured_default_light and not _default_light_state.is_empty():
		dir_light.rotation_degrees = _default_light_state["rotation_degrees"] as Vector3
		dir_light.shadow_enabled = bool(_default_light_state["shadow_enabled"])
		dir_light.shadow_blur = float(_default_light_state["shadow_blur"])
		dir_light.light_energy = float(_default_light_state["light_energy"])
		dir_light.light_color = _default_light_state["light_color"] as Color


func _ensure_directional_light() -> DirectionalLight3D:
	if _target_dir_light != null and is_instance_valid(_target_dir_light):
		return _target_dir_light
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			var found := _find_directional_light_recursive(tree.root)
			if found != null:
				_target_dir_light = found
				if not _has_captured_default_light:
					_default_light_state = {
						"rotation_degrees": found.rotation_degrees,
						"shadow_enabled": found.shadow_enabled,
						"shadow_blur": found.shadow_blur,
						"light_energy": found.light_energy,
						"light_color": found.light_color,
					}
					_has_captured_default_light = true
				return _target_dir_light
	_owned_dir_light = DirectionalLight3D.new()
	_owned_dir_light.name = "PlatformDirectionalLight"
	_owned_dir_light.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	_owned_dir_light.shadow_enabled = true
	_owned_dir_light.shadow_blur = 1.5
	_owned_dir_light.light_energy = 1.15
	add_child(_owned_dir_light)
	_target_dir_light = _owned_dir_light
	if not _has_captured_default_light:
		_default_light_state = {
			"rotation_degrees": _owned_dir_light.rotation_degrees,
			"shadow_enabled": _owned_dir_light.shadow_enabled,
			"shadow_blur": _owned_dir_light.shadow_blur,
			"light_energy": _owned_dir_light.light_energy,
			"light_color": _owned_dir_light.light_color,
		}
		_has_captured_default_light = true
	return _target_dir_light


func _find_directional_light_recursive(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D and node != _owned_dir_light:
		return node as DirectionalLight3D
	for child in node.get_children():
		var found := _find_directional_light_recursive(child)
		if found != null:
			return found
	return null


func _ensure_world_environment() -> WorldEnvironment:
	if _target_world_env != null and is_instance_valid(_target_world_env):
		return _target_world_env

	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			var found := _find_world_environment_recursive(tree.root)
			if found != null:
				_target_world_env = found
				if not _has_captured_default_env:
					_default_environment = found.environment
					_has_captured_default_env = true
				return _target_world_env

	_owned_world_env = WorldEnvironment.new()
	_owned_world_env.name = "PlatformWorldEnvironment"
	add_child(_owned_world_env)
	_target_world_env = _owned_world_env
	if not _has_captured_default_env:
		_default_environment = null
		_has_captured_default_env = true
	return _target_world_env


func _find_world_environment_recursive(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment and node != _owned_world_env:
		return node as WorldEnvironment
	for child in node.get_children():
		var found := _find_world_environment_recursive(child)
		if found != null:
			return found
	return null


func _clear_generated_nodes() -> void:
	if _target_world_env == _owned_world_env:
		_target_world_env = null
	_owned_world_env = null
	if _target_dir_light == _owned_dir_light:
		_target_dir_light = null
	_owned_dir_light = null
	_dot_mat = null
	_floor_instance = null
	_dots_mmi = null
	_mode_stage_root = null
	_voxel_world_root = null
	_clouds_root = null
	_voxel_animals.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
