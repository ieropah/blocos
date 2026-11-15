class_name ProjectSerializer
extends RefCounted
## Versioned JSON serialization, deserialization, schema check, and spatial validation.

const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")
const PlacedPieceData = preload("res://scripts/core/placed_piece_data.gd")
const PlacementSystem = preload("res://scripts/core/placement_system.gd")
const ProjectData = preload("res://scripts/core/project_data.gd")


static func to_dictionary(project: ProjectData) -> Dictionary:
	var serialized_pieces: Array[Dictionary] = []
	for entry: Dictionary in project.pieces:
		var gp: Vector3i = entry.get("grid_pos", Vector3i.ZERO) as Vector3i
		var col: Color = entry.get("color", Color.WHITE) as Color
		serialized_pieces.append({
			"piece_id": str(entry.get("piece_id", "")),
			"grid_pos": {
				"x": gp.x,
				"y": gp.y,
				"z": gp.z,
			},
			"rotation_steps": posmod(int(entry.get("rotation_steps", 0)), 4),
			"color": {
				"r": col.r,
				"g": col.g,
				"b": col.b,
				"a": col.a,
			},
		})

	return {
		"project_id": project.project_id,
		"project_name": project.project_name,
		"format_version": project.format_version,
		"created_at": project.created_at,
		"modified_at": project.modified_at,
		"grid_size": project.grid_size,
		"board_size": project.grid_size,
		"theme_id": project.theme_id,
		"pieces": serialized_pieces,
	}


static func serialize_project(project: ProjectData) -> String:
	if project == null:
		return ""
	return JSON.stringify(to_dictionary(project), "\t")


static func deserialize_project(json_text: String) -> Dictionary:
	if json_text.strip_edges().is_empty():
		return _make_error("empty_data", "Could not open project: the save file is empty.")

	var json := JSON.new()
	var parse_err: Error = json.parse(json_text)
	if parse_err != OK:
		return _make_error("malformed_json", "Could not open project: the save file is damaged.")

	return from_dictionary(json.data)


