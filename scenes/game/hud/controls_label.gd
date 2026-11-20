# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Keyboard key /action, one line each, read from [InputMap] ∴ remapped keys show.
## Read on ready: remap in options menu shows after level reload.
class_name ControlsLabel
extends Label

## Space separated input actions to what they do. Keys of several actions are joined: "WASD move".
@export var actions: Dictionary[String, String] = {
	"move_up move_left move_down move_right": "move",
	"run": "run",
	"jump": "jump",
	"crouch": "crouch",
	"dash": "dash",
	"interact": "interact",
	"ui_cancel": "pause",
}


func _ready() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for action_names: String in actions:
		var keys: PackedStringArray = PackedStringArray()
		for action_name: String in action_names.split(" "):
			if not InputMap.has_action(action_name):
				Log.error("%s: no input action '%s'" % [name, action_name])
				continue
			var event: InputEvent = InputEventHelper.get_action_device_event(action_name, InputEventHelper.DEVICE_KEYBOARD)
			keys.append(InputEventHelper.get_text(event))
		lines.append("%s  %s" % ["".join(keys), actions[action_names]])
	text = "\n".join(lines)
