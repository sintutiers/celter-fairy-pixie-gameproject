# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Saved game data, accessed through static helpers.
## Changing what saved data means (renamed fact key, reordered quest stages, new key format)
## needs bump of [constant SAVE_VERSION] and step in [method _migrate], or old saves break.
class_name GameState
extends Resource

const STATE_NAME: String = "GameState"
const FILE_PATH = "res://scripts/game_state.gd"
## Version this game writes. Older saves are migrated on load.
const SAVE_VERSION: int = 1

## 0 = save from before versions existed.
@export var save_version: int = 0
## Level scene uid to [LevelState].
@export var level_states: Dictionary[String, LevelState] = { }
## Carried items, item id to count. Written by [InventoryComponent].
@export var inventory: Dictionary[String, int] = { }
## Negative = never saved. Written by [SanityComponent].
@export var sanity: float = -1.0
## Story state that outlives level, see [method get_fact].
@export var facts: Dictionary[String, Variant] = { }
@export var current_level_path: String
@export var checkpoint_level_path: String
@export var total_games_played: int
@export var play_time: int
@export var total_time: int


## Returns saved [LevelState] for level scene path or uid, or null without game state.
## Level seen for first time gets state created and saved, so read can write.
static func get_level_state(level_state_key: String) -> LevelState:
	level_state_key = _level_key(level_state_key)
	if not has_game_state():
		return
	var game_state := get_or_create_state()
	if level_state_key.is_empty():
		return
	if level_state_key in game_state.level_states:
		return game_state.level_states[level_state_key]
	else:
		var new_level_state := LevelState.new()
		game_state.level_states[level_state_key] = new_level_state
		GlobalState.save()
		return new_level_state


## False until something called [method get_or_create_state], as in scene run
## straight from editor. Getters then return defaults and nothing is saved.
static func has_game_state() -> bool:
	return GlobalState.has_state(STATE_NAME)


## Every access goes through here, so this is where old saves get migrated.
static func get_or_create_state() -> GameState:
	var game_state: GameState = GlobalState.get_or_create_state(STATE_NAME, FILE_PATH)
	if game_state.save_version != SAVE_VERSION:
		_migrate(game_state)
	return game_state


## Level being played, empty without game state.
static func get_current_level_path() -> String:
	if not has_game_state():
		return ""
	var game_state := get_or_create_state()
	return game_state.current_level_path


## Level that [method continue_game] goes back to, empty without game state.
static func get_checkpoint_level_path() -> String:
	if not has_game_state():
		return ""
	var game_state := get_or_create_state()
	return game_state.checkpoint_level_path


## Number of levels that have saved [LevelState].
static func get_levels_reached() -> int:
	if not has_game_state():
		return 0
	var game_state := get_or_create_state()
	return game_state.level_states.size()


## Saves immediately. Also creates [LevelState] of that level when new.
static func set_checkpoint_level_path(level_path: String) -> void:
	var game_state := get_or_create_state()
	game_state.checkpoint_level_path = level_path
	get_level_state(level_path)
	GlobalState.save()


## Saves immediately.
static func set_current_level_path(level_path: String) -> void:
	var game_state := get_or_create_state()
	game_state.current_level_path = level_path
	GlobalState.save()


## Counts one more game in [member total_games_played]. Progress is kept, see [method reset].
static func start_game() -> void:
	var game_state := get_or_create_state()
	game_state.total_games_played += 1
	GlobalState.save()


## Makes checkpoint level current one and saves.
static func continue_game() -> void:
	var game_state := get_or_create_state()
	game_state.current_level_path = game_state.checkpoint_level_path
	GlobalState.save()


## Wipes level progress, facts, inventory, sanity and play time.
## [member total_games_played] is kept.
static func reset() -> void:
	var game_state := get_or_create_state()
	game_state.level_states.clear()
	game_state.facts.clear()
	game_state.inventory.clear()
	game_state.sanity = -1.0
	game_state.current_level_path = ""
	game_state.checkpoint_level_path = ""
	game_state.play_time = 0
	game_state.total_time = 0
	GlobalState.save()


## True if [param flag] was set in that level. Unknown level or flag = false.
## Used for "this pickup is already taken" persistence, see [member InteractableThing.persistent_id].
static func get_level_flag(level_path: String, flag: String) -> bool:
	var level_state := get_level_state(level_path)
	return level_state != null and level_state.flags.get(flag, false)


## Saves immediately. Warns and saves nothing if level has no state.
static func set_level_flag(level_path: String, flag: String, value: bool = true) -> void:
	var level_state := get_level_state(level_path)
	if not level_state:
		push_warning("no level state for '%s', flag '%s' not saved" % [level_path, flag])
		return
	level_state.flags[flag] = value
	GlobalState.save()


## Returns fact, or [param default] when unset or without game state.
## Facts are global, for state that crosses levels: choices, opinions, quest stages.
## Per-level state (taken pickups) stays in [method get_level_flag].
## Keys use prefix per writer: [code]"choice."[/code], [code]"opinion."[/code], [code]"quest."[/code].
static func get_fact(key: String, default: Variant = false) -> Variant:
	if not has_game_state():
		return default
	return get_or_create_state().facts.get(key, default)


## Saves immediately. Warns and saves nothing without game state.
## [b]Warning:[/b] Renaming key breaks saves that already hold it.
static func set_fact(key: String, value: Variant = true) -> void:
	if not has_game_state():
		push_warning("no game state, fact '%s' not saved" % key)
		return
	get_or_create_state().facts[key] = value
	GlobalState.save()


# Uid survives renaming or moving level scene, path does not.
# Scene without uid keeps its path as key.
static func _level_key(level_path: String) -> String:
	if level_path.is_empty() or level_path.begins_with("uid://"):
		return level_path
	return ResourceUID.path_to_uid(level_path)


# One step per version, in order, each lifts save by one.
# Never edit old step: saves already out there were written by it.
static func _migrate(game_state: GameState) -> void:
	if game_state.save_version > SAVE_VERSION:
		push_error(
			"save is version %d, this game only knows %d. Loaded as is, expect missing progress."
			% [game_state.save_version, SAVE_VERSION],
		)
	# 0 to 1: level states were keyed by scene path.
	if game_state.save_version < 1:
		var by_uid: Dictionary[String, LevelState] = { }
		for level_path: String in game_state.level_states:
			by_uid[_level_key(level_path)] = game_state.level_states[level_path]
		game_state.level_states = by_uid
	game_state.save_version = SAVE_VERSION
	GlobalState.save()