static func from_dictionary(raw_data: Variant) -> Dictionary:
	if not (raw_data is Dictionary):
		return _make_error("invalid_structure", "Could not open project: invalid file structure.")

	var data := raw_data as Dictionary

	if not data.has("format_version"):
		return _make_error("missing_format_version", "Could not open project: missing format version.")
	var version_res: Dictionary = _parse_whole_int(data["format_version"])
	if not bool(version_res["valid"]):
		return _make_error("missing_format_version", "Could not open project: invalid format version.")
	var version_num: int = int(version_res["value"])
	if version_num != ProjectData.CURRENT_FORMAT_VERSION:
		return _make_error(
			"unsupported_version",
			"Could not open project: unsupported format version %d." % version_num
		)

	if not (data.get("project_id", null) is String) or not (data.get("project_name", null) is String):
		return _make_error("missing_metadata", "Could not open project: missing project metadata.")
	var project_id: String = str(data["project_id"]).strip_edges()
	var project_name: String = str(data["project_name"]).strip_edges()
	if project_id.is_empty() or project_name.is_empty():
		return _make_error("missing_metadata", "Could not open project: missing project ID or name.")

	if not data.has("created_at") or not data.has("modified_at"):
		return _make_error("invalid_timestamps", "Could not open project: missing project timestamps.")
	var created_res: Dictionary = _parse_whole_int(data["created_at"])
	var modified_res: Dictionary = _parse_whole_int(data["modified_at"])
	if not bool(created_res["valid"]) or not bool(modified_res["valid"]):
		return _make_error("invalid_timestamps", "Could not open project: invalid project timestamps.")
	var created_at: int = int(created_res["value"])
	var modified_at: int = int(modified_res["value"])
	if created_at < 0 or modified_at < 0:
		return _make_error("invalid_timestamps", "Could not open project: negative project timestamps.")

	var grid_size: int = ProjectData.LEGACY_GRID_SIZE
	if data.has("grid_size"):
		var grid_res: Dictionary = _parse_whole_int(data["grid_size"])
		if not bool(grid_res["valid"]) or int(grid_res["value"]) < 1:
			return _make_error("invalid_grid_size", "Could not open project: invalid grid size.")
		grid_size = int(grid_res["value"])
	elif data.has("board_size"):
		var board_res: Dictionary = _parse_whole_int(data["board_size"])
		if not bool(board_res["valid"]) or int(board_res["value"]) < 1:
			return _make_error("invalid_board_size", "Could not open project: invalid platform size.")
		grid_size = int(board_res["value"])

	var theme_id: String = ProjectData.DEFAULT_THEME_ID
	if data.has("theme_id"):
		if not (data["theme_id"] is String):
			return _make_error("invalid_theme_id", "Could not open project: invalid theme.")
		var parsed_theme: String = str(data["theme_id"]).strip_edges()
		if not ProjectData.is_valid_theme_id(parsed_theme):
			return _make_error("invalid_theme_id", "Could not open project: unsupported theme.")
		theme_id = parsed_theme

	var raw_pieces: Variant = data.get("pieces", null)
	if not (raw_pieces is Array):
		return _make_error("invalid_pieces_list", "Could not open project: invalid pieces list.")

	var normalized_pieces: Array[Dictionary] = []
	var temp_placed: Array[PlacedPieceData] = []
	var piece_idx: int = 1

	for entry_variant: Variant in (raw_pieces as Array):
		if not (entry_variant is Dictionary):
			return _make_error("invalid_piece_entry", "Could not open project: damaged piece entry.")
		var entry := entry_variant as Dictionary

		var raw_piece_id: Variant = entry.get("piece_id", null)
		if not (raw_piece_id is String) or not PieceCatalog.has_piece(str(raw_piece_id)):
			return _make_error("unknown_piece", "Could not open project: unknown block type.")
		var piece_id: String = str(raw_piece_id)

		var raw_grid: Variant = entry.get("grid_pos", null)
		if not (raw_grid is Dictionary):
			return _make_error("invalid_grid_pos", "Could not open project: invalid block position.")
		var grid_dict := raw_grid as Dictionary
		if not grid_dict.has("x") or not grid_dict.has("y") or not grid_dict.has("z"):
			return _make_error("invalid_grid_pos", "Could not open project: incomplete block coordinates.")
		var gx_res: Dictionary = _parse_whole_int(grid_dict["x"])
		var gy_res: Dictionary = _parse_whole_int(grid_dict["y"])
		var gz_res: Dictionary = _parse_whole_int(grid_dict["z"])
		if not bool(gx_res["valid"]) or not bool(gy_res["valid"]) or not bool(gz_res["valid"]):
			return _make_error("invalid_grid_pos", "Could not open project: non-integer grid coordinates.")
		var grid_pos := Vector3i(int(gx_res["value"]), int(gy_res["value"]), int(gz_res["value"]))

		if not entry.has("rotation_steps"):
			return _make_error("invalid_rotation", "Could not open project: missing block rotation.")
		var rot_res: Dictionary = _parse_whole_int(entry["rotation_steps"])
		if not bool(rot_res["valid"]):
			return _make_error("invalid_rotation", "Could not open project: invalid block rotation.")
		var rotation_steps: int = int(rot_res["value"])
		if rotation_steps < 0 or rotation_steps > 3:
			return _make_error("invalid_rotation", "Could not open project: block rotation out of range.")

		var raw_color: Variant = entry.get("color", null)
		if not (raw_color is Dictionary):
			return _make_error("invalid_color", "Could not open project: missing block color.")
		var color_dict := raw_color as Dictionary
		var color_res: Dictionary = _parse_color_dict(color_dict)
		if not bool(color_res["valid"]):
			return _make_error("invalid_color", "Could not open project: invalid block color.")
		var piece_color: Color = color_res["color"] as Color

		normalized_pieces.append({
			"piece_id": piece_id,
			"grid_pos": grid_pos,
			"rotation_steps": rotation_steps,
			"color": piece_color,
		})
		temp_placed.append(PlacedPieceData.new(piece_idx, piece_id, grid_pos, rotation_steps, piece_color))
		piece_idx += 1

	var consistency: Dictionary = PlacementSystem.validate_state_consistency(temp_placed, grid_size)
	if not bool(consistency.get("is_valid", false)):
		return _make_error(
			"invalid_construction_state",
			"Could not open project: invalid block placement (%s)." % str(consistency.get("reason", "invalid"))
		)

	var project := ProjectData.new(
		project_id,
		project_name,
		normalized_pieces,
		created_at,
		modified_at,
		version_num,
		grid_size,
		theme_id
	)
	return {
		"success": true,
		"reason": "ok",
		"error_message": "",
		"project": project,
	}


static func _parse_whole_int(value: Variant) -> Dictionary:
	if value is int:
		return {"valid": true, "value": int(value)}
	if value is float:
		var f: float = float(value)
		if is_nan(f) or is_inf(f):
			return {"valid": false, "value": 0}
		if not is_equal_approx(f, round(f)):
			return {"valid": false, "value": 0}
		return {"valid": true, "value": int(round(f))}
	return {"valid": false, "value": 0}


static func _parse_color_dict(color_dict: Dictionary) -> Dictionary:
	if not color_dict.has("r") or not color_dict.has("g") or not color_dict.has("b"):
		return {"valid": false, "color": Color.WHITE}
	var channels: Array[String] = ["r", "g", "b"]
	var parsed: Dictionary = {}
	for key: String in channels:
		var v: Variant = color_dict[key]
		if not (v is int or v is float):
			return {"valid": false, "color": Color.WHITE}
		var f: float = float(v)
		if is_nan(f) or is_inf(f) or f < -0.001 or f > 1.001:
			return {"valid": false, "color": Color.WHITE}
		parsed[key] = clampf(f, 0.0, 1.0)

	var alpha: float = 1.0
	if color_dict.has("a"):
		var va: Variant = color_dict["a"]
		if not (va is int or va is float):
			return {"valid": false, "color": Color.WHITE}
		var fa: float = float(va)
		if is_nan(fa) or is_inf(fa) or fa < -0.001 or fa > 1.001:
			return {"valid": false, "color": Color.WHITE}
		alpha = clampf(fa, 0.0, 1.0)

	return {
		"valid": true,
		"color": Color(float(parsed["r"]), float(parsed["g"]), float(parsed["b"]), alpha),
	}


static func _make_error(reason: String, message: String) -> Dictionary:
	return {
		"success": false,
		"reason": reason,
		"error_message": message,
		"project": null,
	}
