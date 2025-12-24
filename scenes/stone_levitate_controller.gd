extends Node3D

## Stone Levitation VFX Controller
## - Click on floor to spawn and levitate rock at that position
## - Click again while hovering to shoot toward cursor
## - Rock lands with physics and disappears after 2s

# State machine
enum State { IDLE, RISING, HOVERING, SHOOTING, FALLING, LANDED, HIDDEN, SHATTERED }
var current_state: State = State.IDLE

# Preload shattered rock pieces
var rock_pieces_scene: PackedScene = preload("res://assets/models/rock_pieces.glb")

# Node references
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var stone: RigidBody3D = $stone
@onready var debris: GPUParticles3D = $debris
@onready var smoke: GPUParticles3D = $smoke
@onready var camera: Camera3D = $Camera3D
@onready var floor_node: Node3D = $floor

# Shoot effect nodes (created dynamically)
var shoot_debris: GPUParticles3D
var shoot_smoke: GPUParticles3D

# Screen shake
var camera_original_pos: Vector3
var shake_timer: float = 0.0
var shake_intensity: float = 0.0

# Landing detection
var landed_timer: float = 0.0
const LAND_DISAPPEAR_TIME: float = 2.0
const VELOCITY_THRESHOLD: float = 2.0  # More lenient

# Shooting timeout (force land after this many seconds)
var shoot_timer: float = 0.0
const SHOOT_TIMEOUT: float = 5.0

# Spawn position
var spawn_position: Vector3 = Vector3.ZERO

# Shatter pieces tracking
var shatter_pieces: Array[RigidBody3D] = []
var shatter_timer: float = 0.0
const SHATTER_DISAPPEAR_TIME: float = 2.0

func _ready():
	print("\n" + "=".repeat(60))
	print("=== STONE LEVITATE VFX READY ===")
	print("=".repeat(60))
	
	if has_meta("generator_version"):
		print("  ✅ Version: ", get_meta("generator_version"))
	
	# Store camera original position for shake
	if camera:
		camera_original_pos = camera.position
	
	# Create shoot effect particles
	_create_shoot_effects()
	
	# Hide stone initially and setup collision detection
	if stone:
		stone.visible = false
		# Ensure contact monitoring is enabled for body_entered signal
		stone.contact_monitor = true
		stone.max_contacts_reported = 4
		stone.body_entered.connect(_on_stone_body_entered)
		print("  ✓ Stone collision monitoring enabled")
	
	print("\n✓✓✓ READY!")
	print("  - Click on FLOOR to spawn rock at that location")
	print("  - Click again while hovering to SHOOT toward cursor!\n")

