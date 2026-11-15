extends SceneTree
## Automated verification suite for Phase 3 (independent shape/color catalog,
## preview color preservation + separated validity indicator, piece selection,
## 90-degree rotation with validation/rollback, deletion, and operation-based undo/redo).

const WORKSPACE_SCENE_PATH := "res://scenes/main/construction_workspace.tscn"
const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")
const PlacementSystem = preload("res://scripts/core/placement_system.gd")

var _failures: Array[String] = []
var _shape_signals: Array[String] = []
var _color_signals: Array[Dictionary] = []


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
	await physics_frame

	var manager = workspace.get_construction_manager()
	var interaction = workspace.get_interaction_controller()
	var camera_ctrl = workspace.get_camera_controller()
	var ui = workspace.get_ui()

	_check(manager != null and interaction != null and camera_ctrl != null and ui != null, "Workspace Phase 3 subsystems missing")
	if manager == null or interaction == null or camera_ctrl == null or ui == null:
		workspace.queue_free()
		await process_frame
		_finish()
		return

	_test_independent_shape_and_color_selection(ui)
	_test_preview_color_and_separate_validity_indicator(workspace, manager, interaction, ui)
	await _test_selection_and_ui_state(workspace, manager, interaction, camera_ctrl, ui)
	await _test_rotation_validation_and_rollback(workspace, manager, interaction, ui)
	await _test_delete_and_undo_redo_lifecycle(workspace, manager, interaction, ui)

	workspace.queue_free()
	await process_frame
	_finish()


func _test_independent_shape_and_color_selection(ui: Node) -> void:
	_shape_signals.clear()
	_color_signals.clear()
	ui.shape_selected.connect(func(shape_id: String) -> void:
		_shape_signals.append(shape_id)
	)
	ui.color_selected.connect(func(color_id: String, color_val: Color) -> void:
		_color_signals.append({"id": color_id, "color": color_val})
	)

	var palette: Array[Dictionary] = PieceCatalog.get_color_palette()
	_check(palette.size() >= 6, "Expected at least 6 colors in PieceCatalog palette, got %d" % palette.size())
	_check(ui.get_tray_cards().size() == 4, "Catalog must keep exactly 4 shape entries, got %d" % ui.get_tray_cards().size())
	_check(ui.get_color_buttons().size() == palette.size(), "UI color button count mismatch with PieceCatalog palette")

	ui.select_shape("cube")
	_check(ui.get_selected_shape() == "cube", "Failed to select initial shape 'cube'")

	ui.select_color("plum_purple")
	_check(ui.get_selected_color_id() == "plum_purple", "Selected color ID did not update to plum_purple")
	_check(ui.get_selected_shape() == "cube", "Selecting color unexpectedly changed selected shape")
	var expected_purple: Color = PieceCatalog.get_color_by_id("plum_purple")
	_check(_colors_equal(ui.get_selected_color(), expected_purple), "Selected color RGB mismatch for plum_purple")

	# Selecting a different shape preserves the previously chosen color.
	ui.select_shape("long_block")
	_check(ui.get_selected_shape() == "long_block", "Selected shape did not update to long_block")
	_check(ui.get_selected_color_id() == "plum_purple", "Selecting shape unexpectedly changed selected color")

	# Pressing a color button directly in UI updates color without altering shape.
	var cobalt_btn := ui.find_child("ColorButton_cobalt_blue", true, false) as Button
	_check(cobalt_btn != null, "Missing ColorButton_cobalt_blue in UI")
	if cobalt_btn != null:
		cobalt_btn.pressed.emit()
		_check(ui.get_selected_color_id() == "cobalt_blue", "Pressing Cobalt Blue swatch failed to update color")
		_check(ui.get_selected_shape() == "long_block", "Pressing swatch unexpectedly altered selected shape")

	_check(_color_signals.size() >= 2, "Expected color_selected signals when selecting colors")
	_check(_shape_signals.size() >= 2, "Expected shape_selected signals when selecting shapes")


