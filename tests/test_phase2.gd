extends SceneTree
## Automated verification suite for Phase 2 (placement validation, snapping,
## 0.25 height increments, ramp geometry, tray infinite stock, and drag lifecycle).

const WORKSPACE_SCENE_PATH := "res://scenes/main/construction_workspace.tscn"
const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := ResourceLoader.load(WORKSPACE_SCENE_PATH) as PackedScene
	_check(packed != null, "Main workspace scene failed to load: " + WORKSPACE_SCENE_PATH)
	if packed == null:
		_finish()
		return

	var workspace := packed.instantiate()
	root.add_child(workspace)
	await process_frame

	var manager = workspace.get_construction_manager()
	var interaction = workspace.get_interaction_controller()
	var camera_ctrl = workspace.get_camera_controller()
	var ui = workspace.get_ui()

	_check(manager != null and interaction != null and camera_ctrl != null and ui != null, "Workspace Phase 2 subsystems missing")
	if manager == null or interaction == null or camera_ctrl == null or ui == null:
		workspace.queue_free()
		await process_frame
		_finish()
		return

	_test_valid_platform_and_multiple_instances(workspace, manager)
	_test_stacking_and_quarter_unit_increments(workspace, manager)
	_test_out_of_bounds_collision_and_unsupported(workspace, manager)
	_test_ramp_geometry_and_overhang(workspace, manager)
	_test_tray_infinite_stock_and_drag_commit_cancel(workspace, manager, interaction, camera_ctrl, ui)
	_test_screen_ray_drag_and_camera_lock(workspace, manager, interaction, camera_ctrl, ui)

	workspace.queue_free()
	await process_frame
	_finish()


func _test_valid_platform_and_multiple_instances(workspace: Node, manager: Node) -> void:
	workspace.clear_construction()
	_check(manager.get_piece_count() == 0, "Expected empty board after clear_construction")

	for i in range(3):
		var res: Dictionary = manager.place_piece("cube", Vector3i(i * 2, 0, 0), 0)
		_check(bool(res.get("success", false)), "Failed to place cube instance %d on platform" % i)

	_check(manager.get_piece_count() == 3, "Expected 3 placed cube instances, got %d" % manager.get_piece_count())
	_check(workspace.get_placed_pieces().size() == 3, "Expected 3 visual nodes in workspace")


func _test_stacking_and_quarter_unit_increments(workspace: Node, manager: Node) -> void:
	workspace.clear_construction()

	var plate1: Dictionary = manager.place_piece("square_plate", Vector3i(2, 0, 2), 0)
	_check(bool(plate1.get("success", false)), "First square_plate on platform failed")

	# 0.25 increment: single plate top is at gy = 1.
	var invalid_gap: Dictionary = manager.place_piece("cube", Vector3i(2, 2, 2), 0)
	_check(not bool(invalid_gap.get("success", false)), "Cube at gy=2 on single plate should fail")
	_check(invalid_gap.get("reason", "") == "unsupported", "Expected unsupported at gy=2 on single plate, got %s" % str(invalid_gap.get("reason", "")))

	var cube_on_plate: Dictionary = manager.place_piece("cube", Vector3i(2, 1, 2), 0)
	_check(bool(cube_on_plate.get("success", false)), "Cube at gy=1 on square_plate should succeed")

	# Stack a second square_plate on the remaining open quadrant or clean spot at gy=1 -> top gy=2.
	workspace.clear_construction()
	_check(bool(manager.place_piece("square_plate", Vector3i(2, 0, 2), 0).get("success", false)), "Base plate failed")
	_check(bool(manager.place_piece("square_plate", Vector3i(2, 1, 2), 0).get("success", false)), "Stacked second plate at gy=1 failed")
	var cube_at_half: Dictionary = manager.place_piece("cube", Vector3i(2, 2, 2), 0)
	_check(bool(cube_at_half.get("success", false)), "Cube at gy=2 on two stacked plates failed")

	# Stack cube on top of long_block (top gy = 4).
	var lb: Dictionary = manager.place_piece("long_block", Vector3i(5, 0, 5), 0)
	_check(bool(lb.get("success", false)), "Long block placement failed")
	var top_cube: Dictionary = manager.place_piece("cube", Vector3i(6, 4, 5), 0)
	_check(bool(top_cube.get("success", false)), "Cube on top of long_block at gy=4 failed")


