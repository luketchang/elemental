@tool
extends Node3D

@export var terrain_size: float = 1024.0
@export var mesh_subdivisions: int = 256
@export var river_mask_texture: Texture2D
@export var river_height_texture: Texture2D
@export var height_scale: float = 500.0

var _mesh_instance: MeshInstance3D

func _ready() -> void:
	print("=== RiverWater: _ready() called ===")
	setup()

func setup() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()

	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(terrain_size, terrain_size)
	plane_mesh.subdivide_width = mesh_subdivisions
	plane_mesh.subdivide_depth = mesh_subdivisions

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = plane_mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

	_mesh_instance.position = Vector3(512.0, 0.0, 512.0)

	var shader = load("res://river_debug.gdshader") as Shader
	if not shader:
		push_error("RiverWater: Could not load river_debug.gdshader!")
		return

	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.render_priority = 1
	mat.set_shader_parameter("river_mask", river_mask_texture)
	mat.set_shader_parameter("river_height", river_height_texture)
	mat.set_shader_parameter("terrain_size", terrain_size)
	mat.set_shader_parameter("height_scale", height_scale)
	mat.set_shader_parameter("height_range", 0.16)
	mat.set_shader_parameter("water_nudge", 0.3)

	_mesh_instance.material_override = mat

	print("  Mesh position: ", _mesh_instance.global_position)
	print("  height_scale: ", height_scale)
	print("  river_height_texture: ", river_height_texture)
	print("=== RiverWater: done ===")
