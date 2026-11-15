class_name ConstructionManager
extends Node
## Authoritative state manager for placed toy blocks, validation, snapping, and placement events.

const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")
const PlacedPieceData = preload("res://scripts/core/placed_piece_data.gd")
const PlacementSystem = preload("res://scripts/core/placement_system.gd")
const UndoRedoManager = preload("res://scripts/core/undo_redo_manager.gd")

signal piece_placed(piece_data: PlacedPieceData)
signal piece_removed(instance_id: int)
signal piece_rotated(piece_data: PlacedPieceData)
signal piece_recolored(piece_id: int, new_color: Color)
signal piece_moved(piece_id: int, new_pos: Vector3i, new_rot: int)
signal construction_cleared()
signal history_changed(can_undo: bool, can_redo: bool)

@export var board_size: int = 8:
	set(value):
		var normalized: int = maxi(value, 1)
		if board_size != normalized:
			board_size = normalized
		if grid_size != normalized:
			grid_size = normalized
		if placement_system != null:
			placement_system.set_grid_size(normalized)

var grid_size: int = 8:
	set(value):
		var normalized: int = maxi(value, 1)
		if grid_size != normalized:
			grid_size = normalized
		if board_size != normalized:
			board_size = normalized
		if placement_system != null:
			placement_system.set_grid_size(normalized)

var theme_id: String = "plastic":
	set(value):
		theme_id = value if value in ["plastic", "voxel", "wood"] else "plastic"
		if placement_system != null:
			placement_system.set_theme_rules(theme_id)

var placement_system := PlacementSystem.new()
var _pieces: Array[PlacedPieceData] = []
var _next_instance_id: int = 1
var _history := UndoRedoManager.new()


func _init() -> void:
	placement_system.set_grid_size(grid_size)
	placement_system.set_theme_rules(theme_id)


func set_grid_size(new_size: int) -> void:
	grid_size = new_size


func set_theme_id(new_theme_id: String) -> void:
	theme_id = new_theme_id


func configure_project_rules(p_grid_size: int, p_theme_id: String) -> void:
	grid_size = p_grid_size
	theme_id = p_theme_id


func validate_placement(
	piece_id: String,
	grid_pos: Vector3i,
	rotation_steps: int = 0,
	ignore_piece_id: int = -1
) -> Dictionary:
	return PlacementSystem.validate_placement(
		_pieces,
		piece_id,
		grid_pos,
		rotation_steps,
		board_size,
		ignore_piece_id
	)


func find_snapped_placement(
	piece_id: String,
	world_pos: Vector3,
	rotation_steps: int = 0,
	ignore_piece_id: int = -1
) -> Dictionary:
	return PlacementSystem.find_snapped_placement(
		_pieces,
		piece_id,
		world_pos,
		rotation_steps,
		board_size,
		0.75,
		ignore_piece_id
	)


func place_piece(
	piece_id: String,
	grid_pos: Vector3i,
	rotation_steps: int = 0,
	custom_color: Variant = null,
	record_history: bool = true
) -> Dictionary:
	var validation: Dictionary = validate_placement(piece_id, grid_pos, rotation_steps)
	if not validation["is_valid"]:
		var failed: Dictionary = validation.duplicate()
		failed["success"] = false
		failed["piece"] = null
		failed["piece_data"] = null
		failed["validation"] = validation
		return failed

	var resolved_color: Color = (
		custom_color as Color
		if custom_color is Color
		else PieceCatalog.get_piece_color(piece_id)
	)
	var piece_data := PlacedPieceData.new(
		_next_instance_id,
		piece_id,
		grid_pos,
		validation["rotation_steps"] as int,
		resolved_color
	)
	_next_instance_id += 1
	_pieces.append(piece_data)

	if record_history:
		_history.record_operation({
			"type": "place",
			"instance_id": piece_data.instance_id,
			"piece_id": piece_data.piece_id,
			"grid_pos": piece_data.grid_pos,
			"rotation_steps": piece_data.rotation_steps,
			"color": piece_data.color,
		})

	piece_placed.emit(piece_data)
	if record_history:
		history_changed.emit(can_undo(), can_redo())

	var result: Dictionary = validation.duplicate()
	result["success"] = true
	result["piece"] = piece_data
	result["piece_data"] = piece_data
	result["instance_id"] = piece_data.instance_id
	result["validation"] = validation
	return result