func _test_out_of_bounds_collision_and_unsupported(workspace: Node, manager: Node) -> void:
	workspace.clear_construction()

	var oob_cases: Array[Dictionary] = [
		{"id": "cube", "pos": Vector3i(-1, 0, 0), "rot": 0},
		{"id": "cube", "pos": Vector3i(0, 0, -1), "rot": 0},
		{"id": "long_block", "pos": Vector3i(11, 0, 0), "rot": 0},
		{"id": "long_block", "pos": Vector3i(0, 0, 11), "rot": 1},
		{"id": "square_plate", "pos": Vector3i(11, 0, 10), "rot": 0},
	]
	for case_item: Dictionary in oob_cases:
		var res: Dictionary = manager.place_piece(case_item["id"], case_item["pos"], case_item["rot"])
		_check(not bool(res.get("success", false)), "Out-of-bounds case unexpectedly succeeded: " + str(case_item))
		_check(res.get("reason", "") == "out_of_bounds", "Expected out_of_bounds, got " + str(res))

	var base_cube: Dictionary = manager.place_piece("cube", Vector3i(3, 0, 3), 0)
	_check(bool(base_cube.get("success", false)), "Base cube failed")

	var intersect: Dictionary = manager.place_piece("long_block", Vector3i(2, 0, 3), 0)
	_check(not bool(intersect.get("success", false)), "Intersecting long_block should fail")
	_check(intersect.get("reason", "") == "collision", "Expected collision, got " + str(intersect))

	var floating: Dictionary = manager.place_piece("cube", Vector3i(0, 4, 0), 0)
	_check(not bool(floating.get("success", false)), "Floating cube should fail")
	_check(floating.get("reason", "") == "unsupported", "Expected unsupported, got " + str(floating))


func _test_ramp_geometry_and_overhang(workspace: Node, manager: Node) -> void:
	workspace.clear_construction()

	# Ramp at (2, 0, 2) rot=0: low half at (2, 2) occupies gy 0..1; high half at (3, 2) occupies gy 0..3.
	var ramp_res: Dictionary = manager.place_piece("ramp", Vector3i(2, 0, 2), 0)
	_check(bool(ramp_res.get("success", false)), "Ramp placement failed")

	# Direct stacking on ramp slope/top must be rejected as unsupported (or collision inside wedge).
	var on_low_slope: Dictionary = manager.place_piece("cube", Vector3i(2, 2, 2), 0)
	_check(not bool(on_low_slope.get("success", false)), "Stacking unsupported cube over ramp low half should fail")
	_check(on_low_slope.get("reason", "") == "unsupported", "Expected unsupported above ramp low half, got " + str(on_low_slope))

	var in_low_wedge: Dictionary = manager.place_piece("square_plate", Vector3i(2, 1, 2), 0)
	_check(not bool(in_low_wedge.get("success", false)), "Intersecting ramp wedge at gy=1 should fail")
	_check(in_low_wedge.get("reason", "") == "collision", "Expected collision inside ramp wedge, got " + str(in_low_wedge))

	var on_high_top: Dictionary = manager.place_piece("cube", Vector3i(3, 4, 2), 0)
	_check(not bool(on_high_top.get("success", false)), "Stacking on ramp high sloped edge should be unsupported")
	_check(on_high_top.get("reason", "") == "unsupported", "Expected unsupported on ramp high edge, got " + str(on_high_top))

	# Build adjacent 0.5-high support (2 stacked plates at gx=1, gz=2) to bridge over ramp low half at gy=2!
	_check(bool(manager.place_piece("square_plate", Vector3i(0, 0, 2), 0).get("success", false)), "Support plate 1 failed")
	_check(bool(manager.place_piece("square_plate", Vector3i(0, 1, 2), 0).get("success", false)), "Support plate 2 failed")

	# A long_block at (1, 2, 2) spans gx=1 (supported at gy=2) and gx=2 (empty space above ramp low half gy 2..5).
	var bridge: Dictionary = manager.place_piece("long_block", Vector3i(1, 2, 2), 0)
	_check(bool(bridge.get("success", false)), "Bridge over ramp low half should succeed using real wedge geometry, got " + str(bridge))


