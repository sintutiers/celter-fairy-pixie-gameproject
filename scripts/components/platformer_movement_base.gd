# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Platformer movement: walk, run, jump, wall slide, dash, crouch.
## State chart picks active state, this does physics for it and sends
## events back through [method _send_state_chart_event]. Values come from [MovementProfile].
## Extend it and implement abstract functions for 2D or 3D.
##
## Dependencies (profile, input, facing, state chart, optional interaction) are injected
## by body in [method Node._enter_tree], so they are set in [method Component._on_ready]
## and [method Component._on_setup].
@abstract
class_name PlatformerMovementBase
extends Component

## Emitted when idle, walk, run, push or crouch motion changes on ground.
signal ground_motion_changed(motion: StringName)
## [param jump_count] is jump number in this airtime, 1 for first.
signal jumped(jump_count: int)
## Emitted instead of [signal jumped] when jump pushes off wall.
signal wall_jumped
## [param motion] is ground motion at moment of landing.
signal landed(motion: StringName)
## Emitted once when vertical velocity turns downward.
signal started_falling
## Emitted once when wall slide starts.
signal wall_slid
## Emitted when wall slide ends by losing wall, not by landing or wall jump.
signal fell_from_wall
## Emitted once when dash starts.
signal dashed

## Ignore input during interactions (see [InteractionComponent]).
@export var locks_during_interact: bool = true

var profile: MovementProfile
var input_component: InputComponent
var facing_component: FacingComponent
var interaction_component: InteractionComponent
var state_chart: StateChart

var _empty_frame: InputFrame = InputFrame.new()
# Transition was sent this frame, so post-move check is stale and skipped.
var _transition_sent: bool = false
var _grounded_before_move: bool = false
var _locked: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jumps_used: int = 0
var _current_motion: StringName = Animations.IDLE
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dashes_used: int = 0
var _dash_direction: Vector2 = Vector2.RIGHT
var _wall_jump_lock_timer: float = 0.0
var _was_falling: bool = false
# Only for GameLog, so held direction is logged once.
var _logged_input_direction: Vector2i = Vector2i.ZERO

@onready var _ground_state: StateChartState = %Ground
@onready var _air_state: StateChartState = %Air
@onready var _wall_slide_state: StateChartState = %WallSlide
@onready var _dash_state: StateChartState = %Dash
@onready var _crouch_state: StateChartState = %Crouch


#region Lifecycle
# Order per frame: state chart runs active state physics (priority 0),
# then this runs move_and_slide and post-move checks (priority 1).
func _physics_process(delta: float) -> void:
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	if _wall_jump_lock_timer > 0.0:
		_wall_jump_lock_timer -= delta
	_grounded_before_move = _is_on_floor()
	_move_and_slide()
	if not _transition_sent:
		_run_active_state_post_move_check()
	_transition_sent = false


#region Abstract
# Horizontal vectors are in world space (x/z in 3D). Vertical values are along up.
# _get_gravity_magnitude returns positive magnitude.
@abstract func _get_gravity_magnitude() -> float


@abstract func _get_movement_input(frame: InputFrame) -> Vector2


@abstract func _convert_input_direction_to_world(direction: Vector2) -> Vector2


@abstract func _get_default_dash_direction() -> Vector2


@abstract func _get_horizontal_velocity() -> Vector2


@abstract func _set_horizontal_velocity(value: Vector2) -> void


@abstract func _get_vertical_velocity() -> float


@abstract func _set_vertical_velocity(value: float) -> void


@abstract func _get_wall_normal() -> Vector2


@abstract func _move_and_slide() -> void


@abstract func _is_on_floor() -> bool


@abstract func _is_on_wall() -> bool


@abstract func _is_on_wall_only() -> bool


@abstract func _is_on_ceiling() -> bool


@abstract func _set_collision_shape_crouched(crouched: bool) -> void


# Standing shape fits at current position. Gates leaving crouch under low ceiling.
@abstract func _has_room_to_stand() -> bool
#endregion


