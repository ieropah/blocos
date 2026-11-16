class_name UiIconDrawer
extends RefCounted
## Loads, trims, and caches 4x4 sprite sheet tool icons (with flood-fill white
## background removal) and dynamic isometric SVG piece icons for the Toy UI HUD.

const SVG_SCALE: float = 4.0
const PIECE_SVG_SCALE: float = 2.0
const SHEET_GRID_SIZE: int = 4
const SHEET_PATHS: Array[String] = [
	"res://assets/icons/toy_icons_sheet.png",
	"res://assets/icons/toy_icons_sheet.jpg",
	"res://assets/icons/toy_icons_sheet.webp",
]

const SHEET_GRID_COORDS: Dictionary = {
	"home": Vector2i(0, 0),
	"gallery": Vector2i(1, 0),
	"build": Vector2i(2, 0),
	"paint": Vector2i(3, 0),
	"erase": Vector2i(0, 1),
	"rotate": Vector2i(1, 1),
	"trash": Vector2i(2, 1),
	"undo": Vector2i(3, 1),
	"redo": Vector2i(0, 2),
	"orbit_left": Vector2i(1, 2),
	"orbit_right": Vector2i(2, 2),
	"zoom_in": Vector2i(3, 2),
	"zoom_out": Vector2i(0, 3),
	"reset_camera": Vector2i(1, 3),
}

const ICON_ALIASES: Dictionary = {
	"rotate_piece": "rotate",
	"delete_piece": "trash",
	"rotate_left": "orbit_left",
	"rotate_right": "orbit_right",
	"recenter": "reset_camera",
}

const TOOL_SVGS := {
	"home": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M4 10.5V19C4 20.1 4.9 21 6 21H18C19.1 21 20 20.1 20 19V10.5L12 4L4 10.5Z" fill="#FFD166" stroke="#D97706" stroke-width="2.2" stroke-linejoin="round"/>
		<path d="M9.5 21V14.5C9.5 13.7 10.2 13 11 13H13C13.8 13 14.5 13.7 14.5 14.5V21" fill="#38BDF8" stroke="#0284C7" stroke-width="2.2" stroke-linejoin="round"/>
		<path d="M2.5 11.5L11.1 3.6C11.6 3.1 12.4 3.1 12.9 3.6L21.5 11.5" stroke="#EF4444" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
	</svg>""",

	"gallery": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<rect x="3" y="3" width="7.5" height="7.5" rx="2.5" fill="#FF6B6B" stroke="#DC2626" stroke-width="2"/>
		<rect x="13.5" y="3" width="7.5" height="7.5" rx="2.5" fill="#FFD166" stroke="#D97706" stroke-width="2"/>
		<rect x="3" y="13.5" width="7.5" height="7.5" rx="2.5" fill="#4EA8DE" stroke="#0284C7" stroke-width="2"/>
		<rect x="13.5" y="13.5" width="7.5" height="7.5" rx="2.5" fill="#06D6A0" stroke="#059669" stroke-width="2"/>
	</svg>""",

	"build": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M12 3L20 7.5L12 12L4 7.5L12 3Z" fill="#FDE047" stroke="#CA8A04" stroke-width="2" stroke-linejoin="round"/>
		<path d="M4 7.5V16.5L12 21V12L4 7.5Z" fill="#FACC15" stroke="#CA8A04" stroke-width="2" stroke-linejoin="round"/>
		<path d="M20 7.5V16.5L12 21V12L20 7.5Z" fill="#EAB308" stroke="#CA8A04" stroke-width="2" stroke-linejoin="round"/>
	</svg>""",

	"paint": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M18.4 3.6C19.2 2.8 20.5 2.8 21.3 3.6C22.1 4.4 22.1 5.7 21.3 6.5L14 13.8L11.2 11L18.4 3.6Z" fill="#FB923C" stroke="#C2410C" stroke-width="2" stroke-linejoin="round"/>
		<path d="M11.2 11L14 13.8C13.5 16.5 11.8 18.8 9 19.5C6.8 20 4.5 19.5 3 19C4.2 17.8 4.5 16.2 4.8 14.8C5.3 12.2 7.8 10.8 11.2 11Z" fill="#F472B6" stroke="#DB2777" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
	</svg>""",

	"erase": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M14.5 4.5L20.5 10.5C21.3 11.3 21.3 12.7 20.5 13.5L13 21H7.5L3.5 17C2.7 16.2 2.7 14.8 3.5 14L11.5 4.5C12.3 3.7 13.7 3.7 14.5 4.5Z" fill="#FDA4AF" stroke="#E11D48" stroke-width="2.2" stroke-linejoin="round"/>
		<path d="M8.5 9.5L15.5 16.5L13 21H7.5L3.5 17C2.7 16.2 2.7 14.8 3.5 14L8.5 9.5Z" fill="#60A5FA" stroke="#2563EB" stroke-width="2.2" stroke-linejoin="round"/>
		<path d="M12 21H21" stroke="#94A3B8" stroke-width="2.5" stroke-linecap="round"/>
	</svg>""",

	"rotate": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M20 11C19.5 6.8 16 3.5 11.7 3.5C7.9 3.5 4.7 6 3.7 9.5" stroke="#0EA5E9" stroke-width="2.8" stroke-linecap="round"/>
		<path d="M16.5 11H20.5V7" stroke="#0EA5E9" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>
		<path d="M4 13C4.5 17.2 8 20.5 12.3 20.5C16.1 20.5 19.3 18 20.3 14.5" stroke="#0EA5E9" stroke-width="2.8" stroke-linecap="round"/>
		<path d="M7.5 13H3.5V17" stroke="#0EA5E9" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>
		<circle cx="12" cy="12" r="2.5" fill="#FACC15" stroke="#CA8A04" stroke-width="1.5"/>
	</svg>""",

	"trash": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M6 7.5H18L17 19.2C16.9 20.2 16 21 15 21H9C8 21 7.1 20.2 7 19.2L6 7.5Z" fill="#FCA5A5" stroke="#DC2626" stroke-width="2.2" stroke-linejoin="round"/>
		<path d="M4 7.5H20" stroke="#DC2626" stroke-width="2.8" stroke-linecap="round"/>
		<path d="M9.5 7.5V5C9.5 4.2 10.2 3.5 11 3.5H13C13.8 3.5 14.5 4.2 14.5 5V7.5" stroke="#DC2626" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
		<path d="M10 11.5V16.5M14 11.5V16.5" stroke="#DC2626" stroke-width="2.2" stroke-linecap="round"/>
	</svg>""",

	"undo": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M9 14L4 9L9 4" stroke="#F97316" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
		<path d="M4 9H14.5C17.8 9 20.5 11.7 20.5 15C20.5 18.3 17.8 21 14.5 21H10" stroke="#F97316" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
	</svg>""",

	"redo": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M15 14L20 9L15 4" stroke="#F97316" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
		<path d="M20 9H9.5C6.2 9 3.5 11.7 3.5 15C3.5 18.3 6.2 21 9.5 21H14" stroke="#F97316" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
	</svg>""",

	"orbit_left": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M8 8L4 12L8 16" stroke="#8B5CF6" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
		<path d="M4 12H14C17.3 12 20 10.2 20 8C20 5.8 17.3 4 14 4" stroke="#8B5CF6" stroke-width="2.8" stroke-linecap="round"/>
		<circle cx="13" cy="17" r="2.5" fill="#C4B5FD" stroke="#7C3AED" stroke-width="2"/>
	</svg>""",

	"orbit_right": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M16 8L20 12L16 16" stroke="#8B5CF6" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
		<path d="M20 12H10C6.7 12 4 10.2 4 8C4 5.8 6.7 4 10 4" stroke="#8B5CF6" stroke-width="2.8" stroke-linecap="round"/>
		<circle cx="11" cy="17" r="2.5" fill="#C4B5FD" stroke="#7C3AED" stroke-width="2"/>
	</svg>""",

	"zoom_in": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<circle cx="11" cy="11" r="7" fill="#CCFBF1" stroke="#0D9488" stroke-width="2.5"/>
		<path d="M11 8V14M8 11H14" stroke="#0D9488" stroke-width="2.8" stroke-linecap="round"/>
		<path d="M16.5 16.5L20.5 20.5" stroke="#0D9488" stroke-width="3.2" stroke-linecap="round"/>
	</svg>""",

	"zoom_out": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<circle cx="11" cy="11" r="7" fill="#E0F2FE" stroke="#0284C7" stroke-width="2.5"/>
		<path d="M8 11H14" stroke="#0284C7" stroke-width="2.8" stroke-linecap="round"/>
		<path d="M16.5 16.5L20.5 20.5" stroke="#0284C7" stroke-width="3.2" stroke-linecap="round"/>
	</svg>""",

	"reset_camera": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<circle cx="12" cy="12" r="7" fill="#FEF3C7" stroke="#D97706" stroke-width="2.5"/>
		<circle cx="12" cy="12" r="2.8" fill="#F59E0B"/>
		<path d="M12 2.5V5.5M12 18.5V21.5M2.5 12H5.5M18.5 12H21.5" stroke="#D97706" stroke-width="2.6" stroke-linecap="round"/>
	</svg>""",

	"mode_character": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<circle cx="6.5" cy="7" r="3" fill="#FDBA74" stroke="#C2410C" stroke-width="2"/>
		<circle cx="17.5" cy="7" r="3" fill="#FDBA74" stroke="#C2410C" stroke-width="2"/>
		<circle cx="12" cy="13" r="7.5" fill="#FED7AA" stroke="#C2410C" stroke-width="2.2"/>
		<circle cx="9.2" cy="12" r="1.3" fill="#1E293B"/>
		<circle cx="14.8" cy="12" r="1.3" fill="#1E293B"/>
		<circle cx="7.4" cy="14.2" r="1.3" fill="#FB7185"/>
		<circle cx="16.6" cy="14.2" r="1.3" fill="#FB7185"/>
		<path d="M10.2 15.3C11 16.4 13 16.4 13.8 15.3" stroke="#9A3412" stroke-width="1.8" stroke-linecap="round"/>
	</svg>""",

	"mode_animal": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<ellipse cx="6" cy="9.5" rx="2.1" ry="2.7" transform="rotate(-18 6 9.5)" fill="#FBBF24" stroke="#B45309" stroke-width="1.8"/>
		<ellipse cx="10" cy="6.2" rx="2.1" ry="2.7" transform="rotate(-6 10 6.2)" fill="#FBBF24" stroke="#B45309" stroke-width="1.8"/>
		<ellipse cx="14.2" cy="6.2" rx="2.1" ry="2.7" transform="rotate(6 14.2 6.2)" fill="#FBBF24" stroke="#B45309" stroke-width="1.8"/>
		<ellipse cx="18" cy="9.5" rx="2.1" ry="2.7" transform="rotate(18 18 9.5)" fill="#FBBF24" stroke="#B45309" stroke-width="1.8"/>
		<path d="M12 11.2C8.5 11.2 6.2 13.8 6.5 16.8C6.8 19.2 9 20.5 12 20.5C15 20.5 17.2 19.2 17.5 16.8C17.8 13.8 15.5 11.2 12 11.2Z" fill="#FB923C" stroke="#B45309" stroke-width="2"/>
		<ellipse cx="12" cy="16.2" rx="2.6" ry="2" fill="#FED7AA"/>
	</svg>""",

	"mode_vehicle": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M5.5 12L7.5 7.2C7.9 6.3 8.8 5.8 9.8 5.8H14.2C15.2 5.8 16.1 6.3 16.5 7.2L18.5 12H5.5Z" fill="#7DD3FC" stroke="#0284C7" stroke-width="2" stroke-linejoin="round"/>
		<rect x="2.8" y="11.5" width="18.4" height="6" rx="2.5" fill="#EF4444" stroke="#B91C1C" stroke-width="2"/>
		<circle cx="7" cy="17.8" r="2.7" fill="#334155" stroke="#0F172A" stroke-width="1.6"/>
		<circle cx="7" cy="17.8" r="1" fill="#E2E8F0"/>
		<circle cx="17" cy="17.8" r="2.7" fill="#334155" stroke="#0F172A" stroke-width="1.6"/>
		<circle cx="17" cy="17.8" r="1" fill="#E2E8F0"/>
		<circle cx="4.8" cy="14" r="1" fill="#FEF08A"/>
		<circle cx="19.2" cy="14" r="1" fill="#FEF08A"/>
	</svg>""",

	"mode_scenery": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<rect x="4" y="11" width="10" height="9" rx="1.5" fill="#FEF08A" stroke="#CA8A04" stroke-width="2"/>
		<path d="M2.5 11.5L9 5.5L15.5 11.5" fill="#F87171" stroke="#DC2626" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
		<rect x="7.5" y="15" width="3" height="5" rx="0.8" fill="#60A5FA" stroke="#2563EB" stroke-width="1.5"/>
		<rect x="17.8" y="14.5" width="2.4" height="5.5" rx="0.8" fill="#B45309"/>
		<circle cx="19" cy="11" r="4" fill="#4ADE80" stroke="#16A34A" stroke-width="2"/>
	</svg>""",

	"cat_basic": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M12 3L20 7.5L12 12L4 7.5L12 3Z" fill="#93C5FD" stroke="#1D4ED8" stroke-width="2" stroke-linejoin="round"/>
		<path d="M4 7.5V16.5L12 21V12L4 7.5Z" fill="#60A5FA" stroke="#1D4ED8" stroke-width="2" stroke-linejoin="round"/>
		<path d="M20 7.5V16.5L12 21V12L20 7.5Z" fill="#3B82F6" stroke="#1D4ED8" stroke-width="2" stroke-linejoin="round"/>
		<ellipse cx="12" cy="7.2" rx="2.5" ry="1.3" fill="#DBEAFE" stroke="#1D4ED8" stroke-width="1.3"/>
	</svg>""",

	"cat_building": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M5 9V5.5H8V8H10.5V5.5H13.5V8H16V5.5H19V9L18 11V20H6V11L5 9Z" fill="#FDE68A" stroke="#78350F" stroke-width="2" stroke-linejoin="round"/>
		<path d="M6 13H18M6 16.5H18" stroke="#B45309" stroke-width="1.5"/>
		<path d="M10 13V16.5M14 9.5V13M12 16.5V20" stroke="#B45309" stroke-width="1.5"/>
		<rect x="9.5" y="15.5" width="5" height="4.5" rx="2" fill="#92400E"/>
	</svg>""",

	"back_arrow": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M19 12H6" stroke="#1E293B" stroke-width="3.2" stroke-linecap="round"/>
		<path d="M11.5 6.5L5.5 12L11.5 17.5" stroke="#1E293B" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
	</svg>""",

	"cat_creature": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<circle cx="12" cy="12" r="8.5" fill="#FDE047" stroke="#CA8A04" stroke-width="2"/>
		<circle cx="9" cy="10.2" r="1.4" fill="#1E293B"/>
		<circle cx="15" cy="10.2" r="1.4" fill="#1E293B"/>
		<circle cx="6.8" cy="13" r="1.3" fill="#FB7185"/>
		<circle cx="17.2" cy="13" r="1.3" fill="#FB7185"/>
		<path d="M9 14.5C10.2 16.3 13.8 16.3 15 14.5" stroke="#92400E" stroke-width="2" stroke-linecap="round"/>
	</svg>""",

	"cat_vehicle": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M5 12L7 7.5C7.4 6.6 8.3 6 9.3 6H14.7C15.7 6 16.6 6.6 17 7.5L19 12H5Z" fill="#BAE6FD" stroke="#0369A1" stroke-width="1.8" stroke-linejoin="round"/>
		<rect x="3" y="11.5" width="18" height="5.5" rx="2.2" fill="#FFFFFF" stroke="#0F172A" stroke-width="1.8"/>
		<circle cx="7.5" cy="17.5" r="2.6" fill="#334155" stroke="#0F172A" stroke-width="1.6"/>
		<circle cx="7.5" cy="17.5" r="1" fill="#E2E8F0"/>
		<circle cx="16.5" cy="17.5" r="2.6" fill="#334155" stroke="#0F172A" stroke-width="1.6"/>
		<circle cx="16.5" cy="17.5" r="1" fill="#E2E8F0"/>
	</svg>""",

	"theme": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M12 3C7 3 3 6.8 3 11.5C3 14.5 5 16.5 7.5 16.5H9.2C10.1 16.5 10.7 17.3 10.4 18.2C10.1 19.2 10.8 20.5 12.2 20.5C17 20.5 21 16.5 21 11.5C21 6.8 17 3 12 3Z" fill="#FDE68A" stroke="#D97706" stroke-width="2" stroke-linejoin="round"/>
		<circle cx="8" cy="10" r="1.8" fill="#EF4444"/>
		<circle cx="12" cy="7.5" r="1.8" fill="#3B82F6"/>
		<circle cx="16.2" cy="10" r="1.8" fill="#22C55E"/>
		<circle cx="15.5" cy="14" r="1.6" fill="#A855F7"/>
	</svg>""",

	"world_plastic": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<rect x="6" y="5" width="4.5" height="3" rx="1" fill="#60A5FA" stroke="#1D4ED8" stroke-width="1.8"/>
		<rect x="13.5" y="5" width="4.5" height="3" rx="1" fill="#60A5FA" stroke="#1D4ED8" stroke-width="1.8"/>
		<rect x="3.5" y="8" width="17" height="11" rx="2.5" fill="#3B82F6" stroke="#1D4ED8" stroke-width="2.2"/>
		<path d="M6.5 11.5H17.5" stroke="#93C5FD" stroke-width="2" stroke-linecap="round"/>
	</svg>""",

	"world_solid": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M12 3L20 7.5L12 12L4 7.5L12 3Z" fill="#7DD3FC"/>
		<path d="M4 7.5V16.5L12 21V12L4 7.5Z" fill="#0EA5E9"/>
		<path d="M20 7.5V16.5L12 21V12L20 7.5Z" fill="#0369A1"/>
	</svg>""",

	"world_voxel": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<path d="M12 3.5L20 8L12 12.5L4 8L12 3.5Z" fill="#4ADE80" stroke="#15803D" stroke-width="2" stroke-linejoin="round"/>
		<path d="M4 8V16.5L12 21V12.5L4 8Z" fill="#A16207" stroke="#713F12" stroke-width="2" stroke-linejoin="round"/>
		<path d="M20 8V16.5L12 21V12.5L20 8Z" fill="#854D0E" stroke="#713F12" stroke-width="2" stroke-linejoin="round"/>
	</svg>""",

	"world_wood": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
		<rect x="3.5" y="6" width="17" height="12" rx="2.5" fill="#DEB887" stroke="#92400E" stroke-width="2.2"/>
		<path d="M6 10H18M6 14H15" stroke="#B45309" stroke-width="1.8" stroke-linecap="round"/>
		<circle cx="17.5" cy="14" r="1.1" fill="#92400E"/>
	</svg>"""
}

