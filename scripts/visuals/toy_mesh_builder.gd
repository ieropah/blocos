class_name ToyMeshBuilder
extends RefCounted
## Procedural builder for watertight, smoothly beveled toy block meshes and contact shadows.
##
## All piece meshes place their origin (0, 0, 0) at the center of the bottom face:
## X in [-size.x * 0.5, size.x * 0.5], Y in [0.0, size.y], Z in [-size.z * 0.5, size.z * 0.5].

const _EPSILON: float = 1e-6
const _VOXEL_TEX_SIZE: int = 16

static var _texture_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


## Purges all cached meshes, materials, and procedural textures to free VRAM/RAM on theme switch.
static func clear_cache() -> void:
	_mesh_cache.clear()
	_material_cache.clear()
	_texture_cache.clear()


static func is_voxel_piece(piece_type: String) -> bool:
	return piece_type.begins_with("voxel_")


static func is_tintable_voxel_piece(piece_type: String) -> bool:
	return piece_type in [
		"voxel_wool", "voxel_wool_slab", "voxel_pillar", "voxel_corner",
		"voxel_eye", "voxel_mouth",
		"voxel_eye_cute", "voxel_eye_angry", "voxel_glasses",
		"voxel_mouth_smile", "voxel_snout", "voxel_ears",
		"voxel_belly", "voxel_hair_crown",
	]


## Convenience alias for cached mesh lookup/creation used by interaction and workspace controllers.
static func get_or_build_mesh(
	piece_id: String,
	size: Vector3 = Vector3.ONE,
	theme_id: String = "plastic",
	color_hex: String = ""
) -> ArrayMesh:
	return create_piece_mesh(piece_id, size, 0.045, 3, theme_id, color_hex)


static func create_piece_mesh(
	piece_type: String,
	size: Vector3,
	bevel: float = 0.045,
	segments: int = 3,
	theme_id: String = "",
	color_hex: String = ""
) -> ArrayMesh:
	var cache_key: String = "%s|%.4f,%.4f,%.4f|%.4f|%d|%s|%s" % [
		piece_type, size.x, size.y, size.z, bevel, segments, theme_id, color_hex
	]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key] as ArrayMesh

	var mesh: ArrayMesh
	if is_voxel_piece(piece_type):
		var tint := Color(color_hex) if not color_hex.is_empty() else Color.WHITE
		mesh = create_voxel_box(size, piece_type, tint)
	elif piece_type == "ramp":
		mesh = create_beveled_ramp(size, bevel, segments)
	elif piece_type == "cylinder":
		mesh = _create_plastic_cylinder(size)
	elif piece_type == "cone":
		mesh = _create_plastic_cone(size)
	elif piece_type == "roof_gable":
		mesh = _create_plastic_roof_gable(size)
	elif piece_type == "arch_bridge":
		mesh = _create_plastic_arch_bridge(size, bevel, segments)
	elif piece_type == "corner_block":
		mesh = _create_plastic_corner_block(size, bevel, segments)
	elif piece_type == "plastic_eye":
		mesh = _create_plastic_eye(size, bevel, segments)
	else:
		mesh = create_beveled_box(size, bevel, segments)
	_mesh_cache[cache_key] = mesh
	return mesh


## Returns a MeshInstance3D using the exact cached Mesh and cached Material for GPU instancing.
static func create_cached_mesh_instance(
	piece_id: String,
	size: Vector3,
	color_hex: String = "#FFFFFF",
	theme_id: String = "plastic",
	bevel: float = 0.045,
	segments: int = 3
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = create_piece_mesh(piece_id, size, bevel, segments, theme_id, color_hex)
	if not is_voxel_piece(piece_id):
		mi.material_override = get_piece_material(piece_id, color_hex, theme_id)
	return mi


## Builds or retrieves a cached sharp 90-degree blocky voxel mesh with 16x16 pixel-art materials.
static func create_voxel_box(
	size: Vector3 = Vector3.ONE,
	piece_type: String = "voxel_dirt",
	tint_color: Color = Color.WHITE
) -> ArrayMesh:
	var mesh_key: String = "voxel|%s|%.4f,%.4f,%.4f|%s" % [
		piece_type, size.x, size.y, size.z, tint_color.to_html(true)
	]
	if _mesh_cache.has(mesh_key):
		return _mesh_cache[mesh_key] as ArrayMesh

	var result_mesh: ArrayMesh
	if piece_type == "voxel_stairs_wood" or piece_type == "voxel_stairs_stone":
		result_mesh = _create_voxel_stairs(size, piece_type, tint_color)
		_mesh_cache[mesh_key] = result_mesh
		return result_mesh
	if piece_type == "voxel_fence":
		result_mesh = _create_voxel_fence(size, piece_type, tint_color)
		_mesh_cache[mesh_key] = result_mesh
		return result_mesh

	var effective_size: Vector3 = size
	if piece_type == "voxel_slab_stone" or piece_type == "voxel_slab_wood" or piece_type == "voxel_wool_slab":
		effective_size.y = minf(size.y, 0.5) if size.y > _EPSILON else 0.5

	if is_tintable_voxel_piece(piece_type) and piece_type != "voxel_wool" and piece_type != "voxel_wool_slab":
		var char_mesh := _create_voxel_character_mesh(effective_size, piece_type, tint_color)
		_mesh_cache[mesh_key] = char_mesh
		return char_mesh

	var hx: float = effective_size.x * 0.5
	var hy: float = effective_size.y
	var hz: float = effective_size.z * 0.5

	if piece_type == "voxel_grass" or piece_type == "voxel_bookshelf" or piece_type == "voxel_tnt":
		var mesh := ArrayMesh.new()
		var top_mesh := _build_quad_surface([
			[Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3.UP]
		])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_mesh.surface_get_arrays(0))
		mesh.surface_set_material(0, get_voxel_material(piece_type, tint_color, "top"))

		var side_mesh := _build_quad_surface([
			[Vector3(hx, 0.0, hz), Vector3(hx, 0.0, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3.RIGHT],
			[Vector3(-hx, 0.0, -hz), Vector3(-hx, 0.0, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz), Vector3.LEFT],
			[Vector3(-hx, 0.0, hz), Vector3(hx, 0.0, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), Vector3(0.0, 0.0, 1.0)],
			[Vector3(hx, 0.0, -hz), Vector3(-hx, 0.0, -hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(0.0, 0.0, -1.0)],
		])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, side_mesh.surface_get_arrays(0))
		mesh.surface_set_material(1, get_voxel_material(piece_type, tint_color, "side"))

		var bottom_mesh := _build_quad_surface([
			[Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz), Vector3(hx, 0.0, hz), Vector3(-hx, 0.0, hz), Vector3.DOWN]
		])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bottom_mesh.surface_get_arrays(0))
		mesh.surface_set_material(2, get_voxel_material(piece_type, tint_color, "bottom"))
		_mesh_cache[mesh_key] = mesh
		return mesh

	var quads: Array = []
	_append_box_quads(quads, Vector3(-hx, 0.0, -hz), Vector3(hx, hy, hz))
	var all_mesh := _build_quad_surface(quads)
	all_mesh.surface_set_material(0, get_voxel_material(piece_type, tint_color, "all"))
	_mesh_cache[mesh_key] = all_mesh
	return all_mesh


static func _append_box_quads(quads: Array, min_v: Vector3, max_v: Vector3) -> void:
	quads.append([Vector3(min_v.x, max_v.y, max_v.z), Vector3(max_v.x, max_v.y, max_v.z), Vector3(max_v.x, max_v.y, min_v.z), Vector3(min_v.x, max_v.y, min_v.z), Vector3.UP])
	quads.append([Vector3(min_v.x, min_v.y, min_v.z), Vector3(max_v.x, min_v.y, min_v.z), Vector3(max_v.x, min_v.y, max_v.z), Vector3(min_v.x, min_v.y, max_v.z), Vector3.DOWN])
	quads.append([Vector3(max_v.x, min_v.y, max_v.z), Vector3(max_v.x, min_v.y, min_v.z), Vector3(max_v.x, max_v.y, min_v.z), Vector3(max_v.x, max_v.y, max_v.z), Vector3.RIGHT])
	quads.append([Vector3(min_v.x, min_v.y, min_v.z), Vector3(min_v.x, min_v.y, max_v.z), Vector3(min_v.x, max_v.y, max_v.z), Vector3(min_v.x, max_v.y, min_v.z), Vector3.LEFT])
	quads.append([Vector3(min_v.x, min_v.y, max_v.z), Vector3(max_v.x, min_v.y, max_v.z), Vector3(max_v.x, max_v.y, max_v.z), Vector3(min_v.x, max_v.y, max_v.z), Vector3(0.0, 0.0, 1.0)])
	quads.append([Vector3(max_v.x, min_v.y, min_v.z), Vector3(min_v.x, min_v.y, min_v.z), Vector3(min_v.x, max_v.y, min_v.z), Vector3(max_v.x, max_v.y, min_v.z), Vector3(0.0, 0.0, -1.0)])


static func _create_voxel_stairs(size: Vector3, piece_type: String, tint_color: Color) -> ArrayMesh:
	var hx: float = size.x * 0.5
	var hy: float = size.y
	var hz: float = size.z * 0.5
	var mid_y: float = hy * 0.5
	var quads: Array = []
	# Bottom slab (1.0 x 0.5 x 1.0)
	_append_box_quads(quads, Vector3(-hx, 0.0, -hz), Vector3(hx, mid_y, hz))
	# Back upper step (1.0 x 0.5 x 0.5)
	_append_box_quads(quads, Vector3(-hx, mid_y, -hz), Vector3(hx, hy, 0.0))
	var mesh := _build_quad_surface(quads)
	mesh.surface_set_material(0, get_voxel_material(piece_type, tint_color, "all"))
	return mesh


static func get_voxel_detail_material() -> StandardMaterial3D:
	var cache_key: String = "voxel|vertex_detail"
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.4
	mat.metallic = 0.0
	mat.metallic_specular = 0.25
	_material_cache[cache_key] = mat
	return mat


