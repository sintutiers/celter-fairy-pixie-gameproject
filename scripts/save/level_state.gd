# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Saved data for one level, see [GameState].
class_name LevelState
extends RefCounted

var color: Color
var tutorial_read: bool = false
## Per-level flags, e.g. "thing.box_01" for pickup that is gone for good.
var flags: Dictionary[String, bool] = { }


## Reads what [method to_dictionary] wrote. Missing key keeps default.
static func from_dictionary(data: Dictionary) -> LevelState:
	var level_state: LevelState = LevelState.new()
	var saved_color: String = data.get("color", "")
	level_state.color = Color.from_string(saved_color, level_state.color)
	level_state.tutorial_read = data.get("tutorial_read", false)
	var saved_flags: Dictionary = data.get("flags", { })
	level_state.flags.assign(saved_flags)
	return level_state


## Plain data for save file, see [method GameState.save].
func to_dictionary() -> Dictionary:
	return { "color": color.to_html(), "tutorial_read": tutorial_read, "flags": flags }