static var _cached_sheet_icons: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _piece_texture_cache: Dictionary = {}
static var _icon_texture_cache: Dictionary = {}
static var _sheet_image: Image = null
static var _sheet_load_attempted: bool = false

static var _thumb_viewport: SubViewport = null
static var _thumb_camera: Camera3D = null
static var _thumb_mesh_instance: MeshInstance3D = null
static var _thumb_queue: Array[Dictionary] = []
static var _thumb_processing: bool = false

const _FALLBACK_PIECE_SIZES: Dictionary = {
	"long_block": Vector3(2.0, 1.0, 1.0),
	"square_plate": Vector3(2.0, 0.5, 2.0),
	"flat_tile_2x1": Vector3(2.0, 0.35, 1.0),
	"arch_bridge": Vector3(2.0, 1.0, 1.0),
	"door_block": Vector3(1.0, 2.0, 1.0),
	"wheel_axle": Vector3(2.0, 1.0, 1.0),
	"siren_light": Vector3(1.0, 0.5, 1.0),
	"voxel_wool_slab": Vector3(1.0, 0.5, 1.0),
	"solid_block_2x1": Vector3(2.0, 1.0, 1.0),
	"solid_block_4x1": Vector3(4.0, 1.0, 1.0),
	"solid_plate_1x1": Vector3(1.0, 0.5, 1.0),
	"solid_plate_2x1": Vector3(2.0, 0.5, 1.0),
	"solid_plate_2x2": Vector3(2.0, 0.5, 2.0),
	"solid_pillar_1x2": Vector3(1.0, 2.0, 1.0),
	"solid_wall_2x2": Vector3(2.0, 2.0, 1.0),
	"solid_slope_2x1": Vector3(2.0, 1.0, 1.0),
	"solid_windshield_2x1": Vector3(2.0, 1.0, 1.0),
	"solid_frame_window": Vector3(2.0, 2.0, 1.0),
	"solid_eye_side": Vector3(1.0, 1.0, 0.25),
	"solid_beak_2x1": Vector3(2.0, 1.0, 1.0),
	"solid_foot_2x1": Vector3(2.0, 0.5, 1.0),
	"solid_wing_2x1": Vector3(2.0, 1.0, 1.0),
	"solid_bumper_2x1": Vector3(2.0, 1.0, 1.0),
	"solid_spoiler_2x1": Vector3(2.0, 0.5, 1.0),
}


