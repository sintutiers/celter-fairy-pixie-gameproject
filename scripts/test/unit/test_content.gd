# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Runs content checks of [code]DebugCommands[/code] as tests. They also run on every editor start,
## but only print there ∴ here broken .dialogue + .tres fail CI.
## Each problem is own error above failed assert, w/ file + line.
extends GutTest


#region Tests
func test_dialogue_files_have_known_ids_closed_conditions_and_prefixed_facts() -> void:
	assert_eq(DebugCommands.check_dialogue_files(), 0, "problems in .dialogue files, see errors")


func test_item_and_quest_files_are_valid() -> void:
	assert_eq(DebugCommands.check_content_files(), 0, "problems in item/quest .tres, see errors")
#endregion
