# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Records + replays player movement in level it is placed in, see [InputReplay].
## Record: run level as own scene (F6), press R ([constant RECORD_KEY]) > level restarts + records, play, press R again > saved.
## Replay lands in [constant REPLAY_DIRECTORY] as replay_<date>.json, rename it to what it tests.
## test_movement_replay.gd plays every replay there on each test run.
## Closing window while recording saves too. R is off in export + when level runs inside game scene.
## ⚠ Moving player spawner/geometry player touches in level breaks replays that pass there.
## ⚠ Replay only holds [InputFrame] ∴ dialogue/UI input is not replayed, record movement only.
class_name MovementRecorder
extends Node

const REPLAY_DIRECTORY: String = "res://scripts/test/replays/"
## Not in input map ∴ never moves player.
const RECORD_KEY: Key = KEY_R

# survive reload_current_scene ∴ recording starts on fresh level + saved message stays visible
static var _should_record_on_ready: bool = false
static var _last_saved_message: String = ""

## Player global position after each physics frame while recording/replaying.
var positions: PackedVector3Array = PackedVector3Array()
var player: PlayerBody

var _is_recording: bool = false
var _is_replaying: bool = false
var _recorded_frames: Array[InputFrame] = []
var _input: InputComponent
var _status_label: Label


func _ready() -> void:
	# after movement (1) + PlayerInputComponent edge reset (100) ∴ position is after move
	process_physics_priority = 200
	# spawned in PlayerSpawner._enter_tree ∴ exists before any _ready
	player = get_tree().get_first_node_in_group(PlayerApi.GROUP) as PlayerBody
	if not player:
		Log.error("%s: no PlayerBody in level, nothing to record" % name)
		return
	_input = Component.find_descendant_of_type(player, InputComponent, true)
	# R reloads current scene + writes res:// ∴ only when level itself runs from editor
	if not OS.has_feature("editor") or get_tree().current_scene != owner:
		set_process_unhandled_input(false)
		return
	_is_recording = _should_record_on_ready
	_should_record_on_ready = false
	_add_status_label()
	_update_status_label()


# asks input every frame ∴ it builds exactly one frame /physics frame, also when
# active state skips input (dash) + replay stays in step w/ recording
func _physics_process(_delta: float) -> void:
	if not _input or not (_is_recording or _is_replaying):
		return
	var frame: InputFrame = _input.get_frame()
	if _is_recording:
		_recorded_frames.append(frame)
		_update_status_label()
	positions.append(player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if not key_event or not key_event.pressed or key_event.echo or key_event.physical_keycode != RECORD_KEY:
		return
	get_viewport().set_input_as_handled()
	if _is_recording:
		_is_recording = false
		_save_replay()
	else:
		_should_record_on_ready = true
	# fresh level ∴ every take + its replay start from same spot
	if get_tree().reload_current_scene() != OK:
		Log.error("could not restart level, run it as own scene (F6)")


func _exit_tree() -> void:
	if _is_recording:
		_save_replay()


## Plays [param frames] as player input from next physics frame on. Call right after level enters tree.
func use_replay_input(frames: Array[InputFrame]) -> void:
	_is_replaying = true
	_input.frames = frames


func _save_replay() -> void:
	var replay: InputReplay = InputReplay.new()
	replay.frames = _recorded_frames
	replay.positions = positions
	var date: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path: String = REPLAY_DIRECTORY.path_join("replay_%s.json" % date)
	var error: Error = DirAccess.make_dir_recursive_absolute(REPLAY_DIRECTORY)
	if error == OK:
		error = replay.save_file(path)
	if error != OK:
		_last_saved_message = "could not write %s: %s" % [path, error_string(error)]
		Log.error(_last_saved_message)
		return
	_last_saved_message = "saved %s (%d frames), rename it to what it tests" % [path.get_file(), _recorded_frames.size()]
	Log.pr(_last_saved_message)


# top center ∴ stays clear of HUD in top left corner
func _add_status_label() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	_status_label = Label.new()
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status_label.offset_top = 16.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override(&"font_size", 20)
	_status_label.add_theme_constant_override(&"outline_size", 6)
	_status_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	layer.add_child(_status_label)
	add_child(layer)


func _update_status_label() -> void:
	if _is_recording:
		_status_label.text = "● REC  %d frames\nR: stop + save" % _recorded_frames.size()
		_status_label.modulate = Color.RED
		return
	_status_label.modulate = Color.WHITE
	_status_label.text = "R: restart + record replay"
	if not _last_saved_message.is_empty():
		_status_label.text = _last_saved_message + "\n" + _status_label.text
