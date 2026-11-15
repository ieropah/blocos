class_name ConstructionUI
extends CanvasLayer

## Responsive HUD for the construction workspace.
## Displays the left 20% color & shape tray, bottom-center/left piece editing controls,
## and bottom-right floating camera toolbar with touch-friendly controls.

signal rotate_left_pressed
signal rotate_right_pressed
signal zoom_in_pressed
signal zoom_out_pressed
signal recenter_pressed
signal tray_piece_drag_started(piece_id: String, screen_pos: Vector2)
signal shape_selected(piece_id: String)
signal color_selected(color_id: String, color: Color)
signal rotate_piece_pressed
signal delete_piece_pressed
signal undo_pressed
signal redo_pressed
signal gallery_pressed
signal home_pressed
signal home_requested
signal tool_selected(tool_name: String)

const CameraController = preload("res://scripts/controllers/camera_controller.gd")
const ThemeVisuals = preload("res://scripts/visuals/theme_visuals.gd")
const UiIconDrawer = preload("res://scripts/visuals/ui_icon_drawer.gd")

const TRAY_WIDTH_PX := 116.0
const TOOLBAR_SAFE_MARGIN := 32
const BUTTON_MIN_SIZE := Vector2(68.0, 68.0)
const EDITING_BUTTON_MIN_SIZE := Vector2(68.0, 68.0)
const BUTTON_CORNER_RADIUS := 18
const TRAY_CORNER_RADIUS := 24
const CARD_CORNER_RADIUS := 18
const SWATCH_CORNER_RADIUS := 14
const PALETTE_CONTAINER_CORNER_RADIUS := 16
const ICON_BADGE_CORNER_RADIUS := 16
const ZOOM_BUTTON_STEP := 1.25

const COLOR_TRAY_BG := Color("#F4EFE6")
const COLOR_TRAY_BORDER := Color("#D0C6B8")
const COLOR_CARD_BG := Color("#FFFDF9")
const COLOR_CARD_SELECTED_BG := Color("#FFF3B0")
const COLOR_CARD_BORDER := Color("#D8CFC2")
const COLOR_CARD_SELECTED_BORDER := Color("#F59E0B")
const COLOR_TOOL_SELECTED_BG := Color("#E3F2FD")
const COLOR_TOOL_SELECTED_BORDER := Color("#2196F3")
const COLOR_TOOLBAR_BG := Color("#F4EFE6")
const COLOR_TOOLBAR_BORDER := Color("#D0C6B8")
const COLOR_TEXT_PRIMARY := Color(0.20, 0.19, 0.18, 1.0)
const COLOR_TEXT_MUTED := Color(0.49, 0.46, 0.42, 1.0)
const COLOR_BUTTON_NORMAL := Color("#FFFDF9")
const COLOR_BUTTON_HOVER := Color("#FFFFFF")
const COLOR_BUTTON_PRESSED := Color("#F5EFE6")
const COLOR_BUTTON_DISABLED := Color("#FFFDF9")
const COLOR_BUTTON_BORDER := Color("#D8CFC2")
const COLOR_BUTTON_BORDER_ACTIVE := Color("#C8BEB0")
const COLOR_BUTTON_BORDER_DISABLED := Color("#D8CFC2")
const COLOR_TEXT_DISABLED := Color(0.60, 0.57, 0.52, 0.75)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.12)

const COLOR_OPTIONS: Array[Dictionary] = [
	{"id": "coral_red", "name": "Vermelho Coral", "color": ThemeVisuals.CORAL_RED},
	{"id": "sunny_yellow", "name": "Amarelo Sol", "color": ThemeVisuals.SUNNY_YELLOW},
	{"id": "cobalt_blue", "name": "Azul Cobalto", "color": ThemeVisuals.COBALT_BLUE},
	{"id": "sage_green", "name": "Verde Sálvia", "color": ThemeVisuals.SAGE_GREEN},
	{"id": "terracotta", "name": "Terracota", "color": ThemeVisuals.TERRACOTTA},
	{"id": "plum_purple", "name": "Roxo Ameixa", "color": ThemeVisuals.PLUM_PURPLE},
]

const PREVIEW_PIECES: Array[Dictionary] = [
	{"id": "cube", "name": "Cubo", "color": ThemeVisuals.CORAL_RED},
	{"id": "long_block", "name": "Bloco Longo", "color": ThemeVisuals.COBALT_BLUE},
	{"id": "square_plate", "name": "Placa", "color": ThemeVisuals.SAGE_GREEN},
	{"id": "ramp", "name": "Rampa", "color": ThemeVisuals.TERRACOTTA},
]


