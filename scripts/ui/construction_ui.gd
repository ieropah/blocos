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
signal category_selected(category_id: String)
signal color_selected(color_id: String, color: Color)
signal rotate_piece_pressed
signal delete_piece_pressed
signal undo_pressed
signal redo_pressed
signal gallery_pressed
signal home_pressed
signal home_requested
signal theme_cycle_requested(theme_id: String)
signal tool_selected(tool_name: String)
signal studio_bg_changed(bg_color: Color)

const CameraController = preload("res://scripts/controllers/camera_controller.gd")
const DevTuningPanel = preload("res://scripts/ui/dev_tuning_panel.gd")
const ThemeVisuals = preload("res://scripts/visuals/theme_visuals.gd")
const UiIconDrawer = preload("res://scripts/visuals/ui_icon_drawer.gd")

const TRAY_WIDTH_PX := 160.0
const TRAY_HEIGHT_PX := 656.0
const TOOLBAR_SAFE_MARGIN := 24
const BUTTON_MIN_SIZE := Vector2(96.0, 96.0)
const EDITING_BUTTON_MIN_SIZE := Vector2(96.0, 96.0)
const PALETTE_HEIGHT_PX := 70.0
const STUDIO_BG_BUTTON_SIZE := Vector2(54.0, 54.0)
const STUDIO_BG_COLORS: Array[Color] = [
	Color("#5CC2F2"),
	Color("#F3E6D3"),
	Color("#A8E6CF"),
	Color("#D4C4FB"),
	Color("#FFD3B6"),
	Color("#DCE4EC"),
]
const BUTTON_CORNER_RADIUS := 22
const TRAY_CORNER_RADIUS := 28
const CARD_CORNER_RADIUS := 18
const SWATCH_CORNER_RADIUS := 22
const PALETTE_CONTAINER_CORNER_RADIUS := 35
const ICON_BADGE_CORNER_RADIUS := 16
const ZOOM_BUTTON_STEP := 1.25
const THEME_CYCLE_ORDER: Array[String] = ["plastic", "voxel", "wood"]

const COLOR_TRAY_BG := Color("#F7F1E5")
const COLOR_TRAY_BORDER := Color("#D8CBB8")
const COLOR_CARD_BG := Color("#FFFFFF")
const COLOR_CARD_SELECTED_BG := Color("#FFF8DC")
const COLOR_CARD_BORDER := Color("#E5DDD0")
const COLOR_CARD_SELECTED_BORDER := Color("#FFBE0B")
const COLOR_TOOL_SELECTED_BG := Color("#E3F2FD")
const COLOR_TOOL_SELECTED_BORDER := Color("#2196F3")
const COLOR_TOOLBAR_BG := Color("#F7F1E5")
const COLOR_TOOLBAR_BORDER := Color("#D8CBB8")
const COLOR_TEXT_PRIMARY := Color(0.20, 0.19, 0.18, 1.0)
const COLOR_TEXT_MUTED := Color(0.49, 0.46, 0.42, 1.0)
const COLOR_BUTTON_NORMAL := Color("#FFFFFF")
const COLOR_BUTTON_HOVER := Color("#FFFDF9")
const COLOR_BUTTON_PRESSED := Color("#F5EFE6")
const COLOR_BUTTON_DISABLED := Color("#F7F1E5")
const COLOR_BUTTON_BORDER := Color("#D8CBB8")
const COLOR_BUTTON_BORDER_ACTIVE := Color("#C8BEB0")
const COLOR_BUTTON_BORDER_DISABLED := Color("#D8CBB8")
const COLOR_TEXT_DISABLED := Color(0.60, 0.57, 0.52, 0.75)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.14)

const COLOR_OPTIONS: Array[Dictionary] = [
	{"id": "coral_red", "name": "Vermelho Coral", "color": Color("#EF476F")},
	{"id": "bright_red", "name": "Vermelho Vivo", "color": Color("#E63946")},
	{"id": "tangerine", "name": "Laranja", "color": Color("#F77F00")},
	{"id": "sunny_yellow", "name": "Amarelo Sol", "color": Color("#FFD166")},
	{"id": "lime_green", "name": "Verde Limão", "color": Color("#80ED99")},
	{"id": "sage_green", "name": "Verde Sálvia", "color": Color("#06D6A0")},
	{"id": "sky_blue", "name": "Azul Céu", "color": Color("#4EA8DE")},
	{"id": "cobalt_blue", "name": "Azul Cobalto", "color": Color("#118AB2")},
	{"id": "plum_purple", "name": "Roxo", "color": Color("#9B5DE5")},
	{"id": "bubblegum_pink", "name": "Rosa Chiclete", "color": Color("#F15BB5")},
	{"id": "warm_brown", "name": "Marrom", "color": Color("#A1623B")},
	{"id": "cream_white", "name": "Branco", "color": Color("#F8FAFC")},
	{"id": "obsidian_black", "name": "Preto", "color": Color("#111111")},
]

const PREVIEW_PIECES: Array[Dictionary] = [
	{"id": "cube", "name": "Cubo", "color": Color("#EF476F"), "category": "basic"},
	{"id": "long_block", "name": "Bloco Longo", "color": Color("#118AB2"), "category": "basic"},
	{"id": "square_plate", "name": "Placa", "color": Color("#06D6A0"), "category": "basic"},
	{"id": "ramp", "name": "Rampa", "color": Color("#F77F00"), "category": "basic"},
]

const CATEGORY_TABS: Array[Dictionary] = [
	{"id": "basic", "icon": "cat_basic", "tooltip": "Blocos Básicos", "color": Color("#4EA8DE"), "border": Color("#2E86B8")},
	{"id": "building", "icon": "cat_building", "tooltip": "Construção", "color": Color("#E63946"), "border": Color("#B82532")},
	{"id": "creature", "icon": "cat_creature", "tooltip": "Criaturas", "color": Color("#FFBE0B"), "border": Color("#D99B00")},
	{"id": "vehicle", "icon": "cat_vehicle", "tooltip": "Veículos", "color": Color("#4CC947"), "border": Color("#349E30")},
]

