# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Shows player sanity, inventory and facts as text, for showcase level.
## Polled every frame because it is debug view, not real HUD.
class_name ShowcaseHud
extends Label


func _process(_delta: float) -> void:
	# Looked up every frame, player can respawn or change level.
	var api: PlayerApi = PlayerApi.find(get_tree())
	if not api:
		text = "no player"
		return
	var lines := PackedStringArray()
	if api.sanity:
		lines.append("Sanity %.0f / %.0f (zone %d)" % [api.sanity.value, api.sanity.max_sanity, api.sanity.zone])
	if api.inventory:
		lines.append("Inventory %d / %d slots" % [api.inventory.slots_used(), api.inventory.max_slots])
		for item: ItemData in api.inventory.items:
			var label: String = item.display_name if item.display_name != "" else item.id()
			lines.append("  %s x%d" % [label, api.inventory.items[item]])
	if not GameState.has_game_state():
		lines.append("No save data: flags, facts and pickups reset. Start from the main menu to keep them.")
	else:
		var facts: Dictionary[String, Variant] = GameState.get_or_create_state().facts
		for key: String in facts:
			lines.append("  %s = %s" % [key, facts[key]])
			if key.begins_with("quest."):
				lines.append("    " + _quest_line(key.trim_prefix("quest."), facts[key]))
	text = "\n".join(lines)


# Title and journal text of quest stage. Placeholder for quest journal.
func _quest_line(id: String, stage: int) -> String:
	var quest: QuestData = QuestData.load_id(id)
	if not quest:
		return "unknown quest"
	return "%s: %s" % [quest.title, quest.stages[stage] if stage < quest.stages.size() else "done"]
