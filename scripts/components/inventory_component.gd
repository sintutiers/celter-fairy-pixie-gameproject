# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Player inventory, [ItemData] to count. Stack of [member ItemData.max_stack]
## takes one slot, [member max_slots] limits slots used in total.
## Saved in [member GameState.inventory] on every change and loaded on ready,
## so it survives level changes and restarts. Without game state nothing is saved.
## Dependencies (api, optional sanity_component) are injected by body.
class_name InventoryComponent
extends Component

## Emitted after item was added.
signal item_added(item: ItemData, count: int)
## Emitted when [method add_inventory_item] found no room.
signal add_failed(item: ItemData)

## Slots in total, see [method get_used_slot_count].
@export var max_slots: int = 8
## Prints inventory changes. Testing only.
@export var debug: bool = true

var sanity_component: SanityComponent
## Passed to item use dialogues as extra game state.
var api: PlayerApi
## Item to count. Read only, change it through [method add_inventory_item] and [method remove_inventory_item].
var items: Dictionary[ItemData, int] = { }

# Item use dialogues are skipped while another dialogue is open.
var _in_dialogue: bool = false


## True if at least [param count] of [param item] are carried.
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


## All or nothing. Returns false when there is no room and nothing was added.
## Pushes error when [param count] is below 1.
func add_inventory_item(item: ItemData, count: int = 1) -> bool:
	if not item:
		return false
	if count < 1:
		push_error("%s: add count must be at least 1, got %d" % [name, count])
		return false
	if not can_carry_item(item, count):
		_log_inventory_message("no room for %s" % item.get_item_id())
		add_failed.emit(item)
		return false
	items[item] = items.get(item, 0) + count
	_save_inventory()
	_log_inventory_message("+%d %s" % [count, item.get_item_id()])
	item_added.emit(item, count)
	return true


## Returns false when fewer than [param count] are carried and nothing was removed.
## Pushes error when [param count] is below 1.
func remove_inventory_item(item: ItemData, count: int = 1) -> bool:
	if count < 1:
		push_error("%s: remove count must be at least 1, got %d" % [name, count])
		return false
	if not has_inventory_item(item, count):
		return false
	items[item] -= count
	if items[item] <= 0:
		items.erase(item)
	_save_inventory()
	_log_inventory_message("-%d %s" % [count, item.get_item_id()])
	return true


## Applies item effects and consumes it if [member ItemData.consumed_on_use].
## Its use dialogue only shows when no dialogue is open.
## Returns false if item is not carried.
func use_inventory_item(item: ItemData) -> bool:
	if not has_inventory_item(item):
		return false
	_log_inventory_message("used %s" % item.get_item_id())
	if sanity_component and item.sanity_restore != 0.0:
		sanity_component.add_sanity(item.sanity_restore)
	if item.consumed_on_use:
		remove_inventory_item(item)
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


# No signals: nothing was picked up, pickup toast must stay quiet.
# Item whose .tres is gone is reported by load_item_by_id and dropped on next save.
func _load_saved_inventory() -> void:
	if not GameState.has_game_state():
		return
	var saved: Dictionary[String, int] = GameState.get_or_create_state().inventory
	for id: String in saved:
		var item: ItemData = ItemData.load_item_by_id(id)
		if item:
			items[item] = saved[id]


# Saved by id, not by resource. Renaming item file breaks saves that hold it.
func _save_inventory() -> void:
	if not GameState.has_game_state():
		return
	var saved: Dictionary[String, int] = { }
	for item: ItemData in items:
		saved[item.get_item_id()] = items[item]
	GameState.get_or_create_state().inventory = saved
	GlobalState.save()


func _log_inventory_message(message: String) -> void:
	if debug:
		print("[inv] %s (slots %d/%d)" % [message, get_used_slot_count(), max_slots])


func _get_slots_needed(item: ItemData, count: int) -> int:
	return ceili(float(count) / item.max_stack)
