# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [InputFrame] + [InputReplay] survive JSON ∴ replay recorded today plays same input later.
## New [InputFrame] field missing in [method InputFrame.to_dictionary]/[method InputFrame.from_dictionary] fails here.
extends GutTest

const TEST_REPLAY_PATH: String = "user://test_replay.json"


#region Setup/Teardown
func after_each() -> void:
	if FileAccess.file_exists(TEST_REPLAY_PATH) and DirAccess.remove_absolute(TEST_REPLAY_PATH) != OK:
		fail_test("could not delete %s, next test may see it" % TEST_REPLAY_PATH)
#endregion


#region Tests
func test_every_input_frame_field_survives_dictionary() -> void:
	var frame: InputFrame = _make_frame_with_every_field_set()
	var loaded: InputFrame = InputFrame.from_dictionary(frame.to_dictionary())
	for field: String in _get_input_frame_fields():
		assert_eq(loaded.get(field), frame.get(field), field)


func test_replay_survives_file() -> void:
	var replay: InputReplay = InputReplay.new()
	replay.frames = [_make_frame_with_every_field_set(), InputFrame.new()]
	replay.positions = PackedVector3Array([Vector3(1.5, -2.0, 0.125), Vector3.ZERO])
	assert_eq(replay.save_file(TEST_REPLAY_PATH), OK)
	var loaded: InputReplay = InputReplay.load_file(TEST_REPLAY_PATH)
	assert_eq(loaded.positions, replay.positions)
	assert_eq(loaded.frames.size(), replay.frames.size())
	for index: int in replay.frames.size():
		assert_eq(loaded.frames[index].to_dictionary(), replay.frames[index].to_dictionary())


func test_other_replay_version_is_refused() -> void:
	var file: FileAccess = FileAccess.open(TEST_REPLAY_PATH, FileAccess.WRITE)
	assert_true(file.store_string(JSON.stringify({ "version": InputReplay.VERSION + 1 })))
	file.close()
	assert_null(InputReplay.load_file(TEST_REPLAY_PATH))
	assert_push_error("Record it again")
#endregion


#region Helpers
# from script property list ∴ new field is covered w/o touching this file
func _get_input_frame_fields() -> PackedStringArray:
	var fields: PackedStringArray = PackedStringArray()
	var frame_script: Script = InputFrame
	for property: Dictionary in frame_script.get_script_property_list():
		var usage: int = property["usage"]
		var field: String = property["name"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(field)
	return fields


# every field off its default ∴ dropped field shows as default after round trip
func _make_frame_with_every_field_set() -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	for field: String in _get_input_frame_fields():
		match typeof(frame.get(field)):
			TYPE_BOOL:
				frame.set(field, true)
			TYPE_VECTOR2:
				frame.set(field, Vector2(0.5, -1.0))
			_:
				fail_test("InputFrame.%s has type w/o test value, add one here" % field)
	return frame
#endregion
