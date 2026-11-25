# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Floor + wall where player movement is recorded + replayed, see [InputReplay].
## Record: tick [member is_recording], set [member replay_name], run scene (F6), play, close window.
## Replay is written to [constant REPLAY_DIRECTORY] + test_movement_replay.gd checks it every run.
## ⚠ Moving player, floor/wall here breaks every recorded replay.
class_name MovementArena
extends Node3D

const REPLAY_DIRECTORY: String = "res://test/replays/"

## Writes replay when scene closes. Off ∴ running scene to try movement overwrites ∅.
@export var is_recording: bool = false
## File name w/o .json, existing replay of that name is overwritten.
@export var replay_name: String = "replay"

## Player global position after each physics frame since arena entered tree.
var positions: PackedVector3Array = PackedVector3Array()

var _recorded_frames: Array[InputFrame] = []
var _input: InputComponent

@onready var player: PlayerBody = $Player


func _ready() -> void:
	# after movement (1) + PlayerInputComponent edge reset (100) ∴ position is after move
	process_physics_priority = 200
	_input = Component.find_descendant_of_type(player, InputComponent, true)


# asks input every frame ∴ it builds exactly one frame /physics frame, also when
# active state skips input (dash) + replay stays in step w/ recording
func _physics_process(_delta: float) -> void:
	if not _input:
		return
	var frame: InputFrame = _input.get_frame()
	if is_recording:
		_recorded_frames.append(frame)
	positions.append(player.global_position)


func _exit_tree() -> void:
	if is_recording:
		_save_replay()


## Swaps player input for plain [InputComponent] playing [param frames] + drops net sync.
## Call before arena enters tree, body wires components when it enters.
func use_replay_input(frames: Array[InputFrame]) -> void:
	is_recording = false
	var player_body: PlayerBody = get_node("Player")
	for child: Node in player_body.get_children():
		if child is PlayerInputComponent or child is NetSyncComponent:
			player_body.remove_child(child)
			child.free()
	var replay_input: InputComponent = InputComponent.new()
	replay_input.name = "ReplayInputComponent"
	replay_input.frames = frames
	player_body.add_child(replay_input)


func _save_replay() -> void:
	var replay: InputReplay = InputReplay.new()
	replay.frames = _recorded_frames
	replay.positions = positions
	var path: String = REPLAY_DIRECTORY.path_join(replay_name + ".json")
	var error: Error = DirAccess.make_dir_recursive_absolute(REPLAY_DIRECTORY)
	if error == OK:
		error = replay.save_file(path)
	if error != OK:
		Log.error("could not write replay %s: %s" % [path, error_string(error)])
		return
	Log.pr("replay of %d frames written to %s" % [_recorded_frames.size(), path])
