@tool
extends Node3D
## Generates river ribbon meshes from Gaea river path data.
## Reads river_paths.json and creates MeshInstance3D nodes for each river segment.

@export_file("*.json") var river_data_path: String = "res://river_paths.json"
@export var height_scale: float = 500.0
@export var water_nudge: float = 0.5
@export var min_points: int = 5

## Water material settings
@export_group("Water Appearance")
@export var water_color: Color = Color(0.1, 0.4, 0.8, 0.7)

var _generated: bool = false

func _ready() -> void:
	if not _generated:
		generate()

func generate() -> void:
	# Clear old children
	for child in get_children():
		child.queue_free()

	# Load path data
	var file = FileAccess.open(river_data_path, FileAccess.READ)
	if not file:
		push_error("GenerateRivers: Could not open " + river_data_path)
		return

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("GenerateRivers: JSON parse error")
		return

	var data = json.data
	var paths = data["paths"]
	print("GenerateRivers: Loading %d paths" % paths.size())

	var total_tris = 0
	var created = 0

	for path_data in paths:
		var points = path_data["points"]
		if points.size() < min_points:
			continue

		var mesh = _build_ribbon_mesh(points)
		if mesh:
			var mi = MeshInstance3D.new()
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.name = "River_%d" % path_data["id"]

			# Apply material
			var mat = StandardMaterial3D.new()
			mat.albedo_color = water_color
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = mat

			add_child(mi)
			mi.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
			created += 1
			total_tris += points.size() * 2

	_generated = true
	print("GenerateRivers: Created %d river meshes (%d triangles)" % [created, total_tris])

func _build_ribbon_mesh(points: Array) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var accumulated_dist = 0.0

	for i in range(points.size()):
		var pt = points[i]
		var world_x = float(pt["x"])
		var world_z = float(pt["z"])
		var world_y = float(pt["height"]) * height_scale + water_nudge
		var width = float(pt["width"])

		# Calculate direction for perpendicular offset
		var forward: Vector3
		if i < points.size() - 1:
			var next = points[i + 1]
			forward = Vector3(float(next["x"]) - world_x, 0, float(next["z"]) - world_z).normalized()
		elif i > 0:
			var prev = points[i - 1]
			forward = Vector3(world_x - float(prev["x"]), 0, world_z - float(prev["z"])).normalized()
		else:
			forward = Vector3(0, 0, 1)

		# Perpendicular direction (cross with up)
		var right = forward.cross(Vector3.UP).normalized()
		var half_w = width * 0.5

		var center = Vector3(world_x, world_y, world_z)
		var left_pt = center - right * half_w
		var right_pt = center + right * half_w

		vertices.append(left_pt)
		vertices.append(right_pt)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)

		# UV: x goes 0-1 across width, y accumulates along length
		if i > 0:
			var prev = points[i - 1]
			var dx = world_x - float(prev["x"])
			var dz = world_z - float(prev["z"])
			accumulated_dist += sqrt(dx * dx + dz * dz)

		uvs.append(Vector2(0.0, accumulated_dist / 10.0))
		uvs.append(Vector2(1.0, accumulated_dist / 10.0))

		# Build triangles (two per quad between this point and previous)
		if i > 0:
			var idx = (i - 1) * 2
			# Tri 1
			indices.append(idx)
			indices.append(idx + 1)
			indices.append(idx + 2)
			# Tri 2
			indices.append(idx + 1)
			indices.append(idx + 3)
			indices.append(idx + 2)

	if vertices.size() < 4:
		return null

	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
