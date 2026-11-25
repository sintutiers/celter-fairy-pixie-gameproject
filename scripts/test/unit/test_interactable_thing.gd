# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [InteractableThing] gates in order flag > item > room, + used pickup stays gone after reload.
## Things have no dialogue ∴ interaction ends at once. Flags + pickups are saved ∴ [SaveIsolatedTest].
extends SaveIsolatedTest

# uid:// key is used as is ∴ needs no real level scene
const LEVEL_PATH: String = "uid://test_level"
const FLAG: String = "test.door_open"
const ITEM_ID: String = "bread"

var _inventory: InventoryComponent
var _api: PlayerApi


#region Setup/Teardown
# thing w/o owner counts as placed in current level
func before_each() -> void:
	super()
	GameState.start_game()
	GameState.set_current_level_path(LEVEL_PATH)
	_inventory = autofree(InventoryComponent.new())
	_api = PlayerApi.new(_inventory, null)
#endregion


#region Gates
func test_missing_flag_blocks_before_missing_item() -> void:
	var thing: InteractableThing = InteractableThing.new()
	thing.requires_flag = FLAG
	thing.requires_item = ItemData.load_item_by_id(ITEM_ID)
	add_child_autofree(thing)
	watch_signals(thing)
	await thing.execute_interaction_for_actor(_api)
	assert_signal_emitted_with_parameters(thing.blocked, [_api, InteractableThing.REQUIRES_FLAG])


func test_missing_item_blocks_once_flag_is_set() -> void:
	_api.set_level_flag(FLAG)
	var thing: InteractableThing = InteractableThing.new()
	thing.requires_flag = FLAG
	thing.requires_item = ItemData.load_item_by_id(ITEM_ID)
	add_child_autofree(thing)
	watch_signals(thing)
	await thing.execute_interaction_for_actor(_api)
	assert_signal_emitted_with_parameters(thing.blocked, [_api, InteractableThing.REQUIRES_ITEM])


func test_full_inventory_blocks_pickup() -> void:
	_inventory.max_slots = 0
	var thing: InteractableThing = InteractableThing.new()
	thing.item = ItemData.load_item_by_id(ITEM_ID)
	add_child_autofree(thing)
	watch_signals(thing)
	await thing.execute_interaction_for_actor(_api)
	assert_signal_emitted_with_parameters(thing.blocked, [_api, InteractableThing.FULL])
	assert_false(_api.has_item(ITEM_ID))
#endregion


#region Pickup
func test_pickup_gives_items_and_stays_gone_after_reload() -> void:
	var thing: InteractableThing = _make_pickup()
	add_child_autofree(thing)
	await thing.execute_interaction_for_actor(_api)
	assert_true(_api.has_item(ITEM_ID, 2))
	assert_true(thing.is_queued_for_deletion())
	# same pickup in level loaded again, after game restart
	GameState.unload()
	var reloaded: InteractableThing = _make_pickup()
	add_child_autofree(reloaded)
	assert_true(reloaded.is_queued_for_deletion())
#endregion


#region Helpers
func _make_pickup() -> InteractableThing:
	var thing: InteractableThing = InteractableThing.new()
	thing.item = ItemData.load_item_by_id(ITEM_ID)
	thing.item_count = 2
	thing.free_after = true
	thing.persistent_id = "test_bread"
	return thing
#endregion
