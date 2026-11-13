# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## One quest or favor, saved as a .tres in [constant DIR]. The id is the file name,
## which is what .dialogue files use: [code]advance_quest("help_cassie")[/code].
## Holds no progress, that is the fact [code]"quest.<id>"[/code], see [method PlayerApi.quest_stage].
## Rewards are given by the dialogue that advances the quest, it can react to a full inventory.
class_name QuestData
extends Resource

const DIR: String = "res://scenes/quests/"

@export var title: String = ""
## Journal text per stage, index = stage. A stage equal to the size means done.
## [b]Warning:[/b] Inserting or removing a stage shifts the meaning of saved stages.
@export var stages: PackedStringArray = PackedStringArray()


## Loads the quest with this id. Pushes an error and returns null if it does not exist.
static func load_id(id: String) -> QuestData:
	var path: String = "%s%s.tres" % [DIR, id]
	if not ResourceLoader.exists(path):
		push_error("no quest '%s', expected %s" % [id, path])
		return null
	return load(path) as QuestData
