extends SceneTree
## After the call: "Подняться" leads to the hall in state "leave" -> the exit refuses without the coat ->
## coat from the locker, worn from the inventory -> exit -> the drive cutscene plays all its shots in order
## (run at 2x speed) -> ends on the title screen.
## godot --path . -s res://tests/test_s02_drive.gd [-- --shots]   (offscreen: --position 20000,20000)

const SAFETY_TIMEOUT: float = 120.0
const SPEED: float = 2.0
const EXPECT: Array[String] = ["precinct", "key", "leave", "skyline", "nightlife", "windshield", "tunnel",
	"montage_neon", "montage_gauges", "montage_city", "echo", "face", "ues"]
const SHOT_AT: Dictionary = {"precinct": 1.0, "key": 2.4, "leave": 3.5, "skyline": 4.7, "nightlife": 5.8,
	"windshield": 7.0, "tunnel": 8.2, "montage_neon": 9.0, "montage_gauges": 9.6, "montage_city": 10.2,
	"echo": 10.6, "face": 12.0, "ues_street": 13.8, "lightning": 15.86, "ues_top": 17.2}
var _shots: bool = "--shots" in OS.get_cmdline_user_args()


func _init() -> void:
	_run.call_deferred()
	create_timer(SAFETY_TIMEOUT, true, false, true).timeout.connect(func() -> void:
		push_error("TEST TIMEOUT")
		quit(2))


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/previews/s02_drive_" + name + ".png")


func _run() -> void:
	var ok: bool = true
	var gs: Node = root.get_node("GameState")
	var hud: Node = root.get_node("Hud")
	gs.set_flag("tutorial", "done")
	gs.set_flag("walk_state", "leave")
	gs.items.append("cup_empty")
	change_scene_to_file("res://scenes/s01/walk.tscn")
	await _wait(1.0)
	var w: Node = current_scene
	if str(w.get("_state")) != "leave":
		push_error("FAIL walk state is not 'leave': %s" % w.get("_state")); ok = false
	if not gs.container_items("alexei_locker").has("coat"):
		push_error("FAIL coat is not in the locker"); ok = false
	var x: float = (w.get_node("World/Player") as Node2D).position.x
	if absf(x - 420.0) > 1.0:
		push_error("FAIL spawn x after the call: %s" % x); ok = false
	# the exit refuses without the coat
	w.call("_interact", "exit")
	await _wait(0.3)
	if current_scene != w:
		push_error("FAIL left without the coat"); ok = false
	if not "вещи" in hud.get_objective().to_lower():
		push_error("FAIL objective should ask for the things: '%s'" % hud.get_objective()); ok = false
	for it: String in ["keys", "notebook", "umbrella", "coat"]:
		gs.take_from("alexei_locker", it)
	if not gs.has_item("coat"):
		push_error("FAIL coat not taken"); ok = false
	w.call("_interact", "exit")
	await _wait(0.3)
	if current_scene != w:
		push_error("FAIL left without wearing the coat"); ok = false
	gs.use_item("coat", "wear")
	if gs.has_item("coat") or not bool(gs.get_flag("coat_on", false)):
		push_error("FAIL coat not worn"); ok = false
	await _wait(0.2)
	var pl: Node = w.get_node("World/Player")
	if ResourceLoader.exists(pl.COAT_WALK) and not str((pl.get("sheet") as Texture2D).resource_path).ends_with("_coat.png"):
		push_error("FAIL Alexei is not drawn in the coat"); ok = false
	await _shot("0_coat")
	w.call("_interact", "exit")
	await _wait(2.4)
	var d: Node = current_scene
	if d == null or d.name != "Drive":
		push_error("FAIL exit did not start the drive: %s" % [d]); quit(1); return
	# play it through fast, recording the order of shots
	Engine.time_scale = SPEED
	var seen: Array[String] = []
	var shot_keys: Array = SHOT_AT.keys()
	var music_started: bool = false
	while current_scene == d:
		var n: String = str(d.get("shot_name"))
		if seen.is_empty() or seen[-1] != n:
			seen.append(n)
		var mp: AudioStreamPlayer = d.get("_music")
		if mp and mp.playing:
			music_started = true
		var t: float = float(d.get("_t"))
		for k: Variant in shot_keys.duplicate():
			if t >= float(SHOT_AT[k]):
				shot_keys.erase(k)
				Engine.time_scale = 1.0
				await _shot(str(k))
				Engine.time_scale = SPEED
		await process_frame
		if current_scene == null:
			await process_frame
	Engine.time_scale = 1.0
	if seen != EXPECT:
		push_error("FAIL shots: %s" % [seen]); ok = false
	if not music_started:
		push_error("FAIL the track never played"); ok = false
	await _wait(1.0)
	if current_scene == null or current_scene.name != "Title":
		push_error("FAIL drive did not end on the title: %s" % [current_scene]); ok = false
	print("PASS" if ok else "FAILED")
	quit(0 if ok else 1)
