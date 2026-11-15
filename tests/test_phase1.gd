extends SceneTree
## Automated verification suite for Phase 1 (visual prototype, platform, meshes, camera, UI).

const WORKSPACE_SCENE_PATH := "res://scenes/main/construction_workspace.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_project_settings()

	var packed := ResourceLoader.load(WORKSPACE_SCENE_PATH) as PackedScene
	_check(packed != null, "Main workspace scene failed to load: " + WORKSPACE_SCENE_PATH)
	if packed == null:
		_finish()
		return

	var workspace := packed.instantiate()
	root.add_child(workspace)
	await process_frame

	_test_platform(workspace)
	_test_pieces(workspace)
	_test_camera(workspace)
	_test_ui(workspace)

	workspace.queue_free()
	await process_frame
	_finish()


func _test_project_settings() -> void:
	var width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	var orientation: int = int(ProjectSettings.get_setting("display/window/handheld/orientation", -1))
	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var renderer_mobile: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))

	_check(width == 1920 and height == 1200, "Expected 1920x1200 viewport, got %dx%d" % [width, height])
	_check(orientation == 0, "Expected landscape orientation (0), got %d" % orientation)
	_check(renderer == "mobile" and renderer_mobile == "mobile", "Expected mobile renderer, got %s / %s" % [renderer, renderer_mobile])


func _test_platform(workspace: Node) -> void:
	var platform = workspace.get_platform()
	_check(platform != null, "PlatformController missing from workspace")
	if platform == null:
		return

	_check(platform.get_board_size() == 12, "Expected 12x12 board, got %d" % platform.get_board_size())
	_check(platform.get_tile_count() == 144, "Expected 144 platform tiles, got %d" % platform.get_tile_count())

	var studio_floor := platform.get_node_or_null("StudioFloor") as MeshInstance3D
	var grid_dots := platform.get_node_or_null("GridDotMarkers") as MultiMeshInstance3D
	_check(studio_floor != null and grid_dots != null, "Platform StudioFloor or GridDotMarkers missing")
	if grid_dots != null and grid_dots.multimesh != null:
		_check(grid_dots.multimesh.instance_count == 144, "Expected 144 grid dot markers, got %d" % grid_dots.multimesh.instance_count)


func _test_pieces(workspace: Node) -> void:
	var placed: Array[Dictionary] = workspace.get_placed_pieces()
	_check(placed.size() >= 4, "Expected at least 4 sample pieces, got %d" % placed.size())

	var seen_ids := {}
	var seen_heights: Array[float] = []

	for entry: Dictionary in placed:
		var piece_id: String = entry["piece_id"]
		seen_ids[piece_id] = true

		var mesh := entry["mesh"] as ArrayMesh
		_check(mesh != null and mesh.get_surface_count() > 0, "Missing ArrayMesh surface for " + piece_id)
		if mesh != null and mesh.get_surface_count() > 0:
			var arrays := mesh.surface_get_arrays(0)
			var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			_check(verts.size() > 24, "Expected beveled mesh (>24 verts) for %s, got %d" % [piece_id, verts.size()])

		var base_y: float = entry["base_y"]
		seen_heights.append(base_y)

	for required_id: String in ["cube", "long_block", "square_plate", "ramp"]:
		_check(seen_ids.has(required_id), "Missing required Phase 1 piece type: " + required_id)

	var has_ground := false
	var has_plate_top := false
	var has_block_top := false
	for h: float in seen_heights:
		if is_equal_approx(h, 0.0):
			has_ground = true
		elif is_equal_approx(h, 0.25):
			has_plate_top = true
		elif is_equal_approx(h, 1.0):
			has_block_top = true
	_check(has_ground and has_plate_top and has_block_top, "Expected supported heights 0.0, 0.25, and 1.0; got %s" % [str(seen_heights)])


