# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Plays input into showcase level + checks where player goes, see [MovementRecorder].
## Scripted tests check profile values hold in real physics. Recorded replays in
## [constant MovementRecorder.REPLAY_DIRECTORY] must follow their recorded path.
## Record: run showcase.tscn (F6) + press R.
## ⚠ Intended movement change > delete failing replay + record it again.
## Level + [SanityComponent] read + write save ∴ [SaveIsolatedTest], ∅ save also keeps tutorials closed.
extends SaveIsolatedTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/game/levels/showcase.tscn")
## Meters player may drift from recorded path before replay counts as changed.
## Raise if same replay fails between editor + CI Godot version.
const POSITION_TOLERANCE: float = 0.05
# spawned player drops onto floor + lands in these
const SETTLE_FRAMES: int = 30


#region Scripted
func test_standing_jump_peaks_near_jump_height() -> void:
	var frames: Array[InputFrame] = _make_frames(SETTLE_FRAMES, InputFrame.new())
	var jump: InputFrame = InputFrame.new()
	jump.jump_pressed = true
	frames.append(jump)
	frames.append_array(_make_frames(120, InputFrame.new()))
	var recorder: MovementRecorder = await _play_in_level(frames)

	var ground_height: float = recorder.positions[SETTLE_FRAMES - 1].y
	var peak_height: float = ground_height
	for position: Vector3 in recorder.positions.slice(SETTLE_FRAMES):
		peak_height = maxf(peak_height, position.y)
	var jump_height: float = recorder.player.movement_profile.jump_height
	# apex hang slows gravity near top ∴ peak lands bit above jump_height
	assert_between(peak_height - ground_height, jump_height * 0.95, jump_height * 1.2)
	assert_almost_eq(recorder.positions[-1].y, ground_height, 0.01, "lands back on floor")


func test_walk_reaches_move_speed() -> void:
	var walk: InputFrame = InputFrame.new()
	walk.move = Vector2.RIGHT
	var recorder: MovementRecorder = await _play_in_level(_make_frames(SETTLE_FRAMES + 60, walk))
	assert_almost_eq(_get_last_horizontal_speed(recorder), recorder.player.movement_profile.move_speed, 0.1)


func test_run_reaches_run_speed() -> void:
	var run: InputFrame = InputFrame.new()
	run.move = Vector2.RIGHT
	run.run = true
	var recorder: MovementRecorder = await _play_in_level(_make_frames(SETTLE_FRAMES + 60, run))
	assert_almost_eq(_get_last_horizontal_speed(recorder), recorder.player.movement_profile.run_speed, 0.1)


func test_walking_left_flips_facing() -> void:
	var walk_left: InputFrame = InputFrame.new()
	walk_left.move = Vector2.LEFT
	var frames: Array[InputFrame] = _make_frames(20, walk_left)
	var recorder: MovementRecorder = _start_level(frames)
	var movement: Movement3DComponent = Component.find_descendant_of_type(recorder.player, Movement3DComponent)
	assert_eq(movement.facing, 1.0, "starts at default_facing_right")
	watch_signals(movement)
	await _wait_for_positions(recorder, frames.size())
	assert_eq(movement.facing, -1.0)
	assert_signal_emitted_with_parameters(movement.flipped, [-1.0])
	assert_signal_emit_count(movement.flipped, 1, "held direction flips once")
#endregion


#region Recorded
func test_recorded_replays_follow_recorded_path() -> void:
	var paths: PackedStringArray = _find_replay_paths()
	if paths.is_empty():
		pending("no replays yet, run showcase.tscn (F6) + press R to record one")
		return
	for path: String in paths:
		var replay: InputReplay = InputReplay.load_file(path)
		if not replay:
			fail_test("%s could not be loaded" % path)
			continue
		var recorder: MovementRecorder = await _play_in_level(replay.frames)
		var frame_index: int = _find_first_diverging_frame(recorder.positions, replay.positions)
		var message: String = "%s: player left recorded path at frame %d" % [path.get_file(), frame_index]
		if frame_index != -1:
			message += ", was %s, recorded %s" % [recorder.positions[frame_index], replay.positions[frame_index]]
			message += ". Intended change? delete replay + record it again"
		assert_eq(frame_index, -1, message)
		# one level at time, two players on same floor would collide
		recorder.owner.free()
#endregion


#region Helpers
func _make_frames(count: int, frame: InputFrame) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	frames.resize(count)
	frames.fill(frame)
	return frames


# returns recorder once one position /frame was sampled, recording samples both in same step
func _play_in_level(frames: Array[InputFrame]) -> MovementRecorder:
	var recorder: MovementRecorder = _start_level(frames)
	await _wait_for_positions(recorder, frames.size())
	return recorder


# level is in tree + ready, ∅ physics frame ran yet. Freed after test, freeing it sooner is fine
func _start_level(frames: Array[InputFrame]) -> MovementRecorder:
	var level: Node = LEVEL_SCENE.instantiate()
	add_child_autofree(level)
	var recorder: MovementRecorder = Component.find_descendant_of_type(level, MovementRecorder, true)
	recorder.use_replay_input(frames)
	return recorder


func _wait_for_positions(recorder: MovementRecorder, position_count: int) -> void:
	var timeout: float = float(position_count) / Engine.physics_ticks_per_second + 5.0
	var has_finished: bool = await wait_until(func() -> bool: return recorder.positions.size() >= position_count, timeout)
	assert_true(has_finished, "level sampled %d of %d positions" % [recorder.positions.size(), position_count])


func _get_last_horizontal_speed(recorder: MovementRecorder) -> float:
	var last: Vector3 = recorder.positions[-1]
	var before_last: Vector3 = recorder.positions[-2]
	return Vector2(last.x - before_last.x, last.z - before_last.z).length() * Engine.physics_ticks_per_second


# -1 when every recorded position is matched within POSITION_TOLERANCE
func _find_first_diverging_frame(played: PackedVector3Array, recorded: PackedVector3Array) -> int:
	for index: int in recorded.size():
		if index >= played.size() or played[index].distance_to(recorded[index]) > POSITION_TOLERANCE:
			return index
	return -1


func _find_replay_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(MovementRecorder.REPLAY_DIRECTORY):
		return paths
	for file_name: String in DirAccess.get_files_at(MovementRecorder.REPLAY_DIRECTORY):
		if file_name.get_extension() == "json":
			paths.append(MovementRecorder.REPLAY_DIRECTORY.path_join(file_name))
	return paths
#endregion