static func _add_colored_box(
	quads: Array,
	quad_colors: Array[Color],
	min_v: Vector3,
	max_v: Vector3,
	col: Color
) -> void:
	_append_box_quads(quads, min_v, max_v)
	for _i in range(6):
		quad_colors.append(col)


static func _build_colored_quad_surface(quads: Array, quad_colors: Array[Color]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in range(quads.size()):
		var q: Array = quads[i]
		var col: Color = quad_colors[i]
		_add_quad(verts, normals, uvs, indices, q[0], q[1], q[2], q[3], q[4])
		for _v in range(4):
			colors.append(col)
	return _build_array_mesh(verts, normals, uvs, colors, indices)


static func _create_voxel_character_mesh(
	size: Vector3,
	piece_type: String,
	tint_color: Color
) -> ArrayMesh:
	var sx: float = size.x
	var sy: float = size.y
	var sz: float = size.z
	var hx: float = sx * 0.5
	var hy: float = sy
	var hz: float = sz * 0.5

	var base_quads: Array = []
	var detail_quads: Array = []
	var detail_colors: Array[Color] = []

	var c_white := Color("#FFFFFF")
	var c_black := Color("#111111")
	var c_red := Color("#FF5252")
	var c_pink := Color("#FF80AB")
	var c_gold := Color("#FFD54F")
	var c_cyan := Color("#4DD0E1")
	var c_blue := Color("#1E88E5")
	var c_dark_mouth := Color("#2A1414")
	var c_sky := Color("#29B6F6")

	match piece_type:
		"voxel_pillar":
			var px: float = 0.25 * sx
			var pz: float = 0.25 * sz
			_append_box_quads(base_quads, Vector3(-px, 0.0, -pz), Vector3(px, hy, pz))
		"voxel_corner":
			_append_box_quads(base_quads, Vector3(-hx, 0.0, -hz), Vector3(hx, hy * 0.5, hz))
			_append_box_quads(base_quads, Vector3(-hx, hy * 0.5, -hz), Vector3(hx, hy, 0.0))
		"voxel_eye_cute", "voxel_eye":
			_append_box_quads(base_quads, Vector3(-hx, 0.0, -hz), Vector3(hx, hy, hz))
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.32 * sx, 0.22 * sy, hz), Vector3(0.32 * sx, 0.78 * sy, hz + 0.12), c_white)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.18 * sx, 0.30 * sy, hz + 0.12), Vector3(0.18 * sx, 0.66 * sy, hz + 0.18), c_black)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.15 * sx, 0.51 * sy, hz + 0.18), Vector3(-0.03 * sx, 0.63 * sy, hz + 0.22), c_white)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.05 * sx, 0.34 * sy, hz + 0.18), Vector3(0.13 * sx, 0.42 * sy, hz + 0.21), c_white)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.30 * sx, 0.82 * sy, hz), Vector3(0.30 * sx, 0.91 * sy, hz + 0.10), c_black)
		"voxel_eye_angry":
			_append_box_quads(base_quads, Vector3(-hx, 0.0, -hz), Vector3(hx, hy, hz))
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.34 * sx, 0.20 * sy, hz), Vector3(0.34 * sx, 0.68 * sy, hz + 0.12), c_white)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.15 * sx, 0.28 * sy, hz + 0.12), Vector3(0.15 * sx, 0.58 * sy, hz + 0.18), c_black)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.05 * sx, 0.38 * sy, hz + 0.18), Vector3(0.05 * sx, 0.48 * sy, hz + 0.21), c_red)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.38 * sx, 0.72 * sy, hz), Vector3(-0.06 * sx, 0.88 * sy, hz + 0.18), c_black)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.06 * sx, 0.62 * sy, hz), Vector3(0.36 * sx, 0.78 * sy, hz + 0.20), c_black)
		"voxel_glasses":
			_append_box_quads(base_quads, Vector3(-hx, 0.0, -hz), Vector3(hx, hy, hz))
			# Left & right rims + bridge
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.44 * sx, 0.34 * sy, hz), Vector3(-0.08 * sx, 0.72 * sy, hz + 0.14), c_black)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.08 * sx, 0.34 * sy, hz), Vector3(0.44 * sx, 0.72 * sy, hz + 0.14), c_black)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.08 * sx, 0.50 * sy, hz), Vector3(0.08 * sx, 0.64 * sy, hz + 0.18), c_black)
			# Cyan reflective lenses + white shine
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.37 * sx, 0.41 * sy, hz + 0.14), Vector3(-0.15 * sx, 0.65 * sy, hz + 0.18), c_cyan)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.15 * sx, 0.41 * sy, hz + 0.14), Vector3(0.37 * sx, 0.65 * sy, hz + 0.18), c_cyan)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.34 * sx, 0.55 * sy, hz + 0.18), Vector3(-0.26 * sx, 0.62 * sy, hz + 0.20), c_white)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.18 * sx, 0.55 * sy, hz + 0.18), Vector3(0.26 * sx, 0.62 * sy, hz + 0.20), c_white)
			# Side temples wrapping along -X and +X faces
			_add_colored_box(detail_quads, detail_colors, Vector3(-(hx + 0.06), 0.52 * sy, -0.15 * sz), Vector3(-hx, 0.64 * sy, hz + 0.18), c_black)
			_add_colored_box(detail_quads, detail_colors, Vector3(hx, 0.52 * sy, -0.15 * sz), Vector3(hx + 0.06, 0.64 * sy, hz + 0.18), c_black)
		"voxel_mouth_smile", "voxel_mouth":
			_append_box_quads(base_quads, Vector3(-hx, 0.0, -hz), Vector3(hx, hy, hz))
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.36 * sx, 0.20 * sy, hz), Vector3(0.36 * sx, 0.62 * sy, hz + 0.08), c_dark_mouth)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.28 * sx, 0.46 * sy, hz + 0.08), Vector3(-0.06 * sx, 0.60 * sy, hz + 0.14), c_white)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.06 * sx, 0.46 * sy, hz + 0.08), Vector3(0.28 * sx, 0.60 * sy, hz + 0.14), c_white)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.22 * sx, 0.18 * sy, hz + 0.08), Vector3(0.22 * sx, 0.36 * sy, hz + 0.16), c_red)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.15 * sx, 0.12 * sy, hz + 0.12), Vector3(0.15 * sx, 0.26 * sy, hz + 0.22), c_pink)
		"voxel_snout":
			_append_box_quads(base_quads, Vector3(-hx, 0.0, -hz), Vector3(hx, hy, hz))
			_append_box_quads(base_quads, Vector3(-0.30 * sx, 0.16 * sy, hz), Vector3(0.30 * sx, 0.61 * sy, hz + 0.35))
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.16 * sx, 0.44 * sy, hz + 0.35), Vector3(0.16 * sx, 0.62 * sy, hz + 0.43), c_black)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.20 * sx, 0.26 * sy, hz + 0.35), Vector3(-0.08 * sx, 0.38 * sy, hz + 0.39), c_red)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.08 * sx, 0.26 * sy, hz + 0.35), Vector3(0.20 * sx, 0.38 * sy, hz + 0.39), c_red)
		"voxel_ears":
			_append_box_quads(base_quads, Vector3(-hx, 0.0, -0.42 * sz), Vector3(hx, 0.16 * sy, 0.42 * sz))
			_append_box_quads(base_quads, Vector3(-0.46 * sx, 0.16 * sy, -0.12 * sz), Vector3(-0.16 * sx, 0.68 * sy, 0.13 * sz))
			_append_box_quads(base_quads, Vector3(0.16 * sx, 0.16 * sy, -0.12 * sz), Vector3(0.46 * sx, 0.68 * sy, 0.13 * sz))
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.39 * sx, 0.24 * sy, 0.13 * sz), Vector3(-0.23 * sx, 0.56 * sy, 0.18 * sz), c_pink)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.23 * sx, 0.24 * sy, 0.13 * sz), Vector3(0.39 * sx, 0.56 * sy, 0.18 * sz), c_pink)
		"voxel_belly":
			_append_box_quads(base_quads, Vector3(-hx, 0.0, -hz), Vector3(hx, hy, hz))
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.28 * sx, 0.72 * sy, hz), Vector3(-0.04 * sx, 0.94 * sy, hz + 0.09), c_white)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.04 * sx, 0.72 * sy, hz), Vector3(0.28 * sx, 0.94 * sy, hz + 0.09), c_white)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.32 * sx, 0.08 * sy, hz), Vector3(-0.16 * sx, 0.96 * sy, hz + 0.08), c_blue)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.16 * sx, 0.08 * sy, hz), Vector3(0.32 * sx, 0.96 * sy, hz + 0.08), c_blue)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.32 * sx, 0.08 * sy, hz), Vector3(0.32 * sx, 0.42 * sy, hz + 0.08), c_blue)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.29 * sx, 0.38 * sy, hz + 0.08), Vector3(-0.19 * sx, 0.48 * sy, hz + 0.15), c_gold)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.19 * sx, 0.38 * sy, hz + 0.08), Vector3(0.29 * sx, 0.48 * sy, hz + 0.15), c_gold)
		"voxel_hair_crown":
			_append_box_quads(base_quads, Vector3(-hx, 0.0, -hz), Vector3(hx, 0.16 * sy, hz))
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.44 * sx, 0.16 * sy, -0.44 * sz), Vector3(0.44 * sx, 0.34 * sy, 0.44 * sz), c_gold)
			# 4 corner peaks + 4 midpoint peaks
			for px_sign: float in [-1.0, 1.0]:
				for pz_sign: float in [-1.0, 1.0]:
					var cx: float = px_sign * 0.35 * sx
					var cz: float = pz_sign * 0.35 * sz
					_add_colored_box(detail_quads, detail_colors, Vector3(cx - 0.09 * sx, 0.34 * sy, cz - 0.09 * sz), Vector3(cx + 0.09 * sx, 0.56 * sy, cz + 0.09 * sz), c_gold)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.08 * sx, 0.34 * sy, 0.28 * sz), Vector3(0.08 * sx, 0.58 * sy, 0.44 * sz), c_gold)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.08 * sx, 0.34 * sy, -0.44 * sz), Vector3(0.08 * sx, 0.58 * sy, -0.28 * sz), c_gold)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.44 * sx, 0.34 * sy, -0.08 * sz), Vector3(-0.28 * sx, 0.58 * sy, 0.08 * sz), c_gold)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.28 * sx, 0.34 * sy, -0.08 * sz), Vector3(0.44 * sx, 0.58 * sy, 0.08 * sz), c_gold)
			# Front ruby & side sapphires
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.09 * sx, 0.20 * sy, 0.44 * sz), Vector3(0.09 * sx, 0.31 * sy, 0.50 * sz), c_red)
			_add_colored_box(detail_quads, detail_colors, Vector3(-0.50 * sx, 0.20 * sy, -0.08 * sz), Vector3(-0.44 * sx, 0.30 * sy, 0.08 * sz), c_sky)
			_add_colored_box(detail_quads, detail_colors, Vector3(0.44 * sx, 0.20 * sy, -0.08 * sz), Vector3(0.50 * sx, 0.30 * sy, 0.08 * sz), c_sky)
		_:
			_append_box_quads(base_quads, Vector3(-hx, 0.0, -hz), Vector3(hx, hy, hz))

	var mesh := ArrayMesh.new()
	var base_surface := _build_quad_surface(base_quads)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base_surface.surface_get_arrays(0))
	mesh.surface_set_material(0, get_voxel_material("voxel_wool", tint_color, "all"))
	if not detail_quads.is_empty():
		var detail_surface := _build_colored_quad_surface(detail_quads, detail_colors)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, detail_surface.surface_get_arrays(0))
		mesh.surface_set_material(1, get_voxel_detail_material())
	return mesh


