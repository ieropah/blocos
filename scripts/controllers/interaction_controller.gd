class_name InteractionController
extends Node3D
## Handles drag-and-drop piece placement from the tray onto the 3D construction grid.
## Casts analytical rays against placed pieces and the ground plane, locks camera zoom/pinch
## during active drags, and drives translucent valid/invalid preview feedback.

signal drag_started(piece_id: String)
signal drag_updated(candidate: Dictionary)
signal placement_committed(piece_data)
signal placement_cancelled(piece_id: String, reason: String)
signal piece_selected(instance_id: int)
signal selection_cleared()
signal tool_mode_changed(new_mode: ToolMode)
signal existing_piece_move_started(instance_id: int)
signal existing_piece_move_ended(instance_id: int, committed: bool)

enum ToolMode { BUILD, PAINT, ERASE }

const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")
const ToyMeshBuilder = preload("res://scripts/visuals/toy_mesh_builder.gd")
const ThemeVisuals = preload("res://scripts/visuals/theme_visuals.gd")
const CameraController = preload("res://scripts/controllers/camera_controller.gd")
const ConstructionUI = preload("res://scripts/ui/construction_ui.gd")

const TRAY_DRAG_PLANE_HEIGHT: float = 0.5
const SIDE_HIT_NUDGE: float = 0.05
const INVALID_GRID_POS: Vector3i = Vector3i(-99, 0, -99)
const RAY_EPSILON: float = 1e-6
const TAP_MAX_MOVE_PX: float = 14.0
const ERASE_DRAG_COOLDOWN_MS: int = 120

var current_tool: ToolMode = ToolMode.BUILD

var _construction_manager: Node = null
var _camera_controller: CameraController = null
var _ui: ConstructionUI = null
var _board_size: int = PieceCatalog.DEFAULT_BOARD_SIZE

var _is_dragging: bool = false
var is_moving_existing: bool = false
var moving_piece_id: int = -1
var _drag_piece_id: String = ""
var _drag_rotation_steps: int = 0
var _drag_color: Color = Color.WHITE
var _current_candidate: Dictionary = {}

var _selected_instance_id: int = -1
var _tap_active: bool = false
var _tap_start_pos: Vector2 = Vector2.ZERO
var _pending_piece_press: bool = false
var _pending_piece_id: int = -1
var _is_tool_stroke_active: bool = false
var last_painted_id: int = -1
var _last_erase_time_ms: int = 0

var _preview_root: Node3D = null
var _preview_mesh: MeshInstance3D = null
var _footprint_mesh: MeshInstance3D = null
var _preview_mat: StandardMaterial3D = null
var _is_voxel_preview: bool = false
var _voxel_valid_mats: Array[StandardMaterial3D] = []
var _voxel_invalid_mats: Array[StandardMaterial3D] = []
var _valid_footprint_mat: StandardMaterial3D = null
var _invalid_footprint_mat: StandardMaterial3D = null


func _exit_tree() -> void:
	if _is_dragging:
		_reset_drag_state()
	_end_tool_stroke()
	_disconnect_manager_signals()
	_disconnect_ui_signals()


