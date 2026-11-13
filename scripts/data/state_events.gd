# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Events sent to player [StateChart] by [PlatformerMovementBase].
## [b]Warning:[/b] Values must match transition events in player scenes. Typo or
## rename on either side is not reported, event is just ignored.
class_name StateEvents
extends RefCounted

const DASH: StringName = &"dash"
const CROUCH: StringName = &"crouch"
const CROUCH_END: StringName = &"crouch_end"
const JUMP: StringName = &"jump"
const FALL: StringName = &"fall"
const LAND: StringName = &"land"
const WALL_SLIDE: StringName = &"wall_slide"
