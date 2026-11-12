# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## The narrow interface to the local player, the same for 2D and 3D.
## Dialogue files, [InteractableThing] and [code]DebugCommands[/code] go through this,
## so the inventory and sanity can change without touching them.
## Made by [PlayerBody] and [PlayerBody2D], passed to dialogues as extra game state:
## [codeblock]
## if has_item("showcase_key")
##     do give_item("aspect_of_hate", 2)
##     do set_flag("favor.cassie")
## [/codeblock]
## Items are ids, see [method ItemData.load_id].
class_name PlayerApi
extends RefCounted

## Group the player body joins, see [method find].
const GROUP: StringName = &"player"

## Null when the player has none. Item methods then push an error.
var inventory: InventoryComponent
## Null when the player has none. [method sanity_add] then pushes an error.
var sanity: SanityComponent


func _init(inventory_: InventoryComponent, sanity_: SanityComponent) -> void:
	inventory = inventory_
	sanity = sanity_


## The local player's interface, or null when no player is in [param tree].
static func find(tree: SceneTree) -> PlayerApi:
	var player: Node = tree.get_first_node_in_group(GROUP)
	return player.get(&"api") as PlayerApi if player else null


## Gives [param count] of the item with [param id]. Returns false if there is no room.
func give_item(id: String, count: int = 1) -> bool:
	return _has_inventory() and inventory.add(ItemData.load_id(id), count)


## Removes [param count] of the item. Returns false if fewer are carried.
func remove_item(id: String, count: int = 1) -> bool:
	return _has_inventory() and inventory.remove(ItemData.load_id(id), count)


## True if at least [param count] of the item are carried.
func has_item(id: String, count: int = 1) -> bool:
	return _has_inventory() and inventory.has(ItemData.load_id(id), count)


## Uses the item, see [method InventoryComponent.use].
func use_item(id: String) -> bool:
	return _has_inventory() and inventory.use(ItemData.load_id(id))


## Adds [param amount] to sanity, negative drains. See [method SanityComponent.add].
func sanity_add(amount: float) -> void:
	if not sanity:
		push_error("player has no SanityComponent, sanity_add(%s) ignored" % amount)
		return
	sanity.add(amount)


## Returns the flag in the current level, false when unset.
## Keys use a prefix per writer: [code]"quest."[/code], [code]"favor."[/code], [code]"sanctuary."[/code].
## [b]Warning:[/b] Needs a game state, see [GameState]. A scene run directly from the
## editor has none, so this always returns false.
func get_flag(flag: String) -> bool:
	return GameState.get_level_flag(GameState.get_current_level_path(), flag)


## Sets the flag in the current level and saves, see [method GameState.set_level_flag].
## Without a game state it warns and saves nothing.
func set_flag(flag: String, value: bool = true) -> void:
	GameState.set_level_flag(GameState.get_current_level_path(), flag, value)


func _has_inventory() -> bool:
	if not inventory:
		push_error("player has no InventoryComponent")
	return inventory != null