static func _create_voxel_fence(size: Vector3, piece_type: String, tint_color: Color) -> ArrayMesh:
	var hx: float = size.x * 0.5
	var hy: float = size.y
	var post_half_w: float = 0.125 * size.x
	var rail_half_h: float = 0.075 * hy
	var rail_half_d: float = 0.06 * size.z
	var quads: Array = []
	# Center post (0.25 x 1.0 x 0.25)
	_append_box_quads(quads, Vector3(-post_half_w, 0.0, -post_half_w), Vector3(post_half_w, hy, post_half_w))
	# Two horizontal side bars (1.0 x 0.15 x 0.12) at heights 0.35 and 0.75
	for h_ratio: float in [0.35, 0.75]:
		var cy: float = hy * h_ratio
		_append_box_quads(quads, Vector3(-hx, cy - rail_half_h, -rail_half_d), Vector3(hx, cy + rail_half_h, rail_half_d))
	var mesh := _build_quad_surface(quads)
	mesh.surface_set_material(0, get_voxel_material(piece_type, tint_color, "all"))
	return mesh


static func get_piece_material(
	piece_id: String,
	color_hex: String = "#FFFFFF",
	theme_id: String = "plastic"
) -> StandardMaterial3D:
	if is_voxel_piece(piece_id):
		return get_voxel_material(piece_id, Color.WHITE, "all")

	var mat_key: String = "%s|%s|%s" % [piece_id, color_hex, theme_id]
	if _material_cache.has(mat_key):
		return _material_cache[mat_key] as StandardMaterial3D

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color_hex) if not color_hex.is_empty() else Color.WHITE
	if theme_id == "wood":
		mat.roughness = 0.72
		mat.metallic = 0.0
		mat.metallic_specular = 0.15
	else:
		mat.roughness = 0.35
		mat.metallic = 0.0
		mat.metallic_specular = 0.45
	_material_cache[mat_key] = mat
	return mat


static func get_voxel_material(
	piece_type: String,
	tint_color: Color = Color.WHITE,
	face_role: String = "all"
) -> StandardMaterial3D:
	var tex_key: String = _resolve_voxel_texture_key(piece_type, face_role)
	var is_tintable: bool = is_tintable_voxel_piece(piece_type)
	var is_baked_front: bool = (tex_key == "voxel_eye_front" or tex_key == "voxel_mouth_front")
	var cache_key: String = (
		"voxel|%s|%s" % [tex_key, tint_color.to_html(false)]
		if is_tintable
		else "voxel|%s" % tex_key
	)
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as StandardMaterial3D

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = get_voxel_texture(tex_key, tint_color if is_baked_front else Color.WHITE)
	mat.albedo_color = tint_color if (is_tintable and not is_baked_front) else Color.WHITE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.85
	mat.metallic = 0.0
	mat.metallic_specular = 0.1
	if tex_key == "voxel_glass":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.45)
		mat.roughness = 0.15
	elif tex_key == "voxel_water":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.72)
		mat.roughness = 0.2
	elif tex_key == "voxel_gold":
		mat.roughness = 0.35
		mat.metallic = 0.35
		mat.metallic_specular = 0.6
	_material_cache[cache_key] = mat
	return mat


static func get_voxel_texture(texture_key: String, tint_color: Color = Color.WHITE) -> ImageTexture:
	var is_tinted_face: bool = (texture_key == "voxel_eye_front" or texture_key == "voxel_mouth_front")
	var cache_key: String = "%s|%s" % [texture_key, tint_color.to_html(false)] if is_tinted_face else texture_key
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key] as ImageTexture

	var img := Image.create(_VOXEL_TEX_SIZE, _VOXEL_TEX_SIZE, false, Image.FORMAT_RGBA8)
	match texture_key:
		"voxel_grass_top":
			_paint_voxel_grass_top(img)
		"voxel_grass_board":
			_paint_voxel_grass_board(img)
		"voxel_grass_world":
			_paint_voxel_grass_world(img)
		"voxel_grass_side":
			_paint_voxel_grass_side(img)
		"voxel_pedestal_grid":
			_paint_voxel_pedestal_grid(img)
		"voxel_wool":
			_paint_voxel_wool(img)
		"voxel_eye_front":
			_paint_voxel_eye_front(img, tint_color)
		"voxel_mouth_front":
			_paint_voxel_mouth_front(img, tint_color)
		"voxel_stone":
			_paint_voxel_stone(img)
		"voxel_cobble", "voxel_cobblestone":
			_paint_voxel_cobble(img)
		"voxel_wood":
			_paint_voxel_wood(img)
		"voxel_planks":
			_paint_voxel_planks(img)
		"voxel_leaves":
			_paint_voxel_leaves(img)
		"voxel_brick":
			_paint_voxel_brick(img)
		"voxel_sand":
			_paint_voxel_sand(img)
		"voxel_glass":
			_paint_voxel_glass(img)
		"voxel_water":
			_paint_voxel_water(img)
		"voxel_gold":
			_paint_voxel_gold(img)
		"voxel_bookshelf_side":
			_paint_voxel_bookshelf_side(img)
		"voxel_tnt_side":
			_paint_voxel_tnt_side(img)
		"voxel_tnt_top":
			_paint_voxel_tnt_top(img)
		_:
			_paint_voxel_dirt(img)

	var tex := ImageTexture.create_from_image(img)
	_texture_cache[cache_key] = tex
	return tex


static func _resolve_voxel_texture_key(piece_type: String, face_role: String) -> String:
	match piece_type:
		"voxel_wool", "voxel_wool_slab", "voxel_pillar", "voxel_corner", \
		"voxel_eye", "voxel_mouth", "voxel_eye_cute", "voxel_eye_angry", \
		"voxel_glasses", "voxel_mouth_smile", "voxel_snout", "voxel_ears", \
		"voxel_belly", "voxel_hair_crown":
			return "voxel_wool"
		"voxel_grass":
			if face_role == "top":
				return "voxel_grass_top"
			if face_role == "side":
				return "voxel_grass_side"
			return "voxel_dirt"
		"voxel_bookshelf":
			return "voxel_bookshelf_side" if face_role == "side" else "voxel_planks"
		"voxel_tnt":
			return "voxel_tnt_side" if face_role == "side" else "voxel_tnt_top"
		"voxel_slab_stone":
			return "voxel_stone"
		"voxel_slab_wood", "voxel_stairs_wood", "voxel_fence":
			return "voxel_planks"
		"voxel_stairs_stone":
			return "voxel_cobblestone"
		_:
			return piece_type


