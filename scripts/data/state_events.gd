# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Events sent to the player's [StateChart] by [PlatformerMovementBase] and [InteractionComponent].
## @warning: The values must match the transition events in the player scenes. A typo or
## rename on either side is not reported, the event is just ignored.
class_name StateEvents
extends RefCounted

const DASH: StringName = &"dash"
const CROUCH: StringName = &"crouch"
const CROUCH_END: StringName = &"crouch_end"
const JUMP: StringName = &"jump"
const FALL: StringName = &"fall"
const LAND: StringName = &"land"
const WALL_SLIDE: StringName = &"wall_slide"
const INTERACT: StringName = &"interact"
const INTERACT_END: StringName = &"interact_end"
