extends SceneTree

const OUT: String = "res://art/refs/s03_penthouse/storyboard/"
const SHOTS: Array = [
	["01_entrance", Vector3(-15.5, 1.5, 2.6), Vector3(-9.0, 1.3, -2.2), 55.0],
	["02_shards", Vector3(-2.6, 0.55, 1.3), Vector3(-1.4, 0.1, -0.4), 50.0],
	["03_silhouette", Vector3(-2.4, 1.6, 2.4), Vector3(2.0, 1.3, -2.3), 48.0],
	["05_reverse", Vector3(2.6, 1.7, -1.3), Vector3(-1.6, 1.2, 0.8), 50.0],
	["07_bullet", Vector3(2.2, 1.4, 0.4), Vector3(3.6, 1.3, -1.6), 40.0],
	["08_kneel", Vector3(-1.2, 0.5, 1.8), Vector3(0.6, 0.6, -0.6), 55.0],
	["09_window", Vector3(0.0, 1.5, 1.6), Vector3(2.0, 1.6, -2.4), 50.0],
	["10_after", Vector3(-1.0, 1.4, 2.0), Vector3(2.0, 1.4, -2.3), 55.0],
]


func _init() -> void:
	_r.call_deferred()


func _r() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var sv: SubViewport = SubViewport.new()
	sv.size = Vector2i(640, 360)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var set_scene: Node3D = (load("res://scenes/s03/penthouse_set.tscn") as PackedScene).instantiate()
	sv.add_child(set_scene)
	var cam: Camera3D = Camera3D.new()
	cam.near = 0.05
	cam.far = 80.0
	sv.add_child(cam)
	cam.make_current()
	for s: Array in SHOTS:
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP)
		cam.fov = float(s[3])
		for i: int in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		sv.get_texture().get_image().save_png(OUT + str(s[0]) + ".png")
	quit()
