class_name HomeScreen
extends CanvasLayer
## Playful World Portal home screen for 5-year-olds.
## Features a world-tinted background with 0.25s cross-fade, two giant tactile
## size cards (8x8 character and 16x16 scenery), a 3-world selector pill, and
## a prominent Saved Creations Gallery button.

signal project_started(grid_size: int, theme_id: String)
signal start_new_project_requested(grid_size: int, theme_id: String)
signal mode_started(mode_id: String, grid_size: int, theme_id: String, initial_category: String)
signal gallery_pressed
signal open_gallery_requested
signal theme_changed(theme_id: String)

const UiIconDrawer = preload("res://scripts/visuals/ui_icon_drawer.gd")

const FADE_DURATION_SEC: float = 0.25
const BG_CROSSFADE_DURATION_SEC: float = 0.3

const THEME_BACKGROUND_PATHS: Dictionary = {
	"plastic": "res://assets/backgrounds/bg_theme_plastic.jpg",
	"voxel": "res://assets/backgrounds/bg_theme_voxel.jpg",
	"wood": "res://assets/backgrounds/bg_theme_wood.jpg",
}

const WORLD_THEMES: Dictionary = {
	"plastic": {
		"label": "Plástico",
		"bg_color": Color("#3B73B5"),
		"card_bg": Color("#FFFDF9"),
		"card_border": Color("#93C5FD"),
		"card_accent": Color("#3B82F6"),
		"pill_color": Color("#60A5FA"),
		"curtain_color": Color("#FFB74D"),
	},
	"solid": {
		"label": "Sólido",
		"bg_color": Color("#08C6F7"),
		"card_bg": Color("#F8FEFF"),
		"card_border": Color("#7DD3FC"),
		"card_accent": Color("#0284C7"),
		"pill_color": Color("#38BDF8"),
		"curtain_color": Color("#08C6F7"),
	},
	"voxel": {
		"label": "Voxel",
		"bg_color": Color("#4A8B5B"),
		"card_bg": Color("#F7FEF9"),
		"card_border": Color("#86EFAC"),
		"card_accent": Color("#22C55E"),
		"pill_color": Color("#4ADE80"),
		"curtain_color": Color("#4FC3F7"),
	},
	"wood": {
		"label": "Madeira",
		"bg_color": Color("#C88A55"),
		"card_bg": Color("#FFF9F0"),
		"card_border": Color("#FCD34D"),
		"card_accent": Color("#D97706"),
		"pill_color": Color("#FBBF24"),
		"curtain_color": Color("#A1623B"),
	},
}

const WORLD_ORDER: Array[String] = ["plastic", "solid", "voxel", "wood"]

const MODE_DEFINITIONS: Array[Dictionary] = [
	{
		"mode_id": "character",
		"node_name": "CharacterCard",
		"title": "Boneco",
		"icon": "mode_character",
		"grid_size": 8,
		"size_text": "8x8",
		"grid_divisions": 3,
		"initial_category": "creature",
	},
	{
		"mode_id": "animal",
		"node_name": "AnimalCard",
		"title": "Bichinho",
		"icon": "mode_animal",
		"grid_size": 8,
		"size_text": "8x8",
		"grid_divisions": 3,
		"initial_category": "creature",
	},
	{
		"mode_id": "vehicle",
		"node_name": "VehicleCard",
		"title": "Veículo",
		"icon": "mode_vehicle",
		"grid_size": 12,
		"size_text": "12x12",
		"grid_divisions": 4,
		"initial_category": "vehicle",
	},
	{
		"mode_id": "scenery",
		"node_name": "SceneryCard",
		"title": "Cenário",
		"icon": "mode_scenery",
		"grid_size": 16,
		"size_text": "16x16",
		"grid_divisions": 5,
		"initial_category": "building",
	},
]


class MiniGridBadge extends Control:
	var grid_divisions: int = 4
	var badge_text: String = "8x8"
	var accent_color: Color = Color("#3B82F6")

	func _draw() -> void:
		var box_size: float = 28.0
		var start_x: float = 6.0
		var start_y: float = (size.y - box_size) * 0.5
		var cell: float = box_size / float(grid_divisions)
		var gap: float = 1.5
		for gy in range(grid_divisions):
			for gx in range(grid_divisions):
				var rect := Rect2(
					start_x + float(gx) * cell + gap * 0.5,
					start_y + float(gy) * cell + gap * 0.5,
					maxf(cell - gap, 1.5),
					maxf(cell - gap, 1.5)
				)
				draw_rect(rect, accent_color)


