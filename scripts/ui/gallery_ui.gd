class_name GalleryUI
extends CanvasLayer
## Child-friendly project gallery overlay for creating, opening, renaming, and deleting local builds.

const ProjectData = preload("res://scripts/core/project_data.gd")

signal new_project_requested
signal open_project_requested(project_id: String)
signal rename_project_requested(project_id: String, new_name: String)
signal delete_project_requested(project_id: String)
signal close_gallery_requested

const COLOR_BACKDROP := Color(0.18, 0.16, 0.14, 0.44)
const COLOR_PANEL_BG := Color(0.988, 0.978, 0.955, 0.99)
const COLOR_PANEL_BORDER := Color(0.85, 0.80, 0.72, 1.0)
const COLOR_CARD_BG := Color(1.0, 0.996, 0.988, 1.0)
const COLOR_CARD_ACTIVE_BG := Color(0.992, 0.968, 0.905, 1.0)
const COLOR_CARD_BORDER := Color(0.88, 0.83, 0.76, 1.0)
const COLOR_CARD_ACTIVE_BORDER := Color(0.24, 0.55, 0.83, 0.95)
const COLOR_TEXT_PRIMARY := Color(0.20, 0.19, 0.18, 1.0)
const COLOR_TEXT_MUTED := Color(0.49, 0.46, 0.42, 1.0)
const COLOR_PRIMARY_BG := Color(0.33, 0.73, 0.53, 1.0)
const COLOR_PRIMARY_BORDER := Color(0.23, 0.56, 0.40, 1.0)
const COLOR_OPEN_BG := Color(0.24, 0.55, 0.83, 1.0)
const COLOR_OPEN_BORDER := Color(0.17, 0.41, 0.65, 1.0)
const COLOR_DELETE_BG := Color(0.98, 0.91, 0.90, 1.0)
const COLOR_DELETE_BORDER := Color(0.86, 0.52, 0.48, 1.0)
const COLOR_DELETE_TEXT := Color(0.68, 0.21, 0.18, 1.0)
const COLOR_ERROR_BG := Color(0.99, 0.91, 0.90, 1.0)
const COLOR_ERROR_BORDER := Color(0.85, 0.34, 0.30, 1.0)
const COLOR_NEUTRAL_BG := Color(1.0, 0.994, 0.982, 1.0)
const COLOR_NEUTRAL_BORDER := Color(0.82, 0.77, 0.69, 1.0)
const COLOR_SHADOW := Color(0.18, 0.16, 0.14, 0.16)

var _root: Control = null
var _gallery_panel: PanelContainer = null
var _new_project_button: Button = null
var _close_gallery_button: Button = null
var _error_banner: PanelContainer = null
var _error_label: Label = null
var _rename_bar: PanelContainer = null
var _rename_line_edit: LineEdit = null
var _projects_grid: GridContainer = null
var _empty_label: Label = null
var _project_cards: Dictionary = {}
var _pending_rename_id: String = ""


func _ready() -> void:
	layer = 10
	visible = false
	ensure_setup()


func ensure_setup() -> void:
	if _root != null and is_instance_valid(_root):
		return

	_root = Control.new()
	_root.name = "GalleryRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.name = "GalleryBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COLOR_BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	_gallery_panel = PanelContainer.new()
	_gallery_panel.name = "GalleryPanel"
	_gallery_panel.anchor_left = 0.08
	_gallery_panel.anchor_right = 0.92
	_gallery_panel.anchor_top = 0.07
	_gallery_panel.anchor_bottom = 0.93
	_gallery_panel.offset_left = 0.0
	_gallery_panel.offset_right = 0.0
	_gallery_panel.offset_top = 0.0
	_gallery_panel.offset_bottom = 0.0
	_gallery_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_gallery_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL_BG, COLOR_PANEL_BORDER, 28, 16))
	_root.add_child(_gallery_panel)

	var outer_margin := MarginContainer.new()
	outer_margin.name = "GalleryMargin"
	outer_margin.add_theme_constant_override("margin_left", 32)
	outer_margin.add_theme_constant_override("margin_right", 32)
	outer_margin.add_theme_constant_override("margin_top", 28)
	outer_margin.add_theme_constant_override("margin_bottom", 28)
	_gallery_panel.add_child(outer_margin)

	var layout := VBoxContainer.new()
	layout.name = "GalleryLayout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 18)
	outer_margin.add_child(layout)

	_build_header_row(layout)
	_build_error_banner(layout)
	_build_rename_bar(layout)

	_empty_label = Label.new()
	_empty_label.name = "EmptyGalleryLabel"
	_empty_label.text = "Nenhuma construção salva ainda. Toque em '+ Nova Construção' para começar!"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_label.add_theme_font_size_override("font_size", 24)
	_empty_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	layout.add_child(_empty_label)

	var scroll := ScrollContainer.new()
	scroll.name = "ProjectsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_projects_grid = GridContainer.new()
	_projects_grid.name = "ProjectsGrid"
	_projects_grid.columns = 3
	_projects_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_projects_grid.add_theme_constant_override("h_separation", 20)
	_projects_grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(_projects_grid)