func _create_shoot_effects():
	# Create backward debris burst for shooting
	shoot_debris = GPUParticles3D.new()
	shoot_debris.name = "shoot_debris"
	shoot_debris.emitting = false
	shoot_debris.one_shot = true
	shoot_debris.amount = 8
	shoot_debris.lifetime = 1.0
	shoot_debris.explosiveness = 1.0
	shoot_debris.visible = false
	
	var debris_mesh = load("res://assets/models/debris.obj") as Mesh
	if debris_mesh:
		shoot_debris.draw_pass_1 = debris_mesh
	
	var debris_mat = StandardMaterial3D.new()
	debris_mat.albedo_color = Color(0.45, 0.35, 0.25, 1.0)
	shoot_debris.material_override = debris_mat
	
	var debris_pm = ParticleProcessMaterial.new()
	debris_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	debris_pm.emission_sphere_radius = 0.1
	debris_pm.direction = Vector3(0, 0, 1)
	debris_pm.spread = 30.0
	debris_pm.initial_velocity_min = 4.0
	debris_pm.initial_velocity_max = 6.0
	debris_pm.gravity = Vector3(0, -15, 0)
	debris_pm.scale_min = 0.2
	debris_pm.scale_max = 0.5
	shoot_debris.process_material = debris_pm
	
	add_child(shoot_debris)
	
	# Create impact smoke puff
	shoot_smoke = GPUParticles3D.new()
	shoot_smoke.name = "shoot_smoke"
	shoot_smoke.emitting = false
	shoot_smoke.one_shot = true
	shoot_smoke.amount = 12
	shoot_smoke.lifetime = 1.0
	shoot_smoke.explosiveness = 1.0
	shoot_smoke.visible = false
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	shoot_smoke.draw_pass_1 = quad
	
	var smoke_mat = StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.albedo_color = Color(0.6, 0.55, 0.45, 0.9)
	var smoke_tex = load("res://assets/textures/smoke.png") as Texture2D
	if smoke_tex:
		smoke_mat.albedo_texture = smoke_tex
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	shoot_smoke.material_override = smoke_mat
	
	var smoke_pm = ParticleProcessMaterial.new()
	smoke_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_pm.emission_sphere_radius = 0.2
	smoke_pm.direction = Vector3(0, 0, 0)
	smoke_pm.spread = 180.0
	smoke_pm.initial_velocity_min = 1.0
	smoke_pm.initial_velocity_max = 2.0
	smoke_pm.gravity = Vector3(0, 0, 0)
	smoke_pm.damping_min = 3.0
	smoke_pm.damping_max = 5.0
	
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0.0, 1.0))
	alpha_curve.add_point(Vector2(0.3, 0.6))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	var alpha_tex = CurveTexture.new()
	alpha_tex.curve = alpha_curve
	smoke_pm.alpha_curve = alpha_tex
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.5, 1.0))
	scale_curve.add_point(Vector2(1.0, 1.2))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	smoke_pm.scale_curve = scale_tex
	
	shoot_smoke.process_material = smoke_pm
	add_child(shoot_smoke)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_click(event.position)

func _handle_click(mouse_pos: Vector2):
	match current_state:
		State.IDLE, State.HIDDEN, State.SHATTERED:
			# Clean up any existing shatter pieces first
			if current_state == State.SHATTERED:
				_cleanup_shatter_pieces()
			# Raycast to floor to get spawn position
			var floor_pos = _get_floor_target(mouse_pos)
			if floor_pos != Vector3.ZERO:
				print("\n=== CLICK: Spawning rock at ", floor_pos, " ===")
				spawn_position = floor_pos
				_start_levitation()
			else:
				print("  (Click on the floor to spawn rock)")
		State.HOVERING:
			print("\n=== CLICK: Shooting rock! ===")
			_shoot_rock(mouse_pos)
		State.RISING:
			print("  (Rock is rising, wait for hover)")
		State.SHOOTING, State.FALLING:
			print("  (Rock is in motion)")
		State.LANDED:
			print("  (Rock has landed, wait for reset)")

func _get_floor_target(mouse_pos: Vector2) -> Vector3:
	if not camera:
		return Vector3.ZERO
	
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	
	# Intersect with y=0 plane (floor level)
	if abs(dir.y) < 0.001:
		return Vector3.ZERO  # Ray parallel to floor
	
	var t = -from.y / dir.y
	if t < 0:
		return Vector3.ZERO  # Target behind camera
	
	var target = from + dir * t
	
	# Clamp to floor bounds (50 units from center for 100x100 floor)
	target.x = clamp(target.x, -45, 45)
	target.z = clamp(target.z, -45, 45)
	
	return target

func _start_levitation():
	current_state = State.RISING
	
	if stone:
		# Start below ground with collision disabled temporarily
		stone.position = Vector3(spawn_position.x, -0.8, spawn_position.z)
		stone.rotation = Vector3.ZERO
		stone.linear_velocity = Vector3.ZERO
		stone.angular_velocity = Vector3.ZERO
		stone.visible = true
		
		# Disable collision during rise (so rock can pass through floor)
		stone.collision_layer = 0
		stone.collision_mask = 0
		
		# Unfreeze and apply strong upward impulse
		stone.freeze = false
		stone.apply_central_impulse(Vector3(0, 60, 0))  # Strong upward launch
		
		print("  Stone rising from underground: pos=", stone.position)
	
	# Position particles at spawn location
	if debris:
		debris.position = Vector3(spawn_position.x, 0.1, spawn_position.z)
		debris.restart()
		debris.visible = true
	if smoke:
		smoke.position = Vector3(spawn_position.x, 0.05, spawn_position.z)
		smoke.visible = true
	
	# Hide shoot effects
	if shoot_debris:
		shoot_debris.visible = false
	if shoot_smoke:
		shoot_smoke.visible = false
	
	# After rise, enable collision and freeze for hover
	var hover_timer = get_tree().create_timer(0.25)
	hover_timer.timeout.connect(_on_hover_start)

