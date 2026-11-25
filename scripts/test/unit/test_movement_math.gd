# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Static movement math of [PlatformerMovementBase], w/o body/scene.
## Uses [MovementProfile] defaults ∴ tuning player scene profile changes ∅ here.
extends GutTest

const DELTA: float = 1.0 / 60.0
const GRAVITY: float = 9.8

var _profile: MovementProfile


#region Setup/Teardown
func before_each() -> void:
	_profile = MovementProfile.new()
#endregion


#region Jump
func test_jump_velocity_reaches_jump_height() -> void:
	var velocity: float = PlatformerMovementBase.get_jump_velocity(_profile, false, GRAVITY)
	# v² / 2g = height under rise gravity
	assert_almost_eq(velocity * velocity / (2.0 * _profile.jump_gravity), _profile.jump_height, 0.001)


func test_running_jump_is_higher() -> void:
	var walking: float = PlatformerMovementBase.get_jump_velocity(_profile, false, GRAVITY)
	var running: float = PlatformerMovementBase.get_jump_velocity(_profile, true, GRAVITY)
	assert_almost_eq(running / walking, sqrt(_profile.running_jump_height_multiplier), 0.001)


func test_jump_without_jump_gravity_uses_base_gravity() -> void:
	_profile.jump_gravity = 0.0
	var velocity: float = PlatformerMovementBase.get_jump_velocity(_profile, false, GRAVITY)
	assert_almost_eq(velocity, sqrt(2.0 * GRAVITY * _profile.jump_height), 0.001)


# frame by frame like air state ∴ catches gravity/apex hang drifting from jump_height
func test_simulated_jump_peaks_at_jump_height() -> void:
	_profile.apex_hang_gravity_multiplier = 1.0
	# discrete steps land < 1 frame of rise off
	assert_almost_eq(_simulate_jump_peak(), _profile.jump_height, 0.15)


func test_apex_hang_raises_peak() -> void:
	var height_with_hang: float = _simulate_jump_peak()
	_profile.apex_hang_gravity_multiplier = 1.0
	assert_gt(height_with_hang, _simulate_jump_peak())


func test_momentum_jump_at_run_speed_uses_full_multiplier() -> void:
	var velocity: Vector2 = Vector2(_profile.run_speed, 0.0)
	var jumped: Vector2 = PlatformerMovementBase.get_momentum_jump_velocity(velocity, _profile)
	assert_almost_eq(jumped.x, _profile.run_speed * _profile.momentum_jump_distance_multiplier, 0.001)


func test_momentum_jump_from_standstill_adds_nothing() -> void:
	assert_eq(PlatformerMovementBase.get_momentum_jump_velocity(Vector2.ZERO, _profile), Vector2.ZERO)
#endregion


#region Air + wall slide
func test_fall_speed_is_capped() -> void:
	var vertical: float = PlatformerMovementBase.get_air_vertical_velocity(
		-_profile.max_fall_speed,
		_profile,
		GRAVITY,
		DELTA,
	)
	assert_eq(vertical, -_profile.max_fall_speed)


func test_wall_slide_speed_is_capped() -> void:
	var vertical: float = PlatformerMovementBase.get_wall_slide_vertical_velocity(
		-_profile.wall_slide_speed,
		_profile,
		GRAVITY,
		DELTA,
	)
	assert_eq(vertical, -_profile.wall_slide_speed)
#endregion


#region Horizontal
func test_turning_uses_turn_acceleration() -> void:
	var velocity: Vector2 = _accelerate_to_move_speed(_profile.move_speed, Vector2.LEFT)
	assert_almost_eq(velocity.x, _profile.move_speed - _profile.turn_acceleration * DELTA, 0.001)


func test_speeding_up_uses_move_acceleration() -> void:
	var velocity: Vector2 = _accelerate_to_move_speed(0.0, Vector2.RIGHT)
	assert_almost_eq(velocity.x, minf(_profile.move_acceleration * DELTA, _profile.move_speed), 0.001)


func test_acceleration_stops_at_target_speed() -> void:
	var velocity: Vector2 = _accelerate_to_move_speed(_profile.move_speed, Vector2.RIGHT)
	assert_eq(velocity, Vector2(_profile.move_speed, 0.0))
#endregion


#region Wall jump
func test_first_wall_jump_is_allowed() -> void:
	assert_true(PlatformerMovementBase.can_wall_jump_off(_profile, Vector2.ZERO, Vector2.RIGHT))


func test_same_wall_twice_is_blocked() -> void:
	assert_false(PlatformerMovementBase.can_wall_jump_off(_profile, Vector2.RIGHT, Vector2.RIGHT))


func test_opposite_wall_is_allowed() -> void:
	assert_true(PlatformerMovementBase.can_wall_jump_off(_profile, Vector2.RIGHT, Vector2.LEFT))


func test_wall_contact_refill_allows_same_wall() -> void:
	_profile.wall_contact_refills_jumps = true
	assert_true(PlatformerMovementBase.can_wall_jump_off(_profile, Vector2.RIGHT, Vector2.RIGHT))


func test_disabled_wall_jump_is_never_allowed() -> void:
	_profile.wall_jump_enabled = false
	assert_false(PlatformerMovementBase.can_wall_jump_off(_profile, Vector2.ZERO, Vector2.RIGHT))
#endregion


#region Helpers
# one frame from horizontal speed [param from_x] toward move_speed in [param direction]
func _accelerate_to_move_speed(from_x: float, direction: Vector2) -> Vector2:
	var velocity: Vector2 = Vector2(from_x, 0.0)
	return PlatformerMovementBase.get_accelerated_horizontal_velocity(velocity, direction, _profile.move_speed, _profile, DELTA)


# height gained until vertical velocity turns downward
func _simulate_jump_peak() -> float:
	var vertical: float = PlatformerMovementBase.get_jump_velocity(_profile, false, GRAVITY)
	var height: float = 0.0
	while vertical > 0.0:
		height += vertical * DELTA
		vertical = PlatformerMovementBase.get_air_vertical_velocity(vertical, _profile, GRAVITY, DELTA)
	return height
#endregion
