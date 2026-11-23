extends SceneTree

const SET: String = "res://scenes/s04/ivan_set.tscn"
const OUT: String = "res://art/drafts/s04_render/"
const ALEXEI: String = "res://assets/characters/alexei/alexei_talk.png"
const IVAN: String = "res://assets/characters/ivan/ivan_poses.png"
const PAPERS: String = "res://assets/props/s03/papers.png"
const H: float = 2.3
const TINT: Color = Color(0.78, 0.78, 0.86)
const SHOTS: Array = [
	["shot_wall", Vector2(3.3, 1.5), 3.4, 2, 1.7, 2.8, 0, 3.9, 2.0, true],
	["insert_photos", Vector2(2.4, 2.45), 1.5, -1, 0.0, 0.0, 0, 3.9, 2.0, false],
	["shot_ivan_floor", Vector2(3.9, 1.05), 2.3, -1, 0.0, 0.0, 0, 3.9, 2.0, true],
	["shot_ivan", Vector2(3.9, 1.0), 1.9, -1, 0.0, 0.0, 1, 3.9, 2.0, true],
	["shot_alexei_ivan", Vector2(3.1, 1.35), 2.7, 2, 2.4, 2.8, 1, 3.9, 2.0, true],
	["shot_collar", Vector2(3.2, 1.3), 2.7, 2, 2.85, 2.7, 2, 3.45, 2.4, true],
	["shot_after_punch", Vector2(3.2, 1.2), 2.9, 2, 2.3, 2.8, 3, 3.9, 2.2, true],
	["title_board", Vector2(3.5, 2.05), 3.0, -1, 0.0, 0.0, 0, 30.0, 2.0, false],
]


func _init() -> void:
	_r.call_deferred()


func _sprite(parent: Node, tex: String, frames: int, frame: int, pos: Vector3) -> Sprite3D:
	var s: Sprite3D = Sprite3D.new()
	s.texture = load(tex)
	s.hframes = frames
	s.frame = frame
	s.pixel_size = H / 190.0
	s.offset = Vector2(0, 100)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.modulate = TINT
	s.position = pos
	parent.add_child(s)
	return s


func _r() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var sv: SubViewport = SubViewport.new()
	sv.size = Vector2i(640, 360)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var sc: Node3D = (load(SET) as PackedScene).instantiate()
	sv.add_child(sc)
	var env: WorldEnvironment = sc.get_node_or_null("WorldEnvironment")
	if env and env.environment:
		env.environment = env.environment.duplicate()
		env.environment.ambient_light_energy = maxf(env.environment.ambient_light_energy, 0.2) * 1.5
		env.environment.adjustment_enabled = true
		env.environment.adjustment_brightness = 1.12
	var ref: Camera3D = sc.get_node("Camera3D3")
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.basis = ref.basis
	cam.near = 0.05
	cam.far = 80.0
	sv.add_child(cam)
	cam.make_current()
	var dist: float = ref.position.z
	var fwd: Vector3 = -cam.basis.z
	for s: Array in SHOTS:
		var holder: Node3D = Node3D.new()
		sv.add_child(holder)
		if int(s[3]) >= 0:
			_sprite(holder, ALEXEI, 4, int(s[3]), Vector3(float(s[4]), 0.0, float(s[5])))
		_sprite(holder, IVAN, 4, int(s[6]), Vector3(float(s[7]), 0.0, float(s[8])))
		if bool(s[9]):
			var i: int = 0
			for dx: float in [-0.7, -0.25, 0.55, 0.9]:
				var p: Sprite3D = _sprite(holder, PAPERS, 1, 0, Vector3(float(s[7]) + dx, 0.0, float(s[8]) + 0.25 + 0.15 * (i % 2)))
				p.pixel_size = 0.55 / 128.0
				p.offset = Vector2(0, 20)
				i += 1
		var target: Vector3 = Vector3((s[1] as Vector2).x, (s[1] as Vector2).y, 1.6)
		cam.size = float(s[2])
		cam.position = target - fwd * (dist - 1.6)
		for k: int in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		sv.get_texture().get_image().save_png(OUT + str(s[0]) + ".png")
		holder.queue_free()
		await process_frame
	quit()
