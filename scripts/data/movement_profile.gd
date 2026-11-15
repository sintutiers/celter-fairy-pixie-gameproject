# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Tuning values for [PlatformerMovementBase].
## Speeds are units per second, accelerations units per second squared, times seconds.
class_name MovementProfile
extends Resource

@export_group("Movement")
@export var move_speed: float = 10.0
@export var run_speed: float = 20.0
@export var move_acceleration: float = 120.0
## Used instead of [member move_acceleration] when reversing direction.
@export var turn_acceleration: float = 360.0
## Deceleration with no input.
@export var move_friction: float = 120.0

@export_group("Jump")
## Peak height of standing jump.
@export var jump_height: float = 5.0
## Gravity while rising. 0 or less uses world gravity.
@export var jump_gravity: float = 10.0
## Grace time to still jump after leaving ground.
@export_range(0.0, 1.0, 0.01) var coyote_time: float = 0.1
## Grace time for jump pressed before landing.
@export_range(0.0, 1.0, 0.01) var jump_buffer_time: float = 0.1
@export_range(1, 10, 1) var max_jumps: int = 2
## Vertical velocity multiplier when jump is released while rising. Lower = shorter hop.
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier: float = 0.5
@export_range(0.0, 3.0, 0.05) var running_jump_height_multiplier: float = 1.5
## Horizontal speed multiplier at full run speed, scales down with speed.
@export_range(0.0, 3.0, 0.05) var momentum_jump_distance_multiplier: float = 1.5

@export_group("Fall")
@export var max_fall_speed: float = 30.0
## Added to world gravity while falling.
@export var fall_gravity_offset: float = 0.0
## Hang time applies while vertical speed is below this.
## Keep it well under jump launch speed (about 10 for default jump), or it covers whole jump.
@export var apex_hang_threshold: float = 2.0
@export_range(0.0, 1.0, 0.05) var apex_hang_gravity_multiplier: float = 0.5

@export_group("Wall")
@export var wall_jump_enabled: bool = true
@export var wall_slide_speed: float = 3.0
@export var wall_jump_push_speed: float = 12.0
## Horizontal input is ignored for this long after wall jump.
@export_range(0.0, 1.0, 0.01) var wall_jump_lock_duration: float = 0.1

@export_group("Dash")
## Off = dash only works in air.
@export var can_dash_on_ground: bool = false
@export var dash_speed: float = 35.0
@export_range(0.0, 1.0, 0.01) var dash_duration: float = 0.3
@export_range(0.0, 5.0, 0.01) var dash_cooldown: float = 0.75
## Dashes per airtime, refilled on landing.
@export_range(1, 10, 1) var max_dashes: int = 1

@export_group("Crouch")
## Collision shape height multiplier while crouched. Bottom stays at feet.
## Capsule never gets shorter than its two caps (2 × crouched radius, see [member crouch_radius_scale]).
@export_range(0.0, 1.0, 0.01) var crouch_collision_scale: float = 0.5
## Capsule radius multiplier while crouched. Lets crouched capsule get shorter than
## standing radius allows. 1 = same width as standing.
@export_range(0.1, 1.0, 0.01) var crouch_radius_scale: float = 0.5
@export_range(0.0, 1.0, 0.05) var crouch_speed_multiplier: float = 0.5
## Stay crouched after releasing crouch while ceiling is too low to stand,
## stand up as soon as there is room. Off = stand up at once, even inside ceiling.
@export var crouch_until_room_to_stand: bool = true
