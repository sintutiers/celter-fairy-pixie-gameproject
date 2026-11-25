# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Save round trip + migration of old saves, see [GameState].
## Runs on own save file ∴ real save is never touched.
## Old save layout gets fixture in res://test/fixtures/ when [constant GameState.SAVE_VERSION] is bumped.
extends GutTest

const TEST_SAVE_PATH: String = "user://test_save.json"
const SAVE_V1_FIXTURE_PATH: String = "res://test/fixtures/save_v1.json"
# uid:// key is used as is ∴ needs no real level scene
const LEVEL_PATH: String = "uid://test_level"

var _original_save_path: String


#region Setup/Teardown
func before_all() -> void:
	_original_save_path = GameState.save_path
	GameState.save_path = TEST_SAVE_PATH


func before_each() -> void:
	_delete_test_save_files()
	GameState.unload()


func after_each() -> void:
	_delete_test_save_files()
	GameState.unload()


func after_all() -> void:
	GameState.save_path = _original_save_path
	GameState.unload()
#endregion


#region Round trip
func test_saved_state_reads_back_after_restart() -> void:
	GameState.start_game()
	GameState.set_current_level_path(LEVEL_PATH)
	GameState.set_checkpoint_level_path(LEVEL_PATH)
	GameState.set_level_flag(LEVEL_PATH, "thing.box_01")
	GameState.set_fact("choice.helped_teto", true)
	GameState.set_fact("quest.find_key", 2)
	GameState.set_fact("opinion.teto", 0.5)
	GameState.set_fact("name.pixie", "Pip")
	GameState.get_or_create_state().inventory["key.rusty"] = 3
	GameState.mirror_sanity(42.5)
	GameState.save()

	GameState.unload()

	assert_eq(GameState.get_or_create_state().total_games_played, 1)
	assert_eq(GameState.get_current_level_path(), LEVEL_PATH)
	assert_eq(GameState.get_checkpoint_level_path(), LEVEL_PATH)
	assert_eq(GameState.get_levels_reached(), 1)
	assert_true(GameState.get_level_flag(LEVEL_PATH, "thing.box_01"))
	assert_eq(GameState.get_fact("choice.helped_teto"), true)
	assert_eq(GameState.get_fact("opinion.teto"), 0.5)
	assert_eq(GameState.get_fact("name.pixie"), "Pip")
	assert_eq(GameState.get_or_create_state().inventory.get("key.rusty"), 3)
	assert_eq(GameState.get_saved_sanity(100.0), 42.5)


# JSON has one number type, quest stage 2 must not come back as 2.0
func test_int_fact_stays_int() -> void:
	GameState.start_game()
	GameState.set_fact("quest.find_key", 2)
	GameState.unload()
	assert_typeof(GameState.get_fact("quest.find_key"), TYPE_INT)


# ⚠ known side effect of _convert_whole_number_to_int, float fact w/o fraction comes back as int
func test_whole_float_fact_comes_back_as_int() -> void:
	GameState.start_game()
	GameState.set_fact("opinion.teto", 1.0)
	GameState.unload()
	assert_typeof(GameState.get_fact("opinion.teto"), TYPE_INT)


func test_never_mirrored_sanity_is_left_out() -> void:
	GameState.start_game()
	GameState.unload()
	assert_eq(GameState.get_saved_sanity(100.0), 100.0)
	assert_false(_read_test_save().has("sanity"))
#endregion


#region Getters
func test_level_never_reached_has_no_state() -> void:
	GameState.start_game()
	assert_null(GameState.get_level_state(LEVEL_PATH))
	assert_eq(GameState.get_levels_reached(), 0, "get_level_state only reads")


func test_get_all_facts_is_copy() -> void:
	GameState.start_game()
	GameState.set_fact("choice.helped_teto", true)
	var facts: Dictionary[String, Variant] = GameState.get_all_facts()
	facts["choice.helped_teto"] = false
	assert_eq(GameState.get_fact("choice.helped_teto"), true)


func test_set_fact_refuses_array() -> void:
	GameState.start_game()
	GameState.set_fact("choice.list", [1, 2])
	assert_push_error("must be bool, int, float or String")
	assert_false(GameState.get_all_facts().has("choice.list"))


func test_no_game_state_returns_defaults() -> void:
	assert_false(GameState.has_game_state())
	assert_eq(GameState.get_fact("choice.helped_teto", false), false)
	assert_eq(GameState.get_saved_sanity(100.0), 100.0)
	assert_file_does_not_exist(TEST_SAVE_PATH)
#endregion


#region Migration
func test_v1_save_loads() -> void:
	assert_eq(DirAccess.copy_absolute(SAVE_V1_FIXTURE_PATH, TEST_SAVE_PATH), OK)
	assert_eq(GameState.get_or_create_state().total_games_played, 3)
	assert_eq(GameState.get_checkpoint_level_path(), LEVEL_PATH)
	assert_true(GameState.get_level_flag(LEVEL_PATH, "thing.box_01"))
	assert_eq(GameState.get_fact("quest.find_key"), 1)
	assert_eq(GameState.get_or_create_state().inventory.get("key.rusty"), 2)


func test_v1_never_saved_sanity_is_dropped() -> void:
	assert_eq(DirAccess.copy_absolute(SAVE_V1_FIXTURE_PATH, TEST_SAVE_PATH), OK)
	assert_eq(GameState.get_saved_sanity(100.0), 100.0, "v1 wrote -1 for never saved sanity")
	var written: Dictionary = _read_test_save()
	assert_false(written.has("sanity"), "migrated save is written back w/o it")
	assert_eq(int(written.get("save_version", 0)), GameState.SAVE_VERSION)


func test_v1_saved_sanity_is_kept() -> void:
	_write_test_save({ "save_version": 1, "sanity": 30.0 })
	assert_eq(GameState.get_saved_sanity(100.0), 30.0)


func test_newer_save_version_errors() -> void:
	_write_test_save({ "save_version": GameState.SAVE_VERSION + 1, "total_games_played": 5 })
	assert_eq(GameState.get_or_create_state().total_games_played, 5, "loaded as is")
	assert_push_error("this game only knows")


func test_broken_save_is_kept_aside() -> void:
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	assert_true(file.store_string("{ not json"))
	file.close()
	assert_eq(GameState.get_levels_reached(), 0, "starts fresh")
	assert_engine_error("Parse JSON failed")
	assert_push_error("is not valid save")
	assert_file_exists(TEST_SAVE_PATH + ".broken")


func test_import_v1_save_backs_up_current_one() -> void:
	GameState.start_game()
	assert_true(GameState.import_save(SAVE_V1_FIXTURE_PATH))
	assert_eq(GameState.get_or_create_state().total_games_played, 3)
	assert_eq(GameState.get_saved_sanity(100.0), 100.0)
	assert_file_exists(TEST_SAVE_PATH + ".backup")
#endregion


#region Helpers
func _delete_test_save_files() -> void:
	for suffix: String in ["", ".tmp", ".backup", ".broken"]:
		var path: String = TEST_SAVE_PATH + suffix
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			fail_test("could not delete %s, next test may see it" % path)


func _write_test_save(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	assert_true(file.store_string(JSON.stringify(data)))
	file.close()


func _read_test_save() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	if parsed is not Dictionary:
		fail_test("%s is not JSON object" % TEST_SAVE_PATH)
		return { }
	var data: Dictionary = parsed
	return data
#endregion