static func _build_quad_surface(quads: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for q: Array in quads:
		_add_quad(verts, normals, uvs, indices, q[0], q[1], q[2], q[3], q[4])
	return _build_array_mesh(verts, normals, uvs, PackedColorArray(), indices)


static func _pixel_hash(x: int, y: int, seed_val: int) -> int:
	var h: int = (x * 374761393 + y * 668265263 + seed_val * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


static func _paint_voxel_grass_top(img: Image) -> void:
	var palette: Array[Color] = [
		Color("#5E9D34"), Color("#4C8527"), Color("#6AAE3B"), Color("#54912D")
	]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var idx: int = _pixel_hash(x, y, 11) % palette.size()
			img.set_pixel(x, y, palette[idx])


static func _paint_voxel_grass_board(img: Image) -> void:
	var light_grass := Color("#59B82B")
	var dark_grass := Color("#51AC25")
	var border_grass := Color("#44961C")
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			if x == 0 or y == 0 or x == _VOXEL_TEX_SIZE - 1 or y == _VOXEL_TEX_SIZE - 1:
				img.set_pixel(x, y, border_grass)
			else:
				var checker: int = ((x / 4) + (y / 4)) % 2
				img.set_pixel(x, y, light_grass if checker == 0 else dark_grass)


static func _paint_voxel_grass_world(img: Image) -> void:
	var palette: Array[Color] = [
		Color("#59B82B"), Color("#51AC25"), Color("#5EC02F"), Color("#4CA221")
	]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var idx: int = _pixel_hash(x / 2, y / 2, 19) % palette.size()
			img.set_pixel(x, y, palette[idx])


static func _paint_voxel_pedestal_grid(img: Image) -> void:
	var light_tile := Color("#D8B888")
	var dark_tile := Color("#CCA976")
	var border_tile := Color("#A88454")
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			if x == 0 or y == 0 or x == _VOXEL_TEX_SIZE - 1 or y == _VOXEL_TEX_SIZE - 1:
				img.set_pixel(x, y, border_tile)
			else:
				var checker: int = ((x / 4) + (y / 4)) % 2
				img.set_pixel(x, y, light_tile if checker == 0 else dark_tile)


static func _paint_voxel_wool(img: Image) -> void:
	var shades: Array[Color] = [
		Color(0.90, 0.90, 0.90),
		Color(0.94, 0.94, 0.94),
		Color(0.97, 0.97, 0.97),
		Color(1.00, 1.00, 1.00),
	]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var weave: int = ((x % 2) + (y % 2)) % 2
			var h: int = _pixel_hash(x, y, 211) % 3
			var idx: int = clampi(weave + h, 0, shades.size() - 1)
			img.set_pixel(x, y, shades[idx])


static func _paint_voxel_eye_front(img: Image, bg_tint: Color) -> void:
	_paint_voxel_wool(img)
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var base: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, base * bg_tint)

	var sclera := Color("#FFFFFF")
	var pupil := Color("#1E2430")
	var sparkle := Color("#FFFFFF")
	# Cute 8x8 centered eye block (x: 4..11, y: 4..11)
	for y in range(4, 12):
		for x in range(4, 12):
			img.set_pixel(x, y, sclera)
	# Dark pupil (x: 6..10, y: 6..10)
	for y in range(6, 11):
		for x in range(6, 11):
			img.set_pixel(x, y, pupil)
	# 1px white sparkle at top-left of pupil
	img.set_pixel(6, 6, sparkle)


static func _paint_voxel_mouth_front(img: Image, bg_tint: Color) -> void:
	_paint_voxel_wool(img)
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var base: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, base * bg_tint)

	var lip := Color("#2B1B17")
	var tongue := Color("#FF6B8B")
	# Cute happy pixel smile (y: 7..11, x: 4..11)
	for x in range(4, 12):
		img.set_pixel(x, 8, lip)
	img.set_pixel(4, 7, lip)
	img.set_pixel(11, 7, lip)
	for y in range(9, 12):
		for x in range(5, 11):
			img.set_pixel(x, y, lip)
	for x in range(6, 10):
		img.set_pixel(x, 10, tongue)
		img.set_pixel(x, 11, tongue)


static func _paint_voxel_dirt(img: Image) -> void:
	var palette: Array[Color] = [
		Color("#866043"), Color("#735136"), Color("#966C4A"), Color("#6B4C35")
	]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var idx: int = _pixel_hash(x, y, 23) % palette.size()
			img.set_pixel(x, y, palette[idx])


static func _paint_voxel_grass_side(img: Image) -> void:
	_paint_voxel_dirt(img)
	var grass_palette: Array[Color] = [
		Color("#5E9D34"), Color("#4C8527"), Color("#6AAE3B")
	]
	var edge_shadow := Color("#3E6E20")
	for x in range(_VOXEL_TEX_SIZE):
		var fringe_h: int = 3 + (_pixel_hash(x, 0, 37) % 2)
		for y in range(fringe_h):
			var g_idx: int = _pixel_hash(x, y, 41) % grass_palette.size()
			img.set_pixel(x, y, grass_palette[g_idx])
		if fringe_h < _VOXEL_TEX_SIZE:
			img.set_pixel(x, fringe_h, edge_shadow)


static func _paint_voxel_stone(img: Image) -> void:
	var palette: Array[Color] = [
		Color("#7D7D7D"), Color("#686868"), Color("#8F8F8F")
	]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var is_crack: bool = ((y % 4 == 0) and (_pixel_hash(x, y, 53) % 5 == 0)) or ((x % 5 == 0) and (_pixel_hash(x, y, 59) % 6 == 0))
			if is_crack:
				img.set_pixel(x, y, Color("#585858"))
			else:
				var idx: int = _pixel_hash(x, y, 61) % palette.size()
				img.set_pixel(x, y, palette[idx])


static func _paint_voxel_cobble(img: Image) -> void:
	var mortar := Color("#55595E")
	var stone_palette: Array[Color] = [
		Color("#8E9297"), Color("#7B7F85"), Color("#9EA2A8"), Color("#6E7278")
	]
	for y in range(_VOXEL_TEX_SIZE):
		var row_band: int = y / 4
		var is_h_mortar: bool = (y % 4 == 0)
		var x_offset: int = 4 if (row_band % 2 == 1) else 0
		for x in range(_VOXEL_TEX_SIZE):
			var is_v_mortar: bool = ((x + x_offset) % 8 == 0)
			if is_h_mortar or is_v_mortar:
				img.set_pixel(x, y, mortar)
			else:
				var stone_id: int = _pixel_hash((x + x_offset) / 8, row_band, 107)
				var speck: int = _pixel_hash(x, y, 113) % 5
				var col: Color = stone_palette[(stone_id + (1 if speck == 0 else 0)) % stone_palette.size()]
				img.set_pixel(x, y, col)


static func _paint_voxel_wood(img: Image) -> void:
	var palette: Array[Color] = [
		Color("#9C7F4E"), Color("#785F37"), Color("#B2945E")
	]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var streak: int = _pixel_hash(x, y / 3, 71) % palette.size()
			if _pixel_hash(x, y, 79) % 7 == 0:
				streak = (streak + 1) % palette.size()
			img.set_pixel(x, y, palette[streak])


static func _paint_voxel_leaves(img: Image) -> void:
	var palette: Array[Color] = [
		Color("#3B7A28"), Color("#2D611D"), Color("#4C9135")
	]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var cluster: int = _pixel_hash(x / 2, y / 2, 83) % palette.size()
			var dither: int = (x + y) % 2
			var idx: int = (cluster + dither) % palette.size()
			img.set_pixel(x, y, palette[idx])


static func _paint_voxel_brick(img: Image) -> void:
	var mortar := Color("#C2B9B0")
	var brick_palette: Array[Color] = [
		Color("#B54B3C"), Color("#963B2E"), Color("#C45848")
	]
	for y in range(_VOXEL_TEX_SIZE):
		var row_band: int = y / 4
		var is_h_mortar: bool = (y % 4 == 0)
		var x_offset: int = 4 if (row_band % 2 == 1) else 0
		for x in range(_VOXEL_TEX_SIZE):
			var is_v_mortar: bool = ((x + x_offset) % 8 == 0)
			if is_h_mortar or is_v_mortar:
				img.set_pixel(x, y, mortar)
			else:
				var brick_id: int = _pixel_hash((x + x_offset) / 8, row_band, 97)
				var speck: int = _pixel_hash(x, y, 101) % 4
				var col: Color = brick_palette[(brick_id + (1 if speck == 0 else 0)) % brick_palette.size()]
				img.set_pixel(x, y, col)


static func _paint_voxel_planks(img: Image) -> void:
	var joint := Color("#73532F")
	var palette: Array[Color] = [
		Color("#B88952"), Color("#A77B46"), Color("#C3955D")
	]
	for y in range(_VOXEL_TEX_SIZE):
		var plank_row: int = y / 4
		var is_h_joint: bool = (y % 4 == 0)
		var x_shift: int = 8 if (plank_row % 2 == 1) else 0
		for x in range(_VOXEL_TEX_SIZE):
			var is_v_joint: bool = ((x + x_shift) % 16 == 0)
			if is_h_joint or is_v_joint:
				img.set_pixel(x, y, joint)
			else:
				var grain: int = _pixel_hash(x / 2, y, 131 + plank_row) % palette.size()
				img.set_pixel(x, y, palette[grain])


static func _paint_voxel_sand(img: Image) -> void:
	var palette: Array[Color] = [
		Color("#E5D59B"), Color("#DAC78A"), Color("#EDE0AC"), Color("#CEB97A")
	]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var idx: int = _pixel_hash(x, y, 149) % palette.size()
			img.set_pixel(x, y, palette[idx])


static func _paint_voxel_glass(img: Image) -> void:
	var frame := Color("#BCEEFF")
	var shine := Color("#E8FAFF")
	var interior := Color("#8AD8F5")
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var is_border: bool = (x == 0 or y == 0 or x == _VOXEL_TEX_SIZE - 1 or y == _VOXEL_TEX_SIZE - 1)
			var is_shine: bool = ((x + y == 5 or x + y == 6) and x >= 2 and x <= 5) or ((x + y == 21) and x >= 9 and x <= 12)
			if is_border:
				img.set_pixel(x, y, frame)
			elif is_shine:
				img.set_pixel(x, y, shine)
			else:
				img.set_pixel(x, y, interior)


static func _paint_voxel_water(img: Image) -> void:
	var palette: Array[Color] = [
		Color("#2A7DE1"), Color("#378DF0"), Color("#1E6CCB"), Color("#56A6FA")
	]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			var wave: int = (x + (y / 2) * 3) % 6
			var idx: int = 3 if wave == 0 else (_pixel_hash(x, y, 163) % 3)
			img.set_pixel(x, y, palette[idx])


static func _paint_voxel_gold(img: Image) -> void:
	var border_dark := Color("#C98A12")
	var highlight := Color("#FFF59E")
	var palette: Array[Color] = [
		Color("#F5C831"), Color("#E6B322"), Color("#FCE055")
	]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			if x == 0 or y == 0 or x == _VOXEL_TEX_SIZE - 1 or y == _VOXEL_TEX_SIZE - 1:
				img.set_pixel(x, y, border_dark)
			elif (x >= 2 and x <= 4 and y >= 2 and y <= 4) or (x == 11 and y == 11):
				img.set_pixel(x, y, highlight)
			else:
				var idx: int = _pixel_hash(x / 2, y / 2, 179) % palette.size()
				img.set_pixel(x, y, palette[idx])


