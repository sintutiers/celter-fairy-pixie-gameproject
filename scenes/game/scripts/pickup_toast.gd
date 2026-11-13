# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Shows "+1 bread" or "no room for bread" briefly, then fades.
## Listens to [signal InventoryComponent.item_added] and [signal InventoryComponent.add_failed].
## @experimental: Placeholder until there is inventory UI.
class_name PickupToast
extends Label

## Seconds until message has faded out.
@export var fade_time: float = 3.0

var _tween: Tween


func _ready() -> void:
	text = ""
	# Player made its api in _enter_tree, which runs before any _ready, see PlayerSpawner.
	var api: PlayerApi = PlayerApi.find(get_tree())
	if not api or not api.inventory:
		push_error("%s: no player with an InventoryComponent in the scene" % name)
		return
	api.inventory.item_added.connect(
		func(item: ItemData, count: int) -> void:
			_show("+%d %s" % [count, item.id()]),
	)
	api.inventory.add_failed.connect(
		func(item: ItemData) -> void:
			_show("no room for %s" % item.id()),
	)


func _show(message: String) -> void:
	text = message
	modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