func show_gallery() -> void:
	ensure_setup()
	visible = true


func hide_gallery() -> void:
	ensure_setup()
	cancel_rename()
	visible = false


func is_gallery_open() -> bool:
	return visible


func refresh_projects(projects: Array, active_project_id: String = "") -> void:
	ensure_setup()
	_project_cards.clear()

	for child: Node in _projects_grid.get_children():
		_projects_grid.remove_child(child)
		child.queue_free()

	var valid_projects: Array[ProjectData] = []
	for p_variant: Variant in projects:
		if p_variant is ProjectData:
			valid_projects.append(p_variant as ProjectData)

	_empty_label.visible = valid_projects.is_empty()
	_projects_grid.get_parent().visible = not valid_projects.is_empty()

	for project: ProjectData in valid_projects:
		var card := _create_project_card(project, project.project_id == active_project_id)
		_projects_grid.add_child(card)
		_project_cards[project.project_id] = card


func get_project_cards() -> Dictionary:
	ensure_setup()
	return _project_cards.duplicate()


func begin_rename(project_id: String, current_name: String) -> void:
	ensure_setup()
	_pending_rename_id = project_id
	_rename_line_edit.text = current_name
	_rename_bar.visible = true
	_rename_line_edit.grab_focus()
	_rename_line_edit.select_all()


func cancel_rename() -> void:
	ensure_setup()
	_pending_rename_id = ""
	if _rename_bar != null:
		_rename_bar.visible = false
	if _rename_line_edit != null:
		_rename_line_edit.text = ""


func submit_rename() -> void:
	ensure_setup()
	if _pending_rename_id.is_empty():
		return
	var target_id: String = _pending_rename_id
	var new_name: String = _rename_line_edit.text.strip_edges()
	if new_name.is_empty():
		show_error("Digite um nome para o projeto antes de salvar.")
		return
	cancel_rename()
	rename_project_requested.emit(target_id, new_name)


func show_error(message: String) -> void:
	ensure_setup()
	_error_label.text = message
	_error_banner.visible = not message.strip_edges().is_empty()


func clear_error() -> void:
	ensure_setup()
	_error_label.text = ""
	_error_banner.visible = false


func get_error_message() -> String:
	ensure_setup()
	return _error_label.text if _error_banner.visible else ""


func _build_header_row(parent: Control) -> void:
	var header_row := HBoxContainer.new()
	header_row.name = "GalleryHeaderRow"
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_theme_constant_override("separation", 16)
	parent.add_child(header_row)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	header_row.add_child(title_col)

	var title_label := Label.new()
	title_label.name = "GalleryTitle"
	title_label.text = "Minhas Construções"
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_col.add_child(title_label)

	var subtitle := Label.new()
	subtitle.name = "GallerySubtitle"
	subtitle.text = "Crie um novo projeto ou abra uma construção salva"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	title_col.add_child(subtitle)

	_new_project_button = _create_pill_button(
		"NewProjectButton",
		"+ Nova Construção",
		COLOR_PRIMARY_BG,
		COLOR_PRIMARY_BORDER,
		Color.WHITE,
		Vector2(260.0, 62.0)
	)
	_new_project_button.pressed.connect(func() -> void: new_project_requested.emit())
	header_row.add_child(_new_project_button)

	_close_gallery_button = _create_pill_button(
		"CloseGalleryButton",
		"Voltar",
		COLOR_NEUTRAL_BG,
		COLOR_NEUTRAL_BORDER,
		COLOR_TEXT_PRIMARY,
		Vector2(180.0, 62.0)
	)
	_close_gallery_button.pressed.connect(func() -> void: close_gallery_requested.emit())
	header_row.add_child(_close_gallery_button)


func _build_error_banner(parent: Control) -> void:
	_error_banner = PanelContainer.new()
	_error_banner.name = "ErrorBanner"
	_error_banner.visible = false
	_error_banner.add_theme_stylebox_override("panel", _make_panel_style(COLOR_ERROR_BG, COLOR_ERROR_BORDER, 16, 4))
	parent.add_child(_error_banner)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_error_banner.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	_error_label = Label.new()
	_error_label.name = "ErrorMessageLabel"
	_error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.add_theme_font_size_override("font_size", 18)
	_error_label.add_theme_color_override("font_color", COLOR_DELETE_TEXT)
	row.add_child(_error_label)

	var dismiss_btn := _create_pill_button(
		"DismissErrorButton",
		"OK",
		COLOR_NEUTRAL_BG,
		COLOR_NEUTRAL_BORDER,
		COLOR_TEXT_PRIMARY,
		Vector2(88.0, 48.0)
	)
	dismiss_btn.pressed.connect(clear_error)
	row.add_child(dismiss_btn)