static func _paint_voxel_bookshelf_side(img: Image) -> void:
	_paint_voxel_planks(img)
	var shelf_back := Color("#4A3520")
	var book_colors: Array[Color] = [
		Color("#C93B3B"), Color("#3D78C9"), Color("#43A047"), Color("#E0A82E"), Color("#8E44AD")
	]
	for y in range(_VOXEL_TEX_SIZE):
		var in_top_row: bool = (y >= 2 and y <= 6)
		var in_bot_row: bool = (y >= 9 and y <= 13)
		if not in_top_row and not in_bot_row:
			continue
		for x in range(1, _VOXEL_TEX_SIZE - 1):
			if x % 3 == 0:
				img.set_pixel(x, y, shelf_back)
			else:
				var book_idx: int = _pixel_hash(x / 3, 1 if in_top_row else 2, 193) % book_colors.size()
				var col: Color = book_colors[book_idx]
				if y == 2 or y == 9:
					col = col.lightened(0.18)
				img.set_pixel(x, y, col)


static func _paint_voxel_tnt_side(img: Image) -> void:
	var red_a := Color("#D13426")
	var red_b := Color("#B5271B")
	var band := Color("#F4F4F4")
	var text_col := Color("#1E1E22")
	# 3x5 pixel glyphs for T, N, T centered in white band (y in [5..10])
	var t_glyph := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4)]
	var n_glyph := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)]
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			if y >= 5 and y <= 10:
				img.set_pixel(x, y, band)
			elif y == 4 or y == 11:
				img.set_pixel(x, y, Color("#8A1C14"))
			else:
				img.set_pixel(x, y, red_a if (x % 2 == 0) else red_b)
	for p: Vector2i in t_glyph:
		img.set_pixel(2 + p.x, 5 + p.y, text_col)
		img.set_pixel(11 + p.x, 5 + p.y, text_col)
	for p: Vector2i in n_glyph:
		img.set_pixel(6 + p.x, 5 + p.y, text_col)


static func _paint_voxel_tnt_top(img: Image) -> void:
	var red := Color("#C72F22")
	var dark := Color("#4A201A")
	var fuse := Color("#D8D8DC")
	for y in range(_VOXEL_TEX_SIZE):
		for x in range(_VOXEL_TEX_SIZE):
			if x >= 6 and x <= 9 and y >= 6 and y <= 9:
				img.set_pixel(x, y, fuse if ((x + y) % 2 == 0) else dark)
			elif (x % 4 == 0) or (y % 4 == 0):
				img.set_pixel(x, y, dark)
			else:
				img.set_pixel(x, y, red)


static func create_beveled_box(
	size: Vector3,
	bevel: float = 0.045,
	segments: int = 3
) -> ArrayMesh:
	var cache_key: String = "box|%.4f,%.4f,%.4f|%.4f|%d" % [size.x, size.y, size.z, bevel, segments]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key] as ArrayMesh

	var min_dim: float = minf(size.x, minf(size.y, size.z))
	var r: float = clampf(bevel, 0.0, min_dim * 0.35)
	var segs: int = maxi(segments, 1)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var center := Vector3(0.0, size.y * 0.5, 0.0)
	var half := size * 0.5

	if r <= _EPSILON:
		_build_sharp_box(size, center, half, verts, normals, uvs, indices)
	else:
		var inner_half := half - Vector3(r, r, r)
		var xs := _build_bevel_axis_coords(half.x, r, segs)
		var ys := _build_bevel_axis_coords(half.y, r, segs)
		var zs := _build_bevel_axis_coords(half.z, r, segs)

		# +X, -X, +Y, -Y, +Z, -Z faces
		_add_box_face(verts, normals, uvs, indices, center, inner_half, r, zs, ys, half.x, Vector3.RIGHT, 0, size.z, size.y)
		_add_box_face(verts, normals, uvs, indices, center, inner_half, r, zs, ys, -half.x, Vector3.LEFT, 0, size.z, size.y)
		_add_box_face(verts, normals, uvs, indices, center, inner_half, r, xs, zs, half.y, Vector3.UP, 1, size.x, size.z)
		_add_box_face(verts, normals, uvs, indices, center, inner_half, r, xs, zs, -half.y, Vector3.DOWN, 1, size.x, size.z)
		_add_box_face(verts, normals, uvs, indices, center, inner_half, r, xs, ys, half.z, Vector3(0.0, 0.0, 1.0), 2, size.x, size.y)
		_add_box_face(verts, normals, uvs, indices, center, inner_half, r, xs, ys, -half.z, Vector3(0.0, 0.0, -1.0), 2, size.x, size.y)

	var mesh := _build_array_mesh(verts, normals, uvs, PackedColorArray(), indices)
	_mesh_cache[cache_key] = mesh
	return mesh


static func _append_array_mesh_to_buffers(
	source_mesh: ArrayMesh,
	offset: Vector3,
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	if source_mesh.get_surface_count() == 0:
		return
	var arrays: Array = source_mesh.surface_get_arrays(0)
	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base_idx: int = verts.size()
	for i in range(src_verts.size()):
		verts.append(src_verts[i] + offset)
		normals.append(src_norms[i])
		uvs.append(src_uvs[i])
	for idx in src_indices:
		indices.append(base_idx + idx)


static func _append_cylinder_geometry(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	base_center: Vector3,
	bottom_r: float,
	top_r: float,
	height: float,
	radial_segs: int = 18
) -> void:
	var segs: int = maxi(radial_segs, 6)
	var slope_y: float = (bottom_r - top_r) / maxf(height, _EPSILON)
	var base_idx: int = verts.size()
	for i in range(segs + 1):
		var u: float = float(i) / float(segs)
		var angle: float = u * TAU
		var ca: float = cos(angle)
		var sa: float = sin(angle)
		var side_n := Vector3(ca, slope_y, sa).normalized()
		verts.append(base_center + Vector3(ca * bottom_r, 0.0, sa * bottom_r))
		normals.append(side_n)
		uvs.append(Vector2(u, 1.0))
		verts.append(base_center + Vector3(ca * top_r, height, sa * top_r))
		normals.append(side_n)
		uvs.append(Vector2(u, 0.0))

	for i in range(segs):
		var i0: int = base_idx + i * 2
		var i1: int = i0 + 1
		var i2: int = i0 + 2
		var i3: int = i0 + 3
		indices.append(i0)
		indices.append(i2)
		indices.append(i1)
		indices.append(i1)
		indices.append(i2)
		indices.append(i3)

	# Top cap
	if top_r > _EPSILON:
		var top_center_idx: int = verts.size()
		verts.append(base_center + Vector3(0.0, height, 0.0))
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.5, 0.5))
		for i in range(segs + 1):
			var angle: float = (float(i) / float(segs)) * TAU
			var ca: float = cos(angle)
			var sa: float = sin(angle)
			verts.append(base_center + Vector3(ca * top_r, height, sa * top_r))
			normals.append(Vector3.UP)
			uvs.append(Vector2(0.5 + ca * 0.5, 0.5 + sa * 0.5))
		for i in range(segs):
			indices.append(top_center_idx)
			indices.append(top_center_idx + 1 + i)
			indices.append(top_center_idx + 2 + i)

	# Bottom cap
	if bottom_r > _EPSILON:
		var bot_center_idx: int = verts.size()
		verts.append(base_center)
		normals.append(Vector3.DOWN)
		uvs.append(Vector2(0.5, 0.5))
		for i in range(segs + 1):
			var angle: float = (float(i) / float(segs)) * TAU
			var ca: float = cos(angle)
			var sa: float = sin(angle)
			verts.append(base_center + Vector3(ca * bottom_r, 0.0, sa * bottom_r))
			normals.append(Vector3.DOWN)
			uvs.append(Vector2(0.5 + ca * 0.5, 0.5 + sa * 0.5))
		for i in range(segs):
			indices.append(bot_center_idx)
			indices.append(bot_center_idx + 2 + i)
			indices.append(bot_center_idx + 1 + i)


static func _create_plastic_cylinder(size: Vector3) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var radius: float = minf(size.x, size.z) * 0.46
	_append_cylinder_geometry(verts, normals, uvs, indices, Vector3.ZERO, radius, radius, size.y, 20)
	return _build_array_mesh(verts, normals, uvs, PackedColorArray(), indices)


static func _create_plastic_cone(size: Vector3) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var bot_r: float = minf(size.x, size.z) * 0.46
	var top_r: float = minf(size.x, size.z) * 0.12
	_append_cylinder_geometry(verts, normals, uvs, indices, Vector3.ZERO, bot_r, top_r, size.y, 20)
	return _build_array_mesh(verts, normals, uvs, PackedColorArray(), indices)


static func _create_plastic_roof_gable(size: Vector3) -> ArrayMesh:
	var hx: float = size.x * 0.5
	var hy: float = size.y
	var hz: float = size.z * 0.5
	var lip: float = minf(0.08, hy * 0.12)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	# Bottom & side vertical lips
	_add_quad(verts, normals, uvs, indices, Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz), Vector3(hx, 0.0, hz), Vector3(-hx, 0.0, hz), Vector3.DOWN)
	_add_quad(verts, normals, uvs, indices, Vector3(-hx, 0.0, -hz), Vector3(-hx, 0.0, hz), Vector3(-hx, lip, hz), Vector3(-hx, lip, -hz), Vector3.LEFT)
	_add_quad(verts, normals, uvs, indices, Vector3(hx, 0.0, hz), Vector3(hx, 0.0, -hz), Vector3(hx, lip, -hz), Vector3(hx, lip, hz), Vector3.RIGHT)
	# Two pitched roof slopes meeting at ridge (x = 0, y = hy)
	var n_left := Vector3(-(hy - lip), hx, 0.0).normalized()
	var n_right := Vector3(hy - lip, hx, 0.0).normalized()
	_add_quad(verts, normals, uvs, indices, Vector3(-hx, lip, hz), Vector3(0.0, hy, hz), Vector3(0.0, hy, -hz), Vector3(-hx, lip, -hz), n_left)
	_add_quad(verts, normals, uvs, indices, Vector3(0.0, hy, hz), Vector3(hx, lip, hz), Vector3(hx, lip, -hz), Vector3(0.0, hy, -hz), n_right)
	# Front (+Z) and back (-Z) gable pentagons
	_add_quad(verts, normals, uvs, indices, Vector3(-hx, 0.0, hz), Vector3(hx, 0.0, hz), Vector3(hx, lip, hz), Vector3(-hx, lip, hz), Vector3(0.0, 0.0, 1.0))
	_add_tri_face(verts, normals, uvs, indices, Vector3(-hx, lip, hz), Vector3(hx, lip, hz), Vector3(0.0, hy, hz), Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.5, 0.0), Vector3(0.0, 0.0, 1.0))
	_add_quad(verts, normals, uvs, indices, Vector3(hx, 0.0, -hz), Vector3(-hx, 0.0, -hz), Vector3(-hx, lip, -hz), Vector3(hx, lip, -hz), Vector3(0.0, 0.0, -1.0))
	_add_tri_face(verts, normals, uvs, indices, Vector3(hx, lip, -hz), Vector3(-hx, lip, -hz), Vector3(0.0, hy, -hz), Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.5, 0.0), Vector3(0.0, 0.0, -1.0))
	return _build_array_mesh(verts, normals, uvs, PackedColorArray(), indices)


