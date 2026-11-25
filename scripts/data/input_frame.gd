# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## One physics frame of input. Built by [InputComponent].
## [code]_pressed[/code] + [code]_released[/code] fields are true for that frame only.
class_name InputFrame
extends RefCounted

## Movement axes, length <= 1.
var move: Vector2
var run: bool
var jump_pressed: bool
var jump_released: bool
var crouch: bool
var dash_pressed: bool
var interact_pressed: bool


## Reads what [method to_dictionary] wrote. Missing key keeps default.
static func from_dictionary(data: Dictionary) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	var saved_move: Array = data.get("move", [0.0, 0.0])
	var move_x: float = saved_move[0]
	var move_y: float = saved_move[1]
	frame.move = Vector2(move_x, move_y)
	frame.run = data.get("run", false)
	frame.jump_pressed = data.get("jump_pressed", false)
	frame.jump_released = data.get("jump_released", false)
	frame.crouch = data.get("crouch", false)
	frame.dash_pressed = data.get("dash_pressed", false)
	frame.interact_pressed = data.get("interact_pressed", false)
	return frame


## Plain data for [InputReplay] file. Only fields that are set ∴ idle frame is [code]{}[/code].
func to_dictionary() -> Dictionary:
	var data: Dictionary = { }
	if not move.is_zero_approx():
		data["move"] = [move.x, move.y]
	# one line /field, not get(name) loop ∴ renamed field errors here instead of dropping silently
	if run:
		data["run"] = true
	if jump_pressed:
		data["jump_pressed"] = true
	if jump_released:
		data["jump_released"] = true
	if crouch:
		data["crouch"] = true
	if dash_pressed:
		data["dash_pressed"] = true
	if interact_pressed:
		data["interact_pressed"] = true
	return data


## [code]Log.pr(this)[/code] prints [method to_dictionary] instead of object id.
func to_pretty() -> Dictionary:
	return to_dictionary()