func _on_hover_start():
	if current_state == State.RISING and stone:
		# Freeze at hover height
		stone.freeze = true
		stone.position.y = 1.2  # Hover height
		
		# Re-enable collision for when we shoot/fall
		# Layer 1 = floor, Layer 2 = walls, Mask 3 = collide with both
		stone.collision_layer = 1
		stone.collision_mask = 3
		
		current_state = State.HOVERING
		print("  State -> HOVERING at ", stone.position, " (click to shoot!)")
		
		# Auto-fall after 3 seconds if not shot
		var fall_timer = get_tree().create_timer(3.0)
		fall_timer.timeout.connect(_on_hover_timeout)

func _on_hover_timeout():
	if current_state == State.HOVERING:
		print("  Hover timeout - falling naturally")
		current_state = State.FALLING
		shoot_timer = SHOOT_TIMEOUT  # Use same timeout for falling
		if stone:
			stone.freeze = false

func _shoot_rock(mouse_pos: Vector2):
	current_state = State.SHOOTING
	
	# Ensure collision with walls is enabled
	if stone:
		stone.collision_layer = 1
		stone.collision_mask = 3  # Layer 1 (floor) + Layer 2 (walls)
		print("  Collision mask set to 3 (floor + walls)")
	
	# Get target position on floor
	var target = _get_floor_target(mouse_pos)
	if target == Vector3.ZERO:
		target = stone.position + Vector3(0, 0, -10)  # Default forward
	
	print("  Target: ", target)
	print("  Rock at: ", stone.position)
	
	# Calculate direction and distance
	var to_target = target - stone.position
	to_target.y = 0  # Horizontal only
	var distance = to_target.length()
	var direction = to_target.normalized()
	
	print("  Distance: ", distance)
	print("  Direction: ", direction)
	
	# Unfreeze
	stone.freeze = false
	
	# Fast, powerful shot with slight random deviation
	var base_speed = 45.0  # Much faster base speed
	
	# Add small random radial offset (perpendicular to direction)
	var perpendicular = Vector3(-direction.z, 0, direction.x)  # 90° rotated
	var radial_offset = perpendicular * randf_range(-0.08, 0.08)  # Small sideways drift
	var vertical_wobble = randf_range(-0.02, 0.05)  # Tiny vertical variance
	
	var shoot_direction = (direction + radial_offset).normalized()
	shoot_direction.y = 0.15 + vertical_wobble  # Low arc with slight variance
	
	var impulse = shoot_direction * base_speed * stone.mass
	
	# Add slight random spin for natural tumbling
	stone.apply_torque_impulse(Vector3(
		randf_range(-2, 2),
		randf_range(-1, 1),
		randf_range(-2, 2)
	))
	
	print("  Impulse: ", impulse)
	stone.apply_central_impulse(impulse)
	
	# Start shoot timer (fallback for landing detection)
	shoot_timer = SHOOT_TIMEOUT
	
	# Trigger shoot effects
	_trigger_shoot_effects(direction)
	
	# Start screen shake
	_start_screen_shake(0.15, 0.2)

func _trigger_shoot_effects(shoot_direction: Vector3):
	var rock_pos = stone.position
	
	if shoot_debris:
		shoot_debris.position = rock_pos
		var backward = -shoot_direction
		if backward.length() > 0.01:
			shoot_debris.look_at(rock_pos + backward, Vector3.UP)
		shoot_debris.visible = true
		shoot_debris.restart()
	
	if shoot_smoke:
		shoot_smoke.position = rock_pos
		shoot_smoke.visible = true
		shoot_smoke.restart()

func _start_screen_shake(intensity: float, duration: float):
	shake_intensity = intensity
	shake_timer = duration