var _root: Control = null
var _bg_rect: ColorRect = null
var _bg_tex_a: TextureRect = null
var _bg_tex_b: TextureRect = null
var _active_bg_layer_is_a: bool = true
var _center_column: VBoxContainer = null
var _character_card: Button = null
var _animal_card: Button = null
var _vehicle_card: Button = null
var _scenery_card: Button = null
var _mode_cards: Array[Button] = []
var _mode_badges: Array[MiniGridBadge] = []
var _character_badge: MiniGridBadge = null
var _scenery_badge: MiniGridBadge = null
var _scenery_size_label: Label = null
var _world_buttons: Dictionary = {}
var _gallery_button: Button = null
var _active_theme_id: String = "plastic"
var _selected_mode_id: String = "character"
var _selected_initial_category: String = "creature"
var _bg_tween: Tween = null
var _pulse_tween: Tween = null
var _transition_layer: CanvasLayer = null
var _transition_curtain: ColorRect = null
var _curtain_tween: Tween = null


func _ready() -> void:
	ensure_setup()


## Builds the Home Screen UI hierarchy once. Safe to call before or after _ready().
func ensure_setup() -> void:
	if _root != null and is_instance_valid(_root):
		return

	layer = 5
	_root = Control.new()
	_root.name = "HomeScreenRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_bg_rect = ColorRect.new()
	_bg_rect.name = "WorldBackdrop"
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = (WORLD_THEMES[_active_theme_id]["bg_color"] as Color)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg_rect)

	_bg_tex_a = _create_bg_texture_layer("WorldBackgroundA")
	_root.add_child(_bg_tex_a)
	_bg_tex_b = _create_bg_texture_layer("WorldBackgroundB")
	_root.add_child(_bg_tex_b)

	var center_box := CenterContainer.new()
	center_box.name = "PortalCenter"
	center_box.anchor_left = 0.0
	center_box.anchor_top = 0.34
	center_box.anchor_right = 1.0
	center_box.anchor_bottom = 0.98
	center_box.offset_top = 12.0
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center_box)

	_center_column = VBoxContainer.new()
	_center_column.name = "PortalColumn"
	_center_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_column.add_theme_constant_override("separation", 16)
	_center_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_box.add_child(_center_column)

	var cards_row := HBoxContainer.new()
	cards_row.name = "ModeCardsRow"
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 20)
	cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_column.add_child(cards_row)

	_mode_cards.clear()
	_mode_badges.clear()
	for mode_def: Dictionary in MODE_DEFINITIONS:
		var mode_id: String = str(mode_def["mode_id"])
		var card_result := _create_mode_card(
			mode_id,
			str(mode_def["node_name"]),
			str(mode_def["title"]),
			str(mode_def["icon"]),
			str(mode_def["size_text"]),
			int(mode_def["grid_divisions"]),
			int(mode_def["grid_size"]),
			str(mode_def["initial_category"])
		)
		var card_btn := card_result["button"] as Button
		var badge := card_result["badge"] as MiniGridBadge
		_mode_cards.append(card_btn)
		_mode_badges.append(badge)
		cards_row.add_child(card_btn)
		match mode_id:
			"character":
				_character_card = card_btn
				_character_badge = badge
			"animal":
				_animal_card = card_btn
			"vehicle":
				_vehicle_card = card_btn
			"scenery":
				_scenery_card = card_btn
				_scenery_badge = badge
				_scenery_size_label = card_result["size_label"] as Label

	var world_holder := CenterContainer.new()
	world_holder.name = "WorldSelectorHolder"
	world_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_column.add_child(world_holder)
	world_holder.add_child(_build_world_selector_pill())

	var gallery_holder := CenterContainer.new()
	gallery_holder.name = "GalleryHolder"
	gallery_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_column.add_child(gallery_holder)

	_gallery_button = _create_gallery_button()
	gallery_holder.add_child(_gallery_button)

	_apply_theme_visuals(_active_theme_id, false)


func show_home_screen() -> void:
	ensure_setup()
	visible = true


func hide_home_screen() -> void:
	ensure_setup()
	visible = false


func get_active_theme_id() -> String:
	return _active_theme_id


func get_selected_mode_id() -> String:
	return _selected_mode_id