func _input(event: InputEvent) -> void:
	if not _is_dragging:
		return

	if event is InputEventMouseMotion:
		update_drag((event as InputEventMouseMotion).position)
		_mark_input_handled()
	elif event is InputEventScreenDrag:
		update_drag((event as InputEventScreenDrag).position)
		_mark_input_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			finish_drag(mouse_event.position)
			_mark_input_handled()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if not touch_event.pressed:
			finish_drag(touch_event.position)
			_mark_input_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dragging:
		return

	if current_tool != ToolMode.BUILD:
		_handle_tool_input(event)
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_process_build_pointer_button(mouse_event.pressed, mouse_event.position)
	elif event is InputEventMouseMotion:
		if _pending_piece_press:
			var motion_event := event as InputEventMouseMotion
			if (motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and motion_event.position.distance_to(_tap_start_pos) > TAP_MAX_MOVE_PX:
				var piece_to_move: int = _pending_piece_id
				_pending_piece_press = false
				_pending_piece_id = -1
				if start_existing_piece_drag(piece_to_move, motion_event.position):
					_mark_input_handled()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.index > 0:
			_tap_active = false
			if _pending_piece_press:
				_pending_piece_press = false
				_pending_piece_id = -1
				if _camera_controller != null and is_instance_valid(_camera_controller):
					_camera_controller.is_interaction_locked = false
			return
		_process_build_pointer_button(touch_event.pressed, touch_event.position)
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == 0 and _pending_piece_press:
			if drag_event.position.distance_to(_tap_start_pos) > TAP_MAX_MOVE_PX:
				var piece_to_move: int = _pending_piece_id
				_pending_piece_press = false
				_pending_piece_id = -1
				if start_existing_piece_drag(piece_to_move, drag_event.position):
					_mark_input_handled()


## Configures dependencies for drag-and-drop placement and tap selection.
func setup(
	construction_manager: Node,
	camera_controller: CameraController,
	ui: ConstructionUI,
	board_size: int = PieceCatalog.DEFAULT_BOARD_SIZE
) -> void:
	if _is_dragging:
		cancel_drag()
	_end_tool_stroke()
	_disconnect_manager_signals()
	_disconnect_ui_signals()
	_construction_manager = construction_manager
	_camera_controller = camera_controller
	_ui = ui
	_board_size = maxi(board_size, 1)
	_connect_manager_signals()
	_connect_ui_signals()
	clear_selection()


## Begins dragging a piece from the tray at the given screen coordinate.
func start_tray_drag(
	piece_id: String,
	screen_pos: Vector2,
	rotation_steps: int = 0,
	custom_color: Variant = null
) -> bool:
	if not PieceCatalog.has_piece(piece_id):
		return false
	if _construction_manager == null or not is_instance_valid(_construction_manager):
		return false

	if _is_dragging:
		cancel_drag()

	if current_tool != ToolMode.BUILD:
		set_tool_mode(ToolMode.BUILD)

	clear_selection()
	_drag_color = _resolve_drag_color(piece_id, custom_color)

	if _camera_controller != null and is_instance_valid(_camera_controller):
		_camera_controller.is_interaction_locked = true

	_drag_piece_id = piece_id
	_drag_rotation_steps = posmod(rotation_steps, 4)
	_current_candidate = {}
	_create_preview_nodes(piece_id)
	_is_dragging = true

	drag_started.emit(piece_id)
	update_drag(screen_pos)
	return true


## Begins dragging an already-placed piece on the board at the given screen coordinate.
func start_existing_piece_drag(instance_id: int, screen_pos: Vector2) -> bool:
	if _construction_manager == null or not is_instance_valid(_construction_manager):
		return false
	var piece: Variant = _find_piece_by_id(instance_id)
	if piece == null:
		return false

	var piece_id: String = str(_read_piece_field(piece, "piece_id", ""))
	if not PieceCatalog.has_piece(piece_id):
		return false

	if _is_dragging:
		cancel_drag()

	clear_selection()
	var rot_steps: int = posmod(int(_read_piece_field(piece, "rotation_steps", 0)), 4)
	var color_variant: Variant = _read_piece_field(piece, "color", PieceCatalog.get_piece_color(piece_id))
	_drag_color = color_variant as Color if color_variant is Color else PieceCatalog.get_piece_color(piece_id)

	if _camera_controller != null and is_instance_valid(_camera_controller):
		_camera_controller.is_interaction_locked = true

	is_moving_existing = true
	moving_piece_id = instance_id
	_drag_piece_id = piece_id
	_drag_rotation_steps = rot_steps
	_current_candidate = {}
	_create_preview_nodes(piece_id)
	_is_dragging = true

	existing_piece_move_started.emit(instance_id)
	drag_started.emit(piece_id)
	update_drag(screen_pos)
	return true


## Updates the active drag using a viewport screen coordinate.
func update_drag(screen_pos: Vector2) -> Dictionary:
	if not _is_dragging:
		return {}

	if _ui != null and is_instance_valid(_ui) and _ui.is_screen_point_in_tray(screen_pos):
		_position_preview_over_tray(screen_pos)
		return _commit_invalid_candidate("in_tray")

	var camera: Camera3D = _get_active_camera()
	if camera == null:
		return _commit_invalid_candidate("no_camera")

	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos).normalized()
	var ignore_id: int = moving_piece_id if is_moving_existing else -1
	var hit: Dictionary = _raycast_workspace(ray_origin, ray_dir, ignore_id)
	if not hit.get("hit", false):
		return _commit_invalid_candidate("no_surface_hit")

	var world_hit_pos: Vector3 = hit["point"]
	var hit_normal: Vector3 = hit["normal"]
	if absf(hit_normal.y) < 0.5:
		world_hit_pos += hit_normal * SIDE_HIT_NUDGE

	return update_drag_at_world_pos(world_hit_pos)


## Updates the active drag directly against a world-space target coordinate.
func update_drag_at_world_pos(world_pos: Vector3) -> Dictionary:
	if not _is_dragging:
		return {}
	if _construction_manager == null or not is_instance_valid(_construction_manager):
		return {}

	var candidate_variant: Variant = _construction_manager.find_snapped_placement(
		_drag_piece_id,
		world_pos,
		_drag_rotation_steps
	)
	var candidate: Dictionary = candidate_variant if candidate_variant is Dictionary else {}
	_current_candidate = candidate

	var is_valid: bool = bool(candidate.get("is_valid", false))
	var grid_pos_variant: Variant = candidate.get("grid_pos", INVALID_GRID_POS)
	var grid_pos: Vector3i = grid_pos_variant if grid_pos_variant is Vector3i else INVALID_GRID_POS

	if _preview_root != null and is_instance_valid(_preview_root):
		var def: Dictionary = PieceCatalog.get_piece_definition(_drag_piece_id)
		var piece_size: Vector3 = def.get("size", Vector3.ONE)
		_preview_root.position = PieceCatalog.grid_to_piece_center_base(
			grid_pos,
			piece_size,
			_drag_rotation_steps,
			_board_size
		)
		_preview_root.rotation.y = float(_drag_rotation_steps) * PI * 0.5

	_apply_preview_visual(is_valid)
	drag_updated.emit(_current_candidate)
	return _current_candidate