static func _get_vertex_color_material() -> StandardMaterial3D:
	return get_voxel_detail_material()


static func _create_plastic_arch_bridge(
	size: Vector3,
	_bevel: float = 0.045,
	_segments: int = 3
) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var hx: float = size.x * 0.5
	var hy: float = size.y
	var hz: float = size.z * 0.5
	var arch_r: float = minf(hx * 0.62, hy * 0.66)
	var spring_y: float = hy * 0.08
	var segs: int = 10

	# Top, outer left, outer right, and bottom pillar feet
	_add_quad(verts, normals, uvs, indices, Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3.UP)
	_add_quad(verts, normals, uvs, indices, Vector3(-hx, 0.0, -hz), Vector3(-hx, 0.0, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz), Vector3.LEFT)
	_add_quad(verts, normals, uvs, indices, Vector3(hx, 0.0, hz), Vector3(hx, 0.0, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3.RIGHT)
	_add_quad(verts, normals, uvs, indices, Vector3(-hx, 0.0, -hz), Vector3(-arch_r, 0.0, -hz), Vector3(-arch_r, 0.0, hz), Vector3(-hx, 0.0, hz), Vector3.DOWN)
	_add_quad(verts, normals, uvs, indices, Vector3(arch_r, 0.0, -hz), Vector3(hx, 0.0, -hz), Vector3(hx, 0.0, hz), Vector3(arch_r, 0.0, hz), Vector3.DOWN)

	# Inner vertical pillar walls below spring_y
	_add_quad(verts, normals, uvs, indices, Vector3(-arch_r, 0.0, hz), Vector3(-arch_r, 0.0, -hz), Vector3(-arch_r, spring_y, -hz), Vector3(-arch_r, spring_y, hz), Vector3.RIGHT)
	_add_quad(verts, normals, uvs, indices, Vector3(arch_r, 0.0, -hz), Vector3(arch_r, 0.0, hz), Vector3(arch_r, spring_y, hz), Vector3(arch_r, spring_y, -hz), Vector3.LEFT)

	# Front (+Z) and Back (-Z) outer pillar faces (x in [-hx..-arch_r] and [arch_r..hx], y in [0..hy])
	for z_sign: float in [1.0, -1.0]:
		var z_val: float = hz * z_sign
		var f_norm := Vector3(0.0, 0.0, z_sign)
		if z_sign > 0.0:
			_add_quad(verts, normals, uvs, indices, Vector3(-hx, 0.0, z_val), Vector3(-arch_r, 0.0, z_val), Vector3(-arch_r, hy, z_val), Vector3(-hx, hy, z_val), f_norm)
			_add_quad(verts, normals, uvs, indices, Vector3(arch_r, 0.0, z_val), Vector3(hx, 0.0, z_val), Vector3(hx, hy, z_val), Vector3(arch_r, hy, z_val), f_norm)
		else:
			_add_quad(verts, normals, uvs, indices, Vector3(-arch_r, 0.0, z_val), Vector3(-hx, 0.0, z_val), Vector3(-hx, hy, z_val), Vector3(-arch_r, hy, z_val), f_norm)
			_add_quad(verts, normals, uvs, indices, Vector3(hx, 0.0, z_val), Vector3(arch_r, 0.0, z_val), Vector3(arch_r, hy, z_val), Vector3(hx, hy, z_val), f_norm)

	# Semicircular arch vault underside + front/back spandrels
	for i in range(segs):
		var a0: float = PI * float(i) / float(segs)
		var a1: float = PI * float(i + 1) / float(segs)
		var am: float = (a0 + a1) * 0.5
		var x0: float = -cos(a0) * arch_r
		var y0: float = spring_y + sin(a0) * arch_r
		var x1: float = -cos(a1) * arch_r
		var y1: float = spring_y + sin(a1) * arch_r
		var vault_norm := Vector3(cos(am), -sin(am), 0.0).normalized()

		# Underside curved vault quad
		_add_quad(verts, normals, uvs, indices, Vector3(x0, y0, hz), Vector3(x1, y1, hz), Vector3(x1, y1, -hz), Vector3(x0, y0, -hz), vault_norm)
		# Front (+Z) spandrel quad
		_add_quad(verts, normals, uvs, indices, Vector3(x0, y0, hz), Vector3(x1, y1, hz), Vector3(x1, hy, hz), Vector3(x0, hy, hz), Vector3(0.0, 0.0, 1.0))
		# Back (-Z) spandrel quad
		_add_quad(verts, normals, uvs, indices, Vector3(x1, y1, -hz), Vector3(x0, y0, -hz), Vector3(x0, hy, -hz), Vector3(x1, hy, -hz), Vector3(0.0, 0.0, -1.0))

	return _build_array_mesh(verts, normals, uvs, PackedColorArray(), indices)


static func _create_plastic_corner_block(
	size: Vector3,
	bevel: float = 0.045,
	segments: int = 3
) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var bot_box := create_beveled_box(Vector3(size.x, size.y * 0.5, size.z), bevel * 0.8, segments)
	var top_box := create_beveled_box(Vector3(size.x, size.y * 0.5, size.z * 0.5), bevel * 0.8, segments)
	_append_array_mesh_to_buffers(bot_box, Vector3.ZERO, verts, normals, uvs, indices)
	_append_array_mesh_to_buffers(top_box, Vector3(0.0, size.y * 0.5, -size.z * 0.25), verts, normals, uvs, indices)
	return _build_array_mesh(verts, normals, uvs, PackedColorArray(), indices)


static func _create_plastic_eye(
	size: Vector3,
	bevel: float = 0.045,
	segments: int = 3
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var base_box := create_beveled_box(size, bevel, segments)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base_box.surface_get_arrays(0))

	# Surface 1: 3D embossed cute cartoon eyes on +Z front face (un-tinted vertex colors)
	var sx: float = size.x
	var sy: float = size.y
	var hz: float = size.z * 0.5
	var detail_quads: Array = []
	var detail_colors: Array[Color] = []
	var c_white := Color(1.0, 1.0, 1.0)
	var c_black := Color(0.08, 0.08, 0.08)

	for x_sign: float in [-1.0, 1.0]:
		var cx: float = x_sign * 0.22 * sx
		_add_colored_box(detail_quads, detail_colors, Vector3(cx - 0.16 * sx, 0.28 * sy, hz + 0.002), Vector3(cx + 0.16 * sx, 0.74 * sy, hz + 0.08), c_white)
		_add_colored_box(detail_quads, detail_colors, Vector3(cx - 0.09 * sx, 0.34 * sy, hz + 0.08), Vector3(cx + 0.09 * sx, 0.60 * sy, hz + 0.13), c_black)
		_add_colored_box(detail_quads, detail_colors, Vector3(cx - 0.07 * sx, 0.50 * sy, hz + 0.13), Vector3(cx - 0.01 * sx, 0.57 * sy, hz + 0.155), c_white)

	var detail_surface := _build_colored_quad_surface(detail_quads, detail_colors)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, detail_surface.surface_get_arrays(0))
	mesh.surface_set_material(1, _get_vertex_color_material())
	return mesh


