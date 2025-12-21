extends Node3D

## Click anywhere to trigger the stone levitation animation

@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready():
	print("\n=== STONE LEVITATE VFX READY ===")
	print("Scene: ", name)
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
	
	# Check animation player
	if anim_player:
		print("✓ AnimationPlayer found")
		print("  Animations: ", anim_player.get_animation_list())
	else:
		push_error("✗ AnimationPlayer NOT found!")
	
	print("\n✓✓✓ READY! Click anywhere to trigger stone levitation!\n")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Mouse clicked!")
			_play_levitate()

func _play_levitate():
	if anim_player:
		if not anim_player.is_playing():
			print("▶ Playing levitate animation...")
			anim_player.play("levitate")
		else:
			print("Animation already playing...")
	else:
		push_error("AnimationPlayer is null!")
