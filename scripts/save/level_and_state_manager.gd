# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [LevelManager] that mirrors level paths into [GameState] ∴ they are saved.
## Saved checkpoint wins over one in manager when set.
class_name LevelAndStateManager
extends LevelManager


## Also saves [param value] as current level in [GameState].
func set_current_level_path(value: String) -> void:
	super.set_current_level_path(value)
	GameState.set_current_level_path(value)


## Also saves [param value] as checkpoint in [GameState].
func set_checkpoint_level_path(value: String) -> void:
	super.set_checkpoint_level_path(value)
	GameState.set_checkpoint_level_path(value)


## Checkpoint saved in [GameState], one in manager when ∅ is saved.
func get_checkpoint_level_path() -> String:
	var state_level_path: String = GameState.get_checkpoint_level_path()
	if not state_level_path.is_empty():
		return state_level_path
	return super.get_checkpoint_level_path()
