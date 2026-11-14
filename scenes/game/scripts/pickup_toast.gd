# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Shows "you picked up Bread", "no room for Bread" or "you used Bread" briefly, then fades.
## Listens to [signal InventoryComponent.item_added], [signal InventoryComponent.add_failed]
## and [signal InventoryComponent.item_used].
## @experimental: Placeholder until there is inventory UI.
class_name PickupToast
extends Label

## Seconds until message has faded out.
@export var fade_time: float = 3.0

var _tween: Tween


func _ready() -> void:
	text = ""
	# Player made its api in _enter_tree, which runs before any _ready, see PlayerSpawner.
	var api: PlayerApi = PlayerApi.find_local_player_api(get_tree())
	if not api or not api.inventory:
		push_error("%s: no player with an InventoryComponent in the scene" % name)
		return
	api.inventory.item_added.connect(_on_item_added)
	api.inventory.add_failed.connect(_on_add_failed)
	api.inventory.item_used.connect(_on_item_used)


func _on_item_added(item: ItemData, count: int) -> void:
	var amount: String = " x%d" % count if count > 1 else ""
	_show_toast_message("you picked up %s%s" % [_get_item_label(item), amount])


func _on_add_failed(item: ItemData) -> void:
	_show_toast_message("no room for %s" % _get_item_label(item))


func _on_item_used(item: ItemData, consumed: bool) -> void:
	var label: String = _get_item_label(item)
	var destroyed: String = "\n%s has been destroyed" % label if consumed else ""
	_show_toast_message("you used %s%s" % [label, destroyed])


func _get_item_label(item: ItemData) -> String:
	return item.display_name if item.display_name != "" else item.get_item_id()


func _show_toast_message(message: String) -> void:
	text = message
	modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
