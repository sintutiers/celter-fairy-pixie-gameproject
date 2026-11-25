# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Recorded input, one [InputFrame] /physics frame + where body was after it.
## Played back through [member InputComponent.frames]. Stored as JSON ∴ replay file diffs in git.
class_name InputReplay
extends RefCounted

## Version this game writes. Replay of other version is refused + needs recording again.
const VERSION: int = 1

var frames: Array[InputFrame] = []
## Body global position after each frame, same index as [member frames].
var positions: PackedVector3Array = PackedVector3Array()


## Returns replay in [param path], null + error when file ≠ replay of this [constant VERSION].
static func load_file(path: String) -> InputReplay:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		Log.error("%s is not JSON object, replay not loaded" % path)
		return null
	var data: Dictionary = parsed
	var version: int = data.get("version", 0)
	if version != VERSION:
		Log.error("%s is replay version %d, this game reads %d. Record it again." % [path, version, VERSION])
		return null
	var replay: InputReplay = InputReplay.new()
	var saved_frames: Array = data.get("frames", [])
	for saved_frame: Dictionary in saved_frames:
		replay.frames.append(InputFrame.from_dictionary(saved_frame))
	var saved_positions: Array = data.get("positions", [])
	for saved_position: Array in saved_positions:
		var x: float = saved_position[0]
		var y: float = saved_position[1]
		var z: float = saved_position[2]
		replay.positions.append(Vector3(x, y, z))
	return replay


## Writes replay to [param path], see [method load_file].
func save_file(path: String) -> Error:
	var saved_frames: Array[Dictionary] = []
	for frame: InputFrame in frames:
		saved_frames.append(frame.to_dictionary())
	var saved_positions: Array[Array] = []
	for position: Vector3 in positions:
		saved_positions.append([position.x, position.y, position.z])
	var data: Dictionary = { "version": VERSION, "frames": saved_frames, "positions": saved_positions }
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	# full precision ∴ replayed positions compare against what was recorded, not rounded copy
	if not file.store_string(JSON.stringify(data, "\t", false, true)):
		return file.get_error()
	return OK
