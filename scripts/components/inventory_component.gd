# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Player inventory, [ItemData] to count. Stack of [member ItemData.max_stack]
## takes one slot, [member max_slots] limits slots used in total.
## Saved in [member GameState.inventory] on every change + loaded on ready,
## ∴ it survives level changes + restarts. W/o game state ∅ is saved.
## Dependencies (api, optional sanity_component) are injected by body.
class_name InventoryComponent
extends Component

## Emitted after [member items] changed for any reason, also after saved inventory loaded.
signal changed
## Emitted after item was added.
signal item_added(item: ItemData, count: int)
## Emitted when [method add_inventory_item] found no room.
signal add_failed(item: ItemData)
## Emitted after item was used. [param consumed] = one was removed by that use.
signal item_used(item: ItemData, consumed: bool)

## Slots in total, see [method get_used_slot_count].
@export var max_slots: int = 8

var sanity_component: SanityComponent
## Passed to item use dialogues as extra game state.
var api: PlayerApi
## Item to count. Read only, change it through [method add_inventory_item] + [method remove_inventory_item].
var items: Dictionary[ItemData, int] = { }

# item use dialogues are skipped while another dialogue is open
var _in_dialogue: bool = false


## True if >= [param count] of [param item] are carried.
func has_inventory_item(item: ItemData, count: int = 1) -> bool:
	return item != null and items.get(item, 0) >= count


## Slots taken by all carried stacks together.
func get_used_slot_count() -> int:
	var used: int = 0
	for item: ItemData in items:
		used += _get_slots_needed(item, items[item])
	return used


## True if [param count] more of [param item] fit in free slots.
func can_carry_item(item: ItemData, count: int = 1) -> bool:
	var have: int = items.get(item, 0)
	var extra: int = _get_slots_needed(item, have + count) - _get_slots_needed(item, have)
	return get_used_slot_count() + extra <= max_slots


## All/∅. Returns false when there is no room + ∅ was added.
## Pushes error when [param count] is below 1.
func add_inventory_item(item: ItemData, count: int = 1) -> bool:
	if not item:
		return false
	if count < 1:
		Log.error("%s: add count must be at least 1, got %d" % [name, count])
		return false
	if not can_carry_item(item, count):
		GameLog.write(&"inventory", "no room for %s" % item.get_item_id())
		add_failed.emit(item)
		return false
	items[item] = items.get(item, 0) + count
	_save_inventory()
	changed.emit()
	GameLog.write(&"inventory", "+%d %s" % [count, item.get_item_id()])
	item_added.emit(item, count)
	return true


## Returns false when fewer than [param count] are carried + ∅ was removed.
## Pushes error when [param count] is below 1.
func remove_inventory_item(item: ItemData, count: int = 1) -> bool:
	if count < 1:
		Log.error("%s: remove count must be at least 1, got %d" % [name, count])
		return false
	if not has_inventory_item(item, count):
		return false
	items[item] -= count
	if items[item] <= 0:
		items.erase(item)
	_save_inventory()
	changed.emit()
	GameLog.write(&"inventory", "-%d %s" % [count, item.get_item_id()])
	return true


## Applies item effects + consumes it if [member ItemData.consumed_on_use].
## Its use dialogue only shows when no dialogue is open.
## Returns false if item not carried.
func use_inventory_item(item: ItemData) -> bool:
	if not has_inventory_item(item):
		return false
	GameLog.write(&"inventory", "used %s" % item.get_item_id())
	if sanity_component and item.sanity_restore != 0.0:
		GameLog.write(&"sanity", "add", item.sanity_restore, "from", item.get_item_id())
		sanity_component.add_sanity(item.sanity_restore)
	if item.consumed_on_use:
		remove_inventory_item(item)
	item_used.emit(item, item.consumed_on_use)
	if item.use_dialogue and not _in_dialogue:
		DialogueManager.show_dialogue_balloon(item.use_dialogue, item.use_dialogue_cue, [api])
	return true


func _on_ready() -> void:
	DialogueManager.dialogue_started.connect(
		func(_r: DialogueResource) -> void:
			_in_dialogue = true,
	)
	DialogueManager.dialogue_ended.connect(
		func(_r: DialogueResource) -> void:
			_in_dialogue = false,
	)
	_load_saved_inventory()


func _on_setup() -> void:
	_require_dependencies({ "api": api })


# only changed: ∅ was picked up, pickup toast must stay quiet
# item whose .tres is gone is reported by load_item_by_id + dropped on next save
func _load_saved_inventory() -> void:
	if not GameState.has_game_state():
		return
	var saved: Dictionary[String, int] = GameState.get_or_create_state().inventory
	for id: String in saved:
		var item: ItemData = ItemData.load_item_by_id(id)
		if item:
			items[item] = saved[id]
	changed.emit()


# saved by id, not resource: renaming item file breaks saves that hold it
func _save_inventory() -> void:
	if not GameState.has_game_state():
		return
	var saved: Dictionary[String, int] = { }
	for item: ItemData in items:
		saved[item.get_item_id()] = items[item]
	GameState.get_or_create_state().inventory = saved
	GameState.save()


func _get_slots_needed(item: ItemData, count: int) -> int:
	return ceili(float(count) / item.max_stack)