## Clears all cached 2D and 3D thumbnail textures (e.g. on theme switch or memory cleanup).
static func clear_cache() -> void:
	_icon_texture_cache.clear()
	_piece_texture_cache.clear()
	_texture_cache.clear()
	_cached_sheet_icons.clear()
	_thumb_queue.clear()


static func get_icon_texture(icon_name: String, _accent_color: Color = Color("#EC4899")) -> ImageTexture:
	var resolved_name: String = ICON_ALIASES.get(icon_name, icon_name)

	if _cached_sheet_icons.has(resolved_name):
		return _cached_sheet_icons[resolved_name] as ImageTexture

	if SHEET_GRID_COORDS.has(resolved_name):
		var sheet_tex := _extract_sheet_icon(resolved_name, SHEET_GRID_COORDS[resolved_name] as Vector2i)
		if sheet_tex != null:
			_cached_sheet_icons[resolved_name] = sheet_tex
			return sheet_tex

	return _get_svg_fallback_texture(resolved_name)


static func get_piece_icon_texture(
	piece_id: String,
	base_color: Color,
	theme_id: String = "plastic"
) -> ImageTexture:
	var color_hex: String = base_color.to_html(false)
	var icon_key: String = "%s_%s_%s" % [theme_id, piece_id, color_hex]
	if _icon_texture_cache.has(icon_key):
		return _icon_texture_cache[icon_key] as ImageTexture

	if ToyMeshBuilder.is_voxel_piece(piece_id):
		var is_tintable: bool = ToyMeshBuilder.is_tintable_voxel_piece(piece_id)
		var voxel_cache_key: String = (
			"%s_%s" % [piece_id, base_color.to_html(false)]
			if is_tintable
			else piece_id
		)
		if _piece_texture_cache.has(voxel_cache_key):
			return _piece_texture_cache[voxel_cache_key] as ImageTexture
		var voxel_tex := _create_voxel_piece_icon(piece_id, base_color)
		if voxel_tex != null:
			_piece_texture_cache[voxel_cache_key] = voxel_tex
			return voxel_tex

	var cache_key: String = "%s_%s" % [piece_id, base_color.to_html(false)]
	if _piece_texture_cache.has(cache_key):
		return _piece_texture_cache[cache_key] as ImageTexture

	var top_hex: String = "#" + base_color.lightened(0.28).to_html(false)
	var left_hex: String = "#" + base_color.lightened(0.04).to_html(false)
	var right_hex: String = "#" + base_color.darkened(0.22).to_html(false)
	var outline_hex: String = "#" + base_color.darkened(0.42).to_html(false)

	if theme_id == "solid" or piece_id.begins_with("solid_"):
		var solid_body: String = _create_solid_piece_icon_svg_body(piece_id, base_color)
		var solid_svg: String = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">%s</svg>' % solid_body
		var solid_img := Image.new()
		if solid_img.load_svg_from_string(solid_svg, PIECE_SVG_SCALE) != OK:
			return null
		var solid_tex := ImageTexture.create_from_image(solid_img)
		_piece_texture_cache[cache_key] = solid_tex
		return solid_tex

	var body: String = ""
	match piece_id:
		"flat_tile_2x1":
			body = (
				'<path d="M 24 22 L 56 38 L 40 46 L 8 30 Z" fill="%s"/>' % top_hex
				+ '<path d="M 8 30 L 40 46 L 40 53 L 8 37 Z" fill="%s"/>' % left_hex
				+ '<path d="M 40 46 L 56 38 L 56 45 L 40 53 Z" fill="%s"/>' % right_hex
				+ '<ellipse cx="24" cy="29" rx="4" ry="2.1" fill="%s" stroke="%s" stroke-width="1.3"/>' % [top_hex, outline_hex]
				+ '<ellipse cx="39" cy="36.5" rx="4" ry="2.1" fill="%s" stroke="%s" stroke-width="1.3"/>' % [top_hex, outline_hex]
				+ '<path d="M 24 22 L 56 38 L 56 45 L 40 53 L 8 37 L 8 30 Z" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % outline_hex
			)
		"cylinder":
			body = (
				'<path d="M 14 20 L 14 44 A 18 9 0 0 0 50 44 L 50 20 Z" fill="%s"/>' % left_hex
				+ '<path d="M 32 29 L 32 53 A 18 9 0 0 0 50 44 L 50 20 Z" fill="%s"/>' % right_hex
				+ '<ellipse cx="32" cy="20" rx="18" ry="9" fill="%s" stroke="%s" stroke-width="1.6"/>' % [top_hex, outline_hex]
				+ '<ellipse cx="32" cy="18" rx="6.5" ry="3.4" fill="%s" stroke="%s" stroke-width="1.5"/>' % [top_hex, outline_hex]
				+ '<path d="M 14 20 L 14 44 A 18 9 0 0 0 50 44 L 50 20" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % outline_hex
			)
		"cone":
			body = (
				'<path d="M 27 14 L 14 44 A 18 9 0 0 0 50 44 L 37 14 Z" fill="%s"/>' % left_hex
				+ '<path d="M 32 15 L 32 53 A 18 9 0 0 0 50 44 L 37 14 Z" fill="%s"/>' % right_hex
				+ '<ellipse cx="32" cy="14" rx="5" ry="2.5" fill="%s" stroke="%s" stroke-width="1.5"/>' % [top_hex, outline_hex]
				+ '<path d="M 27 14 L 14 44 A 18 9 0 0 0 50 44 L 37 14" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % outline_hex
			)
		"roof_gable":
			body = (
				'<path d="M 22 18 L 42 8 L 56 40 L 36 50 Z" fill="%s"/>' % top_hex
				+ '<path d="M 8 36 L 22 18 L 36 50 L 36 53 L 8 39 Z" fill="%s"/>' % left_hex
				+ '<path d="M 36 50 L 56 40 L 56 43 L 36 53 Z" fill="%s"/>' % right_hex
				+ '<path d="M 22 18 L 36 50 L 56 40" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>' % outline_hex
				+ '<path d="M 22 18 L 42 8 L 56 40 L 56 43 L 36 53 L 8 39 L 8 36 Z" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % outline_hex
			)
		"arch_bridge":
			body = (
				'<path d="M 20 12 L 58 31 L 46 37 L 8 18 Z" fill="%s"/>' % top_hex
				+ '<path d="M 8 18 L 46 37 L 46 53 L 37 48.5 L 37 43 A 10 10 0 0 0 17 33 L 17 38.5 L 8 34 Z" fill="%s"/>' % left_hex
				+ '<path d="M 46 37 L 58 31 L 58 47 L 46 53 Z" fill="%s"/>' % right_hex
				+ '<path d="M 17 38.5 L 25 34.5 L 25 32.5 A 6 6 0 0 1 33 36.5" stroke="%s" stroke-width="1.6" fill="none" stroke-linecap="round"/>' % outline_hex
				+ '<path d="M 8 18 L 46 37 L 58 31 M 46 37 L 46 53" stroke="%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>' % outline_hex
				+ '<path d="M 20 12 L 58 31 L 58 47 L 46 53 L 37 48.5 L 37 43 A 10 10 0 0 0 17 33 L 17 38.5 L 8 34 L 8 18 Z" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % outline_hex
			)
		"corner_block":
			body = (
				'<path d="M 32 10 L 43 16 L 21 28 L 10 22 Z" fill="%s"/>' % top_hex
				+ '<path d="M 10 22 L 21 28 L 21 50 L 10 44 Z" fill="%s"/>' % left_hex
				+ '<path d="M 21 28 L 43 16 L 43 28 L 21 40 Z" fill="%s"/>' % right_hex
				+ '<path d="M 21 40 L 43 28 L 54 34 L 32 46 Z" fill="%s"/>' % top_hex
				+ '<path d="M 21 40 L 32 46 L 32 56 L 21 50 Z" fill="%s"/>' % left_hex
				+ '<path d="M 32 46 L 54 34 L 54 44 L 32 56 Z" fill="%s"/>' % right_hex
				+ '<path d="M 32 10 L 43 16 L 43 28 L 54 34 L 54 44 L 32 56 L 10 44 L 10 22 Z" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % outline_hex
			)
		"plastic_eye":
			body = (
				'<path d="M 32 8 L 54 20 L 32 32 L 10 20 Z" fill="%s"/>' % top_hex
				+ '<path d="M 10 20 L 32 32 L 32 56 L 10 44 Z" fill="%s"/>' % left_hex
				+ '<path d="M 32 32 L 54 20 L 54 44 L 32 56 Z" fill="%s"/>' % right_hex
				+ '<ellipse cx="32" cy="18" rx="5.5" ry="2.8" fill="%s" stroke="%s" stroke-width="1.3"/>' % [top_hex, outline_hex]
				+ '<ellipse cx="16.5" cy="34" rx="3.4" ry="5.2" fill="#FFFFFF" stroke="#111111" stroke-width="1.2"/>'
				+ '<ellipse cx="25.5" cy="39" rx="3.4" ry="5.2" fill="#FFFFFF" stroke="#111111" stroke-width="1.2"/>'
				+ '<circle cx="16.8" cy="34.5" r="1.8" fill="#111111"/>'
				+ '<circle cx="25.8" cy="39.5" r="1.8" fill="#111111"/>'
				+ '<path d="M 32 8 L 54 20 L 54 44 L 32 56 L 10 44 L 10 20 Z" fill="none" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>' % outline_hex
			)
		"long_block":
			body = (
				'<path d="M 24 12 L 56 28 L 40 36 L 8 20 Z" fill="%s"/>' % top_hex
				+ '<path d="M 8 20 L 40 36 L 40 54 L 8 38 Z" fill="%s"/>' % left_hex
				+ '<path d="M 40 36 L 56 28 L 56 46 L 40 54 Z" fill="%s"/>' % right_hex
				+ '<path d="M 8 20 L 40 36 L 56 28 M 40 36 L 40 54" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>' % outline_hex
				+ '<path d="M 24 12 L 56 28 L 56 46 L 40 54 L 8 38 L 8 20 Z" fill="none" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>' % outline_hex
			)
		"square_plate":
			body = (
				'<path d="M 32 14 L 58 27 L 32 40 L 6 27 Z" fill="%s"/>' % top_hex
				+ '<path d="M 6 27 L 32 40 L 32 50 L 6 37 Z" fill="%s"/>' % left_hex
				+ '<path d="M 32 40 L 58 27 L 58 37 L 32 50 Z" fill="%s"/>' % right_hex
				+ '<path d="M 6 27 L 32 40 L 58 27 M 32 40 L 32 50" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>' % outline_hex
				+ '<path d="M 32 14 L 58 27 L 58 37 L 32 50 L 6 37 L 6 27 Z" fill="none" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>' % outline_hex
			)
		"ramp":
			body = (
				'<path d="M 10 48 L 52 48 L 52 16 Z" fill="%s"/>' % left_hex
				+ '<path d="M 10 48 L 22 40 L 52 16 L 52 48 Z" fill="%s"/>' % right_hex
				+ '<path d="M 10 48 L 52 16 L 42 10 L 10 38 Z" fill="%s"/>' % top_hex
				+ '<path d="M 10 48 L 52 48 L 52 16 L 42 10 L 10 38 Z" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % outline_hex
			)
		"window_block":
			body = (
				'<rect x="13" y="13" width="38" height="38" rx="5" fill="%s" stroke="%s" stroke-width="3.2"/>' % [left_hex, outline_hex]
				+ '<rect x="18" y="18" width="28" height="28" rx="2.5" fill="#94E0FF" stroke="%s" stroke-width="1.8"/>' % outline_hex
				+ '<path d="M 32 18 V 46 M 18 32 H 46" stroke="%s" stroke-width="2.6" stroke-linecap="round"/>' % left_hex
				+ '<path d="M 21 22 L 26 27" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round"/>'
			)
		"door_block":
			body = (
				'<rect x="17" y="8" width="30" height="48" rx="4" fill="%s" stroke="%s" stroke-width="3.2"/>' % [left_hex, outline_hex]
				+ '<rect x="21" y="12" width="22" height="42" rx="2" fill="#D99E61" stroke="%s" stroke-width="1.8"/>' % outline_hex
				+ '<rect x="24" y="16" width="16" height="14" rx="1.5" fill="#B87A42"/>'
				+ '<rect x="24" y="34" width="16" height="15" rx="1.5" fill="#B87A42"/>'
				+ '<circle cx="39" cy="32" r="2.6" fill="#FFD12E" stroke="#92400E" stroke-width="1.2"/>'
			)
		"fence_rail":
			body = (
				'<rect x="10" y="22" width="44" height="7" rx="2" fill="%s" stroke="%s" stroke-width="2.2"/>' % [top_hex, outline_hex]
				+ '<rect x="10" y="36" width="44" height="7" rx="2" fill="%s" stroke="%s" stroke-width="2.2"/>' % [left_hex, outline_hex]
				+ '<rect x="13" y="12" width="10" height="40" rx="3" fill="%s" stroke="%s" stroke-width="2.8"/>' % [left_hex, outline_hex]
				+ '<rect x="41" y="12" width="10" height="40" rx="3" fill="%s" stroke="%s" stroke-width="2.8"/>' % [right_hex, outline_hex]
			)
		"plastic_mouth_smile":
			body = (
				'<path d="M 32 8 L 54 20 L 32 32 L 10 20 Z" fill="%s"/>' % top_hex
				+ '<path d="M 10 20 L 32 32 L 32 56 L 10 44 Z" fill="%s"/>' % left_hex
				+ '<path d="M 32 32 L 54 20 L 54 44 L 32 56 Z" fill="%s"/>' % right_hex
				+ '<path d="M 14 31 Q 21 43 28 38 L 28 35 Q 21 37 14 31 Z" fill="#BF2633"/>'
				+ '<path d="M 15 32 L 27 36 L 26 39 L 17 36 Z" fill="#FFFFFF"/>'
				+ '<circle cx="13" cy="29" r="2.2" fill="#FF8CA6"/>'
				+ '<circle cx="29" cy="36" r="2.2" fill="#FF8CA6"/>'
				+ '<path d="M 32 8 L 54 20 L 54 44 L 32 56 L 10 44 L 10 20 Z" fill="none" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>' % outline_hex
			)
		"plastic_snout":
			body = (
				'<path d="M 32 8 L 54 20 L 32 32 L 10 20 Z" fill="%s"/>' % top_hex
				+ '<path d="M 10 20 L 32 32 L 32 56 L 10 44 Z" fill="%s"/>' % left_hex
				+ '<path d="M 32 32 L 54 20 L 54 44 L 32 56 Z" fill="%s"/>' % right_hex
				+ '<rect x="14" y="29" width="18" height="14" rx="5" fill="%s" stroke="%s" stroke-width="2.2"/>' % [top_hex, outline_hex]
				+ '<ellipse cx="23" cy="33" rx="4.5" ry="3" fill="#1F1F24"/>'
				+ '<path d="M 32 8 L 54 20 L 54 44 L 32 56 L 10 44 L 10 20 Z" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % outline_hex
			)
		"plastic_ears":
			body = (
				'<rect x="10" y="42" width="44" height="12" rx="4" fill="%s" stroke="%s" stroke-width="2.8"/>' % [left_hex, outline_hex]
				+ '<path d="M 14 42 L 16 14 Q 21 8 26 16 L 28 42 Z" fill="%s" stroke="%s" stroke-width="2.8" stroke-linejoin="round"/>' % [top_hex, outline_hex]
				+ '<path d="M 36 42 L 38 16 Q 43 8 48 14 L 50 42 Z" fill="%s" stroke="%s" stroke-width="2.8" stroke-linejoin="round"/>' % [right_hex, outline_hex]
				+ '<path d="M 18 38 L 19 20 L 24 22 L 24 38 Z" fill="#FFA6BF"/>'
				+ '<path d="M 40 38 L 40 22 L 45 20 L 46 38 Z" fill="#FFA6BF"/>'
			)
		"plastic_paw":
			body = (
				'<path d="M 14 22 Q 14 14 24 14 H 40 Q 50 14 50 22 V 40 Q 52 50 44 50 H 20 Q 12 50 14 40 Z" fill="%s" stroke="%s" stroke-width="3.2"/>' % [left_hex, outline_hex]
				+ '<ellipse cx="20" cy="43" rx="4.2" ry="5" fill="#FFBFD0" stroke="%s" stroke-width="1.6"/>' % outline_hex
				+ '<ellipse cx="32" cy="44" rx="4.5" ry="5.4" fill="#FFBFD0" stroke="%s" stroke-width="1.6"/>' % outline_hex
				+ '<ellipse cx="44" cy="43" rx="4.2" ry="5" fill="#FFBFD0" stroke="%s" stroke-width="1.6"/>' % outline_hex
			)
		"plastic_crown_hat":
			body = (
				'<rect x="12" y="40" width="40" height="12" rx="4" fill="%s" stroke="%s" stroke-width="2.8"/>' % [left_hex, outline_hex]
				+ '<path d="M 14 40 L 12 18 L 24 28 L 32 12 L 40 28 L 52 18 L 50 40 Z" fill="#FFD126" stroke="#B45309" stroke-width="2.6" stroke-linejoin="round"/>'
				+ '<circle cx="32" cy="31" r="4.2" fill="#F2334C" stroke="#991B1B" stroke-width="1.5"/>'
			)
		"wheel_axle":
			body = (
				'<rect x="14" y="22" width="36" height="18" rx="4" fill="%s" stroke="%s" stroke-width="2.8"/>' % [left_hex, outline_hex]
				+ '<circle cx="17" cy="40" r="11" fill="#26262B" stroke="#0F172A" stroke-width="2.4"/>'
				+ '<circle cx="17" cy="40" r="5" fill="#D9E0EB"/>'
				+ '<circle cx="47" cy="40" r="11" fill="#26262B" stroke="#0F172A" stroke-width="2.4"/>'
				+ '<circle cx="47" cy="40" r="5" fill="#D9E0EB"/>'
			)
		"windshield":
			body = (
				'<path d="M 10 44 L 22 18 H 48 L 54 44 Z" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % [left_hex, outline_hex]
				+ '<path d="M 17 40 L 26 22 H 44 L 40 40 Z" fill="#80D9FF" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % outline_hex
				+ '<path d="M 24 36 L 30 25" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round"/>'
			)
		"headlight_bumper":
			body = (
				'<rect x="8" y="18" width="48" height="28" rx="6" fill="%s" stroke="%s" stroke-width="3"/>' % [left_hex, outline_hex]
				+ '<rect x="6" y="40" width="52" height="9" rx="4" fill="%s" stroke="%s" stroke-width="2.6"/>' % [right_hex, outline_hex]
				+ '<circle cx="17" cy="30" r="5.5" fill="#FFEB40" stroke="#CA8A04" stroke-width="2"/>'
				+ '<circle cx="47" cy="30" r="5.5" fill="#FFEB40" stroke="#CA8A04" stroke-width="2"/>'
				+ '<rect x="25" y="24" width="14" height="12" rx="2" fill="#C0C7D1" stroke="#475569" stroke-width="1.6"/>'
				+ '<path d="M 27 28 H 37 M 27 32 H 37" stroke="#334155" stroke-width="1.8" stroke-linecap="round"/>'
			)
		"wing_fin":
			body = (
				'<path d="M 6 38 L 22 20 H 42 L 58 38 L 44 46 H 20 Z" fill="%s" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % [top_hex, outline_hex]
				+ '<path d="M 20 28 H 44" stroke="%s" stroke-width="2" stroke-linecap="round"/>' % left_hex
			)
		"steering_wheel":
			body = (
				'<rect x="10" y="38" width="44" height="14" rx="5" fill="%s" stroke="%s" stroke-width="3"/>' % [left_hex, outline_hex]
				+ '<path d="M 29 38 L 32 28" stroke="#3D424D" stroke-width="5" stroke-linecap="round"/>'
				+ '<ellipse cx="32" cy="24" rx="14" ry="10" fill="none" stroke="#292D36" stroke-width="4.5"/>'
				+ '<path d="M 20 24 H 44" stroke="#3D424D" stroke-width="3.5" stroke-linecap="round"/>'
				+ '<circle cx="32" cy="24" r="4" fill="#EB3842" stroke="#991B1B" stroke-width="1.4"/>'
			)
		"propeller_block":
			body = (
				'<rect x="14" y="14" width="36" height="36" rx="6" fill="%s" stroke="%s" stroke-width="3"/>' % [left_hex, outline_hex]
				+ '<rect x="28.5" y="11" width="7" height="42" rx="3" fill="#383D47" stroke="#0F172A" stroke-width="1.8"/>'
				+ '<rect x="11" y="28.5" width="42" height="7" rx="3" fill="#383D47" stroke="#0F172A" stroke-width="1.8"/>'
				+ '<rect x="28.5" y="11" width="7" height="5" rx="1.5" fill="#FFD926"/>'
				+ '<rect x="28.5" y="48" width="7" height="5" rx="1.5" fill="#FFD926"/>'
				+ '<rect x="11" y="28.5" width="5" height="7" rx="1.5" fill="#FFD926"/>'
				+ '<rect x="48" y="28.5" width="5" height="7" rx="1.5" fill="#FFD926"/>'
				+ '<circle cx="32" cy="32" r="5.5" fill="#D9E0E6" stroke="#334155" stroke-width="2"/>'
			)
		"siren_light":
			body = (
				'<rect x="10" y="38" width="44" height="11" rx="4" fill="%s" stroke="%s" stroke-width="2.8"/>' % [left_hex, outline_hex]
				+ '<rect x="13" y="20" width="15" height="18" rx="4" fill="#FF3340" stroke="#991B1B" stroke-width="2.2"/>'
				+ '<rect x="36" y="20" width="15" height="18" rx="4" fill="#268CFF" stroke="#1E40AF" stroke-width="2.2"/>'
				+ '<rect x="28" y="24" width="8" height="14" rx="2" fill="#F1F5F9" stroke="#64748B" stroke-width="1.6"/>'
			)
		_:
			body = (
				'<path d="M 32 8 L 54 20 L 32 32 L 10 20 Z" fill="%s"/>' % top_hex
				+ '<path d="M 10 20 L 32 32 L 32 56 L 10 44 Z" fill="%s"/>' % left_hex
				+ '<path d="M 32 32 L 54 20 L 54 44 L 32 56 Z" fill="%s"/>' % right_hex
				+ '<path d="M 10 20 L 32 32 L 54 20 M 32 32 L 32 56" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>' % outline_hex
				+ '<path d="M 32 8 L 54 20 L 54 44 L 32 56 L 10 44 L 10 20 Z" fill="none" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>' % outline_hex
			)

	var svg_str: String = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">%s</svg>' % body
	var img := Image.new()
	if img.load_svg_from_string(svg_str, PIECE_SVG_SCALE) != OK:
		return null

	var tex := ImageTexture.create_from_image(img)
	_piece_texture_cache[cache_key] = tex
	return tex