## Completes the active drag and commits placement if the final candidate is valid.
func finish_drag(screen_pos: Variant = null) -> Dictionary:
	if not _is_dragging:
		return {"committed": false, "piece": null, "validation": {}}

	if screen_pos is Vector2:
		update_drag(screen_pos as Vector2)

	var candidate: Dictionary = _current_candidate.duplicate()
	var piece_id: String = _drag_piece_id
	var rotation_steps: int = _drag_rotation_steps
	var drag_color: Color = _drag_color
	var was_moving_existing: bool = is_moving_existing
	var moved_id: int = moving_piece_id
	var manager: Node = _construction_manager
	_reset_drag_state()

	if was_moving_existing:
		if bool(candidate.get("is_valid", false)) and manager != null and is_instance_valid(manager) and manager.has_method("move_piece"):
			var target_grid: Vector3i = candidate.get("grid_pos", Vector3i.ZERO)
			var move_result: Variant = manager.call("move_piece", moved_id, target_grid, rotation_steps)
			var move_ok: bool = false
			var moved_piece: Variant = null
			if move_result is Dictionary:
				var move_dict := move_result as Dictionary
				move_ok = bool(move_dict.get("success", move_dict.get("is_valid", false)))
				moved_piece = move_dict.get("piece", move_dict.get("piece_data", null))
			elif move_result is bool:
				move_ok = bool(move_result)
				if move_ok:
					moved_piece = _find_piece_by_id(moved_id)

			existing_piece_move_ended.emit(moved_id, move_ok)
			if move_ok:
				placement_committed.emit(moved_piece)
				return {
					"committed": true,
					"piece": moved_piece,
					"validation": candidate,
				}
		else:
			existing_piece_move_ended.emit(moved_id, false)

		var move_fail_reason: String = str(candidate.get("reason", "invalid"))
		placement_cancelled.emit(piece_id, move_fail_reason)
		return {
			"committed": false,
			"piece": null,
			"validation": candidate,
		}

	if bool(candidate.get("is_valid", false)) and manager != null and is_instance_valid(manager):
		var result: Variant = manager.place_piece(
			piece_id,
			candidate.get("grid_pos", Vector3i.ZERO),
			rotation_steps,
			drag_color
		)
		if result is Dictionary:
			var result_dict := result as Dictionary
			var placed_ok: bool = bool(result_dict.get("success", result_dict.get("is_valid", false)))
			var placed_piece: Variant = result_dict.get("piece", result_dict.get("piece_data", null))
			if placed_ok:
				placement_committed.emit(placed_piece)
				return {
					"committed": true,
					"piece": placed_piece,
					"validation": candidate,
				}

		var fail_reason: String = "placement_failed"
		if result is Dictionary:
			fail_reason = str((result as Dictionary).get("reason", "placement_failed"))
		placement_cancelled.emit(piece_id, fail_reason)
		return {
			"committed": false,
			"piece": null,
			"validation": candidate,
		}

	var reason: String = str(candidate.get("reason", "invalid"))
	placement_cancelled.emit(piece_id, reason)
	return {
		"committed": false,
		"piece": null,
		"validation": candidate,
	}


## Cancels an active drag without placing a piece.
func cancel_drag() -> void:
	if not _is_dragging:
		return
	var piece_id: String = _drag_piece_id
	var was_moving_existing: bool = is_moving_existing
	var moved_id: int = moving_piece_id
	_reset_drag_state()
	if was_moving_existing:
		existing_piece_move_ended.emit(moved_id, false)
	placement_cancelled.emit(piece_id, "cancelled")


func is_dragging() -> bool:
	return _is_dragging


func get_current_candidate() -> Dictionary:
	return _current_candidate.duplicate()


func get_preview_node() -> Node3D:
	return _preview_root


## Casts a ray against placed pieces only and selects the hit piece or clears selection.
func tap_screen_position(screen_pos: Vector2) -> int:
	if _is_dragging:
		return _selected_instance_id

	var camera: Camera3D = _get_active_camera()
	if camera == null:
		clear_selection()
		return _selected_instance_id

	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos).normalized()
	var hit: Dictionary = _raycast_placed_pieces_only(ray_origin, ray_dir)
	if bool(hit.get("hit", false)):
		var hit_id: int = int(hit.get("instance_id", -1))
		if hit_id != -1 and select_piece(hit_id):
			return _selected_instance_id

	clear_selection()
	return _selected_instance_id


## Selects a placed piece by instance_id if it exists in ConstructionManager.
func select_piece(instance_id: int) -> bool:
	if instance_id < 0:
		return false
	if _find_piece_by_id(instance_id) == null:
		return false
	_selected_instance_id = instance_id
	piece_selected.emit(instance_id)
	return true


## Clears the active selection if any piece is currently selected.
func clear_selection() -> void:
	if _selected_instance_id != -1:
		_selected_instance_id = -1
		selection_cleared.emit()


func get_selected_instance_id() -> int:
	return _selected_instance_id


## Rotates the currently selected placed piece in 90-degree increments.
func rotate_selected_piece(step_delta: int = 1) -> Dictionary:
	if _selected_instance_id == -1:
		return {"success": false, "reason": "no_selection"}
	if _construction_manager == null or not is_instance_valid(_construction_manager):
		return {"success": false, "reason": "no_manager"}
	if not _construction_manager.has_method("rotate_piece"):
		return {"success": false, "reason": "rotate_unsupported"}
	var result: Variant = _construction_manager.call("rotate_piece", _selected_instance_id, step_delta)
	if result is Dictionary:
		return result as Dictionary
	return {"success": false, "reason": "invalid_result"}


