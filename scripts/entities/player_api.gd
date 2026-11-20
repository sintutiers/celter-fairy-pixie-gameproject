# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Narrow interface to local player, same for 2D + 3D.
## Dialogue files + [InteractableThing] only call its methods ∴ inventory + sanity
## can change w/o touching them. Other code (HUD, [code]DebugCommands[/code], [SanityArea])
## reads [member inventory] + [member sanity] directly.
## Made by [PlayerBody] + [PlayerBody2D], passed to dialogues as extra game state:
## [codeblock]
## if has_item("showcase_key")
##     $> give_item("aspect_of_hate", 2)
##     $> add_opinion("cassie", 1)
##     $> add_favor("fairy", 2)
##     $> advance_quest("help_cassie")
## [/codeblock]
## Items are ids, see [method ItemData.load_item_by_id].
class_name PlayerApi
extends RefCounted

## Group player body joins, see [method find_local_player_api].
const GROUP: StringName = &"player"

## Null when player has ∅. Item methods > push error.
var inventory: InventoryComponent
## Null when player has ∅. [method add_sanity] > pushes error.
var sanity: SanityComponent


func _init(inventory_: InventoryComponent, sanity_: SanityComponent) -> void:
	inventory = inventory_
	sanity = sanity_


## Local player interface/null when no player is in [param tree].
static func find_local_player_api(tree: SceneTree) -> PlayerApi:
	var player: Node = tree.get_first_node_in_group(GROUP)
	return player.get(&"api") if player else null


## Gives [param count] of item w/ [param id]. Returns false if there is no room.
func give_item(id: String, count: int = 1) -> bool:
	return _require_inventory() and inventory.add_inventory_item(ItemData.load_item_by_id(id), count)


## Removes [param count] of item. Returns false if fewer are carried.
func remove_item(id: String, count: int = 1) -> bool:
	return _require_inventory() and inventory.remove_inventory_item(ItemData.load_item_by_id(id), count)


## True if >= [param count] of item are carried.
func has_item(id: String, count: int = 1) -> bool:
	return _require_inventory() and inventory.has_inventory_item(ItemData.load_item_by_id(id), count)


## Uses item, see [method InventoryComponent.use_inventory_item].
func use_item(id: String) -> bool:
	return _require_inventory() and inventory.use_inventory_item(ItemData.load_item_by_id(id))


## Adds [param amount] to sanity, negative drains. See [method SanityComponent.add_sanity].
func add_sanity(amount: float) -> void:
	if not sanity:
		Log.error("player has no SanityComponent, add_sanity(%s) ignored" % amount)
		return
	GameLog.write(&"sanity", "add", amount, "to", "%.1f" % sanity.value)
	sanity.add_sanity(amount)


## Number of sanity thresholds player is at/above, 0 = lowest.
## See [member SanityComponent.zone].
func get_sanity_zone() -> int:
	if not sanity:
		Log.error("player has no SanityComponent, get_sanity_zone() returns 0")
		return 0
	return sanity.zone


## Returns flag in current level, false when unset.
## For state that crosses levels use [method get_fact].
## ⚠ Needs game state, see [GameState]. Scene run directly from
## editor has ∅ ∴ this always returns false.
func get_level_flag(flag: String) -> bool:
	return GameState.get_level_flag(GameState.get_current_level_path(), flag)


## Sets flag in current level + saves, see [method GameState.set_level_flag].
## W/o game state it warns + saves ∅.
func set_level_flag(flag: String, value: bool = true) -> void:
	GameLog.write(&"ledger", "level flag", flag, "=", value)
	GameState.set_level_flag(GameState.get_current_level_path(), flag, value)


## Returns global fact/[param default] when unset. See [method GameState.get_fact].
func get_fact(key: String, default: Variant = false) -> Variant:
	return GameState.get_fact(key, default)


## Sets global fact + saves, see [method GameState.set_fact].
## Every dialogue choice should end up here, in [method add_opinion], [method add_favor],
## [method add_debt]/in [method advance_quest]: no fake choices.
func set_fact(key: String, value: Variant = true) -> void:
	GameLog.write(&"ledger", key, "=", value)
	GameState.set_fact(key, value)


## How much [param npc] likes player, 0 when they never met. Hidden from player.
func get_opinion(npc: String) -> int:
	return get_fact("opinion." + npc, 0)


## Adds [param amount] to [method get_opinion], negative lowers.
func add_opinion(npc: String, amount: int) -> void:
	set_fact("opinion." + npc, get_opinion(npc) + amount)


## Size of what [param npc] owes player, 0 when ∅. Other direction is [method get_debt],
## both can be open w/ same npc at once.
func get_favor(npc: String) -> int:
	return get_fact("favor." + npc, 0)


## Adds [param amount] to [method get_favor], negative spends.
## Returns false + spends ∅ when less is owed.
func add_favor(npc: String, amount: int) -> bool:
	return _add_to_ledger_fact("favor." + npc, amount)


## Size of what player owes [param npc], 0 when ∅. Other direction is [method get_favor].
func get_debt(npc: String) -> int:
	return get_fact("debt." + npc, 0)


## Adds [param amount] to [method get_debt], negative pays off.
## Returns false + pays ∅ when less is owed.
func add_debt(npc: String, amount: int) -> bool:
	return _add_to_ledger_fact("debt." + npc, amount)


## Stage of quest w/ [param id]: -1 = not started, see [member QuestData.stages].
func get_quest_stage(id: String) -> int:
	# loaded only to fail loudly on typo, bare fact lookup would return -1 forever
	if not QuestData.load_quest_by_id(id):
		return -1
	return get_fact("quest." + id, -1)


## True once quest moved past its last stage.
func is_quest_done(id: String) -> bool:
	var quest: QuestData = QuestData.load_quest_by_id(id)
	return quest != null and get_fact("quest." + id, -1) >= quest.stages.size()


## Starts quest/moves it to its next stage. Pushes error when already done.
func advance_quest(id: String) -> void:
	var quest: QuestData = QuestData.load_quest_by_id(id)
	if not quest:
		return
	var stage: int = get_quest_stage(id) + 1
	if stage > quest.stages.size():
		Log.error("quest '%s' is already done, advance_quest ignored" % id)
		return
	set_fact("quest." + id, stage)


# favors + debts never go below 0: owing other way is its own fact
func _add_to_ledger_fact(key: String, amount: int) -> bool:
	var size: int = get_fact(key, 0) + amount
	if size < 0:
		Log.error("'%s' is %d, cannot add %d" % [key, size - amount, amount])
		return false
	set_fact(key, size)
	return true


func _require_inventory() -> bool:
	if not inventory:
		Log.error("player has no InventoryComponent")
	return inventory != null
