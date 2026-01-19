extends Node3D
class_name FlameRingParticles

## Flame Ring VFX - burst of fire chunks that expand outward from a ring
## Call play() to trigger the effect

@export_group("Ring Settings")
@export var ring_radius: float = 1.0
@export var ring_thickness: float = 0.15  ## How thick the spawn ring is
@export var vertical_ring: bool = true  ## true = faces camera, false = horizontal

@export_group("Particle Count & Timing")
@export_range(80, 300) var amount: int = 160
@export var lifetime: float = 3  ## Slowed down for testing
@export var one_shot: bool = true

@export_group("Motion")
@export var radial_accel: float = 30.0  ## Slowed down - push outward from center
@export var initial_velocity: float = 1.0
@export var velocity_randomness: float = 0.7
@export var tangential_accel: float = 5.0  ## Swirl/wheel feel
@export var linear_damping: float = 2.0  ## Stops them from flying forever
@export var gravity: Vector3 = Vector3(0, 0.5, 0)  ## Slight upward drift

@export_group("Size")
@export var base_scale: float = 0.4
@export var scale_randomness: float = 0.7

@export_group("Visuals")
@export var fire_texture: Texture2D
@export var intensity: float = 3.0

var particles: GPUParticles3D
var material: ShaderMaterial

func _ready():
	_setup_particles()

func _setup_particles():
	# Create GPUParticles3D
	particles = GPUParticles3D.new()
	particles.name = "FlameRingParticles"
	add_child(particles)
	
	# Basic settings
	particles.emitting = false
	particles.one_shot = one_shot
	particles.explosiveness = 0.95  # Slightly staggered for less uniform look
	particles.randomness = 0.3  # Add spawn randomness
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = 0.0
	
	# Process material
	var process_mat = ParticleProcessMaterial.new()
	
	# === EMISSION SHAPE: Ring ===
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	# Vertical ring (faces camera) vs horizontal ring
	if vertical_ring:
		process_mat.emission_ring_axis = Vector3(0, 0, 1)  # Z-axis = vertical ring facing camera
	else:
		process_mat.emission_ring_axis = Vector3(0, 1, 0)  # Y-axis = horizontal ring
	process_mat.emission_ring_radius = ring_radius
	process_mat.emission_ring_inner_radius = ring_radius - ring_thickness
	process_mat.emission_ring_height = 0.05  # Small height for less uniform look
	
	# Add randomness to break up uniform spacing
	process_mat.emission_shape_offset = Vector3(0, 0, 0)
	process_mat.flatness = 0.0
	
	# === MOTION ===
	process_mat.initial_velocity_min = initial_velocity * (1.0 - velocity_randomness)
	process_mat.initial_velocity_max = initial_velocity * (1.0 + velocity_randomness)
	process_mat.direction = Vector3(0, 0, -1)  # Initial direction
	process_mat.spread = 45.0  # Some spread for variety
	process_mat.velocity_pivot = Vector3.ZERO  # Pivot at center for radial motion
	
	# Radial acceleration (pushes outward from center)
	process_mat.radial_accel_min = radial_accel * 0.8
	process_mat.radial_accel_max = radial_accel * 1.2
	
	# Tangential acceleration (swirl)
	process_mat.tangential_accel_min = tangential_accel * 0.5
	process_mat.tangential_accel_max = tangential_accel * 1.5
	
	# Damping (makes them slow down)
	process_mat.damping_min = linear_damping * 0.7
	process_mat.damping_max = linear_damping * 1.3
	
	# Gravity
	process_mat.gravity = gravity
	
	# === ROTATION (lots of randomness so particles look different) ===
	process_mat.angle_min = -180.0
	process_mat.angle_max = 180.0
	process_mat.angular_velocity_min = -20.0  # Some spin backwards
	process_mat.angular_velocity_max = 20.0   # Some spin forwards
	
	# === SIZE (high randomness for variety) ===
	process_mat.scale_min = base_scale * 0.3   # Some very small
	process_mat.scale_max = base_scale * 1.8   # Some quite large
	
	# Scale over lifetime: start slightly larger, then shrink
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.2))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.6))
	var scale_curve_tex = CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	process_mat.scale_curve = scale_curve_tex
	
	# === COLOR / ALPHA ===
	var gradient = Gradient.new()
	# Fire color ramp: white-yellow -> orange -> red -> transparent
	gradient.set_color(0, Color(1.0, 1.0, 0.9, 1.0))  # White-yellow at start
	gradient.add_point(0.15, Color(1.0, 0.85, 0.3, 1.0))  # Yellow-orange
	gradient.add_point(0.45, Color(1.0, 0.4, 0.1, 1.0))  # Orange-red
	gradient.add_point(0.75, Color(0.6, 0.1, 0.05, 0.6))  # Dark red, fading
	gradient.set_color(1, Color(0.3, 0.05, 0.0, 0.0))  # Transparent
	
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex
	
	particles.process_material = process_mat
	
	# === DRAW PASS: Quad mesh with fire material ===
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	particles.draw_pass_1 = quad
	
	# Create fire material
	_setup_fire_material()

func _setup_fire_material():
	# Use a simple additive fire material
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true  # Use particle color
	mat.albedo_color = Color(1.0, 0.8, 0.4)  # Warm base color
	
	# Emission for glow
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = intensity
	
	if fire_texture:
		mat.albedo_texture = fire_texture
		print("  Applied fire texture to material")
	else:
		# No texture - create a simple gradient circle
		print("  No texture - using solid color")
	
	particles.material_override = mat

## Call this to play the effect
func play():
	if particles:
		particles.restart()
		particles.emitting = true

## Call this to update parameters at runtime
func update_parameters():
	_setup_particles()

## Static helper to spawn a flame ring at a position
static func spawn_at(parent: Node, pos: Vector3, radius: float = 1.0) -> FlameRingParticles:
	var ring = FlameRingParticles.new()
	ring.ring_radius = radius
	parent.add_child(ring)
	ring.global_position = pos
	ring.play()
	
	# Auto-cleanup after effect finishes
	var timer = ring.get_tree().create_timer(ring.lifetime + 0.5)
	timer.timeout.connect(ring.queue_free)
	
	return ring