## Deletes the currently selected placed piece and clears selection.
func delete_selected_piece() -> bool:
	if _selected_instance_id == -1:
		return false
	if _construction_manager == null or not is_instance_valid(_construction_manager):
		return false
	var target_id: int = _selected_instance_id
	if _construction_manager.remove_piece(target_id):
		clear_selection()
		return true
	return false


## Sets the active interaction tool mode (BUILD, PAINT, or ERASE).
func set_tool_mode(mode: ToolMode) -> void:
	if current_tool == mode:
		return
	_end_tool_stroke()
	if mode != ToolMode.BUILD:
		if _is_dragging:
			cancel_drag()
		clear_selection()
	current_tool = mode
	tool_mode_changed.emit(current_tool)


func get_tool_mode() -> ToolMode:
	return current_tool


func _commit_invalid_candidate(reason: String) -> Dictionary:
	_current_candidate = {
		"is_valid": false,
		"reason": reason,
		"grid_pos": INVALID_GRID_POS,
		"rotation_steps": _drag_rotation_steps,
		"snapped": false,
	}
	_apply_preview_visual(false)
	drag_updated.emit(_current_candidate)
	return _current_candidate


func _create_preview_nodes(piece_id: String) -> void:
	_clear_preview()

	var def: Dictionary = PieceCatalog.get_piece_definition(piece_id)
	var piece_size: Vector3 = def.get("size", Vector3.ONE)

	_valid_footprint_mat = ThemeVisuals.create_footprint_indicator_material(true)
	_invalid_footprint_mat = ThemeVisuals.create_footprint_indicator_material(false)

	_preview_root = Node3D.new()
	_preview_root.name = "DragPreview"
	add_child(_preview_root)

	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.name = "BlockPreviewMesh"
	_preview_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview_root.add_child(_preview_mesh)

	_update_preview_mesh(piece_id, _drag_color)

	_footprint_mesh = MeshInstance3D.new()
	_footprint_mesh.name = "FootprintIndicator"
	_footprint_mesh.mesh = ToyMeshBuilder.create_validity_indicator_mesh(piece_size.x, piece_size.z)
	_footprint_mesh.position = Vector3.ZERO
	_footprint_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview_root.add_child(_footprint_mesh)

	_apply_preview_visual(false)


func _update_preview_mesh(piece_id: String, color: Color) -> void:
	if _preview_mesh == null or not is_instance_valid(_preview_mesh):
		return
	var def: Dictionary = PieceCatalog.get_piece_definition(piece_id)
	var piece_size: Vector3 = def.get("size", Vector3.ONE)
	var theme_id: String = "plastic"
	if _ui != null and is_instance_valid(_ui) and _ui.has_method("get_active_theme_id"):
		theme_id = str(_ui.call("get_active_theme_id"))

	_is_voxel_preview = ToyMeshBuilder.is_voxel_piece(piece_id)
	_preview_mat = null if _is_voxel_preview else ThemeVisuals.create_preview_material(true, color)

	var mesh: ArrayMesh = ToyMeshBuilder.get_or_build_mesh(piece_id, piece_size, theme_id, color.to_html(true))
	_preview_mesh.mesh = mesh
	_preview_mesh.material_override = null
	for i in range(_preview_mesh.get_surface_override_material_count()):
		_preview_mesh.set_surface_override_material(i, null)

	if _is_voxel_preview:
		_build_voxel_preview_materials(mesh)
	else:
		_voxel_valid_mats.clear()
		_voxel_invalid_mats.clear()


