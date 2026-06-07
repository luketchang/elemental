extends RigidBody3D

## Thrown by pressing E. On its first ground contact it "pops": plays the
## release VFX and spawns an Eevee at that spot, then removes itself.

const EEVEE_SCENE: PackedScene = preload("res://scenes/eevee.tscn")
const SPAWN_VFX: PackedScene = preload("res://scenes/spawn_vfx.tscn")

var _done: bool = false
var _age: float = 0.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 2


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_age += state.step
	# Wait a beat so we don't trigger on the hand, then fire on first contact.
	if not _done and _age > 0.1 and state.get_contact_count() > 0:
		_done = true
		call_deferred("_release", state.transform.origin)


func _release(pos: Vector3) -> void:
	var world: Node = get_tree().current_scene
	var vfx: Node3D = SPAWN_VFX.instantiate()
	world.add_child(vfx)
	vfx.global_position = pos
	var eevee: Node3D = EEVEE_SCENE.instantiate()
	world.add_child(eevee)
	eevee.global_position = pos + Vector3(0.0, 1.0, 0.0)
	queue_free()
