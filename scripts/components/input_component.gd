# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Base class for input sources. Builds one [InputFrame] /physics frame + caches it,
## ∴ every caller in same frame gets same object.
## Used as is, it plays [member frames] back (replay, see [InputReplay]).
## Override [method _build_frame] for new source (player, AI, etc).
class_name InputComponent
extends Component

## Played in order, one /physics frame. After last one/when empty, input is empty.
## ⚠ Frame is only used up when someone calls [method get_frame] that physics frame,
## ∴ caller must ask every frame to stay in step, see [MovementArena].
var frames: Array[InputFrame] = []

var _frame: InputFrame
var _frame_index: int = -1
var _next_frame_index: int = 0


## Returns this physics frame input. Only call from physics code, cache is /physics frame.
func get_frame() -> InputFrame:
	var index: int = Engine.get_physics_frames()
	if index != _frame_index:
		_frame_index = index
		_frame = _build_frame()
	return _frame


## Override for new input source. Called <= once /physics frame, see [method get_frame].
func _build_frame() -> InputFrame:
	if _next_frame_index >= frames.size():
		return InputFrame.new()
	var frame: InputFrame = frames[_next_frame_index]
	_next_frame_index += 1
	return frame