func _test_preview_color_and_separate_validity_indicator(
	workspace: Node,
	manager: Node,
	interaction: Node,
	ui: Node
) -> void:
	workspace.clear_construction()
	ui.select_color("sunny_yellow")
	var yellow_color: Color = PieceCatalog.get_color_by_id("sunny_yellow")

	var cards: Dictionary = ui.get_tray_cards()
	var long_card: Control = cards.get("long_block", null)
	_check(long_card != null, "Missing long_block tray card")
	if long_card == null:
		return

	# Simulate tray drag triggered from UI so workspace passes selected UI color.
	ui.tray_piece_drag_started.emit("long_block", long_card.get_global_rect().get_center())
	_check(interaction.is_dragging(), "Drag did not start from tray_piece_drag_started")

	# Valid world position -> preview block preserves yellow_color, FootprintIndicator turns green.
	var valid_cand: Dictionary = interaction.update_drag_at_world_pos(Vector3(-1.5, 0.0, -1.5))
	_check(bool(valid_cand.get("is_valid", false)), "Expected valid candidate on empty platform: " + str(valid_cand))

	var preview_node: Node3D = interaction.get_preview_node()
	_check(preview_node != null, "Preview node missing at valid position")
	if preview_node != null:
		var block_mesh := preview_node.get_node_or_null("BlockPreviewMesh") as MeshInstance3D
		var footprint_ind := preview_node.get_node_or_null("FootprintIndicator") as MeshInstance3D
		_check(block_mesh != null and block_mesh.material_override is StandardMaterial3D, "BlockPreviewMesh material missing")
		_check(footprint_ind != null and footprint_ind.material_override is StandardMaterial3D, "FootprintIndicator material missing")
		if block_mesh != null and block_mesh.material_override is StandardMaterial3D:
			var pmat := block_mesh.material_override as StandardMaterial3D
			_check(_colors_equal(pmat.albedo_color, yellow_color), "Valid preview did not preserve sunny_yellow color")
		if footprint_ind != null and footprint_ind.material_override is StandardMaterial3D:
			var imat := footprint_ind.material_override as StandardMaterial3D
			_check(imat.albedo_color.g > imat.albedo_color.r, "Valid FootprintIndicator is not green-dominant")

	# Invalid world position -> preview block STILL preserves yellow_color, FootprintIndicator turns red.
	var invalid_cand: Dictionary = interaction.update_drag_at_world_pos(Vector3(12.0, 0.0, 12.0))
	_check(not bool(invalid_cand.get("is_valid", true)), "Expected invalid candidate outside platform")
	if preview_node != null and is_instance_valid(preview_node):
		var block_mesh2 := preview_node.get_node_or_null("BlockPreviewMesh") as MeshInstance3D
		var footprint_ind2 := preview_node.get_node_or_null("FootprintIndicator") as MeshInstance3D
		if block_mesh2 != null and block_mesh2.material_override is StandardMaterial3D:
			var pmat2 := block_mesh2.material_override as StandardMaterial3D
			_check(_colors_equal(pmat2.albedo_color, yellow_color), "Invalid preview altered block color instead of using indicator")
		if footprint_ind2 != null and footprint_ind2.material_override is StandardMaterial3D:
			var imat2 := footprint_ind2.material_override as StandardMaterial3D
			_check(imat2.albedo_color.r > imat2.albedo_color.g, "Invalid FootprintIndicator is not red-dominant")

	# Move back to valid world position and commit -> committed piece & 3D mesh have yellow_color.
	interaction.update_drag_at_world_pos(Vector3(-1.5, 0.0, -1.5))
	var commit_res: Dictionary = interaction.finish_drag()
	_check(bool(commit_res.get("committed", false)), "Failed to commit yellow long_block")
	_check(manager.get_piece_count() == 1, "Expected 1 placed piece after commit")

	var placed: Array = manager.get_placed_pieces()
	if placed.size() == 1:
		var pdata = placed[0]
		_check(_colors_equal(pdata.color, yellow_color), "Committed PlacedPieceData did not receive sunny_yellow color")
		var visuals: Array = workspace.get_placed_pieces()
		_check(visuals.size() == 1, "Expected 1 spawned visual piece")
		if visuals.size() == 1:
			var vmesh := visuals[0].get("mesh_instance", null) as MeshInstance3D
			_check(vmesh != null and vmesh.material_override is StandardMaterial3D, "Spawned piece visual material missing")
			if vmesh != null and vmesh.material_override is StandardMaterial3D:
				_check(_colors_equal((vmesh.material_override as StandardMaterial3D).albedo_color, yellow_color), "Spawned 3D piece mesh color mismatch")


