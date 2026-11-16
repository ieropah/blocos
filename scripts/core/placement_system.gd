class_name PlacementSystem
extends RefCounted
## Pure deterministic rules for grid bounds, sub-cell collision, stacking support, and cursor snapping.

const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")
const PlacedPieceData = preload("res://scripts/core/placed_piece_data.gd")

const _HORIZONTAL_NEIGHBOR_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]

var grid_size: int = 8
var y_step: float = 0.25


func set_grid_size(new_size: int) -> void:
	grid_size = maxi(new_size, 1)


func set_theme_rules(theme_id: String) -> void:
	if theme_id == "voxel":
		y_step = 1.0
	elif theme_id == "solid":
		y_step = 0.5
	else:
		y_step = 0.25


func world_to_grid(world_pos: Vector3, p_grid_size: int = -1) -> Vector3i:
	var active_size: int = maxi(p_grid_size, 1) if p_grid_size > 0 else grid_size
	var half_board: float = float(active_size) * 0.5
	return Vector3i(
		floori((world_pos.x + half_board) / PieceCatalog.GRID_UNIT_SIZE),
		maxi(0, roundi(world_pos.y / PieceCatalog.HEIGHT_SUB_UNIT)),
		floori((world_pos.z + half_board) / PieceCatalog.GRID_UNIT_SIZE)
	)


func grid_to_world(grid_pos: Vector3i, p_grid_size: int = -1) -> Vector3:
	var active_size: int = maxi(p_grid_size, 1) if p_grid_size > 0 else grid_size
	return PieceCatalog.grid_to_world_origin(grid_pos, active_size)


static func validate_placement(
	placed_pieces: Array,
	piece_id: String,
	grid_pos: Vector3i,
	rotation_steps: int = 0,
	board_size: int = 8,
	ignore_piece_id: int = -1
) -> Dictionary:
	var rot: int = posmod(rotation_steps, 4)
	if not PieceCatalog.has_piece(piece_id):
		return _make_validation_result(false, "unknown_piece", grid_pos, rot)
	if _is_out_of_bounds(piece_id, grid_pos, rot, board_size):
		return _make_validation_result(false, "out_of_bounds", grid_pos, rot)

	var occupied_map: Dictionary = _build_occupied_map(placed_pieces, ignore_piece_id)
	var flat_top_map: Dictionary = _build_flat_top_map(placed_pieces, ignore_piece_id) if grid_pos.y > 0 else {}
	return _validate_with_maps(piece_id, grid_pos, rot, board_size, occupied_map, flat_top_map)


static func validate_piece_move(
	placed_pieces: Array,
	target_instance_id: int,
	new_grid_pos: Vector3i,
	new_rotation_steps: int,
	board_size: int = 8
) -> Dictionary:
	var target: PlacedPieceData = null
	var other_pieces: Array = []
	for piece_variant in placed_pieces:
		var piece: PlacedPieceData = piece_variant
		if piece != null and piece.instance_id == target_instance_id and target == null:
			target = piece
		else:
			other_pieces.append(piece_variant)

	var rot: int = posmod(new_rotation_steps, 4)
	if target == null:
		return _make_validation_result(false, "not_found", Vector3i.ZERO, rot)

	var base_check: Dictionary = validate_placement(
		placed_pieces,
		target.piece_id,
		new_grid_pos,
		rot,
		board_size,
		target_instance_id
	)
	if not base_check["is_valid"]:
		return base_check

	var moved_target := PlacedPieceData.new(
		target.instance_id,
		target.piece_id,
		new_grid_pos,
		base_check["rotation_steps"] as int,
		target.color
	)
	var simulated: Array = other_pieces.duplicate()
	simulated.append(moved_target)

	var consistency: Dictionary = validate_state_consistency(simulated, board_size)
	if not consistency["is_valid"]:
		return _make_validation_result(
			false,
			"breaks_support",
			new_grid_pos,
			base_check["rotation_steps"] as int
		)

	return base_check


static func validate_piece_rotation(
	placed_pieces: Array,
	target_instance_id: int,
	new_rotation_steps: int,
	board_size: int = 8
) -> Dictionary:
	var target: PlacedPieceData = null
	var other_pieces: Array = []
	for piece_variant in placed_pieces:
		var piece: PlacedPieceData = piece_variant
		if piece != null and piece.instance_id == target_instance_id and target == null:
			target = piece
		else:
			other_pieces.append(piece_variant)

	var rot: int = posmod(new_rotation_steps, 4)
	if target == null:
		return _make_validation_result(false, "not_found", Vector3i.ZERO, rot)

	var base_check: Dictionary = validate_placement(
		other_pieces,
		target.piece_id,
		target.grid_pos,
		rot,
		board_size
	)
	if not base_check["is_valid"]:
		return base_check

	var rotated_target := PlacedPieceData.new(
		target.instance_id,
		target.piece_id,
		target.grid_pos,
		base_check["rotation_steps"] as int,
		target.color
	)
	var simulated: Array = other_pieces.duplicate()
	simulated.append(rotated_target)

	var consistency: Dictionary = validate_state_consistency(simulated, board_size)
	if not consistency["is_valid"]:
		return _make_validation_result(
			false,
			"breaks_support",
			target.grid_pos,
			base_check["rotation_steps"] as int
		)

	return base_check