static func _iso_box_svg(
	cx: float,
	cy: float,
	sx: float,
	sy: float,
	sz: float,
	top_hex: String,
	left_hex: String,
	right_hex: String
) -> String:
	# Isometric axes in 64x64 viewBox: +X goes down-right, +Z goes down-left, +Y goes up
	var dx := Vector2(sx, sx * 0.52)
	var dz := Vector2(-sz, sz * 0.52)
	var dy := Vector2(0.0, -sy)
	var base := Vector2(cx, cy)
	var p_top_back := base + dy - dx * 0.5 - dz * 0.5
	var p_top_right := base + dy + dx * 0.5 - dz * 0.5
	var p_top_front := base + dy + dx * 0.5 + dz * 0.5
	var p_top_left := base + dy - dx * 0.5 + dz * 0.5
	var p_bot_left := base - dx * 0.5 + dz * 0.5
	var p_bot_front := base + dx * 0.5 + dz * 0.5
	var p_bot_right := base + dx * 0.5 - dz * 0.5
	return (
		'<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s"/>' % [p_top_back.x, p_top_back.y, p_top_right.x, p_top_right.y, p_top_front.x, p_top_front.y, p_top_left.x, p_top_left.y, top_hex]
		+ '<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s"/>' % [p_top_left.x, p_top_left.y, p_top_front.x, p_top_front.y, p_bot_front.x, p_bot_front.y, p_bot_left.x, p_bot_left.y, left_hex]
		+ '<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s"/>' % [p_top_front.x, p_top_front.y, p_top_right.x, p_top_right.y, p_bot_right.x, p_bot_right.y, p_bot_front.x, p_bot_front.y, right_hex]
	)