func get_selected_initial_category() -> String:
	return _selected_initial_category


static func get_initial_category_for_mode(mode_id: String) -> String:
	for mode_def: Dictionary in MODE_DEFINITIONS:
		if str(mode_def["mode_id"]) == mode_id:
			return str(mode_def["initial_category"])
	return "basic"


func set_active_theme(theme_id: String, animate: bool = true) -> void:
	ensure_setup()
	if not WORLD_THEMES.has(theme_id):
		return
	var changed: bool = (_active_theme_id != theme_id)
	_active_theme_id = theme_id
	_apply_theme_visuals(theme_id, animate)
	if changed:
		theme_changed.emit(theme_id)


func _create_mode_card(
	mode_id: String,
	node_name: String,
	title_pt: String,
	icon_name: String,
	size_text: String,
	grid_divisions: int,
	grid_size: int,
	initial_category: String
) -> Dictionary:
	var btn := Button.new()
	btn.name = node_name
	btn.text = ""
	btn.tooltip_text = "%s (%s)" % [title_pt, size_text]
	btn.custom_minimum_size = Vector2(184.0, 212.0)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pivot_offset = btn.custom_minimum_size * 0.5

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_center)

	var icon_rect := TextureRect.new()
	icon_rect.texture = UiIconDrawer.get_icon_texture(icon_name)
	icon_rect.custom_minimum_size = Vector2(96.0, 96.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(icon_rect)

	var title_label := Label.new()
	title_label.text = title_pt
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.20, 0.22, 0.28))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	var badge_center := CenterContainer.new()
	badge_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge_center)

	var badge_pill := PanelContainer.new()
	badge_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(0.92, 0.94, 0.98, 0.95)
	pill_style.set_corner_radius_all(12)
	pill_style.content_margin_left = 10
	pill_style.content_margin_right = 12
	pill_style.content_margin_top = 4
	pill_style.content_margin_bottom = 4
	badge_pill.add_theme_stylebox_override("panel", pill_style)
	badge_center.add_child(badge_pill)

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 6)
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_pill.add_child(badge_row)

	var mini_grid := MiniGridBadge.new()
	mini_grid.grid_divisions = grid_divisions
	mini_grid.badge_text = size_text
	mini_grid.custom_minimum_size = Vector2(36.0, 32.0)
	mini_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.add_child(mini_grid)

	var size_label := Label.new()
	size_label.text = size_text
	size_label.add_theme_font_size_override("font_size", 18)
	size_label.add_theme_color_override("font_color", Color(0.26, 0.30, 0.38))
	size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.add_child(size_label)

	btn.pressed.connect(func() -> void:
		var resolved_size: int = 32 if (mode_id == "scenery" and _active_theme_id == "voxel") else grid_size
		_selected_mode_id = mode_id
		_selected_initial_category = initial_category
		_play_theme_transition_curtain(_active_theme_id, 0.85, 0.72)
		mode_started.emit(mode_id, resolved_size, _active_theme_id, initial_category)
		start_new_project_requested.emit(resolved_size, _active_theme_id)
		project_started.emit(resolved_size, _active_theme_id)
	)

	return {"button": btn, "badge": mini_grid, "size_label": size_label}


func _build_world_selector_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = "WorldSelectorPill"
	pill.mouse_filter = Control.MOUSE_FILTER_STOP

	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(1.0, 1.0, 1.0, 0.24)
	pill_style.border_color = Color(1.0, 1.0, 1.0, 0.45)
	pill_style.set_border_width_all(3)
	pill_style.set_corner_radius_all(48)
	pill_style.content_margin_left = 18
	pill_style.content_margin_right = 18
	pill_style.content_margin_top = 12
	pill_style.content_margin_bottom = 12
	pill.add_theme_stylebox_override("panel", pill_style)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)

	for world_id: String in WORLD_ORDER:
		var theme_data: Dictionary = WORLD_THEMES[world_id]
		var btn := Button.new()
		btn.name = "WorldToggle_%s" % world_id
		btn.text = ""
		btn.tooltip_text = str(theme_data["label"])
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(76.0, 76.0)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pivot_offset = btn.custom_minimum_size * 0.5

		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(center)

		var icon := TextureRect.new()
		icon.texture = UiIconDrawer.get_icon_texture("world_%s" % world_id)
		icon.custom_minimum_size = Vector2(46.0, 46.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)

		btn.pressed.connect(func() -> void:
			set_active_theme(world_id, true)
		)
		_world_buttons[world_id] = btn
		row.add_child(btn)

	return pill


