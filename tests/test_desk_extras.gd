extends SceneTree

const SAFETY_TIMEOUT: float = 60.0
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
	root.get_texture().get_image().save_png("res://art/previews/desk_extras_" + name + ".png")


func _run() -> void:
	var ok: bool = true
	change_scene_to_file("res://scenes/s01/desk.tscn")
	await _wait(1.2)
	var d: Node = current_scene
	d.call("_on_marker", "lamp")
	await _wait(0.6)
	if bool(d.get("_lamp_on")):
		push_error("FAIL lamp did not switch off"); ok = false
	var th: ThoughtBox = d.get_node("UI/Root/ThoughtBox")
	if th.get_text().is_empty():
		push_error("FAIL no comment on the lamp"); ok = false
	if (d.get("_dark") as CanvasModulate).color.r > 0.5:
		push_error("FAIL room not dark"); ok = false
	await _shot("1_lamp_off")
	d.call("_on_doc_clicked", "casefile")
	await _wait(2.5)
	await _shot("2_dark_doc")
	var view: DocumentView = d.get_node("DocumentView")
	if view.shade == Color.WHITE:
		push_error("FAIL document not dim in the dark"); ok = false
	view.close()
	await _wait(0.5)
	d.call("_on_marker", "lamp")
	await _wait(0.5)
	if not bool(d.get("_lamp_on")):
		push_error("FAIL lamp did not switch on"); ok = false
	var term: Terminal = d.get_node("Terminal")
	term.call("_show_search")
	await _wait(0.3)
	var body: VBoxContainer = term.get("_body")
	var hints: int = 0
	for c: Node in body.get_children():
		if c is Button and (c as Button).text.contains("›"):
			hints += 1
	if hints < 3:
		push_error("FAIL search shows %d hints" % hints); ok = false
	if term.call("_lookup", "Тони Руссо") != "RUSSO" and term.call("_lookup", "Руссо") != "RUSSO":
		push_error("FAIL new record not found"); ok = false
	if term.call("_lookup", "Мария Глебова") != "MARIA_GLEBOVA":
		push_error("FAIL 'Мария Глебова' -> %s" % term.call("_lookup", "Мария Глебова")); ok = false
	if term.call("_lookup", "Глебов") != "GLEBOV" or term.call("_lookup", "Корнева") != "KORNEVA":
		push_error("FAIL Глебов / Корнева not found"); ok = false
	print("DESK EXTRAS: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