const MODE_DEFAULT_CATEGORIES: Dictionary = {
	"character": "creature",
	"animal": "creature",
	"vehicle": "vehicle",
	"scenery": "building",
}


class ShapeIcon extends TextureRect:
	var shape_id: String = "cube"
	var fill_color: Color = Color("#EF476F")
	var active_theme_id: String = "plastic"

	func _ready() -> void:
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_refresh_texture()

	func set_icon_color(color: Color, theme_id: String = active_theme_id) -> void:
		fill_color = color
		active_theme_id = theme_id
		_refresh_texture()

	func _refresh_texture() -> void:
		UiIconDrawer.request_piece_3d_thumbnail(shape_id, fill_color, active_theme_id, self)


class GlossyColorDot extends Button:
	var swatch_color: Color = Color("#EF476F")
	var is_selected: bool = false

	func _ready() -> void:
		text = ""
		flat = true
		var empty_style := StyleBoxEmpty.new()
		add_theme_stylebox_override("normal", empty_style)
		add_theme_stylebox_override("hover", empty_style)
		add_theme_stylebox_override("pressed", empty_style)
		add_theme_stylebox_override("focus", empty_style)
		add_theme_stylebox_override("disabled", empty_style)

	func set_selected(selected: bool) -> void:
		if is_selected != selected:
			is_selected = selected
			queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var outer_r: float = minf(size.x, size.y) * 0.5 - 2.0
		if is_selected:
			draw_circle(center, outer_r + 1.5, Color("#1E293B"))
			draw_circle(center, outer_r - 1.5, Color("#FFBE0B"))
		draw_circle(center, outer_r - (4.5 if is_selected else 1.5), Color(1.0, 1.0, 1.0, 0.92))
		var body_r: float = outer_r - (7.0 if is_selected else 4.0)
		draw_circle(center, body_r, swatch_color)
		# Top-left glossy highlight dot
		draw_circle(center + Vector2(-body_r * 0.34, -body_r * 0.34), maxf(body_r * 0.24, 2.5), Color(1.0, 1.0, 1.0, 0.65))


var _root: Control = null
var _drawer_assembly: HBoxContainer = null
var _tray_panel: PanelContainer = null
var _category_tabs_container: VBoxContainer = null
var _palette_container: PanelContainer = null
var _studio_bg_button: Button = null
var _studio_bg_divider: ColorRect = null
var _studio_bg_index: int = 0
var _studio_bg_colors: Array[Color] = STUDIO_BG_COLORS.duplicate()
var _runtime_color_options: Array[Dictionary] = []
var _toolbar_area: MarginContainer = null
var _dev_tuning_panel: DevTuningPanel = null
var _tray_width_px: float = TRAY_WIDTH_PX
var _tray_card_height_px: float = 108.0
var _right_button_size_px: float = 96.0
var _palette_height_px: float = PALETTE_HEIGHT_PX
var _icon_padding_px: float = 14.0
var _cards_box: GridContainer = null
var _top_bar_panel: PanelContainer = null
var _gallery_button: Button = null
var _home_button: Button = null
var _home_confirm_badge: PanelContainer = null
var _home_confirm_pending: bool = false
var _home_confirm_token: int = 0
var _home_bounce_tween: Tween = null
var _theme_button: Button = null
var _active_project_label: Label = null
var _active_project_name: String = "Construção Inicial"
var _editing_toolbar_panel: PanelContainer = null
var _tool_toolbar_panel: PanelContainer = null
var _toolbar_panel: PanelContainer = null
var _category_buttons: Dictionary = {}
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
var _active_category: String = "basic"
var _active_mode_id: String = ""
var _cached_catalog_pieces: Array[Dictionary] = []
var _tab_tween: Tween = null
var _bound_controller: CameraController = null
var _bound_connections: Array[Dictionary] = []


func _ready() -> void:
	ensure_setup()


## Builds the responsive UI hierarchy once. Safe to call before or after _ready().
func ensure_setup() -> void:
	if _root != null and is_instance_valid(_root):
		return

	if _runtime_color_options.is_empty():
		for entry: Dictionary in COLOR_OPTIONS:
			_runtime_color_options.append(entry.duplicate())

	_root = Control.new()
	_root.name = "UIRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	_build_tray_panel(_root)
	_build_toolbar_panel(_root)
	_dev_tuning_panel = DevTuningPanel.new()
	_root.add_child(_dev_tuning_panel)
	_dev_tuning_panel.bind(self)
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


## Sets the active play mode ("character", "animal", "vehicle", "scenery") and selects its default category tab.
func set_mode(mode_id: String) -> void:
	ensure_setup()
	_active_mode_id = mode_id
	var default_cat: String = str(MODE_DEFAULT_CATEGORIES.get(mode_id, "basic"))
	select_category(default_cat, false)


func get_active_mode_id() -> String:
	return _active_mode_id


## Selects a piece category tab ("basic", "building", "creature", "vehicle") and filters the tray.
func select_category(category_id: String, animate: bool = true) -> void:
	ensure_setup()
	var valid: bool = false
	for spec: Dictionary in CATEGORY_TABS:
		if str(spec["id"]) == category_id:
			valid = true
			break
	if not valid:
		return

	_active_category = category_id
	_refresh_category_tabs(animate)
	_rebuild_tray_cards()
	_refresh_palette_visibility()
	category_selected.emit(category_id)


func get_active_category() -> String:
	ensure_setup()
	return _active_category


func get_category_buttons() -> Dictionary:
	ensure_setup()
	return _category_buttons.duplicate()


