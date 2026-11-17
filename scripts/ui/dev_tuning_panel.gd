class_name DevTuningPanel
extends PanelContainer

## Hidden live developer tuning overlay (toggle with F1 or triple-tap top-left 80x80).
## Edits studio lighting, grid dots, pastel backgrounds, 13-color palette, HUD layout,
## camera feel, and block placement feedback in real time with JSON persistence.

const CameraController = preload("res://scripts/controllers/camera_controller.gd")
const FeedbackFX = preload("res://scripts/visuals/feedback_fx.gd")

const PROJECT_TUNING_PATH := "res://dev_tuning.json"
const USER_TUNING_PATH := "user://dev_tuning.json"
const CORNER_TAP_RECT := Rect2(0.0, 0.0, 80.0, 80.0)
const CORNER_TAP_WINDOW_SEC := 0.85

const DEFAULT_STUDIO_BG_HEX: Array[String] = [
	"#5CC2F2",
	"#F3E6D3",
	"#A8E6CF",
	"#D4C4FB",
	"#FFD3B6",
	"#DCE4EC",
]

const DEFAULT_PALETTE_HEX: Array[String] = [
	"#EF476F",
	"#E63946",
	"#F77F00",
	"#FFD166",
	"#80ED99",
	"#06D6A0",
	"#4EA8DE",
	"#118AB2",
	"#9B5DE5",
	"#F15BB5",
	"#A1623B",
	"#F8FAFC",
	"#111111",
]

var _hud: CanvasLayer = null
var _camera_controller: CameraController = null
var _is_built: bool = false
var _is_updating_ui: bool = false
var _corner_tap_times: Array[float] = []

var _status_label: Label = null
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _bg_pickers: Array[ColorPickerButton] = []
var _palette_pickers: Array[ColorPickerButton] = []

var _config: Dictionary = {}


func _ready() -> void:
	visible = false
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_built()
	if _config.is_empty():
		_config = _create_default_config()
	_load_from_disk()
	_sync_controls_from_config()


func bind(hud: CanvasLayer) -> void:
	_hud = hud
	_ensure_built()
	if _config.is_empty():
		_config = _create_default_config()
		_load_from_disk()
	_sync_controls_from_config()
	call_deferred("apply_all")


func sync_camera_controller(controller: CameraController) -> void:
	_camera_controller = controller
	if not _config.is_empty():
		_apply_camera_and_feedback()


func _input(event: InputEvent) -> void:
	if _hud != null and is_instance_valid(_hud) and not _hud.visible:
		return
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		if key_ev.pressed and not key_ev.echo and key_ev.keycode == KEY_F1:
			_toggle_visibility()
			get_viewport().set_input_as_handled()
			return

	var tap_pos := Vector2(-1.0, -1.0)
	var is_tap := false
	if event is InputEventScreenTouch:
		var touch_ev := event as InputEventScreenTouch
		if touch_ev.pressed:
			tap_pos = touch_ev.position
			is_tap = true
	elif event is InputEventMouseButton:
		var mouse_ev := event as InputEventMouseButton
		if mouse_ev.pressed and mouse_ev.button_index == MOUSE_BUTTON_LEFT:
			tap_pos = mouse_ev.position
			is_tap = true

	if is_tap and CORNER_TAP_RECT.has_point(tap_pos):
		var now_sec: float = float(Time.get_ticks_msec()) * 0.001
		_corner_tap_times.append(now_sec)
		while not _corner_tap_times.is_empty() and (now_sec - _corner_tap_times[0]) > CORNER_TAP_WINDOW_SEC:
			_corner_tap_times.pop_front()
		if _corner_tap_times.size() >= 3:
			_corner_tap_times.clear()
			_toggle_visibility()


func _toggle_visibility() -> void:
	_ensure_built()
	visible = not visible
	if visible:
		_sync_controls_from_config()