class ShapeIcon extends TextureRect:
	var shape_id: String = "cube"
	var fill_color: Color = ThemeVisuals.CORAL_RED

	func _ready() -> void:
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_refresh_texture()

	func set_icon_color(color: Color) -> void:
		fill_color = color
		_refresh_texture()

	func _refresh_texture() -> void:
		texture = UiIconDrawer.get_piece_icon_texture(shape_id, fill_color)


var _root: Control = null
var _tray_panel: PanelContainer = null
var _palette_container: PanelContainer = null
var _cards_box: VBoxContainer = null
var _top_bar_panel: PanelContainer = null
var _gallery_button: Button = null
var _home_button: Button = null
var _active_project_label: Label = null
var _active_project_name: String = "Construção Inicial"
var _editing_toolbar_panel: PanelContainer = null
var _tool_toolbar_panel: PanelContainer = null
var _toolbar_panel: PanelContainer = null
var _tray_cards: Dictionary = {}
var _shape_icons: Dictionary = {}
var _color_buttons: Dictionary = {}
var _editing_buttons: Dictionary = {}
var _tool_buttons: Dictionary = {}
var _buttons: Dictionary = {}
var _button_icons: Dictionary = {}
var _paint_tool_icon: TextureRect = null
var _selected_color_id: String = "coral_red"
var _selected_color: Color = ThemeVisuals.CORAL_RED
var _selected_shape_id: String = "cube"
var _selected_tool: String = "build"
var _active_theme_id: String = "plastic"
var _active_grid_size: int = 8
var _bound_controller: CameraController = null
var _bound_connections: Array[Dictionary] = []


func _ready() -> void:
	ensure_setup()


## Builds the responsive UI hierarchy once. Safe to call before or after _ready().
func ensure_setup() -> void:
	if _root != null and is_instance_valid(_root):
		return

	_root = Control.new()
	_root.name = "UIRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	_build_tray_panel(_root)
	_build_toolbar_panel(_root)
	home_pressed.connect(func() -> void: home_requested.emit())


## Sets the active grid size (e.g. 8, 16, 32) and refreshes theme-dependent HUD visibility.
func set_grid_size(size: int) -> void:
	var target_size: int = maxi(size, 1)
	if _active_grid_size == target_size:
		return
	_active_grid_size = target_size
	set_active_theme(_active_theme_id, [], _active_grid_size)


## Alias for set_active_theme so callers using set_theme rebuild the tray and HUD state.
func set_theme(theme_id: String, catalog_pieces: Array = [], grid_size: int = -1) -> void:
	set_active_theme(theme_id, catalog_pieces, grid_size)


## Filters the left piece sidebar to pieces allowed for the active theme and refreshes thumbnails.
func set_active_theme(theme_id: String, catalog_pieces: Array = [], grid_size: int = -1) -> void:
	ensure_setup()
	if _active_theme_id != theme_id:
		ToyMeshBuilder.clear_cache()
	_active_theme_id = theme_id
	if grid_size > 0:
		_active_grid_size = grid_size

	var is_voxel: bool = (theme_id == "voxel")
	var hide_paint_ui: bool = is_voxel and _active_grid_size > 8
	if _palette_container != null and is_instance_valid(_palette_container):
		_palette_container.visible = not hide_paint_ui
	var paint_btn: Button = _tool_buttons.get("paint") as Button
	if paint_btn != null and is_instance_valid(paint_btn):
		paint_btn.visible = not hide_paint_ui
	if hide_paint_ui and _selected_tool == "paint":
		select_tool("build")

	var source_pieces: Array = catalog_pieces
	if source_pieces.is_empty():
		source_pieces = PieceCatalog.get_pieces_for_theme(theme_id, _active_grid_size)
	if source_pieces.is_empty():
		source_pieces = PREVIEW_PIECES

	var normalized_pieces: Array[Dictionary] = []
	for entry: Variant in source_pieces:
		if entry is Dictionary:
			var dict_entry := entry as Dictionary
			var pid: String = str(dict_entry.get("id", ""))
			if not pid.is_empty():
				normalized_pieces.append({
					"id": pid,
					"name": str(dict_entry.get("name", pid)),
				})
		elif entry is String:
			var pid_str: String = entry as String
			if not pid_str.is_empty():
				normalized_pieces.append({"id": pid_str, "name": pid_str})

	if normalized_pieces.is_empty():
		normalized_pieces = PREVIEW_PIECES.duplicate()

	if _cards_box != null and is_instance_valid(_cards_box):
		for child: Node in _cards_box.get_children():
			_cards_box.remove_child(child)
			child.queue_free()

		_tray_cards.clear()
		_shape_icons.clear()
		for piece: Dictionary in normalized_pieces:
			_cards_box.add_child(_create_preview_card(piece))

		if not _tray_cards.has(_selected_shape_id) and not _tray_cards.is_empty():
			_selected_shape_id = str(_tray_cards.keys()[0])

		_refresh_shape_cards()
		_refresh_shape_icons()


