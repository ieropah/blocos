class_name StartScreenUI
extends CanvasLayer
## Kid-friendly start screen displayed over the 3D studio scene.
## Features a colorful block-style "BLOCOS 3D" title, a large green Play button,
## and a secondary button to open the Project Gallery.

signal play_pressed
signal gallery_pressed

const ThemeVisuals = preload("res://scripts/visuals/theme_visuals.gd")

const TITLE_LETTERS: Array[Dictionary] = [
	{"char": "B", "color": ThemeVisuals.CORAL_RED},
	{"char": "L", "color": ThemeVisuals.SUNNY_YELLOW},
	{"char": "O", "color": ThemeVisuals.COBALT_BLUE},
	{"char": "C", "color": ThemeVisuals.SAGE_GREEN},
	{"char": "O", "color": ThemeVisuals.TERRACOTTA},
	{"char": "S", "color": ThemeVisuals.PLUM_PURPLE},
]


class PlayTriangleIcon extends Control:
	func _draw() -> void:
		var cx: float = size.x * 0.5 + 3.0
		var cy: float = size.y * 0.5
		var pts := PackedVector2Array([
			Vector2(cx - 18.0, cy - 22.0),
			Vector2(cx + 22.0, cy),
			Vector2(cx - 18.0, cy + 22.0),
		])
		var rounded := _round_triangle(pts, 7.0, 5)
		draw_colored_polygon(rounded, Color.WHITE)

	static func _round_triangle(points: PackedVector2Array, radius: float, steps: int) -> PackedVector2Array:
		var res := PackedVector2Array()
		var count: int = points.size()
		for i in range(count):
			var p_prev: Vector2 = points[(i - 1 + count) % count]
			var p_curr: Vector2 = points[i]
			var p_next: Vector2 = points[(i + 1) % count]
			var a: Vector2 = p_curr + (p_prev - p_curr).normalized() * radius
			var b: Vector2 = p_curr + (p_next - p_curr).normalized() * radius
			for s in range(steps + 1):
				var t: float = float(s) / float(steps)
				var inv: float = 1.0 - t
				res.append(inv * inv * a + 2.0 * inv * t * p_curr + t * t * b)
		return res


class GalleryGridIcon extends Control:
	func _draw() -> void:
		var cx: float = size.x * 0.5
		var cy: float = size.y * 0.5
		var ink := Color(0.28, 0.24, 0.18, 1.0)
		var folder := StyleBoxFlat.new()
		folder.bg_color = Color(0.98, 0.80, 0.30)
		folder.border_color = ink
		folder.set_border_width_all(2)
		folder.set_corner_radius_all(6)
		draw_style_box(folder, Rect2(cx - 18.0, cy - 11.0, 36.0, 24.0))

		var tab := StyleBoxFlat.new()
		tab.bg_color = Color(0.95, 0.72, 0.22)
		tab.border_color = ink
		tab.set_border_width_all(2)
		tab.set_corner_radius_all(4)
		draw_style_box(tab, Rect2(cx - 18.0, cy - 16.0, 16.0, 8.0))

		var tiles: Array[Color] = [
			ThemeVisuals.CORAL_RED,
			ThemeVisuals.COBALT_BLUE,
			ThemeVisuals.SAGE_GREEN,
			ThemeVisuals.PLUM_PURPLE,
		]
		var offsets: Array[Vector2] = [
			Vector2(-9.0, -4.0),
			Vector2(1.0, -4.0),
			Vector2(-9.0, 4.0),
			Vector2(1.0, 4.0),
		]
		for i in range(4):
			var tile := StyleBoxFlat.new()
			tile.bg_color = tiles[i]
			tile.set_corner_radius_all(2)
			draw_style_box(tile, Rect2(Vector2(cx, cy) + offsets[i], Vector2(7.0, 6.0)))


var _root: Control = null
var _play_button: Button = null
var _gallery_button: Button = null


func _ready() -> void:
	ensure_setup()


