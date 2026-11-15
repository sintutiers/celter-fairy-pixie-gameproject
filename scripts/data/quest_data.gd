# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## One quest or favor, saved as .tres in [constant DIR]. Id is file name,
## which is what .dialogue files use: [code]advance_quest("help_cassie")[/code].
## Holds no progress, that is fact [code]"quest.<id>"[/code], see [method PlayerApi.get_quest_stage].
## Rewards are given by dialogue that advances quest, it can react to full inventory.
class_name QuestData
extends Resource

const DIR: String = "res://content/quests/"

@export var title: String = ""
## Journal text per stage, index = stage. Stage equal to size means done.
## [b]Warning:[/b] Inserting or removing stage shifts meaning of saved stages.
@export var stages: PackedStringArray = PackedStringArray()


## Loads quest with this id. Pushes error and returns null if it does not exist.
static func load_quest_by_id(id: String) -> QuestData:
	var path: String = "%s%s.tres" % [DIR, id]
	if not ResourceLoader.exists(path):
		Log.error("no quest '%s', expected %s" % [id, path])
		return null
	return load(path) as QuestData