## Filters the left piece sidebar to pieces allowed for the active theme and refreshes thumbnails.
func set_active_theme(theme_id: String, catalog_pieces: Array = [], grid_size: int = -1) -> void:
	ensure_setup()
	if _active_theme_id != theme_id:
		ToyMeshBuilder.clear_cache()
		UiIconDrawer.clear_cache()
	_active_theme_id = theme_id
	if grid_size > 0:
		_active_grid_size = grid_size

	var source_pieces: Array = catalog_pieces
	if source_pieces.is_empty():
		source_pieces = PieceCatalog.get_pieces_for_theme(theme_id, _active_grid_size)
	if source_pieces.is_empty():
		source_pieces = PREVIEW_PIECES

	_cached_catalog_pieces.clear()
	for entry: Variant in source_pieces:
		if entry is Dictionary:
			var dict_entry := entry as Dictionary
			var pid: String = str(dict_entry.get("id", ""))
			if not pid.is_empty():
				var cat: String = str(dict_entry.get("category", ""))
				if cat.is_empty():
					cat = _infer_piece_category(pid)
				_cached_catalog_pieces.append({
					"id": pid,
					"name": str(dict_entry.get("name", pid)),
					"category": cat,
				})
		elif entry is String:
			var pid_str: String = entry as String
			if not pid_str.is_empty():
				_cached_catalog_pieces.append({
					"id": pid_str,
					"name": pid_str,
					"category": _infer_piece_category(pid_str),
				})

	if _cached_catalog_pieces.is_empty():
		_cached_catalog_pieces = PREVIEW_PIECES.duplicate()

	_refresh_category_tabs(false)
	_rebuild_tray_cards()
	_refresh_palette_visibility()
	if _studio_bg_button != null and is_instance_valid(_studio_bg_button):
		_studio_bg_button.visible = (_active_theme_id == "solid")
	if _studio_bg_divider != null and is_instance_valid(_studio_bg_divider):
		_studio_bg_divider.visible = (_active_theme_id == "solid")
	if _active_theme_id == "solid":
		_apply_studio_bg_to_platform(_studio_bg_colors[_studio_bg_index])


func _rebuild_tray_cards() -> void:
	var filtered_pieces: Array[Dictionary] = []
	for piece: Dictionary in _cached_catalog_pieces:
		if _active_theme_id == "solid" or str(piece.get("category", "basic")) == _active_category:
			filtered_pieces.append(piece)
	if filtered_pieces.is_empty():
		filtered_pieces = _cached_catalog_pieces.duplicate()

	if _cards_box != null and is_instance_valid(_cards_box):
		for child: Node in _cards_box.get_children():
			_cards_box.remove_child(child)
			child.queue_free()

		_tray_cards.clear()
		_shape_icons.clear()
		for piece: Dictionary in filtered_pieces:
			_cards_box.add_child(_create_preview_card(piece))

		if not _tray_cards.has(_selected_shape_id) and not _tray_cards.is_empty():
			_selected_shape_id = str(_tray_cards.keys()[0])

		_refresh_shape_cards()
		_refresh_shape_icons()


func _refresh_palette_visibility() -> void:
	var show_paint_ui: bool = _is_piece_paintable(_selected_shape_id)
	if _palette_container != null and is_instance_valid(_palette_container):
		_palette_container.visible = show_paint_ui
	var paint_btn: Button = _tool_buttons.get("paint") as Button
	if paint_btn != null and is_instance_valid(paint_btn):
		paint_btn.visible = show_paint_ui
	if not show_paint_ui and _selected_tool == "paint":
		select_tool("build")


func _is_piece_paintable(piece_id: String) -> bool:
	if _active_theme_id != "voxel":
		return true
	if _active_grid_size <= 8 or _active_category == "creature":
		return true
	return ToyMeshBuilder.is_tintable_voxel_piece(piece_id)


static func _infer_piece_category(piece_id: String) -> String:
	if piece_id in [
		"plastic_eye", "plastic_mouth_smile", "plastic_snout",
		"plastic_ears", "plastic_paw", "plastic_crown_hat",
		"voxel_eye", "voxel_mouth", "voxel_eye_cute", "voxel_eye_angry",
		"voxel_glasses", "voxel_mouth_smile", "voxel_snout", "voxel_ears",
		"voxel_belly", "voxel_hair_crown",
	]:
		return "creature"
	if piece_id in [
		"wheel_axle", "windshield", "headlight_bumper",
		"wing_fin", "steering_wheel", "propeller_block", "siren_light",
	]:
		return "vehicle"
	if piece_id in [
		"roof_gable", "arch_bridge", "corner_block",
		"window_block", "door_block", "fence_rail",
		"voxel_brick", "voxel_roof", "voxel_glass", "voxel_door",
		"voxel_window", "voxel_fence", "voxel_stairs", "voxel_pillar",
		"voxel_corner", "voxel_plank", "voxel_cobble", "voxel_stone",
		"voxel_wood", "voxel_leaves", "voxel_grass", "voxel_dirt",
		"voxel_sand", "voxel_water", "voxel_gold", "voxel_wool",
		"voxel_wool_slab",
	]:
		return "building"
	return "basic"


func get_active_theme_id() -> String:
	return _active_theme_id


## Wires toolbar signals to the given CameraController, replacing any prior binding.
func bind_camera_controller(controller: CameraController) -> void:
	ensure_setup()
	_disconnect_bound_controller()

	if controller == null or not is_instance_valid(controller):
		return

	_bound_controller = controller
	if _dev_tuning_panel != null and is_instance_valid(_dev_tuning_panel):
		_dev_tuning_panel.sync_camera_controller(controller)
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


