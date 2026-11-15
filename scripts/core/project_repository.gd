class_name ProjectRepository
extends RefCounted
## Local offline file persistence for construction projects using atomic temp-and-backup writes.

const ProjectData = preload("res://scripts/core/project_data.gd")
const ProjectSerializer = preload("res://scripts/core/project_serializer.gd")

const DEFAULT_STORAGE_DIR := "user://projects"
const META_FILE_NAME := "meta.json"

var _storage_dir: String = DEFAULT_STORAGE_DIR
var _id_counter: int = 0


func _init(p_storage_dir: String = DEFAULT_STORAGE_DIR) -> void:
	set_storage_dir(p_storage_dir)


func set_storage_dir(p_storage_dir: String) -> void:
	var trimmed: String = p_storage_dir.strip_edges()
	_storage_dir = DEFAULT_STORAGE_DIR if trimmed.is_empty() else trimmed.trim_suffix("/")


func get_storage_dir() -> String:
	return _storage_dir


func ensure_storage_dir() -> bool:
	var abs_dir: String = ProjectSettings.globalize_path(_storage_dir)
	var err: Error = DirAccess.make_dir_recursive_absolute(abs_dir)
	return err == OK or DirAccess.dir_exists_absolute(abs_dir)


func get_project_file_path(project_id: String) -> String:
	return _storage_dir.path_join(project_id + ".json")


func project_exists(project_id: String) -> bool:
	if not _is_valid_project_id(project_id):
		return false
	return FileAccess.file_exists(get_project_file_path(project_id))


func generate_unique_project_id() -> String:
	var now_sec: int = int(Time.get_unix_time_from_system())
	for attempt in range(1000):
		_id_counter += 1
		var candidate: String = "proj_%d_%04d" % [now_sec, _id_counter]
		if not project_exists(candidate):
			return candidate
	return "proj_%d_%d" % [now_sec, Time.get_ticks_usec()]


func save_project(project: ProjectData) -> Dictionary:
	if project == null:
		return {"success": false, "reason": "null_project", "error_message": "Invalid project data."}
	if not _is_valid_project_id(project.project_id):
		return {"success": false, "reason": "invalid_project_id", "error_message": "Invalid project ID."}
	if not ensure_storage_dir():
		return {"success": false, "reason": "dir_error", "error_message": "Could not access project storage folder."}

	var validation: Dictionary = ProjectSerializer.from_dictionary(ProjectSerializer.to_dictionary(project))
	if not bool(validation.get("success", false)):
		return {
			"success": false,
			"reason": str(validation.get("reason", "invalid_project")),
			"error_message": str(validation.get("error_message", "Invalid project data.")),
		}

	var json_text: String = ProjectSerializer.serialize_project(project)
	var final_path: String = get_project_file_path(project.project_id)
	var write_res: Dictionary = _write_text_atomic(final_path, json_text, func(read_back: String) -> bool:
		var parsed: Dictionary = ProjectSerializer.deserialize_project(read_back)
		if not bool(parsed.get("success", false)):
			return false
		var parsed_project := parsed.get("project", null) as ProjectData
		return parsed_project != null and parsed_project.project_id == project.project_id
	)
	if not bool(write_res.get("success", false)):
		return write_res

	return {
		"success": true,
		"reason": "ok",
		"path": final_path,
	}


func load_project(project_id: String) -> Dictionary:
	if not _is_valid_project_id(project_id):
		return {
			"success": false,
			"reason": "invalid_project_id",
			"error_message": "Could not open project: invalid project ID.",
			"project": null,
		}

	var file_path: String = get_project_file_path(project_id)
	if not FileAccess.file_exists(file_path):
		return {
			"success": false,
			"reason": "file_not_found",
			"error_message": "Could not open project: file not found.",
			"project": null,
		}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {
			"success": false,
			"reason": "read_error",
			"error_message": "Could not open project: failed to read file.",
			"project": null,
		}
	var content: String = file.get_as_text()
	file.close()

	return ProjectSerializer.deserialize_project(content)


func delete_project(project_id: String) -> Dictionary:
	if not _is_valid_project_id(project_id):
		return {"success": false, "reason": "invalid_project_id", "error_message": "Invalid project ID."}

	var final_path: String = get_project_file_path(project_id)
	var final_abs: String = ProjectSettings.globalize_path(final_path)
	var tmp_abs: String = ProjectSettings.globalize_path(final_path + ".tmp")
	var bak_abs: String = ProjectSettings.globalize_path(final_path + ".bak")

	var existed: bool = FileAccess.file_exists(final_abs)
	if FileAccess.file_exists(tmp_abs):
		DirAccess.remove_absolute(tmp_abs)
	if FileAccess.file_exists(bak_abs):
		DirAccess.remove_absolute(bak_abs)

	if not existed:
		return {"success": false, "reason": "file_not_found", "error_message": "Project file not found."}

	var err: Error = DirAccess.remove_absolute(final_abs)
	if err != OK:
		return {"success": false, "reason": "delete_failed", "error_message": "Could not delete project file."}
	return {"success": true, "reason": "ok"}


