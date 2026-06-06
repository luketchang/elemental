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
@export var camera_distance: float = 3.0
## While aiming, the camera pulls in and shifts to the shoulder so the player
## body doesn't block the arc/ball (which fly along the camera's forward).
@export var aim_camera_distance: float = 1.8
@export var aim_side_offset: float = 0.8

@export_group("Throw")
@export var throw_speed: float = 20.0
@export var throw_gravity: float = 20.0
## Upward bias added to the aim direction so throws lob and carry farther.
@export var launch_lift: float = 0.4
## Time (s) into the Throw clip where the arm is cocked back — held while aiming.
@export var aim_hold_time: float = 0.5
## Time (s) into the Throw clip where the ball leaves the hand.
@export var release_time: float = 0.85
@export var throw_height: float = 1.4
@export var throw_forward: float = 0.6
@export var trajectory_dots: int = 40
@export var trajectory_step: float = 0.05

@onready var _yaw: Node3D = $CamYaw
@onready var _spring_arm: SpringArm3D = $CamYaw/SpringArm3D
@onready var _anim: AnimationPlayer = $Mannequin/AnimationPlayer
@onready var _mannequin: Node3D = $Mannequin
@onready var _camera: Camera3D = $CamYaw/SpringArm3D/Camera3D

const POKEBALL_SCENE: PackedScene = preload("res://scenes/pokeball.tscn")
const THROW_ANIM: String = "Throw/mixamo_com"

enum State { NORMAL, AIMING, THROWING }

var _pitch: float = 0.0
var _state: int = State.NORMAL
var _ball_thrown: bool = false
var _dots: Array[MeshInstance3D] = []
var _trajectory_root: Node3D
var _landing_ring: MeshInstance3D
var _skel: Skeleton3D
var _hand_bone: int = -1


func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Stop the spring arm from colliding with our own body.
	_spring_arm.add_excluded_object(get_rid())
	_spring_arm.spring_length = camera_distance
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
	_setup_throw()


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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		if _state == State.NORMAL:
			_enter_aiming()
		elif _state == State.AIMING:
			_cancel_aiming()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _state == State.AIMING:
			_start_throw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and _state == State.AIMING:
			_cancel_aiming()


