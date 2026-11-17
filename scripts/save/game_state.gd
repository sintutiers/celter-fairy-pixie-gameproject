# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Saved game data, accessed through static helpers.
## One save, held in memory and written as JSON to [member save_path] by [method save].
## New field needs default here plus line in [method _to_dictionary] and [method _apply_dictionary].
## Changing what saved data means (renamed fact key, reordered quest stages, new key format)
## needs bump of [constant SAVE_VERSION] and step in [method _migrate_save_to_current_version], or old saves break.
class_name GameState
extends RefCounted

## Version this game writes. Older saves are migrated on load.
const SAVE_VERSION: int = 1

## Extra instance for multiplayer testing passes [code]--save=<name>[/code] after
## [code]--[/code] and gets its own file, because all editor instances share user://.
static var save_path: String = _get_save_path()

static var _current: GameState

## Level scene uid to [LevelState].
var level_states: Dictionary[String, LevelState] = { }
## Carried items, item id to count. Written by [InventoryComponent].
var inventory: Dictionary[String, int] = { }
## Negative = never saved. Written by [SanityComponent].
var sanity: float = -1.0
## Story state that outlives level, see [method get_fact].
var facts: Dictionary[String, Variant] = { }
var current_level_path: String
var checkpoint_level_path: String
var total_games_played: int
var play_time: int
var total_time: int


## Returns saved [LevelState] for level scene path or uid, or null without game state.
## Level seen for first time gets state created and saved, so read can write.
static func get_level_state(level_state_key: String) -> LevelState:
	level_state_key = _get_level_state_key(level_state_key)
	if not has_game_state():
		return
	var game_state: GameState = get_or_create_state()
	if level_state_key.is_empty():
		return
	if level_state_key in game_state.level_states:
		return game_state.level_states[level_state_key]
	else:
		var new_level_state: LevelState = LevelState.new()
		game_state.level_states[level_state_key] = new_level_state
		save()
		return new_level_state


## False until save file exists, as with scene run straight from editor before
## game was ever started from main menu. Getters then return defaults and nothing is saved.
static func has_game_state() -> bool:
	return _current != null or FileAccess.file_exists(save_path)


## Every access goes through here. First call loads save file, or creates it.
static func get_or_create_state() -> GameState:
	if _current:
		return _current
	_current = GameState.new()
	if FileAccess.file_exists(save_path):
		_current._apply_dictionary(_read_save_file())
	# Also writes back migrated save.
	save()
	return _current


## Writes whole state to [member save_path]. Does nothing before [method get_or_create_state].
static func save() -> void:
	if not _current:
		return
	# Written beside save and then moved over it, so crash mid write keeps old save.
	var temporary_path: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if not file:
		Log.error("cannot open %s: %s" % [temporary_path, error_string(FileAccess.get_open_error())])
		return
	if not file.store_string(JSON.stringify(_current._to_dictionary(), "\t")):
		Log.error("cannot write %s: %s" % [temporary_path, error_string(file.get_error())])
		return
	file.close()
	var error: Error = DirAccess.rename_absolute(temporary_path, save_path)
	if error != OK:
		Log.error("cannot replace %s: %s" % [save_path, error_string(error)])


## Copies save file to [param path], for backup or bug report.
static func export_save(path: String) -> Error:
	save()
	return DirAccess.copy_absolute(save_path, path)


