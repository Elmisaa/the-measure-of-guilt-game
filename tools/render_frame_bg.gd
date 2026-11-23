extends SceneTree

func _init() -> void:
	_r.call_deferred()


func _r() -> void:
	var set_path: String = ""
	var out: String = ""
	var cx: float = 0.0
	var cam_name: String = "Camera3D3"
	var pts: Array = []
	var brighten: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			set_path = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--x="):
			cx = float(a.substr(4))
		elif a.begins_with("--cam="):
			cam_name = a.substr(6)
		elif a.begins_with("--pt="):
			pts.append(a.substr(5).split(","))
		elif a == "--brighten":
			brighten = true
	var sv: SubViewport = SubViewport.new()
	sv.size = Vector2i(640, 360)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var sc: Node3D = (load(set_path) as PackedScene).instantiate()
	sv.add_child(sc)
	if brighten:
		var env: WorldEnvironment = sc.get_node_or_null("WorldEnvironment")
		if env and env.environment:
			env.environment = env.environment.duplicate()
			env.environment.ambient_light_energy = maxf(env.environment.ambient_light_energy, 0.2) * 2.2
			env.environment.adjustment_enabled = true
			env.environment.adjustment_brightness = 1.35
		for l: Node in sc.find_children("*", "Light3D", true, false):
			(l as Light3D).light_energy *= 1.4
	var ref: Camera3D = sc.get_node(cam_name)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.35
	cam.basis = ref.basis
	cam.near = 0.05
	cam.far = 80.0
	sv.add_child(cam)
	cam.make_current()
	cam.position = Vector3(cx, ref.position.y - 0.05, ref.position.z)
	for i: int in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(out)
	for p: PackedStringArray in pts:
		print("PT ", p[0], " ", cam.unproject_position(Vector3(float(p[1]), float(p[2]), float(p[3]))))
	quit()