func _test_selection_and_ui_state(
	workspace: Node,
	manager: Node,
	interaction: Node,
	camera_ctrl: Node,
	ui: Node
) -> void:
	workspace.clear_construction()
	camera_ctrl.apply_immediate()
	await physics_frame
	await process_frame

	var rotate_btn := ui.find_child("RotatePieceButton", true, false) as Button
	var delete_btn := ui.find_child("DeletePieceButton", true, false) as Button
	var undo_btn := ui.find_child("UndoButton", true, false) as Button
	var redo_btn := ui.find_child("RedoButton", true, false) as Button
	_check(rotate_btn != null and delete_btn != null and undo_btn != null and redo_btn != null, "Editing toolbar buttons missing")

	var highlight := workspace.get_selection_highlight() as MeshInstance3D
	_check(highlight != null, "Workspace SelectionHighlight missing")
	_check(interaction.get_selected_instance_id() == -1, "Expected no initial selection")
	if highlight != null:
		_check(not highlight.visible, "SelectionHighlight should start hidden")
	if rotate_btn != null and delete_btn != null:
		_check(rotate_btn.disabled and delete_btn.disabled, "Rotate and Delete buttons must start disabled")

	# Place a cobalt blue cube near board center at (4, 0, 4).
	var blue_col: Color = PieceCatalog.get_color_by_id("cobalt_blue")
	var place_res: Dictionary = manager.place_piece("cube", Vector3i(4, 0, 4), 0, blue_col)
	_check(bool(place_res.get("success", false)), "Failed to place cube for tap selection test")
	var placed_pieces: Array = manager.get_placed_pieces()
	var cube_id: int = placed_pieces[0].instance_id
	await physics_frame
	await process_frame

	var camera: Camera3D = camera_ctrl.get_camera()
	var cube_center_world: Vector3 = PieceCatalog.grid_to_piece_center_base(Vector3i(4, 0, 4), Vector3.ONE, 0, manager.board_size) + Vector3(0.0, 0.5, 0.0)
	var cube_screen: Vector2 = camera.unproject_position(cube_center_world)
	_check(not ui.is_screen_point_over_ui(cube_screen), "Projected cube center unexpectedly under UI: " + str(cube_screen))

	var yaw_before: int = camera_ctrl.get_current_step_index()
	var zoom_before: float = camera_ctrl.get_target_ortho_size()
	var tapped_id: int = interaction.tap_screen_position(cube_screen)
	_check(tapped_id == cube_id, "Tap on cube center returned %d instead of %d" % [tapped_id, cube_id])
	_check(interaction.get_selected_instance_id() == cube_id, "InteractionController did not select tapped cube")
	_check(camera_ctrl.get_current_step_index() == yaw_before and is_equal_approx(camera_ctrl.get_target_ortho_size(), zoom_before), "Tap selection unexpectedly moved camera")
	if highlight != null:
		_check(highlight.visible, "SelectionHighlight did not become visible after selecting cube")
	if rotate_btn != null and delete_btn != null:
		_check((not rotate_btn.disabled) and (not delete_btn.disabled), "Rotate/Delete buttons did not enable on selection")

	# Tap empty corner of the platform at (0, 0, 0) -> selection should clear.
	var empty_world: Vector3 = PieceCatalog.grid_to_piece_center_base(Vector3i(0, 0, 0), Vector3.ONE, 0, manager.board_size)
	var empty_screen: Vector2 = camera.unproject_position(empty_world)
	var tapped_empty: int = interaction.tap_screen_position(empty_screen)
	_check(tapped_empty == -1, "Tapping empty board cell returned non-empty ID %d" % tapped_empty)
	_check(interaction.get_selected_instance_id() == -1, "Selection did not clear on empty tap")
	if highlight != null:
		_check(not highlight.visible, "SelectionHighlight stayed visible after clearing selection")
	if rotate_btn != null and delete_btn != null:
		_check(rotate_btn.disabled and delete_btn.disabled, "Rotate/Delete buttons stayed enabled after clearing selection")