func get_active_theme_id() -> String:
	return _active_theme_id


## Wires toolbar signals to the given CameraController, replacing any prior binding.
func bind_camera_controller(controller: CameraController) -> void:
	ensure_setup()
	_disconnect_bound_controller()

	if controller == null or not is_instance_valid(controller):
		return

	_bound_controller = controller
	var bindings: Array[Dictionary] = [
		{"signal": rotate_left_pressed, "callable": controller.rotate_step.bind(-1)},
		{"signal": rotate_right_pressed, "callable": controller.rotate_step.bind(1)},
		{"signal": zoom_in_pressed, "callable": controller.zoom_step.bind(-ZOOM_BUTTON_STEP)},
		{"signal": zoom_out_pressed, "callable": controller.zoom_step.bind(ZOOM_BUTTON_STEP)},
		{"signal": recenter_pressed, "callable": controller.recenter},
	]

	for entry: Dictionary in bindings:
		var sig: Signal = entry["signal"]
		var cb: Callable = entry["callable"]
		sig.connect(cb)
		_bound_connections.append(entry)


## Returns a shallow copy of the toolbar buttons keyed by button node name.
func get_toolbar_buttons() -> Dictionary:
	ensure_setup()
	return _buttons.duplicate()


## Returns true if the given screen coordinate lies within the left tray panel.
func is_screen_point_in_tray(screen_pos: Vector2) -> bool:
	ensure_setup()
	return (
		_tray_panel != null
		and is_instance_valid(_tray_panel)
		and _tray_panel.get_global_rect().has_point(screen_pos)
	)


## Returns a shallow copy of tray piece cards keyed by piece ID.
func get_tray_cards() -> Dictionary:
	ensure_setup()
	return _tray_cards.duplicate()


## Returns a shallow copy of the color swatch buttons keyed by color ID.
func get_color_buttons() -> Dictionary:
	ensure_setup()
	return _color_buttons.duplicate()


## Returns a shallow copy of the piece-editing and history buttons keyed by button node name.
func get_editing_buttons() -> Dictionary:
	ensure_setup()
	return _editing_buttons.duplicate()


## Returns a shallow copy of the tool mode buttons keyed by tool name ("build", "paint", "erase").
func get_tool_buttons() -> Dictionary:
	ensure_setup()
	return _tool_buttons.duplicate()


## Selects the active interaction tool ("build", "paint", or "erase") and updates highlights.
func select_tool(tool_name: String) -> void:
	ensure_setup()
	if not _tool_buttons.has(tool_name):
		return
	if _selected_tool == tool_name:
		return
	_selected_tool = tool_name
	_refresh_tool_buttons()
	tool_selected.emit(tool_name)


func get_selected_tool() -> String:
	ensure_setup()
	return _selected_tool


## Selects an active block color by color_id or Color without changing the selected shape.
func select_color(color_id_or_color: Variant) -> void:
	ensure_setup()
	var matched_id: String = ""
	var matched_color: Color = _selected_color

	if color_id_or_color is String:
		var requested_id: String = color_id_or_color as String
		for entry: Dictionary in COLOR_OPTIONS:
			if str(entry["id"]) == requested_id:
				matched_id = requested_id
				matched_color = entry["color"] as Color
				break
		if matched_id.is_empty():
			return
	elif color_id_or_color is Color:
		var requested_color: Color = color_id_or_color as Color
		matched_color = requested_color
		for entry: Dictionary in COLOR_OPTIONS:
			var entry_color: Color = entry["color"] as Color
			if (
				absf(entry_color.r - requested_color.r) <= 0.01
				and absf(entry_color.g - requested_color.g) <= 0.01
				and absf(entry_color.b - requested_color.b) <= 0.01
			):
				matched_id = str(entry["id"])
				matched_color = entry_color
				break
	else:
		return

	_selected_color_id = matched_id
	_selected_color = matched_color
	_refresh_color_buttons()
	_refresh_shape_icons()
	if _paint_tool_icon != null and is_instance_valid(_paint_tool_icon):
		_paint_tool_icon.texture = UiIconDrawer.get_icon_texture("paint", _selected_color)
	if _selected_tool == "erase" and not (_active_theme_id == "voxel" and _active_grid_size > 8):
		select_tool("paint")
	color_selected.emit(_selected_color_id, _selected_color)


