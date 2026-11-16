# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## One kind of item, saved as .tres in [constant DIR]. Id is file name,
## which is what .dialogue files use: [code]give_item("apple")[/code].
class_name ItemData
extends Resource

const DIR: String = "res://content/items/"

@export var display_name: String = ""
@export_multiline var description: String = ""
## 1 = does not stack.
@export_range(1, 99, 1) var max_stack: int = 1
@export var consumed_on_use: bool = true
## Added to sanity on use. Negative drains.
@export var sanity_restore: float = 0.0
@export_group("Use")
## Shown when item is used outside dialogue.
@export var use_dialogue: DialogueResource
@export var use_dialogue_cue: String = "start"


## Loads item with this id. Pushes error and returns null if it does not exist.
static func load_item_by_id(id: String) -> ItemData:
	var path: String = "%s%s.tres" % [DIR, id]
	if not ResourceLoader.exists(path):
		Log.error("no item '%s', expected %s" % [id, path])
		return null
	return load(path) as ItemData


## Name shown to player, [member display_name] or id when that is empty.
func get_display_label() -> String:
	return display_name if display_name != "" else get_item_id()


## Id .dialogue files and [method PlayerApi.give_item] use: file name without extension.
func get_item_id() -> String:
	return resource_path.get_file().get_basename()