## Returns true if the given screen coordinate lies within the left tray panel or its binder tabs.
func is_screen_point_in_tray(screen_pos: Vector2) -> bool:
	ensure_setup()
	return (
		(_drawer_assembly != null and is_instance_valid(_drawer_assembly) and _drawer_assembly.get_global_rect().has_point(screen_pos))
		or (_tray_panel != null and is_instance_valid(_tray_panel) and _tray_panel.get_global_rect().has_point(screen_pos))
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
		for entry: Dictionary in _runtime_color_options:
			if str(entry["id"]) == requested_id:
				matched_id = requested_id
				matched_color = entry["color"] as Color
				break
		if matched_id.is_empty():
			return
	elif color_id_or_color is Color:
		var requested_color: Color = color_id_or_color as Color
		matched_color = requested_color
		for entry: Dictionary in _runtime_color_options:
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
	_refresh_palette_visibility()
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
				btn.modulate.a = 1.0
		if _button_icons.has(btn_name):
			var icon := _button_icons[btn_name] as TextureRect
			if icon != null and is_instance_valid(icon):
				icon.modulate.a = 1.0 if is_selected else 0.55


## Enables or disables the Undo and Redo buttons based on history availability.
func set_history_state(can_undo: bool, can_redo: bool) -> void:
	ensure_setup()
	if _editing_buttons.has("UndoButton"):
		var undo_btn := _editing_buttons["UndoButton"] as Button
		if undo_btn != null and is_instance_valid(undo_btn):
			undo_btn.disabled = not can_undo
			undo_btn.modulate.a = 1.0
		if _button_icons.has("UndoButton"):
			var undo_icon := _button_icons["UndoButton"] as TextureRect
			if undo_icon != null and is_instance_valid(undo_icon):
				undo_icon.modulate.a = 1.0 if can_undo else 0.55
	if _editing_buttons.has("RedoButton"):
		var redo_btn := _editing_buttons["RedoButton"] as Button
		if redo_btn != null and is_instance_valid(redo_btn):
			redo_btn.disabled = not can_redo
			redo_btn.modulate.a = 1.0
		if _button_icons.has("RedoButton"):
			var redo_icon := _button_icons["RedoButton"] as TextureRect
			if redo_icon != null and is_instance_valid(redo_icon):
				redo_icon.modulate.a = 1.0 if can_redo else 0.55


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
	if (
		_dev_tuning_panel != null
		and is_instance_valid(_dev_tuning_panel)
		and _dev_tuning_panel.visible
		and _dev_tuning_panel.get_global_rect().has_point(screen_pos)
	):
		return true
	if is_screen_point_in_tray(screen_pos):
		return true
	if (
		_studio_bg_button != null
		and is_instance_valid(_studio_bg_button)
		and _studio_bg_button.visible
		and _studio_bg_button.get_global_rect().has_point(screen_pos)
	):
		return true
	for panel: PanelContainer in [_palette_container, _top_bar_panel, _tool_toolbar_panel, _editing_toolbar_panel, _toolbar_panel]:
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
	_drawer_assembly = HBoxContainer.new()
	_drawer_assembly.name = "LeftDrawerAssembly"
	_drawer_assembly.anchor_left = 0.0
	_drawer_assembly.anchor_right = 0.0
	_drawer_assembly.anchor_top = 0.5
	_drawer_assembly.anchor_bottom = 0.5
	_drawer_assembly.offset_left = 16.0
	_drawer_assembly.offset_top = -TRAY_HEIGHT_PX * 0.5
	_drawer_assembly.offset_right = 16.0 + TRAY_WIDTH_PX + 72.0
	_drawer_assembly.offset_bottom = TRAY_HEIGHT_PX * 0.5
	_drawer_assembly.add_theme_constant_override("separation", 0)
	_drawer_assembly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_drawer_assembly)

	_tray_panel = PanelContainer.new()
	_tray_panel.name = "TrayPanel"
	_tray_panel.custom_minimum_size = Vector2(TRAY_WIDTH_PX, TRAY_HEIGHT_PX)
	_tray_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tray_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_tray_panel.add_theme_stylebox_override("panel", _make_tray_style())
	_drawer_assembly.add_child(_tray_panel)

	var margin := MarginContainer.new()
	margin.name = "TrayMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_tray_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "TrayColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var scroll := ScrollContainer.new()
	scroll.name = "PreviewScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(scroll)

	_cards_box = GridContainer.new()
	_cards_box.name = "PreviewCards"
	_cards_box.columns = 1
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_box.add_theme_constant_override("h_separation", 10)
	_cards_box.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_cards_box)

	var tabs_margin := MarginContainer.new()
	tabs_margin.name = "BinderTabsMargin"
	tabs_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tabs_margin.add_theme_constant_override("margin_top", 24)
	tabs_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer_assembly.add_child(tabs_margin)

	_category_tabs_container = VBoxContainer.new()
	_category_tabs_container.name = "CategoryTabsBar"
	_category_tabs_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_category_tabs_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_category_tabs_container.add_theme_constant_override("separation", 8)
	tabs_margin.add_child(_category_tabs_container)

	_category_buttons.clear()
	for tab_spec: Dictionary in CATEGORY_TABS:
		var cat_id: String = str(tab_spec["id"])
		var tab_btn := _create_category_tab_button(tab_spec)
		_category_tabs_container.add_child(tab_btn)
		_category_buttons[cat_id] = tab_btn
	_refresh_category_tabs(false)

	_tray_cards.clear()
	_shape_icons.clear()
	for piece: Dictionary in PREVIEW_PIECES:
		_cards_box.add_child(_create_preview_card(piece))

	_refresh_shape_cards()
	_refresh_shape_icons()


