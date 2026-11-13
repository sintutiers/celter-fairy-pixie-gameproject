# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Debug commands for [LimboConsole]. Autoload.
## Commands go through [PlayerApi], so they work for 2D and 3D player.
## Also checks every .dialogue file for unknown item and quest ids on startup,
## see [method _check_dialogue_ids].
##
## [LimboConsole] silently fails to register bare callable, command name
## must be passed as second argument even when function name matches.
extends Node


func _ready() -> void:
	LimboConsole.register_command(give_item, "give", "Gives an item. Usage: give <item_id> <count>")
	LimboConsole.register_command(
		set_sanity,
		"sanity",
		"Sets the player's sanity. Usage: sanity <value>",
	)
	LimboConsole.register_command(use_item, "use", "Uses a carried item. Usage: use <item_id>")
	LimboConsole.add_argument_autocomplete_source("give", 0, _item_ids)
	LimboConsole.add_argument_autocomplete_source("use", 0, _item_ids)
	# Exported builds hold no .dialogue source, only compiled resources.
	if OS.has_feature("editor"):
		_check_dialogue_ids()


#region Commands
## Gives [param count] of item with [param id]. Id is .tres file name,
## same as in .dialogue files, see [method ItemData.load_id].
func give_item(id: String, count: int = 1) -> void:
	var api: PlayerApi = _api()
	if not api:
		return
	if api.give_item(id, count):
		LimboConsole.info("+%d %s" % [count, id])
	else:
		LimboConsole.error("could not give %d %s, see the errors above" % [count, id])


## Uses carried item with [param id], see [method InventoryComponent.use].
## Only way to use item until there is inventory UI.
func use_item(id: String) -> void:
	var api: PlayerApi = _api()
	if not api:
		return
	if api.use_item(id):
		LimboConsole.info("used %s" % id)
	else:
		LimboConsole.error("could not use %s, is it carried?" % id)


## Sets sanity meter to [param value], clamped to [member SanityComponent.max_sanity].
func set_sanity(value: float) -> void:
	var api: PlayerApi = _api()
	if not api:
		return
	if not api.sanity:
		LimboConsole.error("player has no SanityComponent")
		return
	api.sanity.set_value(value)
	LimboConsole.info("sanity %.0f/%.0f" % [api.sanity.value, api.sanity.max_sanity])
#endregion


# Looked up per command, cached one goes stale on respawn or level change.
func _api() -> PlayerApi:
	var api: PlayerApi = PlayerApi.find(get_tree())
	if not api:
		LimboConsole.error("no player in the scene")
	return api


# Autocomplete for give and use: every .tres in ItemData.DIR, by id.
func _item_ids() -> Array[String]:
	var ids: Array[String] = []
	# Not DirAccess, in exported project it lists PCK contents, not original file names.
	for file: String in ResourceLoader.list_directory(ItemData.DIR):
		if file.get_extension() == "tres":
			ids.append(file.get_basename())
	return ids


#region Dialogue check
# Typo in .dialogue id only fails when that line is reached in play, which for
# rare branch is never during testing. This reports them all on every run from editor.
# Only literal ids are seen. Flags and facts have no list to check against.
func _check_dialogue_ids() -> void:
	var calls: RegEx = RegEx.create_from_string(
		"\\b(give_item|remove_item|has_item|use_item|quest_stage|quest_done|advance_quest)\\(\\s*\"([^\"]*)\"",
	)
	for path: String in _dialogue_files("res://"):
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in calls.search_all(text):
			var id: String = found.get_string(2)
			var directory: String = QuestData.DIR if "quest" in found.get_string(1) else ItemData.DIR
			if ResourceLoader.exists("%s%s.tres" % [directory, id]):
				continue
			var line: int = text.count("\n", 0, found.get_start()) + 1
			push_error("%s:%d: %s(\"%s\") but %s%s.tres does not exist" % [path, line, found.get_string(1), id, directory, id])


# Hidden folders are skipped by DirAccess, addons hold only example dialogue.
func _dialogue_files(directory: String) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	for folder: String in DirAccess.get_directories_at(directory):
		if folder != "addons":
			files.append_array(_dialogue_files(directory.path_join(folder)))
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() == "dialogue":
			files.append(directory.path_join(file))
	return files
#endregion
