class_name SaveManager
extends Node
## Coordinates project lifecycle (create, open, rename, delete, list) and automatic local saves.

const ProjectData = preload("res://scripts/core/project_data.gd")
const ProjectRepository = preload("res://scripts/core/project_repository.gd")
const ConstructionManager = preload("res://scripts/core/construction_manager.gd")
const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")

signal project_created(project: ProjectData)
signal project_loaded(project: ProjectData)
signal project_saved(project_id: String)
signal project_renamed(project_id: String, new_name: String)
signal project_deleted(project_id: String)
signal project_error(error_message: String, reason: String)
signal projects_list_changed()

var _repository := ProjectRepository.new()
var _bound_manager: ConstructionManager = null
var _manager_connections: Array[Dictionary] = []
var _current_project: ProjectData = null
var _autosave_enabled: bool = true
var _is_restoring: bool = false
var _last_error: Dictionary = {}


func _exit_tree() -> void:
	_disconnect_manager()


func setup(storage_dir: String = ProjectRepository.DEFAULT_STORAGE_DIR) -> void:
	_repository.set_storage_dir(storage_dir)
	_repository.ensure_storage_dir()


func set_storage_dir(storage_dir: String) -> void:
	_repository.set_storage_dir(storage_dir)
	_repository.ensure_storage_dir()


func get_storage_dir() -> String:
	return _repository.get_storage_dir()


func get_repository() -> ProjectRepository:
	return _repository


func bind_construction_manager(manager: ConstructionManager) -> void:
	_disconnect_manager()
	if manager == null or not is_instance_valid(manager):
		return

	_bound_manager = manager
	var bindings: Array[Dictionary] = [
		{"signal": manager.piece_placed, "callable": _on_manager_piece_changed},
		{"signal": manager.piece_rotated, "callable": _on_manager_piece_changed},
		{"signal": manager.piece_removed, "callable": _on_manager_piece_changed},
		{"signal": manager.construction_cleared, "callable": _on_manager_cleared},
	]
	for entry: Dictionary in bindings:
		var sig: Signal = entry["signal"]
		var cb: Callable = entry["callable"]
		sig.connect(cb)
		_manager_connections.append(entry)


func set_autosave_enabled(enabled: bool) -> void:
	_autosave_enabled = enabled


func is_autosave_enabled() -> bool:
	return _autosave_enabled


func get_current_project() -> ProjectData:
	return _current_project


func get_current_project_id() -> String:
	return _current_project.project_id if _current_project != null else ""


func get_last_error() -> Dictionary:
	return _last_error.duplicate()


func list_projects() -> Array[ProjectData]:
	return _repository.list_projects()


func create_project(
	custom_name: String = "",
	p_grid_size: int = -1,
	p_theme_id: String = ""
) -> Dictionary:
	_repository.ensure_storage_dir()
	var trimmed_name: String = custom_name.strip_edges()
	var final_name: String = (
		trimmed_name
		if not trimmed_name.is_empty()
		else "Construction %d" % _repository.allocate_next_construction_number()
	)
	var project_id: String = _repository.generate_unique_project_id()
	var now_sec: int = int(Time.get_unix_time_from_system())
	var resolved_grid_size: int = (
		p_grid_size
		if p_grid_size > 0
		else (
			_bound_manager.grid_size
			if _bound_manager != null and is_instance_valid(_bound_manager)
			else ProjectData.DEFAULT_GRID_SIZE
		)
	)
	var resolved_theme_id: String = (
		p_theme_id
		if ProjectData.is_valid_theme_id(p_theme_id)
		else (
			_bound_manager.theme_id
			if _bound_manager != null and is_instance_valid(_bound_manager)
			else ProjectData.DEFAULT_THEME_ID
		)
	)

	var new_project := ProjectData.new(
		project_id,
		final_name,
		[],
		now_sec,
		now_sec,
		ProjectData.CURRENT_FORMAT_VERSION,
		resolved_grid_size,
		resolved_theme_id
	)
	var save_res: Dictionary = _repository.save_project(new_project)
	if not bool(save_res.get("success", false)):
		_record_error(save_res)
		return save_res

	if _bound_manager != null and is_instance_valid(_bound_manager):
		_is_restoring = true
		_bound_manager.configure_project_rules(resolved_grid_size, resolved_theme_id)
		_bound_manager.clear_all()
		_is_restoring = false

	_current_project = new_project
	_last_error.clear()
	project_created.emit(new_project)
	projects_list_changed.emit()

	return {
		"success": true,
		"reason": "ok",
		"error_message": "",
		"project": new_project,
	}