func _on_home_button_pressed() -> void:
	if _home_confirm_pending:
		_reset_home_confirm()
		home_pressed.emit()
		return

	_home_confirm_pending = true
	_home_confirm_token += 1
	var token: int = _home_confirm_token

	if _home_confirm_badge != null and is_instance_valid(_home_confirm_badge):
		_home_confirm_badge.visible = true
	if _home_button != null and is_instance_valid(_home_button):
		_home_button.add_theme_stylebox_override("normal", _make_toy_button_style(Color("#FEE2E2"), Color("#EF4444"), false, 2))
		_home_button.add_theme_stylebox_override("hover", _make_toy_button_style(Color("#FECACA"), Color("#DC2626"), false, 2))
		if is_inside_tree():
			if _home_bounce_tween != null and _home_bounce_tween.is_valid():
				_home_bounce_tween.kill()
			_home_button.scale = Vector2(0.86, 0.86)
			_home_bounce_tween = create_tween()
			_home_bounce_tween.set_trans(Tween.TRANS_BACK)
			_home_bounce_tween.set_ease(Tween.EASE_OUT)
			_home_bounce_tween.tween_property(_home_button, "scale", Vector2(1.08, 1.08), 0.12)
			_home_bounce_tween.tween_property(_home_button, "scale", Vector2.ONE, 0.12)

	if is_inside_tree():
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(func() -> void:
			if _home_confirm_token == token:
				_reset_home_confirm()
		)


func _reset_home_confirm() -> void:
	_home_confirm_pending = false
	if _home_confirm_badge != null and is_instance_valid(_home_confirm_badge):
		_home_confirm_badge.visible = false
	if _home_button != null and is_instance_valid(_home_button):
		_home_button.add_theme_stylebox_override("normal", _make_toy_button_style(COLOR_BUTTON_NORMAL, COLOR_BUTTON_BORDER, false, 2))
		_home_button.add_theme_stylebox_override("hover", _make_toy_button_style(COLOR_BUTTON_HOVER, COLOR_BUTTON_BORDER_ACTIVE, false, 2))


func _on_theme_button_pressed() -> void:
	var idx: int = THEME_CYCLE_ORDER.find(_active_theme_id)
	var next_idx: int = (idx + 1) % THEME_CYCLE_ORDER.size() if idx >= 0 else 0
	var next_theme: String = THEME_CYCLE_ORDER[next_idx]
	set_active_theme(next_theme, [], _active_grid_size)
	theme_cycle_requested.emit(next_theme)


