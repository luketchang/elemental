@tool
extends EditorScript

## River Importer v2 for Terrain3D + Waterways
## Run: Script Editor -> File -> Run (Ctrl+Shift+X)

const JSON_PATH := "res://river_paths.json"

# Terrain mapping — adjust these if rivers are offset
# Your regions: 01_00 to 02_03, region size 256
# Region (1,0) = world pos (256, 0), region (2,3) = world pos (512, 768)
# So terrain spans roughly X: 256..768, Z: 0..1024
const TERRAIN_ORIGIN := Vector3(-512, 0, -512)
const TERRAIN_SIZE := Vector2(1024, 1024)

const MIN_POINTS := 3
const MIN_SEGMENT_SIZE := 50
const HEIGHT_OFFSET := -0.3
const DEFAULT_WIDTH := 6.0

func _run():
	print("=== River Importer v2 ===")
	
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
	
	# Remove old imported rivers
	var old := scene_root.find_child("ImportedRivers", true, false)
	if old:
		old.queue_free()
		print("Removed old ImportedRivers")
	
	var container := Node3D.new()
	container.name = "ImportedRivers"
	scene_root.add_child(container)
	container.owner = scene_root
	
	var terrain: Node = _find_node_by_class(scene_root, "Terrain3D")
	var has_waterways := ResourceLoader.exists("res://addons/waterways/river_manager.gd")
	
	var created := 0
	for river_data in rivers:
		var points: Array = river_data["points"]
		var seg_size: int = river_data.get("segment_size", 0)
		
		if points.size() < MIN_POINTS or seg_size < MIN_SEGMENT_SIZE:
			continue
		
		var river_node: Node3D
		if has_waterways:
			var river_script = load("res://addons/waterways/river_manager.gd")
			if river_script:
				river_node = Node3D.new()
				river_node.set_script(river_script)
			else:
				river_node = Path3D.new()
		else:
			river_node = Path3D.new()
		
		river_node.name = "River_%03d" % river_data["id"]
		
		var curve := Curve3D.new()
		for i in range(points.size()):
			var pt: Dictionary = points[i]
			var world_x: float = TERRAIN_ORIGIN.x + pt["x"] * TERRAIN_SIZE.x
			var world_z: float = TERRAIN_ORIGIN.z + pt["z"] * TERRAIN_SIZE.y
			
			var world_y: float = 0.0
			if terrain and terrain.has_method("get_data"):
				var tdata = terrain.get_data()
				if tdata and tdata.has_method("get_height"):
					var h: float = tdata.get_height(Vector3(world_x, 0, world_z))
					if not is_nan(h):
						world_y = h
			
			world_y += HEIGHT_OFFSET
			curve.add_point(Vector3(world_x, world_y, world_z))
		
		if river_node is Path3D:
			river_node.curve = curve
		else:
			river_node.set("curve", curve)
		
		container.add_child(river_node)
		river_node.owner = scene_root
		created += 1
	
	print("=== Created %d rivers ===" % created)
	print("If offset, select ImportedRivers node and drag to align")

func _find_node_by_class(root: Node, cls: String) -> Node:
	if root.get_class() == cls: return root
	for child in root.get_children():
		var found := _find_node_by_class(child, cls)
		if found: return found
	return null
