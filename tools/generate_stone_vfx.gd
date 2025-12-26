@tool
extends EditorScript

## Stone Levitation VFX Generator (v6.0 - Physics-Based)
## Run this script from: File -> Run (or Ctrl+Shift+X)
## Generates: res://scenes/stone_levitate_vfx.tscn
##
## PHYSICS APPROACH:
## - Stones are RigidBody3D nodes with collision shapes
## - Launch: Upward impulse applied at t=0.0s
## - Hover: Physics frozen at peak (t=0.2s-3.2s)
## - Fall: Physics unfrozen at t=3.2s, natural bounce/roll on ground
## - Stones have mass, bounce, friction for realistic behavior
##
## NOTE: EditorScript requires @tool but only runs when you explicitly execute it

func _run():
	
	print("\n\n=== GENERATING STONE LEVITATION VFX SCENE ===")
	print("🔧 GENERATOR VERSION: v6.0 - PHYSICS-BASED STONES")
	print("Stones: RigidBody3D with impulse launch, freeze hover, physics fall")
	print("Debris: 15 particles, vel 5-7 (higher), spread 20° (consistent), lifetime 2s")
	print("If you don't see this version number, the script wasn't saved/reloaded!\n")
	
	# Create root node
	var root = Node3D.new()
	root.name = "StoneLevitateVFX"
	print("✓ Created root node: ", root.name)
	
	# Attach the controller script for click-to-play
	var script = load("res://scenes/stone_levitate_controller.gd")
	if script:
		root.set_script(script)
		# Add version metadata to the root node
		var timestamp = Time.get_datetime_string_from_system()
		root.set_meta("generator_version", "v6.0")
		root.set_meta("generated_at", timestamp)
		root.set_meta("physics_enabled", "true")
		root.set_meta("stone_type", "RigidBody3D")
		root.set_meta("debris_velocity", "5-7")
		root.set_meta("debris_spread", "20°")
		root.set_meta("debris_amount", "15")
		print("✓ Attached controller script with version metadata")
		print("  Generated at: ", timestamp)
	else:
		push_warning("✗ Failed to load controller script")
	
	# === LIGHTING (so scene isn't gray) ===
	print("\nAdding lighting...")
	var light = _create_light()
	root.add_child(light)
	light.owner = root
	print("✓ Light: ", light.name, " at rotation ", light.rotation_degrees)
	
	# === FLOOR (visual ground + collision) ===
	print("\nAdding floor...")
	var floor = _create_floor()
	root.add_child(floor)
	floor.owner = root
	# Set owner for all children (mesh and collision body)
	for child in floor.get_children():
		child.owner = root
		for grandchild in child.get_children():
			grandchild.owner = root
	print("✓ Floor: ", floor.name, " at ", floor.position, " (with collision)")
	
	# === DEBRIS COLLISION BOX (makes debris bounce on floor) ===
	print("\nAdding debris collider...")
	var debris_collider = _create_debris_collider()
	root.add_child(debris_collider)
	debris_collider.owner = root
	print("✓ Debris collider: ", debris_collider.name, " size=", debris_collider.size, " pos=", debris_collider.position)
	
	# === WORLD BOUNDARY (alternative collision for particles) ===
	print("\nAdding world boundary collision...")
	var world_boundary = _create_world_boundary()
	root.add_child(world_boundary)
	world_boundary.owner = root
	print("✓ World boundary collider added")
	
	# === STONE RIGIDBODY ===
	print("\nAdding stone rigidbody...")
	var stone = _create_stone_rigidbody()
	root.add_child(stone)
	stone.owner = root
	# Set owner for all children (mesh and collision)
	for child in stone.get_children():
		child.owner = root
	print("✓ Stone: ", stone.name, " at ", stone.position, " (RigidBody3D with physics)")
	
	# === DEBRIS PARTICLES ===
	print("\nAdding debris particles...")
	var debris = _create_debris_particles()
	root.add_child(debris)
	debris.owner = root
	print("✓ Debris: ", debris.name, " (mesh: ", debris.draw_pass_1 != null, ")")
	
	# === SMOKE PARTICLES ===
	print("\nAdding smoke particles...")
	var smoke = _create_smoke_particles()
	root.add_child(smoke)
	smoke.owner = root
	print("✓ Smoke: ", smoke.name, " (mesh: ", smoke.draw_pass_1 != null, ")")
	
	# === ANIMATION PLAYER ===
	print("\nAdding animation player...")
	var anim_player = _create_animation_player()
	root.add_child(anim_player)
	anim_player.owner = root
	print("✓ AnimationPlayer: ", anim_player.name, " (has anim: ", anim_player.has_animation("levitate"), ")")
	
	# === CAMERA (for easy preview) ===
	print("\nAdding camera...")
	var camera = _create_camera()
	root.add_child(camera)
	camera.owner = root
	print("✓ Camera: ", camera.name, " at ", camera.position, " (current: ", camera.current, ")")
	
	# === WALLS (randomly placed obstacles for shatter effect) ===
	print("\nAdding walls...")
	var walls = _create_walls()
	for wall in walls:
		root.add_child(wall)
		wall.owner = root
		for child in wall.get_children():
			child.owner = root
	print("✓ Walls: ", walls.size(), " walls placed randomly")
	
	# === WORLD ENVIRONMENT (background, not just void) ===
	print("\nAdding environment...")
	var env = _create_environment()
	root.add_child(env)
	env.owner = root
	print("✓ WorldEnvironment: ", env.name)
	
	# === PACK AND SAVE ===
	print("\n=== PACKING AND SAVING ===")
	print("Total children in scene: ", root.get_child_count())
	for child in root.get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
	
	var save_path = "res://scenes/stone_levitate_vfx.tscn"
	
	# Force delete old file first to avoid caching issues
	if FileAccess.file_exists(save_path):
		print("Deleting old scene file...")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	
	var packed = PackedScene.new()
	var result = packed.pack(root)
	if result == OK:
		print("✓ Scene packed successfully")
		# Print animation details to verify
		print("Verifying animation keyframes...")
		var anim_player_node = root.get_node("AnimationPlayer") as AnimationPlayer
		if anim_player_node:
			var anim = anim_player_node.get_animation("levitate")
			if anim:
				print("  Animation length: ", anim.length)
				print("  Track count: ", anim.get_track_count())
				for i in anim.get_track_count():
					var path = anim.track_get_path(i)
					var key_count = anim.track_get_key_count(i)
					var interp = anim.track_get_interpolation_type(i)
					print("  Track ", i, ": ", path, " (", key_count, " keys, interp=", interp, " 1=LINEAR 2=CUBIC)")
					if key_count > 0 and "position" in str(path):
						for k in key_count:
							print("    Key ", k, ": t=", anim.track_get_key_time(i, k), " v=", anim.track_get_key_value(i, k))
						print("  ⚠️ CHECK: Last key should be y=0.25, interp should be 1 (LINEAR)")
		
		var err = ResourceSaver.save(packed, save_path)
		if err == OK:
			print("✓✓✓ SUCCESS: Scene saved to ", save_path)
			print("\nNow open the scene in Godot and run it!")
		else:
			push_error("✗ Failed to save scene (error code ", err, ")")
	else:
		push_error("✗ Failed to pack scene (error code ", result, ")")
	
	print("=== END GENERATION ===\n")
	
	# Clean up
	root.queue_free()