func get_piece_by_id(instance_id: int) -> PlacedPieceData:
	var idx: int = _find_piece_index(instance_id)
	return _pieces[idx] if idx >= 0 else null


func rotate_piece(
	instance_id: int,
	step_delta: int = 1,
	record_history: bool = true
) -> Dictionary:
	var piece: PlacedPieceData = get_piece_by_id(instance_id)
	if piece == null:
		return {
			"success": false,
			"is_valid": false,
			"reason": "not_found",
			"piece": null,
		}
	var new_rot: int = posmod(piece.rotation_steps + step_delta, 4)
	return _set_piece_rotation(instance_id, new_rot, record_history)


func recolor_piece(
	piece_id: int,
	new_color: Color,
	record_undo: bool = true
) -> bool:
	var piece: PlacedPieceData = get_piece_by_id(piece_id)
	if piece == null or piece.color == new_color:
		return false

	var old_color: Color = piece.color
	piece.color = new_color

	if record_undo:
		_history.record_recolor(piece_id, old_color, new_color)

	piece_recolored.emit(piece_id, new_color)
	if record_undo:
		history_changed.emit(can_undo(), can_redo())
	return true


func move_piece(
	piece_id: int,
	new_grid_pos: Vector3i,
	new_rot: int,
	record_undo: bool = true
) -> bool:
	var idx: int = _find_piece_index(piece_id)
	if idx < 0:
		return false

	var piece: PlacedPieceData = _pieces[idx]
	var normalized_rot: int = posmod(new_rot, 4)
	if piece.grid_pos == new_grid_pos and piece.rotation_steps == normalized_rot:
		return false

	var validation: Dictionary = PlacementSystem.validate_piece_move(
		_pieces,
		piece_id,
		new_grid_pos,
		normalized_rot,
		board_size
	)
	if not bool(validation.get("is_valid", false)):
		return false

	var old_grid_pos: Vector3i = piece.grid_pos
	var old_rot: int = piece.rotation_steps
	_pieces[idx] = PlacedPieceData.new(
		piece_id,
		piece.piece_id,
		new_grid_pos,
		normalized_rot,
		piece.color
	)

	if record_undo:
		_history.record_move(piece_id, old_grid_pos, old_rot, new_grid_pos, normalized_rot)

	piece_moved.emit(piece_id, new_grid_pos, normalized_rot)
	if record_undo:
		history_changed.emit(can_undo(), can_redo())
	return true


func remove_piece(instance_id: int, record_history: bool = true) -> bool:
	var result: Dictionary = delete_piece(instance_id, record_history)
	return bool(result.get("success", false))


func delete_piece(instance_id: int, record_history: bool = true) -> Dictionary:
	var idx: int = _find_piece_index(instance_id)
	if idx < 0:
		return {
			"success": false,
			"reason": "not_found",
			"instance_id": instance_id,
			"piece": null,
		}

	var piece: PlacedPieceData = _pieces[idx]
	_pieces.remove_at(idx)

	if record_history:
		_history.record_operation({
			"type": "delete",
			"instance_id": piece.instance_id,
			"piece_id": piece.piece_id,
			"grid_pos": piece.grid_pos,
			"rotation_steps": piece.rotation_steps,
			"color": piece.color,
		})

	piece_removed.emit(instance_id)
	if record_history:
		history_changed.emit(can_undo(), can_redo())

	return {
		"success": true,
		"reason": "ok",
		"instance_id": instance_id,
		"piece": piece,
	}


func undo() -> Dictionary:
	return _execute_history_step(true)


func redo() -> Dictionary:
	return _execute_history_step(false)


func can_undo() -> bool:
	return _history.can_undo()


func can_redo() -> bool:
	return _history.can_redo()


func clear_history() -> void:
	_history.clear()
	history_changed.emit(false, false)


func get_placed_pieces() -> Array[PlacedPieceData]:
	return _pieces.duplicate()


