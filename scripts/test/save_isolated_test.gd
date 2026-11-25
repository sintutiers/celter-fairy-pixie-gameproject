# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Base for tests that read/write save: points [member GameState.save_path] at
## [constant TEST_SAVE_PATH] ∴ real save is never touched. Every test starts w/ ∅ save file
## + ∅ state in memory, [method GameState.start_game] gives it game state.
## Subclass overriding a hook calls [code]super()[/code] first.
class_name SaveIsolatedTest
extends GutTest

## Own save file, deleted before each test + after last one.
const TEST_SAVE_PATH: String = "user://test_save.json"

var _original_save_path: String


#region Setup/Teardown
func before_all() -> void:
	_original_save_path = GameState.save_path
	GameState.save_path = TEST_SAVE_PATH


func before_each() -> void:
	_delete_test_save_files()
	GameState.unload()


func after_all() -> void:
	_delete_test_save_files()
	GameState.save_path = _original_save_path
	GameState.unload()
#endregion


#region Helpers
# also files GameState writes beside save: tmp while writing, backup on import, broken on bad JSON
func _delete_test_save_files() -> void:
	for suffix: String in ["", ".tmp", ".backup", ".broken"]:
		var path: String = TEST_SAVE_PATH + suffix
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			fail_test("could not delete %s, next test may see it" % path)
#endregion