func get_selected_color() -> Color:
	ensure_setup()
	return _selected_color


func get_selected_color_id() -> String:
	ensure_setup()
	return _selected_color_id


## Selects a block shape by piece_id without changing the selected color.
func select_shape(piece_id: String) -> void:
	ensure_setup()
	if not _tray_cards.has(piece_id):
		return
	_selected_shape_id = piece_id
	_refresh_shape_cards()
	select_tool("build")
	shape_selected.emit(piece_id)


func get_selected_shape() -> String:
	ensure_setup()
	return _selected_shape_id


## Enables or disables the Rotate and Delete buttons for the active piece selection.
func set_piece_selected_state(is_selected: bool) -> void:
	ensure_setup()
	for btn_name: String in ["RotatePieceButton", "DeletePieceButton"]:
		if _editing_buttons.has(btn_name):
			var btn := _editing_buttons[btn_name] as Button
			if btn != null and is_instance_valid(btn):
				btn.disabled = not is_selected
				btn.modulate.a = 1.0 if is_selected else 0.45


## Enables or disables the Undo and Redo buttons based on history availability.
func set_history_state(can_undo: bool, can_redo: bool) -> void:
	ensure_setup()
	if _editing_buttons.has("UndoButton"):
		var undo_btn := _editing_buttons["UndoButton"] as Button
		if undo_btn != null and is_instance_valid(undo_btn):
			undo_btn.disabled = not can_undo
			undo_btn.modulate.a = 1.0 if can_undo else 0.45
	if _editing_buttons.has("RedoButton"):
		var redo_btn := _editing_buttons["RedoButton"] as Button
		if redo_btn != null and is_instance_valid(redo_btn):
			redo_btn.disabled = not can_redo
			redo_btn.modulate.a = 1.0 if can_redo else 0.45


## Updates the active project title shown beside the Projects button.
func set_active_project_name(project_name: String) -> void:
	ensure_setup()
	var trimmed: String = project_name.strip_edges()
	_active_project_name = "Construção Inicial" if trimmed.is_empty() else trimmed
	if _active_project_label != null and is_instance_valid(_active_project_label):
		_active_project_label.text = _active_project_name


func get_active_project_name() -> String:
	ensure_setup()
	return _active_project_name


func get_gallery_button() -> Button:
	ensure_setup()
	return _gallery_button


## Returns true if the given screen coordinate lies over any interactive HUD panel.
func is_screen_point_over_ui(screen_pos: Vector2) -> bool:
	ensure_setup()
	for panel: PanelContainer in [_tray_panel, _top_bar_panel, _tool_toolbar_panel, _editing_toolbar_panel, _toolbar_panel]:
		if (
			panel != null
			and is_instance_valid(panel)
			and panel.visible
			and panel.get_global_rect().has_point(screen_pos)
		):
			return true
	return false


func _disconnect_bound_controller() -> void:
	for entry: Dictionary in _bound_connections:
		var sig: Signal = entry["signal"]
		var cb: Callable = entry["callable"]
		if sig.is_connected(cb):
			sig.disconnect(cb)
	_bound_connections.clear()
	_bound_controller = null


