# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [InventoryComponent] slots, stacking + use. Items are made in memory ∴ no content needed.
## Inventory saves whenever save file exists ∴ [SaveIsolatedTest].
extends SaveIsolatedTest

var _inventory: InventoryComponent


#region Setup/Teardown
func before_each() -> void:
	super()
	_inventory = autofree(InventoryComponent.new())
#endregion


#region Slots
func test_full_stack_takes_one_slot() -> void:
	var item: ItemData = _make_item(5)
	_inventory.add_inventory_item(item, 5)
	assert_eq(_inventory.get_used_slot_count(), 1)
	_inventory.add_inventory_item(item)
	assert_eq(_inventory.get_used_slot_count(), 2, "6th starts next stack")


func test_add_without_room_adds_nothing() -> void:
	_inventory.max_slots = 2
	var item: ItemData = _make_item(1)
	watch_signals(_inventory)
	assert_false(_inventory.add_inventory_item(item, 3))
	assert_false(_inventory.has_inventory_item(item), "all/∅, not 2 of 3")
	assert_signal_emitted(_inventory.add_failed)


func test_removing_last_one_drops_item() -> void:
	var item: ItemData = _make_item(5)
	_inventory.add_inventory_item(item)
	assert_true(_inventory.remove_inventory_item(item))
	assert_does_not_have(_inventory.items, item)
#endregion


#region Use
func test_use_restores_sanity_and_consumes_one() -> void:
	var sanity: SanityComponent = autofree(SanityComponent.new())
	sanity.set_current_sanity_value(50.0)
	_inventory.sanity_component = sanity
	var item: ItemData = _make_item(5)
	item.sanity_restore = 15.0
	_inventory.add_inventory_item(item, 2)
	assert_true(_inventory.use_inventory_item(item))
	assert_eq(sanity.value, 65.0)
	assert_eq(_inventory.items[item], 1)


func test_item_not_consumed_on_use_stays() -> void:
	var item: ItemData = _make_item(1)
	item.consumed_on_use = false
	_inventory.add_inventory_item(item)
	assert_true(_inventory.use_inventory_item(item))
	assert_true(_inventory.has_inventory_item(item))


func test_using_item_not_carried_does_nothing() -> void:
	assert_false(_inventory.use_inventory_item(_make_item(1)))
#endregion


#region Helpers
# no use_dialogue ∴ use never opens balloon
func _make_item(max_stack: int) -> ItemData:
	var item: ItemData = ItemData.new()
	item.max_stack = max_stack
	return item
#endregion
