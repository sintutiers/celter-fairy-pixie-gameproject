# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Safe space: sanity does not drain while player is inside, and first entry
## restores [member first_entry_sanity], once per sanctuary.
## Needs [CollisionShape3D] child and mask on physics layer 2 ("player").
class_name Sanctuary
extends Area3D

## Added to sanity on first entry. 0 = none.
@export var first_entry_sanity: float = 15.0
## Saves first entry per level in [LevelState], so it stays used after reload.
## Must be unique within level. Empty = used again every time level loads.
@export var persistent_id: String = ""

# Also covers play without game state, where nothing is saved.
var _entered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var sanity: SanityComponent = _get_sanity_component_of_body(body)
	if sanity:
		sanity.pause_sanity_drain()
		_restore_sanity_on_first_entry(sanity)


func _on_body_exited(body: Node3D) -> void:
	var sanity: SanityComponent = _get_sanity_component_of_body(body)
	if sanity:
		sanity.resume_sanity_drain()


func _restore_sanity_on_first_entry(sanity: SanityComponent) -> void:
	if _entered or first_entry_sanity == 0.0:
		return
	_entered = true
	if persistent_id != "" and GameState.has_game_state():
		var level_path: String = _get_placed_level_path()
		if GameState.get_level_flag(level_path, _get_entered_flag_key()):
			return
		GameState.set_level_flag(level_path, _get_entered_flag_key())
	sanity.add_sanity(first_entry_sanity)


func _get_entered_flag_key() -> String:
	return "sanctuary." + persistent_id


# Scene path of level this was placed in, same rule as InteractableThing:
# topmost owner, so sanctuary inside prefab does not share flag across levels.
func _get_placed_level_path() -> String:
	if not owner:
		return GameState.get_current_level_path()
	var level: Node = owner
	while level.owner:
		level = level.owner
	return level.scene_file_path


# Through api, same as PlayerApi.find_local_player_api, so body can be any player body.
func _get_sanity_component_of_body(body: Node3D) -> SanityComponent:
	var api: PlayerApi = body.get(&"api") as PlayerApi
	if not api or not api.sanity:
		push_error("%s: %s has no SanityComponent, drain not paused" % [name, body.name])
		return null
	return api.sanity