func _build_tray_panel(parent: Control) -> void:
	_tray_panel = PanelContainer.new()
	_tray_panel.name = "TrayPanel"
	_tray_panel.anchor_left = 0.0
	_tray_panel.anchor_right = 0.0
	_tray_panel.anchor_top = 0.0
	_tray_panel.anchor_bottom = 1.0
	_tray_panel.offset_left = 14.0
	_tray_panel.offset_top = 14.0
	_tray_panel.offset_right = 14.0 + TRAY_WIDTH_PX
	_tray_panel.offset_bottom = -14.0
	_tray_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_tray_panel.add_theme_stylebox_override("panel", _make_tray_style())
	parent.add_child(_tray_panel)

	var margin := MarginContainer.new()
	margin.name = "TrayMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_tray_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "TrayColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_palette_container = PanelContainer.new()
	_palette_container.name = "ColorPaletteContainer"
	_palette_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_palette_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette_container.add_theme_stylebox_override("panel", _make_palette_container_style())
	_palette_container.visible = (_active_theme_id != "voxel")
	column.add_child(_palette_container)

	var color_grid := GridContainer.new()
	color_grid.name = "ColorGrid"
	color_grid.columns = 2
	color_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	color_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_grid.add_theme_constant_override("h_separation", 6)
	color_grid.add_theme_constant_override("v_separation", 6)
	_palette_container.add_child(color_grid)

	_color_buttons.clear()
	for entry: Dictionary in COLOR_OPTIONS:
		var color_id: String = str(entry["id"])
		var color_name: String = str(entry["name"])
		var swatch_color: Color = entry["color"] as Color
		var swatch_btn := _create_color_button(color_id, color_name, swatch_color)
		color_grid.add_child(swatch_btn)
		_color_buttons[color_id] = swatch_btn

	var scroll := ScrollContainer.new()
	scroll.name = "PreviewScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(scroll)

	_cards_box = VBoxContainer.new()
	_cards_box.name = "PreviewCards"
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_box.add_theme_constant_override("separation", 12)
	scroll.add_child(_cards_box)

	_tray_cards.clear()
	_shape_icons.clear()
	for piece: Dictionary in PREVIEW_PIECES:
		_cards_box.add_child(_create_preview_card(piece))

	_refresh_color_buttons()
	_refresh_shape_cards()
	_refresh_shape_icons()