func _process(delta):
	# Screen shake
	if shake_timer > 0:
		shake_timer -= delta
		if camera:
			var offset = Vector3(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
			camera.position = camera_original_pos + offset
		
		if shake_timer <= 0 and camera:
			camera.position = camera_original_pos
	
	# Landing detection for shooting state
	if current_state == State.SHOOTING or current_state == State.FALLING:
		# Decrement shoot timer
		shoot_timer -= delta
		
		if stone:
			var vel = stone.linear_velocity.length()
			var y_pos = stone.position.y
			
			# Check if rock has landed (on or below floor level with low velocity)
			if y_pos <= 0.8 and vel < VELOCITY_THRESHOLD:
				_on_rock_landed()
			# Timeout fallback - force land after SHOOT_TIMEOUT seconds
			elif shoot_timer <= 0:
				print("  Shoot timeout reached, forcing land")
				_on_rock_landed()
			# Rock fell off the map (below floor significantly)
			elif y_pos < -2.0:
				print("  Rock fell off map")
				_on_rock_landed()
	
	# Landed timer countdown
	if current_state == State.LANDED:
		landed_timer -= delta
		if landed_timer <= 0:
			_hide_everything()
	
	# Shatter pieces cleanup timer
	if current_state == State.SHATTERED:
		shatter_timer -= delta
		if shatter_timer <= 0:
			_cleanup_shatter_pieces()

func _on_rock_landed():
	if current_state == State.LANDED:
		return  # Already landed
	
	current_state = State.LANDED
	landed_timer = LAND_DISAPPEAR_TIME
	print("  Rock landed at ", stone.position, "! Disappearing in ", LAND_DISAPPEAR_TIME, "s")

func _hide_everything():
	current_state = State.HIDDEN
	
	if stone:
		stone.visible = false
		stone.freeze = true
	if debris:
		debris.visible = false
	if smoke:
		smoke.visible = false
	if shoot_debris:
		shoot_debris.visible = false
	if shoot_smoke:
		shoot_smoke.visible = false
	
	print("  Hidden. Click on floor to spawn again!")


func _on_stone_body_entered(body: Node):
	print("  [Collision] body_entered: ", body.name, " state=", State.keys()[current_state])
	
	# Only shatter if shooting and hit a wall
	if current_state != State.SHOOTING:
		print("    -> Ignored (not shooting)")
		return
	
	# Check if it's a wall (name starts with "wall_")
	if body.name.begins_with("wall_"):
		print("\n=== WALL HIT! Shattering rock! ===")
		_shatter_rock(body)  # Pass the wall we hit
	else:
		print("    -> Not a wall, ignoring")


func _shatter_rock(wall: Node3D):
	if not stone:
		return
	
	# Capture rock's momentum before hiding
	var rock_pos = stone.global_position
	var rock_vel = stone.linear_velocity
	var wall_pos = wall.global_position if wall else rock_pos
	
	print("  Rock velocity at impact: ", rock_vel)
	print("  Rock position: ", rock_pos)
	print("  Wall position: ", wall_pos)
	
	# Hide original rock
	stone.visible = false
	stone.freeze = true
	stone.collision_layer = 0
	stone.collision_mask = 0
	
	# Spawn shattered pieces - pass wall position for proper normal calculation
	_spawn_shatter_pieces(rock_pos, rock_vel, wall_pos)
	
	# Trigger impact effects at collision point
	_trigger_impact_effects(rock_pos, rock_vel)
	
	# Screen shake for impact
	_start_screen_shake(0.2, 0.25)
	
	# Start shatter cleanup timer
	current_state = State.SHATTERED
	shatter_timer = SHATTER_DISAPPEAR_TIME


func _trigger_impact_effects(impact_pos: Vector3, _impact_vel: Vector3):
	# Debris burst at impact
	if shoot_debris:
		shoot_debris.position = impact_pos
		shoot_debris.visible = true
		shoot_debris.restart()


func _spawn_shatter_pieces(rock_pos: Vector3, _incoming_velocity: Vector3, _wall_pos: Vector3):
	# Clean up any existing pieces first
	_cleanup_shatter_pieces()
	
	# Instantiate the rock_pieces scene
	var pieces_instance = rock_pieces_scene.instantiate()
	
	# Get all mesh children from the GLB
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(pieces_instance, meshes)
	
	print("  Found ", meshes.size(), " piece meshes in rock_pieces.glb")
	
	# === SIMPLE APPROACH: Let physics engine handle collisions naturally ===
	# Don't try to manually calculate reflections - just spawn pieces and let them
	# collide with walls/floor naturally via the physics engine
	
	for i in meshes.size():
		var mesh_node = meshes[i]
		var piece_rigid = RigidBody3D.new()
		piece_rigid.name = "shatter_piece_%d" % i
		
		# Spawn at rock position with small random offset
		var local_offset = mesh_node.global_transform.origin * 0.3
		var random_offset = Vector3(
			randf_range(-0.2, 0.2),
			randf_range(0, 0.2),
			randf_range(-0.2, 0.2)
		)
		piece_rigid.position = rock_pos + local_offset + random_offset
		
		# Physics properties
		piece_rigid.mass = 0.6
		piece_rigid.physics_material_override = PhysicsMaterial.new()
		piece_rigid.physics_material_override.bounce = 0.5  # Good bounce off walls
		piece_rigid.physics_material_override.friction = 0.7
		piece_rigid.angular_damp = 1.0
		piece_rigid.linear_damp = 0.2
		piece_rigid.freeze = false
		piece_rigid.continuous_cd = true  # Prevent tunneling
		
		# === KEY FIX: Collide with BOTH floor (layer 1) AND walls (layer 2) ===
		piece_rigid.collision_layer = 1
		piece_rigid.collision_mask = 3  # Binary 11 = layers 1 and 2
		
		# Clone the mesh
		var piece_mesh = MeshInstance3D.new()
		piece_mesh.name = "mesh"
		piece_mesh.mesh = mesh_node.mesh
		piece_mesh.scale = Vector3(0.8, 0.8, 0.8)
		
		# Apply material
		var mat = StandardMaterial3D.new()
		var rock_tex = load("res://assets/textures/T_rocks_A_color.png") as Texture2D
		if rock_tex:
			mat.albedo_texture = rock_tex
		else:
			mat.albedo_color = Color(0.6, 0.5, 0.4, 1.0)
		piece_mesh.set_surface_override_material(0, mat)
		
		piece_rigid.add_child(piece_mesh)
		
		# Collision shape
		var collision = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.3, 0.3, 0.3)
		collision.shape = box
		piece_rigid.add_child(collision)
		
		# Add to scene
		add_child(piece_rigid)
		shatter_pieces.append(piece_rigid)
		
		# === SIMPLE VELOCITY: Start with ZERO, apply small random impulse ===
		# Let the physics engine handle wall/floor collisions naturally
		piece_rigid.linear_velocity = Vector3.ZERO
		
		# Small random explosion impulse (not directional - just scatter)
		var impulse = Vector3(
			randf_range(-3, 3),
			randf_range(2, 5),  # Upward bias
			randf_range(-3, 3)
		)
		piece_rigid.apply_central_impulse(impulse)
		
		# Random tumbling
		piece_rigid.angular_velocity = Vector3(
			randf_range(-5, 5),
			randf_range(-3, 3),
			randf_range(-5, 5)
		)
	
	# Clean up the instance
	pieces_instance.queue_free()
	
	print("  Spawned ", shatter_pieces.size(), " pieces (physics engine handles collisions)")


func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]):
	if node is MeshInstance3D and node.mesh:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)


func _cleanup_shatter_pieces():
	for piece in shatter_pieces:
		if is_instance_valid(piece):
			piece.queue_free()
	shatter_pieces.clear()
	
	# Also hide other effects
	if debris:
		debris.visible = false
	if smoke:
		smoke.visible = false
	if shoot_debris:
		shoot_debris.visible = false
	if shoot_smoke:
		shoot_smoke.visible = false
	
	current_state = State.HIDDEN
	print("  Shatter pieces cleaned up. Click on floor to spawn again!")