static func validate_state_consistency(
	placed_pieces: Array,
	board_size: int = 8
) -> Dictionary:
	var occupied_map: Dictionary = {}
	var flat_top_owners: Dictionary = {}

	for i in range(placed_pieces.size()):
		var piece: PlacedPieceData = placed_pieces[i]
		if piece == null or not PieceCatalog.has_piece(piece.piece_id):
			return {"is_valid": false, "reason": "unknown_piece"}
		if _is_out_of_bounds(piece.piece_id, piece.grid_pos, piece.rotation_steps, board_size):
			return {"is_valid": false, "reason": "out_of_bounds"}

		for cell: Vector3i in piece.occupied_cells:
			if occupied_map.has(cell):
				return {"is_valid": false, "reason": "collision"}
			occupied_map[cell] = i

		for top_cell: Vector3i in piece.flat_top_cells:
			flat_top_owners[top_cell] = i

	for i in range(placed_pieces.size()):
		var piece: PlacedPieceData = placed_pieces[i]
		if piece.grid_pos.y == 0:
			continue
		var has_support: bool = false
		for fp: Vector2i in PieceCatalog.get_footprint_cells(
			piece.piece_id,
			piece.grid_pos,
			piece.rotation_steps
		):
			var support_cell := Vector3i(fp.x, piece.grid_pos.y, fp.y)
			if flat_top_owners.has(support_cell) and int(flat_top_owners[support_cell]) != i:
				has_support = true
				break
		if not has_support:
			for cell: Vector3i in piece.occupied_cells:
				for offset: Vector3i in _HORIZONTAL_NEIGHBOR_OFFSETS:
					var neighbor: Vector3i = cell + offset
					if occupied_map.has(neighbor) and int(occupied_map[neighbor]) != i:
						has_support = true
						break
				if has_support:
					break
		if not has_support:
			return {"is_valid": false, "reason": "unsupported"}

	return {"is_valid": true, "reason": "ok"}


static func find_snapped_placement(
	placed_pieces: Array,
	piece_id: String,
	world_pos: Vector3,
	rotation_steps: int = 0,
	board_size: int = 8,
	snap_world_distance: float = 0.75,
	ignore_piece_id: int = -1
) -> Dictionary:
	var rot: int = posmod(rotation_steps, 4)
	var sub_size: Vector3i = PieceCatalog.get_rotated_sub_cells_size(piece_id, rot)
	var half_board: float = float(board_size) * 0.5
	var raw_gx: int = roundi(world_pos.x + half_board - float(sub_size.x) * 0.5)
	var raw_gz: int = roundi(world_pos.z + half_board - float(sub_size.z) * 0.5)

	if not PieceCatalog.has_piece(piece_id):
		var unknown_result: Dictionary = _make_validation_result(
			false,
			"unknown_piece",
			Vector3i(raw_gx, 0, raw_gz),
			rot
		)
		unknown_result["snapped"] = false
		return unknown_result

	if absf(world_pos.x) > half_board + snap_world_distance or absf(world_pos.z) > half_board + snap_world_distance:
		var out_result: Dictionary = validate_placement(
			placed_pieces,
			piece_id,
			Vector3i(raw_gx, 0, raw_gz),
			rot,
			board_size,
			ignore_piece_id
		)
		out_result["snapped"] = false
		return out_result

	var occupied_map: Dictionary = _build_occupied_map(placed_pieces, ignore_piece_id)
	var flat_top_map: Dictionary = _build_flat_top_map(placed_pieces, ignore_piece_id)

	var nominal_heights: Array[int] = _collect_candidate_heights(
		placed_pieces,
		raw_gx,
		raw_gz,
		sub_size,
		world_pos.y,
		ignore_piece_id
	)
	for gy: int in nominal_heights:
		var candidate := Vector3i(raw_gx, gy, raw_gz)
		var check: Dictionary = _validate_with_maps(
			piece_id,
			candidate,
			rot,
			board_size,
			occupied_map,
			flat_top_map
		)
		if check["is_valid"]:
			check["snapped"] = true
			return check

	var def: Dictionary = PieceCatalog.get_piece_definition(piece_id)
	var piece_size: Vector3 = def["size"]
	var cursor_xz := Vector2(world_pos.x, world_pos.z)
	var neighbors: Array[Dictionary] = []

	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var cx: int = raw_gx + dx
			var cz: int = raw_gz + dz
			var center: Vector3 = PieceCatalog.grid_to_piece_center_base(
				Vector3i(cx, 0, cz),
				piece_size,
				rot,
				board_size
			)
			var dist: float = Vector2(center.x, center.z).distance_to(cursor_xz)
			if dist <= snap_world_distance:
				neighbors.append({"cx": cx, "cz": cz, "dist": dist})

	neighbors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = a["dist"]
		var db: float = b["dist"]
		if absf(da - db) > 1e-6:
			return da < db
		var ax: int = a["cx"]
		var bx: int = b["cx"]
		if ax != bx:
			return ax < bx
		return (a["cz"] as int) < (b["cz"] as int)
	)

	for nb: Dictionary in neighbors:
		var cx: int = nb["cx"]
		var cz: int = nb["cz"]
		if _is_out_of_bounds(piece_id, Vector3i(cx, 0, cz), rot, board_size):
			continue
		var heights: Array[int] = _collect_candidate_heights(
			placed_pieces,
			cx,
			cz,
			sub_size,
			world_pos.y,
			ignore_piece_id
		)
		for gy: int in heights:
			var candidate := Vector3i(cx, gy, cz)
			var check: Dictionary = _validate_with_maps(
				piece_id,
				candidate,
				rot,
				board_size,
				occupied_map,
				flat_top_map
			)
			if check["is_valid"]:
				check["snapped"] = true
				return check

	var fallback_gy: int = (
		nominal_heights[0]
		if not nominal_heights.is_empty()
		else maxi(0, roundi(world_pos.y / PieceCatalog.HEIGHT_SUB_UNIT))
	)
	var fallback: Dictionary = _validate_with_maps(
		piece_id,
		Vector3i(raw_gx, fallback_gy, raw_gz),
		rot,
		board_size,
		occupied_map,
		flat_top_map
	)
	fallback["snapped"] = false
	return fallback


