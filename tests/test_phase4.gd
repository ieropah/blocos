extends SceneTree
## Automated verification suite for Phase 4 (rounded tray UI refinement, exact 90-deg
## rotation preservation, project gallery CRUD, auto-naming, local JSON persistence,
## autosave, version/schema/spatial validation, and scene reconstruction).

const WORKSPACE_SCENE_PATH := "res://scenes/main/construction_workspace.tscn"
const TEST_STORAGE_DIR := "user://test_phase4_projects"

const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")
const PlacementSystem = preload("res://scripts/core/placement_system.gd")
const ProjectData = preload("res://scripts/core/project_data.gd")
const ProjectSerializer = preload("res://scripts/core/project_serializer.gd")
const ProjectRepository = preload("res://scripts/core/project_repository.gd")

var _failures: Array[String] = []
var _completed_stages: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_clean_test_storage(TEST_STORAGE_DIR)

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
	var save_manager = workspace.get_save_manager()
	var gallery_ui = workspace.get_gallery_ui()

	_check(
		manager != null and interaction != null and camera_ctrl != null
		and ui != null and save_manager != null and gallery_ui != null,
		"Workspace Phase 4 subsystems missing"
	)
	if (
		manager == null or interaction == null or camera_ctrl == null
		or ui == null or save_manager == null or gallery_ui == null
	):
		workspace.queue_free()
		await process_frame
		_clean_test_storage(TEST_STORAGE_DIR)
		_finish()
		return

	save_manager.set_storage_dir(TEST_STORAGE_DIR)

	_test_tray_rounded_corners_and_preserved_geometry(workspace, ui)
	await _test_rotation_exact_90_degree_increments(workspace, manager, interaction, ui)
	await _test_project_creation_auto_naming_rename_delete(workspace, camera_ctrl, save_manager, gallery_ui)
	await _test_autosave_persistence_and_scene_reconstruction(packed, workspace, manager, save_manager, interaction, ui)
	_test_validation_versioning_and_corruption_safety(workspace, manager, save_manager, gallery_ui)

	_check(_completed_stages == 5, "Expected 5 completed test stages, got %d" % _completed_stages)

	workspace.queue_free()
	await process_frame
	_clean_test_storage(TEST_STORAGE_DIR)
	_finish()


