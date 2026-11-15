class_name UndoRedoManager
extends RefCounted
## Operation-based undo/redo history stacks for construction edits.

enum ActionType {
	PLACE,
	DELETE,
	ROTATE,
	RECOLOR,
	MOVE,
}

const ACTION_RECOLOR := "recolor"
const ACTION_MOVE := "move"

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []


func record_operation(op: Dictionary) -> void:
	_undo_stack.append(op.duplicate(true))
	_redo_stack.clear()


func record_recolor(piece_id: int, old_color: Color, new_color: Color) -> void:
	record_operation({
		"type": ACTION_RECOLOR,
		"piece_id": piece_id,
		"old_color": old_color,
		"new_color": new_color,
	})


func record_move(
	piece_id: int,
	old_grid_pos: Vector3i,
	old_rot: int,
	new_grid_pos: Vector3i,
	new_rot: int
) -> void:
	record_operation({
		"type": ACTION_MOVE,
		"piece_id": piece_id,
		"old_grid_pos": old_grid_pos,
		"old_rot": old_rot,
		"new_grid_pos": new_grid_pos,
		"new_rot": new_rot,
	})


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func pop_undo() -> Dictionary:
	if _undo_stack.is_empty():
		return {}
	return _undo_stack.pop_back() as Dictionary


func push_redo(op: Dictionary) -> void:
	_redo_stack.append(op.duplicate(true))


func pop_redo() -> Dictionary:
	if _redo_stack.is_empty():
		return {}
	return _redo_stack.pop_back() as Dictionary


func push_undo(op: Dictionary) -> void:
	_undo_stack.append(op.duplicate(true))


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()


func get_undo_count() -> int:
	return _undo_stack.size()


func get_redo_count() -> int:
	return _redo_stack.size()
