extends CharacterBody3D

## Third-person player controller for the mannequin (scenes/player.tscn):
## WASD to move (camera-relative), mouse to orbit the camera, Shift to sprint,
## Space to jump, Esc to release/recapture the mouse. Drives the idle/walk
## animations and turns the mannequin to face its direction of travel.

@export var move_speed: float = 4.0
@export var sprint_multiplier: float = 2.5
## Ground speed (m/s) the walk clip is authored for. The walk plays faster/slower
## so the feet match actual travel instead of sliding. Lower if feet still skate.
@export var walk_anim_speed: float = 1.4
@export var gravity: float = 30.0
@export var jump_velocity: float = 12.0
@export var mouse_sensitivity: float = 0.003
@export var turn_speed: float = 10.0
@export var min_pitch: float = deg_to_rad(-80.0)
@export var max_pitch: float = deg_to_rad(70.0)

@onready var _yaw: Node3D = $CamYaw
@onready var _spring_arm: SpringArm3D = $CamYaw/SpringArm3D
@onready var _anim: AnimationPlayer = $Mannequin/AnimationPlayer
@onready var _mannequin: Node3D = $Mannequin

var _pitch: float = 0.0


func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Stop the spring arm from colliding with our own body.
	_spring_arm.add_excluded_object(get_rid())
	# The walk clips live in a separate imported library. Add it at runtime so the
	# setup survives Godot re-serializing player.tscn (which drops the
	# AnimationPlayer's library overrides and leaves only the idle).
	if not _anim.has_animation_library("Walking"):
		var walk_lib: AnimationLibrary = load("res://characters/player/Walking.fbx")
		if walk_lib != null:
			_anim.add_animation_library("Walking", walk_lib)
	# Mixamo clips import non-looping; force looping so movement stays continuous.
	for clip in ["mixamo_com", "Walking/mixamo_com"]:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	# The Mixamo walk travels forward (motion baked into the hips), so the mesh
	# drifts then snaps back each loop. Lock the hips' horizontal translation on
	# the walk clip so it cycles in place; the body is moved by velocity instead.
	# (Root-motion extraction would do this too, but it's global and also strips
	# the idle's hip rotation, which makes the character lean.)
	_lock_walk_in_place()
	_anim.play("mixamo_com")

	_align_feet_to_ground()


func _lock_walk_in_place() -> void:
	# Pin the hips' X/Z to their first-frame value so the walk doesn't travel
	# forward (which caused drift + a snap-back at each loop). Keep Y so the
	# vertical step bob is preserved. Idle is left alone.
	var anim: Animation = _anim.get_animation("Walking/mixamo_com")
	if anim == null:
		return
	var track: int = anim.find_track(NodePath("Skeleton3D:mixamorig1_Hips"), Animation.TYPE_POSITION_3D)
	if track < 0:
		return
	var key_count: int = anim.track_get_key_count(track)
	if key_count == 0:
		return
	var base: Vector3 = anim.track_get_key_value(track, 0)
	for k in key_count:
		var v: Vector3 = anim.track_get_key_value(track, k)
		anim.track_set_key_value(track, k, Vector3(base.x, v.y, base.z))


func _align_feet_to_ground() -> void:
	# The collider's base sits at the body origin (y=0), which is where the feet
	# should rest. Mixamo's mesh origin isn't exactly at the soles, so the
	# character floats (or sinks). Find the mesh's lowest point and shift the
	# mannequin so that point lines up with the body origin / ground.
	var lowest: float = INF
	var stack: Array[Node] = [_mannequin]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is VisualInstance3D:
			var aabb: AABB = (node as VisualInstance3D).get_aabb()
			var to_mannequin: Transform3D = _mannequin.global_transform.affine_inverse() * (node as Node3D).global_transform
			for i in 8:
				lowest = minf(lowest, (to_mannequin * aabb.get_endpoint(i)).y)
		for child in node.get_children():
			stack.push_back(child)
	if lowest != INF:
		_mannequin.position.y -= lowest


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw.rotation.y -= event.relative.x * mouse_sensitivity
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, min_pitch, max_pitch)
		_spring_arm.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	# Build a movement direction relative to where the camera is facing.
	var input_dir: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir -= _yaw.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += _yaw.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= _yaw.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += _yaw.global_transform.basis.x

	input_dir.y = 0.0
	input_dir = input_dir.normalized()

	var speed: float = move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= sprint_multiplier

	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed

	move_and_slide()

	_update_animation(delta)


func _update_animation(delta: float) -> void:
	# Pick idle/walk from horizontal speed and turn the mannequin to face travel.
	var horizontal: Vector2 = Vector2(velocity.x, velocity.z)
	if horizontal.length() > 0.1:
		if _anim.current_animation != "Walking/mixamo_com":
			_anim.play("Walking/mixamo_com")
		# Match walk playback to ground speed so the feet grip instead of sliding
		# (also speeds the legs up when sprinting).
		_anim.speed_scale = maxf(horizontal.length() / walk_anim_speed, 0.1)
		# This mannequin's mesh faces +Z (Mixamo default), not Godot's -Z, so we
		# aim +Z at the travel direction. Rotate only the mannequin so the camera
		# rig stays under mouse control.
		var target_yaw: float = atan2(velocity.x, velocity.z)
		_mannequin.rotation.y = lerp_angle(_mannequin.rotation.y, target_yaw, turn_speed * delta)
	elif _anim.current_animation != "mixamo_com":
		_anim.play("mixamo_com")
		_anim.speed_scale = 1.0