func _test_tray_rounded_corners_and_preserved_geometry(workspace: Node, ui: Node) -> void:
	var tray := ui.find_child("TrayPanel", true, false) as PanelContainer
	_check(tray != null, "TrayPanel missing")
	if tray != null:
		var tray_style := tray.get_theme_stylebox("panel") as StyleBoxFlat
		_check(tray_style != null, "TrayPanel missing StyleBoxFlat")
		if tray_style != null:
			_check(
				tray_style.corner_radius_top_left >= 24
				and tray_style.corner_radius_top_right >= 24
				and tray_style.corner_radius_bottom_left >= 24
				and tray_style.corner_radius_bottom_right >= 24,
				"TrayPanel must have rounded corners on all 4 sides"
			)
		_check(tray.offset_left > 0.0 and tray.offset_top > 0.0 and tray.offset_bottom < 0.0, "TrayPanel should be inset cleanly for rounded frame")

	var palette_box := ui.find_child("ColorPaletteContainer", true, false) as PanelContainer
	_check(palette_box != null, "ColorPaletteContainer missing in tray")
	if palette_box != null:
		var pal_style := palette_box.get_theme_stylebox("panel") as StyleBoxFlat
		_check(pal_style != null and pal_style.corner_radius_top_left >= 16, "ColorPaletteContainer should have rounded corners")

	var color_buttons: Dictionary = ui.get_color_buttons()
	_check(color_buttons.size() >= 6, "Expected >= 6 color swatches")
	for btn_var: Variant in color_buttons.values():
		var btn := btn_var as Button
		if btn != null:
			var bstyle := btn.get_theme_stylebox("normal") as StyleBoxFlat
			_check(bstyle != null and bstyle.corner_radius_top_left >= 16, "Color swatch missing rounded corners")

	var cards: Dictionary = ui.get_tray_cards()
	_check(cards.size() == 4, "Tray must keep exact 4 shape cards")
	for card_var: Variant in cards.values():
		var card := card_var as PanelContainer
		_check(card != null, "Invalid tray card control")
		if card != null:
			var cstyle := card.get_theme_stylebox("panel") as StyleBoxFlat
			_check(
				cstyle != null
				and cstyle.corner_radius_top_left >= 20
				and cstyle.corner_radius_bottom_right >= 20,
				"Tray card missing rounded corners: " + card.name
			)
			var badge := card.find_child("IconBadge", true, false) as PanelContainer
			var icon := card.find_child("ShapeIcon", true, false) as Control
			_check(badge != null and icon != null, "Tray card missing IconBadge or ShapeIcon: " + card.name)
			if badge != null:
				var istyle := badge.get_theme_stylebox("panel") as StyleBoxFlat
				_check(istyle != null and istyle.corner_radius_top_left >= 14, "IconBadge should have rounded corners")

	# Verify TopBarPanel & GalleryButton do not overlap TrayPanel.
	var top_bar := ui.find_child("TopBarPanel", true, false) as PanelContainer
	var gallery_btn := ui.get_gallery_button() as Button
	_check(top_bar != null and gallery_btn != null, "TopBarPanel or GalleryButton missing")
	if top_bar != null and tray != null:
		_check(not top_bar.get_global_rect().intersects(tray.get_global_rect()), "TopBarPanel overlaps TrayPanel")

	# Verify 3D piece geometry stays beveled and unchanged.
	var sample_pieces: Array[Dictionary] = workspace.get_placed_pieces()
	_check(sample_pieces.size() >= 4, "Starter 3D pieces missing")
	for entry: Dictionary in sample_pieces:
		var mesh := entry.get("mesh", null) as ArrayMesh
		_check(mesh != null and mesh.get_surface_count() > 0, "Missing beveled mesh surface")
		if mesh != null and mesh.get_surface_count() > 0:
			var verts := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			_check(verts.size() > 24, "3D mesh should remain beveled (>24 verts)")

	_completed_stages += 1


func _test_rotation_exact_90_degree_increments(
	workspace: Node,
	manager: Node,
	interaction: Node,
	ui: Node
) -> void:
	workspace.clear_construction()
	var lb_res: Dictionary = manager.place_piece("long_block", Vector3i(3, 0, 3), 0, PieceCatalog.get_color_by_id("cobalt_blue"), false)
	_check(bool(lb_res.get("success", false)), "Failed to place long_block for 90-degree cycle test")
	var lb_id: int = manager.get_placed_pieces()[0].instance_id
	interaction.select_piece(lb_id)

	var expected_steps: Array[int] = [1, 2, 3, 0]
	var expected_yaws: Array[float] = [PI * 0.5, PI, PI * 1.5, 0.0]
	for i in range(4):
		ui.rotate_piece_pressed.emit()
		await process_frame
		var piece_after = manager.get_piece_by_id(lb_id)
		var visual_node: Node3D = workspace.get_placed_pieces()[0]["node"] as Node3D
		_check(
			piece_after != null and piece_after.rotation_steps == expected_steps[i],
			"Click %d expected rotation_steps %d, got %d" % [i + 1, expected_steps[i], piece_after.rotation_steps if piece_after != null else -1]
		)
		_check(
			visual_node != null and is_equal_approx(fposmod(visual_node.rotation.y, TAU), expected_yaws[i]),
			"Click %d expected vertical yaw %.3f, got %.3f" % [i + 1, expected_yaws[i], visual_node.rotation.y]
		)

	# Invalid rotation at border preserves previous valid position and rotation.
	workspace.clear_construction()
	manager.place_piece("long_block", Vector3i(11, 0, 2), 1, PieceCatalog.get_color_by_id("terracotta"), false)
	var edge_id: int = manager.get_placed_pieces()[0].instance_id
	interaction.select_piece(edge_id)
	var bad_rot: Dictionary = interaction.rotate_selected_piece(1)
	_check(not bool(bad_rot.get("success", true)), "Invalid border rotation should be rejected")
	var edge_after = manager.get_piece_by_id(edge_id)
	_check(edge_after.grid_pos == Vector3i(11, 0, 2) and edge_after.rotation_steps == 1, "Invalid rotation modified previous valid state")

	_completed_stages += 1


