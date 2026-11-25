# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Plays input into [MovementArena] + checks where player goes.
## Scripted tests check profile values hold in real physics. Recorded replays in
## [constant MovementArena.REPLAY_DIRECTORY] must follow their recorded path.
## Record: run movement_arena.tscn (F6) + press R, see [MovementArena].
## ⚠ Intended movement change > delete failing replay + record it again.
extends GutTest

const ARENA_SCENE: PackedScene = preload("res://scripts/test/integration/movement_arena.tscn")
const TEST_SAVE_PATH: String = "user://test_save.json"
## Meters player may drift from recorded path before replay counts as changed.
## Raise if same replay fails between editor + CI Godot version.
const POSITION_TOLERANCE: float = 0.05
# player drops onto floor + lands in these
const SETTLE_FRAMES: int = 30

var _original_save_path: String


#region Setup/Teardown
# SanityComponent reads + writes save ∴ arena player gets own, empty one
func before_all() -> void:
	_original_save_path = GameState.save_path
	GameState.save_path = TEST_SAVE_PATH
	GameState.unload()


func after_all() -> void:
	GameState.save_path = _original_save_path
	GameState.unload()
#endregion


#region Scripted
func test_standing_jump_peaks_near_jump_height() -> void:
	var frames: Array[InputFrame] = _make_frames(SETTLE_FRAMES, InputFrame.new())
	var jump: InputFrame = InputFrame.new()
	jump.jump_pressed = true
	frames.append(jump)
	frames.append_array(_make_frames(120, InputFrame.new()))
	var arena: MovementArena = await _play_in_arena(frames)

	var ground_height: float = arena.positions[SETTLE_FRAMES - 1].y
	var peak_height: float = ground_height
	for position: Vector3 in arena.positions.slice(SETTLE_FRAMES):
		peak_height = maxf(peak_height, position.y)
	var jump_height: float = arena.player.movement_profile.jump_height
	# apex hang slows gravity near top ∴ peak lands bit above jump_height
	assert_between(peak_height - ground_height, jump_height * 0.95, jump_height * 1.2)
	assert_almost_eq(arena.positions[-1].y, ground_height, 0.01, "lands back on floor")


func test_walk_reaches_move_speed() -> void:
	var walk: InputFrame = InputFrame.new()
	walk.move = Vector2.RIGHT
	var arena: MovementArena = await _play_in_arena(_make_frames(SETTLE_FRAMES + 60, walk))
	assert_almost_eq(_get_last_horizontal_speed(arena), arena.player.movement_profile.move_speed, 0.1)


func test_run_reaches_run_speed() -> void:
	var run: InputFrame = InputFrame.new()
	run.move = Vector2.RIGHT
	run.run = true
	var arena: MovementArena = await _play_in_arena(_make_frames(SETTLE_FRAMES + 60, run))
	assert_almost_eq(_get_last_horizontal_speed(arena), arena.player.movement_profile.run_speed, 0.1)


func test_walking_left_flips_facing() -> void:
	var walk_left: InputFrame = InputFrame.new()
	walk_left.move = Vector2.LEFT
	var frames: Array[InputFrame] = _make_frames(20, walk_left)
	var arena: MovementArena = _start_arena(frames)
	var movement: Movement3DComponent = Component.find_descendant_of_type(arena.player, Movement3DComponent)
	assert_eq(movement.facing, 1.0, "starts at default_facing_right")
	watch_signals(movement)
	await _wait_for_positions(arena, frames.size())
	assert_eq(movement.facing, -1.0)
	assert_signal_emitted_with_parameters(movement, "flipped", [-1.0])
	assert_signal_emit_count(movement, "flipped", 1, "held direction flips once")
#endregion


#region Recorded
func test_recorded_replays_follow_recorded_path() -> void:
	var paths: PackedStringArray = _find_replay_paths()
	if paths.is_empty():
		pending("no replays yet, run movement_arena.tscn (F6) + press R to record one")
		return
	for path: String in paths:
		var replay: InputReplay = InputReplay.load_file(path)
		if not replay:
			fail_test("%s could not be loaded" % path)
			continue
		var arena: MovementArena = await _play_in_arena(replay.frames, replay.positions.size())
		var frame_index: int = _find_first_diverging_frame(arena.positions, replay.positions)
		var message: String = "%s: player left recorded path at frame %d" % [path.get_file(), frame_index]
		if frame_index != -1:
			message += ", was %s, recorded %s" % [arena.positions[frame_index], replay.positions[frame_index]]
			message += ". Intended change? delete replay + record it again"
		assert_eq(frame_index, -1, message)
		# one arena at time, two players on same floor would collide
		remove_child(arena)
		arena.free()
#endregion


#region Helpers
func _make_frames(count: int, frame: InputFrame) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	for index: int in count:
		frames.append(frame)
	return frames


# returns arena once [param position_count] positions (default: one /frame) were sampled
func _play_in_arena(frames: Array[InputFrame], position_count: int = -1) -> MovementArena:
	var arena: MovementArena = _start_arena(frames)
	await _wait_for_positions(arena, frames.size() if position_count < 0 else position_count)
	return arena


# arena is in tree + ready, ∅ physics frame ran yet. Freed after test, freeing it sooner is fine
func _start_arena(frames: Array[InputFrame]) -> MovementArena:
	var arena: MovementArena = ARENA_SCENE.instantiate()
	arena.use_replay_input(frames)
	add_child_autofree(arena)
	return arena


func _wait_for_positions(arena: MovementArena, position_count: int) -> void:
	var timeout: float = float(position_count) / Engine.physics_ticks_per_second + 5.0
	var has_finished: bool = await wait_until(func() -> bool: return arena.positions.size() >= position_count, timeout)
	assert_true(has_finished, "arena sampled %d of %d positions" % [arena.positions.size(), position_count])


func _get_last_horizontal_speed(arena: MovementArena) -> float:
	var last: Vector3 = arena.positions[-1]
	var before_last: Vector3 = arena.positions[-2]
	return Vector2(last.x - before_last.x, last.z - before_last.z).length() * Engine.physics_ticks_per_second


# -1 when every recorded position is matched within POSITION_TOLERANCE
func _find_first_diverging_frame(played: PackedVector3Array, recorded: PackedVector3Array) -> int:
	for index: int in recorded.size():
		if index >= played.size() or played[index].distance_to(recorded[index]) > POSITION_TOLERANCE:
			return index
	return -1


func _find_replay_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(MovementArena.REPLAY_DIRECTORY):
		return paths
	for file_name: String in DirAccess.get_files_at(MovementArena.REPLAY_DIRECTORY):
		if file_name.get_extension() == "json":
			paths.append(MovementArena.REPLAY_DIRECTORY.path_join(file_name))
	return paths
#endregion