func _create_gallery_button() -> Button:
	var btn := Button.new()
	btn.name = "HomeGalleryButton"
	btn.text = ""
	btn.tooltip_text = "Minhas Criações"
	btn.custom_minimum_size = Vector2(230.0, 72.0)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var cream := Color("#FFF3C4")
	var border := Color("#E0B84C")
	btn.add_theme_stylebox_override("normal", _make_tactile_style(cream, border, 26, 8))
	btn.add_theme_stylebox_override("hover", _make_tactile_style(cream.lightened(0.06), border, 26, 8))
	btn.add_theme_stylebox_override("pressed", _make_tactile_style(cream.darkened(0.06), border.darkened(0.1), 26, 4))
	btn.add_theme_stylebox_override("focus", _make_tactile_style(cream, border, 26, 8))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var icon := TextureRect.new()
	icon.texture = UiIconDrawer.get_icon_texture("gallery")
	icon.custom_minimum_size = Vector2(40.0, 40.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.text = "Minhas Criações"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.28, 0.22, 0.14))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	btn.pressed.connect(func() -> void:
		open_gallery_requested.emit()
		gallery_pressed.emit()
	)
	return btn


func _apply_theme_visuals(theme_id: String, animate: bool) -> void:
	var theme_data: Dictionary = WORLD_THEMES[theme_id]
	var target_bg: Color = theme_data["bg_color"] as Color
	var card_bg: Color = theme_data["card_bg"] as Color
	var card_border: Color = theme_data["card_border"] as Color
	var card_accent: Color = theme_data["card_accent"] as Color

	if _bg_tween != null and _bg_tween.is_valid():
		_bg_tween.kill()

	var bg_path: String = str(THEME_BACKGROUND_PATHS.get(theme_id, ""))
	var new_tex: Texture2D = null
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		var loaded: Resource = load(bg_path)
		if loaded is Texture2D:
			new_tex = loaded as Texture2D

	var incoming_layer: TextureRect = _bg_tex_b if _active_bg_layer_is_a else _bg_tex_a
	var outgoing_layer: TextureRect = _bg_tex_a if _active_bg_layer_is_a else _bg_tex_b
	if new_tex != null:
		_active_bg_layer_is_a = not _active_bg_layer_is_a
		incoming_layer.texture = new_tex
		incoming_layer.modulate.a = 0.0

	if animate and is_inside_tree():
		_bg_tween = create_tween()
		_bg_tween.set_parallel(true)
		_bg_tween.set_trans(Tween.TRANS_SINE)
		_bg_tween.set_ease(Tween.EASE_OUT)
		_bg_tween.tween_property(_bg_rect, "color", target_bg, BG_CROSSFADE_DURATION_SEC)
		if new_tex != null:
			_bg_tween.tween_property(incoming_layer, "modulate:a", 1.0, BG_CROSSFADE_DURATION_SEC)
			_bg_tween.tween_property(outgoing_layer, "modulate:a", 0.0, BG_CROSSFADE_DURATION_SEC)
		else:
			_bg_tween.tween_property(_bg_tex_a, "modulate:a", 0.0, BG_CROSSFADE_DURATION_SEC)
			_bg_tween.tween_property(_bg_tex_b, "modulate:a", 0.0, BG_CROSSFADE_DURATION_SEC)
	else:
		_bg_rect.color = target_bg
		if new_tex != null:
			incoming_layer.modulate.a = 1.0
			outgoing_layer.modulate.a = 0.0
		else:
			_bg_tex_a.modulate.a = 0.0
			_bg_tex_b.modulate.a = 0.0

	for card: Button in _mode_cards:
		if card == null:
			continue
		card.add_theme_stylebox_override("normal", _make_tactile_style(card_bg, card_border, 30, 10))
		card.add_theme_stylebox_override("hover", _make_tactile_style(card_bg.lightened(0.03), card_accent, 30, 10))
		card.add_theme_stylebox_override("pressed", _make_tactile_style(card_bg.darkened(0.04), card_border.darkened(0.15), 30, 5))
		card.add_theme_stylebox_override("focus", _make_tactile_style(card_bg, card_accent, 30, 10))

	for badge: MiniGridBadge in _mode_badges:
		if badge != null:
			badge.accent_color = card_accent
			badge.queue_redraw()
	if _scenery_badge != null:
		_scenery_badge.accent_color = card_accent
		_scenery_badge.grid_divisions = 7 if theme_id == "voxel" else 5
		_scenery_badge.badge_text = "32x32" if theme_id == "voxel" else "16x16"
		_scenery_badge.queue_redraw()
	if _scenery_size_label != null:
		_scenery_size_label.text = "32x32" if theme_id == "voxel" else "16x16"
	if _scenery_card != null:
		_scenery_card.tooltip_text = "Cenário (%s)" % ("32x32" if theme_id == "voxel" else "16x16")

	for world_id: String in WORLD_ORDER:
		var btn: Button = _world_buttons.get(world_id) as Button
		if btn == null:
			continue
		var is_selected: bool = (world_id == theme_id)
		btn.set_pressed_no_signal(is_selected)
		var pill_col: Color = WORLD_THEMES[world_id]["pill_color"] as Color
		var base_col: Color = Color.WHITE if is_selected else Color(1.0, 1.0, 1.0, 0.72)
		var border_col: Color = pill_col.darkened(0.18) if is_selected else Color(0.85, 0.88, 0.92, 0.8)
		btn.add_theme_stylebox_override("normal", _make_tactile_style(base_col, border_col, 38, 6 if is_selected else 4))
		btn.add_theme_stylebox_override("hover", _make_tactile_style(Color.WHITE, pill_col, 38, 6))
		btn.add_theme_stylebox_override("pressed", _make_tactile_style(base_col.darkened(0.05), border_col, 38, 3))
		btn.add_theme_stylebox_override("focus", _make_tactile_style(base_col, border_col, 38, 6 if is_selected else 4))

	if animate and is_inside_tree():
		_play_card_pulse()
		_play_theme_transition_curtain(theme_id, 0.42, 0.65)


