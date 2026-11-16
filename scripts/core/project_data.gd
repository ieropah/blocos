class_name ProjectData
extends RefCounted
## Logical data model for an independent construction project and its metadata.

const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")
const PlacedPieceData = preload("res://scripts/core/placed_piece_data.gd")

const CURRENT_FORMAT_VERSION: int = 1
const DEFAULT_GRID_SIZE: int = 8
const LEGACY_GRID_SIZE: int = 12
const VALID_GRID_SIZES: Array[int] = [8, 12, 16, 32]
const DEFAULT_THEME_ID: String = "plastic"
const VALID_THEMES: Array[String] = ["plastic", "voxel", "solid", "wood"]
const DEFAULT_MODE_ID: String = "scenery"
const VALID_MODES: Array[String] = ["character", "animal", "vehicle", "scenery"]

var project_id: String = ""
var project_name: String = ""
var format_version: int = CURRENT_FORMAT_VERSION
var created_at: int = 0
var modified_at: int = 0
var grid_size: int = DEFAULT_GRID_SIZE
var board_size: int = DEFAULT_GRID_SIZE
var theme_id: String = DEFAULT_THEME_ID
var mode_id: String = DEFAULT_MODE_ID
var pieces: Array[Dictionary] = []


func _init(
	p_id: String = "",
	p_name: String = "",
	p_pieces: Array = [],
	p_created_at: int = 0,
	p_modified_at: int = 0,
	p_version: int = CURRENT_FORMAT_VERSION,
	p_grid_size: int = DEFAULT_GRID_SIZE,
	p_theme_id: String = DEFAULT_THEME_ID,
	p_mode_id: String = DEFAULT_MODE_ID
) -> void:
	project_id = p_id
	project_name = p_name
	format_version = p_version
	created_at = p_created_at
	modified_at = p_modified_at
	grid_size = normalize_grid_size(p_grid_size)
	board_size = grid_size
	theme_id = normalize_theme_id(p_theme_id)
	mode_id = normalize_mode_id(p_mode_id)
	set_pieces_from_placed_data(p_pieces)


static func is_valid_grid_size(size: int) -> bool:
	return size in VALID_GRID_SIZES


static func normalize_grid_size(size: int) -> int:
	if size in VALID_GRID_SIZES:
		return size
	return maxi(size, 1)


static func is_valid_theme_id(p_theme_id: String) -> bool:
	return p_theme_id in VALID_THEMES


static func normalize_theme_id(p_theme_id: String) -> String:
	return p_theme_id if p_theme_id in VALID_THEMES else DEFAULT_THEME_ID


static func is_valid_mode_id(p_mode_id: String) -> bool:
	return p_mode_id in VALID_MODES


static func normalize_mode_id(p_mode_id: String) -> String:
	return p_mode_id if p_mode_id in VALID_MODES else DEFAULT_MODE_ID


func get_piece_count() -> int:
	return pieces.size()


func set_pieces_from_placed_data(placed_pieces: Array) -> void:
	pieces.clear()
	for entry_variant: Variant in placed_pieces:
		if entry_variant is PlacedPieceData:
			var placed := entry_variant as PlacedPieceData
			pieces.append({
				"piece_id": placed.piece_id,
				"grid_pos": placed.grid_pos,
				"rotation_steps": posmod(placed.rotation_steps, 4),
				"color": placed.color,
			})
		elif entry_variant is Dictionary:
			var d := entry_variant as Dictionary
			var gp: Variant = d.get("grid_pos", Vector3i.ZERO)
			var grid_pos: Vector3i = gp as Vector3i if gp is Vector3i else Vector3i.ZERO
			var col: Variant = d.get("color", Color.WHITE)
			var piece_color: Color = col as Color if col is Color else Color.WHITE
			pieces.append({
				"piece_id": str(d.get("piece_id", "")),
				"grid_pos": grid_pos,
				"rotation_steps": posmod(int(d.get("rotation_steps", 0)), 4),
				"color": piece_color,
			})


func duplicate_data() -> ProjectData:
	var script_cls := get_script() as GDScript
	return script_cls.new(
		project_id,
		project_name,
		pieces,
		created_at,
		modified_at,
		format_version,
		grid_size,
		theme_id,
		mode_id
	)
