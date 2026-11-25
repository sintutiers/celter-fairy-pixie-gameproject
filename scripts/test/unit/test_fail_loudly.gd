# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Rule 3 (fail loudly) as tests: wrong use errors + does ∅ instead of going on silently.
## Save errors are in test_game_state.gd. Nodes are made in code, no scene.
## [SanityComponent] reads save on ready + writes it on exit ∴ [SaveIsolatedTest].
extends SaveIsolatedTest


#region Content ids
func test_unknown_item_id_errors() -> void:
	assert_null(ItemData.load_item_by_id("no_such_item"))
	assert_push_error("no item 'no_such_item'")


func test_unknown_quest_id_errors() -> void:
	assert_null(QuestData.load_quest_by_id("no_such_quest"))
	assert_push_error("no quest 'no_such_quest'")
#endregion


#region Inventory
func test_adding_null_item_errors() -> void:
	var inventory: InventoryComponent = autofree(InventoryComponent.new())
	assert_false(inventory.add_inventory_item(null))
	assert_push_error("got null item")


func test_adding_zero_items_errors() -> void:
	var inventory: InventoryComponent = autofree(InventoryComponent.new())
	assert_false(inventory.add_inventory_item(ItemData.new(), 0))
	assert_push_error("must be at least 1")
	assert_true(inventory.items.is_empty())
#endregion


#region Sanity
func test_resume_without_pause_errors() -> void:
	var sanity: SanityComponent = autofree(SanityComponent.new())
	sanity.resume_sanity_drain()
	assert_push_error("without matching pause_sanity_drain")


func test_thresholds_out_of_order_error() -> void:
	var sanity: SanityComponent = SanityComponent.new()
	sanity.thresholds = PackedFloat32Array([0.5, 0.25])
	add_child_autofree(sanity)
	# check is in _on_setup, which is deferred
	await wait_process_frames(1)
	assert_push_error("thresholds must be ascending")


func test_zero_max_sanity_errors() -> void:
	var sanity: SanityComponent = SanityComponent.new()
	sanity.max_sanity = 0.0
	add_child_autofree(sanity)
	assert_push_error("max_sanity must be above 0")
#endregion


#region Level nodes
func test_sanity_area_without_shape_or_player_layer_errors() -> void:
	add_child_autofree(SanityArea.new())
	assert_push_error("no CollisionShape3D child")
	assert_push_error("misses player layer 2")


# owner = level root, like nodes saved in level scene
func test_duplicate_persistent_id_errors() -> void:
	var level: Node3D = Node3D.new()
	for thing_name: String in ["FirstJar", "SecondJar"]:
		var thing: InteractableThing = InteractableThing.new()
		thing.name = thing_name
		thing.persistent_id = "jar"
		thing.free_after = true
		level.add_child(thing)
		thing.owner = level
	add_child_autofree(level)
	assert_push_error("share persistent_id \"jar\"")
#endregion


#region Components
# not wired by body ∴ every dependency is missing
func test_unwired_component_errors() -> void:
	add_child_autofree(InteractionComponent.new())
	await wait_process_frames(1)
	assert_push_error("missing required dependencies")
#endregion
