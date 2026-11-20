# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Another player, shown from net_player row. Display only, no physics/input.
## Expects [AnimatedSprite3D] child whose animations match [Animations].
class_name RemotePlayer
extends Node3D

## Seconds to ease toward latest position. Keep it above send interval of
## [NetSyncComponent], else motion stutters between updates.
@export var smoothing: float = 0.15

var _sprite: AnimatedSprite3D
var _target: Vector3
var _placed: bool = false
# last animation reported missing, row repeats every update ∴ its logged once
var _missing_animation: String = ""


func _ready() -> void:
	_sprite = Component.find_descendant_of_type(self, AnimatedSprite3D) as AnimatedSprite3D
	if not _sprite:
		Log.error("%s: no AnimatedSprite3D child, position only" % name)


func _process(delta: float) -> void:
	global_position = global_position.lerp(_target, 1.0 - exp(-delta / smoothing))


## Applies latest row. First call snaps to position, not easing from origin.
func apply_net_player_row(row: FaerieNetPlayer) -> void:
	_target = Vector3(row.x, row.y, row.z)
	if not _placed:
		global_position = _target
		_placed = true
	# already reported in _ready
	if not _sprite:
		return
	_sprite.flip_h = row.flip
	if _sprite.animation == row.animation:
		return
	if not _sprite.sprite_frames.has_animation(row.animation):
		if row.animation != _missing_animation:
			_missing_animation = row.animation
			Log.error("%s: no animation '%s'" % [name, row.animation])
		return
	_sprite.play(row.animation)