func _physics_process(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		if Input.is_key_pressed(KEY_SPACE) and _state == State.NORMAL:
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	match _state:
		State.NORMAL:
			_process_movement()
			_update_animation(delta)
		State.AIMING:
			velocity.x = 0.0
			velocity.z = 0.0
			_face_camera(delta)
			_hold_windup()
			_update_trajectory()
		State.THROWING:
			velocity.x = 0.0
			velocity.z = 0.0
			_face_camera(delta)
			_check_release()

	move_and_slide()


func _process_movement() -> void:
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


# --- Throw / aim -------------------------------------------------------------

func _setup_throw() -> void:
	# Graft the throw clip onto the mannequin's AnimationPlayer (Throw.fbx imports
	# as an Animation Library, like Walking). It plays once, so keep it non-looping.
	if not _anim.has_animation_library("Throw"):
		var throw_lib: AnimationLibrary = load("res://characters/player/Throw.fbx")
		if throw_lib != null:
			_anim.add_animation_library("Throw", throw_lib)
	if _anim.has_animation(THROW_ANIM):
		_anim.get_animation(THROW_ANIM).loop_mode = Animation.LOOP_NONE
	_anim.animation_finished.connect(_on_anim_finished)
	# Locate the right-hand bone so the throw/arc originate from the hand.
	var skel_node := _mannequin.find_child("Skeleton3D", true, false)
	if skel_node is Skeleton3D:
		_skel = skel_node
		_hand_bone = _skel.find_bone("mixamorig1_RightHand")
		if _hand_bone < 0:
			for b in _skel.get_bone_count():
				if _skel.get_bone_name(b).findn("righthand") != -1:
					_hand_bone = b
					break
	_build_trajectory_visuals()


func _build_trajectory_visuals() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.45, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.06
	dot_mesh.height = 0.12
	dot_mesh.radial_segments = 6
	dot_mesh.rings = 4
	_trajectory_root = Node3D.new()
	add_child(_trajectory_root)
	for i in trajectory_dots:
		var d := MeshInstance3D.new()
		d.mesh = dot_mesh
		d.material_override = mat
		d.visible = false
		_trajectory_root.add_child(d)
		_dots.append(d)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.5
	_landing_ring = MeshInstance3D.new()
	_landing_ring.mesh = ring
	_landing_ring.material_override = mat
	_landing_ring.visible = false
	add_child(_landing_ring)


func _enter_aiming() -> void:
	_state = State.AIMING
	_ball_thrown = false
	_set_aim_camera(true)
	if _anim.has_animation(THROW_ANIM):
		_anim.speed_scale = 1.0
		_anim.play(THROW_ANIM)


func _hold_windup() -> void:
	# Let the windup play to the cocked pose, then freeze there until thrown.
	if _anim.current_animation == THROW_ANIM and _anim.current_animation_position >= aim_hold_time:
		_anim.speed_scale = 0.0


func _start_throw() -> void:
	_state = State.THROWING
	_hide_trajectory()
	_anim.speed_scale = 1.0
	if not _anim.has_animation(THROW_ANIM):
		# No throw clip (e.g. Throw.fbx not reimported yet) — just throw and reset.
		_end_throw()
		return
	if _anim.current_animation != THROW_ANIM:
		_anim.play(THROW_ANIM)


func _check_release() -> void:
	if not _ball_thrown and _anim.current_animation_position >= release_time:
		_spawn_ball()
		_ball_thrown = true


func _cancel_aiming() -> void:
	_state = State.NORMAL
	_hide_trajectory()
	_set_aim_camera(false)
	_anim.speed_scale = 1.0
	_anim.play("mixamo_com")


func _end_throw() -> void:
	if not _ball_thrown:
		_spawn_ball()
		_ball_thrown = true
	_state = State.NORMAL
	_set_aim_camera(false)
	_anim.speed_scale = 1.0
	_anim.play("mixamo_com")


func _set_aim_camera(active: bool) -> void:
	# Over-the-shoulder while aiming so the body doesn't block the throw line.
	if active:
		_spring_arm.spring_length = aim_camera_distance
		_spring_arm.position.x = aim_side_offset
	else:
		_spring_arm.spring_length = camera_distance
		_spring_arm.position.x = 0.0


func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == THROW_ANIM and _state == State.THROWING:
		_end_throw()


func _face_camera(delta: float) -> void:
	var fwd: Vector3 = -_camera.global_transform.basis.z
	var yaw: float = atan2(fwd.x, fwd.z)
	_mannequin.rotation.y = lerp_angle(_mannequin.rotation.y, yaw, turn_speed * delta)


func _aim_direction() -> Vector3:
	var dir: Vector3 = (-_camera.global_transform.basis.z).normalized()
	dir.y += launch_lift
	dir.y = clampf(dir.y, -0.6, 1.5)
	return dir.normalized()


func _throw_origin() -> Vector3:
	# Originate from the actual throwing hand if we found it; else chest height.
	if _skel != null and _hand_bone >= 0:
		return _skel.global_transform * _skel.get_bone_global_pose(_hand_bone).origin
	return global_position + Vector3(0.0, throw_height, 0.0)


func _spawn_ball() -> void:
	var ball := POKEBALL_SCENE.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(ball)
	var dir: Vector3 = _aim_direction()
	ball.global_position = _throw_origin() + dir * throw_forward
	# Match the ball's gravity to the previewed arc and drop drag so it tracks it.
	var default_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	ball.gravity_scale = throw_gravity / default_gravity
	ball.linear_damp = 0.0
	ball.add_collision_exception_with(self)
	ball.linear_velocity = dir * throw_speed


func _update_trajectory() -> void:
	var dir: Vector3 = _aim_direction()
	var origin: Vector3 = _throw_origin() + dir * throw_forward
	var v0: Vector3 = dir * throw_speed
	var g: Vector3 = Vector3(0.0, -throw_gravity, 0.0)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var prev: Vector3 = origin
	var landing: Vector3 = Vector3.INF
	var shown: int = 0
	for i in range(1, trajectory_dots + 1):
		var t: float = i * trajectory_step
		var p: Vector3 = origin + v0 * t + 0.5 * g * t * t
		var query := PhysicsRayQueryParameters3D.create(prev, p)
		query.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			landing = hit.position
			_place_dot(shown, landing)
			shown += 1
			break
		_place_dot(shown, p)
		shown += 1
		prev = p
	for j in range(shown, _dots.size()):
		_dots[j].visible = false
	if landing != Vector3.INF:
		_landing_ring.visible = true
		_landing_ring.global_position = landing + Vector3(0.0, 0.05, 0.0)
	else:
		_landing_ring.visible = false


func _place_dot(index: int, pos: Vector3) -> void:
	if index < _dots.size():
		_dots[index].visible = true
		_dots[index].global_position = pos


func _hide_trajectory() -> void:
	for d in _dots:
		d.visible = false
	if _landing_ring != null:
		_landing_ring.visible = false
