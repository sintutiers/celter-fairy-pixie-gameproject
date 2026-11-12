extends Label

@onready var action_names := AppSettings.get_action_names()

func _get_inputs_as_string() -> String:
	var pressed := PackedStringArray()
	for action_name in action_names:
		if Input.is_action_pressed(action_name):
			pressed.append(action_name)
	return " + ".join(pressed)

func _process(_delta : float) -> void:
	if Input.is_anything_pressed():
		text = _get_inputs_as_string()
	else:
		text = ""