func _test_camera(workspace: Node) -> void:
	var cam_ctrl = workspace.get_camera_controller()
	_check(cam_ctrl != null, "CameraController missing from workspace")
	if cam_ctrl == null:
		return

	var cam: Camera3D = cam_ctrl.get_camera()
	_check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "Expected orthogonal projection")
	_check(is_equal_approx(cam_ctrl.get_target_yaw_degrees(), 45.0), "Expected initial yaw 45.0")

	var expected_yaws: Array[float] = [135.0, 225.0, 315.0, 45.0]
	for expected_yaw: float in expected_yaws:
		cam_ctrl.rotate_step(1)
		cam_ctrl.apply_immediate()
		_check(
			is_equal_approx(cam_ctrl.get_target_yaw_degrees(), expected_yaw),
			"Expected yaw %.1f, got %.1f" % [expected_yaw, cam_ctrl.get_target_yaw_degrees()]
		)

	cam_ctrl.zoom_step(-20.0)
	_check(is_equal_approx(cam_ctrl.get_target_ortho_size(), cam_ctrl.min_size), "Zoom in did not clamp to min_size")

	cam_ctrl.zoom_step(40.0)
	_check(is_equal_approx(cam_ctrl.get_target_ortho_size(), cam_ctrl.max_size), "Zoom out did not clamp to max_size")

	cam_ctrl.recenter()
	cam_ctrl.apply_immediate()
	_check(is_equal_approx(cam_ctrl.get_target_ortho_size(), cam_ctrl.default_size), "Recenter did not restore default_size")
	_check(is_equal_approx(cam.size, cam_ctrl.default_size), "Recenter did not update Camera3D size")


func _test_ui(workspace: Node) -> void:
	var ui = workspace.get_ui()
	var cam_ctrl = workspace.get_camera_controller()
	_check(ui != null, "ConstructionUI missing from workspace")
	if ui == null:
		return

	var buttons: Dictionary = ui.get_toolbar_buttons()
	for btn_name: String in ["RotateLeftButton", "RotateRightButton", "ZoomOutButton", "ZoomInButton", "RecenterButton"]:
		_check(buttons.has(btn_name), "Missing UI button: " + btn_name)

	var toolbar := ui.find_child("ToolbarPanel", true, false) as Control
	_check(toolbar != null and toolbar.visible, "ToolbarPanel missing or hidden")
	if toolbar != null:
		var viewport_rect: Rect2 = root.get_visible_rect()
		var toolbar_rect: Rect2 = toolbar.get_global_rect()
		_check(toolbar_rect.size.x > 0.0 and toolbar_rect.size.y > 0.0, "ToolbarPanel has zero size")
		_check(toolbar_rect.position.x >= 0.0 and toolbar_rect.position.y >= 0.0, "ToolbarPanel clipped on top/left")
		_check(toolbar_rect.end.x <= viewport_rect.size.x and toolbar_rect.end.y <= viewport_rect.size.y, "ToolbarPanel outside viewport bounds: %s vs %s" % [str(toolbar_rect), str(viewport_rect)])

	if cam_ctrl != null and buttons.size() == 5:
		var initial_yaw: float = cam_ctrl.get_target_yaw_degrees()
		(buttons["RotateRightButton"] as Button).pressed.emit()
		_check(is_equal_approx(cam_ctrl.get_target_yaw_degrees(), initial_yaw + 90.0), "RotateRightButton did not rotate camera +90 deg")
		(buttons["RotateLeftButton"] as Button).pressed.emit()
		_check(is_equal_approx(cam_ctrl.get_target_yaw_degrees(), initial_yaw), "RotateLeftButton did not rotate camera back")
		(buttons["ZoomInButton"] as Button).pressed.emit()
		_check(cam_ctrl.get_target_ortho_size() < cam_ctrl.default_size, "ZoomInButton did not zoom in")
		(buttons["RecenterButton"] as Button).pressed.emit()
		_check(is_equal_approx(cam_ctrl.get_target_ortho_size(), cam_ctrl.default_size), "RecenterButton did not restore default_size")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PHASE1_TESTS_PASSED")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		print("PHASE1_TESTS_FAILED: %d" % _failures.size())
		quit(1)