func _create_section_label(node_name: String, label_text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	return label


func _create_color_button(color_id: String, color_name: String, swatch_color: Color) -> Button:
	var btn := GlossyColorDot.new()
	btn.name = "ColorButton_" + color_id
	btn.tooltip_text = color_name
	btn.swatch_color = swatch_color
	btn.custom_minimum_size = Vector2(46.0, 46.0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_meta("color_id", color_id)
	btn.set_meta("swatch_color", swatch_color)
	btn.pressed.connect(func() -> void: select_color(color_id))
	return btn


func _create_category_tab_button(tab_spec: Dictionary) -> Button:
	var cat_id: String = str(tab_spec["id"])
	var btn := Button.new()
	btn.name = "CategoryTab_" + cat_id
	btn.text = ""
	btn.tooltip_text = str(tab_spec["tooltip"])
	btn.custom_minimum_size = Vector2(58.0, 68.0)
	btn.pivot_offset = Vector2(0.0, 34.0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_meta("category_id", cat_id)
	btn.set_meta("tab_bg", tab_spec["color"])
	btn.set_meta("tab_border", tab_spec["border"])
	btn.pressed.connect(func() -> void: select_category(cat_id, true))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center)

	var icon := TextureRect.new()
	icon.texture = UiIconDrawer.get_icon_texture(str(tab_spec["icon"]))
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)

	return btn


func _make_binder_tab_style(bg_color: Color, border_color: Color, is_pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 0
	style.border_width_top = 2
	style.border_width_right = 3
	style.border_width_bottom = 3 if is_pressed else 6
	style.corner_radius_top_left = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = 5
	style.shadow_offset = Vector2(2, 3)
	return style


func _refresh_category_tabs(animate: bool = false) -> void:
	var show_tabs: bool = (_active_theme_id != "solid")
	if _category_tabs_container != null and is_instance_valid(_category_tabs_container):
		_category_tabs_container.visible = show_tabs
		var tabs_parent := _category_tabs_container.get_parent() as Control
		if tabs_parent != null:
			tabs_parent.visible = show_tabs
	if not show_tabs:
		return

	if animate and is_inside_tree() and _tab_tween != null and _tab_tween.is_valid():
		_tab_tween.kill()
	if animate and is_inside_tree():
		_tab_tween = create_tween()
		_tab_tween.set_parallel(true)
		_tab_tween.set_trans(Tween.TRANS_BACK)
		_tab_tween.set_ease(Tween.EASE_OUT)

	for cat_id_variant: Variant in _category_buttons.keys():
		var cat_id: String = str(cat_id_variant)
		var btn := _category_buttons[cat_id] as Button
		if btn == null or not is_instance_valid(btn):
			continue
		var is_active: bool = (cat_id == _active_category)
		var tab_bg: Color = btn.get_meta("tab_bg", COLOR_BUTTON_NORMAL) as Color
		var tab_border: Color = btn.get_meta("tab_border", COLOR_BUTTON_BORDER) as Color
		var shown_bg: Color = tab_bg if is_active else tab_bg.darkened(0.08)

		btn.add_theme_stylebox_override("normal", _make_binder_tab_style(shown_bg, tab_border, false))
		btn.add_theme_stylebox_override("hover", _make_binder_tab_style(tab_bg.lightened(0.06), tab_border, false))
		btn.add_theme_stylebox_override("pressed", _make_binder_tab_style(tab_bg.darkened(0.08), tab_border, true))
		btn.add_theme_stylebox_override("focus", _make_binder_tab_style(shown_bg, tab_border, false))

		var target_w: float = 70.0 if is_active else 58.0
		if animate and is_inside_tree() and _tab_tween != null:
			_tab_tween.tween_property(btn, "custom_minimum_size:x", target_w, 0.18)
		else:
			btn.custom_minimum_size = Vector2(target_w, 68.0)


func _create_preview_card(piece: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var piece_id: String = piece["id"]
	var piece_name: String = piece["name"]

	var card_w: float = maxf(_tray_width_px - 36.0, 72.0)
	var icon_side: float = maxf(minf(card_w, _tray_card_height_px) - _icon_padding_px * 2.0, 28.0)
	card.name = piece_name.replace(" ", "") + "Card"
	card.custom_minimum_size = Vector2(card_w, _tray_card_height_px)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.set_meta("piece_id", piece_id)
	card.add_theme_stylebox_override("panel", _make_card_style(piece_id == _selected_shape_id))
	_tray_cards[piece_id] = card

	card.gui_input.connect(_on_card_gui_input.bind(card, piece_id))

	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var png_path: String = PieceCatalog.get_piece_icon_path(piece_id)
	if png_path.is_empty() or not ResourceLoader.exists(png_path):
		png_path = "res://assets/icons/%s.png" % piece_id
	if ResourceLoader.exists(png_path):
		var png_tex := load(png_path) as Texture2D
		if png_tex != null:
			var tex_icon := TextureRect.new()
			tex_icon.name = "PieceIcon"
			tex_icon.texture = png_tex
			tex_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_icon.custom_minimum_size = Vector2(icon_side, icon_side)
			tex_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(tex_icon)
			return card

	var icon := ShapeIcon.new()
	icon.name = "ShapeIcon"
	icon.shape_id = piece_id
	icon.fill_color = _selected_color
	icon.active_theme_id = _active_theme_id
	icon.custom_minimum_size = Vector2(icon_side, icon_side)
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
		var btn := _color_buttons[color_id] as GlossyColorDot
		if btn == null or not is_instance_valid(btn):
			continue
		btn.set_selected(color_id == _selected_color_id)


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
				icon.set_icon_color(Color.WHITE, _active_theme_id)
			else:
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				icon.set_icon_color(_selected_color, _active_theme_id)


func _build_toolbar_panel(parent: Control) -> void:
	var toolbar_area := MarginContainer.new()
	toolbar_area.name = "ToolbarArea"
	_toolbar_area = toolbar_area
	toolbar_area.anchor_left = 0.0
	toolbar_area.anchor_top = 0.0
	toolbar_area.anchor_right = 1.0
	toolbar_area.anchor_bottom = 1.0
	toolbar_area.offset_left = 16.0 + TRAY_WIDTH_PX + 72.0
	toolbar_area.offset_top = 0.0
	toolbar_area.offset_right = 0.0
	toolbar_area.offset_bottom = 0.0
	toolbar_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar_area.add_theme_constant_override("margin_left", 16)
	toolbar_area.add_theme_constant_override("margin_top", 16)
	toolbar_area.add_theme_constant_override("margin_right", TOOLBAR_SAFE_MARGIN)
	toolbar_area.add_theme_constant_override("margin_bottom", 16)
	parent.add_child(toolbar_area)

	var layout_col := VBoxContainer.new()
	layout_col.name = "ToolbarLayoutColumn"
	layout_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_col.add_theme_constant_override("separation", 12)
	toolbar_area.add_child(layout_col)

	# Zone 1: Top-Right Tools (Row 1: Eraser + Paint, Row 2: Undo below Paint)
	var top_right_tools := _create_top_right_tools_panel()
	layout_col.add_child(top_right_tools)

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
	bottom_row.add_theme_constant_override("separation", 12)
	layout_col.add_child(bottom_row)

	# Zone 2: Bottom Color Bar (70px height pill) with Studio Background Cycle Button inside
	_palette_container = PanelContainer.new()
	_palette_container.name = "ColorPaletteContainer"
	_palette_container.custom_minimum_size = Vector2(0.0, PALETTE_HEIGHT_PX)
	_palette_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_palette_container.size_flags_vertical = Control.SIZE_SHRINK_END
	_palette_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_palette_container.add_theme_stylebox_override("panel", _make_palette_container_style())
	bottom_row.add_child(_palette_container)

	var color_row := HBoxContainer.new()
	color_row.name = "ColorRow"
	color_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	color_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	color_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_row.add_theme_constant_override("separation", 8)
	_palette_container.add_child(color_row)

	_studio_bg_button = _create_studio_bg_button()
	color_row.add_child(_studio_bg_button)

	_studio_bg_divider = ColorRect.new()
	_studio_bg_divider.name = "StudioBgDivider"
	_studio_bg_divider.custom_minimum_size = Vector2(2.0, 36.0)
	_studio_bg_divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_studio_bg_divider.color = COLOR_TRAY_BORDER
	_studio_bg_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_studio_bg_divider.visible = (_active_theme_id == "solid")
	color_row.add_child(_studio_bg_divider)

	_color_buttons.clear()
	for entry: Dictionary in _runtime_color_options:
		var color_id: String = str(entry["id"])
		var color_name: String = str(entry["name"])
		var swatch_color: Color = entry["color"] as Color
		var swatch_btn := _create_color_button(color_id, color_name, swatch_color)
		color_row.add_child(swatch_btn)
		_color_buttons[color_id] = swatch_btn
	_refresh_color_buttons()

	var spacer := Control.new()
	spacer.name = "BottomBarSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(spacer)

	# Zone 3: Bottom-Right Action Bar (3 loose 96x96 buttons: Camera/Rotate, Trash, Home)
	var editing_specs: Array[Dictionary] = [
		{"name": "RotatePieceButton", "icon": "camera_toggle", "fallback": "rotate_piece", "tooltip": "", "signal": rotate_piece_pressed, "disabled": false},
		{"name": "DeletePieceButton", "icon": "clear_all", "fallback": "delete_piece", "tooltip": "", "signal": delete_piece_pressed, "disabled": true},
		{"name": "HomeButton", "icon": "home", "fallback": "home", "tooltip": "", "signal": home_pressed, "disabled": false},
	]
	_editing_buttons.clear()
	_editing_toolbar_panel = _create_toolbar_panel(
		"EditingToolbarPanel",
		"EditingButtons",
		editing_specs,
		EDITING_BUTTON_MIN_SIZE,
		_editing_buttons
	)
	_editing_toolbar_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if _editing_buttons.has("HomeButton"):
		_home_button = _editing_buttons["HomeButton"] as Button
	_editing_toolbar_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	bottom_row.add_child(_editing_toolbar_panel)


func _create_top_right_tools_panel() -> VBoxContainer:
	var container := VBoxContainer.new()
	container.name = "TopRightToolsContainer"
	container.size_flags_horizontal = Control.SIZE_SHRINK_END
	container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", 12)

	var row1 := HBoxContainer.new()
	row1.name = "TopRightToolsRow1"
	row1.alignment = BoxContainer.ALIGNMENT_END
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_theme_constant_override("separation", 12)
	container.add_child(row1)

	var tool_specs: Array[Dictionary] = [
		{"id": "erase", "name": "EraseToolButton", "icon": "eraser", "fallback": "erase"},
		{"id": "paint", "name": "PaintToolButton", "icon": "quick_paint", "fallback": "paint"},
	]

	_tool_buttons.clear()
	_paint_tool_icon = null
	for spec: Dictionary in tool_specs:
		var tool_id: String = str(spec["id"])
		var btn := Button.new()
		btn.name = str(spec["name"])
		btn.text = ""
		btn.expand_icon = true
		btn.custom_minimum_size = BUTTON_MIN_SIZE
		btn.pivot_offset = BUTTON_MIN_SIZE * 0.5
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func() -> void: select_tool(tool_id))

		var icon := _attach_hud_icon(btn, str(spec["icon"]), str(spec["fallback"]))
		if tool_id == "paint":
			_paint_tool_icon = icon

		row1.add_child(btn)
		_tool_buttons[tool_id] = btn

	var row2 := HBoxContainer.new()
	row2.name = "TopRightToolsRow2"
	row2.alignment = BoxContainer.ALIGNMENT_END
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(row2)

	var undo_btn := Button.new()
	undo_btn.name = "UndoButton"
	undo_btn.text = ""
	undo_btn.expand_icon = true
	undo_btn.custom_minimum_size = BUTTON_MIN_SIZE
	undo_btn.pivot_offset = BUTTON_MIN_SIZE * 0.5
	undo_btn.disabled = true
	undo_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	undo_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var undo_style := _make_toy_button_style(COLOR_BUTTON_NORMAL, COLOR_BUTTON_BORDER, false, 2)
	undo_btn.add_theme_stylebox_override("normal", undo_style)
	undo_btn.add_theme_stylebox_override("hover", _make_toy_button_style(COLOR_BUTTON_HOVER, COLOR_BUTTON_BORDER_ACTIVE, false, 2))
	undo_btn.add_theme_stylebox_override("pressed", _make_toy_button_style(COLOR_BUTTON_PRESSED, COLOR_BUTTON_BORDER_ACTIVE, true, 2))
	undo_btn.add_theme_stylebox_override("disabled", undo_style)
	undo_btn.add_theme_stylebox_override("focus", _make_toy_button_style(COLOR_BUTTON_HOVER, COLOR_BUTTON_BORDER_ACTIVE, false, 2))
	var undo_icon := _attach_hud_icon(undo_btn, "undo", "undo")
	undo_icon.modulate.a = 0.55
	_button_icons["UndoButton"] = undo_icon
	undo_btn.pressed.connect(func() -> void: undo_pressed.emit())
	row2.add_child(undo_btn)
	_editing_buttons["UndoButton"] = undo_btn

	_refresh_tool_buttons()
	return container


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
			bool(spec.get("disabled", false)),
			str(spec.get("fallback", ""))
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
	initially_disabled: bool = false,
	fallback_type: String = ""
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

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", focus_style)
	btn.add_theme_stylebox_override("disabled", normal_style)
	btn.modulate.a = 1.0

	var icon := _attach_hud_icon(btn, icon_type, fallback_type)
	icon.modulate.a = 0.55 if initially_disabled else 1.0
	_button_icons[button_name] = icon

	btn.pressed.connect(func() -> void: target_signal.emit())
	return btn


func _create_studio_bg_button() -> Button:
	var btn := Button.new()
	btn.name = "StudioBgButton"
	btn.text = ""
	btn.custom_minimum_size = STUDIO_BG_BUTTON_SIZE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.visible = (_active_theme_id == "solid")

	var icon := _attach_hud_icon(btn, "studio_bg", "studio_bg")
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	_button_icons["StudioBgButton"] = icon

	_studio_bg_button = btn
	_update_studio_bg_button_visual()
	btn.pressed.connect(_on_studio_bg_button_pressed)
	return btn


func _update_studio_bg_button_visual() -> void:
	if _studio_bg_button == null or not is_instance_valid(_studio_bg_button):
		return
	var next_idx: int = (_studio_bg_index + 1) % _studio_bg_colors.size()
	var preview_col: Color = _studio_bg_colors[next_idx]
	var normal_style := _make_toy_button_style(preview_col, Color("#FFFFFF"), false, 3)
	normal_style.set_corner_radius_all(16)
	var hover_style := _make_toy_button_style(preview_col.lightened(0.06), Color("#FFBE0B"), false, 3)
	hover_style.set_corner_radius_all(16)
	var pressed_style := _make_toy_button_style(preview_col.darkened(0.06), Color("#FFBE0B"), true, 3)
	pressed_style.set_corner_radius_all(16)

	_studio_bg_button.add_theme_stylebox_override("normal", normal_style)
	_studio_bg_button.add_theme_stylebox_override("hover", hover_style)
	_studio_bg_button.add_theme_stylebox_override("pressed", pressed_style)
	_studio_bg_button.add_theme_stylebox_override("focus", hover_style)
	_studio_bg_button.add_theme_stylebox_override("disabled", normal_style)


func _on_studio_bg_button_pressed() -> void:
	_studio_bg_index = (_studio_bg_index + 1) % _studio_bg_colors.size()
	var bg_color: Color = _studio_bg_colors[_studio_bg_index]
	_update_studio_bg_button_visual()
	_apply_studio_bg_to_platform(bg_color)
	studio_bg_changed.emit(bg_color)


func set_studio_bg_preset(index: int, color: Color, apply_immediately: bool = true) -> void:
	ensure_setup()
	if index < 0 or index >= _studio_bg_colors.size():
		return
	_studio_bg_colors[index] = color
	_update_studio_bg_button_visual()
	if apply_immediately:
		_studio_bg_index = index
		_apply_studio_bg_to_platform(color)
		studio_bg_changed.emit(color)


func set_palette_color(index: int, color: Color) -> void:
	ensure_setup()
	if index < 0 or index >= _runtime_color_options.size():
		return
	_runtime_color_options[index]["color"] = color
	var color_id: String = str(_runtime_color_options[index]["id"])
	if _color_buttons.has(color_id):
		var btn := _color_buttons[color_id] as GlossyColorDot
		if btn != null and is_instance_valid(btn):
			btn.swatch_color = color
			btn.set_meta("swatch_color", color)
			btn.queue_redraw()
	if _selected_color_id == color_id:
		_selected_color = color
		_refresh_shape_icons()
		if _paint_tool_icon != null and is_instance_valid(_paint_tool_icon):
			_paint_tool_icon.texture = UiIconDrawer.get_icon_texture("paint", _selected_color)
		color_selected.emit(_selected_color_id, _selected_color)


func apply_hud_tuning(
	tray_width: float,
	card_height: float,
	right_btn_size: float,
	palette_height: float,
	icon_padding: float
) -> void:
	ensure_setup()
	_tray_width_px = tray_width
	_tray_card_height_px = card_height
	_right_button_size_px = right_btn_size
	_palette_height_px = palette_height
	_icon_padding_px = icon_padding

	if _tray_panel != null and is_instance_valid(_tray_panel):
		_tray_panel.custom_minimum_size.x = tray_width
	if _drawer_assembly != null and is_instance_valid(_drawer_assembly):
		_drawer_assembly.offset_right = 16.0 + tray_width + 72.0
	if _toolbar_area != null and is_instance_valid(_toolbar_area):
		_toolbar_area.offset_left = 16.0 + tray_width + 72.0

	var card_w: float = maxf(tray_width - 36.0, 72.0)
	for card_var: Variant in _tray_cards.values():
		var card := card_var as PanelContainer
		if card != null and is_instance_valid(card):
			card.custom_minimum_size = Vector2(card_w, card_height)

	var shape_icon_side: float = maxf(minf(card_w, card_height) - icon_padding * 2.0, 28.0)
	for icon_var: Variant in _shape_icons.values():
		var icon := icon_var as Control
		if icon != null and is_instance_valid(icon):
			icon.custom_minimum_size = Vector2(shape_icon_side, shape_icon_side)

	var right_sz := Vector2(right_btn_size, right_btn_size)
	for btn_var: Variant in _tool_buttons.values():
		var btn := btn_var as Button
		if btn != null and is_instance_valid(btn):
			btn.custom_minimum_size = right_sz
			btn.pivot_offset = right_sz * 0.5
	for btn_var: Variant in _editing_buttons.values():
		var btn := btn_var as Button
		if btn != null and is_instance_valid(btn):
			btn.custom_minimum_size = right_sz
			btn.pivot_offset = right_sz * 0.5

	var hud_icon_side: float = maxf(right_btn_size - icon_padding * 2.0, 24.0)
	for key_var: Variant in _button_icons.keys():
		var key: String = str(key_var)
		var hud_icon := _button_icons[key] as Control
		if hud_icon == null or not is_instance_valid(hud_icon):
			continue
		if key == "StudioBgButton":
			var bg_icon_side: float = maxf(palette_height - icon_padding * 2.0, 20.0)
			hud_icon.custom_minimum_size = Vector2(bg_icon_side, bg_icon_side)
		else:
			hud_icon.custom_minimum_size = Vector2(hud_icon_side, hud_icon_side)

	if _palette_container != null and is_instance_valid(_palette_container):
		_palette_container.custom_minimum_size.y = palette_height
	if _studio_bg_button != null and is_instance_valid(_studio_bg_button):
		var bg_btn_side: float = maxf(palette_height - 16.0, 40.0)
		_studio_bg_button.custom_minimum_size = Vector2(bg_btn_side, bg_btn_side)


func _apply_studio_bg_to_platform(bg_color: Color) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	_propagate_studio_bg(tree.root, bg_color)


func _propagate_studio_bg(node: Node, bg_color: Color) -> void:
	if node.has_method("set_studio_background_color"):
		node.call("set_studio_background_color", bg_color)
	elif node.has_method("set_studio_bg_color"):
		node.call("set_studio_bg_color", bg_color)
	for child: Node in node.get_children():
		_propagate_studio_bg(child, bg_color)


func _load_icon_texture(icon_key: String, fallback_type: String = "") -> Texture2D:
	var png_path: String = "res://assets/icons/%s.png" % icon_key
	if ResourceLoader.exists(png_path):
		var loaded := load(png_path) as Texture2D
		if loaded != null:
			return loaded
	var drawer_key: String = fallback_type if not fallback_type.is_empty() else icon_key
	return UiIconDrawer.get_icon_texture(drawer_key, _selected_color)


func _attach_hud_icon(btn: Button, icon_type: String, fallback_type: String = "") -> TextureRect:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center)

	var icon := TextureRect.new()
	icon.name = "HudIcon"
	icon.texture = _load_icon_texture(icon_type, fallback_type)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(52.0, 52.0)
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
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_palette_container_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_TRAY_BG
	style.border_color = COLOR_TRAY_BORDER
	style.set_border_width_all(2)
	style.border_width_bottom = 5
	style.set_corner_radius_all(PALETTE_CONTAINER_CORNER_RADIUS)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
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
