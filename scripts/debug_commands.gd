# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Debug commands for [LimboConsole]. Autoload.
## Commands go through [PlayerApi], so they work for the 2D and the 3D player.
##
## [LimboConsole] silently fails to register a bare callable, the command name
## must be passed as the second argument even when the function name matches.
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


#region Commands
## Gives [param count] of the item with [param id]. The id is the .tres file name,
## same as in .dialogue files, see [method ItemData.load_id].
func give_item(id: String, count: int = 1) -> void:
	var api: PlayerApi = _api()
	if not api:
		return
	if api.give_item(id, count):
		LimboConsole.info("+%d %s" % [count, id])
	else:
		LimboConsole.error("could not give %d %s, see the errors above" % [count, id])


## Uses the carried item with [param id], see [method InventoryComponent.use].
## The only way to use an item until there is an inventory UI.
func use_item(id: String) -> void:
	var api: PlayerApi = _api()
	if not api:
		return
	if api.use_item(id):
		LimboConsole.info("used %s" % id)
	else:
		LimboConsole.error("could not use %s, is it carried?" % id)


## Sets the sanity meter to [param value], clamped to [member SanityComponent.max_sanity].
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


# Looked up per command, a cached one goes stale on respawn or level change.
func _api() -> PlayerApi:
	var api: PlayerApi = PlayerApi.find(get_tree())
	if not api:
		LimboConsole.error("no player in the scene")
	return api


# Autocomplete for the give command: every .tres in ItemData.DIR, by id.
func _item_ids() -> Array[String]:
	var ids: Array[String] = []
	# Not DirAccess, in an exported project it lists the PCK contents, not the original file names.
	for file: String in ResourceLoader.list_directory(ItemData.DIR):
		if file.get_extension() == "tres":
			ids.append(file.get_basename())
	return ids
