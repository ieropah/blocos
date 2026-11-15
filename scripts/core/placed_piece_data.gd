class_name PlacedPieceData
extends RefCounted
## Data model representing a placed toy block instance and its cached sub-cell footprints.

const PieceCatalog = preload("res://scripts/core/piece_catalog.gd")

var instance_id: int
var piece_id: String
var grid_pos: Vector3i
var rotation_steps: int
var color: Color
var occupied_cells: Array[Vector3i] = []
var flat_top_cells: Array[Vector3i] = []


func _init(
	p_instance_id: int,
	p_piece_id: String,
	p_grid_pos: Vector3i,
	p_rotation_steps: int = 0,
	p_color: Color = Color.WHITE
) -> void:
	instance_id = p_instance_id
	piece_id = p_piece_id
	grid_pos = p_grid_pos
	rotation_steps = posmod(p_rotation_steps, 4)
	color = p_color
	occupied_cells = PieceCatalog.get_occupied_sub_cells(piece_id, grid_pos, rotation_steps)
	flat_top_cells = PieceCatalog.get_flat_top_support_cells(piece_id, grid_pos, rotation_steps)