func _build_voxel_preview_materials(mesh: ArrayMesh) -> void:
	_voxel_valid_mats.clear()
	_voxel_invalid_mats.clear()
	for i in range(mesh.get_surface_count()):
		var base_mat: Material = mesh.surface_get_material(i)
		if base_mat is StandardMaterial3D:
			var base_col: Color = (base_mat as StandardMaterial3D).albedo_color
			var valid_mat := (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			valid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			valid_mat.albedo_color = Color(base_col.r, base_col.g, base_col.b, 0.85)
			_voxel_valid_mats.append(valid_mat)

			var invalid_mat := (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			invalid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			invalid_mat.albedo_color = Color(base_col.r, base_col.g * 0.35, base_col.b * 0.35, 0.75)
			_voxel_invalid_mats.append(invalid_mat)


func _apply_preview_visual(is_valid: bool) -> void:
	if _preview_mesh != null and is_instance_valid(_preview_mesh):
		if _is_voxel_preview:
			_preview_mesh.material_override = null
			var mats: Array[StandardMaterial3D] = _voxel_valid_mats if is_valid else _voxel_invalid_mats
			for i in range(mats.size()):
				_preview_mesh.set_surface_override_material(i, mats[i])
		elif _preview_mat != null:
			_preview_mesh.material_override = null
			for i in range(_preview_mesh.get_surface_override_material_count()):
				_preview_mesh.set_surface_override_material(i, null)
			if _preview_mesh.mesh != null and _preview_mesh.mesh.get_surface_count() > 1:
				_preview_mesh.set_surface_override_material(0, _preview_mat)
			else:
				_preview_mesh.material_override = _preview_mat
	if _footprint_mesh != null and is_instance_valid(_footprint_mesh):
		_footprint_mesh.material_override = _valid_footprint_mat if is_valid else _invalid_footprint_mat


func _position_preview_over_tray(screen_pos: Vector2) -> void:
	if _preview_root == null or not is_instance_valid(_preview_root):
		return
	_preview_root.rotation.y = float(_drag_rotation_steps) * PI * 0.5

	var camera: Camera3D = _get_active_camera()
	if camera == null:
		return

	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos).normalized()
	var tray_plane := Plane(Vector3.UP, TRAY_DRAG_PLANE_HEIGHT)
	var hit: Variant = tray_plane.intersects_ray(ray_origin, ray_dir)
	if hit is Vector3:
		_preview_root.position = hit as Vector3


func _reset_drag_state() -> void:
	_clear_preview()
	_is_dragging = false
	is_moving_existing = false
	moving_piece_id = -1
	_drag_piece_id = ""
	_drag_rotation_steps = 0
	_drag_color = Color.WHITE
	_current_candidate = {}
	if _camera_controller != null and is_instance_valid(_camera_controller):
		_camera_controller.is_interaction_locked = false


func _clear_preview() -> void:
	if _preview_root != null and is_instance_valid(_preview_root):
		if _preview_root.get_parent() != null:
			_preview_root.get_parent().remove_child(_preview_root)
		_preview_root.queue_free()
	_preview_root = null
	_preview_mesh = null
	_footprint_mesh = null
	_preview_mat = null
	_is_voxel_preview = false
	_voxel_valid_mats.clear()
	_voxel_invalid_mats.clear()
	_valid_footprint_mat = null
	_invalid_footprint_mat = null


func _resolve_drag_color(piece_id: String, custom_color: Variant) -> Color:
	if custom_color is Color:
		return custom_color as Color
	if _ui != null and is_instance_valid(_ui) and _ui.has_method("get_selected_color"):
		var ui_color: Variant = _ui.call("get_selected_color")
		if ui_color is Color:
			return ui_color as Color
	return PieceCatalog.get_piece_color(piece_id)


func _process_build_pointer_button(pressed: bool, pos: Vector2) -> void:
	if pressed:
		if _is_screen_point_over_ui(pos):
			_tap_active = false
			_pending_piece_press = false
			_pending_piece_id = -1
			return
		var hit_id: int = _raycast_piece_id_at_screen_pos(pos)
		if hit_id != -1:
			_pending_piece_press = true
			_pending_piece_id = hit_id
			_tap_active = false
			_tap_start_pos = pos
			if _camera_controller != null and is_instance_valid(_camera_controller):
				_camera_controller.is_interaction_locked = true
			_mark_input_handled()
		else:
			_pending_piece_press = false
			_pending_piece_id = -1
			_tap_active = true
			_tap_start_pos = pos
	else:
		if _pending_piece_press:
			var tapped_id: int = _pending_piece_id
			_pending_piece_press = false
			_pending_piece_id = -1
			if _camera_controller != null and is_instance_valid(_camera_controller):
				_camera_controller.is_interaction_locked = false
			if not _is_screen_point_over_ui(pos) and pos.distance_to(_tap_start_pos) <= TAP_MAX_MOVE_PX:
				if select_piece(tapped_id):
					var tapped_piece: Variant = _find_piece_by_id(tapped_id)
					if tapped_piece != null and _construction_manager != null and _construction_manager.has_method("move_piece"):
						var grid_pos: Variant = _read_piece_field(tapped_piece, "grid_pos", Vector3i.ZERO)
						var next_rot: int = posmod(int(_read_piece_field(tapped_piece, "rotation_steps", 0)) + 1, 4)
						if grid_pos is Vector3i:
							_construction_manager.call("move_piece", tapped_id, grid_pos as Vector3i, next_rot)
					else:
						rotate_selected_piece(1)
					_mark_input_handled()
			return
		if _tap_active:
			_tap_active = false
			if _is_screen_point_over_ui(pos):
				return
			if pos.distance_to(_tap_start_pos) <= TAP_MAX_MOVE_PX:
				var prev_selected: int = _selected_instance_id
				var selected_id: int = tap_screen_position(pos)
				if selected_id != -1 or prev_selected != -1:
					_mark_input_handled()


func _raycast_piece_id_at_screen_pos(screen_pos: Vector2) -> int:
	var camera: Camera3D = _get_active_camera()
	if camera == null:
		return -1
	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos).normalized()
	var hit: Dictionary = _raycast_placed_pieces_only(ray_origin, ray_dir)
	if bool(hit.get("hit", false)):
		return int(hit.get("instance_id", -1))
	return -1


func _process_tap_event(pressed: bool, pos: Vector2) -> void:
	if pressed:
		if _is_screen_point_over_ui(pos):
			_tap_active = false
			return
		_tap_active = true
		_tap_start_pos = pos
	elif _tap_active:
		_tap_active = false
		if _is_screen_point_over_ui(pos):
			return
		if pos.distance_to(_tap_start_pos) <= TAP_MAX_MOVE_PX:
			var prev_selected: int = _selected_instance_id
			var selected_id: int = tap_screen_position(pos)
			if selected_id != -1 or prev_selected != -1:
				_mark_input_handled()