func list_projects() -> Array[ProjectData]:
	var results: Array[ProjectData] = []
	if not ensure_storage_dir():
		return results

	var dir := DirAccess.open(_storage_dir)
	if dir == null:
		return results

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if (
			not dir.current_is_dir()
			and file_name != META_FILE_NAME
			and file_name.ends_with(".json")
		):
			var project_id: String = file_name.trim_suffix(".json")
			var load_res: Dictionary = load_project(project_id)
			if bool(load_res.get("success", false)):
				var loaded := load_res.get("project", null) as ProjectData
				if loaded != null:
					results.append(loaded)
		file_name = dir.get_next()
	dir.list_dir_end()

	results.sort_custom(func(a: ProjectData, b: ProjectData) -> bool:
		if a.created_at != b.created_at:
			return a.created_at < b.created_at
		return a.project_id < b.project_id
	)
	return results


func allocate_next_construction_number() -> int:
	ensure_storage_dir()
	var last_number: int = _read_meta_last_number()
	var projects: Array[ProjectData] = list_projects()

	var max_used: int = 0
	var existing_names: Dictionary = {}
	for p: ProjectData in projects:
		var trimmed: String = p.project_name.strip_edges()
		existing_names[trimmed] = true
		var parsed_num: int = _extract_construction_number(trimmed)
		if parsed_num > max_used:
			max_used = parsed_num

	var next_num: int = maxi(last_number + 1, max_used + 1)
	while existing_names.has("Construction %d" % next_num):
		next_num += 1

	_write_meta_last_number(next_num)
	return next_num


func _read_meta_last_number() -> int:
	var meta_path: String = _storage_dir.path_join(META_FILE_NAME)
	if not FileAccess.file_exists(meta_path):
		return 0
	var file := FileAccess.open(meta_path, FileAccess.READ)
	if file == null:
		return 0
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return 0
	var data := json.data as Dictionary
	return maxi(0, int(data.get("last_number", 0)))


func _write_meta_last_number(last_number: int) -> void:
	var meta_path: String = _storage_dir.path_join(META_FILE_NAME)
	var json_text: String = JSON.stringify({"last_number": last_number}, "\t")
	_write_text_atomic(meta_path, json_text, func(read_back: String) -> bool:
		var json := JSON.new()
		return json.parse(read_back) == OK and json.data is Dictionary
	)


func _write_text_atomic(final_path: String, text: String, verifier: Callable) -> Dictionary:
	var tmp_path: String = final_path + ".tmp"
	var bak_path: String = final_path + ".bak"
	var final_abs: String = ProjectSettings.globalize_path(final_path)
	var tmp_abs: String = ProjectSettings.globalize_path(tmp_path)
	var bak_abs: String = ProjectSettings.globalize_path(bak_path)

	var tmp_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		return {
			"success": false,
			"reason": "write_error",
			"error_message": "Could not open temporary file for writing.",
		}
	tmp_file.store_string(text)
	tmp_file.flush()
	tmp_file.close()

	var verify_file := FileAccess.open(tmp_path, FileAccess.READ)
	if verify_file == null:
		DirAccess.remove_absolute(tmp_abs)
		return {
			"success": false,
			"reason": "verify_error",
			"error_message": "Could not verify saved temporary file.",
		}
	var read_back: String = verify_file.get_as_text()
	verify_file.close()

	if not bool(verifier.call(read_back)):
		DirAccess.remove_absolute(tmp_abs)
		return {
			"success": false,
			"reason": "verify_failed",
			"error_message": "Saved data failed integrity verification.",
		}

	var had_existing: bool = FileAccess.file_exists(final_abs)
	if had_existing:
		if FileAccess.file_exists(bak_abs):
			DirAccess.remove_absolute(bak_abs)
		var bak_err: Error = DirAccess.rename_absolute(final_abs, bak_abs)
		if bak_err != OK:
			DirAccess.remove_absolute(tmp_abs)
			return {
				"success": false,
				"reason": "backup_failed",
				"error_message": "Could not create backup before saving.",
			}

	var rename_err: Error = DirAccess.rename_absolute(tmp_abs, final_abs)
	if rename_err != OK:
		if had_existing and FileAccess.file_exists(bak_abs):
			DirAccess.rename_absolute(bak_abs, final_abs)
		if FileAccess.file_exists(tmp_abs):
			DirAccess.remove_absolute(tmp_abs)
		return {
			"success": false,
			"reason": "rename_failed",
			"error_message": "Could not finalize saved file.",
		}

	if FileAccess.file_exists(bak_abs):
		DirAccess.remove_absolute(bak_abs)

	return {"success": true, "reason": "ok"}


static func _is_valid_project_id(project_id: String) -> bool:
	var trimmed: String = project_id.strip_edges()
	if trimmed.is_empty():
		return false
	if trimmed.contains("/") or trimmed.contains("\\") or trimmed.contains(".."):
		return false
	if trimmed == "meta":
		return false
	return true


static func _extract_construction_number(project_name: String) -> int:
	if not project_name.begins_with("Construction "):
		return 0
	var suffix: String = project_name.trim_prefix("Construction ").strip_edges()
	if suffix.is_valid_int():
		return maxi(0, int(suffix))
	return 0