func serialize_pieces() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for piece: PlacedPieceData in _pieces:
		if piece == null:
			continue
		serialized.append({
			"piece_id": piece.piece_id,
			"grid_pos": piece.grid_pos,
			"rotation_steps": posmod(piece.rotation_steps, 4),
			"color": piece.color,
		})
	return serialized


func load_serialized_pieces(serialized_pieces: Array) -> Dictionary:
	var candidate_pieces: Array[PlacedPieceData] = []
	var next_id: int = 1

	for entry_variant: Variant in serialized_pieces:
		var piece_data: PlacedPieceData = null
		if entry_variant is PlacedPieceData:
			var src := entry_variant as PlacedPieceData
			piece_data = PlacedPieceData.new(
				next_id,
				src.piece_id,
				src.grid_pos,
				posmod(src.rotation_steps, 4),
				src.color
			)
		elif entry_variant is Dictionary:
			var entry := entry_variant as Dictionary
			var piece_id: String = str(entry.get("piece_id", ""))
			var raw_grid: Variant = entry.get("grid_pos", Vector3i.ZERO)
			var grid_pos: Vector3i = Vector3i.ZERO
			if raw_grid is Vector3i:
				grid_pos = raw_grid as Vector3i
			elif raw_grid is Dictionary:
				var gd := raw_grid as Dictionary
				grid_pos = Vector3i(int(gd.get("x", 0)), int(gd.get("y", 0)), int(gd.get("z", 0)))
			else:
				return {"success": false, "reason": "invalid_grid_pos"}

			var rot_steps: int = posmod(int(entry.get("rotation_steps", 0)), 4)
			var raw_color: Variant = entry.get("color", Color.WHITE)
			var piece_color: Color = Color.WHITE
			if raw_color is Color:
				piece_color = raw_color as Color
			elif raw_color is Dictionary:
				var cd := raw_color as Dictionary
				piece_color = Color(
					clampf(float(cd.get("r", 1.0)), 0.0, 1.0),
					clampf(float(cd.get("g", 1.0)), 0.0, 1.0),
					clampf(float(cd.get("b", 1.0)), 0.0, 1.0),
					clampf(float(cd.get("a", 1.0)), 0.0, 1.0)
				)
			else:
				return {"success": false, "reason": "invalid_color"}

			piece_data = PlacedPieceData.new(next_id, piece_id, grid_pos, rot_steps, piece_color)
		else:
			return {"success": false, "reason": "invalid_piece_entry"}

		candidate_pieces.append(piece_data)
		next_id += 1

	var consistency: Dictionary = PlacementSystem.validate_state_consistency(candidate_pieces, board_size)
	if not bool(consistency.get("is_valid", false)):
		return {
			"success": false,
			"reason": str(consistency.get("reason", "invalid_construction_state")),
		}

	clear_all()
	_next_instance_id = 1
	for piece: PlacedPieceData in candidate_pieces:
		_pieces.append(piece)
		_next_instance_id = maxi(_next_instance_id, piece.instance_id + 1)
		piece_placed.emit(piece)
	clear_history()

	return {
		"success": true,
		"reason": "ok",
		"piece_count": _pieces.size(),
	}


func get_piece_count() -> int:
	return _pieces.size()


func clear_all() -> void:
	_pieces.clear()
	_history.clear()
	construction_cleared.emit()
	history_changed.emit(false, false)


func _restore_piece_with_id(
	instance_id: int,
	piece_id: String,
	grid_pos: Vector3i,
	rotation_steps: int,
	color: Color
) -> PlacedPieceData:
	if get_piece_by_id(instance_id) != null:
		return null
	var validation: Dictionary = validate_placement(piece_id, grid_pos, rotation_steps)
	if not validation["is_valid"]:
		return null

	var piece_data := PlacedPieceData.new(
		instance_id,
		piece_id,
		grid_pos,
		validation["rotation_steps"] as int,
		color
	)
	_next_instance_id = maxi(_next_instance_id, instance_id + 1)
	_pieces.append(piece_data)
	piece_placed.emit(piece_data)
	return piece_data


func _apply_rotation_without_history(instance_id: int, target_rotation_steps: int) -> bool:
	var result: Dictionary = _set_piece_rotation(
		instance_id,
		posmod(target_rotation_steps, 4),
		false
	)
	return bool(result.get("success", false))


