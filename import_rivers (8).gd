@tool
extends EditorScript

## River Importer v3 — Auto-detects terrain bounds from Terrain3D
## Run: Script Editor -> File -> Run (Ctrl+Shift+X)

const JSON_PATH := "res://river_paths.json"
const MIN_POINTS := 3
const MIN_SEGMENT_SIZE := 50
const HEIGHT_OFFSET := -0.3

func _run():
	print("=== River Importer v3 (auto-detect) ===")
	
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if not file:
		printerr("Could not open " + JSON_PATH)
		return
	
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		printerr("JSON parse error: " + json.get_error_message())
		return
	
	var data: Dictionary = json.data
	var rivers: Array = data["rivers"]
	print("Loaded %d rivers" % rivers.size())
	
	var scene_root := get_editor_interface().get_edited_scene_root()
	
	# Find Terrain3D and auto-detect bounds
	var terrain: Node = _find_node_by_class(scene_root, "Terrain3D")
	if not terrain:
		printerr("No Terrain3D node found!")
		return
	
	# Get terrain bounds from Terrain3D data
	var tdata = terrain.get_data() if terrain.has_method("get_data") else null
	var terrain_min_x := 0.0
	var terrain_min_z := 0.0
	var terrain_max_x := 1024.0
	var terrain_max_z := 1024.0
	
	if tdata:
		# Try to get region info to determine bounds
		var regions = null
		if tdata.has_method("get_region_locations"):
			regions = tdata.get_region_locations()
		elif tdata.has_method("get_regions"):
			regions = tdata.get_regions()
		
		var region_size := 256.0
		if terrain.has_method("get_region_size"):
			region_size = float(terrain.get_region_size())
		elif tdata.has_method("get_region_size"):
			region_size = float(tdata.get_region_size())
		
		if regions and regions.size() > 0:
			var min_loc := Vector2(99999, 99999)
			var max_loc := Vector2(-99999, -99999)
			for loc in regions:
				var v: Vector2
				if loc is Vector2:
					v = loc
				elif loc is Vector2i:
					v = Vector2(loc)
				else:
					continue
				min_loc.x = min(min_loc.x, v.x)
				min_loc.y = min(min_loc.y, v.y)
				max_loc.x = max(max_loc.x, v.x)
				max_loc.y = max(max_loc.y, v.y)
			
			terrain_min_x = min_loc.x * region_size
			terrain_min_z = min_loc.y * region_size
			terrain_max_x = (max_loc.x + 1) * region_size
			terrain_max_z = (max_loc.y + 1) * region_size
			print("  Auto-detected terrain bounds:")
			print("    X: %0.0f to %0.0f" % [terrain_min_x, terrain_max_x])
			print("    Z: %0.0f to %0.0f" % [terrain_min_z, terrain_max_z])
			print("    Region size: %0.0f" % region_size)
			print("    Regions: %s to %s" % [str(min_loc), str(max_loc)])
		else:
			print("  WARNING: Could not get regions, trying AABB...")
			if tdata.has_method("get_aabb"):
				var aabb: AABB = tdata.get_aabb()
				terrain_min_x = aabb.position.x
				terrain_min_z = aabb.position.z
				terrain_max_x = aabb.position.x + aabb.size.x
				terrain_max_z = aabb.position.z + aabb.size.z
				print("    AABB: %s" % str(aabb))
			else:
				print("  WARNING: Could not detect bounds, using defaults")
	
	var terrain_width := terrain_max_x - terrain_min_x
	var terrain_depth := terrain_max_z - terrain_min_z
	print("  Terrain size: %0.0f x %0.0f" % [terrain_width, terrain_depth])
	
	# Remove old imported rivers
	var old := scene_root.find_child("ImportedRivers", true, false)
	if old:
		old.queue_free()
		print("Removed old ImportedRivers")
	
	var container := Node3D.new()
	container.name = "ImportedRivers"
	scene_root.add_child(container)
	container.owner = scene_root
	
	var has_waterways := ResourceLoader.exists("res://addons/waterways/river_manager.gd")
	var river_script = null
	if has_waterways:
		river_script = load("res://addons/waterways/river_manager.gd")
		print("  Waterways plugin found")
	
	var created := 0
	for river_data in rivers:
		var points: Array = river_data["points"]
		var seg_size: int = river_data.get("segment_size", 0)
		
		if points.size() < MIN_POINTS or seg_size < MIN_SEGMENT_SIZE:
			continue
		
		# Build the curve
		var curve := Curve3D.new()
		curve.bake_interval = 0.05
		var river_widths: Array[float] = []
		
		for i in range(points.size()):
			var pt: Dictionary = points[i]
			var world_x: float = terrain_min_x + pt["x"] * terrain_width
			var world_z: float = terrain_max_z - pt["z"] * terrain_depth
			
			var world_y: float = 0.0
			if tdata and tdata.has_method("get_height"):
				var h: float = tdata.get_height(Vector3(world_x, 0, world_z))
				if not is_nan(h):
					world_y = h
			world_y += HEIGHT_OFFSET
			
			var pos := Vector3(world_x, world_y, world_z)
			# Add with tangent handles for smooth curves
			if i > 0 and i < points.size() - 1:
				var prev_pt = points[i - 1]
				var next_pt = points[i + 1]
				var prev_x = terrain_min_x + prev_pt["x"] * terrain_width
				var prev_z = terrain_max_z - prev_pt["z"] * terrain_depth
				var next_x = terrain_min_x + next_pt["x"] * terrain_width
				var next_z = terrain_max_z - next_pt["z"] * terrain_depth
				var tangent = Vector3(next_x - prev_x, 0, next_z - prev_z) * 0.25
				curve.add_point(pos, -tangent, tangent)
			else:
				curve.add_point(pos)
			
			var w: float = pt.get("width", 4.0)
			river_widths.append(w)
		
		if river_script:
			# River manager extends Node3D, has its own curve property
			var river_node := Node3D.new()
			river_node.set_script(river_script)
			river_node.name = "River_%03d" % river_data["id"]
			# Set curve BEFORE adding to tree so _enter_tree sees it
			river_node.curve = curve
			river_node.widths = river_widths
			container.add_child(river_node)
			river_node.owner = scene_root
		else:
			# Fallback to Path3D
			var path := Path3D.new()
			path.name = "River_%03d" % river_data["id"]
			path.curve = curve
			container.add_child(path)
			path.owner = scene_root
		
		created += 1
	
	print("=== Created %d rivers ===" % created)

func _find_node_by_class(root: Node, cls: String) -> Node:
	if root.get_class() == cls: return root
	for child in root.get_children():
		var found := _find_node_by_class(child, cls)
		if found: return found
	return null
