# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Debug commands for [LimboConsole]. Autoload.
## Player commands go through [PlayerApi] ∴ they work for 2D + 3D player.
## Also checks every .dialogue file on startup for unknown item + quest ids +
## for unclosed option conditions, see [method _check_dialogue_files].
##
## [LimboConsole] silently fails to register bare callable, command name
## must be passed as second argument even when function name matches.
extends Node

## On = [ExplainFeed] shows what dialogue + pickups did, design notes + why
## options are locked. Not saved, off on every start.
var explain: bool = false

# component toggle_sanity_drain paused ∴ same one gets resumed
var _drain_paused_sanity: SanityComponent


func _ready() -> void:
	LimboConsole.register_command(give_item, "give", "Gives an item. Usage: give <item_id> <count>")
	LimboConsole.register_command(
		set_sanity,
		"sanity",
		"Sets the player's sanity. Usage: sanity <value>",
	)
	LimboConsole.register_command(use_item, "use", "Uses a carried item. Usage: use <item_id>")
	LimboConsole.register_command(toggle_explain, "explain", "Toggles explaining what dialogue and pickups did.")
	LimboConsole.register_command(toggle_sanity_drain, "drain", "Toggles sanity drain of the current player.")
	LimboConsole.register_command(set_fact, "fact", "Sets a fact, lists all without one. Usage: fact <key> <value>")
	LimboConsole.register_command(load_level, "level", "Loads a level, lists all without one. Usage: level <number>")
	LimboConsole.register_command(set_time_scale, "timescale", "Sets game speed, 1 is normal. Usage: timescale <value>")
	LimboConsole.register_command(show_save_file, "savefile", "Shows the save file in the file manager.")
	LimboConsole.add_argument_autocomplete_source("give", 0, _get_all_item_ids)
	LimboConsole.add_argument_autocomplete_source("use", 0, _get_all_item_ids)
	# exported builds hold no .dialogue source, only compiled resources
	if OS.has_feature("editor"):
		_check_dialogue_files()


#region Commands
## Gives [param count] of item w/ [param id]. Id is .tres file name,
## same as in .dialogue files, see [method ItemData.load_item_by_id].
func give_item(id: String, count: int = 1) -> void:
	var api: PlayerApi = _get_player_api()
	if not api:
		return
	if api.give_item(id, count):
		LimboConsole.info("+%d %s" % [count, id])
	else:
		LimboConsole.error("could not give %d %s, see the errors above" % [count, id])


## Uses carried item w/ [param id], see [method InventoryComponent.use_inventory_item].
## Only way to use item until there is inventory UI.
func use_item(id: String) -> void:
	var api: PlayerApi = _get_player_api()
	if not api:
		return
	if api.use_item(id):
		LimboConsole.info("used %s" % id)
	else:
		LimboConsole.error("could not use %s, is it carried?" % id)


## Sets sanity meter to [param value], clamped to [member SanityComponent.max_sanity].
func set_sanity(value: float) -> void:
	var api: PlayerApi = _get_player_api()
	if not api:
		return
	if not api.sanity:
		LimboConsole.error("player has no SanityComponent")
		return
	api.sanity.set_current_sanity_value(value)
	LimboConsole.info("sanity %.0f/%.0f" % [api.sanity.value, api.sanity.max_sanity])


## Flips [member explain].
func toggle_explain() -> void:
	explain = not explain
	LimboConsole.info("explain %s" % ("on" if explain else "off"))


## Pauses sanity drain of current player/resumes it when paused by this.
## New player after respawn/level change drains again.
func toggle_sanity_drain() -> void:
	if is_instance_valid(_drain_paused_sanity):
		_drain_paused_sanity.resume_sanity_drain()
		_drain_paused_sanity = null
		LimboConsole.info("sanity drain on")
		return
	var api: PlayerApi = _get_player_api()
	if not api:
		return
	if not api.sanity:
		LimboConsole.error("player has no SanityComponent")
		return
	api.sanity.pause_sanity_drain()
	_drain_paused_sanity = api.sanity
	LimboConsole.info("sanity drain off")