func _build_rename_bar(parent: Control) -> void:
	_rename_bar = PanelContainer.new()
	_rename_bar.name = "RenameBar"
	_rename_bar.visible = false
	_rename_bar.add_theme_stylebox_override("panel", _make_panel_style(COLOR_CARD_ACTIVE_BG, COLOR_CARD_ACTIVE_BORDER, 18, 4))
	parent.add_child(_rename_bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_rename_bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var prompt := Label.new()
	prompt.name = "RenamePromptLabel"
	prompt.text = "Nome do Projeto:"
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	row.add_child(prompt)

	_rename_line_edit = LineEdit.new()
	_rename_line_edit.name = "RenameLineEdit"
	_rename_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_line_edit.custom_minimum_size = Vector2(240.0, 50.0)
	_rename_line_edit.placeholder_text = "Digite o nome da construção"
	_rename_line_edit.add_theme_font_size_override("font_size", 20)
	_rename_line_edit.text_submitted.connect(func(_txt: String) -> void: submit_rename())
	row.add_child(_rename_line_edit)

	var confirm_btn := _create_pill_button(
		"ConfirmRenameButton",
		"Salvar Nome",
		COLOR_PRIMARY_BG,
		COLOR_PRIMARY_BORDER,
		Color.WHITE,
		Vector2(156.0, 52.0)
	)
	confirm_btn.pressed.connect(submit_rename)
	row.add_child(confirm_btn)

	var cancel_btn := _create_pill_button(
		"CancelRenameButton",
		"Cancelar",
		COLOR_NEUTRAL_BG,
		COLOR_NEUTRAL_BORDER,
		COLOR_TEXT_PRIMARY,
		Vector2(124.0, 52.0)
	)
	cancel_btn.pressed.connect(cancel_rename)
	row.add_child(cancel_btn)


func _create_project_card(project: ProjectData, is_active: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ProjectCard_" + project.project_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 176.0)
	card.set_meta("project_id", project.project_id)
	var bg_col: Color = COLOR_CARD_ACTIVE_BG if is_active else COLOR_CARD_BG
	var border_col: Color = COLOR_CARD_ACTIVE_BORDER if is_active else COLOR_CARD_BORDER
	card.add_theme_stylebox_override("panel", _make_panel_style(bg_col, border_col, 22, 6))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var name_label := Label.new()
	name_label.name = "ProjectNameLabel"
	name_label.text = project.project_name
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	col.add_child(name_label)

	var piece_count: int = project.get_piece_count()
	var count_label := Label.new()
	count_label.name = "PieceCountLabel"
	count_label.text = "1 bloco" if piece_count == 1 else "%d blocos" % piece_count
	if is_active:
		count_label.text += "  •  Atual"
	count_label.add_theme_font_size_override("font_size", 17)
	count_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	col.add_child(count_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var actions_row := HBoxContainer.new()
	actions_row.name = "ProjectCardActions"
	actions_row.add_theme_constant_override("separation", 10)
	col.add_child(actions_row)

	var open_btn := _create_pill_button(
		"OpenProjectButton",
		"Abrir",
		COLOR_OPEN_BG,
		COLOR_OPEN_BORDER,
		Color.WHITE,
		Vector2(104.0, 52.0)
	)
	open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_btn.pressed.connect(func() -> void: open_project_requested.emit(project.project_id))
	actions_row.add_child(open_btn)

	var rename_btn := _create_pill_button(
		"RenameProjectButton",
		"Renomear",
		COLOR_NEUTRAL_BG,
		COLOR_NEUTRAL_BORDER,
		COLOR_TEXT_PRIMARY,
		Vector2(120.0, 52.0)
	)
	rename_btn.pressed.connect(func() -> void: begin_rename(project.project_id, project.project_name))
	actions_row.add_child(rename_btn)

	var delete_btn := _create_pill_button(
		"DeleteProjectButton",
		"Apagar",
		COLOR_DELETE_BG,
		COLOR_DELETE_BORDER,
		COLOR_DELETE_TEXT,
		Vector2(104.0, 52.0)
	)
	delete_btn.pressed.connect(func() -> void: delete_project_requested.emit(project.project_id))
	actions_row.add_child(delete_btn)

	return card


func _create_pill_button(
	btn_name: String,
	label_text: String,
	bg_color: Color,
	border_color: Color,
	text_color: Color,
	min_size: Vector2
) -> Button:
	var btn := Button.new()
	btn.name = btn_name
	btn.text = label_text
	btn.custom_minimum_size = min_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_color_override("font_focus_color", text_color)

	btn.add_theme_stylebox_override("normal", _make_button_style(bg_color, border_color, 4))
	btn.add_theme_stylebox_override("hover", _make_button_style(bg_color.lightened(0.06), border_color, 4))
	btn.add_theme_stylebox_override("pressed", _make_button_style(bg_color.darkened(0.06), border_color, 2))
	btn.add_theme_stylebox_override("focus", _make_button_style(bg_color, border_color, 4))
	return btn


func _make_panel_style(
	bg_color: Color,
	border_color: Color,
	radius: int,
	shadow_size: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_button_style(bg_color: Color, border_color: Color, bottom_border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.border_width_bottom = bottom_border
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