func _test_tray_infinite_stock_and_drag_commit_cancel(
	workspace: Node,
	manager: Node,
	interaction: Node,
	camera_ctrl: Node,
	ui: Node
) -> void:
	workspace.clear_construction()

	var cards: Dictionary = ui.get_tray_cards()
	_check(cards.size() == 4, "Expected 4 tray cards before drags")

	# Start drag of cube, move to valid world coordinate at board cell (6, 0, 6) -> world (0.5, 0.0, 0.5) on 12x12 board.
	var started: bool = interaction.start_tray_drag("cube", Vector2(100.0, 150.0), 0)
	_check(started and interaction.is_dragging(), "start_tray_drag failed for cube")
	_check(camera_ctrl.is_interaction_locked, "Camera should be locked while dragging")

	var valid_cand: Dictionary = interaction.update_drag_at_world_pos(Vector3(0.5, 0.0, 0.5))
	_check(bool(valid_cand.get("is_valid", false)), "Expected valid drag candidate at (0.5, 0, 0.5)")
	_check(valid_cand.get("grid_pos", Vector3i.ZERO) == Vector3i(6, 0, 6), "Expected snapped grid_pos (6, 0, 6), got " + str(valid_cand.get("grid_pos", null)))

	var preview_node: Node3D = interaction.get_preview_node()
	_check(preview_node != null, "Preview node missing during drag")
	if preview_node != null:
		var mesh_inst := preview_node.get_node_or_null("BlockPreviewMesh") as MeshInstance3D
		_check(mesh_inst != null and mesh_inst.material_override != null, "Preview material missing")
		if mesh_inst != null and mesh_inst.material_override is StandardMaterial3D:
			var mat := mesh_inst.material_override as StandardMaterial3D
			var expected_color: Color = PieceCatalog.get_piece_definition("cube")["color"]
			_check(
				is_equal_approx(mat.albedo_color.r, expected_color.r) and is_equal_approx(mat.albedo_color.g, expected_color.g) and is_equal_approx(mat.albedo_color.b, expected_color.b),
				"Valid preview should preserve the piece's selected color"
			)
		var valid_indicator := preview_node.get_node_or_null("FootprintIndicator") as MeshInstance3D
		_check(valid_indicator != null and valid_indicator.material_override is StandardMaterial3D, "Valid footprint indicator missing")
		if valid_indicator != null and valid_indicator.material_override is StandardMaterial3D:
			var ind_mat := valid_indicator.material_override as StandardMaterial3D
			_check(ind_mat.albedo_color.g > ind_mat.albedo_color.r, "Valid footprint indicator should have green-dominant color")

	var commit_res: Dictionary = interaction.finish_drag()
	_check(bool(commit_res.get("committed", false)), "Valid drag did not commit")
	_check(not interaction.is_dragging(), "InteractionController still dragging after finish_drag")
	_check(not camera_ctrl.is_interaction_locked, "Camera should unlock after finish_drag")
	_check(manager.get_piece_count() == 1, "Expected 1 committed piece")
	_check(ui.get_tray_cards().size() == 4, "Tray card disappeared after placing piece (infinite stock violated)")

	# Second drag of the same piece type ("cube") moved out of bounds -> invalid -> cancelled cleanly.
	_check(interaction.start_tray_drag("cube", Vector2(100.0, 150.0), 0), "Second drag of cube failed (infinite stock)")
	var invalid_cand: Dictionary = interaction.update_drag_at_world_pos(Vector3(12.0, 0.0, 12.0))
	_check(not bool(invalid_cand.get("is_valid", true)), "Expected invalid candidate outside platform")

	var preview_invalid: Node3D = interaction.get_preview_node()
	if preview_invalid != null:
		var mesh_inst2 := preview_invalid.get_node_or_null("BlockPreviewMesh") as MeshInstance3D
		if mesh_inst2 != null and mesh_inst2.material_override is StandardMaterial3D:
			var mat2 := mesh_inst2.material_override as StandardMaterial3D
			var expected_color2: Color = PieceCatalog.get_piece_definition("cube")["color"]
			_check(
				is_equal_approx(mat2.albedo_color.r, expected_color2.r) and is_equal_approx(mat2.albedo_color.g, expected_color2.g) and is_equal_approx(mat2.albedo_color.b, expected_color2.b),
				"Invalid preview should preserve the piece's selected color"
			)
		var invalid_indicator := preview_invalid.get_node_or_null("FootprintIndicator") as MeshInstance3D
		_check(invalid_indicator != null and invalid_indicator.material_override is StandardMaterial3D, "Invalid footprint indicator missing")
		if invalid_indicator != null and invalid_indicator.material_override is StandardMaterial3D:
			var ind_mat2 := invalid_indicator.material_override as StandardMaterial3D
			_check(ind_mat2.albedo_color.r > ind_mat2.albedo_color.g, "Invalid footprint indicator should have red-dominant color")

	var cancel_res: Dictionary = interaction.finish_drag()
	_check(not bool(cancel_res.get("committed", true)), "Invalid drag should not commit")
	_check(manager.get_piece_count() == 1, "Invalid drag left a piece behind")
	_check(interaction.get_preview_node() == null, "Preview node remained after invalid drag cancel")
	_check(not camera_ctrl.is_interaction_locked, "Camera remained locked after invalid drag cancel")


