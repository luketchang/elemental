extends Node3D

## One-shot Pokémon-release VFX: a spherical additive flash, a light pop, and a
## burst of glowing sparks. Builds itself in code and frees after ~1.5s.

func _ready() -> void:
	_make_flash()
	_make_light()
	_make_sparks()
	get_tree().create_timer(1.5).timeout.connect(queue_free)


func _make_flash() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.6, 0.85, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.85, 1.0)
	var m := MeshInstance3D.new()
	m.mesh = sphere
	m.material_override = mat
	m.scale = Vector3.ONE * 0.2
	add_child(m)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 3.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4).set_ease(Tween.EASE_IN)


func _make_light() -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.85, 1.0)
	l.light_energy = 8.0
	l.omni_range = 8.0
	add_child(l)
	create_tween().tween_property(l, "light_energy", 0.0, 0.5).set_ease(Tween.EASE_IN)


func _make_sparks() -> void:
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.06
	spark_mesh.height = 0.12
	spark_mesh.radial_segments = 5
	spark_mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.6)
	mat.albedo_color = Color(1.0, 0.95, 0.6)
	var p := CPUParticles3D.new()
	p.mesh = spark_mesh
	p.material_override = mat
	p.amount = 40
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 90.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0.0, -12.0, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.color = Color(1.0, 0.95, 0.6)
	add_child(p)