func _handle_tool_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.index > 0:
			_end_tool_stroke()
			return
		if touch_event.pressed:
			if _is_screen_point_over_ui(touch_event.position):
				_end_tool_stroke()
				return
			_begin_tool_stroke()
			_apply_active_tool_at(touch_event.position, false)
			_mark_input_handled()
		else:
			if _is_tool_stroke_active:
				_end_tool_stroke()
				_mark_input_handled()
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index > 0 or not _is_tool_stroke_active:
			return
		if not _is_screen_point_over_ui(drag_event.position):
			_apply_active_tool_at(drag_event.position, true)
		_mark_input_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			if _is_screen_point_over_ui(mouse_event.position):
				_end_tool_stroke()
				return
			_begin_tool_stroke()
			_apply_active_tool_at(mouse_event.position, false)
			_mark_input_handled()
		else:
			if _is_tool_stroke_active:
				_end_tool_stroke()
				_mark_input_handled()
	elif event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if not _is_tool_stroke_active or (motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		if not _is_screen_point_over_ui(motion_event.position):
			_apply_active_tool_at(motion_event.position, true)
		_mark_input_handled()


func _begin_tool_stroke() -> void:
	_is_tool_stroke_active = true
	last_painted_id = -1
	if _camera_controller != null and is_instance_valid(_camera_controller):
		_camera_controller.is_interaction_locked = true


func _end_tool_stroke() -> void:
	if not _is_tool_stroke_active and last_painted_id == -1:
		return
	_is_tool_stroke_active = false
	last_painted_id = -1
	if _camera_controller != null and is_instance_valid(_camera_controller) and not _is_dragging:
		_camera_controller.is_interaction_locked = false


func _apply_active_tool_at(screen_pos: Vector2, is_drag: bool) -> void:
	if _construction_manager == null or not is_instance_valid(_construction_manager):
		return
	var camera: Camera3D = _get_active_camera()
	if camera == null:
		return

	if current_tool == ToolMode.ERASE and is_drag:
		var now_ms: int = Time.get_ticks_msec()
		if now_ms - _last_erase_time_ms < ERASE_DRAG_COOLDOWN_MS:
			return

	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos).normalized()
	var hit: Dictionary = _raycast_placed_pieces_only(ray_origin, ray_dir)
	if not bool(hit.get("hit", false)):
		return

	var hit_id: int = int(hit.get("instance_id", -1))
	if hit_id == -1:
		return

	if current_tool == ToolMode.PAINT:
		if hit_id != last_painted_id:
			var active_color: Color = _resolve_active_color()
			_construction_manager.recolor_piece(hit_id, active_color)
			last_painted_id = hit_id
	elif current_tool == ToolMode.ERASE:
		if _construction_manager.remove_piece(hit_id):
			_last_erase_time_ms = Time.get_ticks_msec()


func _resolve_active_color() -> Color:
	if _ui != null and is_instance_valid(_ui) and _ui.has_method("get_selected_color"):
		var ui_color: Variant = _ui.call("get_selected_color")
		if ui_color is Color:
			return ui_color as Color
	return Color.WHITE


func _is_screen_point_over_ui(screen_pos: Vector2) -> bool:
	if _ui == null or not is_instance_valid(_ui):
		return false
	if _ui.has_method("is_screen_point_over_ui"):
		return bool(_ui.call("is_screen_point_over_ui", screen_pos))
	return _ui.is_screen_point_in_tray(screen_pos)


func _find_piece_by_id(instance_id: int) -> Variant:
	if _construction_manager == null or not is_instance_valid(_construction_manager):
		return null
	if _construction_manager.has_method("get_piece_by_id"):
		return _construction_manager.call("get_piece_by_id", instance_id)
	var placed_variant: Variant = _construction_manager.get_placed_pieces()
	if placed_variant is Array:
		for piece: Variant in placed_variant:
			if int(_read_piece_field(piece, "instance_id", -1)) == instance_id:
				return piece
	return null


func _connect_manager_signals() -> void:
	if _construction_manager == null or not is_instance_valid(_construction_manager):
		return
	if _construction_manager.has_signal("piece_removed") and not _construction_manager.is_connected("piece_removed", _on_manager_piece_removed):
		_construction_manager.connect("piece_removed", _on_manager_piece_removed)
	if _construction_manager.has_signal("construction_cleared") and not _construction_manager.is_connected("construction_cleared", _on_manager_cleared):
		_construction_manager.connect("construction_cleared", _on_manager_cleared)


func _disconnect_manager_signals() -> void:
	if _construction_manager == null or not is_instance_valid(_construction_manager):
		return
	if _construction_manager.has_signal("piece_removed") and _construction_manager.is_connected("piece_removed", _on_manager_piece_removed):
		_construction_manager.disconnect("piece_removed", _on_manager_piece_removed)
	if _construction_manager.has_signal("construction_cleared") and _construction_manager.is_connected("construction_cleared", _on_manager_cleared):
		_construction_manager.disconnect("construction_cleared", _on_manager_cleared)