func _test_project_creation_auto_naming_rename_delete(
	workspace: Node,
	camera_ctrl: Node,
	save_manager: Node,
	gallery_ui: Node
) -> void:
	workspace.open_gallery()
	await process_frame
	_check(gallery_ui.is_gallery_open(), "Gallery did not open")
	_check(camera_ctrl.is_interaction_locked, "Camera should lock when gallery is open")

	# Create 3 projects with automatic naming via gallery.
	gallery_ui.new_project_requested.emit()
	await process_frame
	_check(not gallery_ui.is_gallery_open(), "Gallery should close after creating new project")
	_check(not camera_ctrl.is_interaction_locked, "Camera should unlock when gallery closes")

	workspace.open_gallery()
	gallery_ui.new_project_requested.emit()
	await process_frame

	workspace.open_gallery()
	gallery_ui.new_project_requested.emit()
	await process_frame

	var projects: Array = save_manager.list_projects()
	_check(projects.size() == 3, "Expected 3 created projects, got %d" % projects.size())
	if projects.size() == 3:
		_check(projects[0].project_name == "Construction 1", "Expected Construction 1, got " + projects[0].project_name)
		_check(projects[1].project_name == "Construction 2", "Expected Construction 2, got " + projects[1].project_name)
		_check(projects[2].project_name == "Construction 3", "Expected Construction 3, got " + projects[2].project_name)
		_check(
			projects[0].project_id != projects[1].project_id
			and projects[1].project_id != projects[2].project_id,
			"Project IDs must be unique"
		)

		# Rename project 2 through GalleryUI inline rename flow.
		workspace.open_gallery()
		await process_frame
		_check(gallery_ui.get_project_cards().size() == 3, "Gallery UI should display 3 cards")
		var p2_id: String = projects[1].project_id
		gallery_ui.begin_rename(p2_id, projects[1].project_name)
		var rename_input := gallery_ui.find_child("RenameLineEdit", true, false) as LineEdit
		_check(rename_input != null, "RenameLineEdit missing")
		if rename_input != null:
			rename_input.text = "Castle Tower"
			gallery_ui.submit_rename()
		await process_frame

		var reloaded_p2: Dictionary = save_manager.get_repository().load_project(p2_id)
		_check(bool(reloaded_p2.get("success", false)), "Failed to load renamed project")
		if bool(reloaded_p2.get("success", false)):
			_check(reloaded_p2["project"].project_name == "Castle Tower", "Project rename did not persist")

		# Empty rename must be rejected safely.
		var empty_res: Dictionary = workspace.rename_project(p2_id, "   ")
		_check(not bool(empty_res.get("success", true)), "Empty rename should fail")
		var check_p2: Dictionary = save_manager.get_repository().load_project(p2_id)
		_check(check_p2["project"].project_name == "Castle Tower", "Empty rename overwrote valid name")

		# Delete project 2 via GalleryUI signal.
		gallery_ui.delete_project_requested.emit(p2_id)
		await process_frame
		_check(save_manager.list_projects().size() == 2, "Expected 2 projects after delete")
		_check(not save_manager.get_repository().project_exists(p2_id), "Deleted project file still exists")

		# Creating next project continues sequence without colliding.
		var p4_res: Dictionary = workspace.create_new_project()
		_check(bool(p4_res.get("success", false)), "Creating 4th project failed")
		if bool(p4_res.get("success", false)):
			_check(p4_res["project"].project_name == "Construction 4", "Expected Construction 4, got " + p4_res["project"].project_name)

		workspace.close_gallery()

	_completed_stages += 1


