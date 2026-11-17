class_name CameraController
extends Node3D

## Controls the fixed-angle isometric orthographic camera for the construction workspace.
## Supports 90-degree stepped yaw rotation, smooth zoom (pinch, magnify gesture, mouse wheel),
## recentering, and automatic lateral framing compensation for the left piece tray.

const PIVOT_NODE_NAME := "CameraPivot"
const CAMERA_NODE_NAME := "IsometricCamera"
const ROTATION_STEP_COUNT := 4
const DEFAULT_ASPECT_RATIO := 1920.0 / 1200.0
const MIN_PINCH_DISTANCE_PX := 2.0

@export var pitch_degrees: float = -35.264
@export var base_yaw_degrees: float = 45.0
@export var camera_distance: float = 25.0
@export var default_size: float = 13.0
@export var min_size: float = 6.0
@export var max_size: float = 19.5
@export var near_clip: float = 0.1
@export var far_clip: float = 100.0
@export var smoothing_speed: float = 12.0
@export var orbit_sensitivity: float = 1.0
@export var tray_width_ratio: float = 0.07
@export var mouse_wheel_zoom_step: float = 0.9
@export var button_zoom_step: float = 1.25

## When true, zoom and pinch inputs are ignored (for example, while dragging a block).
var is_interaction_locked: bool = false:
	set(value):
		is_interaction_locked = value
		if is_interaction_locked:
			_last_pinch_distance = -1.0

var _pivot: Node3D = null
var _camera: Camera3D = null
var _is_setup: bool = false
var _step_index: int = 0
var _target_yaw_degrees: float = 45.0
var _target_ortho_size: float = 10.5
var _target_position: Vector3 = Vector3.ZERO
var _active_touches: Dictionary = {}
var _last_pinch_distance: float = -1.0


func _ready() -> void:
	ensure_setup()


func _process(delta: float) -> void:
	ensure_setup()

	var weight: float = clampf(1.0 - exp(-smoothing_speed * delta), 0.0, 1.0)
	_pivot.position = _pivot.position.lerp(_target_position, weight)
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, deg_to_rad(_target_yaw_degrees), weight)
	_pivot.rotation.x = lerpf(_pivot.rotation.x, deg_to_rad(pitch_degrees), weight)
	_camera.size = lerpf(_camera.size, _target_ortho_size, weight)
	_update_camera_offset()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMagnifyGesture:
		_handle_magnify_gesture(event as InputEventMagnifyGesture)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)


## Ensures the CameraPivot and IsometricCamera nodes exist and are configured.
## Safe to call before or after _ready().
func ensure_setup() -> void:
	if _pivot == null or not is_instance_valid(_pivot):
		var existing_pivot := get_node_or_null(PIVOT_NODE_NAME)
		if existing_pivot is Node3D:
			_pivot = existing_pivot as Node3D
		else:
			_pivot = Node3D.new()
			_pivot.name = PIVOT_NODE_NAME
			add_child(_pivot)

	_pivot.rotation_order = EULER_ORDER_YXZ

	if _camera == null or not is_instance_valid(_camera):
		var existing_camera := _pivot.get_node_or_null(CAMERA_NODE_NAME)
		if existing_camera is Camera3D:
			_camera = existing_camera as Camera3D
		else:
			_camera = Camera3D.new()
			_camera.name = CAMERA_NODE_NAME
			_pivot.add_child(_camera)

	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = near_clip
	_camera.far = far_clip
	_camera.position = Vector3(0.0, 0.0, camera_distance)
	_camera.rotation = Vector3.ZERO

	if not _is_setup:
		_is_setup = true
		_target_yaw_degrees = _compute_yaw_for_step(_step_index)
		_target_ortho_size = clampf(default_size, min_size, max_size)
		_target_position = Vector3.ZERO
		apply_immediate()


## Rotates the camera horizontally in 90-degree increments wrapped to [0..3].
func rotate_step(step_delta: int) -> void:
	ensure_setup()
	_step_index = posmod(_step_index + step_delta, ROTATION_STEP_COUNT)
	_target_yaw_degrees = _compute_yaw_for_step(_step_index)


## Adjusts the target orthographic size. Negative delta zooms in; positive delta zooms out.
func zoom_step(zoom_delta: float) -> void:
	ensure_setup()
	_target_ortho_size = clampf(_target_ortho_size + zoom_delta, min_size, max_size)


## Convenience helper to zoom in by one button step.
func zoom_in() -> void:
	zoom_step(-button_zoom_step)


## Convenience helper to zoom out by one button step.
func zoom_out() -> void:
	zoom_step(button_zoom_step)


## Resets target focus position and zoom while preserving the current 90-degree yaw step.
func recenter() -> void:
	ensure_setup()
	_target_position = Vector3.ZERO
	_target_ortho_size = clampf(default_size, min_size, max_size)


