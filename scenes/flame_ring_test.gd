extends Node3D

## Simple flipbook animation test
## Press SPACE to play the fire impact flipbook

var camera: Camera3D
var mesh: MeshInstance3D
var material: ShaderMaterial
var is_playing: bool = false
var current_time: float = 0.0

@export var flipbook_duration: float = 0.5  # Total animation time
@export var rows: int = 2
@export var cols: int = 2

func _ready():
	# Create camera
	camera = Camera3D.new()
	camera.position = Vector3(0, 0, 3)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	add_child(camera)
	
	# Create quad to display flipbook
	mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2.5, 2.5)
	mesh.mesh = quad
	add_child(mesh)
	
	# Create shader material for flipbook with additive blending
	_setup_flipbook_material()
	
	print("Controls:")
	print("  SPACE - Play animation")
	print("  UP/DOWN - Adjust speed (current: %.2fs)" % flipbook_duration)

func _setup_flipbook_material():
	# Create shader for flipbook animation
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform sampler2D flipbook_tex : source_color;
uniform int rows = 2;
uniform int cols = 2;
uniform int current_frame = 0;
uniform float intensity = 2.0;

void fragment() {
	// Calculate UV for current frame
	float frame_width = 1.0 / float(cols);
	float frame_height = 1.0 / float(rows);
	
	int col = current_frame % cols;
	int row = current_frame / cols;
	
	vec2 frame_uv = vec2(
		float(col) * frame_width + UV.x * frame_width,
		float(row) * frame_height + UV.y * frame_height
	);
	
	vec4 tex_color = texture(flipbook_tex, frame_uv);
	
	// Additive: black becomes transparent, bright colors glow
	float alpha = max(tex_color.r, max(tex_color.g, tex_color.b));
	
	ALBEDO = tex_color.rgb * intensity;
	ALPHA = alpha;
}
"""
	
	material = ShaderMaterial.new()
	material.shader = shader
	
	# Load flipbook texture
	var tex = load("res://assets/flipbooks/fire-impact.png")
	if tex:
		material.set_shader_parameter("flipbook_tex", tex)
		print("✓ Loaded fire-impact.png flipbook")
	else:
		print("✗ Could not load flipbook texture")
	
	material.set_shader_parameter("rows", rows)
	material.set_shader_parameter("cols", cols)
	material.set_shader_parameter("current_frame", 0)
	material.set_shader_parameter("intensity", 2.5)
	
	mesh.material_override = material

func _process(delta):
	# Press space to play
	if Input.is_action_just_pressed("ui_accept"):
		play()
	
	# Speed controls
	if Input.is_key_pressed(KEY_UP):
		flipbook_duration = max(0.1, flipbook_duration - delta * 0.5)
		print("Duration: %.2fs (faster)" % flipbook_duration)
	if Input.is_key_pressed(KEY_DOWN):
		flipbook_duration = min(3.0, flipbook_duration + delta * 0.5)
		print("Duration: %.2fs (slower)" % flipbook_duration)
	
	# Update flipbook animation
	if is_playing:
		current_time += delta
		
		var total_frames = rows * cols
		var frame_duration = flipbook_duration / float(total_frames)
		var frame = int(current_time / frame_duration)
		
		if frame >= total_frames:
			# Animation finished
			is_playing = false
			mesh.visible = false
			print("Flipbook finished")
		else:
			material.set_shader_parameter("current_frame", frame)

func play():
	print("Playing flipbook!")
	is_playing = true
	current_time = 0.0
	mesh.visible = true
	material.set_shader_parameter("current_frame", 0)
