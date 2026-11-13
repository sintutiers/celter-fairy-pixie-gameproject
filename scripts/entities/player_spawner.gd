# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Spawns player where this marker stands, so level holds one spawner
## instead of its own copy of player scene.
## Player becomes child of spawner and is found like any other player,
## through [method PlayerApi.find].
## Per level changes to player (edited component value) are not possible this way,
## put those in [member player_scene] or in level script.
class_name PlayerSpawner
extends Marker3D

@export var player_scene: PackedScene = preload("res://scenes/game/player.tscn")
## Gets player as follow target. Leave empty for level with fixed camera.
@export var camera: PhantomCamera3D

var _player: Node3D


# Not in _ready: every _enter_tree in level runs before first _ready, so player and
# its api exist for any _ready that looks them up (level script, HUD), whatever node order.
func _enter_tree() -> void:
	# Runs again when spawner is moved in tree.
	if _player:
		return
	if not player_scene:
		push_error("%s: no player_scene, level has no player" % name)
		return
	_player = player_scene.instantiate() as Node3D
	if not _player:
		push_error("%s: player_scene root is not a Node3D, level has no player" % name)
		return
	add_child(_player)
	if camera:
		camera.follow_target = _player