func _test_rotation_validation_and_rollback(
	workspace: Node,
	manager: Node,
	interaction: Node,
	ui: Node
) -> void:
	# 1. Valid 90-degree rotation of long_block updates state, visual rotation, and highlight.
	workspace.clear_construction()
	var lb_res: Dictionary = manager.place_piece("long_block", Vector3i(3, 0, 3), 0, PieceCatalog.get_color_by_id("coral_red"), false)
	_check(bool(lb_res.get("success", false)), "Failed to place long_block for valid rotation test")
	var lb_data = manager.get_placed_pieces()[0]
	var lb_id: int = lb_data.instance_id
	interaction.select_piece(lb_id)

	ui.rotate_piece_pressed.emit()
	var after_rot = manager.get_piece_by_id(lb_id)
	_check(after_rot != null and after_rot.rotation_steps == 1, "Valid 90-degree rotation via UI did not advance rotation_steps to 1")
	_check(manager.can_undo(), "Successful rotation was not recorded in undo history")
	var visual_node: Node3D = workspace.get_placed_pieces()[0]["node"] as Node3D
	_check(is_equal_approx(visual_node.rotation.y, PI * 0.5), "Visual node rotation.y did not update after rotate_piece")
	var highlight := workspace.get_selection_highlight() as MeshInstance3D
	_check(highlight != null and highlight.visible and is_equal_approx(highlight.rotation.y, PI * 0.5), "SelectionHighlight did not stay synced with rotated piece")

	# 2. Invalid rotation: out of bounds at board edge (grid_pos=(11,0,3), rot=1 -> rotating to rot=2 tries x=12).
	workspace.clear_construction()
	var edge_res: Dictionary = manager.place_piece("long_block", Vector3i(11, 0, 3), 1, PieceCatalog.get_color_by_id("sage_green"), false)
	_check(bool(edge_res.get("success", false)), "Failed to place edge long_block at (11,0,3) rot=1")
	var edge_id: int = manager.get_placed_pieces()[0].instance_id
	interaction.select_piece(edge_id)
	var rot_fail_bounds: Dictionary = interaction.rotate_selected_piece(1)
	_check(not bool(rot_fail_bounds.get("success", true)), "Out-of-bounds rotation unexpectedly succeeded")
	var edge_after = manager.get_piece_by_id(edge_id)
	_check(edge_after.rotation_steps == 1 and edge_after.grid_pos == Vector3i(11, 0, 3), "Out-of-bounds failed rotation mutated piece state")
	_check(not manager.can_undo(), "Failed out-of-bounds rotation should not add an undo entry")

	# 3. Invalid rotation: collision with adjacent cube.
	workspace.clear_construction()
	manager.place_piece("long_block", Vector3i(2, 0, 2), 0, PieceCatalog.get_color_by_id("cobalt_blue"), false)
	manager.place_piece("cube", Vector3i(2, 0, 3), 0, PieceCatalog.get_color_by_id("sunny_yellow"), false)
	var col_lb_id: int = manager.get_placed_pieces()[0].instance_id
	interaction.select_piece(col_lb_id)
	var rot_fail_col: Dictionary = interaction.rotate_selected_piece(1)
	_check(not bool(rot_fail_col.get("success", true)), "Colliding rotation unexpectedly succeeded")
	var col_lb_after = manager.get_piece_by_id(col_lb_id)
	_check(col_lb_after.rotation_steps == 0 and col_lb_after.grid_pos == Vector3i(2, 0, 2), "Colliding rotation did not roll back state")

	# 4. Invalid rotation: rotating base piece removes support under stacked top block -> rollback.
	workspace.clear_construction()
	manager.place_piece("long_block", Vector3i(2, 0, 2), 0, PieceCatalog.get_color_by_id("terracotta"), false)
	manager.place_piece("cube", Vector3i(3, 4, 2), 0, PieceCatalog.get_color_by_id("plum_purple"), false)
	var base_id: int = manager.get_placed_pieces()[0].instance_id
	interaction.select_piece(base_id)
	var rot_fail_support: Dictionary = interaction.rotate_selected_piece(1)
	_check(not bool(rot_fail_support.get("success", true)), "Rotation breaking support under stacked cube unexpectedly succeeded")
	var base_after = manager.get_piece_by_id(base_id)
	_check(base_after.rotation_steps == 0 and base_after.grid_pos == Vector3i(2, 0, 2), "Support-breaking rotation did not roll back state")
	var consistency: Dictionary = PlacementSystem.validate_state_consistency(manager.get_placed_pieces(), manager.board_size)
	_check(bool(consistency.get("is_valid", false)), "Board state inconsistent after blocked support rotation: " + str(consistency))
	await process_frame


