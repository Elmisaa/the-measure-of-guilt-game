extends SceneTree

const HALL: String = "res://scenes/s01/walk.tscn"
const FACTORY: String = "res://scenes/s06/factory_present.tscn"

var _snapshot: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_snapshot = arg.trim_prefix("--capture=")
	create_timer(25.0).timeout.connect(func() -> void: _fail("timed out"))
	_run.call_deferred()


func _run() -> void:
	var state: Node = root.get_node("GameState")
	var hud: Node = root.get_node("Hud")
	var saves: Node = root.get_node("SaveGame")
	state.new_game()
	state.set_flag("tutorial", "done")
	change_scene_to_file(HALL)
	await scene_changed
	await create_timer(2.0).timeout
	var hall_player: Node2D = current_scene.get_node("World/Player")
	hall_player.position.x = 900
	await process_frame

	hud.toggle_inventory()
	await process_frame
	var inventory: InventoryPanel = hud.get("_inventory")
	if hud.controls_hint_visible():
		_fail("the controls hint should not overlap the inventory")
		return
	if inventory.get("_grid").get_child_count() != 24 or not inventory.call("_actions_for", "bandage").has("drop"):
		_fail("inventory should have 24 cells and a drop action")
		return
	if not _snapshot.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_snapshot.path_join("inventory.png"))

	inventory.choose("bandage", "drop")
	var pickup: Button = hud.get("_ground_pickup")
	if state.has_item("bandage") or not pickup.visible or not saves.save("3"):
		_fail("dropping in the hall should show a pickup and allow saving")
		return
	hall_player.position.x += 180.0
	await process_frame
	await process_frame
	if pickup.visible:
		_fail("a distant item should be out of reach")
		return

	change_scene_to_file(FACTORY)
	await scene_changed
	await process_frame
	if pickup.visible or state.has_item("bandage"):
		_fail("the hall drop should not appear in the factory")
		return
	if not await saves.load_slot("3"):
		_fail("could not load the hall drop")
		return
	await process_frame
	if not pickup.visible or state.has_item("bandage"):
		_fail("the hall drop should be restored near the loaded position")
		return
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_G
	key.pressed = true
	hud.call("_input", key)
	if not state.has_item("bandage") or state.dropped_items.has("bandage"):
		_fail("G should pick the item back up exactly once")
		return

	change_scene_to_file(FACTORY)
	await scene_changed
	await process_frame
	hud.toggle_inventory()
	inventory.choose("bandage", "drop")
	if not pickup.visible or state.dropped_items["bandage"]["position"].size() != 3:
		_fail("the factory should store a 3D drop position")
		return
	pickup.pressed.emit()
	if not state.has_item("bandage") or pickup.visible:
		_fail("clicking the pickup should restore the item and hide the prompt")
		return
	print("INVENTORY DROP: OK")
	quit()


func _fail(message: String) -> void:
	push_error("INVENTORY DROP: " + message)
	quit(1)
