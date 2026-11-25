# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Saved game data, accessed through static helpers.
## One save, held in memory + written as JSON to [member save_path] by [method save].
## New field needs default here + line in [method to_dictionary] + [method from_dictionary].
## Changing what saved data means (renamed fact key, reordered quest stages, new key format)
## needs bump of [constant SAVE_VERSION] + step in [method _migrate_save_to_current_version], else old saves break.
class_name GameState
extends RefCounted

## Version this game writes. Older saves are migrated on load.
const SAVE_VERSION: int = 2

## Extra instance for multiplayer testing passes [code]--save=<name>[/code] after
## [code]--[/code] + gets its own file ∵ all editor instances share user://.
static var save_path: String = _get_save_path()

static var _current: GameState

## Level scene uid to [LevelState].
var level_states: Dictionary[String, LevelState] = { }
## Carried items, item id to count. Written by [InventoryComponent].
var inventory: Dictionary[String, int] = { }
## False until [SanityComponent] first mirrored [member sanity], see [method get_saved_sanity].
var has_sanity: bool = false
var sanity: float = 0.0
## Story state that outlives level, see [method get_fact].
var facts: Dictionary[String, Variant] = { }
var current_level_path: String
var checkpoint_level_path: String
var total_games_played: int
var play_time: int
var total_time: int


## Returns saved [LevelState] for level scene path/uid, null for level never reached/w/o game state.
## Only reads, see [method get_or_create_level_state].
static func get_level_state(level_path: String) -> LevelState:
	if not has_game_state():
		return null
	var level_states: Dictionary[String, LevelState] = get_or_create_state().level_states
	return level_states.get(_get_level_state_key(level_path), null)


## Like [method get_level_state], but level seen for first time gets state created + saved.
## That is what counts it in [method get_levels_reached]. Null w/o game state.
## Returned state is live: field changed on it is written by next [method save].
static func get_or_create_level_state(level_path: String) -> LevelState:
	var level_state_key: String = _get_level_state_key(level_path)
	if not has_game_state() or level_state_key.is_empty():
		return null
	var game_state: GameState = get_or_create_state()
	if level_state_key in game_state.level_states:
		return game_state.level_states[level_state_key]
	var new_level_state: LevelState = LevelState.new()
	game_state.level_states[level_state_key] = new_level_state
	save()
	return new_level_state


## False until save file exists, as w/ scene run straight from editor before
## game was ever started from main menu. Getters > return defaults + ∅ is saved.
static func has_game_state() -> bool:
	return _current != null or FileAccess.file_exists(save_path)


## Every access goes through here. First call loads save file/creates it.
static func get_or_create_state() -> GameState:
	if _current:
		return _current
	_current = from_dictionary(_read_save_file() if FileAccess.file_exists(save_path) else { })
	# also writes back migrated save
	save()
	return _current


## Drops state held in memory ∴ next access reads [member save_path] again, as on game start.
## Changes since last [method save] are lost. For tests, game never needs it.
static func unload() -> void:
	_current = null


## Writes whole state to [member save_path]. Does ∅ before [method get_or_create_state].
static func save() -> void:
	if not _current:
		return
	# written beside save > moved over it ∴ crash mid write keeps old save
	var temporary_path: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if not file:
		Log.error("cannot open %s: %s" % [temporary_path, error_string(FileAccess.get_open_error())])
		return
	if not file.store_string(JSON.stringify(_current.to_dictionary(), "\t")):
		Log.error("cannot write %s: %s" % [temporary_path, error_string(file.get_error())])
		return
	file.close()
	var error: Error = DirAccess.rename_absolute(temporary_path, save_path)
	if error != OK:
		Log.error("cannot replace %s: %s" % [save_path, error_string(error)])


## Copies save file to [param path], for backup/bug report.
static func export_save(path: String) -> Error:
	save()
	return DirAccess.copy_absolute(save_path, path)