## Replaces save with file at [param path], which may be older version. Old save is kept as .backup.
## Returns false and changes nothing when file is not save.
## Nodes still hold old values, so caller must reload scene.
static func import_save(path: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		return false
	var data: Dictionary = parsed
	if not data.has("save_version"):
		return false
	if FileAccess.file_exists(save_path) and DirAccess.copy_absolute(save_path, save_path + ".backup") != OK:
		Log.error("could not back up %s, import stopped" % save_path)
		return false
	_migrate_save_to_current_version(data)
	_current = GameState.new()
	_current._apply_dictionary(data)
	save()
	return true


## Level being played, empty without game state.
static func get_current_level_path() -> String:
	if not has_game_state():
		return ""
	var game_state: GameState = get_or_create_state()
	return game_state.current_level_path


## Scene path of level [param node] was placed in. Topmost owner, not direct one:
## inside instanced prefab direct owner is prefab root, which would share level flags
## across every level. Node added from code (no owner) gets current level.
static func get_placed_level_path(node: Node) -> String:
	if not node.owner:
		return get_current_level_path()
	var level: Node = node.owner
	while level.owner:
		level = level.owner
	return level.scene_file_path


## Level that [method continue_game] goes back to, empty without game state.
static func get_checkpoint_level_path() -> String:
	if not has_game_state():
		return ""
	var game_state: GameState = get_or_create_state()
	return game_state.checkpoint_level_path


## Number of levels that have saved [LevelState].
static func get_levels_reached() -> int:
	if not has_game_state():
		return 0
	var game_state: GameState = get_or_create_state()
	return game_state.level_states.size()


## Saves immediately. Also creates [LevelState] of that level when new.
static func set_checkpoint_level_path(level_path: String) -> void:
	var game_state: GameState = get_or_create_state()
	game_state.checkpoint_level_path = level_path
	get_level_state(level_path)
	save()


## Saves immediately.
static func set_current_level_path(level_path: String) -> void:
	var game_state: GameState = get_or_create_state()
	game_state.current_level_path = level_path
	save()


## Counts one more game in [member total_games_played]. Progress is kept, see [method reset].
static func start_game() -> void:
	var game_state: GameState = get_or_create_state()
	game_state.total_games_played += 1
	save()


## Makes checkpoint level current one and saves.
static func continue_game() -> void:
	var game_state: GameState = get_or_create_state()
	game_state.current_level_path = game_state.checkpoint_level_path
	save()


## Wipes level progress, facts, inventory, sanity and play time.
## [member total_games_played] is kept.
static func reset() -> void:
	var game_state: GameState = get_or_create_state()
	game_state.level_states.clear()
	game_state.facts.clear()
	game_state.inventory.clear()
	game_state.sanity = -1.0
	game_state.current_level_path = ""
	game_state.checkpoint_level_path = ""
	game_state.play_time = 0
	game_state.total_time = 0
	save()


## True if [param flag] was set in that level. Unknown level or flag = false.
## Used for "this pickup is already taken" persistence, see [member InteractableThing.persistent_id].
static func get_level_flag(level_path: String, flag: String) -> bool:
	var level_state: LevelState = get_level_state(level_path)
	return level_state != null and level_state.flags.get(flag, false)


## Saves immediately. Warns and saves nothing if level has no state.
static func set_level_flag(level_path: String, flag: String, value: bool = true) -> void:
	var level_state: LevelState = get_level_state(level_path)
	if not level_state:
		Log.warn("no level state for '%s', flag '%s' not saved" % [level_path, flag])
		return
	level_state.flags[flag] = value
	save()


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
		Log.warn("no game state, fact '%s' not saved" % key)
		return
	get_or_create_state().facts[key] = value
	save()


# Uid survives renaming or moving level scene, path does not.
# Scene without uid keeps its path as key.
static func _get_level_state_key(level_path: String) -> String:
	if level_path.is_empty() or level_path.begins_with("uid://"):
		return level_path
	return ResourceUID.path_to_uid(level_path)


static func _get_save_path() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			return "user://save_%s.json" % argument.trim_prefix("--save=")
	return "user://save.json"


# Empty for file that is not JSON object. That file is kept as .broken, next save would overwrite it.
static func _read_save_file() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is not Dictionary:
		var broken_path: String = save_path + ".broken"
		Log.error("%s is not valid save, starting fresh. Old file kept as %s" % [save_path, broken_path])
		if DirAccess.rename_absolute(save_path, broken_path) != OK:
			Log.error("could not keep %s" % broken_path)
		return { }
	var data: Dictionary = parsed
	_migrate_save_to_current_version(data)
	return data


# One step per version, in order, each lifts save by one. Steps change plain data
# from file, before it becomes GameState, so they do not depend on how class looks now.
# Never edit old step: saves already out there were written by it.
static func _migrate_save_to_current_version(data: Dictionary) -> void:
	var version: int = data.get("save_version", SAVE_VERSION)
	if version > SAVE_VERSION:
		Log.error(
			"save is version %d, this game only knows %d. Loaded as is, expect missing progress."
			% [version, SAVE_VERSION],
		)
	# No steps yet. First one starts with "if version < 2:" and renames or rebuilds keys in data.


# JSON has one number type, so 3 is read back as 3.0. Counts and quest stages must stay int.
static func _convert_whole_number_to_int(value: Variant) -> Variant:
	if value is float:
		var number: float = value
		if number == floorf(number):
			return int(number)
	return value


func _to_dictionary() -> Dictionary:
	var saved_levels: Dictionary[String, Dictionary] = { }
	for key: String in level_states:
		saved_levels[key] = level_states[key].to_dictionary()
	return {
		"save_version": SAVE_VERSION,
		"current_level_path": current_level_path,
		"checkpoint_level_path": checkpoint_level_path,
		"total_games_played": total_games_played,
		"play_time": play_time,
		"total_time": total_time,
		"sanity": sanity,
		"inventory": inventory,
		"facts": facts,
		"level_states": saved_levels,
	}


# Missing key keeps default, so new field needs no migration step.
func _apply_dictionary(data: Dictionary) -> void:
	current_level_path = data.get("current_level_path", "")
	checkpoint_level_path = data.get("checkpoint_level_path", "")
	total_games_played = data.get("total_games_played", 0)
	play_time = data.get("play_time", 0)
	total_time = data.get("total_time", 0)
	sanity = data.get("sanity", -1.0)
	var saved_inventory: Dictionary = data.get("inventory", { })
	for id: String in saved_inventory:
		var count: int = saved_inventory[id]
		inventory[id] = count
	var saved_facts: Dictionary = data.get("facts", { })
	for key: String in saved_facts:
		facts[key] = _convert_whole_number_to_int(saved_facts[key])
	var saved_levels: Dictionary = data.get("level_states", { })
	for key: String in saved_levels:
		var saved_level: Dictionary = saved_levels[key]
		level_states[key] = LevelState.from_dictionary(saved_level)
