extends SceneTree
const OUT: String = "res://art/drafts/s03_talk_bg/"
func _init() -> void:
	_r.call_deferred()
func _shoot(sv: SubViewport, name: String) -> void:
	for i: int in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(OUT + name + ".png")
func _r() -> void:
	var sv: SubViewport = SubViewport.new()
	sv.size = Vector2i(640, 360)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var set_scene: Node3D = (load("res://scenes/s03/penthouse_set.tscn") as PackedScene).instantiate()
	sv.add_child(set_scene)
	var ref: Camera3D = set_scene.get_node("Camera3D")
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.basis = ref.basis
	cam.near = 0.05
	cam.far = 80.0
	sv.add_child(cam)
	cam.make_current()
	cam.size = 4.35
	cam.position = Vector3(-0.7, ref.position.y - 0.05, ref.position.z)
	await _shoot(sv, "talk_normal")
	for pt: Array in [["viktor", Vector3(2.05, 0, -1.95)], ["alexei", Vector3(-1.6, 0, 0.6)], ["alexei_mid", Vector3(0.4, 0, 0.6)], ["entity", Vector3(3.6, 0, -1.6)], ["window", Vector3(2.0, 1.7, -2.2)], ["lamp", Vector3(0.05, 1.75, -1.0)], ["head", Vector3(2.05, 2.3, -1.95)]]:
		print("PT ", pt[0], " ", cam.unproject_position(pt[1]))
	if OS.get_cmdline_user_args().has("--moon-only"):
		pass
	for l: Node in set_scene.find_children("*", "Light3D", true, false):
		(l as Light3D).visible = false
	var env: WorldEnvironment = set_scene.get_node("WorldEnvironment")
	env.environment.ambient_light_energy = 0.35
	env.environment.ambient_light_color = Color(0.35, 0.42, 0.6)
	env.environment.glow_enabled = false
	for g: Node in set_scene.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = g
		if gi is MeshInstance3D:
			var mi: MeshInstance3D = gi
			for i: int in mi.get_surface_override_material_count():
				var m: Material = mi.get_active_material(i)
				if m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled:
					var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
					d.emission_enabled = false
					d.albedo_color = d.albedo_color.darkened(0.6)
					mi.set_surface_override_material(i, d)
		if gi is CSGShape3D and (gi as CSGShape3D).material is StandardMaterial3D and ((gi as CSGShape3D).material as StandardMaterial3D).emission_enabled:
			var d2: StandardMaterial3D = ((gi as CSGShape3D).material as StandardMaterial3D).duplicate()
			d2.emission_enabled = false
			(gi as CSGShape3D).material = d2
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 0.95)
	moon.light_energy = 0.28
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-30, 180, 0)
	sv.add_child(moon)
	await _shoot(sv, "talk_moon")
	quit()
