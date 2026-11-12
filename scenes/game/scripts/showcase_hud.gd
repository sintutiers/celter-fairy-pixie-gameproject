# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Shows the player's sanity and inventory as text, for the showcase level.
## Polled every frame because it is a debug view, not the real HUD.
class_name ShowcaseHud
extends Label


func _process(_delta: float) -> void:
	# Looked up every frame, the player can respawn or change level.
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
		lines.append("No save data: flags and pickups reset. Start from the main menu to keep them.")
	text = "\n".join(lines)