func _on_ready() -> void:
	process_physics_priority = 1
	# _on_setup reports missing state chart.
	if not state_chart:
		return
	state_chart.process_physics_priority = 0
	_ground_state.state_physics_processing.connect(_on_ground_state_physics_processing)
	_air_state.state_physics_processing.connect(_on_air_state_physics_processing)
	_wall_slide_state.state_entered.connect(_on_wall_slide_state_entered)
	_wall_slide_state.state_physics_processing.connect(_on_wall_slide_state_physics_processing)
	_dash_state.state_entered.connect(_on_dash_state_entered)
	_dash_state.state_physics_processing.connect(_on_dash_state_physics_processing)
	_crouch_state.state_entered.connect(_on_crouch_state_entered)
	_crouch_state.state_physics_processing.connect(_on_crouch_state_physics_processing)
	_crouch_state.state_exited.connect(_on_crouch_state_exited)


func _on_setup() -> void:
	var dependencies: Dictionary = {
		"profile": profile,
		"input_component": input_component,
		"facing_component": facing_component,
		"state_chart": state_chart,
	}
	if not _require_dependencies(dependencies):
		_disable_movement()
		return

	if locks_during_interact and interaction_component:
		interaction_component.interact_started.connect(_set_input_locked.bind(true))
		interaction_component.interact_ended.connect(_set_input_locked.bind(false))
#endregion


#region Helpers
# Stops state chart too, so no state handler runs on missing dependencies.
func _disable_movement() -> void:
	set_physics_process(false)
	if state_chart:
		state_chart.process_mode = Node.PROCESS_MODE_DISABLED


func _set_input_locked(value: bool) -> void:
	_locked = value


# Empty while locked, so every state sees no input instead of needing its own check.
func _get_input_frame() -> InputFrame:
	if _locked:
		return _empty_frame
	return input_component.get_frame()


func _run_active_state_post_move_check() -> void:
	if _ground_state.active:
		_run_ground_post_move_check()
	elif _air_state.active:
		_run_air_post_move_check()
	elif _wall_slide_state.active:
		_run_wall_slide_post_move_check()
	elif _dash_state.active:
		_run_dash_post_move_check()
	elif _crouch_state.active:
		_run_crouch_post_move_check()


func _get_current_movement_input() -> Vector2:
	return _get_movement_input(_get_input_frame()).limit_length(1.0)


# Sends event to state chart, see StateEvents. Post-move check is skipped this frame.
func _send_state_chart_event(event: StringName) -> void:
	_transition_sent = true
	state_chart.send_event(event)


func _is_pushing_into_wall(input_dir: Vector2) -> bool:
	if input_dir.is_zero_approx():
		return false
	return _convert_input_direction_to_world(input_dir).dot(-_get_wall_normal()) > 0.0


func _apply_horizontal_movement(
	delta: float,
	input_dir: Vector2,
	is_running: bool,
	speed_multiplier: float = 1.0,
) -> void:
	var input_sign: Vector2i = Vector2i(input_dir.sign())
	if input_sign != _logged_input_direction:
		_logged_input_direction = input_sign
		GameLog.write(&"movement", "input", input_sign)
	# Wall jump lock ignores input, facing included.
	if _wall_jump_lock_timer > 0.0:
		return
	var horizontal_velocity: Vector2 = _get_horizontal_velocity()

	if input_dir.is_zero_approx():
		_set_horizontal_velocity(
			horizontal_velocity.move_toward(Vector2.ZERO, profile.move_friction * delta)
		)
		return

	var direction: Vector2 = _convert_input_direction_to_world(input_dir)
	var turning: bool = not horizontal_velocity.is_zero_approx() and horizontal_velocity.dot(direction) < 0.0
	var accel_rate: float = profile.turn_acceleration if turning else profile.move_acceleration
	var target_speed: float = (profile.run_speed if is_running else profile.move_speed) * speed_multiplier
	_set_horizontal_velocity(horizontal_velocity.move_toward(direction * target_speed, accel_rate * delta))
	facing_component.update_facing_from_input(input_dir)


func _update_current_motion(on_ground: bool, input_dir: Vector2, is_running: bool) -> void:
	var motion: StringName
	if not input_dir.is_zero_approx() and _is_on_wall():
		motion = Animations.PUSH
	elif is_running and not input_dir.is_zero_approx():
		motion = Animations.RUN
	elif not input_dir.is_zero_approx():
		motion = Animations.WALK
	else:
		motion = Animations.IDLE

	if motion == _current_motion:
		return
	_current_motion = motion
	# Tracked in air too, so landing reports right motion. Only emitted on ground.
	if on_ground:
		GameLog.write(&"movement", str(motion))
		ground_motion_changed.emit(motion)


