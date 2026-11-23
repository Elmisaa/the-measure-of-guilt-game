@tool
extends EditorPlugin


var check_interval: float = 1.0
var timer: Timer
var watched_files: Dictionary = {}
var editor_interface: EditorInterface

var watched_extensions: Array[String] = [".tscn", ".scn", ".gd", ".tres", ".res"]

func _enter_tree() -> void:
	editor_interface = get_editor_interface()
	
	timer = Timer.new()
	timer.wait_time = check_interval
	timer.timeout.connect(_check_for_changes)
	add_child(timer)
	timer.start()
	
	_update_watched_files()
	
	print("[Godot MCP - AutoReload] Plugin activated - watching for external changes")

func _exit_tree() -> void:
	if timer:
		timer.stop()
		timer.queue_free()
	print("[Godot MCP - AutoReload] Plugin deactivated")

func _update_watched_files() -> void:
	var edited_scene = editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene.scene_file_path:
		var path = edited_scene.scene_file_path
		if not watched_files.has(path):
			watched_files[path] = _get_modified_time(path)
		
		_watch_node_scripts(edited_scene)

func _watch_node_scripts(node: Node) -> void:
	var script = node.get_script()
	if script and script.resource_path:
		var path = script.resource_path
		if not watched_files.has(path):
			watched_files[path] = _get_modified_time(path)
	
	for child in node.get_children():
		_watch_node_scripts(child)

func _get_modified_time(path: String) -> int:
	var global_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		return FileAccess.get_modified_time(global_path)
	return 0

func _check_for_changes() -> void:
	_update_watched_files()
	
	var files_to_reload: Array = []
	var scripts_to_reload: Array = []
	
	for path in watched_files.keys():
		var current_time = _get_modified_time(path)
		var last_time = watched_files[path]
		
		if current_time > last_time:
			if path.ends_with(".gd"):
				scripts_to_reload.append(path)
			else:
				files_to_reload.append(path)
			watched_files[path] = current_time
	
	for path in scripts_to_reload:
		_reload_script(path)
	
	for path in files_to_reload:
		_reload_scene(path)

func _reload_script(path: String) -> void:
	print("[Godot MCP - AutoReload] Script changed: ", path)
	
	var script = load(path)
	if script:
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		print("[Godot MCP - AutoReload] Script reloaded: ", path)

func _reload_scene(path: String) -> void:
	print("[Godot MCP - AutoReload] Scene changed: ", path)
	
	var edited_scene = editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene.scene_file_path == path:
		editor_interface.reload_scene_from_path(path)
		print("[Godot MCP - AutoReload] Scene reloaded: ", path)

func set_check_interval(interval: float) -> void:
	check_interval = interval
	if timer:
		timer.wait_time = interval

func add_watched_extension(ext: String) -> void:
	if not watched_extensions.has(ext):
		watched_extensions.append(ext)

func clear_watched_files() -> void:
	watched_files.clear()
