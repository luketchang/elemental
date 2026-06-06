extends CharacterBody3D

## Eevee NPC: wanders the map but stays leashed to the player (the mannequin).
## It picks random points within `leash_radius` of the player and walks to them;
## if it ever drifts past the leash it heads straight back. Plays its single
## glb animation (the walk cycle) only while it's actually moving.

@export var move_speed: float = 1.5
@export var gravity: float = 30.0
@export var leash_radius: float = 6.0            # ~20 ft
@export var arrive_distance: float = 0.6         # how close counts as "arrived"
@export var wander_interval_min: float = 2.0
@export var wander_interval_max: float = 4.0
@export var turn_speed: float = 8.0
## Optional manual fine-tune, added on top of the auto-derived facing. Leave at 0
## unless the nose ends up slightly off after auto-calibration.
@export var yaw_offset_degrees: float = 0.0
## Multiplies the walk animation's playback speed by the movement speed so the
## legs cadence with travel (kills foot-sliding). Raise if feet still skate,
## lower if it looks like it's moonwalking.
@export var anim_speed_per_unit: float = 1.0

@onready var _model: Node3D = $Model

var _anim: AnimationPlayer
var _walk_anim: String = ""
var _player: Node3D
var _target: Vector3
var _wander_timer: float = 0.0
var _facing_offset: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_target = global_position
	_compute_facing_offset()
	# The AnimationPlayer lives inside the imported glb; owned=false reaches into it.
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		var clips: PackedStringArray = _anim.get_animation_list()
		if clips.size() > 0:
			_walk_anim = clips[0]
			for clip in clips:
				if clip.findn("walk") != -1 or clip.findn("nla") != -1:
					_walk_anim = clip
					break
			if _anim.has_animation(_walk_anim):
				_anim.get_animation(_walk_anim).loop_mode = Animation.LOOP_LINEAR
				_lock_root_motion_in_place()


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	if _player == null:
		# Player may not be in the tree yet on the first frame — keep trying.
		_player = get_tree().get_first_node_in_group("player") as Node3D
		move_and_slide()
		return

	var here: Vector3 = global_position
	var player_pos: Vector3 = _player.global_position
	var to_player: Vector3 = Vector3(player_pos.x - here.x, 0.0, player_pos.z - here.z)
	var to_target: Vector3 = Vector3(_target.x - here.x, 0.0, _target.z - here.z)

	_wander_timer -= delta
	if to_player.length() > leash_radius:
		# Past the leash: forget wandering, walk straight back to the player.
		_target = player_pos
		to_target = to_player
	elif _wander_timer <= 0.0 or to_target.length() < arrive_distance:
		_pick_new_target(player_pos)
		to_target = Vector3(_target.x - here.x, 0.0, _target.z - here.z)

	if to_target.length() > arrive_distance:
		var dir: Vector3 = to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		# Face travel direction: aim the model's real nose (auto-derived from the
		# skeleton) along the velocity, plus any manual fine-tune.
		var target_yaw: float = atan2(dir.x, dir.z) + _facing_offset + deg_to_rad(yaw_offset_degrees)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, turn_speed * delta)
		_set_walking(true)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_walking(false)

	move_and_slide()


func _pick_new_target(player_pos: Vector3) -> void:
	var angle: float = randf() * TAU
	var radius: float = randf() * leash_radius
	_target = player_pos + Vector3(cos(angle), 0.0, sin(angle)) * radius
	_wander_timer = randf_range(wander_interval_min, wander_interval_max)


func _set_walking(moving: bool) -> void:
	if _anim == null or _walk_anim == "":
		return
	if moving:
		# Cadence the legs to the travel speed so the feet grip instead of sliding.
		_anim.speed_scale = maxf(move_speed * anim_speed_per_unit, 0.1)
		if _anim.current_animation != _walk_anim:
			_anim.play(_walk_anim)
	elif _anim.is_playing():
		_anim.stop()


func _lock_root_motion_in_place() -> void:
	# If the walk clip travels (net forward motion baked into a root bone) it
	# drifts then snaps back on loop while velocity also moves it. Find the track
	# with the largest NET horizontal displacement — feet are cyclic (net ~0), so
	# only a root/locomotion track drifts — and pin its X/Z so it plays in place.
	var anim: Animation = _anim.get_animation(_walk_anim)
	var best: int = -1
	var best_net: float = 0.0
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var n: int = anim.track_get_key_count(t)
		if n < 2:
			continue
		var first: Vector3 = anim.track_get_key_value(t, 0)
		var last: Vector3 = anim.track_get_key_value(t, n - 1)
		var net: float = Vector2(last.x - first.x, last.z - first.z).length()
		if net > best_net:
			best_net = net
			best = t
	if best >= 0 and best_net > 0.1:
		var base: Vector3 = anim.track_get_key_value(best, 0)
		for k in anim.track_get_key_count(best):
			var v: Vector3 = anim.track_get_key_value(best, k)
			anim.track_set_key_value(best, k, Vector3(base.x, v.y, base.z))


func _compute_facing_offset() -> void:
	# Work out which way the model's nose points in its own local space by comparing
	# the head bones to the tail bones — no hand-guessed yaw offset needed.
	var skeletons := find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skel: Skeleton3D = skeletons[0] as Skeleton3D
	var head: Vector3 = _bone_centroid(skel, "head")
	var tail: Vector3 = _bone_centroid(skel, "tail")
	if head == Vector3.INF or tail == Vector3.INF:
		return
	# Bring both into the model's local frame and take the ground-plane heading.
	var to_model: Transform3D = _model.global_transform.affine_inverse()
	var head_local: Vector3 = to_model * (skel.global_transform * head)
	var tail_local: Vector3 = to_model * (skel.global_transform * tail)
	var forward: Vector3 = Vector3(head_local.x - tail_local.x, 0.0, head_local.z - tail_local.z)
	if forward.length() < 0.05:
		return  # head sits over tail — heading ambiguous, fall back to manual offset
	# Offset that rotates this local heading onto +Z; the movement code then turns
	# from there to point the nose along the velocity.
	_facing_offset = -atan2(forward.x, forward.z)


func _bone_centroid(skel: Skeleton3D, keyword: String) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).findn(keyword) != -1:
			sum += skel.get_bone_global_pose(i).origin
			count += 1
	if count == 0:
		return Vector3.INF
	return sum / float(count)