static func create_beveled_ramp(
	size: Vector3,
	bevel: float = 0.04,
	segments: int = 3
) -> ArrayMesh:
	var cache_key: String = "ramp|%.4f,%.4f,%.4f|%.4f|%d" % [size.x, size.y, size.z, bevel, segments]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key] as ArrayMesh

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var hx: float = size.x * 0.5
	var hy: float = size.y
	var hz: float = size.z * 0.5
	var hyp: float = sqrt(size.x * size.x + size.y * size.y)
	var inradius: float = (size.x * size.y) / (size.x + size.y + hyp)
	var r_z: float = clampf(bevel, 0.0, minf(inradius * 0.45, hz * 0.45))
	var segs: int = maxi(segments, 1)

	if r_z <= _EPSILON:
		_build_sharp_ramp(size, hx, hy, hz, verts, normals, uvs, indices)
		var sharp_mesh := _build_array_mesh(verts, normals, uvs, PackedColorArray(), indices)
		_mesh_cache[cache_key] = sharp_mesh
		return sharp_mesh

	# Outer right triangle in X-Y plane (CCW): V0 (bottom-left), V1 (bottom-right), V2 (top-right).
	var v0 := Vector2(-hx, 0.0)
	var v1 := Vector2(hx, 0.0)
	var v2 := Vector2(hx, hy)

	# Inner triangle inset by r_z from all 3 edges.
	var c0 := Vector2(-hx + r_z * (size.x + hyp) / size.y, r_z)
	var c1 := Vector2(hx - r_z, r_z)
	var c2 := Vector2(hx - r_z, hy - r_z * (size.y + hyp) / size.x)

	var n_bottom := Vector2(0.0, -1.0)
	var n_back := Vector2(1.0, 0.0)
	var n_slope := Vector2(-size.y, size.x).normalized()

	var outer_corners: Array[Vector2] = [v0, v1, v2]
	var inner_corners: Array[Vector2] = [c0, c1, c2]
	var prev_normals: Array[Vector2] = [n_slope, n_bottom, n_back]
	var next_normals: Array[Vector2] = [n_bottom, n_back, n_slope]

	var outer_edge_lens := _triangle_corner_min_adj_edges(v0, v1, v2)
	var inner_edge_lens := _triangle_corner_min_adj_edges(c0, c1, c2)

	var outer_pts := PackedVector2Array()
	var inner_pts := PackedVector2Array()
	var loop_normals := PackedVector2Array()

	for corner_idx in range(3):
		var n_prev: Vector2 = prev_normals[corner_idx]
		var n_next: Vector2 = next_normals[corner_idx]
		var turn_angle: float = acos(clampf(n_prev.dot(n_next), -1.0, 1.0))
		var gamma: float = PI - turn_angle
		var tan_half_gamma: float = tan(gamma * 0.5)

		# Tangent setback distance d <= r_z keeps arc radius <= r_z on all right-triangle corners.
		var d_out: float = minf(r_z, outer_edge_lens[corner_idx] * 0.30)
		var d_in: float = minf(d_out * 0.40, inner_edge_lens[corner_idx] * 0.25)

		var arc_r_out: float = d_out * tan_half_gamma
		var arc_r_in: float = d_in * tan_half_gamma

		var t_prev_dir := Vector2(-n_prev.y, n_prev.x)
		var o_out: Vector2 = outer_corners[corner_idx] - t_prev_dir * d_out - n_prev * arc_r_out
		var o_in: Vector2 = inner_corners[corner_idx] - t_prev_dir * d_in - n_prev * arc_r_in

		for s in range(segs + 1):
			var frac: float = float(s) / float(segs)
			var n2d: Vector2 = n_prev.rotated(frac * turn_angle).normalized()
			outer_pts.append(o_out + n2d * arc_r_out)
			inner_pts.append(o_in + n2d * arc_r_in)
			loop_normals.append(n2d)

	var n_loop: int = outer_pts.size()
	var u_coords := PackedFloat32Array()
	u_coords.resize(n_loop + 1)
	u_coords[0] = 0.0
	var perimeter: float = 0.0
	for i in range(n_loop):
		var next_i: int = (i + 1) % n_loop
		perimeter += outer_pts[i].distance_to(outer_pts[next_i])
		u_coords[i + 1] = perimeter
	if perimeter > _EPSILON:
		for i in range(n_loop + 1):
			u_coords[i] /= perimeter

	# Build rings along Z: -Z bevel (phi PI/2 -> 0), then +Z bevel (phi 0 -> PI/2).
	var ring_starts := PackedInt32Array()
	var z_inner: float = hz - r_z

	for j in range(segs, -1, -1):
		var phi: float = (float(j) / float(segs)) * (PI * 0.5)
		ring_starts.append(verts.size())
		_append_ramp_bevel_ring(
			verts, normals, uvs,
			outer_pts, inner_pts, loop_normals, u_coords,
			phi, -1.0, z_inner, r_z, size.z
		)

	for j in range(0, segs + 1):
		var phi: float = (float(j) / float(segs)) * (PI * 0.5)
		ring_starts.append(verts.size())
		_append_ramp_bevel_ring(
			verts, normals, uvs,
			outer_pts, inner_pts, loop_normals, u_coords,
			phi, 1.0, z_inner, r_z, size.z
		)

	var num_rings: int = ring_starts.size()
	for r_idx in range(num_rings - 1):
		var base_a: int = ring_starts[r_idx]
		var base_b: int = ring_starts[r_idx + 1]
		for i in range(n_loop):
			var a0: int = base_a + i
			var a1: int = base_a + i + 1
			var b0: int = base_b + i
			var b1: int = base_b + i + 1
			var out_n0: Vector3 = (normals[a0] + normals[a1] + normals[b1]).normalized()
			_emit_tri_oriented(indices, verts, a0, a1, b1, out_n0)
			var out_n1: Vector3 = (normals[a0] + normals[b1] + normals[b0]).normalized()
			_emit_tri_oriented(indices, verts, a0, b1, b0, out_n1)

	# Flat +Z and -Z end caps using inner profile points.
	_append_ramp_z_cap(verts, normals, uvs, indices, inner_pts, size, hz, 1.0)
	_append_ramp_z_cap(verts, normals, uvs, indices, inner_pts, size, -hz, -1.0)

	var ramp_mesh := _build_array_mesh(verts, normals, uvs, PackedColorArray(), indices)
	var ramp_key: String = "ramp|%.4f,%.4f,%.4f|%.4f|%d" % [size.x, size.y, size.z, bevel, segments]
	_mesh_cache[ramp_key] = ramp_mesh
	return ramp_mesh


static func create_contact_shadow_mesh(footprint_x: float, footprint_z: float) -> ArrayMesh:
	var cache_key: String = "shadow|%.4f,%.4f" % [footprint_x, footprint_z]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key] as ArrayMesh
	var fx: float = maxf(footprint_x, 0.05)
	var fz: float = maxf(footprint_z, 0.05)
	var inset: float = minf(0.03, minf(fx, fz) * 0.1)
	var inner_hx: float = fx * 0.5 - inset
	var inner_hz: float = fz * 0.5 - inset
	var outer_hx: float = fx * 0.5 + 0.08
	var outer_hz: float = fz * 0.5 + 0.08
	var y: float = 0.003

	var inner_color := Color(0.08, 0.06, 0.04, 0.22)
	var outer_color := Color(0.08, 0.06, 0.04, 0.0)

	var verts := PackedVector3Array([
		Vector3(-inner_hx, y, -inner_hz),
		Vector3(inner_hx, y, -inner_hz),
		Vector3(inner_hx, y, inner_hz),
		Vector3(-inner_hx, y, inner_hz),
		Vector3(-outer_hx, y, -outer_hz),
		Vector3(outer_hx, y, -outer_hz),
		Vector3(outer_hx, y, outer_hz),
		Vector3(-outer_hx, y, outer_hz),
	])

	var normals := PackedVector3Array()
	normals.resize(8)
	for i in range(8):
		normals[i] = Vector3.UP

	var colors := PackedColorArray([
		inner_color, inner_color, inner_color, inner_color,
		outer_color, outer_color, outer_color, outer_color,
	])

	var uvs := PackedVector2Array([
		Vector2(0.15, 0.15), Vector2(0.85, 0.15), Vector2(0.85, 0.85), Vector2(0.15, 0.85),
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])

	var indices := PackedInt32Array()
	_emit_tri_oriented(indices, verts, 0, 1, 2, Vector3.UP)
	_emit_tri_oriented(indices, verts, 0, 2, 3, Vector3.UP)

	for i in range(4):
		var next_i: int = (i + 1) % 4
		var in0: int = i
		var in1: int = next_i
		var out0: int = 4 + i
		var out1: int = 4 + next_i
		_emit_tri_oriented(indices, verts, out0, out1, in1, Vector3.UP)
		_emit_tri_oriented(indices, verts, out0, in1, in0, Vector3.UP)

	var shadow_mesh := _build_array_mesh(verts, normals, uvs, colors, indices)
	_mesh_cache[cache_key] = shadow_mesh
	return shadow_mesh


static func create_validity_indicator_mesh(
	footprint_x: float,
	footprint_z: float,
	border_width: float = 0.14
) -> ArrayMesh:
	var cache_key: String = "validity|%.4f,%.4f|%.4f" % [footprint_x, footprint_z, border_width]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key] as ArrayMesh
	var fx: float = maxf(footprint_x, 0.05)
	var fz: float = maxf(footprint_z, 0.05)
	var inner_hx: float = maxf(fx * 0.5 - 0.02, 0.05)
	var outer_hx: float = maxf(fx * 0.5 + border_width, inner_hx + 0.005)
	var inner_hz: float = maxf(fz * 0.5 - 0.02, 0.05)
	var outer_hz: float = maxf(fz * 0.5 + border_width, inner_hz + 0.005)
	var mesh := _create_frame_ring_mesh(inner_hx, inner_hz, outer_hx, outer_hz, 0.008)
	_mesh_cache[cache_key] = mesh
	return mesh


static func create_selection_indicator_mesh(
	footprint_x: float,
	footprint_z: float,
	border_width: float = 0.10
) -> ArrayMesh:
	var cache_key: String = "selection|%.4f,%.4f|%.4f" % [footprint_x, footprint_z, border_width]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key] as ArrayMesh
	var fx: float = maxf(footprint_x, 0.05)
	var fz: float = maxf(footprint_z, 0.05)
	var inner_hx: float = fx * 0.5 + 0.01
	var outer_hx: float = maxf(fx * 0.5 + border_width, inner_hx + 0.005)
	var inner_hz: float = fz * 0.5 + 0.01
	var outer_hz: float = maxf(fz * 0.5 + border_width, inner_hz + 0.005)
	var mesh := _create_frame_ring_mesh(inner_hx, inner_hz, outer_hx, outer_hz, 0.012)
	_mesh_cache[cache_key] = mesh
	return mesh


static func _create_frame_ring_mesh(
	inner_hx: float,
	inner_hz: float,
	outer_hx: float,
	outer_hz: float,
	y: float
) -> ArrayMesh:
	var verts := PackedVector3Array([
		Vector3(-inner_hx, y, -inner_hz),
		Vector3(inner_hx, y, -inner_hz),
		Vector3(inner_hx, y, inner_hz),
		Vector3(-inner_hx, y, inner_hz),
		Vector3(-outer_hx, y, -outer_hz),
		Vector3(outer_hx, y, -outer_hz),
		Vector3(outer_hx, y, outer_hz),
		Vector3(-outer_hx, y, outer_hz),
	])

	var normals := PackedVector3Array()
	normals.resize(8)
	for i in range(8):
		normals[i] = Vector3.UP

	var uvs := PackedVector2Array([
		Vector2(0.15, 0.15), Vector2(0.85, 0.15), Vector2(0.85, 0.85), Vector2(0.15, 0.85),
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])

	var indices := PackedInt32Array()
	for i in range(4):
		var next_i: int = (i + 1) % 4
		var in0: int = i
		var in1: int = next_i
		var out0: int = 4 + i
		var out1: int = 4 + next_i
		_emit_tri_oriented(indices, verts, out0, out1, in1, Vector3.UP)
		_emit_tri_oriented(indices, verts, out0, in1, in0, Vector3.UP)

	return _build_array_mesh(verts, normals, uvs, PackedColorArray(), indices)


