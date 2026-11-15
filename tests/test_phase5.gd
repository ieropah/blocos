extends SceneTree
## Automated verification suite for Phase 5A (piece moving, recoloring, undo/redo, 3D updates, and persistence).

const WORKSPACE_SCENE_PATH := "res://scenes/main/construction_workspace.tscn"
const TEST_STORAGE_DIR := "user://test_phase5_projects"

var _failures: Array[String] = []


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
	var save_manager = workspace.get_save_manager()
	_check(manager != null and save_manager != null, "Workspace subsystems should initialize.")
	if manager == null or save_manager == null:
		_finish()
		return

	save_manager.set_storage_dir(TEST_STORAGE_DIR)
	var created: Dictionary = workspace.create_new_project("Phase 5 Test")
	_check(bool(created.get("success", false)), "Should create a temporary test project.")
	var project_id: String = save_manager.get_current_project_id()

	var initial_color := Color(0.9, 0.2, 0.2, 1.0)
	var painted_color := Color(0.15, 0.55, 0.95, 1.0)

	# Place a 2x1 long_block at (1, 0, 2) and an obstacle cube at (5, 0, 5)
	var placed_a: Dictionary = manager.place_piece("long_block", Vector3i(1, 0, 2), 0, initial_color)
	_check(bool(placed_a.get("success", false)), "Should place test long_block.")
	var piece_id: int = int(placed_a.get("instance_id", -1))

	var placed_b: Dictionary = manager.place_piece("cube", Vector3i(5, 0, 5), 0, Color(0.2, 0.8, 0.3, 1.0))
	_check(bool(placed_b.get("success", false)), "Should place obstacle cube.")
	var obstacle_id: int = int(placed_b.get("instance_id", -1))

	var visual_a: Dictionary = _find_visual_entry(workspace, piece_id)
	_check(not visual_a.is_empty(), "Placed piece should have a 3D visual entry.")
	var node_a := visual_a.get("node") as Node3D
	var mesh_inst_a := visual_a.get("mesh_instance") as MeshInstance3D
	var mesh_before: Mesh = mesh_inst_a.mesh

	var recolor_log: Array[Dictionary] = []
	manager.piece_recolored.connect(func(id: int, col: Color) -> void:
		recolor_log.append({"piece_id": id, "color": col})
	)

	var move_log: Array[Dictionary] = []
	manager.piece_moved.connect(func(id: int, pos: Vector3i, rot: int) -> void:
		move_log.append({"piece_id": id, "pos": pos, "rot": rot})
	)

	# 1. Move piece to valid overlapping position (verifies ignore_piece_id works) and new rotation
	var target_pos := Vector3i(2, 0, 2)
	var target_rot: int = 1
	var ok_move: bool = manager.move_piece(piece_id, target_pos, target_rot)
	_check(ok_move, "move_piece should succeed when moving to a valid overlapping position.")
	_check(manager.get_piece_by_id(piece_id).grid_pos == target_pos, "grid_pos should update on move.")
	_check(manager.get_piece_by_id(piece_id).rotation_steps == target_rot, "rotation_steps should update on move.")
	_check(move_log.size() == 1 and int(move_log[0]["piece_id"]) == piece_id and move_log[0]["pos"] == target_pos and int(move_log[0]["rot"]) == target_rot, "piece_moved signal should emit.")
	_check(is_equal_approx(node_a.rotation.y, float(target_rot) * PI * 0.5), "3D node rotation should update on move.")

	# 2. Invalid moves: out of bounds, collision, unsupported, same pos/rot no-op, breaks support
	_check(not manager.move_piece(piece_id, Vector3i(-1, 0, 0), 0), "move_piece should reject out_of_bounds.")
	_check(not manager.move_piece(piece_id, Vector3i(11, 0, 0), 0), "move_piece should reject out_of_bounds on 12x12 grid.")
	_check(not manager.move_piece(piece_id, Vector3i(5, 0, 5), 0), "move_piece should reject collision with obstacle.")
	_check(not manager.move_piece(piece_id, Vector3i(0, 4, 0), 0), "move_piece should reject unsupported floating position.")
	_check(not manager.move_piece(piece_id, target_pos, target_rot), "move_piece should return false for same pos and rotation.")
	_check(not manager.move_piece(999999, Vector3i(0, 0, 0), 0), "move_piece should return false for unknown piece_id.")

	# Stack a cube on obstacle_id (cube height is 4 sub-units), then verify moving obstacle_id away is rejected (breaks_support)
	var placed_top: Dictionary = manager.place_piece("cube", Vector3i(5, 4, 5), 0, Color.WHITE, false)
	_check(bool(placed_top.get("success", false)), "Should stack a cube on top of obstacle cube.")
	_check(not manager.move_piece(obstacle_id, Vector3i(6, 0, 6), 0), "move_piece should reject moving a piece that supports another piece.")
	manager.remove_piece(int(placed_top.get("instance_id", -1)), false)

	# 3. Recolor piece & same-color no-op
	var ok_paint: bool = manager.recolor_piece(piece_id, painted_color)
	_check(ok_paint, "recolor_piece should return true for a new color.")
	_check(manager.get_piece_by_id(piece_id).color.is_equal_approx(painted_color), "PlacedPieceData.color should update.")
	_check(recolor_log.size() == 1, "piece_recolored signal should emit.")
	_check(mesh_inst_a.mesh == mesh_before, "Mesh instance should not recreate its mesh on recolor.")
	_check((mesh_inst_a.material_override as StandardMaterial3D).albedo_color.is_equal_approx(painted_color), "3D material albedo_color should update.")

	_check(not manager.recolor_piece(piece_id, painted_color), "recolor_piece should return false when painting with the same color.")
	_check(not manager.recolor_piece(999999, initial_color), "recolor_piece should return false for unknown piece_id.")

	# 4. Undo / Redo for both RECOLOR and MOVE
	var undo_paint: Dictionary = manager.undo()
	_check(bool(undo_paint.get("success", false)), "Undo of recolor should succeed.")
	_check(manager.get_piece_by_id(piece_id).color.is_equal_approx(initial_color), "Undo should restore initial_color.")
	_check((mesh_inst_a.material_override as StandardMaterial3D).albedo_color.is_equal_approx(initial_color), "Undo should restore 3D material color.")

	var undo_move: Dictionary = manager.undo()
	_check(bool(undo_move.get("success", false)), "Undo of move should succeed.")
	_check(manager.get_piece_by_id(piece_id).grid_pos == Vector3i(1, 0, 2), "Undo should restore original grid_pos.")
	_check(manager.get_piece_by_id(piece_id).rotation_steps == 0, "Undo should restore original rotation_steps.")
	_check(is_equal_approx(node_a.rotation.y, 0.0), "Undo should restore 3D node rotation.")

	var redo_move: Dictionary = manager.redo()
	_check(bool(redo_move.get("success", false)), "Redo of move should succeed.")
	_check(manager.get_piece_by_id(piece_id).grid_pos == target_pos and manager.get_piece_by_id(piece_id).rotation_steps == target_rot, "Redo should reapply move.")
	_check(is_equal_approx(node_a.rotation.y, float(target_rot) * PI * 0.5), "Redo should reapply 3D node rotation.")

	var redo_paint: Dictionary = manager.redo()
	_check(bool(redo_paint.get("success", false)), "Redo of recolor should succeed.")
	_check(manager.get_piece_by_id(piece_id).color.is_equal_approx(painted_color), "Redo should reapply painted_color.")
	_check((mesh_inst_a.material_override as StandardMaterial3D).albedo_color.is_equal_approx(painted_color), "Redo should reapply 3D material color.")

	# 5. Persistence in serialization and autosaved project reload
	save_manager.set_autosave_enabled(false)
	workspace.clear_construction()
	save_manager.set_autosave_enabled(true)
	_check(manager.get_piece_count() == 0, "Workspace should be empty after clear_construction.")

	var reopened: Dictionary = workspace.open_project(project_id)
	_check(bool(reopened.get("success", false)), "Should reopen autosaved project.")
	var reloaded_pieces: Array = manager.get_placed_pieces()
	_check(reloaded_pieces.size() == 2, "Reloaded project should have 2 pieces.")
	if reloaded_pieces.size() == 2:
		var reloaded_a = reloaded_pieces[0]
		_check(reloaded_a.grid_pos == target_pos and reloaded_a.rotation_steps == target_rot, "Reloaded piece should preserve moved pos and rot.")
		_check(reloaded_a.color.is_equal_approx(painted_color), "Reloaded piece should preserve autosaved painted color.")

	workspace.queue_free()
	await process_frame
	_clean_test_storage(TEST_STORAGE_DIR)
	_finish()


func _find_visual_entry(workspace: Node, piece_id: int) -> Dictionary:
	for entry: Dictionary in workspace.get_placed_pieces():
		if int(entry.get("instance_id", -1)) == piece_id:
			return entry
	return {}


func _clean_test_storage(dir_path: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs_dir)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PHASE5_TESTS_PASSED")
		quit(0)
		return
	for msg: String in _failures:
		push_error("PHASE5_TEST_FAILURE: " + msg)
	quit(1)