## Replaces save w/ file at [param path], which may be older version. Old save is kept as .backup.
## Returns false, warns + changes ∅ when file ≠ save.
## Nodes still hold old values ∴ caller must reload scene.
static func import_save(path: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		Log.warn("%s is not JSON object, import stopped" % path)
		return false
	var data: Dictionary = parsed
	if not data.has("save_version"):
		Log.warn("%s has no save_version, import stopped" % path)
		return false
	if FileAccess.file_exists(save_path) and DirAccess.copy_absolute(save_path, save_path + ".backup") != OK:
		Log.error("could not back up %s, import stopped" % save_path)
		return false
	_migrate_save_to_current_version(data)
	_current = from_dictionary(data)
	save()
	return true


## Level being played, ∅ w/o game state.
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


## Level that [method continue_game] goes back to, ∅ w/o game state.
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
	get_or_create_level_state(level_path)
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


## Makes checkpoint level current one + saves.
static func continue_game() -> void:
	var game_state: GameState = get_or_create_state()
	game_state.current_level_path = game_state.checkpoint_level_path
	save()


## Saved sanity, [param default] when never saved/w/o game state.
static func get_saved_sanity(default: float) -> float:
	if not has_game_state():
		return default
	var game_state: GameState = get_or_create_state()
	return game_state.sanity if game_state.has_sanity else default


## Copies [param value] into save w/o writing file, ∅ w/o game state.
## Sanity changes every physics frame ∴ file gets it on next [method save].
static func mirror_sanity(value: float) -> void:
	if not has_game_state():
		return
	var game_state: GameState = get_or_create_state()
	game_state.sanity = value
	game_state.has_sanity = true


## Wipes level progress, facts, inventory, sanity + play time.
## [member total_games_played] is kept.
static func reset() -> void:
	var game_state: GameState = get_or_create_state()
	game_state.level_states.clear()
	game_state.facts.clear()
	game_state.inventory.clear()
	game_state.has_sanity = false
	game_state.sanity = 0.0
	game_state.current_level_path = ""
	game_state.checkpoint_level_path = ""
	game_state.play_time = 0
	game_state.total_time = 0
	save()


## True if [param flag] was set in that level. Unknown level/flag = false.
## Used for "this pickup is already taken" persistence, see [member InteractableThing.persistent_id].
static func get_level_flag(level_path: String, flag: String) -> bool:
	var level_state: LevelState = get_level_state(level_path)
	return level_state != null and level_state.flags.get(flag, false)


## Saves immediately. Warns + saves ∅ if level has no state.
static func set_level_flag(level_path: String, flag: String, value: bool = true) -> void:
	var level_state: LevelState = get_or_create_level_state(level_path)
	if not level_state:
		Log.warn("no level state for '%s', flag '%s' not saved" % [level_path, flag])
		return
	level_state.flags[flag] = value
	save()


## Returns fact, [param default] when unset/w/o game state.
## Facts are global, for state that crosses levels: choices, opinions, quest stages.
## Per-level state (taken pickups) stays in [method get_level_flag].
## Keys use prefix /writer: [code]"choice."[/code], [code]"opinion."[/code], [code]"quest."[/code].
static func get_fact(key: String, default: Variant = false) -> Variant:
	if not has_game_state():
		return default
	return get_or_create_state().facts.get(key, default)


## Copy of every fact, empty w/o game state. Changing it changes ∅, see [method set_fact].
static func get_all_facts() -> Dictionary[String, Variant]:
	if not has_game_state():
		return { }
	return get_or_create_state().facts.duplicate()


## Saves immediately. Warns + saves ∅ w/o game state.
## [param value] must be bool, int, float/String: Array/Dictionary from [method get_fact]
## would be live + could change w/o save.
## ⚠ Renaming key breaks saves that already hold it.
static func set_fact(key: String, value: Variant = true) -> void:
	if typeof(value) not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		Log.error("fact '%s' must be bool, int, float or String, got %s" % [key, type_string(typeof(value))])
		return
	if not has_game_state():
		Log.warn("no game state, fact '%s' not saved" % key)
		return
	get_or_create_state().facts[key] = value
	save()


# uid survives renaming/moving level scene, path doesnt
# scene w/o uid keeps its path as key
static func _get_level_state_key(level_path: String) -> String:
	if level_path.is_empty() or level_path.begins_with("uid://"):
		return level_path
	return ResourceUID.path_to_uid(level_path)


static func _get_save_path() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			return "user://save_%s.json" % argument.trim_prefix("--save=")
	return "user://save.json"


# ∅ for file that ≠ JSON object, kept as .broken since next save would overwrite it
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


# one step /version, in order, each lifts save by one
# steps change plain file data before it becomes GameState ∴ they dont depend on current class
# never edit old step: saves already out there were written by it
static func _migrate_save_to_current_version(data: Dictionary) -> void:
	var version: int = data.get("save_version", SAVE_VERSION)
	if version > SAVE_VERSION:
		Log.error(
			"save is version %d, this game only knows %d. Loaded as is, expect missing progress."
			% [version, SAVE_VERSION],
		)
	if version < 2:
		# v1 wrote -1.0 for never saved sanity, v2 leaves key out
		var saved_sanity: float = data.get("sanity", 0.0)
		if saved_sanity < 0.0:
			data.erase("sanity")


# JSON has one number type ∴ 3 reads back as 3.0, counts + quest stages must stay int
static func _convert_whole_number_to_int(value: Variant) -> Variant:
	if value is float:
		var number: float = value
		if number == floorf(number):
			return int(number)
	return value


## Plain data for save file, read back by [method from_dictionary].
func to_dictionary() -> Dictionary:
	var saved_levels: Dictionary[String, Dictionary] = { }
	for key: String in level_states:
		saved_levels[key] = level_states[key].to_dictionary()
	var data: Dictionary = {
		"save_version": SAVE_VERSION,
		"current_level_path": current_level_path,
		"checkpoint_level_path": checkpoint_level_path,
		"total_games_played": total_games_played,
		"play_time": play_time,
		"total_time": total_time,
		"inventory": inventory,
		"facts": facts,
		"level_states": saved_levels,
	}
	if has_sanity:
		data["sanity"] = sanity
	return data


## Reads what [method to_dictionary] wrote, after [method _migrate_save_to_current_version].
## Missing key keeps default ∴ new field needs no migration step.
static func from_dictionary(data: Dictionary) -> GameState:
	var game_state: GameState = GameState.new()
	game_state.current_level_path = data.get("current_level_path", "")
	game_state.checkpoint_level_path = data.get("checkpoint_level_path", "")
	game_state.total_games_played = data.get("total_games_played", 0)
	game_state.play_time = data.get("play_time", 0)
	game_state.total_time = data.get("total_time", 0)
	game_state.has_sanity = data.has("sanity")
	game_state.sanity = data.get("sanity", 0.0)
	var saved_inventory: Dictionary = data.get("inventory", { })
	for id: String in saved_inventory:
		var count: int = saved_inventory[id]
		game_state.inventory[id] = count
	var saved_facts: Dictionary = data.get("facts", { })
	for key: String in saved_facts:
		game_state.facts[key] = _convert_whole_number_to_int(saved_facts[key])
	var saved_levels: Dictionary = data.get("level_states", { })
	for key: String in saved_levels:
		var saved_level: Dictionary = saved_levels[key]
		game_state.level_states[key] = LevelState.from_dictionary(saved_level)
	return game_state