func _set_piece_rotation(
	instance_id: int,
	target_rotation_steps: int,
	record_history: bool
) -> Dictionary:
	var idx: int = _find_piece_index(instance_id)
	if idx < 0:
		return {
			"success": false,
			"is_valid": false,
			"reason": "not_found",
			"piece": null,
		}

	var piece: PlacedPieceData = _pieces[idx]
	var new_rot: int = posmod(target_rotation_steps, 4)
	var validation: Dictionary = PlacementSystem.validate_piece_rotation(
		_pieces,
		instance_id,
		new_rot,
		board_size
	)
	if not validation["is_valid"]:
		return {
			"success": false,
			"is_valid": false,
			"reason": validation["reason"],
			"piece": piece,
			"validation": validation,
		}

	var old_rot: int = piece.rotation_steps
	var updated := PlacedPieceData.new(
		instance_id,
		piece.piece_id,
		piece.grid_pos,
		new_rot,
		piece.color
	)
	_pieces[idx] = updated

	if record_history:
		_history.record_operation({
			"type": "rotate",
			"instance_id": instance_id,
			"old_rotation_steps": old_rot,
			"new_rotation_steps": new_rot,
		})

	piece_rotated.emit(updated)
	if record_history:
		history_changed.emit(can_undo(), can_redo())

	return {
		"success": true,
		"is_valid": true,
		"reason": "ok",
		"piece": updated,
		"validation": validation,
	}


func _execute_history_step(is_undo: bool) -> Dictionary:
	var op: Dictionary = _history.pop_undo() if is_undo else _history.pop_redo()
	if op.is_empty():
		return {"success": false, "reason": "empty"}

	var op_type: String = str(op.get("type", ""))
	var instance_id: int = int(op.get("instance_id", op.get("piece_id", -1)))
	var ok: bool = false

	var should_remove: bool = (op_type == "place") if is_undo else (op_type == "delete")
	var should_restore: bool = (op_type == "delete") if is_undo else (op_type == "place")

	if should_remove:
		ok = remove_piece(instance_id, false)
	elif should_restore:
		var restored: PlacedPieceData = _restore_piece_with_id(
			instance_id,
			str(op.get("piece_id", "")),
			op.get("grid_pos", Vector3i.ZERO) as Vector3i,
			int(op.get("rotation_steps", 0)),
			op.get("color", Color.WHITE) as Color
		)
		ok = restored != null
	elif op_type == "rotate":
		var rot_key: String = "old_rotation_steps" if is_undo else "new_rotation_steps"
		ok = _apply_rotation_without_history(instance_id, int(op.get(rot_key, 0)))
	elif op_type == UndoRedoManager.ACTION_RECOLOR:
		var color_key: String = "old_color" if is_undo else "new_color"
		var target_color: Color = op.get(color_key, Color.WHITE) as Color
		ok = recolor_piece(instance_id, target_color, false)
	elif op_type == UndoRedoManager.ACTION_MOVE:
		var target_pos: Vector3i = op.get("old_grid_pos" if is_undo else "new_grid_pos", Vector3i.ZERO) as Vector3i
		var target_rot: int = int(op.get("old_rot" if is_undo else "new_rot", 0))
		ok = move_piece(instance_id, target_pos, target_rot, false)
	else:
		history_changed.emit(can_undo(), can_redo())
		return {
			"success": false,
			"reason": "unknown_operation",
			"operation": op_type,
			"instance_id": instance_id,
		}

	if not ok:
		history_changed.emit(can_undo(), can_redo())
		return {
			"success": false,
			"reason": "operation_failed",
			"operation": op_type,
			"instance_id": instance_id,
		}

	if is_undo:
		_history.push_redo(op)
	else:
		_history.push_undo(op)
	history_changed.emit(can_undo(), can_redo())

	return {
		"success": true,
		"operation": op_type,
		"instance_id": instance_id,
	}


func _find_piece_index(instance_id: int) -> int:
	for i in range(_pieces.size()):
		if _pieces[i].instance_id == instance_id:
			return i
	return -1