func _create_section_label(node_name: String, label_text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	return label


func _create_color_button(color_id: String, color_name: String, swatch_color: Color) -> Button:
	var btn := Button.new()
	btn.name = "ColorButton_" + color_id
	btn.tooltip_text = color_name
	btn.custom_minimum_size = Vector2(42.0, 32.0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_meta("color_id", color_id)
	btn.set_meta("swatch_color", swatch_color)
	btn.pressed.connect(func() -> void: select_color(color_id))
	return btn


func _create_preview_card(piece: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var piece_id: String = piece["id"]
	var piece_name: String = piece["name"]

	card.name = piece_name.replace(" ", "") + "Card"
	card.custom_minimum_size = Vector2(88.0, 66.0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.set_meta("piece_id", piece_id)
	card.add_theme_stylebox_override("panel", _make_card_style(piece_id == _selected_shape_id))
	_tray_cards[piece_id] = card

	card.gui_input.connect(_on_card_gui_input.bind(card, piece_id))

	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var icon := ShapeIcon.new()
	icon.name = "ShapeIcon"
	icon.shape_id = piece_id
	icon.fill_color = _selected_color
	icon.custom_minimum_size = Vector2(72.0, 56.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	_shape_icons[piece_id] = icon

	return card


func _on_card_gui_input(event: InputEvent, card: PanelContainer, piece_id: String) -> void:
	var local_pos := Vector2.ZERO
	var should_start := false

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			local_pos = mouse_event.position
			should_start = true
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and touch_event.index == 0:
			local_pos = touch_event.position
			should_start = true

	if should_start:
		var global_pos: Vector2 = card.get_global_transform_with_canvas() * local_pos
		card.accept_event()
		select_shape(piece_id)
		tray_piece_drag_started.emit(piece_id, global_pos)


func _refresh_color_buttons() -> void:
	for color_id_variant: Variant in _color_buttons.keys():
		var color_id: String = str(color_id_variant)
		var btn := _color_buttons[color_id] as Button
		if btn == null or not is_instance_valid(btn):
			continue
		var swatch_color: Color = btn.get_meta("swatch_color", ThemeVisuals.CORAL_RED) as Color
		var is_active: bool = color_id == _selected_color_id
		var normal_style := _make_swatch_button_style(swatch_color, is_active, false)
		var hover_style := _make_swatch_button_style(swatch_color.lightened(0.08), is_active, true)
		var pressed_style := _make_swatch_button_style(swatch_color.darkened(0.08), true, true)
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_stylebox_override("focus", hover_style)


func _refresh_shape_cards() -> void:
	for piece_id_variant: Variant in _tray_cards.keys():
		var piece_id: String = str(piece_id_variant)
		var card := _tray_cards[piece_id] as PanelContainer
		if card == null or not is_instance_valid(card):
			continue
		card.add_theme_stylebox_override("panel", _make_card_style(piece_id == _selected_shape_id))


func _refresh_shape_icons() -> void:
	for icon_variant: Variant in _shape_icons.values():
		var icon := icon_variant as ShapeIcon
		if icon != null and is_instance_valid(icon):
			if ToyMeshBuilder.is_voxel_piece(icon.shape_id):
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon.set_icon_color(Color.WHITE)
			else:
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				icon.set_icon_color(_selected_color)


func _build_toolbar_panel(parent: Control) -> void:
	var toolbar_area := MarginContainer.new()
	toolbar_area.name = "ToolbarArea"
	toolbar_area.anchor_left = 0.0
	toolbar_area.anchor_top = 0.0
	toolbar_area.anchor_right = 1.0
	toolbar_area.anchor_bottom = 1.0
	toolbar_area.offset_left = 14.0 + TRAY_WIDTH_PX
	toolbar_area.offset_top = 0.0
	toolbar_area.offset_right = 0.0
	toolbar_area.offset_bottom = 0.0
	toolbar_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar_area.add_theme_constant_override("margin_left", 24)
	toolbar_area.add_theme_constant_override("margin_top", 20)
	toolbar_area.add_theme_constant_override("margin_right", TOOLBAR_SAFE_MARGIN)
	toolbar_area.add_theme_constant_override("margin_bottom", TOOLBAR_SAFE_MARGIN)
	parent.add_child(toolbar_area)

	var layout_col := VBoxContainer.new()
	layout_col.name = "ToolbarLayoutColumn"
	layout_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_col.add_theme_constant_override("separation", 12)
	toolbar_area.add_child(layout_col)

	var top_row := HBoxContainer.new()
	top_row.name = "TopBarRow"
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_col.add_child(top_row)

	_top_bar_panel = _create_top_bar_panel()
	top_row.add_child(_top_bar_panel)

	var top_spacer := Control.new()
	top_spacer.name = "TopBarSpacer"
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_spacer)

	_tool_toolbar_panel = _create_tool_toolbar_panel()
	top_row.add_child(_tool_toolbar_panel)

	var vertical_spacer := Control.new()
	vertical_spacer.name = "ToolbarVerticalSpacer"
	vertical_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vertical_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_col.add_child(vertical_spacer)

	var bottom_row := HBoxContainer.new()
	bottom_row.name = "BottomBarRow"
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_theme_constant_override("separation", 16)
	layout_col.add_child(bottom_row)

	var editing_specs: Array[Dictionary] = [
		{"name": "RotatePieceButton", "icon": "rotate_piece", "tooltip": "Girar bloco selecionado 90 graus", "signal": rotate_piece_pressed, "disabled": true},
		{"name": "DeletePieceButton", "icon": "delete_piece", "tooltip": "Apagar bloco selecionado", "signal": delete_piece_pressed, "disabled": true},
		{"name": "UndoButton", "icon": "undo", "tooltip": "Desfazer última ação", "signal": undo_pressed, "disabled": true},
		{"name": "RedoButton", "icon": "redo", "tooltip": "Refazer última ação", "signal": redo_pressed, "disabled": true},
	]
	_editing_buttons.clear()
	_editing_toolbar_panel = _create_toolbar_panel(
		"EditingToolbarPanel",
		"EditingButtons",
		editing_specs,
		EDITING_BUTTON_MIN_SIZE,
		_editing_buttons
	)
	_editing_toolbar_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bottom_row.add_child(_editing_toolbar_panel)

	var spacer := Control.new()
	spacer.name = "BottomBarSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(spacer)

	var camera_specs: Array[Dictionary] = [
		{"name": "RotateLeftButton", "icon": "rotate_left", "tooltip": "Girar câmera 90 graus à esquerda", "signal": rotate_left_pressed},
		{"name": "RotateRightButton", "icon": "rotate_right", "tooltip": "Girar câmera 90 graus à direita", "signal": rotate_right_pressed},
		{"name": "ZoomOutButton", "icon": "zoom_out", "tooltip": "Afastar zoom", "signal": zoom_out_pressed},
		{"name": "ZoomInButton", "icon": "zoom_in", "tooltip": "Aproximar zoom", "signal": zoom_in_pressed},
		{"name": "RecenterButton", "icon": "recenter", "tooltip": "Centralizar câmera", "signal": recenter_pressed},
	]
	_buttons.clear()
	_toolbar_panel = _create_toolbar_panel(
		"ToolbarPanel",
		"ToolbarButtons",
		camera_specs,
		BUTTON_MIN_SIZE,
		_buttons
	)
	_toolbar_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	bottom_row.add_child(_toolbar_panel)


func _create_top_bar_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "TopBarPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_toolbar_style())

	var margin := MarginContainer.new()
	margin.name = "TopBarMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "TopBarContents"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	_home_button = _create_toolbar_button(
		"HomeButton",
		"home",
		"Voltar para a tela inicial",
		home_pressed,
		Vector2(68.0, 68.0),
		false
	)
	row.add_child(_home_button)

	_gallery_button = _create_toolbar_button(
		"GalleryButton",
		"gallery",
		"Abrir galeria de projetos",
		gallery_pressed,
		Vector2(68.0, 68.0),
		false
	)
	row.add_child(_gallery_button)

	_active_project_label = Label.new()
	_active_project_label.name = "ActiveProjectLabel"
	_active_project_label.text = _active_project_name
	_active_project_label.visible = false
	row.add_child(_active_project_label)

	return panel


func _create_tool_toolbar_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ToolToolbarPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_toolbar_style())

	var margin := MarginContainer.new()
	margin.name = "ToolToolbarMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "ToolButtonsRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var tool_specs: Array[Dictionary] = [
		{"id": "build", "name": "BuildToolButton", "icon": "build", "tooltip": "Modo construir: arraste peças para montar"},
		{"id": "paint", "name": "PaintToolButton", "icon": "paint", "tooltip": "Modo pintar: toque ou arraste para colorir peças"},
		{"id": "erase", "name": "EraseToolButton", "icon": "erase", "tooltip": "Modo borracha: toque ou arraste para apagar peças"},
	]

	_tool_buttons.clear()
	_paint_tool_icon = null
	for spec: Dictionary in tool_specs:
		var tool_id: String = str(spec["id"])
		var btn := Button.new()
		btn.name = str(spec["name"])
		btn.text = ""
		btn.expand_icon = true
		btn.tooltip_text = str(spec["tooltip"])
		btn.custom_minimum_size = Vector2(68.0, 68.0)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func() -> void: select_tool(tool_id))

		var icon := _attach_hud_icon(btn, str(spec["icon"]))
		if tool_id == "paint":
			icon.texture = UiIconDrawer.get_icon_texture("paint", _selected_color)
			_paint_tool_icon = icon

		row.add_child(btn)
		_tool_buttons[tool_id] = btn

	_refresh_tool_buttons()
	return panel


func _refresh_tool_buttons() -> void:
	for tool_id_variant: Variant in _tool_buttons.keys():
		var tool_id: String = str(tool_id_variant)
		var btn := _tool_buttons[tool_id] as Button
		if btn == null or not is_instance_valid(btn):
			continue
		var is_active: bool = tool_id == _selected_tool
		var normal_bg: Color = COLOR_TOOL_SELECTED_BG if is_active else COLOR_BUTTON_NORMAL
		var normal_border: Color = COLOR_TOOL_SELECTED_BORDER if is_active else COLOR_BUTTON_BORDER
		var hover_bg: Color = COLOR_TOOL_SELECTED_BG if is_active else COLOR_BUTTON_HOVER
		var hover_border: Color = COLOR_TOOL_SELECTED_BORDER if is_active else COLOR_BUTTON_BORDER_ACTIVE
		var top_bw: int = 3 if is_active else 2

		var normal_style := _make_toy_button_style(normal_bg, normal_border, false, top_bw)
		var hover_style := _make_toy_button_style(hover_bg, hover_border, false, top_bw)
		var pressed_style := _make_toy_button_style(normal_bg.darkened(0.04), normal_border, true, top_bw)
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_stylebox_override("focus", hover_style)


func _create_toolbar_panel(
	panel_name: String,
	row_name: String,
	button_specs: Array[Dictionary],
	min_button_size: Vector2,
	target_map: Dictionary
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_toolbar_style())

	var margin := MarginContainer.new()
	margin.name = panel_name + "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	for spec: Dictionary in button_specs:
		var btn := _create_toolbar_button(
			spec["name"],
			spec["icon"],
			spec["tooltip"],
			spec["signal"],
			min_button_size,
			bool(spec.get("disabled", false))
		)
		row.add_child(btn)
		target_map[spec["name"]] = btn

	return panel


func _create_toolbar_button(
	button_name: String,
	icon_type: String,
	tooltip: String,
	target_signal: Signal,
	min_size: Vector2 = BUTTON_MIN_SIZE,
	initially_disabled: bool = false
) -> Button:
	var btn := Button.new()
	btn.name = button_name
	btn.text = ""
	btn.expand_icon = true
	btn.tooltip_text = tooltip
	btn.disabled = initially_disabled
	btn.custom_minimum_size = min_size
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal_style := _make_toy_button_style(COLOR_BUTTON_NORMAL, COLOR_BUTTON_BORDER, false, 2)
	var hover_style := _make_toy_button_style(COLOR_BUTTON_HOVER, COLOR_BUTTON_BORDER_ACTIVE, false, 2)
	var pressed_style := _make_toy_button_style(COLOR_BUTTON_PRESSED, COLOR_BUTTON_BORDER_ACTIVE, true, 2)
	var focus_style := _make_toy_button_style(COLOR_BUTTON_HOVER, COLOR_BUTTON_BORDER_ACTIVE, false, 2)
	var disabled_style := _make_toy_button_style(COLOR_BUTTON_DISABLED, COLOR_BUTTON_BORDER_DISABLED, false, 2)

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", focus_style)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	btn.modulate.a = 0.45 if initially_disabled else 1.0

	var icon := _attach_hud_icon(btn, icon_type)
	_button_icons[button_name] = icon

	btn.pressed.connect(func() -> void: target_signal.emit())
	return btn


func _attach_hud_icon(btn: Button, icon_type: String) -> TextureRect:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center)

	var icon := TextureRect.new()
	icon.name = "HudIcon"
	icon.texture = UiIconDrawer.get_icon_texture(icon_type, _selected_color)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(54.0, 54.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	return icon


func _make_tray_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_TRAY_BG
	style.border_color = COLOR_TRAY_BORDER
	style.set_border_width_all(2)
	style.border_width_bottom = 5
	style.set_corner_radius_all(TRAY_CORNER_RADIUS)
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_palette_container_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.955, 0.938, 0.902, 0.88)
	style.border_color = COLOR_CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(PALETTE_CONTAINER_CORNER_RADIUS)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _make_icon_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.962, 0.946, 0.912, 0.92)
	style.border_color = Color(0.89, 0.85, 0.78, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(ICON_BADGE_CORNER_RADIUS)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _make_card_style(is_selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_SELECTED_BG if is_selected else COLOR_CARD_BG
	style.border_color = COLOR_CARD_SELECTED_BORDER if is_selected else COLOR_CARD_BORDER
	style.set_border_width_all(3 if is_selected else 2)
	style.border_width_bottom = 6
	style.set_corner_radius_all(CARD_CORNER_RADIUS)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.08)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_swatch_button_style(
	color: Color,
	is_selected: bool,
	is_highlighted: bool
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	if is_selected:
		style.border_color = Color("#FFFFFF")
		style.set_border_width_all(3)
		style.border_width_bottom = 5
	else:
		style.border_color = COLOR_BUTTON_BORDER_ACTIVE if is_highlighted else color.darkened(0.18)
		style.set_border_width_all(2)
		style.border_width_bottom = 4
	style.set_corner_radius_all(SWATCH_CORNER_RADIUS)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.10 if is_selected else 0.05)
	style.shadow_size = 4 if is_selected else 2
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_toolbar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_TOOLBAR_BG
	style.border_color = COLOR_TOOLBAR_BORDER
	style.set_border_width_all(2)
	style.border_width_bottom = 5
	style.set_corner_radius_all(24)
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_toy_button_style(
	bg_color: Color,
	border_color: Color,
	is_pressed_state: bool = false,
	top_border_width: int = 2
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(top_border_width)
	style.border_width_bottom = 2 if is_pressed_state else 6
	style.set_corner_radius_all(BUTTON_CORNER_RADIUS)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 8 if is_pressed_state else 6
	style.content_margin_bottom = 4 if is_pressed_state else 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.08 if is_pressed_state else 0.12)
	style.shadow_size = 2 if is_pressed_state else 4
	style.shadow_offset = Vector2(0, 2 if is_pressed_state else 3)
	return style
