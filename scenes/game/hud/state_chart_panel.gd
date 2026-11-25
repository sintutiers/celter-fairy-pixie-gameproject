# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Addon state chart debugger (active states + event history) for local player,
## shown while [code]DebugMenu[/code] is (F3). [code]DebugCommands[/code] adds it to
## [code]DebugMenu[/code] ∴ it is in every scene, not in [Hud].
## Picks player again when shown + after respawn/level change.
class_name StateChartPanel
extends "res://addons/godot_state_charts/utilities/state_chart_debugger.gd"

var _watched_player: Node


func _ready() -> void:
	super()
	DebugMenu.visibility_changed.connect(_on_debug_menu_visibility_changed)
	_on_debug_menu_visibility_changed()


func _process(delta: float) -> void:
	# player respawned/level changed while shown ∴ watch new one
	if not is_instance_valid(_watched_player):
		_watch_local_player()
	super(delta)


func _on_debug_menu_visibility_changed() -> void:
	# enabled setter shows/hides + starts/stops processing
	enabled = DebugMenu.visible
	if enabled:
		_watch_local_player()


func _watch_local_player() -> void:
	var player: Node = get_tree().get_first_node_in_group(PlayerApi.GROUP)
	# debug_node(null) turns debugger off ∴ only called w/ player, menus keep looking
	if player and debug_node(player):
		_watched_player = player
