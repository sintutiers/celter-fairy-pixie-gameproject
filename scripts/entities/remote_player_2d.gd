# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## 2D twin of [RemotePlayer], shown from a net_player row. Display only, no physics or input.
## Expects an [AnimatedSprite2D] child whose animations match [Animations].
## Uses x and y of the row, z is ignored. Keep it in step with [RemotePlayer].
class_name RemotePlayer2D
extends Node2D

## Seconds to ease toward the latest position. Keep it above the send interval of
## [NetSyncComponent] or motion stutters between updates.
@export var smoothing: float = 0.15

var _sprite: AnimatedSprite2D
var _target: Vector2
var _placed: bool = false
# Last animation reported missing. The row repeats every update, so it is logged once.
var _missing_animation: String = ""


func _ready() -> void:
	_sprite = Component.find_component(self, AnimatedSprite2D) as AnimatedSprite2D
	if not _sprite:
		push_error("%s: no AnimatedSprite2D child, position only" % name)


func _process(delta: float) -> void:
	global_position = global_position.lerp(_target, 1.0 - exp(-delta / smoothing))


## Forgets the old position, so a pooled remote snaps to its next row.
func reset() -> void:
	_placed = false


## Applies the latest row. The first call snaps to the position instead of easing from the origin.
func apply(row: FaerieNetPlayer) -> void:
	_target = Vector2(row.x, row.y)
	if not _placed:
		global_position = _target
		_placed = true
	# Already reported in _ready.
	if not _sprite:
		return
	_sprite.flip_h = row.flip
	if _sprite.animation == row.animation:
		return
	if not _sprite.sprite_frames.has_animation(row.animation):
		if row.animation != _missing_animation:
			_missing_animation = row.animation
			push_error("%s: no animation '%s'" % [name, row.animation])
		return
	_sprite.play(row.animation)