func _update_jump_buffer(delta: float) -> void:
	if _get_input_frame().jump_pressed:
		_jump_buffer_timer = profile.jump_buffer_time
	else:
		_jump_buffer_timer -= delta


func _try_jump(is_running: bool, is_wall_jump: bool = false) -> bool:
	var can_jump: bool = _coyote_timer > 0.0 or _jumps_used < profile.max_jumps
	if _jump_buffer_timer <= 0.0 or not can_jump:
		return false

	var height: float = profile.jump_height * (
		profile.running_jump_height_multiplier if is_running else 1.0
	)
	var rise_gravity: float = profile.jump_gravity if profile.jump_gravity > 0.0 else _get_gravity_magnitude()
	# v = sqrt(2 * g * h) reaches exactly height under rise gravity.
	_set_vertical_velocity(sqrt(2.0 * rise_gravity * height))

	if is_wall_jump:
		_set_horizontal_velocity(_get_wall_normal() * profile.wall_jump_push_speed)
		_wall_jump_lock_timer = profile.wall_jump_lock_duration
	else:
		var horizontal_velocity: Vector2 = _get_horizontal_velocity()
		var speed_ratio: float = clampf(horizontal_velocity.length() / profile.run_speed, 0.0, 1.0)
		_set_horizontal_velocity(
			horizontal_velocity * lerpf(1.0, profile.momentum_jump_distance_multiplier, speed_ratio)
		)

	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_jumps_used += 1
	_was_falling = false

	if is_wall_jump:
		GameLog.write(&"movement", "wall jump")
		wall_jumped.emit()
	else:
		GameLog.write(&"movement", "jump", _jumps_used)
		jumped.emit(_jumps_used)
	return true


func _should_start_dash() -> bool:
	if _dash_cooldown_timer > 0.0 or _dashes_used >= profile.max_dashes:
		return false
	return _get_input_frame().dash_pressed


# Refills jumps and dashes, whatever state landing came from.
func _handle_landing() -> void:
	_dashes_used = 0
	_jumps_used = 0
	_was_falling = false
	# landed already carries motion. Emitting ground_motion_changed here
	# would replace landing animation on same frame, see
	# AnimationComponent._on_ground_motion_changed.
	GameLog.write(&"movement", "landed", str(_current_motion))
	landed.emit(_current_motion)
	_send_state_chart_event(StateEvents.LAND)
#endregion


#region Ground
func _on_ground_state_physics_processing(delta: float) -> void:
	var frame: InputFrame = _get_input_frame()

	_coyote_timer = profile.coyote_time
	_update_jump_buffer(delta)

	if profile.can_dash_on_ground and _should_start_dash():
		_send_state_chart_event(StateEvents.DASH)
		return

	if frame.crouch:
		_send_state_chart_event(StateEvents.CROUCH)
		return

	_apply_horizontal_movement(delta, _get_current_movement_input(), frame.run)

	if _try_jump(frame.run):
		_send_state_chart_event(StateEvents.JUMP)


func _run_ground_post_move_check() -> void:
	_update_current_motion(true, _get_current_movement_input(), _get_input_frame().run)
	if not _is_on_floor():
		_send_state_chart_event(StateEvents.FALL)
#endregion


#region Air
func _on_air_state_physics_processing(delta: float) -> void:
	if _should_start_dash():
		_send_state_chart_event(StateEvents.DASH)
		return

	var vertical: float = _get_vertical_velocity()
	# Rise gravity only while going up, so jump height and fall speed tune separately.
	var gravity: float = (
		profile.jump_gravity
		if (profile.jump_gravity > 0.0 and vertical > 0.0)
		else _get_gravity_magnitude() + profile.fall_gravity_offset
	)
	# Less gravity near apex for hang time.
	if absf(vertical) < profile.apex_hang_threshold:
		gravity *= profile.apex_hang_gravity_multiplier
	vertical = maxf(vertical - gravity * delta, -profile.max_fall_speed)

	if _is_on_ceiling() and vertical > 0.0:
		vertical = 0.0

	if vertical < 0.0 and not _was_falling:
		_was_falling = true
		GameLog.write(&"movement", "falling")
		started_falling.emit()
	elif vertical >= 0.0:
		_was_falling = false

	_coyote_timer -= delta
	# Walking off ledge spends ground jump once grace time is over,
	# otherwise every air jump is still available.
	if _coyote_timer <= 0.0 and _jumps_used == 0:
		_jumps_used = 1
	_update_jump_buffer(delta)

	if _get_input_frame().jump_released and vertical > 0.0:
		vertical *= profile.jump_cut_multiplier
	_set_vertical_velocity(vertical)

	_apply_horizontal_movement(delta, _get_current_movement_input(), false)
	_try_jump(false)