func _create_light() -> DirectionalLight3D:
	var light = DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.rotation_degrees = Vector3(-45, -45, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	return light


func _create_floor() -> Node3D:
	# Create a container node for floor mesh + collision
	var floor_root = Node3D.new()
	floor_root.name = "floor"
	floor_root.position = Vector3(0, 0, 0)
	# No slant - flat floor for proper physics
	
	# Visual mesh
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "floor_mesh"
	var plane = PlaneMesh.new()
	plane.size = Vector2(100, 100)  # HUGE floor for rock shooting
	floor_mesh.mesh = plane
	
	# Floor material - earthy brown color
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.3, 0.2, 1.0)
	floor_mesh.set_surface_override_material(0, mat)
	
	floor_root.add_child(floor_mesh)
	
	# Physics body for collision
	var body = StaticBody3D.new()
	body.name = "floor_collision"
	
	# Set collision layers for proper interaction with stones
	body.collision_layer = 1  # Layer 1
	body.collision_mask = 1   # Collides with layer 1
	
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box = BoxShape3D.new()
	box.size = Vector3(100, 0.2, 100)  # HUGE floor
	collision.shape = box
	collision.position = Vector3(0, -0.1, 0)  # Slightly below floor surface
	
	body.add_child(collision)
	floor_root.add_child(body)
	
	return floor_root


