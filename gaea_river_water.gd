@tool
extends Node3D
## Gaea River Water Overlay for Terrain3D
##
## SETUP:
## 1. Import Rivers_Out.exr as your Terrain3D heightmap (it has carved riverbeds)
## 2. Place the 3 PNG textures (river_mask.png, river_depth.png, river_direction.png)
##    and river_water.gdshader in your project
## 3. Add this script to a Node3D that is a sibling of your Terrain3D node
## 4. Set the exported properties to match your Terrain3D settings
## 5. Assign textures in the inspector or call setup() from code
##
## The script creates a flat quad mesh sized to your terrain, applies the river
## shader, and positions it so the water sits in the carved riverbeds.

## Must match your Terrain3D region size * vertex_spacing
@export var terrain_size: float = 1024.0

## Must match the height_scale you used when importing the heightmap into Terrain3D
## (i.e., if Gaea's 0-1 normalized heights map to 0-300m, set this to 300)
@export var terrain_height_scale: float = 300.0

## Slight Y offset so water doesn't z-fight with the riverbed
@export var water_y_offset: float = 0.15

## Subdivision count for the water plane mesh.
## More subdivisions = water follows terrain curvature better.
## 128-256 is usually enough for 1024m terrain.
@export var mesh_subdivisions: int = 256

@export_group("Textures")
@export var river_mask_texture: Texture2D
@export var river_depth_texture: Texture2D
@export var river_direction_texture: Texture2D
@export var water_normal_texture: Texture2D

@export_group("Water Appearance")
@export var shallow_color: Color = Color(0.2, 0.6, 0.8, 0.5)
@export var deep_color: Color = Color(0.05, 0.15, 0.3, 0.9)
@export var flow_speed: float = 0.3
@export var normal_tile_scale: float = 12.0

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial

func _ready() -> void:
	setup()

func setup() -> void:
	# Clean up existing
	if _mesh_instance:
		_mesh_instance.queue_free()

	# Create the water plane mesh
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(terrain_size, terrain_size)
	plane_mesh.subdivide_width = mesh_subdivisions
	plane_mesh.subdivide_depth = mesh_subdivisions

	# Create mesh instance
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = plane_mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

	# Position at terrain center, slight Y offset
	# Terrain3D typically centers regions at origin, so the plane should match
	_mesh_instance.position = Vector3(terrain_size / 2.0, water_y_offset, terrain_size / 2.0)

	# Load and apply shader
	var shader = load("res://river_water.gdshader") as Shader
	if not shader:
		push_error("GaeaRiverWater: Could not load river_water.gdshader from res://")
		return

	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.render_priority = 1  # Render after terrain

	# Set textures
	if river_mask_texture:
		_material.set_shader_parameter("river_mask", river_mask_texture)
	if river_depth_texture:
		_material.set_shader_parameter("river_depth", river_depth_texture)
	if river_direction_texture:
		_material.set_shader_parameter("river_direction", river_direction_texture)
	if water_normal_texture:
		_material.set_shader_parameter("water_normal_map", water_normal_texture)

	# Set scale parameters
	_material.set_shader_parameter("terrain_height_scale", terrain_height_scale)
	_material.set_shader_parameter("terrain_size", terrain_size)
	_material.set_shader_parameter("water_surface_offset", water_y_offset)

	# Set appearance
	_material.set_shader_parameter("shallow_color", shallow_color)
	_material.set_shader_parameter("deep_color", deep_color)
	_material.set_shader_parameter("flow_speed", flow_speed)
	_material.set_shader_parameter("normal_tile_scale", normal_tile_scale)

	_mesh_instance.material_override = _material
	print("GaeaRiverWater: Water mesh created (%dx%d subdivisions, %.0fm terrain)" % [
		mesh_subdivisions, mesh_subdivisions, terrain_size
	])

## Call this if you change properties at runtime
func refresh() -> void:
	setup()