static func snap_adjacent_to_hit_piece(
	placed_pieces: Array,
	hit_piece: PlacedPieceData,
	hit_normal: Vector3,
	candidate_piece_id: String,
	rotation_steps: int = 0,
	board_size: int = 8,
	ignore_piece_id: int = -1
) -> Dictionary:
	var rot: int = posmod(rotation_steps, 4)
	if hit_piece == null or not PieceCatalog.has_piece(candidate_piece_id):
		var err: Dictionary = _make_validation_result(false, "invalid_target", Vector3i.ZERO, rot)
		err["snapped"] = false
		return err

	var hit_size: Vector3i = PieceCatalog.get_rotated_sub_cells_size(hit_piece.piece_id, hit_piece.rotation_steps)
	var cand_size: Vector3i = PieceCatalog.get_rotated_sub_cells_size(candidate_piece_id, rot)
	var target_pos: Vector3i = hit_piece.grid_pos

	if hit_normal.y > 0.5:
		target_pos.y = hit_piece.grid_pos.y + hit_size.y
	elif absf(hit_normal.x) > 0.5 or absf(hit_normal.z) > 0.5:
		target_pos.y = hit_piece.grid_pos.y
		if absf(hit_normal.x) >= absf(hit_normal.z):
			target_pos.x = (
				hit_piece.grid_pos.x + hit_size.x
				if hit_normal.x > 0.0
				else hit_piece.grid_pos.x - cand_size.x
			)
		else:
			target_pos.z = (
				hit_piece.grid_pos.z + hit_size.z
				if hit_normal.z > 0.0
				else hit_piece.grid_pos.z - cand_size.z
			)
	else:
		var unsupported: Dictionary = _make_validation_result(false, "unsupported_face", target_pos, rot)
		unsupported["snapped"] = false
		return unsupported

	var res: Dictionary = validate_placement(
		placed_pieces,
		candidate_piece_id,
		target_pos,
		rot,
		board_size,
		ignore_piece_id
	)
	res["snapped"] = bool(res.get("is_valid", false))
	return res


