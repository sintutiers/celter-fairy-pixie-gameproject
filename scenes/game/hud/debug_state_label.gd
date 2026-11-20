# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Shows sanity numbers, inventory slots + every fact as text. Developer view, see [member Hud.show_debug_state].
## Polled every frame ∵ facts have no signal. Stops while hidden.
class_name DebugStateLabel
extends Label


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree())


func _ready() -> void:
	set_process(is_visible_in_tree())


func _process(_delta: float) -> void:
	# looked up every frame, player can respawn/change level
	var api: PlayerApi = PlayerApi.find_local_player_api(get_tree())
	if not api:
		text = "no player"
		return
	var lines: PackedStringArray = PackedStringArray()
	if api.sanity:
		lines.append("Sanity %.0f / %.0f (zone %d)" % [api.sanity.value, api.sanity.max_sanity, api.sanity.zone])
	if api.inventory:
		lines.append("Inventory %d / %d slots" % [api.inventory.get_used_slot_count(), api.inventory.max_slots])
		for item: ItemData in api.inventory.items:
			lines.append("  %s x%d" % [item.get_display_label(), api.inventory.items[item]])
	if not GameState.has_game_state():
		lines.append("No save data: flags, facts and pickups reset. Start from the main menu to keep them.")
	else:
		var facts: Dictionary[String, Variant] = GameState.get_or_create_state().facts
		for key: String in facts:
			lines.append("  %s = %s" % [key, facts[key]])
			if key.begins_with("quest."):
				lines.append("    " + _format_quest_stage_line(key.trim_prefix("quest."), facts[key]))
	text = "\n".join(lines)


# title + journal text of quest stage, placeholder for quest journal
func _format_quest_stage_line(id: String, stage: int) -> String:
	var quest: QuestData = QuestData.load_quest_by_id(id)
	if not quest:
		return "unknown quest"
	return "%s: %s" % [quest.title, quest.stages[stage] if stage < quest.stages.size() else "done"]