func _ensure_transition_curtain() -> void:
	if _transition_curtain != null and is_instance_valid(_transition_curtain):
		return
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "ThemeTransitionLayer"
	_transition_layer.layer = 20
	add_child(_transition_layer)

	_transition_curtain = ColorRect.new()
	_transition_curtain.name = "ThemeTransitionCurtain"
	_transition_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_curtain.color = Color(1.0, 1.0, 1.0, 0.0)
	_transition_curtain.visible = false
	_transition_layer.add_child(_transition_curtain)


func _play_theme_transition_curtain(theme_id: String, peak_alpha: float, duration: float) -> void:
	if not is_inside_tree():
		return
	_ensure_transition_curtain()
	if _curtain_tween != null and _curtain_tween.is_valid():
		_curtain_tween.kill()

	var theme_data: Dictionary = WORLD_THEMES.get(theme_id, WORLD_THEMES["plastic"]) as Dictionary
	var curtain_col: Color = theme_data.get("curtain_color", Color("#FFB74D")) as Color
	_transition_curtain.color = Color(curtain_col.r, curtain_col.g, curtain_col.b, 0.0)
	_transition_curtain.visible = true

	var fade_in_time: float = clampf(duration * 0.25, 0.12, 0.22)
	var fade_out_time: float = maxf(duration - fade_in_time, 0.35)
	_curtain_tween = create_tween()
	_curtain_tween.tween_property(_transition_curtain, "color:a", peak_alpha, fade_in_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_curtain_tween.tween_property(_transition_curtain, "color:a", 0.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_curtain_tween.tween_callback(func() -> void:
		if _transition_curtain != null and is_instance_valid(_transition_curtain):
			_transition_curtain.visible = false
	)


func _play_card_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_parallel(true)
	_pulse_tween.set_trans(Tween.TRANS_BACK)
	_pulse_tween.set_ease(Tween.EASE_OUT)
	for card: Button in _mode_cards:
		if card == null:
			continue
		card.scale = Vector2(0.96, 0.96)
		_pulse_tween.tween_property(card, "scale", Vector2.ONE, FADE_DURATION_SEC)


static func _create_bg_texture_layer(node_name: String) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.name = node_name
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.modulate.a = 0.0
	return tex_rect


static func _make_tactile_style(
	bg_color: Color,
	border_color: Color,
	corner_radius: int,
	bottom_thickness: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.border_width_bottom = bottom_thickness
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = Color(0.06, 0.10, 0.18, 0.22)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 6)
	return style
