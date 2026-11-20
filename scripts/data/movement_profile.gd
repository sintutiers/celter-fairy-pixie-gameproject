# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Tuning values for [PlatformerMovementBase].
## Speeds are units /second, accelerations units /second squared, times seconds.
class_name MovementProfile
extends Resource

@export_group("Movement")
## Walk speed.
@export var move_speed: float = 7.5
## Speed while run is held.
@export var run_speed: float = 12.5
## Speed gained /second toward walk/run speed.
@export var move_acceleration: float = 120.0
## Used, not [member move_acceleration] when reversing direction.
@export var turn_acceleration: float = 360.0
## Deceleration w/ no input.
@export var move_friction: float = 120.0

@export_group("Jump")
## Peak height of standing jump.
@export var jump_height: float = 2.0
## Gravity while rising. <= 0 uses world gravity.
@export var jump_gravity: float = 10.0
## Grace time to still jump after leaving ground.
@export_range(0.0, 1.0, 0.02) var coyote_time: float = 0.1
## Grace time for jump pressed before landing.
@export_range(0.0, 1.0, 0.01) var jump_buffer_time: float = 0.1
## Jumps /airtime, ground jump included.
@export_range(1, 10, 1) var max_jumps: int = 1
## Vertical velocity multiplier when jump is released while rising. Lower = shorter hop.
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier: float = 0.5
## [member jump_height] multiplier when jumping while running.
@export_range(0.0, 3.0, 0.05) var running_jump_height_multiplier: float = 1.5
## Horizontal speed multiplier at full run speed, scales down w/ speed.
@export_range(0.0, 3.0, 0.05) var momentum_jump_distance_multiplier: float = 1.5

@export_group("Fall")
## Fall speed cap.
@export var max_fall_speed: float = 30.0
## Added to world gravity while falling.
@export var fall_gravity_offset: float = 0.0
## Hang time applies while vertical speed is below this.
## Keep it well under jump launch speed (≈10 for default jump), else it covers whole jump.
@export var apex_hang_threshold: float = 1.5
## Gravity multiplier during hang time, see [member apex_hang_threshold].
@export_range(0.0, 1.0, 0.05) var apex_hang_gravity_multiplier: float = 0.5

@export_group("Wall")
## Off = wall slide w/o wall jump.
@export var wall_jump_enabled: bool = true
## Touching wall (wall slide) refills jumps. Off = wall jumps are free but air jumps stay spent,
## + same wall cannot be wall jumped twice in a row before landing.
@export var wall_contact_refills_jumps: bool = false
## Fall speed cap while wall sliding.
@export var wall_slide_speed: float = 4.0
## Horizontal speed away from wall on wall jump.
@export var wall_jump_push_speed: float = 10.0
## Horizontal input is ignored for this long after wall jump.
@export_range(0.0, 1.0, 0.01) var wall_jump_lock_duration: float = 0.1

@export_group("Dash")
## Off = dash only in air.
@export var can_dash_on_ground: bool = false
## Horizontal speed during dash.
@export var dash_speed: float = 35.0
## How long dash lasts.
@export_range(0.0, 1.0, 0.01) var dash_duration: float = 0.3
## Time from dash start until next dash is allowed.
@export_range(0.0, 5.0, 0.01) var dash_cooldown: float = 0.75
## Dash /airtime, refilled on landing.
@export_range(0, 10, 1) var max_dashes: int = 0

@export_group("Crouch")
## Collision shape height multiplier while crouched. Bottom stays at feet.
## Capsule never gets shorter than its two caps (2 × crouched radius, see [member crouch_radius_scale]).
@export_range(0.0, 1.0, 0.01) var crouch_collision_scale: float = 0.5
## Capsule radius multiplier while crouched. Lets crouched capsule get shorter than
## standing radius allows. 1 = same width as standing.
@export_range(0.1, 1.0, 0.01) var crouch_radius_scale: float = 0.5
## Walk speed multiplier while crouched.
@export_range(0.0, 1.0, 0.05) var crouch_speed_multiplier: float = 0.5
## Stay crouched after releasing crouch while ceiling is too low to stand,
## stand up as soon as there is room. Off = stand up at once, even inside ceiling.
@export var crouch_until_room_to_stand: bool = true