func _test_screen_ray_drag_and_camera_lock(
	workspace: Node,
	manager: Node,
	interaction: Node,
	camera_ctrl: Node,
	ui: Node
) -> void:
	workspace.clear_construction()
	camera_ctrl.apply_immediate()
	var camera: Camera3D = camera_ctrl.get_camera()

	# Project the center of board cell (4, 0, 4) -> world (0.5, 0.0, 0.5) to screen coordinates.
	var target_world := Vector3(0.5, 0.0, 0.5)
	var target_screen: Vector2 = camera.unproject_position(target_world)
	_check(not ui.is_screen_point_in_tray(target_screen), "Target screen point unexpectedly inside tray: " + str(target_screen))

	# Emit tray_piece_drag_started via UI signal as if user pressed the Long Block card.
	var cards: Dictionary = ui.get_tray_cards()
	var long_card: Control = cards.get("long_block", null)
	_check(long_card != null, "Missing long_block card in tray")
	if long_card != null:
		var card_center: Vector2 = long_card.get_global_rect().get_center()
		ui.tray_piece_drag_started.emit("long_block", card_center)
		_check(interaction.is_dragging(), "UI tray_piece_drag_started did not start InteractionController drag")
		_check(camera_ctrl.is_interaction_locked, "Camera not locked after tray_piece_drag_started")
		var in_tray_cand: Dictionary = interaction.get_current_candidate()
		_check(not bool(in_tray_cand.get("is_valid", true)), "Preview inside tray should be invalid")

		# Attempt camera zoom while dragging; locked camera must ignore wheel event.
		var before_zoom: float = camera_ctrl.get_target_ortho_size()
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		camera_ctrl._unhandled_input(wheel)
		_check(is_equal_approx(camera_ctrl.get_target_ortho_size(), before_zoom), "Camera zoom changed while drag lock active")

		# Move pointer to projected world board point and release.
		var cand: Dictionary = interaction.update_drag(target_screen)
		_check(bool(cand.get("is_valid", false)), "Screen-ray drag over open platform failed: " + str(cand))
		var fin: Dictionary = interaction.finish_drag(target_screen)
		_check(bool(fin.get("committed", false)), "Screen-ray finish_drag failed to commit")
		_check(manager.get_piece_count() == 1, "Expected 1 piece after screen-ray commit")
		_check(not camera_ctrl.is_interaction_locked, "Camera remained locked after screen-ray finish_drag")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PHASE2_TESTS_PASSED")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		print("PHASE2_TESTS_FAILED: %d" % _failures.size())
		quit(1)
