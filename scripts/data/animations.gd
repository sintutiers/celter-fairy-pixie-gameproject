# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Sprite animation names, must match animations in player sprite frames.
## Ground motions ([constant IDLE] to [constant CROUCH_IDLE]) are also what
## [signal PlatformerMovementBase.ground_motion_changed] reports +
## [AnimationComponent] plays them as is.
class_name Animations
extends RefCounted

const IDLE: StringName = &"idle"
const WALK: StringName = &"walk"
const RUN: StringName = &"run"
const PUSH: StringName = &"push"
const CROUCH_WALK: StringName = &"crouch_walk"
const CROUCH_IDLE: StringName = &"crouch_idle"
const JUMP: StringName = &"jump"
const AIRSPIN: StringName = &"airspin"
const WALL_SLIDE: StringName = &"wall_slide"
const DASH: StringName = &"dash"
const FALLING: StringName = &"falling"
const LAND: StringName = &"land"
