# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Items local player carries, one line each. HUD widget, works alone. Hidden while empty.
class_name InventoryList
extends Label

var _inventory: InventoryComponent


func _ready() -> void:
	var api: PlayerApi = PlayerApi.find_local_player_api(get_tree())
	if not api or not api.inventory:
		Log.error("%s: no player with InventoryComponent in scene" % name)
		hide()
		return
	_inventory = api.inventory
	_inventory.changed.connect(_on_inventory_changed)
	# Player ready before this already sent its load signal.
	_on_inventory_changed()


func _on_inventory_changed() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for item: ItemData in _inventory.items:
		var count: int = _inventory.items[item]
		lines.append(item.get_display_label() + (" x%d" % count if count > 1 else ""))
	text = "\n".join(lines)
	visible = not lines.is_empty()