func _create_debris_collider() -> GPUParticlesCollisionBox3D:
	# Particle collision box - HUGE for rock shooting anywhere
	var collider = GPUParticlesCollisionBox3D.new()
	collider.name = "debris_collider"
	collider.size = Vector3(100, 2.5, 100)  # Match floor size
	collider.position = Vector3(0, -1.0, 0)
	return collider


func _create_world_boundary() -> GPUParticlesCollisionBox3D:
	# Additional collision box for particles
	var collider = GPUParticlesCollisionBox3D.new()
	collider.name = "floor_particle_collision"
	collider.size = Vector3(100, 0.5, 100)  # Match floor size
	collider.position = Vector3(0, -0.25, 0)
	return collider


func _create_camera() -> Camera3D:
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(8, 8, 12)  # Higher and further back for huge floor
	camera.rotation_degrees = Vector3(-30, 30, 0)  # Looking down more
	camera.current = true
	return camera


func _create_environment() -> WorldEnvironment:
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.3, 0.35, 1.0)  # Dark gray-blue
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.45, 1.0)
	env.ambient_light_energy = 0.5
	
	world_env.environment = env
	return world_env


func _create_stone_rigidbody() -> RigidBody3D:
	var rigid_body = RigidBody3D.new()
	rigid_body.name = "stone"
	
	# Configure physics properties
	rigid_body.mass = 5.0  # Medium weight stone
	rigid_body.physics_material_override = PhysicsMaterial.new()
	rigid_body.physics_material_override.bounce = 0.3  # Some bounce
	rigid_body.physics_material_override.friction = 0.8  # High friction for rolling
	rigid_body.angular_damp = 2.0  # Slows rotation naturally
	rigid_body.linear_damp = 0.1  # Slight air resistance
	rigid_body.freeze = true  # Start frozen, will be unfrozen by animation
	
	# Enable contact monitoring for wall collision detection
	rigid_body.contact_monitor = true
	rigid_body.max_contacts_reported = 4
	
	# Set collision layers
	rigid_body.collision_layer = 1  # Layer 1
	rigid_body.collision_mask = 3   # Collides with layer 1 (floor) and layer 2 (walls)
	
	print("  - Loading rock.glb...")
	# Load the rock.glb (exported stoneB2)
	var glb_scene = load("res://assets/models/rock.glb") as PackedScene
	if glb_scene:
		print("  - ✓ GLB loaded, instantiating...")
		var instance = glb_scene.instantiate()
		print("  - Instance created, searching for mesh...")
		# Find the first MeshInstance3D in the GLB
		var stone_node = _find_first_mesh_instance(instance)
		if stone_node:
			print("  - ✓ Found mesh node: ", stone_node.name)
			
			# Create mesh child
			var stone_mesh = MeshInstance3D.new()
			stone_mesh.name = "mesh"
			stone_mesh.mesh = stone_node.mesh
			print("  - Mesh assigned, applying rocks_A texture material...")
			
			# Create material with rocks_A texture
			var rock_mat = StandardMaterial3D.new()
			var rock_tex = load("res://assets/textures/T_rocks_A_color.png") as Texture2D
			if rock_tex:
				rock_mat.albedo_texture = rock_tex
				rock_mat.albedo_color = Color(0.9, 0.9, 0.9, 1.0)
				print("  - ✓ Applied T_rocks_A_color.png texture")
			else:
				rock_mat.albedo_color = Color(0.6, 0.5, 0.4, 1.0)  # Fallback brown
				print("  - ! Could not load texture, using fallback color")
			stone_mesh.set_surface_override_material(0, rock_mat)
			stone_mesh.scale = Vector3(0.8, 0.8, 0.8)  # Adjust scale as needed
			
			# Add mesh to rigid body
			rigid_body.add_child(stone_mesh)
			stone_mesh.owner = rigid_body
			
			# Create collision shape from mesh
			var collision_shape = CollisionShape3D.new()
			collision_shape.name = "CollisionShape3D"
			
			# Use a simple box shape for better physics performance
			# Approximate the rock size
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(0.6, 0.6, 0.6)  # Scaled to match mesh
			collision_shape.shape = box_shape
			
			rigid_body.add_child(collision_shape)
			collision_shape.owner = rigid_body
			
			print("  - ✓ Added collision shape (box)")
		else:
			push_warning("  - ✗ Could not find mesh in rock.glb")
		instance.queue_free()
	else:
		push_error("  - ✗ Could not load rock.glb - check if file exists!")
	
	# Initial position (just above floor - will be launched by impulse)
	rigid_body.position = Vector3(0, 0.3, 0)  # Start above floor, visible
	
	return rigid_body


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh:
		return node
	for child in node.get_children():
		var found = _find_first_mesh_instance(child)
		if found:
			return found
	return null