func _test_autosave_persistence_and_scene_reconstruction(
	packed: PackedScene,
	workspace: Node,
	manager: Node,
	save_manager: Node,
	interaction: Node,
	ui: Node
) -> void:
	# Start fresh in clean project storage for deterministic verification.
	workspace.close_gallery()
	_clean_test_storage(TEST_STORAGE_DIR)
	save_manager.set_storage_dir(TEST_STORAGE_DIR)

	var res_a: Dictionary = workspace.create_new_project("Project Alpha")
	_check(bool(res_a.get("success", false)), "Failed to create Project Alpha")
	var proj_a_id: String = res_a["project"].project_id
	_check(manager.get_piece_count() == 0, "New project must start with empty board")

	# 1. Place sage_green square_plate via drag interaction -> autosaves.
	var green: Color = PieceCatalog.get_color_by_id("sage_green")
	_check(interaction.start_tray_drag("square_plate", Vector2(100, 300), 0, green), "Drag square_plate failed")
	interaction.update_drag_at_world_pos(PieceCatalog.grid_to_piece_center_base(Vector3i(2, 0, 2), Vector3(2.0, 0.25, 2.0), 0, manager.board_size))
	_check(bool(interaction.finish_drag().get("committed", false)), "Failed committing square_plate")

	# 2. Place plum_purple long_block on top at gy=1 and rotate 90 degrees -> autosaves.
	var purple: Color = PieceCatalog.get_color_by_id("plum_purple")
	var lb_place: Dictionary = manager.place_piece("long_block", Vector3i(2, 1, 2), 0, purple)
	_check(bool(lb_place.get("success", false)), "Failed placing long_block on plate")
	var lb_id: int = int(lb_place.get("instance_id", -1))
	interaction.select_piece(lb_id)
	ui.rotate_piece_pressed.emit()
	await process_frame

	# 3. Place terracotta ramp rotated 2 steps, plus temp cube then delete + undo + redo -> autosaves.
	var orange: Color = PieceCatalog.get_color_by_id("terracotta")
	manager.place_piece("ramp", Vector3i(5, 0, 5), 2, orange)
	var tmp_cube: Dictionary = manager.place_piece("cube", Vector3i(0, 0, 7), 0, PieceCatalog.get_color_by_id("coral_red"))
	var tmp_id: int = int(tmp_cube.get("instance_id", -1))
	interaction.select_piece(tmp_id)
	ui.delete_piece_pressed.emit()
	await process_frame

	# Check undo restores cube and autosaves (4 pieces on disk), then redo removes cube again and autosaves (3 pieces on disk).
	ui.undo_pressed.emit()
	await process_frame
	var disk_after_undo: Dictionary = save_manager.get_repository().load_project(proj_a_id)
	_check(bool(disk_after_undo.get("success", false)) and disk_after_undo["project"].get_piece_count() == 4, "Autosave after undo failed")

	ui.redo_pressed.emit()
	await process_frame
	var disk_after_redo: Dictionary = save_manager.get_repository().load_project(proj_a_id)
	_check(bool(disk_after_redo.get("success", false)) and disk_after_redo["project"].get_piece_count() == 3, "Autosave after redo failed")

	# Create independent second project and add 1 cube.
	var res_b: Dictionary = workspace.create_new_project("Project Beta")
	_check(bool(res_b.get("success", false)), "Failed to create Project Beta")
	var proj_b_id: String = res_b["project"].project_id
	_check(manager.get_piece_count() == 0, "Project Beta must start empty without leaking Alpha pieces")
	manager.place_piece("cube", Vector3i(6, 0, 1), 3, PieceCatalog.get_color_by_id("cobalt_blue"))
	await process_frame

	# Verify Alpha on disk is still completely intact while Beta has 1 piece.
	var disk_a: Dictionary = save_manager.get_repository().load_project(proj_a_id)
	var disk_b: Dictionary = save_manager.get_repository().load_project(proj_b_id)
	_check(disk_a["project"].get_piece_count() == 3, "Project Alpha count changed unexpectedly")
	_check(disk_b["project"].get_piece_count() == 1, "Project Beta count mismatch")

	# Reopen Alpha in same workspace -> check logical & 3D scene reconstruction.
	var reopen_a: Dictionary = workspace.open_project(proj_a_id)
	_check(bool(reopen_a.get("success", false)), "Failed to reopen Project Alpha")
	_check(ui.get_active_project_name() == "Project Alpha", "Active project label did not update on open")
	_check(manager.get_piece_count() == 3, "Reopened Project Alpha piece count mismatch")
	_check(workspace.get_placed_pieces().size() == 3, "Reopened Project Alpha 3D visual node count mismatch")

	# Simulate complete app close + reopen by instantiating a fresh ConstructionWorkspace.
	var fresh_workspace := packed.instantiate()
	root.add_child(fresh_workspace)
	await process_frame
	var fresh_save = fresh_workspace.get_save_manager()
	fresh_save.set_storage_dir(TEST_STORAGE_DIR)
	var fresh_open: Dictionary = fresh_workspace.open_project(proj_a_id)
	_check(bool(fresh_open.get("success", false)), "Fresh workspace failed to load Project Alpha from JSON")

	var fresh_manager = fresh_workspace.get_construction_manager()
	var restored_pieces: Array = fresh_manager.get_placed_pieces()
	_check(restored_pieces.size() == 3, "Fresh workspace expected 3 restored pieces")
	var found_rotated_lb := false
	var found_ramp := false
	var found_plate := false
	for p in restored_pieces:
		if p.piece_id == "square_plate" and p.grid_pos == Vector3i(2, 0, 2) and _colors_equal(p.color, green):
			found_plate = true
		elif p.piece_id == "long_block" and p.grid_pos == Vector3i(2, 1, 2) and p.rotation_steps == 1 and _colors_equal(p.color, purple):
			found_rotated_lb = true
		elif p.piece_id == "ramp" and p.grid_pos == Vector3i(5, 0, 5) and p.rotation_steps == 2 and _colors_equal(p.color, orange):
			found_ramp = true
	_check(found_plate and found_rotated_lb and found_ramp, "Restored pieces lost type, grid_pos, rotation, or color")

	# Check 3D mesh node transform & material on the reconstructed scene.
	var fresh_visuals: Array = fresh_workspace.get_placed_pieces()
	_check(fresh_visuals.size() == 3, "Fresh workspace 3D visuals mismatch")
	var matched_purple_mesh := false
	for vis: Dictionary in fresh_visuals:
		if vis["piece_id"] == "long_block" and int(vis["rotation_steps"]) == 1:
			var n3d := vis["node"] as Node3D
			var minstance := vis["mesh_instance"] as MeshInstance3D
			if (
				n3d != null
				and is_equal_approx(n3d.position.y, 0.25)
				and is_equal_approx(n3d.rotation.y, PI * 0.5)
				and minstance != null
				and minstance.material_override is StandardMaterial3D
				and _colors_equal((minstance.material_override as StandardMaterial3D).albedo_color, purple)
			):
				matched_purple_mesh = true
	_check(matched_purple_mesh, "Reconstructed 3D node did not preserve height (0.25), 90-deg rotation, or color")

	fresh_workspace.queue_free()
	await process_frame
	_completed_stages += 1


