# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [PlayerApi] contract .dialogue files rely on: items by id, quest stages, opinion + ledger facts, level flags.
## Inventory + sanity are bare components, not in tree.
extends SaveIsolatedTest

# any quest works, stage count is read from it
const QUEST_ID: String = "feed_tree"
const ITEM_ID: String = "bread"

var _api: PlayerApi


#region Setup/Teardown
func before_each() -> void:
	super()
	GameState.start_game()
	var inventory: InventoryComponent = autofree(InventoryComponent.new())
	var sanity: SanityComponent = autofree(SanityComponent.new())
	_api = PlayerApi.new(inventory, sanity)
#endregion


#region Items
func test_given_item_is_carried() -> void:
	assert_true(_api.give_item(ITEM_ID, 2))
	assert_true(_api.has_item(ITEM_ID, 2))
	assert_false(_api.has_item(ITEM_ID, 3))


func test_given_item_is_saved_by_id() -> void:
	_api.give_item(ITEM_ID, 2)
	assert_eq(GameState.get_or_create_state().inventory.get(ITEM_ID), 2)


func test_removing_more_than_carried_removes_nothing() -> void:
	_api.give_item(ITEM_ID)
	assert_false(_api.remove_item(ITEM_ID, 2))
	assert_true(_api.has_item(ITEM_ID))
#endregion


#region Quests
func test_quest_goes_from_not_started_through_stages_to_done() -> void:
	assert_eq(_api.get_quest_stage(QUEST_ID), -1, "not started")
	var stage_count: int = QuestData.load_quest_by_id(QUEST_ID).stages.size()
	for stage: int in stage_count:
		_api.advance_quest(QUEST_ID)
		assert_eq(_api.get_quest_stage(QUEST_ID), stage)
		assert_false(_api.is_quest_done(QUEST_ID))
	_api.advance_quest(QUEST_ID)
	assert_true(_api.is_quest_done(QUEST_ID))


func test_advancing_done_quest_errors() -> void:
	var stage_count: int = QuestData.load_quest_by_id(QUEST_ID).stages.size()
	for _advance: int in stage_count + 1:
		_api.advance_quest(QUEST_ID)
	_api.advance_quest(QUEST_ID)
	assert_push_error("already done")
	assert_eq(_api.get_quest_stage(QUEST_ID), stage_count, "stays done")
#endregion


#region Facts
func test_opinion_adds_up_and_may_go_below_zero() -> void:
	_api.add_opinion("teto", 2)
	_api.add_opinion("teto", -3)
	assert_eq(_api.get_opinion("teto"), -1)


func test_favor_cannot_be_spent_below_zero() -> void:
	assert_true(_api.add_favor("fairy", 2))
	assert_false(_api.add_favor("fairy", -3))
	assert_push_error("cannot add -3")
	assert_eq(_api.get_favor("fairy"), 2)


func test_debt_cannot_be_paid_below_zero() -> void:
	assert_true(_api.add_debt("fairy", 1))
	assert_false(_api.add_debt("fairy", -2))
	assert_push_error("cannot add -2")
	assert_eq(_api.get_debt("fairy"), 1)


func test_favor_and_debt_are_separate() -> void:
	_api.add_favor("fairy", 2)
	_api.add_debt("fairy", 1)
	assert_eq(_api.get_favor("fairy"), 2)
	assert_eq(_api.get_debt("fairy"), 1)


func test_level_flag_belongs_to_current_level() -> void:
	GameState.set_current_level_path("uid://test_level_a")
	_api.set_level_flag("test.door_open")
	assert_true(_api.get_level_flag("test.door_open"))
	GameState.set_current_level_path("uid://test_level_b")
	assert_false(_api.get_level_flag("test.door_open"))
#endregion


#region Missing components
func test_item_call_without_inventory_errors() -> void:
	var api: PlayerApi = PlayerApi.new(null, null)
	assert_false(api.give_item(ITEM_ID))
	assert_push_error("no InventoryComponent")


func test_add_sanity_without_sanity_errors() -> void:
	var api: PlayerApi = PlayerApi.new(null, null)
	api.add_sanity(10.0)
	assert_push_error("no SanityComponent")
#endregion
