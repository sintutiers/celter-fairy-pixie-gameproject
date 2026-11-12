# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Shows the player's sanity and inventory as text, for the showcase level.
## Polled every frame because it is a debug view, not the real HUD.
class_name ShowcaseHud
extends Label


func _process(_delta: float) -> void:
	# Looked up every frame, the "player" group is joined after this node is ready.
	var player := get_tree().get_first_node_in_group(&"player") as PlayerBody
	if not player:
		text = "no player"
		return
	var lines := PackedStringArray()
	if player.sanity:
		lines.append("Sanity %.0f / %.0f (zone %d)" % [player.sanity.value, player.sanity.max_sanity, player.sanity.zone])
	if player.inventory:
		lines.append("Inventory %d / %d slots" % [player.inventory.slots_used(), player.inventory.max_slots])
		for item: ItemData in player.inventory.items:
			var label: String = item.display_name if item.display_name != "" else item.id()
			lines.append("  %s x%d" % [label, player.inventory.items[item]])
	if not GameState.has_game_state():
		lines.append("No save data: flags and pickups reset. Start from the main menu to keep them.")
	text = "\n".join(lines)
