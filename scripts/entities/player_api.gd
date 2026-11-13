# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## The narrow interface to the local player, the same for 2D and 3D.
## Dialogue files, [InteractableThing] and [code]DebugCommands[/code] go through this,
## so the inventory and sanity can change without touching them.
## Made by [PlayerBody] and [PlayerBody2D], passed to dialogues as extra game state:
## [codeblock]
## if has_item("showcase_key")
##     do give_item("aspect_of_hate", 2)
##     do add_opinion("cassie", 1)
##     do advance_quest("help_cassie")
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


## Number of sanity thresholds the player is at or above, 0 = lowest.
## See [member SanityComponent.zone].
func sanity_zone() -> int:
	if not sanity:
		push_error("player has no SanityComponent, sanity_zone() returns 0")
		return 0
	return sanity.zone


## Returns the flag in the current level, false when unset.
## For state that crosses levels use [method get_fact].
## [b]Warning:[/b] Needs a game state, see [GameState]. A scene run directly from the
## editor has none, so this always returns false.
func get_flag(flag: String) -> bool:
	return GameState.get_level_flag(GameState.get_current_level_path(), flag)


## Sets the flag in the current level and saves, see [method GameState.set_level_flag].
## Without a game state it warns and saves nothing.
func set_flag(flag: String, value: bool = true) -> void:
	GameState.set_level_flag(GameState.get_current_level_path(), flag, value)


## Returns a global fact, or [param default] when unset. See [method GameState.get_fact].
func get_fact(key: String, default: Variant = false) -> Variant:
	return GameState.get_fact(key, default)


## Sets a global fact and saves, see [method GameState.set_fact].
## Every dialogue choice should end up here, in [method add_opinion] or in
## [method advance_quest]: no fake choices.
func set_fact(key: String, value: Variant = true) -> void:
	GameState.set_fact(key, value)


## How much [param npc] likes the player, 0 when they never met. Hidden from the player.
func opinion(npc: String) -> int:
	return get_fact("opinion." + npc, 0)


## Adds [param amount] to [method opinion], negative lowers.
func add_opinion(npc: String, amount: int) -> void:
	set_fact("opinion." + npc, opinion(npc) + amount)


## Stage of the quest with [param id]: -1 = not started, see [member QuestData.stages].
func quest_stage(id: String) -> int:
	# Loaded only to fail loudly on a typo, a bare fact lookup would return -1 forever.
	if not QuestData.load_id(id):
		return -1
	return get_fact("quest." + id, -1)


## True once the quest moved past its last stage.
func quest_done(id: String) -> bool:
	var quest: QuestData = QuestData.load_id(id)
	return quest != null and get_fact("quest." + id, -1) >= quest.stages.size()


## Starts the quest, or moves it to its next stage. Pushes an error when already done.
func advance_quest(id: String) -> void:
	var quest: QuestData = QuestData.load_id(id)
	if not quest:
		return
	var stage: int = quest_stage(id) + 1
	if stage > quest.stages.size():
		push_error("quest '%s' is already done, advance_quest ignored" % id)
		return
	set_fact("quest." + id, stage)


func _has_inventory() -> bool:
	if not inventory:
		push_error("player has no InventoryComponent")
	return inventory != null