## Sets fact [param key], see [method GameState.set_fact]. Lists every fact w/o key.
## [param value] true, false/whole number is saved as that, anything else as text.
func set_fact(key: String = "", value: String = "true") -> void:
	if not GameState.has_game_state():
		LimboConsole.error("no save data, start from the main menu once")
		return
	if key == "":
		var facts: Dictionary[String, Variant] = GameState.get_or_create_state().facts
		for listed: String in facts:
			LimboConsole.info("%s = %s" % [listed, facts[listed]])
		return
	var parsed: Variant = value
	if value == "true" or value == "false":
		parsed = value == "true"
	elif value.is_valid_int():
		parsed = value.to_int()
	GameState.set_fact(key, parsed)
	LimboConsole.info("%s = %s" % [key, parsed])


## Loads level [param number] from list of [LevelManager], 1 = first. Lists them w/o valid number.
## Number + not name, level file names hold spaces.
func load_level(number: int = 0) -> void:
	var scene: Node = get_tree().current_scene
	var manager: LevelManager = Component.find_descendant_of_type(scene, LevelManager) if scene else null
	if not manager or not manager.scene_lister:
		LimboConsole.error("no LevelManager in this scene, start from the main menu")
		return
	var levels: Array[String] = manager.scene_lister.files
	if number < 1 or number > levels.size():
		for index: int in levels.size():
			LimboConsole.info("%d %s" % [index + 1, levels[index].get_file().get_basename()])
		return
	manager.load_level(levels[number - 1])


## Sets [member Engine.time_scale], below 1 is slow motion.
func set_time_scale(value: float = 1.0) -> void:
	if value <= 0.0:
		LimboConsole.error("timescale must be above 0")
		return
	Engine.time_scale = value
	LimboConsole.info("timescale %s" % value)


## Opens folder of [member GameState.save_path] w/ file selected.
func show_save_file() -> void:
	var path: String = ProjectSettings.globalize_path(GameState.save_path)
	if OS.shell_show_in_file_manager(path) == OK:
		LimboConsole.info(path)
	else:
		LimboConsole.error("could not show %s" % path)
#endregion


# looked up /command, cached one goes stale on respawn/level change
func _get_player_api() -> PlayerApi:
	var api: PlayerApi = PlayerApi.find_local_player_api(get_tree())
	if not api:
		LimboConsole.error("no player in the scene")
	return api


# autocomplete for give + use: every .tres in ItemData.DIR, by id
func _get_all_item_ids() -> Array[String]:
	var ids: Array[String] = []
	# not DirAccess: in export it lists PCK contents, not original file names
	for file: String in ResourceLoader.list_directory(ItemData.DIR):
		if file.get_extension() == "tres":
			ids.append(file.get_basename())
	return ids


#region Dialogue check
# typo in .dialogue id only fails once line is reached ∴ rare branches slip through testing
# reports them all on every editor run, literal ids only (flags + facts have no list)
func _check_dialogue_files() -> void:
	var id_call_pattern: RegEx = RegEx.create_from_string(
		"\\b(give_item|remove_item|has_item|use_item|get_quest_stage|is_quest_done|advance_quest)\\(\\s*\"([^\"]*)\"",
	)
	# option condition must end in " /]", plain "]" compiles but shows as text + is never checked
	var unclosed_condition_pattern: RegEx = RegEx.create_from_string("(?m)^\\s*- .*\\[if [^\\]]*[^/]\\]$")
	for path: String in _find_dialogue_files("res://"):
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in unclosed_condition_pattern.search_all(text):
			Log.error("%s:%d: option condition must end in \" /]\"" % [path, text.count("\n", 0, found.get_start()) + 1])
		for found: RegExMatch in id_call_pattern.search_all(text):
			var id: String = found.get_string(2)
			var directory: String = QuestData.DIR if "quest" in found.get_string(1) else ItemData.DIR
			if ResourceLoader.exists("%s%s.tres" % [directory, id]):
				continue
			var line: int = text.count("\n", 0, found.get_start()) + 1
			Log.error("%s:%d: %s(\"%s\") but %s%s.tres does not exist" % [path, line, found.get_string(1), id, directory, id])


# DirAccess skips hidden folders, addons hold only example dialogue
func _find_dialogue_files(directory: String) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	for folder: String in DirAccess.get_directories_at(directory):
		if folder != "addons":
			files.append_array(_find_dialogue_files(directory.path_join(folder)))
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() == "dialogue":
			files.append(directory.path_join(file))
	return files
#endregion