func open_project(project_id: String, manager: ConstructionManager = null) -> Dictionary:
	var load_res: Dictionary = _repository.load_project(project_id)
	if not bool(load_res.get("success", false)):
		_record_error(load_res)
		return load_res

	var loaded := load_res.get("project", null) as ProjectData
	if loaded == null:
		var err_res := {
			"success": false,
			"reason": "invalid_project",
			"error_message": "Could not open project: invalid project data.",
			"project": null,
		}
		_record_error(err_res)
		return err_res

	var target_manager: ConstructionManager = (
		manager
		if manager != null and is_instance_valid(manager)
		else _bound_manager
	)
	if target_manager != null and is_instance_valid(target_manager):
		_is_restoring = true
		target_manager.configure_project_rules(loaded.grid_size, loaded.theme_id)
		var scene_res: Dictionary = target_manager.load_serialized_pieces(loaded.pieces)
		_is_restoring = false
		if not bool(scene_res.get("success", false)):
			var reason: String = str(scene_res.get("reason", "load_failed"))
			var err_res := {
				"success": false,
				"reason": reason,
				"error_message": "Could not open project: invalid block placement (%s)." % reason,
				"project": null,
			}
			_record_error(err_res)
			return err_res

	_current_project = loaded
	_last_error.clear()
	project_loaded.emit(loaded)

	return {
		"success": true,
		"reason": "ok",
		"error_message": "",
		"project": loaded,
	}


func save_current_project(pieces_override: Variant = null) -> Dictionary:
	if _current_project == null:
		return {
			"success": false,
			"reason": "no_active_project",
			"error_message": "No active project selected to save.",
		}

	var pieces_source: Array = []
	if pieces_override is Array:
		pieces_source = pieces_override as Array
	elif _bound_manager != null and is_instance_valid(_bound_manager):
		pieces_source = _bound_manager.get_placed_pieces()

	_current_project.set_pieces_from_placed_data(pieces_source)
	var now_sec: int = int(Time.get_unix_time_from_system())
	_current_project.modified_at = maxi(now_sec, _current_project.created_at)
	if _bound_manager != null and is_instance_valid(_bound_manager):
		_current_project.grid_size = _bound_manager.grid_size
		_current_project.board_size = _bound_manager.grid_size
		_current_project.theme_id = _bound_manager.theme_id

	var save_res: Dictionary = _repository.save_project(_current_project)
	if not bool(save_res.get("success", false)):
		_record_error(save_res)
		return save_res

	_last_error.clear()
	project_saved.emit(_current_project.project_id)
	projects_list_changed.emit()

	return {
		"success": true,
		"reason": "ok",
		"error_message": "",
		"project_id": _current_project.project_id,
	}


func rename_project(project_id: String, new_name: String) -> Dictionary:
	var trimmed_name: String = new_name.strip_edges()
	if trimmed_name.is_empty():
		var empty_res := {
			"success": false,
			"reason": "empty_name",
			"error_message": "Project name cannot be empty.",
		}
		_record_error(empty_res)
		return empty_res

	var load_res: Dictionary = _repository.load_project(project_id)
	if not bool(load_res.get("success", false)):
		_record_error(load_res)
		return load_res

	var project := load_res.get("project", null) as ProjectData
	if project == null:
		var err_res := {
			"success": false,
			"reason": "invalid_project",
			"error_message": "Could not rename project.",
		}
		_record_error(err_res)
		return err_res

	project.project_name = trimmed_name
	project.modified_at = maxi(int(Time.get_unix_time_from_system()), project.modified_at)

	var save_res: Dictionary = _repository.save_project(project)
	if not bool(save_res.get("success", false)):
		_record_error(save_res)
		return save_res

	if _current_project != null and _current_project.project_id == project_id:
		_current_project.project_name = trimmed_name
		_current_project.modified_at = project.modified_at

	_last_error.clear()
	project_renamed.emit(project_id, trimmed_name)
	projects_list_changed.emit()

	return {
		"success": true,
		"reason": "ok",
		"error_message": "",
		"project": project,
	}


func delete_project(project_id: String) -> Dictionary:
	var del_res: Dictionary = _repository.delete_project(project_id)
	if not bool(del_res.get("success", false)):
		_record_error(del_res)
		return del_res

	if _current_project != null and _current_project.project_id == project_id:
		_current_project = null

	_last_error.clear()
	project_deleted.emit(project_id)
	projects_list_changed.emit()

	return {
		"success": true,
		"reason": "ok",
		"error_message": "",
		"project_id": project_id,
	}


func _on_manager_piece_changed(_arg: Variant) -> void:
	_trigger_autosave()


func _on_manager_cleared() -> void:
	_trigger_autosave()


func _trigger_autosave() -> void:
	if _autosave_enabled and not _is_restoring and _current_project != null:
		save_current_project()


func _record_error(err_res: Dictionary) -> void:
	var msg: String = str(err_res.get("error_message", "Project operation failed."))
	var reason: String = str(err_res.get("reason", "unknown_error"))
	_last_error = {"error_message": msg, "reason": reason}
	project_error.emit(msg, reason)


func _disconnect_manager() -> void:
	for entry: Dictionary in _manager_connections:
		var sig: Signal = entry["signal"]
		var cb: Callable = entry["callable"]
		if is_instance_valid(_bound_manager) and sig.is_connected(cb):
			sig.disconnect(cb)
	_manager_connections.clear()
	_bound_manager = null
