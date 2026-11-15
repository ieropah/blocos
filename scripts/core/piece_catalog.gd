class_name PieceCatalog
extends RefCounted
## Declarative catalog of modular toy block definitions and grid-to-world coordinate helpers.

const GRID_UNIT_SIZE: float = 1.0
const HEIGHT_SUB_UNIT: float = 0.25
const DEFAULT_BOARD_SIZE: int = 12

const _PIECE_ORDER: Array[String] = [
	"cube",
	"long_block",
	"square_plate",
	"ramp",
	"flat_tile_2x1",
	"cylinder",
	"cone",
	"roof_gable",
	"arch_bridge",
	"corner_block",
	"plastic_eye",
	"voxel_grass",
	"voxel_dirt",
	"voxel_stone",
	"voxel_wood",
	"voxel_leaves",
	"voxel_brick",
	"voxel_planks",
	"voxel_cobblestone",
	"voxel_sand",
	"voxel_glass",
	"voxel_water",
	"voxel_gold",
	"voxel_bookshelf",
	"voxel_tnt",
	"voxel_slab_stone",
	"voxel_slab_wood",
	"voxel_stairs_wood",
	"voxel_stairs_stone",
	"voxel_fence",
	"voxel_wool",
	"voxel_wool_slab",
	"voxel_pillar",
	"voxel_corner",
	"voxel_eye_cute",
	"voxel_eye_angry",
	"voxel_glasses",
	"voxel_mouth_smile",
	"voxel_snout",
	"voxel_ears",
	"voxel_belly",
	"voxel_hair_crown",
]

