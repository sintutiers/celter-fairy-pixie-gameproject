# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Spawns player where this marker stands ∴ level holds one spawner
## instead of its own copy of player scene.
## Player becomes child of spawner + is found like any other player,
## through [method PlayerApi.find_local_player_api].
## Per level changes to player (edited component value) not possible this way,
## put those in [member player_scene]/in level script.
class_name PlayerSpawner
extends Marker3D

@export var player_scene: PackedScene = preload("res://scenes/game/player.tscn")
## Gets player as follow target. Leave ∅ for level w/ fixed camera.
@export var camera: PhantomCamera3D

var _player: Node3D


# not in _ready: every _enter_tree in level runs before first _ready ∴ player +
# its api exist for any _ready that looks them up (level script, HUD), whatever node order
func _enter_tree() -> void:
	# runs again when spawner is moved in tree
	if _player:
		return
	if not player_scene:
		Log.error("%s: no player_scene, level has no player" % name)
		return
	_player = player_scene.instantiate() as Node3D
	if not _player:
		Log.error("%s: player_scene root is not a Node3D, level has no player" % name)
		return
	add_child(_player)
	if camera:
		camera.follow_target = _player
