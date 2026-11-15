class_name ConstructionWorkspace
extends Node3D
## Main construction workspace integrating environment, studio lighting, 8x8 platform,
## deterministic placement manager, drag-and-drop interaction controller, isometric camera, and HUD.

const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")
const PlacedPieceData = preload("res://scripts/core/placed_piece_data.gd")
const PlacementSystem = preload("res://scripts/core/placement_system.gd")
const ConstructionManager = preload("res://scripts/core/construction_manager.gd")
const ToyMeshBuilder = preload("res://scripts/visuals/toy_mesh_builder.gd")
const ThemeVisuals = preload("res://scripts/visuals/theme_visuals.gd")
const FeedbackFX = preload("res://scripts/visuals/feedback_fx.gd")
const PlatformController = preload("res://scripts/controllers/platform_controller.gd")
const CameraController = preload("res://scripts/controllers/camera_controller.gd")
const InteractionController = preload("res://scripts/controllers/interaction_controller.gd")
const ConstructionUI = preload("res://scripts/ui/construction_ui.gd")
const HomeScreen = preload("res://scripts/ui/home_screen.gd")
const GalleryUI = preload("res://scripts/ui/gallery_ui.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
const ProjectData = preload("res://scripts/core/project_data.gd")

const SAMPLE_COMPOSITION: Array[Dictionary] = [
	{
		"name": "SampleSquarePlate",
		"piece_id": "square_plate",
		"grid_pos": Vector3i(3, 0, 3),
		"rotation_steps": 0,
		"color": ThemeVisuals.SAGE_GREEN,
	},
	{
		"name": "SampleYellowCube",
		"piece_id": "cube",
		"grid_pos": Vector3i(3, 1, 3),
		"rotation_steps": 0,
		"color": ThemeVisuals.SUNNY_YELLOW,
	},
	{
		"name": "SampleLongBlock",
		"piece_id": "long_block",
		"grid_pos": Vector3i(1, 0, 3),
		"rotation_steps": 0,
		"color": ThemeVisuals.COBALT_BLUE,
	},
	{
		"name": "SampleRamp",
		"piece_id": "ramp",
		"grid_pos": Vector3i(3, 0, 1),
		"rotation_steps": 2,
		"color": ThemeVisuals.TERRACOTTA,
	},
	{
		"name": "SampleCoralCube",
		"piece_id": "cube",
		"grid_pos": Vector3i(1, 4, 3),
		"rotation_steps": 0,
		"color": ThemeVisuals.CORAL_RED,
	},
]

var _is_setup: bool = false
var _world_env: WorldEnvironment = null
var _studio_lights: Node3D = null
var _platform: PlatformController = null
var _construction_manager: ConstructionManager = null
var _camera_controller: CameraController = null
var _interaction_controller: InteractionController = null
var _pieces_root: Node3D = null
var _ui: ConstructionUI = null
var _placed_pieces: Array[Dictionary] = []
var _piece_nodes_by_id: Dictionary = {}
var _contact_shadow_mat: StandardMaterial3D = null
var _selection_highlight: MeshInstance3D = null
var _save_manager: SaveManager = null
var _home_screen: HomeScreen = null
var _gallery_ui: GalleryUI = null
var _active_project_id: String = ""
var _suppress_feedback_fx: bool = false
var _last_selected_voxel_piece_id: String = ""
var _collision_shape_cache: Dictionary = {}


func _ready() -> void:
	ensure_setup()


## Initializes all Phase 1 and Phase 2 subsystems and the sample composition once.
func ensure_setup() -> void:
	if _is_setup:
		return
	_is_setup = true

	_contact_shadow_mat = ThemeVisuals.create_contact_shadow_material()

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorkspaceEnvironment"
	_world_env.environment = ThemeVisuals.create_workspace_environment()
	add_child(_world_env)

	_studio_lights = Node3D.new()
	_studio_lights.name = "StudioLights"
	add_child(_studio_lights)
	ThemeVisuals.setup_studio_lighting(_studio_lights)

	_platform = PlatformController.new()
	_platform.name = "Platform"
	add_child(_platform)
	_platform.build_platform(ProjectData.DEFAULT_GRID_SIZE)
	if _platform.has_method("set_theme"):
		_platform.call("set_theme", ProjectData.DEFAULT_THEME_ID)

	_pieces_root = Node3D.new()
	_pieces_root.name = "PiecesRoot"
	add_child(_pieces_root)

	_construction_manager = ConstructionManager.new()
	_construction_manager.name = "ConstructionManager"
	_construction_manager.configure_project_rules(ProjectData.DEFAULT_GRID_SIZE, ProjectData.DEFAULT_THEME_ID)
	add_child(_construction_manager)
	_construction_manager.piece_placed.connect(_on_piece_placed)
	_construction_manager.piece_rotated.connect(_on_piece_rotated)
	_construction_manager.piece_recolored.connect(_on_piece_recolored)
	_construction_manager.piece_moved.connect(_on_piece_moved)
	_construction_manager.piece_removed.connect(_on_piece_removed)
	_construction_manager.construction_cleared.connect(_on_construction_cleared)
	_construction_manager.history_changed.connect(_on_history_changed)

	_suppress_feedback_fx = true
	_build_sample_composition()
	_suppress_feedback_fx = false
	_construction_manager.clear_history()

	_camera_controller = CameraController.new()
	_camera_controller.name = "CameraController"
	add_child(_camera_controller)
	_camera_controller.ensure_setup()
	_camera_controller.get_camera().current = true

	_ui = ConstructionUI.new()
	_ui.name = "ConstructionUI"
	add_child(_ui)
	_ui.ensure_setup()
	_ui.bind_camera_controller(_camera_controller)
	_sync_ui_theme_context(ProjectData.DEFAULT_GRID_SIZE, ProjectData.DEFAULT_THEME_ID)

	_selection_highlight = MeshInstance3D.new()
	_selection_highlight.name = "SelectionHighlight"
	_selection_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection_highlight.material_override = ThemeVisuals.create_selection_material()
	_selection_highlight.visible = false
	add_child(_selection_highlight)

	_interaction_controller = InteractionController.new()
	_interaction_controller.name = "InteractionController"
	add_child(_interaction_controller)
	_interaction_controller.setup(
		_construction_manager,
		_camera_controller,
		_ui,
		ProjectData.DEFAULT_GRID_SIZE
	)
	_ui.tray_piece_drag_started.connect(_on_tray_piece_drag_started)
	if _ui.has_signal("piece_selected"):
		_ui.connect("piece_selected", _on_ui_piece_selected)
	elif _ui.has_signal("tray_piece_selected"):
		_ui.connect("tray_piece_selected", _on_ui_piece_selected)
	_ui.rotate_piece_pressed.connect(_on_rotate_piece_pressed)
	_ui.delete_piece_pressed.connect(_on_delete_piece_pressed)
	_ui.undo_pressed.connect(_on_undo_pressed)
	_ui.redo_pressed.connect(_on_redo_pressed)
	_ui.gallery_pressed.connect(open_gallery)
	if _ui.has_signal("home_requested"):
		_ui.home_requested.connect(_on_home_requested)
	elif _ui.has_signal("home_pressed"):
		_ui.home_pressed.connect(_on_home_requested)
	_ui.tool_selected.connect(_on_tool_selected)
	_interaction_controller.piece_selected.connect(_on_piece_selected)
	_interaction_controller.selection_cleared.connect(_on_selection_cleared)
	_interaction_controller.tool_mode_changed.connect(_on_tool_mode_changed)
	_interaction_controller.existing_piece_move_started.connect(_on_existing_piece_move_started)
	_interaction_controller.existing_piece_move_ended.connect(_on_existing_piece_move_ended)
	_ui.set_piece_selected_state(false)
	_ui.set_history_state(_construction_manager.can_undo(), _construction_manager.can_redo())

	_save_manager = SaveManager.new()
	_save_manager.name = "SaveManager"
	add_child(_save_manager)
	_save_manager.setup()
	_save_manager.bind_construction_manager(_construction_manager)
	_save_manager.projects_list_changed.connect(_refresh_gallery_list)
	_save_manager.project_loaded.connect(_on_project_activated)
	_save_manager.project_created.connect(_on_project_activated)
	_save_manager.project_renamed.connect(_on_project_renamed)
	_save_manager.project_deleted.connect(_on_project_deleted)
	_save_manager.project_error.connect(_on_project_error)

	_gallery_ui = GalleryUI.new()
	_gallery_ui.name = "GalleryUI"
	add_child(_gallery_ui)
	_gallery_ui.ensure_setup()
	_gallery_ui.hide_gallery()
	_gallery_ui.close_gallery_requested.connect(close_gallery)
	_gallery_ui.new_project_requested.connect(_on_gallery_new_project_requested)
	_gallery_ui.open_project_requested.connect(_on_gallery_open_project_requested)
	_gallery_ui.rename_project_requested.connect(_on_gallery_rename_project_requested)
	_gallery_ui.delete_project_requested.connect(_on_gallery_delete_project_requested)

	_home_screen = HomeScreen.new()
	_home_screen.name = "HomeScreen"
	add_child(_home_screen)
	if _home_screen.has_method("ensure_setup"):
		_home_screen.call("ensure_setup")
	if _home_screen.has_signal("start_new_project_requested"):
		_home_screen.connect("start_new_project_requested", _on_home_start_new_project_requested)
	if _home_screen.has_signal("open_gallery_requested"):
		_home_screen.connect("open_gallery_requested", open_gallery)
	open_home_screen()


func get_platform() -> PlatformController:
	ensure_setup()
	return _platform


func get_construction_manager() -> ConstructionManager:
	ensure_setup()
	return _construction_manager


func get_camera_controller() -> CameraController:
	ensure_setup()
	return _camera_controller


func get_interaction_controller() -> InteractionController:
	ensure_setup()
	return _interaction_controller


func get_ui() -> ConstructionUI:
	ensure_setup()
	return _ui


func get_save_manager() -> SaveManager:
	ensure_setup()
	return _save_manager


func get_gallery_ui() -> GalleryUI:
	ensure_setup()
	return _gallery_ui


func get_home_screen() -> HomeScreen:
	ensure_setup()
	return _home_screen


func get_start_screen_ui() -> HomeScreen:
	return get_home_screen()


func open_home_screen() -> void:
	ensure_setup()
	if _interaction_controller != null:
		if _interaction_controller.is_dragging():
			_interaction_controller.cancel_drag()
		_interaction_controller.clear_selection()
	if _camera_controller != null:
		_camera_controller.is_interaction_locked = true
	if _ui != null and is_instance_valid(_ui):
		_ui.visible = false
	if _home_screen != null and is_instance_valid(_home_screen):
		if _home_screen.has_method("show_home_screen"):
			_home_screen.call("show_home_screen")
		else:
			_home_screen.visible = true


func open_start_screen() -> void:
	open_home_screen()


func enter_workspace() -> void:
	ensure_setup()
	if _home_screen != null and is_instance_valid(_home_screen):
		if _home_screen.has_method("hide_home_screen"):
			_home_screen.call("hide_home_screen")
		else:
			_home_screen.visible = false
	if _ui != null and is_instance_valid(_ui):
		_ui.visible = true
	if _camera_controller != null:
		_camera_controller.is_interaction_locked = false


func get_selection_highlight() -> MeshInstance3D:
	ensure_setup()
	return _selection_highlight


func open_gallery() -> void:
	ensure_setup()
	if _interaction_controller != null:
		if _interaction_controller.is_dragging():
			_interaction_controller.cancel_drag()
		_interaction_controller.clear_selection()
	if _camera_controller != null:
		_camera_controller.is_interaction_locked = true
	_gallery_ui.clear_error()
	_refresh_gallery_list()
	_gallery_ui.show_gallery()


func close_gallery() -> void:
	ensure_setup()
	_gallery_ui.hide_gallery()
	if _camera_controller != null:
		_camera_controller.is_interaction_locked = false


func create_new_project(
	custom_name: String = "",
	p_grid_size: int = -1,
	p_theme_id: String = ""
) -> Dictionary:
	ensure_setup()
	if p_theme_id == "voxel" and p_grid_size >= 16:
		p_grid_size = 32
	if _interaction_controller != null:
		if _interaction_controller.is_dragging():
			_interaction_controller.cancel_drag()
		_interaction_controller.clear_selection()
	_suppress_feedback_fx = true
	var res: Dictionary = _save_manager.create_project(custom_name, p_grid_size, p_theme_id)
	_suppress_feedback_fx = false
	if bool(res.get("success", false)):
		_gallery_ui.clear_error()
		close_gallery()
		enter_workspace()
	return res


func open_project(project_id: String) -> Dictionary:
	ensure_setup()
	if _interaction_controller != null:
		if _interaction_controller.is_dragging():
			_interaction_controller.cancel_drag()
		_interaction_controller.clear_selection()
	_suppress_feedback_fx = true
	var res: Dictionary = _save_manager.open_project(project_id, _construction_manager)
	_suppress_feedback_fx = false
	if bool(res.get("success", false)):
		_gallery_ui.clear_error()
		close_gallery()
		enter_workspace()
	else:
		_gallery_ui.show_error(str(res.get("error_message", "Could not open project.")))
	return res


func rename_project(project_id: String, new_name: String) -> Dictionary:
	ensure_setup()
	return _save_manager.rename_project(project_id, new_name)


func delete_project(project_id: String) -> Dictionary:
	ensure_setup()
	return _save_manager.delete_project(project_id)


func get_placed_pieces() -> Array[Dictionary]:
	ensure_setup()
	return _placed_pieces.duplicate()


func raycast_placed_piece_face(ray_origin: Vector3, ray_dir: Vector3) -> Dictionary:
	ensure_setup()
	if _construction_manager == null or ray_dir.length_squared() < 1e-8:
		return {"hit": false}

	var dir: Vector3 = ray_dir.normalized()
	var best_t: float = INF
	var best_hit: Dictionary = {"hit": false}
	var active_grid_size: int = _construction_manager.grid_size

	for piece: PlacedPieceData in _construction_manager.get_placed_pieces():
		var sub_size: Vector3i = PieceCatalog.get_rotated_sub_cells_size(piece.piece_id, piece.rotation_steps)
		var min_pt: Vector3 = PieceCatalog.grid_to_world_origin(piece.grid_pos, active_grid_size)
		var max_pt: Vector3 = min_pt + Vector3(
			float(sub_size.x) * PieceCatalog.GRID_UNIT_SIZE,
			float(sub_size.y) * PieceCatalog.HEIGHT_SUB_UNIT,
			float(sub_size.z) * PieceCatalog.GRID_UNIT_SIZE
		)
		var hit_info: Dictionary = _intersect_ray_aabb(ray_origin, dir, min_pt, max_pt)
		if bool(hit_info.get("hit", false)):
			var t: float = float(hit_info["t"])
			if t < best_t:
				best_t = t
				best_hit = {
					"hit": true,
					"instance_id": piece.instance_id,
					"piece_data": piece,
					"normal": hit_info["normal"],
					"position": ray_origin + dir * t,
					"t": t,
				}
	return best_hit


func compute_face_snapped_placement(
	hit_instance_id: int,
	hit_normal: Vector3,
	candidate_piece_id: String,
	rotation_steps: int = 0
) -> Dictionary:
	ensure_setup()
	if _construction_manager == null:
		return {"is_valid": false, "snapped": false, "reason": "not_ready"}
	var hit_piece: PlacedPieceData = _construction_manager.get_piece_by_id(hit_instance_id)
	return PlacementSystem.snap_adjacent_to_hit_piece(
		_construction_manager.get_placed_pieces(),
		hit_piece,
		hit_normal,
		candidate_piece_id,
		rotation_steps,
		_construction_manager.grid_size
	)


func _intersect_ray_aabb(
	ray_origin: Vector3,
	ray_dir: Vector3,
	aabb_min: Vector3,
	aabb_max: Vector3
) -> Dictionary:
	var t_min: float = 0.0
	var t_max: float = INF
	var hit_normal := Vector3.ZERO

	for axis in range(3):
		var origin_v: float = ray_origin[axis]
		var dir_v: float = ray_dir[axis]
		var min_v: float = aabb_min[axis]
		var max_v: float = aabb_max[axis]
		if absf(dir_v) < 1e-7:
			if origin_v < min_v or origin_v > max_v:
				return {"hit": false}
			continue
		var inv_d: float = 1.0 / dir_v
		var t1: float = (min_v - origin_v) * inv_d
		var t2: float = (max_v - origin_v) * inv_d
		var axis_normal := Vector3.ZERO
		axis_normal[axis] = -1.0
		if t1 > t2:
			var tmp: float = t1
			t1 = t2
			t2 = tmp
			axis_normal[axis] = 1.0
		if t1 > t_min:
			t_min = t1
			hit_normal = axis_normal
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return {"hit": false}

	if hit_normal == Vector3.ZERO:
		return {"hit": false}
	return {"hit": true, "t": t_min, "normal": hit_normal}


## Clears all placed pieces from both logical state and 3D scene visuals.
func clear_construction() -> void:
	ensure_setup()
	if _interaction_controller != null:
		if _interaction_controller.is_dragging():
			_interaction_controller.cancel_drag()
		_interaction_controller.clear_selection()
	_construction_manager.clear_all()
	_construction_manager.clear_history()


func _build_sample_composition() -> void:
	for spec: Dictionary in SAMPLE_COMPOSITION:
		_construction_manager.place_piece(
			spec["piece_id"],
			spec["grid_pos"],
			spec["rotation_steps"],
			spec["color"],
			false
		)


func _is_voxel_character_mode() -> bool:
	return _construction_manager != null and _construction_manager.theme_id == "voxel" and _construction_manager.board_size == 8


func _on_ui_piece_selected(piece_id: String) -> void:
	if piece_id.begins_with("voxel_") and not _is_voxel_character_mode():
		_last_selected_voxel_piece_id = piece_id
		if _ui != null and is_instance_valid(_ui) and _ui.has_method("set_selected_color"):
			_ui.call("set_selected_color", PieceCatalog.get_piece_color(piece_id))
	else:
		_last_selected_voxel_piece_id = ""


func _on_tray_piece_drag_started(piece_id: String, screen_pos: Vector2) -> void:
	if _interaction_controller != null:
		if piece_id.begins_with("voxel_") and not _is_voxel_character_mode() and piece_id != _last_selected_voxel_piece_id:
			_last_selected_voxel_piece_id = piece_id
			if _ui != null and is_instance_valid(_ui) and _ui.has_method("set_selected_color"):
				_ui.call("set_selected_color", PieceCatalog.get_piece_color(piece_id))
		elif not piece_id.begins_with("voxel_") or _is_voxel_character_mode():
			_last_selected_voxel_piece_id = ""
		var selected_color: Variant = _ui.get_selected_color() if _ui != null else null
		_interaction_controller.start_tray_drag(piece_id, screen_pos, 0, selected_color)


func _on_rotate_piece_pressed() -> void:
	if _interaction_controller != null:
		_interaction_controller.rotate_selected_piece(1)


func _on_delete_piece_pressed() -> void:
	if _interaction_controller != null:
		_interaction_controller.delete_selected_piece()


func _on_undo_pressed() -> void:
	if _interaction_controller != null and _interaction_controller.is_dragging():
		_interaction_controller.cancel_drag()
	if _construction_manager != null:
		_construction_manager.undo()


func _on_redo_pressed() -> void:
	if _interaction_controller != null and _interaction_controller.is_dragging():
		_interaction_controller.cancel_drag()
	if _construction_manager != null:
		_construction_manager.redo()


func _on_piece_selected(_instance_id: int) -> void:
	if _ui != null:
		_ui.set_piece_selected_state(true)
	_refresh_selection_highlight()


func _on_selection_cleared() -> void:
	if _ui != null:
		_ui.set_piece_selected_state(false)
	_refresh_selection_highlight()


func _on_history_changed(can_undo_val: bool, can_redo_val: bool) -> void:
	if _ui != null:
		_ui.set_history_state(can_undo_val, can_redo_val)


func _on_tool_selected(tool_name: String) -> void:
	if _interaction_controller == null:
		return
	match tool_name:
		"build":
			_interaction_controller.set_tool_mode(InteractionController.ToolMode.BUILD)
		"paint":
			_interaction_controller.set_tool_mode(InteractionController.ToolMode.PAINT)
		"erase":
			_interaction_controller.set_tool_mode(InteractionController.ToolMode.ERASE)


func _on_tool_mode_changed(new_mode: InteractionController.ToolMode) -> void:
	if _ui == null or not is_instance_valid(_ui):
		return
	match new_mode:
		InteractionController.ToolMode.BUILD:
			_ui.select_tool("build")
		InteractionController.ToolMode.PAINT:
			_ui.select_tool("paint")
		InteractionController.ToolMode.ERASE:
			_ui.select_tool("erase")


func _on_piece_placed(piece_data: PlacedPieceData) -> void:
	_spawn_placed_piece_visual(piece_data)
	if not _suppress_feedback_fx:
		var node := _piece_nodes_by_id.get(piece_data.instance_id) as Node3D
		FeedbackFX.play_place_tween(node)
		if node != null and is_instance_valid(node):
			FeedbackFX.spawn_burst(_pieces_root, node.position + Vector3(0.0, 0.25, 0.0), piece_data.color, false)
		FeedbackFX.play_sfx("place")


func _on_piece_rotated(piece_data: PlacedPieceData) -> void:
	_apply_piece_transform_visual(piece_data)


func _on_existing_piece_move_started(instance_id: int) -> void:
	if _piece_nodes_by_id.has(instance_id):
		var node := _piece_nodes_by_id[instance_id] as Node3D
		if node != null and is_instance_valid(node):
			node.visible = false


func _on_existing_piece_move_ended(instance_id: int, committed: bool) -> void:
	var node := _piece_nodes_by_id.get(instance_id) as Node3D
	if node != null and is_instance_valid(node):
		node.visible = true
	if committed and _construction_manager != null:
		var piece_data: PlacedPieceData = _construction_manager.get_piece_by_id(instance_id)
		if piece_data != null:
			_apply_piece_transform_visual(piece_data)
			if not _suppress_feedback_fx and node != null and is_instance_valid(node):
				FeedbackFX.play_place_tween(node)
				FeedbackFX.spawn_burst(_pieces_root, node.position + Vector3(0.0, 0.25, 0.0), piece_data.color, false)
				FeedbackFX.play_sfx("place")
	_refresh_selection_highlight()


func _on_piece_moved(piece_id: int, _new_pos: Vector3i, _new_rot: int) -> void:
	var piece_data: PlacedPieceData = _construction_manager.get_piece_by_id(piece_id) if _construction_manager != null else null
	if piece_data != null:
		_apply_piece_transform_visual(piece_data)
	_trigger_autosave()


func _apply_piece_transform_visual(piece_data: PlacedPieceData) -> void:
	var def := PieceCatalog.get_piece_definition(piece_data.piece_id)
	var piece_size: Vector3 = def["size"]
	var new_pos: Vector3 = PieceCatalog.grid_to_piece_center_base(
		piece_data.grid_pos,
		piece_size,
		piece_data.rotation_steps,
		_construction_manager.board_size
	)
	var new_rot_y: float = float(piece_data.rotation_steps) * PI * 0.5

	if _piece_nodes_by_id.has(piece_data.instance_id):
		var node := _piece_nodes_by_id[piece_data.instance_id] as Node3D
		if node != null and is_instance_valid(node):
			node.position = new_pos
			node.rotation.y = new_rot_y
			node.set_meta("grid_pos", piece_data.grid_pos)
			node.set_meta("rotation_steps", piece_data.rotation_steps)

	for entry: Dictionary in _placed_pieces:
		if int(entry.get("instance_id", -1)) == piece_data.instance_id:
			entry["grid_pos"] = piece_data.grid_pos
			entry["rotation_steps"] = piece_data.rotation_steps
			entry["base_y"] = new_pos.y
			break

	_refresh_selection_highlight()


func _on_piece_recolored(piece_id: int, new_color: Color) -> void:
	for entry: Dictionary in _placed_pieces:
		if int(entry.get("instance_id", -1)) == piece_id:
			var piece_type: String = str(entry.get("piece_id", ""))
			var mesh_instance := entry.get("mesh_instance") as MeshInstance3D
			if mesh_instance != null and is_instance_valid(mesh_instance):
				if ToyMeshBuilder.is_voxel_piece(piece_type):
					var def := PieceCatalog.get_piece_definition(piece_type)
					var piece_size: Vector3 = def.get("size", Vector3.ONE)
					var tint: Color = Color.WHITE if new_color.is_equal_approx(PieceCatalog.get_piece_color(piece_type)) else new_color
					var voxel_mesh: ArrayMesh = ToyMeshBuilder.create_voxel_box(piece_size, piece_type, tint)
					mesh_instance.mesh = voxel_mesh
					mesh_instance.material_override = null
					entry["mesh"] = voxel_mesh
				else:
					_apply_piece_surface_material(mesh_instance, new_color)
			break

	if not _suppress_feedback_fx:
		var node := _piece_nodes_by_id.get(piece_id) as Node3D
		FeedbackFX.play_paint_tween(node)
		if node != null and is_instance_valid(node):
			FeedbackFX.spawn_burst(_pieces_root, node.position + Vector3(0.0, 0.25, 0.0), new_color, false)
		FeedbackFX.play_sfx("paint")

	_trigger_autosave()


func _trigger_autosave() -> void:
	if _save_manager != null and _save_manager.is_autosave_enabled() and not _save_manager.get_current_project_id().is_empty():
		_save_manager.save_current_project()


func _on_piece_removed(instance_id: int) -> void:
	if _interaction_controller != null and _interaction_controller.get_selected_instance_id() == instance_id:
		_interaction_controller.clear_selection()

	var burst_pos := Vector3.ZERO
	var has_burst_pos := false
	var piece_color := Color.WHITE

	if _piece_nodes_by_id.has(instance_id):
		var node: Node = _piece_nodes_by_id[instance_id]
		if node is Node3D and is_instance_valid(node):
			burst_pos = (node as Node3D).position + Vector3(0.0, 0.25, 0.0)
			has_burst_pos = true
		_piece_nodes_by_id.erase(instance_id)
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()

	for i in range(_placed_pieces.size() - 1, -1, -1):
		if int(_placed_pieces[i].get("instance_id", -1)) == instance_id:
			var mesh_instance := _placed_pieces[i].get("mesh_instance") as MeshInstance3D
			if mesh_instance != null and is_instance_valid(mesh_instance):
				var mat: Material = mesh_instance.get_surface_override_material(0) if (mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0) else null
				if mat == null:
					mat = mesh_instance.material_override
				if mat is StandardMaterial3D:
					piece_color = (mat as StandardMaterial3D).albedo_color
			_placed_pieces.remove_at(i)

	if not _suppress_feedback_fx:
		if has_burst_pos:
			FeedbackFX.spawn_burst(_pieces_root, burst_pos, piece_color, true)
		FeedbackFX.play_sfx("erase")

	_refresh_selection_highlight()


func _on_construction_cleared() -> void:
	if _interaction_controller != null:
		_interaction_controller.clear_selection()
	for child: Node in _pieces_root.get_children():
		_pieces_root.remove_child(child)
		child.queue_free()
	_piece_nodes_by_id.clear()
	_placed_pieces.clear()
	_refresh_selection_highlight()


func _refresh_selection_highlight() -> void:
	if _selection_highlight == null or not is_instance_valid(_selection_highlight):
		return
	var selected_id: int = _interaction_controller.get_selected_instance_id() if _interaction_controller != null else -1
	if selected_id < 0 or not _piece_nodes_by_id.has(selected_id):
		_selection_highlight.visible = false
		return
	var piece_data: PlacedPieceData = _construction_manager.get_piece_by_id(selected_id) if _construction_manager != null else null
	if piece_data == null:
		_selection_highlight.visible = false
		return
	var def := PieceCatalog.get_piece_definition(piece_data.piece_id)
	var piece_size: Vector3 = def["size"]
	_selection_highlight.mesh = ToyMeshBuilder.create_selection_indicator_mesh(piece_size.x, piece_size.z)
	_selection_highlight.position = PieceCatalog.grid_to_piece_center_base(
		piece_data.grid_pos,
		piece_size,
		piece_data.rotation_steps,
		_construction_manager.board_size
	)
	_selection_highlight.rotation.y = float(piece_data.rotation_steps) * PI * 0.5
	_selection_highlight.visible = true


func _spawn_placed_piece_visual(piece_data: PlacedPieceData) -> void:
	var piece_id: String = piece_data.piece_id
	var def := PieceCatalog.get_piece_definition(piece_id)
	var piece_size: Vector3 = def["size"]
	var shape: String = def["shape"]
	var grid_pos: Vector3i = piece_data.grid_pos
	var rot_steps: int = piece_data.rotation_steps

	var piece_root := Node3D.new()
	piece_root.name = "Piece_%d_%s" % [piece_data.instance_id, piece_id]
	piece_root.set_process(false)
	piece_root.set_physics_process(false)
	piece_root.position = PieceCatalog.grid_to_piece_center_base(
		grid_pos,
		piece_size,
		rot_steps,
		_construction_manager.board_size
	)
	piece_root.rotation.y = float(rot_steps) * PI * 0.5
	piece_root.set_meta("instance_id", piece_data.instance_id)
	piece_root.set_meta("piece_id", piece_id)
	piece_root.set_meta("grid_pos", grid_pos)
	piece_root.set_meta("rotation_steps", rot_steps)
	_pieces_root.add_child(piece_root)
	_piece_nodes_by_id[piece_data.instance_id] = piece_root

	var is_voxel: bool = ToyMeshBuilder.is_voxel_piece(piece_id)
	var mesh: ArrayMesh
	if is_voxel:
		var tint: Color = Color.WHITE if piece_data.color.is_equal_approx(PieceCatalog.get_piece_color(piece_id)) else piece_data.color
		mesh = ToyMeshBuilder.create_voxel_box(piece_size, piece_id, tint)
	else:
		mesh = ToyMeshBuilder.create_piece_mesh(
			piece_id,
			piece_size,
			0.04 if shape == "ramp" else 0.045,
			3
		)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "BlockMesh"
	mesh_instance.set_process(false)
	mesh_instance.set_physics_process(false)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = null
	if not is_voxel:
		_apply_piece_surface_material(mesh_instance, piece_data.color)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	piece_root.add_child(mesh_instance)

	var shadow_shrink: float = 0.0 if grid_pos.y == 0 else 0.16
	var shadow_mesh := ToyMeshBuilder.create_contact_shadow_mesh(
		maxf(piece_size.x - shadow_shrink, 0.12),
		maxf(piece_size.z - shadow_shrink, 0.12)
	)
	var shadow_instance := MeshInstance3D.new()
	shadow_instance.name = "ContactShadow"
	shadow_instance.set_process(false)
	shadow_instance.set_physics_process(false)
	shadow_instance.mesh = shadow_mesh
	shadow_instance.material_override = _contact_shadow_mat
	shadow_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece_root.add_child(shadow_instance)

	_placed_pieces.append({
		"instance_id": piece_data.instance_id,
		"piece_id": piece_id,
		"grid_pos": grid_pos,
		"rotation_steps": rot_steps,
		"node": piece_root,
		"mesh_instance": mesh_instance,
		"mesh": mesh,
		"base_y": piece_root.position.y,
	})


func _apply_piece_surface_material(mesh_instance: MeshInstance3D, color: Color) -> void:
	mesh_instance.material_override = null
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return
	var existing_mat := mesh_instance.get_surface_override_material(0)
	if existing_mat is StandardMaterial3D:
		(existing_mat as StandardMaterial3D).albedo_color = color
	else:
		mesh_instance.set_surface_override_material(0, ThemeVisuals.create_toy_material(color))
	if mesh_instance.mesh.get_surface_count() > 1:
		mesh_instance.set_surface_override_material(1, null)


func _get_cached_box_shape(piece_size: Vector3) -> BoxShape3D:
	if _collision_shape_cache.has(piece_size):
		return _collision_shape_cache[piece_size] as BoxShape3D
	var box_shape := BoxShape3D.new()
	box_shape.size = piece_size
	_collision_shape_cache[piece_size] = box_shape
	return box_shape


func _refresh_gallery_list() -> void:
	if _gallery_ui == null or not is_instance_valid(_gallery_ui) or _save_manager == null:
		return
	_gallery_ui.refresh_projects(_save_manager.list_projects(), _save_manager.get_current_project_id())


func _on_gallery_new_project_requested() -> void:
	create_new_project("")


func _on_gallery_open_project_requested(project_id: String) -> void:
	open_project(project_id)


func _on_gallery_rename_project_requested(project_id: String, new_name: String) -> void:
	rename_project(project_id, new_name)


func _on_gallery_delete_project_requested(project_id: String) -> void:
	delete_project(project_id)


func _on_home_start_new_project_requested(p_grid_size: int, p_theme_id: String) -> void:
	create_new_project("", p_grid_size, p_theme_id)


func _on_home_requested() -> void:
	_trigger_autosave()
	open_home_screen()


func _apply_workspace_rules(p_grid_size: int, p_theme_id: String) -> void:
	if _construction_manager != null:
		_construction_manager.configure_project_rules(p_grid_size, p_theme_id)
	if _interaction_controller != null:
		if _interaction_controller.has_method("set_grid_size"):
			_interaction_controller.call("set_grid_size", p_grid_size)
		elif _interaction_controller.has_method("set_board_size"):
			_interaction_controller.call("set_board_size", p_grid_size)
		elif "grid_size" in _interaction_controller:
			_interaction_controller.set("grid_size", p_grid_size)
		elif "board_size" in _interaction_controller:
			_interaction_controller.set("board_size", p_grid_size)
		elif "_board_size" in _interaction_controller:
			_interaction_controller.set("_board_size", p_grid_size)
		var y_step: float = 0.5 if p_theme_id == "voxel" else PieceCatalog.HEIGHT_SUB_UNIT
		if _interaction_controller.has_method("set_y_step"):
			_interaction_controller.call("set_y_step", y_step)
		elif "y_step" in _interaction_controller:
			_interaction_controller.set("y_step", y_step)
	if _platform != null and is_instance_valid(_platform):
		if _platform.has_method("set_grid_size"):
			_platform.call("set_grid_size", p_grid_size)
		if _platform.has_method("set_theme"):
			_platform.call("set_theme", p_theme_id)
	if _camera_controller != null and is_instance_valid(_camera_controller) and _camera_controller.has_method("adapt_to_grid_size"):
		_camera_controller.call("adapt_to_grid_size", p_grid_size)
	_sync_ui_theme_context(p_grid_size, p_theme_id)


func _sync_ui_theme_context(p_grid_size: int, p_theme_id: String) -> void:
	if _ui == null or not is_instance_valid(_ui):
		return
	if _ui.has_method("set_grid_size"):
		_ui.call("set_grid_size", p_grid_size)
	elif "grid_size" in _ui:
		_ui.set("grid_size", p_grid_size)
	elif "_grid_size" in _ui:
		_ui.set("_grid_size", p_grid_size)
	if _ui.has_method("set_active_theme"):
		_ui.call("set_active_theme", p_theme_id)
	elif _ui.has_method("set_theme"):
		_ui.call("set_theme", p_theme_id)
	if _ui.has_method("set_theme_context"):
		_ui.call("set_theme_context", p_theme_id, p_grid_size)
	var theme_pieces: Array = PieceCatalog.get_pieces_for_theme(p_theme_id, p_grid_size)
	if _ui.has_method("set_available_pieces"):
		_ui.call("set_available_pieces", theme_pieces)
	var default_piece: String = PieceCatalog.get_default_piece_id(p_theme_id, p_grid_size)
	if _ui.has_method("select_piece"):
		_ui.call("select_piece", default_piece)
	elif _ui.has_method("set_selected_piece"):
		_ui.call("set_selected_piece", default_piece)
	if default_piece.begins_with("voxel_") and not (p_theme_id == "voxel" and p_grid_size == 8):
		_last_selected_voxel_piece_id = default_piece
		if _ui.has_method("set_selected_color"):
			_ui.call("set_selected_color", PieceCatalog.get_piece_color(default_piece))
	else:
		_last_selected_voxel_piece_id = ""


func _on_project_activated(project: ProjectData) -> void:
	if project == null:
		return
	_active_project_id = project.project_id
	_apply_workspace_rules(project.grid_size, project.theme_id)
	if _ui != null and is_instance_valid(_ui):
		_ui.set_active_project_name(project.project_name)
	_refresh_gallery_list()


func _on_project_renamed(project_id: String, new_name: String) -> void:
	if project_id == _active_project_id and _ui != null and is_instance_valid(_ui):
		_ui.set_active_project_name(new_name)
	_refresh_gallery_list()


func _on_project_deleted(project_id: String) -> void:
	if project_id == _active_project_id:
		_active_project_id = ""
		clear_construction()
		if _ui != null and is_instance_valid(_ui):
			_ui.set_active_project_name("No Project Open")
	_refresh_gallery_list()


func _on_project_error(error_message: String, _reason: String) -> void:
	if _gallery_ui != null and is_instance_valid(_gallery_ui):
		_gallery_ui.show_error(error_message)