func _connect_ui_signals() -> void:
	if _ui == null or not is_instance_valid(_ui):
		return
	if _ui.has_signal("shape_selected") and not _ui.is_connected("shape_selected", _on_ui_shape_selected):
		_ui.connect("shape_selected", _on_ui_shape_selected)


func _disconnect_ui_signals() -> void:
	if _ui == null or not is_instance_valid(_ui):
		return
	if _ui.has_signal("shape_selected") and _ui.is_connected("shape_selected", _on_ui_shape_selected):
		_ui.disconnect("shape_selected", _on_ui_shape_selected)


func _on_ui_shape_selected(piece_id: String) -> void:
	set_tool_mode(ToolMode.BUILD)
	if _is_dragging and not is_moving_existing and piece_id != _drag_piece_id and PieceCatalog.has_piece(piece_id):
		var prev_pos: Vector3 = _preview_root.position if (_preview_root != null and is_instance_valid(_preview_root)) else Vector3.ZERO
		var prev_rot: float = _preview_root.rotation.y if (_preview_root != null and is_instance_valid(_preview_root)) else 0.0
		var was_valid: bool = bool(_current_candidate.get("is_valid", false))
		_drag_piece_id = piece_id
		_drag_color = _resolve_drag_color(piece_id, null)
		_create_preview_nodes(piece_id)
		if _preview_root != null and is_instance_valid(_preview_root):
			_preview_root.position = prev_pos
			_preview_root.rotation.y = prev_rot
		_apply_preview_visual(was_valid)


func _on_manager_piece_removed(instance_id: int) -> void:
	if instance_id == _selected_instance_id:
		clear_selection()


func _on_manager_cleared() -> void:
	clear_selection()


func _get_active_camera() -> Camera3D:
	if _camera_controller == null or not is_instance_valid(_camera_controller):
		return null
	var camera: Camera3D = _camera_controller.get_camera()
	if camera == null or not is_instance_valid(camera) or not camera.is_inside_tree():
		return null
	return camera


func _raycast_workspace(ray_origin: Vector3, ray_dir: Vector3, ignore_instance_id: int = -1) -> Dictionary:
	var best_t: float = INF
	var best_point := Vector3.ZERO
	var best_normal := Vector3.UP
	var has_hit := false

	if absf(ray_dir.y) > RAY_EPSILON:
		var t_ground: float = -ray_origin.y / ray_dir.y
		if t_ground >= 0.0:
			best_t = t_ground
			best_point = ray_origin + ray_dir * t_ground
			best_point.y = 0.0
			best_normal = Vector3.UP
			has_hit = true

	var piece_hit: Dictionary = _raycast_placed_pieces_only(ray_origin, ray_dir, ignore_instance_id)
	if bool(piece_hit.get("hit", false)):
		var t_piece: float = float(piece_hit["t"])
		if t_piece >= 0.0 and t_piece < best_t:
			best_t = t_piece
			best_point = piece_hit["point"]
			best_normal = piece_hit["normal"]
			has_hit = true

	if not has_hit:
		return {"hit": false}

	return {
		"hit": true,
		"t": best_t,
		"point": best_point,
		"normal": best_normal,
	}


func _raycast_placed_pieces_only(ray_origin: Vector3, ray_dir: Vector3, ignore_instance_id: int = -1) -> Dictionary:
	var best_t: float = INF
	var best_point := Vector3.ZERO
	var best_normal := Vector3.UP
	var best_instance_id: int = -1
	var has_hit := false

	if _construction_manager != null and is_instance_valid(_construction_manager):
		var placed_variant: Variant = _construction_manager.get_placed_pieces()
		if placed_variant is Array:
			for piece: Variant in placed_variant:
				var piece_instance_id: int = int(_read_piece_field(piece, "instance_id", -1))
				if ignore_instance_id != -1 and piece_instance_id == ignore_instance_id:
					continue
				var piece_hit: Dictionary = _intersect_ray_placed_piece(ray_origin, ray_dir, piece)
				if piece_hit.get("hit", false):
					var t_piece: float = float(piece_hit["t"])
					if t_piece >= 0.0 and t_piece < best_t:
						best_t = t_piece
						best_point = piece_hit["point"]
						best_normal = piece_hit["normal"]
						best_instance_id = piece_instance_id
						has_hit = true

	if not has_hit:
		return {"hit": false}

	return {
		"hit": true,
		"t": best_t,
		"point": best_point,
		"normal": best_normal,
		"instance_id": best_instance_id,
	}


func _intersect_ray_placed_piece(ray_origin: Vector3, ray_dir: Vector3, piece: Variant) -> Dictionary:
	var piece_id: String = str(_read_piece_field(piece, "piece_id", ""))
	if not PieceCatalog.has_piece(piece_id):
		return {"hit": false}

	var grid_variant: Variant = _read_piece_field(piece, "grid_pos", null)
	if not (grid_variant is Vector3i):
		return {"hit": false}

	var grid_pos: Vector3i = grid_variant as Vector3i
	var rot_steps: int = posmod(int(_read_piece_field(piece, "rotation_steps", 0)), 4)
	var def: Dictionary = PieceCatalog.get_piece_definition(piece_id)
	var piece_size: Vector3 = def["size"]
	var shape: String = str(def["shape"])

	if shape == "ramp":
		return _intersect_ray_ramp(ray_origin, ray_dir, piece_size, grid_pos, rot_steps)

	var swap_xz: bool = rot_steps % 2 == 1
	var footprint_x: float = piece_size.z if swap_xz else piece_size.x
	var footprint_z: float = piece_size.x if swap_xz else piece_size.z
	var box_min: Vector3 = PieceCatalog.grid_to_world_origin(grid_pos, _board_size)
	var box_max: Vector3 = box_min + Vector3(footprint_x, piece_size.y, footprint_z)
	return _intersect_ray_aabb(ray_origin, ray_dir, box_min, box_max)


