extends Node2D
## s01 format 2: Alexei's desk. Placeholder: background, documents, hint, intro thought.
## Next step: hover wiggle on documents, click -> close-up.

const THOUGHT_DELAY: float = 0.8

@onready var _hint: Label = $UI/Root/Hint
@onready var _thought: ThoughtBox = $UI/Root/ThoughtBox


func _ready() -> void:
	var data: Dictionary = DialogueData.load_file("s01_precinct").get("desk", {})
	_hint.text = str(data.get("hint", ""))
	await get_tree().create_timer(THOUGHT_DELAY).timeout
	_thought.show_text(str(data.get("intro_thought", "")))
