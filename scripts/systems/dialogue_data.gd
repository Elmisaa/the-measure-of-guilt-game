class_name DialogueData
extends RefCounted

const DIR: String = "res://data/dialogues/"


static func load_file(id: String) -> Dictionary:
	var path: String = DIR + id + ".json"
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("DialogueData: cannot read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("DialogueData: bad JSON in %s" % path)
	return {}
