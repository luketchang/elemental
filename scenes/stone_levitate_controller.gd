extends Node3D

## Click anywhere to trigger the stone levitation animation

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var stone: MeshInstance3D = $stone
@onready var debris: GPUParticles3D = $debris
@onready var floor_collision: StaticBody3D = $floor/floor_collision
@onready var debris_collider: GPUParticlesCollisionBox3D = $debris_collider

func _ready():
	print("\n" + "=".repeat(60))
	print("=== STONE LEVITATE VFX READY ===")
	print("=".repeat(60))
	print("\n🔧 RUNTIME VERSION CHECK:")
	if has_meta("generator_version"):
		print("  ✅ RUNNING NEW VERSION: ", get_meta("generator_version"))
		print("  📅 Generated at: ", get_meta("generated_at"))
		print("  ⚙️  Debris velocity: ", get_meta("debris_velocity"))
		print("  ⚙️  Debris spread: ", get_meta("debris_spread"))
		print("  ⚙️  Debris amount: ", get_meta("debris_amount"))
	else:
		print("  ❌❌❌ OLD VERSION - No metadata found!")
		print("  ❌❌❌ YOU ARE RUNNING AN OLD SCENE FILE!")
		print("  ❌❌❌ Delete scenes/stone_levitate_vfx.tscn and regenerate!")
	print("\nScene: ", name)
	print("Children count: ", get_child_count())
	
	# List all children
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
		if child is Camera3D:
			print("    Camera current: ", child.current)
			print("    Camera position: ", child.position)
		if child is MeshInstance3D:
			print("    Mesh: ", child.mesh != null)
			print("    Position: ", child.position)
		if child is GPUParticlesCollisionBox3D:
			print("    Collider size: ", child.size)
			print("    Collider position: ", child.position)
		if child.name == "floor":
			print("    Floor children: ", child.get_child_count())
			for floor_child in child.get_children():
				print("      - ", floor_child.name, " (", floor_child.get_class(), ")")
	
	# Check animation player
	if anim_player:
		print("✓ AnimationPlayer found")
		print("  Animations: ", anim_player.get_animation_list())
	else:
		push_error("✗ AnimationPlayer NOT found!")
	
	# Check collision setup
	print("\n=== COLLISION SETUP ===")
	if floor_collision:
		print("✓ Floor collision body found")
		var collision_shape = floor_collision.get_node_or_null("CollisionShape3D")
		if collision_shape:
			print("  CollisionShape3D found")
			print("  Shape: ", collision_shape.shape)
			if collision_shape.shape is BoxShape3D:
				print("  Box size: ", collision_shape.shape.size)
			print("  Position: ", collision_shape.position)
	else:
		push_error("✗ Floor collision NOT found!")
	
	if debris_collider:
		print("✓ Debris collider found")
		print("  Size: ", debris_collider.size)
		print("  Position: ", debris_collider.position)
	else:
		push_error("✗ Debris collider NOT found!")
	
	if debris:
		print("✓ Debris particles found")
		var pm = debris.process_material as ParticleProcessMaterial
		if pm:
			print("  Collision mode: ", pm.collision_mode, " (1=RIGID, 2=HIDE_ON_CONTACT)")
			print("  Collision friction: ", pm.collision_friction)
			print("  Collision bounce: ", pm.collision_bounce)
			print("  Collision use_scale: ", pm.collision_use_scale)
			print("  Gravity: ", pm.gravity)
		print("  One-shot: ", debris.one_shot)
		print("  Amount: ", debris.amount)
		print("  Lifetime: ", debris.lifetime)
	
	print("\n✓✓✓ READY! Click anywhere to trigger stone levitation!\n")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("\n=== MOUSE CLICKED ===")
			_play_levitate()

func _play_levitate():
	if anim_player:
		if not anim_player.is_playing():
			print("▶ Playing levitate animation...")
			print("  Stone start position: ", stone.position)
			
			# Reset particles for replay (one_shot needs manual restart)
			if debris:
				debris.restart()
				print("  Debris particles restarted")
			
			# Play animation
			anim_player.play("levitate")
			
			# Monitor stone position during animation
			var timer = get_tree().create_timer(0.2)
			timer.timeout.connect(func(): 
				print("  Stone at t=0.2s: ", stone.position)
			)
			var timer2 = get_tree().create_timer(3.3)
			timer2.timeout.connect(func(): 
				print("  Stone at t=3.3s: ", stone.position)
			)
			var timer3 = get_tree().create_timer(3.6)
			timer3.timeout.connect(func(): 
				print("  Stone at t=3.6s (after fall): ", stone.position)
			)
		else:
			print("Animation already playing...")
	else:
		push_error("AnimationPlayer is null!")
