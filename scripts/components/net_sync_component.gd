# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Publishes local player position, facing + animation through [code]Net[/code].
## Works for 3D body w/ [AnimatedSprite3D] + 2D body w/ [AnimatedSprite2D],
## 2D position is sent w/ z = 0. Dependencies (body, sprite) are injected by body.
class_name NetSyncComponent
extends Component

## Seconds between updates.
@export var send_interval: float = 0.1

var body: Node
var sprite: Node


func _on_setup() -> void:
	if not _require_dependencies({ "body": body, "sprite": sprite }):
		return
	var timer: Timer = Timer.new()
	timer.wait_time = send_interval
	# sampled in physics step, where body has moved
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	timer.autostart = true
	timer.timeout.connect(_send_local_player_state)
	add_child(timer)


func _send_local_player_state() -> void:
	var is_2d: bool = body is Node2D
	var position: Vector3
	if is_2d:
		var position_2d: Vector2 = (body as Node2D).global_position
		position = Vector3(position_2d.x, position_2d.y, 0.0)
	else:
		position = (body as Node3D).global_position
	Net.send_local_player_state(position, sprite.flip_h, sprite.animation, is_2d)