func _create_debris_particles() -> GPUParticles3D:
	var debris = GPUParticles3D.new()
	debris.name = "debris"
	debris.position = Vector3(0, 0.2, 0)  # Slightly above ground (like earth-bending: 0.228366)
	debris.emitting = false
	debris.one_shot = true  # Quick burst, not continuous
	debris.amount = 15  # Small amount for subtle effect
	debris.lifetime = 6.0  # Long enough to stay until stone disappears at 5.5s
	debris.fixed_fps = 60
	debris.explosiveness = 1.0  # All at once
	debris.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 5, 10))  # Reasonable bounds
	
	# Load debris mesh
	var debris_mesh = load("res://assets/models/debris.obj") as Mesh
	if debris_mesh:
		debris.draw_pass_1 = debris_mesh
	
	# Material override - brown rock color
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.25, 1.0)
	debris.material_override = mat
	
	# Process material - Consistent small pop
	var process_mat = ParticleProcessMaterial.new()
	process_mat.particle_flag_rotate_y = true
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.2  # Tight spawn area
	process_mat.angle_min = -180.0
	process_mat.angle_max = 180.0
	process_mat.direction = Vector3(0, 1, 0)  # Straight up
	process_mat.spread = 20.0  # TIGHT spread - consistent trajectories
	process_mat.initial_velocity_min = 5.0  # Higher velocity for more height
	process_mat.initial_velocity_max = 7.0  # Higher velocity for more height
	process_mat.gravity = Vector3(0, -33, 0)  # Strong gravity - settles quickly
	process_mat.scale_min = 0.3  # Match earth-bending
	process_mat.scale_max = 1.0  # Match earth-bending
	
	# Scale curve - Stay full size until near end
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))       # Start full size
	scale_curve.add_point(Vector2(0.9, 1.0))       # Stay full size until 90%
	scale_curve.add_point(Vector2(1.0, 0.0))       # Shrink at very end
	var scale_curve_tex = CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	process_mat.scale_curve = scale_curve_tex
	
	# Radial velocity curve - Match earth-bending
	var radial_curve = Curve.new()
	radial_curve.add_point(Vector2(0.012474, 0.98856))
	radial_curve.add_point(Vector2(1.0, 0.000175953))
	var radial_curve_tex = CurveTexture.new()
	radial_curve_tex.curve = radial_curve
	process_mat.radial_velocity_min = 0.999978
	process_mat.radial_velocity_max = 1.99998
	process_mat.radial_velocity_curve = radial_curve_tex
	
	# Collision with ground - EXACT match earth-bending
	process_mat.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	process_mat.collision_friction = 0.8  # Match earth-bending
	process_mat.collision_bounce = 0.3  # Match earth-bending
	process_mat.collision_use_scale = true
	
	debris.process_material = process_mat
	
	return debris