func _run_air_post_move_check() -> void:
	var input_dir: Vector2 = _get_current_movement_input()
	_update_current_motion(false, input_dir, false)

	if not _grounded_before_move and _is_on_floor():
		_handle_landing()
		return

	if _is_on_wall_only() and _is_pushing_into_wall(input_dir):
		_send_state_chart_event(StateEvents.WALL_SLIDE)
#endregion


#region Wall slide
func _on_wall_slide_state_entered() -> void:
	_jump_buffer_timer = 0.0
	_was_falling = false
	GameLog.write(&"movement", "wall slide")
	wall_slid.emit()
	# Wall contact refills jumps so wall jumps can chain.
	if profile.wall_jump_enabled:
		_jumps_used = 0
		_coyote_timer = profile.coyote_time


func _on_wall_slide_state_physics_processing(delta: float) -> void:
	var gravity: float = _get_gravity_magnitude() + profile.fall_gravity_offset
	_set_vertical_velocity(
		maxf(_get_vertical_velocity() - gravity * delta, -profile.wall_slide_speed)
	)
	_update_jump_buffer(delta)

	if profile.wall_jump_enabled and _try_jump(false, true):
		_send_state_chart_event(StateEvents.JUMP)
		return

	_apply_horizontal_movement(delta, _get_current_movement_input(), false)


func _run_wall_slide_post_move_check() -> void:
	if not _grounded_before_move and _is_on_floor():
		_handle_landing()
		return

	if not _is_on_wall():
		_send_state_chart_event(StateEvents.FALL)
		GameLog.write(&"movement", "fell from wall")
		fell_from_wall.emit()
#endregion


#region Dash
func _on_dash_state_entered() -> void:
	_dash_timer = profile.dash_duration
	_dash_cooldown_timer = profile.dash_cooldown
	_dashes_used += 1
	_was_falling = false

	var direction: Vector2 = _convert_input_direction_to_world(_get_current_movement_input())
	_dash_direction = direction.normalized() if not direction.is_zero_approx() else _get_default_dash_direction()
	GameLog.write(&"movement", "dash", _dash_direction)
	dashed.emit()


func _on_dash_state_physics_processing(delta: float) -> void:
	_set_horizontal_velocity(_dash_direction * profile.dash_speed)
	_set_vertical_velocity(0.0)
	_dash_timer -= delta


func _run_dash_post_move_check() -> void:
	if _dash_timer > 0.0:
		return

	if _is_on_floor():
		_update_current_motion(true, _get_current_movement_input(), _get_input_frame().run)
		_handle_landing()
	else:
		# Dash entry cleared _was_falling, so next air frame emits started_falling.
		_send_state_chart_event(StateEvents.FALL)
#endregion


#region Crouch
func _on_crouch_state_entered() -> void:
	_set_collision_shape_crouched(true)


func _on_crouch_state_physics_processing(delta: float) -> void:
	_apply_horizontal_movement(delta, _get_current_movement_input(), false, profile.crouch_speed_multiplier)
	# Never carry upward velocity into crouch.
	_set_vertical_velocity(minf(_get_vertical_velocity(), 0.0) - _get_gravity_magnitude() * delta)


func _run_crouch_post_move_check() -> void:
	var input_dir: Vector2 = _get_current_movement_input()
	var motion: StringName = Animations.CROUCH_WALK if not input_dir.is_zero_approx() else Animations.CROUCH_IDLE
	if motion != _current_motion:
		_current_motion = motion
		GameLog.write(&"movement", str(motion))
		ground_motion_changed.emit(motion)

	if not _is_on_floor():
		_send_state_chart_event(StateEvents.FALL)
		return
	if _get_input_frame().crouch:
		return
	if profile.crouch_until_room_to_stand and not _has_room_to_stand():
		return
	_send_state_chart_event(StateEvents.CROUCH_END)


func _on_crouch_state_exited() -> void:
	_set_collision_shape_crouched(false)
#endregion