const _PIECE_DEFINITIONS: Dictionary = {
	"cube": {
		"id": "cube",
		"display_name": "Cube",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.90, 0.37, 0.32),
		"themes": ["plastic", "wood"],
	},
	"long_block": {
		"id": "long_block",
		"display_name": "Long Block",
		"size": Vector3(2.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(2, 4, 1),
		"shape": "box",
		"color": Color(0.24, 0.55, 0.83),
		"themes": ["plastic", "wood"],
	},
	"square_plate": {
		"id": "square_plate",
		"display_name": "Square Plate",
		"size": Vector3(2.0, 0.25, 2.0),
		"grid_sub_cells": Vector3i(2, 1, 2),
		"shape": "box",
		"color": Color(0.33, 0.73, 0.53),
		"themes": ["plastic", "wood"],
	},
	"ramp": {
		"id": "ramp",
		"display_name": "Ramp",
		"size": Vector3(2.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(2, 4, 1),
		"shape": "ramp",
		"color": Color(0.93, 0.53, 0.25),
		"themes": ["plastic", "wood"],
	},
	"flat_tile_2x1": {
		"id": "flat_tile_2x1",
		"display_name": "Flat Plate 2x1",
		"size": Vector3(2.0, 0.25, 1.0),
		"grid_sub_cells": Vector3i(2, 1, 1),
		"shape": "box",
		"color": Color(0.33, 0.73, 0.53),
		"themes": ["plastic"],
	},
	"cylinder": {
		"id": "cylinder",
		"display_name": "Cylinder",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.74, 0.23),
		"themes": ["plastic"],
	},
	"cone": {
		"id": "cone",
		"display_name": "Tower Cone",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "cone",
		"color": Color(0.90, 0.37, 0.32),
		"themes": ["plastic"],
	},
	"roof_gable": {
		"id": "roof_gable",
		"display_name": "Gable Roof 2x1",
		"size": Vector3(2.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(2, 4, 1),
		"shape": "gable",
		"color": Color(0.93, 0.53, 0.25),
		"themes": ["plastic"],
	},
	"arch_bridge": {
		"id": "arch_bridge",
		"display_name": "Arch Bridge 2x1",
		"size": Vector3(2.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(2, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.74, 0.23),
		"themes": ["plastic"],
	},
	"corner_block": {
		"id": "corner_block",
		"display_name": "Stepped L-Block",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "stairs",
		"color": Color(0.62, 0.44, 0.78),
		"themes": ["plastic"],
	},
	"plastic_eye": {
		"id": "plastic_eye",
		"display_name": "3D Eye Block",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["plastic"],
	},
	"voxel_grass": {
		"id": "voxel_grass",
		"display_name": "Grass Block",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#56A832"),
		"themes": ["voxel"],
	},
	"voxel_dirt": {
		"id": "voxel_dirt",
		"display_name": "Dirt Block",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#8B5A2B"),
		"themes": ["voxel"],
	},
	"voxel_stone": {
		"id": "voxel_stone",
		"display_name": "Stone Block",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#8C8F94"),
		"themes": ["voxel"],
	},
	"voxel_wood": {
		"id": "voxel_wood",
		"display_name": "Oak Log",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#9C6B30"),
		"themes": ["voxel"],
	},
	"voxel_leaves": {
		"id": "voxel_leaves",
		"display_name": "Tree Leaves",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#3A8228"),
		"themes": ["voxel"],
	},
	"voxel_brick": {
		"id": "voxel_brick",
		"display_name": "Clay Bricks",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#B84A39"),
		"themes": ["voxel"],
	},
	"voxel_planks": {
		"id": "voxel_planks",
		"display_name": "Oak Wood Planks",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#B8945F"),
		"themes": ["voxel"],
	},
	"voxel_cobblestone": {
		"id": "voxel_cobblestone",
		"display_name": "Cobblestone",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#7A7A7A"),
		"themes": ["voxel"],
	},
	"voxel_sand": {
		"id": "voxel_sand",
		"display_name": "Sand",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#E3D59E"),
		"themes": ["voxel"],
	},
	"voxel_glass": {
		"id": "voxel_glass",
		"display_name": "Glass Block",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#A8E6FF"),
		"themes": ["voxel"],
	},
	"voxel_water": {
		"id": "voxel_water",
		"display_name": "Water Block",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#2F7AD9"),
		"themes": ["voxel"],
	},
	"voxel_gold": {
		"id": "voxel_gold",
		"display_name": "Gold Block",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#F5C832"),
		"themes": ["voxel"],
	},
	"voxel_bookshelf": {
		"id": "voxel_bookshelf",
		"display_name": "Bookshelf",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#8C6239"),
		"themes": ["voxel"],
	},
	"voxel_tnt": {
		"id": "voxel_tnt",
		"display_name": "TNT Block",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color("#DB3B2B"),
		"themes": ["voxel"],
	},
	"voxel_slab_stone": {
		"id": "voxel_slab_stone",
		"display_name": "Stone Slab",
		"size": Vector3(1.0, 0.5, 1.0),
		"grid_sub_cells": Vector3i(1, 2, 1),
		"shape": "box",
		"color": Color("#8C8F94"),
		"themes": ["voxel"],
	},
	"voxel_slab_wood": {
		"id": "voxel_slab_wood",
		"display_name": "Wood Plank Slab",
		"size": Vector3(1.0, 0.5, 1.0),
		"grid_sub_cells": Vector3i(1, 2, 1),
		"shape": "box",
		"color": Color("#B8945F"),
		"themes": ["voxel"],
	},
	"voxel_stairs_wood": {
		"id": "voxel_stairs_wood",
		"display_name": "Wood Stairs",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "stairs",
		"color": Color("#B8945F"),
		"themes": ["voxel"],
	},
	"voxel_stairs_stone": {
		"id": "voxel_stairs_stone",
		"display_name": "Cobblestone Stairs",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "stairs",
		"color": Color("#7A7A7A"),
		"themes": ["voxel"],
	},
	"voxel_fence": {
		"id": "voxel_fence",
		"display_name": "Wood Fence Post",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "fence",
		"color": Color("#9C6B30"),
		"themes": ["voxel"],
	},
	"voxel_wool": {
		"id": "voxel_wool",
		"display_name": "Base Cube",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_wool_slab": {
		"id": "voxel_wool_slab",
		"display_name": "Horizontal Half-Slab",
		"size": Vector3(1.0, 0.5, 1.0),
		"grid_sub_cells": Vector3i(1, 2, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_pillar": {
		"id": "voxel_pillar",
		"display_name": "Thin Limb Pillar",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_corner": {
		"id": "voxel_corner",
		"display_name": "Stepped Corner",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_eye_cute": {
		"id": "voxel_eye_cute",
		"display_name": "Cute 3D Eyes",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_eye_angry": {
		"id": "voxel_eye_angry",
		"display_name": "Hero 3D Eyes",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_glasses": {
		"id": "voxel_glasses",
		"display_name": "3D Glasses",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_mouth_smile": {
		"id": "voxel_mouth_smile",
		"display_name": "Happy 3D Mouth",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_snout": {
		"id": "voxel_snout",
		"display_name": "3D Snout / Beak",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_ears": {
		"id": "voxel_ears",
		"display_name": "3D Ears / Horns",
		"size": Vector3(1.0, 0.5, 1.0),
		"grid_sub_cells": Vector3i(1, 2, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_belly": {
		"id": "voxel_belly",
		"display_name": "Belly / Outfit",
		"size": Vector3(1.0, 1.0, 1.0),
		"grid_sub_cells": Vector3i(1, 4, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
	"voxel_hair_crown": {
		"id": "voxel_hair_crown",
		"display_name": "Hair / Crown / Crest",
		"size": Vector3(1.0, 0.5, 1.0),
		"grid_sub_cells": Vector3i(1, 2, 1),
		"shape": "box",
		"color": Color(0.95, 0.95, 0.95),
		"themes": ["voxel"],
		"voxel_mode": "character",
	},
}

const _RAMP_LOW_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(0, 1),
	Vector2i(1, 0),
	Vector2i(0, 0),
]

const _RAMP_HIGH_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 0),
	Vector2i(0, 0),
	Vector2i(0, 1),
]

const _DEFAULT_COLOR_ID: String = "coral_red"

const _COLOR_PALETTE: Array[Dictionary] = [
	{"id": "coral_red", "name": "Coral Red", "color": Color(0.90, 0.37, 0.32)},
	{"id": "sunny_yellow", "name": "Sunny Yellow", "color": Color(0.95, 0.74, 0.23)},
	{"id": "cobalt_blue", "name": "Cobalt Blue", "color": Color(0.24, 0.55, 0.83)},
	{"id": "sage_green", "name": "Sage Green", "color": Color(0.33, 0.73, 0.53)},
	{"id": "terracotta", "name": "Terracotta", "color": Color(0.93, 0.53, 0.25)},
	{"id": "plum_purple", "name": "Plum Purple", "color": Color(0.62, 0.44, 0.78)},
]


static func get_color_palette() -> Array[Dictionary]:
	var palette: Array[Dictionary] = []
	for entry: Dictionary in _COLOR_PALETTE:
		palette.append(entry.duplicate(true))
	return palette


static func get_default_color_id() -> String:
	return _DEFAULT_COLOR_ID


static func has_color_id(color_id: String) -> bool:
	for entry: Dictionary in _COLOR_PALETTE:
		if str(entry.get("id", "")) == color_id:
			return true
	return false


static func get_color_by_id(color_id: String) -> Color:
	var fallback: Color = _COLOR_PALETTE[0]["color"] as Color
	for entry: Dictionary in _COLOR_PALETTE:
		var entry_id: String = str(entry.get("id", ""))
		if entry_id == _DEFAULT_COLOR_ID:
			fallback = entry["color"] as Color
		if entry_id == color_id:
			return entry["color"] as Color
	return fallback


static func get_all_piece_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_PIECE_ORDER)
	return ids


static func get_pieces_for_theme(theme_id: String, grid_size: int = 16) -> Array:
	var allowed: Array = []
	var target_voxel_mode: String = "character" if grid_size == 8 else "scenery"
	for piece_id: String in _PIECE_ORDER:
		if not is_piece_allowed_in_theme(piece_id, theme_id):
			continue
		if theme_id == "voxel":
			var def: Dictionary = _PIECE_DEFINITIONS[piece_id]
			if str(def.get("voxel_mode", "scenery")) != target_voxel_mode:
				continue
		allowed.append(piece_id)
	return allowed


static func get_pieces_for_context(theme_id: String, grid_size: int) -> Array:
	return get_pieces_for_theme(theme_id, grid_size)


static func get_default_piece_id(theme_id: String = "plastic", grid_size: int = 16) -> String:
	var pieces: Array = get_pieces_for_theme(theme_id, grid_size)
	if not pieces.is_empty():
		return str(pieces[0])
	return "cube"


static func is_piece_allowed_in_theme(piece_id: String, theme_id: String) -> bool:
	if not _PIECE_DEFINITIONS.has(piece_id):
		return false
	var def: Dictionary = _PIECE_DEFINITIONS[piece_id]
	var themes: Array = def.get("themes", ["plastic", "wood"])
	return theme_id in themes


static func has_piece(piece_id: String) -> bool:
	return _PIECE_DEFINITIONS.has(piece_id)


static func get_piece_definition(piece_id: String) -> Dictionary:
	if not _PIECE_DEFINITIONS.has(piece_id):
		return {}
	return (_PIECE_DEFINITIONS[piece_id] as Dictionary).duplicate(true)


static func grid_to_world_origin(grid_pos: Vector3i, board_size: int = DEFAULT_BOARD_SIZE) -> Vector3:
	var half_board: float = float(board_size) * 0.5
	return Vector3(
		(float(grid_pos.x) - half_board) * GRID_UNIT_SIZE,
		float(grid_pos.y) * HEIGHT_SUB_UNIT,
		(float(grid_pos.z) - half_board) * GRID_UNIT_SIZE
	)


static func grid_to_piece_center_base(
	grid_pos: Vector3i,
	piece_size: Vector3,
	rotation_steps: int = 0,
	board_size: int = DEFAULT_BOARD_SIZE
) -> Vector3:
	var swap_xz: bool = posmod(rotation_steps, 2) == 1
	var footprint_x: float = piece_size.z if swap_xz else piece_size.x
	var footprint_z: float = piece_size.x if swap_xz else piece_size.z
	return grid_to_world_origin(grid_pos, board_size) + Vector3(footprint_x * 0.5, 0.0, footprint_z * 0.5)


static func get_piece_color(piece_id: String) -> Color:
	if not _PIECE_DEFINITIONS.has(piece_id):
		return Color.WHITE
	return (_PIECE_DEFINITIONS[piece_id] as Dictionary).get("color", Color.WHITE)


static func get_rotated_sub_cells_size(piece_id: String, rotation_steps: int = 0) -> Vector3i:
	if not _PIECE_DEFINITIONS.has(piece_id):
		return Vector3i.ZERO
	var sub: Vector3i = (_PIECE_DEFINITIONS[piece_id] as Dictionary)["grid_sub_cells"]
	var swap_xz: bool = posmod(rotation_steps, 2) == 1
	return Vector3i(sub.z if swap_xz else sub.x, sub.y, sub.x if swap_xz else sub.z)


static func get_footprint_cells(
	piece_id: String,
	grid_pos: Vector3i,
	rotation_steps: int = 0
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var sub_size: Vector3i = get_rotated_sub_cells_size(piece_id, rotation_steps)
	if sub_size == Vector3i.ZERO:
		return cells
	for dx in range(sub_size.x):
		for dz in range(sub_size.z):
			cells.append(Vector2i(grid_pos.x + dx, grid_pos.z + dz))
	return cells


static func get_occupied_sub_cells(
	piece_id: String,
	grid_pos: Vector3i,
	rotation_steps: int = 0
) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if not _PIECE_DEFINITIONS.has(piece_id):
		return cells
	var def: Dictionary = _PIECE_DEFINITIONS[piece_id]
	var shape: String = def["shape"]
	var rot: int = posmod(rotation_steps, 4)
	var sub_size: Vector3i = get_rotated_sub_cells_size(piece_id, rot)

	if shape == "box" or shape == "stairs" or shape == "fence" or shape == "cone" or shape == "gable":
		for dx in range(sub_size.x):
			for dy in range(sub_size.y):
				for dz in range(sub_size.z):
					cells.append(Vector3i(grid_pos.x + dx, grid_pos.y + dy, grid_pos.z + dz))
	elif shape == "ramp":
		# Low half leaves upper sub-cells open under the slope; high half fills the full column.
		var low_offset: Vector2i = _RAMP_LOW_OFFSETS[rot]
		var high_offset: Vector2i = _RAMP_HIGH_OFFSETS[rot]
		var low_height: int = maxi(1, sub_size.y / 2)
		for dy in range(low_height):
			cells.append(Vector3i(grid_pos.x + low_offset.x, grid_pos.y + dy, grid_pos.z + low_offset.y))
		for dy in range(sub_size.y):
			cells.append(Vector3i(grid_pos.x + high_offset.x, grid_pos.y + dy, grid_pos.z + high_offset.y))

	return cells


static func get_flat_top_support_cells(
	piece_id: String,
	grid_pos: Vector3i,
	rotation_steps: int = 0
) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if not _PIECE_DEFINITIONS.has(piece_id):
		return cells
	var def: Dictionary = _PIECE_DEFINITIONS[piece_id]
	if def["shape"] != "box":
		return cells
	var sub_size: Vector3i = get_rotated_sub_cells_size(piece_id, rotation_steps)
	var top_y: int = grid_pos.y + sub_size.y
	for fp: Vector2i in get_footprint_cells(piece_id, grid_pos, rotation_steps):
		cells.append(Vector3i(fp.x, top_y, fp.y))
	return cells