func _create_smoke_particles() -> GPUParticles3D:
	var smoke = GPUParticles3D.new()
	smoke.name = "smoke"
	smoke.position = Vector3(0, 0.05, 0)  # At ground level (base of rock)
	smoke.emitting = false
	smoke.one_shot = true  # Short burst, not continuous
	smoke.amount = 15  # Focused, not too much
	smoke.lifetime = 0.6  # Short-lived dust puff
	smoke.explosiveness = 1.0  # All at once
	
	# Quad mesh for billboard smoke
	var quad = QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)  # Smaller, more focused
	smoke.draw_pass_1 = quad
	
	# Material - billboard with smoke texture
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.50, 0.42, 0.8)  # Dusty brown
	
	var smoke_tex = load("res://assets/textures/smoke.png") as Texture2D
	if smoke_tex:
		mat.albedo_texture = smoke_tex
	
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.2
	smoke.material_override = mat
	
	# Process material - dust puff that rises slightly like real disturbed dust
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.35  # Focused at base
	process_mat.direction = Vector3(0, 1, 0)  # Upward direction
	process_mat.spread = 120.0  # Wide spread around the rock
	process_mat.initial_velocity_min = 0.6
	process_mat.initial_velocity_max = 1.2
	process_mat.gravity = Vector3(0, 0.3, 0)  # Slight upward - dust rises when disturbed
	process_mat.damping_min = 1.5
	process_mat.damping_max = 2.5  # Lighter damping for natural float
	
	# Scale curve - quick puff that expands then fades
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.5))
	var scale_curve_tex = CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	process_mat.scale_curve = scale_curve_tex
	
	# Alpha curve - fade out quickly
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.8))
	alpha_curve.add_point(Vector2(0.4, 0.6))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	var alpha_curve_tex = CurveTexture.new()
	alpha_curve_tex.curve = alpha_curve
	process_mat.alpha_curve = alpha_curve_tex
	
	smoke.process_material = process_mat
	
	return smoke