## Adapts default zoom and zoom bounds to frame 8x8, 12x12, 16x16, or 32x32 boards comfortably.
func adapt_to_grid_size(size: int) -> void:
	ensure_setup()
	if size <= 8:
		min_size = 5.0
		max_size = 16.0
		default_size = 9.5
		camera_distance = 25.0
	elif size >= 32:
		min_size = 8.0
		max_size = 48.0
		default_size = 32.0
		camera_distance = 36.0
	elif size >= 16:
		min_size = 7.0
		max_size = 26.0
		default_size = 17.5
		camera_distance = 25.0
	else:
		min_size = 6.0
		max_size = 19.5
		default_size = 13.0
		camera_distance = 25.0

	_target_position = Vector3.ZERO
	_target_ortho_size = clampf(default_size, min_size, max_size)
	apply_immediate()


func set_grid_size(size: int) -> void:
	adapt_to_grid_size(size)


func apply_tuning(p_orbit_sensitivity: float, p_min_size: float, p_max_size: float, p_smoothing_speed: float) -> void:
	orbit_sensitivity = maxf(p_orbit_sensitivity, 0.1)
	min_size = maxf(p_min_size, 1.0)
	max_size = maxf(p_max_size, min_size + 1.0)
	smoothing_speed = maxf(p_smoothing_speed, 1.0)
	_target_ortho_size = clampf(_target_ortho_size, min_size, max_size)


## Immediately snaps pivot transform, camera size, and lateral offset to current targets.
func apply_immediate() -> void:
	ensure_setup()
	_pivot.position = _target_position
	_pivot.rotation = Vector3(deg_to_rad(pitch_degrees), deg_to_rad(_target_yaw_degrees), 0.0)
	_camera.position = Vector3(0.0, 0.0, camera_distance)
	_camera.size = _target_ortho_size
	_update_camera_offset()


## Returns the wrapped 90-degree rotation step index in [0..3].
func get_current_step_index() -> int:
	return _step_index


## Returns the target horizontal yaw in degrees (45, 135, 225, or 315).
func get_target_yaw_degrees() -> float:
	ensure_setup()
	return _target_yaw_degrees


## Returns the target orthographic size.
func get_target_ortho_size() -> float:
	ensure_setup()
	return _target_ortho_size


## Returns the managed orthographic Camera3D instance.
func get_camera() -> Camera3D:
	ensure_setup()
	return _camera


func _compute_yaw_for_step(step_index: int) -> float:
	return base_yaw_degrees + float(posmod(step_index, ROTATION_STEP_COUNT)) * 90.0


func _update_camera_offset() -> void:
	if _camera == null:
		return

	var aspect_ratio := DEFAULT_ASPECT_RATIO
	if is_inside_tree() and get_viewport() != null:
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			aspect_ratio = viewport_size.x / viewport_size.y

	# Center the world origin in the remaining (1 - tray_width_ratio) right workspace.
	var shift_fraction: float = tray_width_ratio * 0.5
	if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
		_camera.h_offset = -shift_fraction * _camera.size
	else:
		_camera.h_offset = -shift_fraction * _camera.size * aspect_ratio


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if not event.pressed:
		_active_touches.erase(event.index)
		_last_pinch_distance = _compute_pinch_distance() if _active_touches.size() == 2 else -1.0
		return

	if is_interaction_locked:
		return

	_active_touches[event.index] = event.position
	_last_pinch_distance = _compute_pinch_distance() if _active_touches.size() == 2 else -1.0


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if is_interaction_locked:
		_last_pinch_distance = -1.0
		return

	if not _active_touches.has(event.index):
		return

	_active_touches[event.index] = event.position
	if _active_touches.size() != 2:
		_last_pinch_distance = -1.0
		return

	var current_distance: float = _compute_pinch_distance()
	if _last_pinch_distance > MIN_PINCH_DISTANCE_PX and current_distance > MIN_PINCH_DISTANCE_PX:
		ensure_setup()
		var ratio: float = clampf(_last_pinch_distance / current_distance, 0.2, 5.0)
		_target_ortho_size = clampf(_target_ortho_size * ratio, min_size, max_size)
		_mark_input_handled()

	_last_pinch_distance = current_distance


func _handle_magnify_gesture(event: InputEventMagnifyGesture) -> void:
	if is_interaction_locked:
		return

	if event.factor <= 0.01:
		return

	ensure_setup()
	_target_ortho_size = clampf(_target_ortho_size / event.factor, min_size, max_size)
	_mark_input_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if is_interaction_locked or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_step(-mouse_wheel_zoom_step)
		_mark_input_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_step(mouse_wheel_zoom_step)
		_mark_input_handled()


func _compute_pinch_distance() -> float:
	if _active_touches.size() != 2:
		return -1.0
	var positions: Array = _active_touches.values()
	var first: Vector2 = positions[0]
	var second: Vector2 = positions[1]
	return first.distance_to(second)


func _mark_input_handled() -> void:
	if is_inside_tree() and get_viewport() != null:
		get_viewport().set_input_as_handled()