func _ensure_built() -> void:
	if _is_built:
		return
	_is_built = true

	name = "DevTuningPanel"
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.92
	offset_left = 14.0
	offset_top = 14.0
	offset_right = 382.0
	offset_bottom = 0.0
	custom_minimum_size = Vector2(368.0, 420.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.88)
	panel_style.border_color = Color(0.35, 0.45, 0.62, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", panel_style)

	var root_col := VBoxContainer.new()
	root_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_col.add_theme_constant_override("separation", 8)
	add_child(root_col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_col.add_child(header)

	var title := Label.new()
	title.text = "DEV TUNING (F1)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#F8FAFC"))
	header.add_child(title)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color("#86EFAC"))
	header.add_child(_status_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28.0, 26.0)
	close_btn.pressed.connect(func() -> void: visible = false)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_col.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	_add_section_header(content, "Estúdio & Luz")
	_add_slider_row(content, "key_light_energy", "Luz Key", 0.0, 3.0, 0.05, "%.2f")
	_add_slider_row(content, "fill_light_energy", "Luz Fill", 0.0, 2.0, 0.05, "%.2f")
	_add_slider_row(content, "ambient_light_energy", "Luz Amb/Rim", 0.0, 2.0, 0.05, "%.2f")
	_add_slider_row(content, "grid_dot_opacity", "Opacidade Grid", 0.0, 1.0, 0.02, "%.2f")
	_add_slider_row(content, "grid_dot_scale", "Escala Pontos", 0.4, 2.5, 0.05, "%.2f")

	var bg_label := Label.new()
	bg_label.text = "Fundos Pastéis (6):"
	bg_label.add_theme_font_size_override("font_size", 12)
	bg_label.add_theme_color_override("font_color", Color("#CBD5E1"))
	content.add_child(bg_label)

	var bg_row := HBoxContainer.new()
	bg_row.add_theme_constant_override("separation", 6)
	content.add_child(bg_row)
	_bg_pickers.clear()
	for i in range(DEFAULT_STUDIO_BG_HEX.size()):
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(46.0, 26.0)
		picker.edit_alpha = false
		var idx: int = i
		picker.color_changed.connect(func(col: Color) -> void: _on_studio_bg_picker_changed(idx, col))
		bg_row.add_child(picker)
		_bg_pickers.append(picker)

	_add_section_header(content, "Editor da Paleta (13 Cores)")
	var palette_grid := GridContainer.new()
	palette_grid.columns = 7
	palette_grid.add_theme_constant_override("h_separation", 6)
	palette_grid.add_theme_constant_override("v_separation", 6)
	content.add_child(palette_grid)
	_palette_pickers.clear()
	for i in range(DEFAULT_PALETTE_HEX.size()):
		var p_picker := ColorPickerButton.new()
		p_picker.custom_minimum_size = Vector2(40.0, 26.0)
		p_picker.edit_alpha = false
		var p_idx: int = i
		p_picker.color_changed.connect(func(col: Color) -> void: _on_palette_picker_changed(p_idx, col))
		palette_grid.add_child(p_picker)
		_palette_pickers.append(p_picker)

	_add_section_header(content, "Layout da HUD")
	_add_slider_row(content, "tray_width", "Bandeja Esq.", 120.0, 240.0, 2.0, "%.0f px")
	_add_slider_row(content, "card_height", "Altura Cartão", 80.0, 150.0, 2.0, "%.0f px")
	_add_slider_row(content, "right_btn_size", "Botões Dir.", 72.0, 128.0, 2.0, "%.0f px")
	_add_slider_row(content, "palette_height", "Barra Inf.", 56.0, 100.0, 2.0, "%.0f px")
	_add_slider_row(content, "icon_padding", "Padding Ícone", 4.0, 24.0, 1.0, "%.0f px")

	_add_section_header(content, "Câmera & Feedback")
	_add_slider_row(content, "orbit_sensitivity", "Sensib. Órbita", 0.2, 3.0, 0.05, "%.2f")
	_add_slider_row(content, "zoom_min", "Zoom Mín.", 2.0, 15.0, 0.25, "%.2f")
	_add_slider_row(content, "zoom_max", "Zoom Máx.", 10.0, 60.0, 0.5, "%.1f")
	_add_slider_row(content, "camera_damping", "Suavização", 2.0, 25.0, 0.5, "%.1f")
	_add_slider_row(content, "place_duration", "Duração Bloco", 0.05, 0.50, 0.01, "%.2f s")
	_add_slider_row(content, "place_overshoot", "Overshoot", 1.00, 1.60, 0.02, "%.2f")

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	root_col.add_child(footer)

	var save_btn := Button.new()
	save_btn.text = "Salvar no Projeto"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_save_to_project)
	footer.add_child(save_btn)

	var copy_btn := Button.new()
	copy_btn.text = "Copiar JSON"
	copy_btn.pressed.connect(_copy_json)
	footer.add_child(copy_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Resetar"
	reset_btn.pressed.connect(_reset_defaults)
	footer.add_child(reset_btn)


func _add_section_header(parent: Control, text: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#93C5FD"))
	parent.add_child(lbl)


func _add_slider_row(
	parent: Control,
	key: String,
	label_text: String,
	min_val: float,
	max_val: float,
	step_val: float,
	format_str: String
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(106.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("#E2E8F0"))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(val: float) -> void: _on_slider_changed(key, val, format_str))
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(56.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color("#FDE68A"))
	row.add_child(val_lbl)

	_sliders[key] = slider
	_value_labels[key] = val_lbl
	slider.set_meta("format_str", format_str)


func _create_default_config() -> Dictionary:
	return {
		"key_light_energy": 1.15,
		"fill_light_energy": 0.42,
		"ambient_light_energy": 0.55,
		"grid_dot_opacity": 0.72,
		"grid_dot_scale": 1.0,
		"studio_bg_colors": DEFAULT_STUDIO_BG_HEX.duplicate(),
		"palette_colors": DEFAULT_PALETTE_HEX.duplicate(),
		"tray_width": 160.0,
		"card_height": 108.0,
		"right_btn_size": 96.0,
		"palette_height": 70.0,
		"icon_padding": 14.0,
		"orbit_sensitivity": 1.0,
		"zoom_min": 5.0,
		"zoom_max": 19.5,
		"camera_damping": 12.0,
		"place_duration": 0.15,
		"place_overshoot": 1.20,
	}


func _sync_controls_from_config() -> void:
	_is_updating_ui = true
	for key_var: Variant in _sliders.keys():
		var key: String = str(key_var)
		var slider := _sliders[key] as HSlider
		var val_lbl := _value_labels[key] as Label
		var val: float = float(_config.get(key, slider.min_value))
		slider.value = val
		var fmt: String = str(slider.get_meta("format_str", "%.2f"))
		val_lbl.text = fmt % val

	var bg_list: Array = _config.get("studio_bg_colors", DEFAULT_STUDIO_BG_HEX) as Array
	for i in range(mini(_bg_pickers.size(), bg_list.size())):
		_bg_pickers[i].color = Color(str(bg_list[i]))

	var pal_list: Array = _config.get("palette_colors", DEFAULT_PALETTE_HEX) as Array
	for i in range(mini(_palette_pickers.size(), pal_list.size())):
		_palette_pickers[i].color = Color(str(pal_list[i]))
	_is_updating_ui = false


func _on_slider_changed(key: String, val: float, format_str: String) -> void:
	if _value_labels.has(key):
		(_value_labels[key] as Label).text = format_str % val
	if _is_updating_ui:
		return
	_config[key] = val
	if key in ["tray_width", "card_height", "right_btn_size", "palette_height", "icon_padding"]:
		_apply_hud_layout()
	elif key in ["orbit_sensitivity", "zoom_min", "zoom_max", "camera_damping", "place_duration", "place_overshoot"]:
		_apply_camera_and_feedback()
	else:
		_apply_studio_and_lighting()


func _on_studio_bg_picker_changed(index: int, color: Color) -> void:
	if _is_updating_ui:
		return
	var bg_list: Array = _config.get("studio_bg_colors", DEFAULT_STUDIO_BG_HEX.duplicate()) as Array
	if index >= 0 and index < bg_list.size():
		bg_list[index] = "#" + color.to_html(false)
		_config["studio_bg_colors"] = bg_list
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("set_studio_bg_preset"):
		_hud.call("set_studio_bg_preset", index, color, true)


func _on_palette_picker_changed(index: int, color: Color) -> void:
	if _is_updating_ui:
		return
	var pal_list: Array = _config.get("palette_colors", DEFAULT_PALETTE_HEX.duplicate()) as Array
	if index >= 0 and index < pal_list.size():
		pal_list[index] = "#" + color.to_html(false)
		_config["palette_colors"] = pal_list
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("set_palette_color"):
		_hud.call("set_palette_color", index, color)


func apply_all() -> void:
	_apply_hud_layout()
	_apply_palette_and_bg_presets()
	_apply_studio_and_lighting()
	_apply_camera_and_feedback()


func _apply_hud_layout() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	if _hud.has_method("apply_hud_tuning"):
		_hud.call(
			"apply_hud_tuning",
			float(_config.get("tray_width", 160.0)),
			float(_config.get("card_height", 108.0)),
			float(_config.get("right_btn_size", 96.0)),
			float(_config.get("palette_height", 70.0)),
			float(_config.get("icon_padding", 14.0))
		)


func _apply_palette_and_bg_presets() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	var pal_list: Array = _config.get("palette_colors", DEFAULT_PALETTE_HEX) as Array
	if _hud.has_method("set_palette_color"):
		for i in range(pal_list.size()):
			_hud.call("set_palette_color", i, Color(str(pal_list[i])))
	var bg_list: Array = _config.get("studio_bg_colors", DEFAULT_STUDIO_BG_HEX) as Array
	if _hud.has_method("set_studio_bg_preset"):
		for i in range(bg_list.size()):
			_hud.call("set_studio_bg_preset", i, Color(str(bg_list[i])), false)


func _apply_studio_and_lighting() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	_apply_lighting_recursive(tree.root)


func _apply_lighting_recursive(node: Node) -> void:
	if node is DirectionalLight3D:
		var dl := node as DirectionalLight3D
		if dl.name == "FillLight":
			dl.light_energy = float(_config.get("fill_light_energy", 0.42))
		elif dl.name == "RimLight":
			dl.light_energy = float(_config.get("ambient_light_energy", 0.55))
		else:
			dl.light_energy = float(_config.get("key_light_energy", 1.15))
	elif node is WorldEnvironment:
		var we := node as WorldEnvironment
		if we.environment != null:
			we.environment.ambient_light_energy = float(_config.get("ambient_light_energy", 0.55))
	elif node is MultiMeshInstance3D and node.name == "GridDotMarkers":
		var mmi := node as MultiMeshInstance3D
		var dot_scale: float = float(_config.get("grid_dot_scale", 1.0))
		if mmi.multimesh != null and mmi.multimesh.mesh is CylinderMesh:
			var cyl := mmi.multimesh.mesh as CylinderMesh
			cyl.top_radius = 0.055 * dot_scale
			cyl.bottom_radius = 0.055 * dot_scale
		if mmi.material_override is StandardMaterial3D:
			var mat := mmi.material_override as StandardMaterial3D
			var col: Color = mat.albedo_color
			col.a = float(_config.get("grid_dot_opacity", 0.72))
			mat.albedo_color = col

	for child: Node in node.get_children():
		_apply_lighting_recursive(child)


func _apply_camera_and_feedback() -> void:
	FeedbackFX.place_duration = float(_config.get("place_duration", 0.15))
	FeedbackFX.place_overshoot_xz = float(_config.get("place_overshoot", 1.20))
	if _camera_controller != null and is_instance_valid(_camera_controller):
		_camera_controller.apply_tuning(
			float(_config.get("orbit_sensitivity", 1.0)),
			float(_config.get("zoom_min", 5.0)),
			float(_config.get("zoom_max", 19.5)),
			float(_config.get("camera_damping", 12.0))
		)


func _load_from_disk() -> void:
	var path: String = ""
	if FileAccess.file_exists(PROJECT_TUNING_PATH):
		path = PROJECT_TUNING_PATH
	elif FileAccess.file_exists(USER_TUNING_PATH):
		path = USER_TUNING_PATH
	if path.is_empty():
		return

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var loaded := parsed as Dictionary
		for key_var: Variant in loaded.keys():
			var key: String = str(key_var)
			var val: Variant = loaded[key_var]
			if val != null and _config.has(key):
				_config[key] = val


func _save_to_project() -> void:
	var json_str: String = JSON.stringify(_config, "\t")
	var saved_ok := false
	if OS.get_name() != "Android":
		var abs_path: String = ProjectSettings.globalize_path(PROJECT_TUNING_PATH)
		var f := FileAccess.open(abs_path, FileAccess.WRITE)
		if f != null:
			f.store_string(json_str)
			saved_ok = true
	if not saved_ok:
		var uf := FileAccess.open(USER_TUNING_PATH, FileAccess.WRITE)
		if uf != null:
			uf.store_string(json_str)
			saved_ok = true
	_set_status("Salvo!" if saved_ok else "Erro ao salvar")


func _copy_json() -> void:
	DisplayServer.clipboard_set(JSON.stringify(_config, "\t"))
	_set_status("JSON copiado!")


func _reset_defaults() -> void:
	_config = _create_default_config()
	_sync_controls_from_config()
	apply_all()
	_set_status("Padrão restaurado")


func _set_status(msg: String) -> void:
	if _status_label != null and is_instance_valid(_status_label):
		_status_label.text = msg