func ensure_setup() -> void:
	if _root != null and is_instance_valid(_root):
		return

	layer = 5
	_root = Control.new()
	_root.name = "StartScreenRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.name = "StartBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.10, 0.20, 0.36, 0.28)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)

	var center_box := CenterContainer.new()
	center_box.name = "StartCenter"
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center_box)

	var column := VBoxContainer.new()
	column.name = "StartColumn"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_box.add_child(column)

	column.add_child(_build_title_row())

	var play_holder := CenterContainer.new()
	play_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(play_holder)

	_play_button = _create_play_button()
	play_holder.add_child(_play_button)

	var gallery_holder := CenterContainer.new()
	gallery_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gallery_holder)

	_gallery_button = _create_gallery_button()
	gallery_holder.add_child(_gallery_button)


func show_start_screen() -> void:
	ensure_setup()
	visible = true


func hide_start_screen() -> void:
	ensure_setup()
	visible = false


func get_play_button() -> Button:
	ensure_setup()
	return _play_button


func get_gallery_button() -> Button:
	ensure_setup()
	return _gallery_button


func _build_title_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "TitleBlocksRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for item: Dictionary in TITLE_LETTERS:
		row.add_child(_make_letter_block(str(item["char"]), item["color"] as Color))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(14.0, 0.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	row.add_child(_make_letter_block("3D", Color("#FFFFFF"), Color(0.20, 0.24, 0.30)))
	return row


func _make_letter_block(text_str: String, bg_color: Color, text_color: Color = Color.WHITE) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(68.0, 72.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = bg_color.darkened(0.22)
	style.set_border_width_all(3)
	style.border_width_bottom = 8
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.08, 0.14, 0.24, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text_str
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", text_color)
	badge.add_child(label)
	return badge


func _create_play_button() -> Button:
	var btn := Button.new()
	btn.name = "StartPlayButton"
	btn.text = ""
	btn.tooltip_text = "Jogar"
	btn.custom_minimum_size = Vector2(180.0, 110.0)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var green := Color("#4CD964")
	btn.add_theme_stylebox_override("normal", _make_toy_style(green, green.darkened(0.24), 32, 10))
	btn.add_theme_stylebox_override("hover", _make_toy_style(green.lightened(0.08), green.darkened(0.20), 32, 10))
	btn.add_theme_stylebox_override("pressed", _make_toy_style(green.darkened(0.08), green.darkened(0.30), 32, 5))
	btn.add_theme_stylebox_override("focus", _make_toy_style(green.lightened(0.05), green.darkened(0.22), 32, 10))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center)

	var icon := PlayTriangleIcon.new()
	icon.custom_minimum_size = Vector2(72.0, 64.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)

	btn.pressed.connect(func() -> void: play_pressed.emit())
	return btn


func _create_gallery_button() -> Button:
	var btn := Button.new()
	btn.name = "StartGalleryButton"
	btn.text = ""
	btn.tooltip_text = "Projetos"
	btn.custom_minimum_size = Vector2(140.0, 64.0)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var cream := Color("#FFF3C4")
	var border := Color("#E0C470")
	btn.add_theme_stylebox_override("normal", _make_toy_style(cream, border, 22, 6))
	btn.add_theme_stylebox_override("hover", _make_toy_style(cream.lightened(0.05), border, 22, 6))
	btn.add_theme_stylebox_override("pressed", _make_toy_style(cream.darkened(0.08), border, 22, 3))
	btn.add_theme_stylebox_override("focus", _make_toy_style(cream, border, 22, 6))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center)

	var icon := GalleryGridIcon.new()
	icon.custom_minimum_size = Vector2(56.0, 44.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)

	btn.pressed.connect(func() -> void: gallery_pressed.emit())
	return btn


func _make_toy_style(bg_color: Color, border_color: Color, radius: int, bottom_border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.border_width_bottom = bottom_border
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.08, 0.14, 0.24, 0.25)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 6)
	return style