func _intersect_ray_aabb(
	ray_origin: Vector3,
	ray_dir: Vector3,
	box_min: Vector3,
	box_max: Vector3
) -> Dictionary:
	var clip: Dictionary = _clip_ray_to_aabb(ray_origin, ray_dir, box_min, box_max)
	if not bool(clip.get("hit", false)) or not bool(clip.get("has_normal", false)):
		return {"hit": false}

	var t_min: float = float(clip["t_min"])
	var normal: Vector3 = clip["normal"]
	var hit_point: Vector3 = ray_origin + ray_dir * t_min

	if absf(normal.x) > 0.5:
		hit_point.x = box_max.x if normal.x > 0.0 else box_min.x
	elif absf(normal.y) > 0.5:
		hit_point.y = box_max.y if normal.y > 0.0 else box_min.y
	elif absf(normal.z) > 0.5:
		hit_point.z = box_max.z if normal.z > 0.0 else box_min.z

	return {
		"hit": true,
		"t": t_min,
		"point": hit_point,
		"normal": normal,
	}


func _intersect_ray_ramp(
	ray_origin: Vector3,
	ray_dir: Vector3,
	piece_size: Vector3,
	grid_pos: Vector3i,
	rot_steps: int
) -> Dictionary:
	var center_base: Vector3 = PieceCatalog.grid_to_piece_center_base(
		grid_pos,
		piece_size,
		rot_steps,
		_board_size
	)
	var basis := Basis(Vector3.UP, float(rot_steps) * PI * 0.5)
	var inv_basis := basis.transposed()
	var local_origin: Vector3 = inv_basis * (ray_origin - center_base)
	var local_dir: Vector3 = inv_basis * ray_dir

	var hx: float = piece_size.x * 0.5
	var hz: float = piece_size.z * 0.5
	var clip: Dictionary = _clip_ray_to_aabb(
		local_origin,
		local_dir,
		Vector3(-hx, 0.0, -hz),
		Vector3(hx, piece_size.y, hz)
	)
	if not bool(clip.get("hit", false)):
		return {"hit": false}

	var t_min: float = float(clip["t_min"])
	var t_max: float = float(clip["t_max"])
	var local_normal: Vector3 = clip["normal"]
	var has_normal: bool = bool(clip["has_normal"])

	var p_slope := Vector3(-hx, 0.0, 0.0)
	var n_slope := Vector3(-piece_size.y, piece_size.x, 0.0).normalized()
	var denom: float = n_slope.dot(local_dir)
	var dist: float = n_slope.dot(local_origin - p_slope)

	if absf(denom) < RAY_EPSILON:
		if dist > 0.0:
			return {"hit": false}
	else:
		var t_slope: float = -dist / denom
		if denom < 0.0:
			if t_slope > t_min:
				t_min = t_slope
				local_normal = n_slope
				has_normal = true
		else:
			t_max = minf(t_max, t_slope)

		if t_min > t_max:
			return {"hit": false}

	if not has_normal or t_max < 0.0:
		return {"hit": false}

	return {
		"hit": true,
		"t": t_min,
		"point": ray_origin + ray_dir * t_min,
		"normal": (basis * local_normal).normalized(),
	}


static func _clip_ray_to_aabb(
	ray_origin: Vector3,
	ray_dir: Vector3,
	box_min: Vector3,
	box_max: Vector3
) -> Dictionary:
	var t_min: float = 0.0
	var t_max: float = INF
	var hit_normal := Vector3.ZERO
	var has_normal := false

	for axis in range(3):
		var o: float = ray_origin[axis]
		var d: float = ray_dir[axis]
		var b_min: float = box_min[axis]
		var b_max: float = box_max[axis]

		if absf(d) < RAY_EPSILON:
			if o < b_min or o > b_max:
				return {"hit": false}
			continue

		var inv_d: float = 1.0 / d
		var t1: float = (b_min - o) * inv_d
		var t2: float = (b_max - o) * inv_d
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
			has_normal = true
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return {"hit": false}

	if t_max < 0.0:
		return {"hit": false}

	return {
		"hit": true,
		"t_min": t_min,
		"t_max": t_max,
		"normal": hit_normal,
		"has_normal": has_normal,
	}


static func _read_piece_field(piece: Variant, field: String, default_value: Variant) -> Variant:
	if piece is Dictionary:
		return (piece as Dictionary).get(field, default_value)
	if piece is Object:
		var value: Variant = (piece as Object).get(field)
		if value != null:
			return value
	return default_value


func _mark_input_handled() -> void:
	if is_inside_tree() and get_viewport() != null:
		get_viewport().set_input_as_handled()