static func _create_solid_piece_icon_svg_body(piece_id: String, base_color: Color) -> String:
	var top_hex: String = "#" + base_color.lightened(0.22).to_html(false)
	var left_hex: String = "#" + base_color.to_html(false)
	var right_hex: String = "#" + base_color.darkened(0.22).to_html(false)

	match piece_id:
		"solid_cube":
			return _iso_box_svg(32.0, 44.0, 22.0, 22.0, 22.0, top_hex, left_hex, right_hex)
		"solid_block_2x1", "long_block":
			return _iso_box_svg(32.0, 42.0, 28.0, 16.0, 15.0, top_hex, left_hex, right_hex)
		"solid_block_4x1":
			return _iso_box_svg(32.0, 39.0, 40.0, 12.0, 11.0, top_hex, left_hex, right_hex)
		"solid_plate_1x1":
			return _iso_box_svg(32.0, 40.0, 22.0, 10.0, 22.0, top_hex, left_hex, right_hex)
		"solid_plate_2x1", "flat_tile_2x1":
			return _iso_box_svg(32.0, 39.0, 30.0, 8.0, 16.0, top_hex, left_hex, right_hex)
		"solid_plate_2x2", "square_plate":
			return _iso_box_svg(32.0, 40.0, 26.0, 9.0, 26.0, top_hex, left_hex, right_hex)
		"solid_pillar_1x2":
			return _iso_box_svg(32.0, 49.0, 16.0, 34.0, 16.0, top_hex, left_hex, right_hex)
		"solid_wall_2x2":
			return _iso_box_svg(32.0, 47.0, 28.0, 28.0, 14.0, top_hex, left_hex, right_hex)
		"solid_slope_1x1", "ramp":
			return (
				'<polygon points="10,48 52,16 42,10 10,38" fill="%s"/>' % top_hex
				+ '<polygon points="10,38 10,48 52,48 52,16" fill="%s"/>' % left_hex
				+ '<polygon points="52,16 52,48 42,42 42,10" fill="%s"/>' % right_hex
			)
		"solid_slope_2x1":
			return (
				'<polygon points="6,46 56,22 46,16 6,36" fill="%s"/>' % top_hex
				+ '<polygon points="6,36 6,46 56,46 56,22" fill="%s"/>' % left_hex
				+ '<polygon points="56,22 56,46 46,40 46,16" fill="%s"/>' % right_hex
			)
		"solid_windshield_2x1":
			return (
				'<polygon points="8,44 50,18 40,12 8,34" fill="#93E5FF"/>'
				+ '<polygon points="8,34 8,44 50,44 50,18" fill="%s"/>' % left_hex
				+ '<polygon points="50,18 50,44 40,38 40,12" fill="%s"/>' % right_hex
			)
		"solid_corner_L":
			return (
				_iso_box_svg(32.0, 44.0, 24.0, 11.0, 24.0, top_hex, left_hex, right_hex)
				+ _iso_box_svg(36.0, 31.0, 24.0, 11.0, 12.0, top_hex, left_hex, right_hex)
			)
		"solid_frame_window":
			return (
				'<polygon points="16,12 48,26 48,54 16,40" fill="%s"/>' % left_hex
				+ '<polygon points="16,12 24,8 56,22 48,26" fill="%s"/>' % top_hex
				+ '<polygon points="48,26 56,22 56,50 48,54" fill="%s"/>' % right_hex
				+ '<polygon points="24,22 40,29 40,44 24,37" fill="#DDF6FF"/>'
			)
		"solid_eye_side":
			return (
				'<rect x="14" y="14" width="36" height="36" fill="#FFFFFF"/>'
				+ '<rect x="24" y="24" width="16" height="16" fill="#1A1C24"/>'
			)
		"solid_eye_front", "plastic_eye":
			return (
				_iso_box_svg(32.0, 44.0, 22.0, 22.0, 22.0, top_hex, left_hex, right_hex)
				+ '<polygon points="14,29 26,35 26,47 14,41" fill="#FFFFFF"/>'
				+ '<polygon points="17.5,33.5 22.5,36 22.5,42 17.5,39.5" fill="#1A1C24"/>'
			)
		"solid_beak_2x1":
			return _iso_box_svg(32.0, 40.0, 32.0, 12.0, 14.0, "#FFE066", "#F59E0B", "#B45309")
		"solid_foot_2x1":
			return (
				_iso_box_svg(32.0, 45.0, 28.0, 9.0, 16.0, top_hex, left_hex, right_hex)
				+ _iso_box_svg(26.0, 36.0, 14.0, 8.0, 14.0, top_hex, left_hex, right_hex)
			)
		"solid_wing_2x1":
			return (
				_iso_box_svg(32.0, 42.0, 28.0, 11.0, 14.0, top_hex, left_hex, right_hex)
				+ _iso_box_svg(36.0, 31.0, 18.0, 9.0, 12.0, top_hex, left_hex, right_hex)
			)
		"solid_tail_step":
			return (
				_iso_box_svg(32.0, 44.0, 24.0, 11.0, 20.0, top_hex, left_hex, right_hex)
				+ _iso_box_svg(25.0, 33.0, 12.0, 12.0, 18.0, top_hex, left_hex, right_hex)
			)
		"solid_wheel_block", "wheel_axle":
			return (
				_iso_box_svg(32.0, 40.0, 22.0, 20.0, 22.0, top_hex, left_hex, right_hex)
				+ '<polygon points="13,30 27,37 27,52 13,45" fill="#23252C"/>'
				+ '<polygon points="17,36 23,39 23,46 17,43" fill="#EEF2F6"/>'
			)
		"solid_bumper_2x1":
			return (
				_iso_box_svg(32.0, 42.0, 30.0, 12.0, 16.0, top_hex, left_hex, right_hex)
				+ '<polygon points="12,35 28,43 28,48 12,40" fill="#CBD5E1"/>'
			)
		"solid_fender":
			return (
				_iso_box_svg(32.0, 44.0, 22.0, 11.0, 22.0, top_hex, left_hex, right_hex)
				+ _iso_box_svg(27.0, 33.0, 22.0, 11.0, 11.0, top_hex, left_hex, right_hex)
			)
		"solid_light_1x1":
			return _iso_box_svg(32.0, 42.0, 18.0, 16.0, 18.0, "#FEF08A", "#FACC15", "#CA8A04")
		"solid_spoiler_2x1":
			return (
				_iso_box_svg(32.0, 43.0, 10.0, 12.0, 10.0, right_hex, left_hex, right_hex)
				+ _iso_box_svg(32.0, 31.0, 34.0, 7.0, 14.0, top_hex, left_hex, right_hex)
			)
		"roof_gable":
			return (
				'<path d="M 22 18 L 42 8 L 56 40 L 36 50 Z" fill="%s"/>' % top_hex
				+ '<path d="M 8 36 L 22 18 L 36 50 L 36 53 L 8 39 Z" fill="%s"/>' % left_hex
				+ '<path d="M 36 50 L 56 40 L 56 43 L 36 53 Z" fill="%s"/>' % right_hex
			)
		_:
			return _iso_box_svg(32.0, 44.0, 22.0, 22.0, 22.0, top_hex, left_hex, right_hex)