static func _build_bevel_axis_coords(half_extent: float, r: float, segs: int) -> PackedFloat32Array:
	var coords := PackedFloat32Array()
	var inner: float = maxf(0.0, half_extent - r)

	for i in range(segs + 1):
		var t: float = float(segs - i) / float(segs)
		coords.append(-(inner + r * tan(t * PI * 0.25)))

	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		coords.append(inner + r * tan(t * PI * 0.25))

	return coords


static func _add_box_face(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	center: Vector3,
	inner_half: Vector3,
	r: float,
	u_coords: PackedFloat32Array,
	v_coords: PackedFloat32Array,
	fixed_coord: float,
	face_normal: Vector3,
	axis_kind: int,
	size_u: float,
	size_v: float
) -> void:
	var nu: int = u_coords.size()
	var nv: int = v_coords.size()
	var base_idx: int = verts.size()
	var half_u: float = size_u * 0.5
	var half_v: float = size_v * 0.5

	for j in range(nv):
		var vc: float = v_coords[j]
		var uv_y: float = 1.0 - (vc + half_v) / maxf(size_v, _EPSILON)
		for i in range(nu):
			var uc: float = u_coords[i]
			var uv_x: float = (uc + half_u) / maxf(size_u, _EPSILON)
			var local_outer := Vector3.ZERO
			if axis_kind == 0:
				local_outer = Vector3(fixed_coord, vc, uc)
			elif axis_kind == 1:
				local_outer = Vector3(uc, fixed_coord, vc)
			else:
				local_outer = Vector3(uc, vc, fixed_coord)

			var core_local: Vector3 = local_outer.clamp(-inner_half, inner_half)
			var diff: Vector3 = local_outer - core_local
			var n: Vector3 = diff.normalized() if diff.length_squared() > 1e-12 else face_normal
			verts.append(center + core_local + n * r)
			normals.append(n)
			uvs.append(Vector2(uv_x, uv_y))

	for j in range(nv - 1):
		for i in range(nu - 1):
			var i00: int = base_idx + j * nu + i
			var i10: int = base_idx + j * nu + (i + 1)
			var i01: int = base_idx + (j + 1) * nu + i
			var i11: int = base_idx + (j + 1) * nu + (i + 1)
			var out_n0: Vector3 = (normals[i00] + normals[i10] + normals[i11]).normalized()
			_emit_tri_oriented(indices, verts, i00, i10, i11, out_n0)
			var out_n1: Vector3 = (normals[i00] + normals[i11] + normals[i01]).normalized()
			_emit_tri_oriented(indices, verts, i00, i11, i01, out_n1)


static func _build_sharp_box(
	size: Vector3,
	center: Vector3,
	half: Vector3,
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	var xs := PackedFloat32Array([-half.x, half.x])
	var ys := PackedFloat32Array([-half.y, half.y])
	var zs := PackedFloat32Array([-half.z, half.z])
	_add_box_face(verts, normals, uvs, indices, center, half, 0.0, zs, ys, half.x, Vector3.RIGHT, 0, size.z, size.y)
	_add_box_face(verts, normals, uvs, indices, center, half, 0.0, zs, ys, -half.x, Vector3.LEFT, 0, size.z, size.y)
	_add_box_face(verts, normals, uvs, indices, center, half, 0.0, xs, zs, half.y, Vector3.UP, 1, size.x, size.z)
	_add_box_face(verts, normals, uvs, indices, center, half, 0.0, xs, zs, -half.y, Vector3.DOWN, 1, size.x, size.z)
	_add_box_face(verts, normals, uvs, indices, center, half, 0.0, xs, ys, half.z, Vector3(0.0, 0.0, 1.0), 2, size.x, size.y)
	_add_box_face(verts, normals, uvs, indices, center, half, 0.0, xs, ys, -half.z, Vector3(0.0, 0.0, -1.0), 2, size.x, size.y)


static func _build_sharp_ramp(
	size: Vector3,
	hx: float,
	hy: float,
	hz: float,
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	var n_slope := Vector3(-size.y, size.x, 0.0).normalized()
	# Bottom
	_add_quad(
		verts, normals, uvs, indices,
		Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz),
		Vector3(hx, 0.0, hz), Vector3(-hx, 0.0, hz),
		Vector3.DOWN
	)
	# Back (+X)
	_add_quad(
		verts, normals, uvs, indices,
		Vector3(hx, 0.0, -hz), Vector3(hx, hy, -hz),
		Vector3(hx, hy, hz), Vector3(hx, 0.0, hz),
		Vector3.RIGHT
	)
	# Slope
	_add_quad(
		verts, normals, uvs, indices,
		Vector3(-hx, 0.0, -hz), Vector3(hx, hy, -hz),
		Vector3(hx, hy, hz), Vector3(-hx, 0.0, hz),
		n_slope
	)
	# +Z and -Z side triangles
	_add_tri_face(
		verts, normals, uvs, indices,
		Vector3(-hx, 0.0, hz), Vector3(hx, 0.0, hz), Vector3(hx, hy, hz),
		Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0),
		Vector3(0.0, 0.0, 1.0)
	)
	_add_tri_face(
		verts, normals, uvs, indices,
		Vector3(-hx, 0.0, -hz), Vector3(hx, hy, -hz), Vector3(hx, 0.0, -hz),
		Vector2(0.0, 1.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0),
		Vector3(0.0, 0.0, -1.0)
	)


static func _add_quad(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	out_normal: Vector3
) -> void:
	var base: int = verts.size()
	verts.append_array([p0, p1, p2, p3])
	normals.append_array([out_normal, out_normal, out_normal, out_normal])
	uvs.append_array([Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	_emit_tri_oriented(indices, verts, base, base + 1, base + 2, out_normal)
	_emit_tri_oriented(indices, verts, base, base + 2, base + 3, out_normal)


static func _add_tri_face(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	uv0: Vector2,
	uv1: Vector2,
	uv2: Vector2,
	out_normal: Vector3
) -> void:
	var base: int = verts.size()
	verts.append_array([p0, p1, p2])
	normals.append_array([out_normal, out_normal, out_normal])
	uvs.append_array([uv0, uv1, uv2])
	_emit_tri_oriented(indices, verts, base, base + 1, base + 2, out_normal)


static func _triangle_corner_min_adj_edges(a: Vector2, b: Vector2, c: Vector2) -> Array[float]:
	var lab: float = a.distance_to(b)
	var lbc: float = b.distance_to(c)
	var lca: float = c.distance_to(a)
	return [minf(lca, lab), minf(lab, lbc), minf(lbc, lca)]


static func _append_ramp_bevel_ring(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	outer_pts: PackedVector2Array,
	inner_pts: PackedVector2Array,
	loop_normals: PackedVector2Array,
	u_coords: PackedFloat32Array,
	phi: float,
	z_sign: float,
	z_inner: float,
	r_z: float,
	total_depth: float
) -> void:
	var n_loop: int = outer_pts.size()
	var cos_phi: float = cos(phi)
	var sin_phi: float = sin(phi)
	var z_val: float = z_sign * (z_inner + r_z * sin_phi)
	var v_uv: float = clampf((z_val + total_depth * 0.5) / maxf(total_depth, _EPSILON), 0.0, 1.0)

	for i in range(n_loop + 1):
		var src_i: int = i % n_loop
		var p_in: Vector2 = inner_pts[src_i]
		var p_out: Vector2 = outer_pts[src_i]
		var n2d: Vector2 = loop_normals[src_i]
		var delta: Vector2 = p_out - p_in
		var xy: Vector2 = p_in + delta * cos_phi
		var support: float = maxf(n2d.dot(delta), r_z)
		var n3d := Vector3(
			r_z * cos_phi * n2d.x,
			r_z * cos_phi * n2d.y,
			z_sign * sin_phi * support
		).normalized()
		verts.append(Vector3(xy.x, xy.y, z_val))
		normals.append(n3d)
		uvs.append(Vector2(u_coords[i], v_uv))


static func _append_ramp_z_cap(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	inner_pts: PackedVector2Array,
	size: Vector3,
	z_pos: float,
	z_sign: float
) -> void:
	var n_loop: int = inner_pts.size()
	var centroid := Vector2.ZERO
	for pt in inner_pts:
		centroid += pt
	centroid /= float(n_loop)

	var cap_normal := Vector3(0.0, 0.0, z_sign)
	var center_idx: int = verts.size()
	verts.append(Vector3(centroid.x, centroid.y, z_pos))
	normals.append(cap_normal)
	uvs.append(Vector2(centroid.x / maxf(size.x, _EPSILON) + 0.5, 1.0 - centroid.y / maxf(size.y, _EPSILON)))

	var ring_start: int = verts.size()
	for i in range(n_loop):
		var pt: Vector2 = inner_pts[i]
		verts.append(Vector3(pt.x, pt.y, z_pos))
		normals.append(cap_normal)
		uvs.append(Vector2(pt.x / maxf(size.x, _EPSILON) + 0.5, 1.0 - pt.y / maxf(size.y, _EPSILON)))

	for i in range(n_loop):
		var next_i: int = (i + 1) % n_loop
		_emit_tri_oriented(indices, verts, center_idx, ring_start + i, ring_start + next_i, cap_normal)


static func _emit_tri_oriented(
	indices: PackedInt32Array,
	verts: PackedVector3Array,
	i0: int,
	i1: int,
	i2: int,
	expected_outward_normal: Vector3
) -> void:
	var p0: Vector3 = verts[i0]
	var p1: Vector3 = verts[i1]
	var p2: Vector3 = verts[i2]
	# Godot 4 front faces use clockwise winding when viewed from outside:
	# Plane(p0, p1, p2).normal points along (p2 - p0).cross(p1 - p0).
	var outward_cross: Vector3 = (p2 - p0).cross(p1 - p0)
	if outward_cross.length_squared() <= 1e-12:
		return
	if outward_cross.dot(expected_outward_normal) < 0.0:
		var tmp: int = i1
		i1 = i2
		i2 = tmp
	indices.append(i0)
	indices.append(i1)
	indices.append(i2)


static func _build_array_mesh(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