func _create_animation_player() -> AnimationPlayer:
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	
	# Create the levitate animation with physics
	# Timeline: 
	#   0.0: Unfreeze stone, apply upward impulse
	#   0.2: Stone reaches peak, freeze physics (hover starts)
	#   3.2: Hover ends, unfreeze physics (fall begins)
	#   3.5: Stone hits ground, bounces naturally
	#   5.5: Hide stone
	var anim = Animation.new()
	anim.length = 5.5
	anim.loop_mode = Animation.LOOP_NONE
	
	# --- STONE FREEZE TRACK (controls physics on/off) ---
	var stone_freeze_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(stone_freeze_track, "stone:freeze")
	anim.value_track_set_update_mode(stone_freeze_track, Animation.UPDATE_DISCRETE)
	
	anim.track_insert_key(stone_freeze_track, 0.0, false)   # Unfreeze for launch
	anim.track_insert_key(stone_freeze_track, 0.2, true)    # Freeze at peak (hover)
	anim.track_insert_key(stone_freeze_track, 3.2, false)   # Unfreeze for fall
	
	# --- STONE IMPULSE METHOD CALL TRACK ---
	var stone_impulse_track = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(stone_impulse_track, "stone")
	
	# Apply upward impulse at start (adjust force to reach desired height)
	anim.track_insert_key(stone_impulse_track, 0.0, {
		"method": "apply_central_impulse",
		"args": [Vector3(0, 50.0, 0)]  # Strong upward impulse (mass=5, so need 50 for good height)
	})
	
	# NOTE: Position is reset by controller script before animation plays
	# Do NOT add a position track here - it would override physics!
	
	# --- STONE VISIBILITY TRACK (disappear 2s after landing) ---
	var stone_vis_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(stone_vis_track, "stone:visible")
	anim.value_track_set_update_mode(stone_vis_track, Animation.UPDATE_DISCRETE)
	
	anim.track_insert_key(stone_vis_track, 0.0, true)
	anim.track_insert_key(stone_vis_track, 5.5, false)   # Disappear 2s after landing (3.5 + 2.0)
	
	# --- DEBRIS EMITTING TRACK (quick burst on lift) ---
	var debris_emit_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(debris_emit_track, "debris:emitting")
	anim.value_track_set_update_mode(debris_emit_track, Animation.UPDATE_DISCRETE)
	
	anim.track_insert_key(debris_emit_track, 0.0, true)   # Instant burst on start
	# one_shot=true handles stopping automatically
	
	# --- DEBRIS VISIBILITY TRACK (disappear when stone disappears) ---
	var debris_vis_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(debris_vis_track, "debris:visible")
	anim.value_track_set_update_mode(debris_vis_track, Animation.UPDATE_DISCRETE)
	
	anim.track_insert_key(debris_vis_track, 0.0, true)
	anim.track_insert_key(debris_vis_track, 5.5, false)   # Hide debris when stone disappears
	
	# --- SMOKE EMITTING TRACK (short dust puff at base) ---
	var smoke_emit_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(smoke_emit_track, "smoke:emitting")
	anim.value_track_set_update_mode(smoke_emit_track, Animation.UPDATE_DISCRETE)
	
	anim.track_insert_key(smoke_emit_track, 0.0, true)    # Instant dust puff on lift
	# one_shot=true handles stopping automatically
	
	# --- SMOKE VISIBILITY TRACK (disappear when stone disappears) ---
	var smoke_vis_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(smoke_vis_track, "smoke:visible")
	anim.value_track_set_update_mode(smoke_vis_track, Animation.UPDATE_DISCRETE)
	
	anim.track_insert_key(smoke_vis_track, 0.0, true)
	anim.track_insert_key(smoke_vis_track, 5.5, false)   # Hide smoke when stone disappears
	
	# Create animation library and add
	var lib = AnimationLibrary.new()
	lib.add_animation("levitate", anim)
	anim_player.add_animation_library("", lib)
	
	# No autoplay - will be triggered by click
	# anim_player.autoplay = "levitate"
	
	return anim_player


func _create_walls() -> Array[StaticBody3D]:
	var walls: Array[StaticBody3D] = []
	var wall_count = 8  # More walls
	
	# Wall dimensions - BIG walls
	var wall_height = 4.0
	var wall_width = 8.0
	var wall_depth = 1.0
	
	# Place walls closer to center so they're easy to hit
	var min_distance = 10.0
	var max_distance = 25.0
	
	for i in wall_count:
		var wall = StaticBody3D.new()
		wall.name = "wall_%d" % i
		
		# Evenly spaced around center with slight randomness
		var base_angle = (float(i) / wall_count) * TAU
		var angle = base_angle + randf_range(-0.2, 0.2)
		var distance = randf_range(min_distance, max_distance)
		var pos_x = cos(angle) * distance
		var pos_z = sin(angle) * distance
		
		wall.position = Vector3(pos_x, wall_height / 2.0, pos_z)
		
		# Face toward center (perpendicular to radius) with slight variation
		wall.rotation_degrees.y = rad_to_deg(angle) + 90 + randf_range(-20, 20)
		
		# Collision layer 2 (separate from floor layer 1)
		wall.collision_layer = 2
		wall.collision_mask = 1  # Collides with rocks on layer 1
		
		# Add to "walls" group for easy detection
		wall.add_to_group("walls")
		
		# Visual mesh
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "mesh"
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(wall_width, wall_height, wall_depth)
		mesh_instance.mesh = box_mesh
		
		# Wall material - reddish brick color to stand out
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.3, 0.25, 1.0)  # Reddish-brown brick
		mesh_instance.set_surface_override_material(0, mat)
		
		wall.add_child(mesh_instance)
		
		# Collision shape
		var collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(wall_width, wall_height, wall_depth)
		collision.shape = box_shape
		
		wall.add_child(collision)
		
		walls.append(wall)
	
	return walls