static func _create_voxel_piece_icon(piece_id: String, base_color: Color = Color.WHITE) -> ImageTexture:
	var size_px: int = 128
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var top_key: String = piece_id
	var side_key: String = piece_id
	var left_override_img: Image = null
	var tint_col: Color = Color.WHITE
	match piece_id:
		"voxel_grass":
			top_key = "voxel_grass_top"
			side_key = "voxel_grass_side"
		"voxel_bookshelf":
			top_key = "voxel_planks"
			side_key = "voxel_bookshelf_side"
		"voxel_tnt":
			top_key = "voxel_tnt_top"
			side_key = "voxel_tnt_side"
		"voxel_slab_stone":
			top_key = "voxel_stone"
			side_key = "voxel_stone"
		"voxel_slab_wood", "voxel_stairs_wood", "voxel_fence":
			top_key = "voxel_planks"
			side_key = "voxel_planks"
		"voxel_stairs_stone":
			top_key = "voxel_cobblestone"
			side_key = "voxel_cobblestone"
		"voxel_wool", "voxel_wool_slab", "voxel_pillar", "voxel_corner", \
		"voxel_eye", "voxel_mouth", "voxel_eye_cute", "voxel_eye_angry", \
		"voxel_glasses", "voxel_mouth_smile", "voxel_snout", "voxel_ears", \
		"voxel_belly", "voxel_hair_crown":
			top_key = "voxel_wool"
			side_key = "voxel_wool"
			tint_col = base_color

	var top_img: Image = ToyMeshBuilder.get_voxel_texture(top_key).get_image()
	var side_img: Image = ToyMeshBuilder.get_voxel_texture(side_key).get_image()

	var face_alpha: float = 1.0
	if piece_id == "voxel_glass":
		face_alpha = 0.62
	elif piece_id == "voxel_water":
		face_alpha = 0.78

	if piece_id == "voxel_slab_stone" or piece_id == "voxel_slab_wood" or piece_id == "voxel_wool_slab":
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(64.0, 39.0), Vector2(110.0, 64.0), Vector2(64.0, 89.0), Vector2(18.0, 64.0),
			Vector2(18.0, 89.0), Vector2(64.0, 114.0),
			1.0, 1.0, 0.5, tint_col, left_override_img
		)
	elif piece_id == "voxel_pillar":
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(64.0, 26.0), Vector2(87.0, 38.5), Vector2(64.0, 51.0), Vector2(41.0, 38.5),
			Vector2(41.0, 88.5), Vector2(64.0, 101.0),
			1.0, 0.5, 1.0, tint_col
		)
	elif piece_id == "voxel_stairs_wood" or piece_id == "voxel_stairs_stone" or piece_id == "voxel_corner":
		# Back upper step (half depth along +Z/-Z axis, upper half height)
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(64.0, 14.0), Vector2(87.0, 26.5), Vector2(41.0, 51.5), Vector2(18.0, 39.0),
			Vector2(18.0, 89.0), Vector2(41.0, 101.5),
			1.0, 0.5, 1.0, tint_col
		)
		# Front lower step (full depth/half height)
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(87.0, 51.5), Vector2(110.0, 64.0), Vector2(64.0, 89.0), Vector2(41.0, 76.5),
			Vector2(41.0, 101.5), Vector2(64.0, 114.0),
			1.0, 0.5, 0.5, tint_col
		)
	elif piece_id == "voxel_fence":
		# Back/right rail extension
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(70.0, 36.0), Vector2(106.0, 55.0), Vector2(96.0, 61.0), Vector2(60.0, 42.0),
			Vector2(60.0, 52.0), Vector2(96.0, 71.0),
			1.0, 0.25, 0.25
		)
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(70.0, 58.0), Vector2(106.0, 77.0), Vector2(96.0, 83.0), Vector2(60.0, 64.0),
			Vector2(60.0, 74.0), Vector2(96.0, 93.0),
			1.0, 0.25, 0.25
		)
		# Center post
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(64.0, 18.0), Vector2(78.0, 26.0), Vector2(64.0, 34.0), Vector2(50.0, 26.0),
			Vector2(50.0, 96.0), Vector2(64.0, 104.0),
			0.35, 0.35, 1.0
		)
		# Front/left rail extension
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(32.0, 40.0), Vector2(68.0, 59.0), Vector2(58.0, 65.0), Vector2(22.0, 46.0),
			Vector2(22.0, 56.0), Vector2(58.0, 75.0),
			1.0, 0.25, 0.25
		)
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(32.0, 62.0), Vector2(68.0, 81.0), Vector2(58.0, 87.0), Vector2(22.0, 68.0),
			Vector2(22.0, 78.0), Vector2(58.0, 97.0),
			1.0, 0.25, 0.25
		)
	elif piece_id == "voxel_ears":
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(64.0, 56.0), Vector2(110.0, 81.0), Vector2(64.0, 106.0), Vector2(18.0, 81.0),
			Vector2(18.0, 91.0), Vector2(64.0, 116.0),
			1.0, 1.0, 0.2, tint_col
		)
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(42.0, 32.0), Vector2(56.0, 39.5), Vector2(42.0, 47.0), Vector2(28.0, 39.5),
			Vector2(28.0, 72.0), Vector2(42.0, 79.5),
			1.0, 0.4, 0.7, tint_col
		)
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(84.0, 32.0), Vector2(98.0, 39.5), Vector2(84.0, 47.0), Vector2(70.0, 39.5),
			Vector2(70.0, 72.0), Vector2(84.0, 79.5),
			1.0, 0.4, 0.7, tint_col
		)
		_draw_iso_solid_face(img, Vector2(32.0, 45.0), Vector2(39.0, 49.0), Vector2(39.0, 70.0), Vector2(32.0, 66.0), Color("#FF80AB"))
		_draw_iso_solid_face(img, Vector2(74.0, 45.0), Vector2(81.0, 49.0), Vector2(81.0, 70.0), Vector2(74.0, 66.0), Color("#FF80AB"))
	elif piece_id == "voxel_hair_crown":
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(64.0, 52.0), Vector2(110.0, 77.0), Vector2(64.0, 102.0), Vector2(18.0, 77.0),
			Vector2(18.0, 89.0), Vector2(64.0, 114.0),
			1.0, 1.0, 0.2, tint_col
		)
		var gold_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		gold_img.fill(Color("#FFD54F"))
		_draw_iso_prism(
			img, gold_img, gold_img,
			Vector2(64.0, 40.0), Vector2(104.0, 62.0), Vector2(64.0, 84.0), Vector2(24.0, 62.0),
			Vector2(24.0, 78.0), Vector2(64.0, 100.0),
			1.0, 1.0, 0.3, Color.WHITE
		)
		for peak_x: float in [29.0, 45.0, 60.0, 79.0, 95.0]:
			var py: float = 36.0 if peak_x < 65.0 else 38.0
			_draw_iso_solid_face(img, Vector2(peak_x - 4.0, py), Vector2(peak_x + 4.0, py + 4.0), Vector2(peak_x + 4.0, py + 20.0), Vector2(peak_x - 4.0, py + 16.0), Color("#FFD54F"))
		_draw_iso_solid_face(img, Vector2(41.0, 76.0), Vector2(49.0, 80.5), Vector2(49.0, 88.5), Vector2(41.0, 84.0), Color("#FF5252"))
	else:
		_draw_iso_prism(
			img, top_img, side_img,
			Vector2(64.0, 14.0), Vector2(110.0, 39.0), Vector2(64.0, 64.0), Vector2(18.0, 39.0),
			Vector2(18.0, 89.0), Vector2(64.0, 114.0),
			face_alpha, 1.0, 1.0, tint_col, left_override_img
		)
		_draw_voxel_character_icon_overlay(img, piece_id, tint_col)

	return ImageTexture.create_from_image(img)