func _test_delete_and_undo_redo_lifecycle(
	workspace: Node,
	manager: Node,
	interaction: Node,
	ui: Node
) -> void:
	workspace.clear_construction()
	var undo_btn := ui.find_child("UndoButton", true, false) as Button
	var redo_btn := ui.find_child("RedoButton", true, false) as Button
	var rotate_btn := ui.find_child("RotatePieceButton", true, false) as Button
	var delete_btn := ui.find_child("DeletePieceButton", true, false) as Button
	var highlight := workspace.get_selection_highlight() as MeshInstance3D

	_check(not manager.can_undo() and not manager.can_redo(), "History should start empty after clear_construction")
	if undo_btn != null and redo_btn != null:
		_check(undo_btn.disabled and redo_btn.disabled, "Undo and Redo buttons should start disabled")

	# Op 1: Place plum_purple long_block via drag interaction.
	ui.select_color("plum_purple")
	var purple: Color = PieceCatalog.get_color_by_id("plum_purple")
	_check(interaction.start_tray_drag("long_block", Vector2(100, 150), 0, purple), "Op 1 drag start failed")
	interaction.update_drag_at_world_pos(Vector3(-1.5, 0.0, -1.5))
	var op1: Dictionary = interaction.finish_drag()
	_check(bool(op1.get("committed", false)), "Op 1 place failed")
	var lb_id: int = manager.get_placed_pieces()[0].instance_id
	_check(manager.can_undo() and not manager.can_redo(), "Undo should be available after Op 1")
	if undo_btn != null and redo_btn != null:
		_check((not undo_btn.disabled) and redo_btn.disabled, "UI Undo/Redo button states incorrect after Op 1")

	# Op 2: Select and rotate long_block 90 degrees via UI signal.
	interaction.select_piece(lb_id)
	ui.rotate_piece_pressed.emit()
	_check(manager.get_piece_by_id(lb_id).rotation_steps == 1, "Op 2 rotate failed")

	# Op 3: Place cobalt_blue ramp via drag interaction.
	ui.select_color("cobalt_blue")
	var blue: Color = PieceCatalog.get_color_by_id("cobalt_blue")
	_check(interaction.start_tray_drag("ramp", Vector2(100, 250), 0, blue), "Op 3 drag start failed")
	interaction.update_drag_at_world_pos(Vector3(1.5, 0.0, 1.5))
	var op3: Dictionary = interaction.finish_drag()
	_check(bool(op3.get("committed", false)), "Op 3 ramp place failed")
	_check(manager.get_piece_count() == 2, "Expected 2 pieces before delete")
	var ramp_id: int = manager.get_placed_pieces()[1].instance_id

	# Op 4: Select ramp and delete via UI signal.
	interaction.select_piece(ramp_id)
	ui.delete_piece_pressed.emit()
	await process_frame
	_check(manager.get_piece_count() == 1, "Op 4 delete did not remove ramp")
	_check(workspace.get_placed_pieces().size() == 1, "Workspace visuals count mismatch after delete")
	_check(interaction.get_selected_instance_id() == -1, "Selection should clear after deleting selected piece")
	if highlight != null:
		_check(not highlight.visible, "SelectionHighlight stayed visible after delete")
	if rotate_btn != null and delete_btn != null:
		_check(rotate_btn.disabled and delete_btn.disabled, "Edit buttons stayed enabled after delete")

	# Undo #1 -> undo delete (ramp restored with original ID and color).
	ui.undo_pressed.emit()
	await process_frame
	_check(manager.get_piece_count() == 2, "Undo #1 did not restore deleted ramp")
	_check(workspace.get_placed_pieces().size() == 2, "Workspace visuals count mismatch after Undo #1")
	var restored_ramp = manager.get_piece_by_id(ramp_id)
	_check(restored_ramp != null and _colors_equal(restored_ramp.color, blue), "Undo #1 did not preserve ramp ID or color")
	if redo_btn != null:
		_check(not redo_btn.disabled, "RedoButton did not enable after Undo #1")

	# Undo #2 -> undo place ramp.
	ui.undo_pressed.emit()
	await process_frame
	_check(manager.get_piece_count() == 1, "Undo #2 did not remove ramp")
	_check(workspace.get_placed_pieces().size() == 1, "Workspace visuals mismatch after Undo #2")
	_check(manager.get_piece_by_id(ramp_id) == null, "Ramp still present after Undo #2")

	# Undo #3 -> undo rotate long_block (rotation_steps back to 0 and visual synced).
	ui.undo_pressed.emit()
	await process_frame
	var lb_unrot = manager.get_piece_by_id(lb_id)
	_check(lb_unrot != null and lb_unrot.rotation_steps == 0, "Undo #3 did not revert long_block rotation")
	var lb_vis: Node3D = workspace.get_placed_pieces()[0]["node"] as Node3D
	_check(is_equal_approx(lb_vis.rotation.y, 0.0), "Visual rotation.y did not revert on Undo #3")

	# Undo #4 -> undo place long_block.
	ui.undo_pressed.emit()
	await process_frame
	_check(manager.get_piece_count() == 0, "Undo #4 did not remove long_block")
	_check(workspace.get_placed_pieces().size() == 0, "Workspace visuals non-empty after Undo #4")
	_check(not manager.can_undo() and manager.can_redo(), "History flags invalid after full undo")
	if undo_btn != null and redo_btn != null:
		_check(undo_btn.disabled and (not redo_btn.disabled), "Undo/Redo button states invalid after full undo")

	# Redo #1..#4 -> replay all 4 operations cleanly.
	ui.redo_pressed.emit()
	await process_frame
	_check(manager.get_piece_count() == 1 and manager.get_piece_by_id(lb_id) != null, "Redo #1 did not restore long_block")
	_check(_colors_equal(manager.get_piece_by_id(lb_id).color, purple), "Redo #1 did not preserve long_block color")

	ui.redo_pressed.emit()
	await process_frame
	_check(manager.get_piece_by_id(lb_id).rotation_steps == 1, "Redo #2 did not re-apply long_block rotation")

	ui.redo_pressed.emit()
	await process_frame
	_check(manager.get_piece_count() == 2 and manager.get_piece_by_id(ramp_id) != null, "Redo #3 did not restore ramp")

	ui.redo_pressed.emit()
	await process_frame
	_check(manager.get_piece_count() == 1 and manager.get_piece_by_id(ramp_id) == null, "Redo #4 did not re-delete ramp")
	_check(not manager.can_redo() and manager.can_undo(), "Redo stack should be empty after Redo #4")
	if redo_btn != null:
		_check(redo_btn.disabled, "RedoButton stayed enabled after final redo")

	# Verify consistency and that a new operation clears the redo stack.
	ui.undo_pressed.emit() # Restores ramp -> can_redo is true.
	await process_frame
	_check(manager.can_redo(), "Expected redo available after undo before new operation")
	manager.place_piece("cube", Vector3i(0, 0, 7), 0, PieceCatalog.get_color_by_id("coral_red"), true)
	await process_frame
	_check(not manager.can_redo(), "New operation should clear redo stack")
	_check(workspace.get_placed_pieces().size() == manager.get_piece_count(), "Scene visuals out of sync with manager state")
	var final_consistency: Dictionary = PlacementSystem.validate_state_consistency(manager.get_placed_pieces(), manager.board_size)
	_check(bool(final_consistency.get("is_valid", false)), "Final state consistency check failed: " + str(final_consistency))


func _colors_equal(a: Color, b: Color) -> bool:
	return (
		is_equal_approx(a.r, b.r)
		and is_equal_approx(a.g, b.g)
		and is_equal_approx(a.b, b.b)
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PHASE3_TESTS_PASSED")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		print("PHASE3_TESTS_FAILED: %d" % _failures.size())
		quit(1)
