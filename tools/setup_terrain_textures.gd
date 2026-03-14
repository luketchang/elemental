@tool
extends EditorScript

## setup_terrain_textures.gd
## -------------------------
## Run this ONCE from the Godot Script Editor to:
##   1. Channel pack your Megascans textures (albedo+height, normal+roughness)
##   2. Save the packed PNGs to res://materials/
##   3. Add them as a Terrain3DTextureAsset to your Terrain3D node
##
## How to run:
##   1. Open this script in the Godot Script Editor
##   2. File → Run (or Ctrl+Shift+X)
##
## Set the paths below to match your project before running.

# ── INPUT: your raw Megascans texture paths ──────────────────────────────────
const ALBEDO_PATH    = "res://materials/grass_and_rubble_pjwey0_2k/Grass_And_Rubble_pjwey0_2K_BaseColor.jpg"
const HEIGHT_PATH    = "res://materials/grass_and_rubble_pjwey0_2k/Grass_And_Rubble_pjwey0_2K_Displacement.jpg"
const NORMAL_PATH    = "res://materials/grass_and_rubble_pjwey0_2k/Grass_And_Rubble_pjwey0_2K_Normal.jpg"
const ROUGHNESS_PATH = "res://materials/grass_and_rubble_pjwey0_2k/Grass_And_Rubble_pjwey0_2K_Roughness.jpg"

# ── OUTPUT: where packed textures will be saved ───────────────────────────────
const OUT_ALBEDO_HEIGHT  = "res://materials/packed/grass_rubble_albedo_height.png"
const OUT_NORMAL_ROUGH   = "res://materials/packed/grass_rubble_normal_rough.png"

# ── SCENE: path to your Terrain3D node in the current scene ──────────────────
const TERRAIN_NODE_PATH  = "/root/World_tscn/Terrain3D"

# ── TEXTURE SLOT: which slot to put this texture in (0 = first) ──────────────
const TEXTURE_SLOT = 0
const TEXTURE_NAME = "Grass and Rubble"


func _run() -> void:
	print("=== Terrain3D Texture Setup ===")

	# Step 1: Pack textures
	var albedo_height = _pack_albedo_height()
	if albedo_height == null:
		push_error("Failed to create albedo+height texture")
		return

	var normal_rough = _pack_normal_roughness()
	if normal_rough == null:
		push_error("Failed to create normal+roughness texture")
		return

	# Step 2: Save packed textures to disk
	_ensure_dir("res://materials/packed")
	var err1 = ResourceSaver.save(albedo_height, OUT_ALBEDO_HEIGHT)
	var err2 = ResourceSaver.save(normal_rough, OUT_NORMAL_ROUGH)
	if err1 != OK or err2 != OK:
		push_error("Failed to save packed textures. err1=%d err2=%d" % [err1, err2])
		return
	print("Packed textures saved.")

	# Force Godot to import the new files
	var fs = EditorInterface.get_resource_filesystem()
	fs.scan()
	await fs.filesystem_changed

	# Step 3: Load packed textures back as proper Texture2D resources
	var tex_albedo: Texture2D = load(OUT_ALBEDO_HEIGHT)
	var tex_normal: Texture2D = load(OUT_NORMAL_ROUGH)
	if tex_albedo == null or tex_normal == null:
		push_error("Could not load packed textures after saving.")
		return

	# Step 4: Create Terrain3DTextureAsset
	var texture_asset = Terrain3DTextureAsset.new()
	texture_asset.name = TEXTURE_NAME
	texture_asset.albedo_texture = tex_albedo
	texture_asset.normal_texture = tex_normal
	texture_asset.uv_scale = 0.1  # Adjust tiling — lower = larger tiles

	# Step 5: Find Terrain3D node and assign
	var terrain = get_scene().get_node_or_null(TERRAIN_NODE_PATH)
	if terrain == null:
		# Try finding it by type if path is wrong
		terrain = _find_terrain3d(get_scene())

	if terrain == null:
		push_error("Could not find Terrain3D node. Check TERRAIN_NODE_PATH.")
		return

	print("Found Terrain3D: ", terrain.name)

	var assets: Terrain3DAssets = terrain.assets
	if assets == null:
		push_error("Terrain3D has no assets resource assigned.")
		return

	assets.set_texture(TEXTURE_SLOT, texture_asset)
	print("Texture assigned to slot %d." % TEXTURE_SLOT)

	# Step 6: Enable autoshader on the material so texture shows automatically
	var mat = terrain.material
	if mat and mat.has_method("set"):
		if "auto_shader" in mat:
			mat.auto_shader = true
			print("Autoshader enabled.")

	# Save the scene
	EditorInterface.save_scene()
	print("=== Done! Terrain should now show the grass texture. ===")


func _pack_albedo_height() -> ImageTexture:
	print("Packing albedo + height...")
	var albedo_img = _load_image(ALBEDO_PATH)
	var height_img = _load_image(HEIGHT_PATH)
	if albedo_img == null or height_img == null:
		return null

	var size = albedo_img.get_size()
	# Resize height to match albedo if needed
	if height_img.get_size() != size:
		height_img.resize(size.x, size.y)

	# Convert albedo to RGBA, put height in alpha channel
	albedo_img.convert(Image.FORMAT_RGBA8)
	height_img.convert(Image.FORMAT_L8)

	for y in size.y:
		for x in size.x:
			var col = albedo_img.get_pixel(x, y)
			var h = height_img.get_pixel(x, y).r
			col.a = h
			albedo_img.set_pixel(x, y, col)

	var tex = ImageTexture.create_from_image(albedo_img)
	print("  Albedo+height packed: %dx%d" % [size.x, size.y])
	return tex


func _pack_normal_roughness() -> ImageTexture:
	print("Packing normal + roughness...")
	var normal_img = _load_image(NORMAL_PATH)
	var rough_img  = _load_image(ROUGHNESS_PATH)
	if normal_img == null or rough_img == null:
		return null

	var size = normal_img.get_size()
	if rough_img.get_size() != size:
		rough_img.resize(size.x, size.y)

	normal_img.convert(Image.FORMAT_RGBA8)
	rough_img.convert(Image.FORMAT_L8)

	for y in size.y:
		for x in size.x:
			var col = normal_img.get_pixel(x, y)
			var r = rough_img.get_pixel(x, y).r
			col.a = r
			normal_img.set_pixel(x, y, col)

	var tex = ImageTexture.create_from_image(normal_img)
	print("  Normal+roughness packed: %dx%d" % [size.x, size.y])
	return tex


func _load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		push_error("File not found: " + path)
		return null
	var img = Image.load_from_file(path)
	if img == null:
		push_error("Failed to load image: " + path)
	return img


func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _find_terrain3d(node: Node) -> Node:
	if node.get_class() == "Terrain3D":
		return node
	for child in node.get_children():
		var result = _find_terrain3d(child)
		if result:
			return result
	return null