static func _draw_voxel_character_icon_overlay(img: Image, piece_id: String, tint_col: Color) -> void:
	match piece_id:
		"voxel_eye_cute", "voxel_eye":
			_draw_iso_solid_face(img, Vector2(25.0, 50.0), Vector2(54.0, 66.0), Vector2(54.0, 96.0), Vector2(25.0, 80.0), Color.WHITE)
			_draw_iso_solid_face(img, Vector2(33.0, 59.0), Vector2(47.0, 67.0), Vector2(47.0, 87.0), Vector2(33.0, 79.0), Color("#111111"))
			_draw_iso_solid_face(img, Vector2(34.0, 62.0), Vector2(39.0, 65.0), Vector2(39.0, 71.0), Vector2(34.0, 68.0), Color.WHITE)
		"voxel_eye_angry":
			_draw_iso_solid_face(img, Vector2(25.0, 56.0), Vector2(54.0, 72.0), Vector2(54.0, 96.0), Vector2(25.0, 80.0), Color.WHITE)
			_draw_iso_solid_face(img, Vector2(34.0, 64.0), Vector2(46.0, 70.5), Vector2(46.0, 88.0), Vector2(34.0, 81.5), Color("#111111"))
			_draw_iso_solid_face(img, Vector2(38.0, 71.0), Vector2(42.0, 73.0), Vector2(42.0, 79.0), Vector2(38.0, 77.0), Color("#FF5252"))
			_draw_iso_solid_face(img, Vector2(23.0, 47.0), Vector2(41.0, 57.0), Vector2(41.0, 66.0), Vector2(23.0, 56.0), Color("#111111"))
			_draw_iso_solid_face(img, Vector2(40.0, 60.0), Vector2(56.0, 69.0), Vector2(56.0, 77.0), Vector2(40.0, 68.0), Color("#111111"))
		"voxel_glasses":
			_draw_iso_solid_face(img, Vector2(21.0, 54.0), Vector2(39.0, 64.0), Vector2(39.0, 84.0), Vector2(21.0, 74.0), Color("#111111"))
			_draw_iso_solid_face(img, Vector2(43.0, 66.0), Vector2(61.0, 76.0), Vector2(61.0, 96.0), Vector2(43.0, 86.0), Color("#111111"))
			_draw_iso_solid_face(img, Vector2(38.0, 66.0), Vector2(44.0, 69.5), Vector2(44.0, 76.0), Vector2(38.0, 72.5), Color("#111111"))
			_draw_iso_solid_face(img, Vector2(24.0, 59.0), Vector2(36.0, 65.5), Vector2(36.0, 79.5), Vector2(24.0, 73.0), Color("#4DD0E1"))
			_draw_iso_solid_face(img, Vector2(46.0, 71.0), Vector2(58.0, 77.5), Vector2(58.0, 91.5), Vector2(46.0, 85.0), Color("#4DD0E1"))
		"voxel_mouth_smile", "voxel_mouth":
			_draw_iso_solid_face(img, Vector2(25.0, 64.0), Vector2(57.0, 81.5), Vector2(57.0, 101.5), Vector2(25.0, 84.0), Color("#2A1414"))
			_draw_iso_solid_face(img, Vector2(29.0, 67.0), Vector2(38.0, 72.0), Vector2(38.0, 79.0), Vector2(29.0, 74.0), Color.WHITE)
			_draw_iso_solid_face(img, Vector2(44.0, 75.5), Vector2(53.0, 80.5), Vector2(53.0, 87.5), Vector2(44.0, 82.5), Color.WHITE)
			_draw_iso_solid_face(img, Vector2(34.0, 81.0), Vector2(48.0, 89.0), Vector2(48.0, 99.0), Vector2(34.0, 91.0), Color("#FF80AB"))
		"voxel_snout":
			_draw_iso_solid_face(img, Vector2(25.0, 68.0), Vector2(53.0, 83.5), Vector2(53.0, 102.0), Vector2(25.0, 86.5), tint_col.lightened(0.08))
			_draw_iso_solid_face(img, Vector2(34.0, 73.0), Vector2(44.0, 78.5), Vector2(44.0, 86.5), Vector2(34.0, 81.0), Color("#111111"))
		"voxel_belly":
			_draw_iso_solid_face(img, Vector2(26.0, 56.0), Vector2(34.0, 60.5), Vector2(34.0, 95.0), Vector2(26.0, 90.5), Color("#1E88E5"))
			_draw_iso_solid_face(img, Vector2(48.0, 68.0), Vector2(56.0, 72.5), Vector2(56.0, 107.0), Vector2(48.0, 102.5), Color("#1E88E5"))
			_draw_iso_solid_face(img, Vector2(26.0, 79.0), Vector2(56.0, 95.5), Vector2(56.0, 107.0), Vector2(26.0, 90.5), Color("#1E88E5"))
			_draw_iso_solid_face(img, Vector2(28.0, 75.0), Vector2(33.0, 78.0), Vector2(33.0, 83.0), Vector2(28.0, 80.0), Color("#FFD54F"))
			_draw_iso_solid_face(img, Vector2(49.0, 87.0), Vector2(54.0, 90.0), Vector2(54.0, 95.0), Vector2(49.0, 92.0), Color("#FFD54F"))


static func _draw_iso_solid_face(
	img: Image,
	p00: Vector2,
	p10: Vector2,
	p11: Vector2,
	p01: Vector2,
	col: Color
) -> void:
	var size_px: int = img.get_width()
	var min_x: int = clampi(int(floor(minf(minf(p00.x, p10.x), minf(p11.x, p01.x)))) - 1, 0, size_px - 1)
	var max_x: int = clampi(int(ceil(maxf(maxf(p00.x, p10.x), maxf(p11.x, p01.x)))) + 1, 0, size_px - 1)
	var min_y: int = clampi(int(floor(minf(minf(p00.y, p10.y), minf(p11.y, p01.y)))) - 1, 0, size_px - 1)
	var max_y: int = clampi(int(ceil(maxf(maxf(p00.y, p10.y), maxf(p11.y, p01.y)))) + 1, 0, size_px - 1)
	var outline_col := Color(0.14, 0.14, 0.18, 0.9)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var uv := _solve_parallelogram_uv(Vector2(float(x) + 0.5, float(y) + 0.5), p00, p10 - p00, p01 - p00)
			if uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0:
				var is_edge: bool = uv.x < 0.08 or uv.x > 0.92 or uv.y < 0.08 or uv.y > 0.92
				img.set_pixel(x, y, outline_col if is_edge else col)


static func _draw_iso_prism(
	img: Image,
	top_img: Image,
	side_img: Image,
	p_top: Vector2,
	p_right: Vector2,
	p_center: Vector2,
	p_left: Vector2,
	p_bot_left: Vector2,
	p_bot_center: Vector2,
	face_alpha: float,
	uv_u_scale: float,
	uv_v_scale: float,
	tint_color: Color = Color.WHITE,
	left_override_img: Image = null
) -> void:
	var size_px: int = img.get_width()
	var outline_col := Color(0.14, 0.14, 0.18, 0.92)
	var seam_col := Color(0.14, 0.14, 0.18, 0.55)
	var right_drop: Vector2 = p_bot_center - p_center
	var p_bot_right: Vector2 = p_right + right_drop
	var min_x: int = clampi(int(floor(minf(p_left.x, minf(p_top.x, p_bot_left.x)))) - 1, 0, size_px - 1)
	var max_x: int = clampi(int(ceil(maxf(p_right.x, p_bot_right.x))) + 1, 0, size_px - 1)
	var min_y: int = clampi(int(floor(p_top.y)) - 1, 0, size_px - 1)
	var max_y: int = clampi(int(ceil(p_bot_center.y)) + 1, 0, size_px - 1)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var pt := Vector2(float(x) + 0.5, float(y) + 0.5)
			var uv_top := _solve_parallelogram_uv(pt, p_top, p_right - p_top, p_left - p_top)
			if uv_top.x >= 0.0 and uv_top.x <= 1.0 and uv_top.y >= 0.0 and uv_top.y <= 1.0:
				var tx: int = clampi(int(uv_top.x * 16.0), 0, 15)
				var ty: int = clampi(int(uv_top.y * 16.0 * uv_u_scale), 0, 15)
				var col: Color = top_img.get_pixel(tx, ty) * tint_color * Color(1.06, 1.06, 1.06, 1.0)
				col.a = face_alpha
				if uv_top.x < 0.045 or uv_top.y < 0.045:
					col = outline_col
				elif uv_top.x > 0.955 or uv_top.y > 0.955:
					col = seam_col
				img.set_pixel(x, y, col)
				continue

			var uv_left := _solve_parallelogram_uv(pt, p_left, p_center - p_left, p_bot_left - p_left)
			if uv_left.x >= 0.0 and uv_left.x <= 1.0 and uv_left.y >= 0.0 and uv_left.y <= 1.0:
				var tx: int = clampi(int(uv_left.x * 16.0), 0, 15)
				var ty: int = clampi(int(uv_left.y * 16.0 * uv_v_scale), 0, 15)
				var left_src: Image = left_override_img if left_override_img != null else side_img
				var left_tint: Color = Color.WHITE if left_override_img != null else tint_color
				var col: Color = left_src.get_pixel(tx, ty) * left_tint * Color(0.92, 0.92, 0.92, 1.0)
				col.a = face_alpha
				if uv_left.x < 0.045 or uv_left.y > 0.955:
					col = outline_col
				elif uv_left.x > 0.955 or uv_left.y < 0.045:
					col = seam_col
				img.set_pixel(x, y, col)
				continue

			var uv_right := _solve_parallelogram_uv(pt, p_center, p_right - p_center, p_bot_center - p_center)
			if uv_right.x >= 0.0 and uv_right.x <= 1.0 and uv_right.y >= 0.0 and uv_right.y <= 1.0:
				var tx: int = clampi(int(uv_right.x * 16.0 * uv_u_scale), 0, 15)
				var ty: int = clampi(int(uv_right.y * 16.0 * uv_v_scale), 0, 15)
				var col: Color = side_img.get_pixel(tx, ty) * tint_color * Color(0.76, 0.76, 0.76, 1.0)
				col.a = face_alpha
				if uv_right.x > 0.955 or uv_right.y > 0.955:
					col = outline_col
				elif uv_right.x < 0.045 or uv_right.y < 0.045:
					col = seam_col
				img.set_pixel(x, y, col)


static func _solve_parallelogram_uv(p: Vector2, origin: Vector2, axis_u: Vector2, axis_v: Vector2) -> Vector2:
	var rel: Vector2 = p - origin
	var det: float = axis_u.x * axis_v.y - axis_u.y * axis_v.x
	if absf(det) < 1e-6:
		return Vector2(-1.0, -1.0)
	var u: float = (rel.x * axis_v.y - rel.y * axis_v.x) / det
	var v: float = (axis_u.x * rel.y - axis_u.y * rel.x) / det
	return Vector2(u, v)


static func _get_svg_fallback_texture(resolved_name: String) -> ImageTexture:
	if _texture_cache.has(resolved_name):
		return _texture_cache[resolved_name] as ImageTexture

	if not TOOL_SVGS.has(resolved_name):
		return null

	var svg_str: String = TOOL_SVGS[resolved_name]
	var img := Image.new()
	var err: Error = img.load_svg_from_string(svg_str, SVG_SCALE)
	if err != OK:
		return null

	var tex := ImageTexture.create_from_image(img)
	_texture_cache[resolved_name] = tex
	return tex


static func _ensure_sheet_loaded() -> Image:
	if _sheet_load_attempted:
		return _sheet_image
	_sheet_load_attempted = true

	for path: String in SHEET_PATHS:
		var img: Image = null
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is Texture2D:
				img = (res as Texture2D).get_image()
			elif res is Image:
				img = res as Image
		elif FileAccess.file_exists(path):
			img = Image.load_from_file(ProjectSettings.globalize_path(path))

		if img != null and not img.is_empty():
			_sheet_image = img
			break

	return _sheet_image


static func _extract_sheet_icon(_icon_name: String, grid_pos: Vector2i) -> ImageTexture:
	var sheet := _ensure_sheet_loaded()
	if sheet == null or sheet.is_empty():
		return null

	var cell_w: int = int(sheet.get_width() / SHEET_GRID_SIZE)
	var cell_h: int = int(sheet.get_height() / SHEET_GRID_SIZE)
	if cell_w <= 0 or cell_h <= 0:
		return null

	var region := Rect2i(grid_pos.x * cell_w, grid_pos.y * cell_h, cell_w, cell_h)
	var cell_img: Image = sheet.get_region(region)
	if cell_img.get_format() != Image.FORMAT_RGBA8:
		cell_img.convert(Image.FORMAT_RGBA8)

	_remove_border_white_background(cell_img)
	var trimmed_img: Image = _trim_with_margin(cell_img, 0.08)
	return ImageTexture.create_from_image(trimmed_img)


