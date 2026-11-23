extends SceneTree

func _init() -> void:
	_r.call_deferred()


func _aabb(n: Node) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in n.find_children("*", "VisualInstance3D", true, false) + ([n] if n is VisualInstance3D else []):
		var v: VisualInstance3D = c
		if not v.is_visible_in_tree() or v is Light3D:
			continue
		var b: AABB = v.global_transform * v.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _r() -> void:
	var path: String = ""
	var out: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			path = a.substr(6)
		if a.begins_with("--out="):
			out = a.substr(6)
	var sv: SubViewport = SubViewport.new()
	sv.size = Vector2i(640, 360)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var sc: Node3D = (load(path) as PackedScene).instantiate()
	sv.add_child(sc)
	await process_frame
	for n: Node in sc.get_children():
		if n is Node3D and not (n is Camera3D) and not (n is Light3D):
			var b: AABB = _aabb(n)
			if b.size != Vector3.ZERO:
				print("%-26s x %6.2f..%6.2f  y %5.2f..%5.2f  z %5.2f..%5.2f" % [n.name, b.position.x, b.end.x, b.position.y, b.end.y, b.position.z, b.end.z])
	var ref: Camera3D = sc.get_node_or_null("Camera3D3")
	var pans: Array = []
	for a2: String in OS.get_cmdline_user_args():
		if a2.begins_with("--pan="):
			pans = Array(a2.substr(6).split(","))
	if ref and not pans.is_empty():
		var cam: Camera3D = Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 4.35
		cam.basis = ref.basis
		cam.near = 0.05
		cam.far = 80.0
		sv.add_child(cam)
		cam.make_current()
		for px: String in pans:
			cam.position = Vector3(float(px), ref.position.y - 0.05, ref.position.z)
			for k2: int in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			sv.get_texture().get_image().save_png(out + "side_%s.png" % px)
		quit()
		return
	var i: int = 0
	for c: Node in sc.find_children("*", "Camera3D", true, false):
		(c as Camera3D).make_current()
		for k: int in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		sv.get_texture().get_image().save_png(out + "cam_%d_%s.png" % [i, c.name])
		print("CAM ", c.name, " ", (c as Camera3D).position, " size ", (c as Camera3D).size)
		i += 1
	quit()