func _test_validation_versioning_and_corruption_safety(
	workspace: Node,
	manager: Node,
	save_manager: Node,
	gallery_ui: Node
) -> void:
	var repo: ProjectRepository = save_manager.get_repository()
	var pieces_before: int = manager.get_piece_count()
	var active_before: String = save_manager.get_current_project_id()

	# 1. Missing project file fails gracefully and surfaces gallery error.
	var missing_res: Dictionary = workspace.open_project("nonexistent_proj_999")
	_check(not bool(missing_res.get("success", true)), "Missing project unexpectedly loaded")
	_check(not gallery_ui.get_error_message().is_empty(), "Gallery error banner not populated on missing file")

	# 2. Malformed JSON does not crash and does not overwrite/delete the corrupt file.
	var corrupt_path: String = repo.get_project_file_path("corrupt_json_proj")
	var wf := FileAccess.open(corrupt_path, FileAccess.WRITE)
	_check(wf != null, "Failed to write corrupt test fixture")
	if wf != null:
		wf.store_string("{ this is not valid json !!!")
		wf.close()

	var corrupt_res: Dictionary = workspace.open_project("corrupt_json_proj")
	_check(not bool(corrupt_res.get("success", true)), "Malformed JSON unexpectedly succeeded")
	_check(str(corrupt_res.get("reason", "")) == "malformed_json", "Expected malformed_json reason")
	_check(FileAccess.file_exists(corrupt_path), "Corrupt file was unexpectedly deleted")

	# 3. Unsupported future format version rejected.
	var future_json := JSON.stringify({
		"project_id": "future_proj",
		"project_name": "Future Build",
		"format_version": 99,
		"created_at": 100,
		"modified_at": 100,
		"board_size": 8,
		"pieces": [],
	})
	var future_res: Dictionary = ProjectSerializer.deserialize_project(future_json)
	_check(not bool(future_res.get("success", true)), "Unsupported format version unexpectedly accepted")
	_check(str(future_res.get("reason", "")) == "unsupported_version", "Expected unsupported_version reason")

	# 4. Unknown piece ID rejected.
	var bad_piece_json := JSON.stringify({
		"project_id": "bad_piece_proj",
		"project_name": "Bad Piece",
		"format_version": ProjectData.CURRENT_FORMAT_VERSION,
		"created_at": 100,
		"modified_at": 100,
		"board_size": 8,
		"pieces": [{
			"piece_id": "spaceship",
			"grid_pos": {"x": 0, "y": 0, "z": 0},
			"rotation_steps": 0,
			"color": {"r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0},
		}],
	})
	var bad_piece_res: Dictionary = ProjectSerializer.deserialize_project(bad_piece_json)
	_check(not bool(bad_piece_res.get("success", true)), "Unknown piece ID unexpectedly accepted")
	_check(str(bad_piece_res.get("reason", "")) == "unknown_piece", "Expected unknown_piece reason")

	# 5. Floating/unsupported spatial state rejected by serializer.
	var floating_json := JSON.stringify({
		"project_id": "floating_proj",
		"project_name": "Floating Cube",
		"format_version": ProjectData.CURRENT_FORMAT_VERSION,
		"created_at": 100,
		"modified_at": 100,
		"board_size": 8,
		"pieces": [{
			"piece_id": "cube",
			"grid_pos": {"x": 2, "y": 4, "z": 2},
			"rotation_steps": 0,
			"color": {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0},
		}],
	})
	var floating_res: Dictionary = ProjectSerializer.deserialize_project(floating_json)
	_check(not bool(floating_res.get("success", true)), "Floating piece save unexpectedly accepted")
	_check(str(floating_res.get("reason", "")) == "invalid_construction_state", "Expected invalid_construction_state reason")

	# 6. Trying to save invalid project does not overwrite an existing valid project on disk.
	var valid_before: Dictionary = repo.load_project(active_before)
	_check(bool(valid_before.get("success", false)), "Active project missing before invalid save test")
	var invalid_overwrite := ProjectData.new(
		active_before,
		"Overwrite Attempt",
		[{"piece_id": "unknown_block", "grid_pos": Vector3i.ZERO, "rotation_steps": 0, "color": Color.RED}],
		100,
		200
	)
	var bad_save_res: Dictionary = repo.save_project(invalid_overwrite)
	_check(not bool(bad_save_res.get("success", true)), "Invalid project save unexpectedly succeeded")
	var valid_after: Dictionary = repo.load_project(active_before)
	_check(
		bool(valid_after.get("success", false))
		and valid_after["project"].project_name == valid_before["project"].project_name
		and valid_after["project"].get_piece_count() == valid_before["project"].get_piece_count(),
		"Existing valid project on disk was corrupted by rejected save"
	)

	# Active workspace state remains completely preserved after failed loads.
	_check(manager.get_piece_count() == pieces_before, "Failed open altered active construction state")
	_check(save_manager.get_current_project_id() == active_before, "Failed open changed active project ID")

	_completed_stages += 1


func _clean_test_storage(dir_res: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(dir_res)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	var dir := DirAccess.open(abs_dir)
	if dir != null:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while not fname.is_empty():
			if not dir.current_is_dir():
				DirAccess.remove_absolute(abs_dir.path_join(fname))
			fname = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(abs_dir)


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
		print("PHASE4_TESTS_PASSED")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		print("PHASE4_TESTS_FAILED: %d" % _failures.size())
		quit(1)