static func _remove_border_white_background(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var total: int = w * h
	if total <= 0:
		return

	var data: PackedByteArray = img.get_data()
	var visited := PackedByteArray()
	visited.resize(total)
	visited.fill(0)

	var queue := PackedInt32Array()
	queue.resize(total)
	var head: int = 0
	var tail: int = 0

	var is_white_bg := func(idx: int) -> bool:
		var offset: int = idx * 4
		var r: float = float(data[offset]) / 255.0
		var g: float = float(data[offset + 1]) / 255.0
		var b: float = float(data[offset + 2]) / 255.0
		return r > 0.88 and g > 0.88 and b > 0.88

	# Seed BFS from all 4 borders of the cell
	for x in range(w):
		var top_idx: int = x
		if visited[top_idx] == 0 and is_white_bg.call(top_idx):
			visited[top_idx] = 1
			queue[tail] = top_idx
			tail += 1
		var bot_idx: int = (h - 1) * w + x
		if visited[bot_idx] == 0 and is_white_bg.call(bot_idx):
			visited[bot_idx] = 1
			queue[tail] = bot_idx
			tail += 1

	for y in range(1, h - 1):
		var left_idx: int = y * w
		if visited[left_idx] == 0 and is_white_bg.call(left_idx):
			visited[left_idx] = 1
			queue[tail] = left_idx
			tail += 1
		var right_idx: int = y * w + (w - 1)
		if visited[right_idx] == 0 and is_white_bg.call(right_idx):
			visited[right_idx] = 1
			queue[tail] = right_idx
			tail += 1

	while head < tail:
		var curr: int = queue[head]
		head += 1
		data[curr * 4 + 3] = 0

		var cx: int = curr % w
		var cy: int = int(curr / w)

		if cx > 0:
			var n_left: int = curr - 1
			if visited[n_left] == 0 and is_white_bg.call(n_left):
				visited[n_left] = 1
				queue[tail] = n_left
				tail += 1
		if cx + 1 < w:
			var n_right: int = curr + 1
			if visited[n_right] == 0 and is_white_bg.call(n_right):
				visited[n_right] = 1
				queue[tail] = n_right
				tail += 1
		if cy > 0:
			var n_up: int = curr - w
			if visited[n_up] == 0 and is_white_bg.call(n_up):
				visited[n_up] = 1
				queue[tail] = n_up
				tail += 1
		if cy + 1 < h:
			var n_down: int = curr + w
			if visited[n_down] == 0 and is_white_bg.call(n_down):
				visited[n_down] = 1
				queue[tail] = n_down
				tail += 1

	# Smoothstep alpha feathering on pixels immediately bordering the background
	for y in range(h):
		for x in range(w):
			var idx: int = y * w + x
			if visited[idx] != 0:
				continue
			var touches_bg: bool = (
				(x > 0 and visited[idx - 1] != 0)
				or (x + 1 < w and visited[idx + 1] != 0)
				or (y > 0 and visited[idx - w] != 0)
				or (y + 1 < h and visited[idx + w] != 0)
			)
			if not touches_bg:
				continue

			var offset: int = idx * 4
			var r: float = float(data[offset]) / 255.0
			var g: float = float(data[offset + 1]) / 255.0
			var b: float = float(data[offset + 2]) / 255.0
			var min_chan: float = minf(r, minf(g, b))
			if min_chan > 0.68:
				var t: float = clampf((min_chan - 0.68) / (0.88 - 0.68), 0.0, 1.0)
				var alpha: float = 1.0 - smoothstep(0.0, 1.0, t)
				data[offset + 3] = int(roundf(alpha * 255.0))

	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)


static func _trim_with_margin(img: Image, margin_ratio: float) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var data: PackedByteArray = img.get_data()

	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1

	for y in range(h):
		for x in range(w):
			var alpha: int = data[(y * w + x) * 4 + 3]
			if alpha > 12:
				if x < min_x:
					min_x = x
				if y < min_y:
					min_y = y
				if x > max_x:
					max_x = x
				if y > max_y:
					max_y = y

	if max_x < min_x or max_y < min_y:
		return img

	var crop_w: int = max_x - min_x + 1
	var crop_h: int = max_y - min_y + 1
	var trimmed: Image = img.get_region(Rect2i(min_x, min_y, crop_w, crop_h))

	var max_dim: int = maxi(crop_w, crop_h)
	var pad: int = int(ceilf(float(max_dim) * margin_ratio))
	var canvas_size: int = max_dim + pad * 2
	var canvas := Image.create(canvas_size, canvas_size, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))

	var dest := Vector2i((canvas_size - crop_w) / 2, (canvas_size - crop_h) / 2)
	canvas.blit_rect(trimmed, Rect2i(0, 0, crop_w, crop_h), dest)
	return canvas


## Requests an asynchronous real 3D isometric thumbnail rendered via the shared SubViewport.
## Immediately sets a fast cached/2D placeholder on target_rect, then swaps in the 3D render.
static func request_piece_3d_thumbnail(
	piece_id: String,
	base_color: Color,
	theme_id: String,
	target_rect: TextureRect
) -> void:
	if target_rect == null or not is_instance_valid(target_rect):
		return
	var color_hex: String = base_color.to_html(false)
	var cache_key: String = "%s_%s_%s" % [theme_id, piece_id, color_hex]
	if _icon_texture_cache.has(cache_key):
		target_rect.texture = _icon_texture_cache[cache_key] as Texture2D
		return

	target_rect.texture = get_piece_icon_texture(piece_id, base_color, theme_id)

	if DisplayServer.get_name() == "headless":
		return
	if not _ensure_thumb_viewport():
		return

	_thumb_queue.append({
		"piece_id": piece_id,
		"base_color": base_color,
		"color_hex": "#" + color_hex,
		"theme_id": theme_id,
		"cache_key": cache_key,
		"target_rect": target_rect,
	})
	if not _thumb_processing:
		_process_thumb_queue()


static func _resolve_piece_catalog_size(piece_id: String) -> Vector3:
	if PieceCatalog.has_piece(piece_id):
		var def: Dictionary = PieceCatalog.get_piece_definition(piece_id)
		var sz: Variant = def.get("size", Vector3.ONE)
		if sz is Vector3:
			return sz as Vector3
	if _FALLBACK_PIECE_SIZES.has(piece_id):
		return _FALLBACK_PIECE_SIZES[piece_id] as Vector3
	return Vector3.ONE


static func _ensure_thumb_viewport() -> bool:
	if _thumb_viewport != null and is_instance_valid(_thumb_viewport):
		return _thumb_viewport.is_inside_tree()

	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return false
	var tree := main_loop as SceneTree
	if tree.root == null:
		return false

	_thumb_viewport = SubViewport.new()
	_thumb_viewport.name = "PieceThumbSubViewport"
	_thumb_viewport.size = Vector2i(128, 128)
	_thumb_viewport.transparent_bg = true
	_thumb_viewport.own_world_3d = true
	_thumb_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_thumb_viewport.msaa_3d = Viewport.MSAA_4X

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.96, 1.0)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_thumb_viewport.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.96, 0.90)
	key_light.light_energy = 1.25
	key_light.look_at_from_position(Vector3(3.0, 5.0, 4.0), Vector3.ZERO, Vector3.UP)
	_thumb_viewport.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.light_color = Color(0.84, 0.92, 1.0)
	fill_light.light_energy = 0.55
	fill_light.look_at_from_position(Vector3(-4.0, 2.5, -2.0), Vector3.ZERO, Vector3.UP)
	_thumb_viewport.add_child(fill_light)

	_thumb_camera = Camera3D.new()
	_thumb_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_thumb_camera.size = 2.4
	_thumb_camera.near = 0.1
	_thumb_camera.far = 25.0
	_thumb_camera.look_at_from_position(Vector3(3.0, 2.6, 3.0), Vector3(0.0, 0.35, 0.0), Vector3.UP)
	_thumb_viewport.add_child(_thumb_camera)

	_thumb_mesh_instance = MeshInstance3D.new()
	_thumb_mesh_instance.name = "ThumbPieceMesh"
	_thumb_viewport.add_child(_thumb_mesh_instance)

	tree.root.add_child(_thumb_viewport)
	return true


static func _process_thumb_queue() -> void:
	_thumb_processing = true
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		_thumb_processing = false
		return
	var tree := main_loop as SceneTree

	while not _thumb_queue.is_empty():
		var job: Dictionary = _thumb_queue.pop_front()
		var cache_key: String = str(job["cache_key"])
		var target_rect := job.get("target_rect") as TextureRect
		if _icon_texture_cache.has(cache_key):
			if target_rect != null and is_instance_valid(target_rect):
				target_rect.texture = _icon_texture_cache[cache_key] as Texture2D
			continue
		if not _ensure_thumb_viewport():
			break

		var piece_id: String = str(job["piece_id"])
		var theme_id: String = str(job["theme_id"])
		var color_hex: String = str(job["color_hex"])
		var catalog_size: Vector3 = _resolve_piece_catalog_size(piece_id)
		var mesh: ArrayMesh = ToyMeshBuilder.get_or_build_mesh(piece_id, catalog_size, theme_id, color_hex)
		if mesh == null or mesh.get_surface_count() == 0:
			continue

		_thumb_mesh_instance.mesh = mesh
		_thumb_mesh_instance.set_surface_override_material(0, null)
		if not ToyMeshBuilder.is_voxel_piece(piece_id):
			_thumb_mesh_instance.set_surface_override_material(
				0,
				ToyMeshBuilder.get_piece_material(piece_id, color_hex, theme_id)
			)

		var max_span: float = maxf(catalog_size.x, catalog_size.z)
		_thumb_camera.size = 2.7 if max_span > 1.5 else 2.4
		_thumb_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

		await tree.process_frame
		await RenderingServer.frame_post_draw

		if _thumb_viewport == null or not is_instance_valid(_thumb_viewport):
			break
		var vp_tex := _thumb_viewport.get_texture()
		if vp_tex == null:
			continue
		var img := vp_tex.get_image()
		if img == null or img.is_empty():
			continue

		var tex := ImageTexture.create_from_image(img)
		_icon_texture_cache[cache_key] = tex
		if target_rect != null and is_instance_valid(target_rect):
			target_rect.texture = tex

	_thumb_processing = false