static func _validate_with_maps(
	piece_id: String,
	grid_pos: Vector3i,
	rot: int,
	board_size: int,
	occupied_map: Dictionary,
	flat_top_map: Dictionary
) -> Dictionary:
	if not PieceCatalog.has_piece(piece_id):
		return _make_validation_result(false, "unknown_piece", grid_pos, rot)
	if _is_out_of_bounds(piece_id, grid_pos, rot, board_size):
		return _make_validation_result(false, "out_of_bounds", grid_pos, rot)

	for cell: Vector3i in PieceCatalog.get_occupied_sub_cells(piece_id, grid_pos, rot):
		if occupied_map.has(cell):
			return _make_validation_result(false, "collision", grid_pos, rot)

	if grid_pos.y == 0:
		return _make_validation_result(true, "ok", grid_pos, rot)

	for fp: Vector2i in PieceCatalog.get_footprint_cells(piece_id, grid_pos, rot):
		if flat_top_map.has(Vector3i(fp.x, grid_pos.y, fp.y)):
			return _make_validation_result(true, "ok", grid_pos, rot)

	if _has_lateral_support(piece_id, grid_pos, rot, occupied_map):
		return _make_validation_result(true, "ok", grid_pos, rot)

	return _make_validation_result(false, "unsupported", grid_pos, rot)


static func _has_lateral_support(
	piece_id: String,
	grid_pos: Vector3i,
	rot: int,
	occupied_map: Dictionary
) -> bool:
	for cell: Vector3i in PieceCatalog.get_occupied_sub_cells(piece_id, grid_pos, rot):
		for offset: Vector3i in _HORIZONTAL_NEIGHBOR_OFFSETS:
			if occupied_map.has(cell + offset):
				return true
	return false


static func _is_out_of_bounds(
	piece_id: String,
	grid_pos: Vector3i,
	rot: int,
	board_size: int
) -> bool:
	var sub_size: Vector3i = PieceCatalog.get_rotated_sub_cells_size(piece_id, rot)
	return (
		grid_pos.y < 0
		or grid_pos.x < 0
		or grid_pos.z < 0
		or grid_pos.x + sub_size.x > board_size
		or grid_pos.z + sub_size.z > board_size
	)


static func _build_occupied_map(placed_pieces: Array, ignore_piece_id: int = -1) -> Dictionary:
	var map: Dictionary = {}
	for piece_variant in placed_pieces:
		var piece: PlacedPieceData = piece_variant
		if piece == null or (ignore_piece_id >= 0 and piece.instance_id == ignore_piece_id):
			continue
		for cell: Vector3i in piece.occupied_cells:
			map[cell] = true
	return map


static func _build_flat_top_map(placed_pieces: Array, ignore_piece_id: int = -1) -> Dictionary:
	var map: Dictionary = {}
	for piece_variant in placed_pieces:
		var piece: PlacedPieceData = piece_variant
		if piece == null or (ignore_piece_id >= 0 and piece.instance_id == ignore_piece_id):
			continue
		for top_cell: Vector3i in piece.flat_top_cells:
			map[top_cell] = true
	return map


static func _collect_candidate_heights(
	placed_pieces: Array,
	cx: int,
	cz: int,
	sub_size: Vector3i,
	world_y: float,
	ignore_piece_id: int = -1
) -> Array[int]:
	var seen: Dictionary = {0: true}
	var max_x: int = cx + sub_size.x - 1
	var max_z: int = cz + sub_size.z - 1

	for piece_variant in placed_pieces:
		var piece: PlacedPieceData = piece_variant
		if piece == null or (ignore_piece_id >= 0 and piece.instance_id == ignore_piece_id):
			continue
		for top_cell: Vector3i in piece.flat_top_cells:
			if (
				top_cell.x >= cx
				and top_cell.x <= max_x
				and top_cell.z >= cz
				and top_cell.z <= max_z
			):
				seen[top_cell.y] = true
		if piece.grid_pos.y > 0:
			var p_size: Vector3i = PieceCatalog.get_rotated_sub_cells_size(piece.piece_id, piece.rotation_steps)
			var p_max_x: int = piece.grid_pos.x + p_size.x - 1
			var p_max_z: int = piece.grid_pos.z + p_size.z - 1
			var x_adjacent: bool = (p_max_x + 1 >= cx and piece.grid_pos.x - 1 <= max_x)
			var z_adjacent: bool = (p_max_z + 1 >= cz and piece.grid_pos.z - 1 <= max_z)
			if x_adjacent and z_adjacent:
				seen[piece.grid_pos.y] = true

	var heights: Array[int] = []
	for key: Variant in seen.keys():
		heights.append(key as int)

	heights.sort_custom(func(a: int, b: int) -> bool:
		var dist_a: float = absf(float(a) * PieceCatalog.HEIGHT_SUB_UNIT - world_y)
		var dist_b: float = absf(float(b) * PieceCatalog.HEIGHT_SUB_UNIT - world_y)
		if absf(dist_a - dist_b) > 1e-5:
			return dist_a < dist_b
		return a > b
	)
	return heights


static func _make_validation_result(
	is_valid: bool,
	reason: String,
	grid_pos: Vector3i,
	rotation_steps: int
) -> Dictionary:
	return {
		"is_valid": is_valid,
		"reason": reason,
		"grid_pos": grid_pos,
		"rotation_steps": rotation_steps,
	}
