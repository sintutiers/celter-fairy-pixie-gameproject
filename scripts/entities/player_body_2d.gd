@tool
# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## 2D twin of [PlayerBody]: owns every component on the player [CharacterBody2D] and wires
## their dependencies in [method Node._enter_tree]. Same rules, see [PlayerBody].
##
## No interaction or net sync yet, [InteractionComponent] and [Net] are 3D only.
## The dialogue API and flags are a copy of [PlayerBody]'s, keep them in step.
## @note: This is a [code]@tool[/code] script only for [member fill_components].
class_name PlayerBody2D
extends CharacterBody2D

## Editor only. Fills every empty slot below from the children.
@export_tool_button("Fill components") var fill_components: Callable = _fill_exports

@export_group("Components")
@export var input: InputComponent
@export var facing: FacingComponent
@export var movement: Movement2DComponent
@export var animation: AnimationComponent
@export var sanity: SanityComponent
@export var inventory: InventoryComponent
@export_group("Data")
@export var movement_profile: MovementProfile

@export_group("Scene Nodes")
@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var state_chart: StateChart


func _enter_tree() -> void:
	# Wiring mutates components, which are placeholders in the editor.
	if Engine.is_editor_hint():
		return
	_wire_components()


func _fill_exports() -> void:
	if not Engine.is_editor_hint():
		return
	input = _pick(input, InputComponent)
	facing = _pick(facing, FacingComponent)
	movement = _pick(movement, Movement2DComponent)
	animation = _pick(animation, AnimationComponent)
	sanity = _pick(sanity, SanityComponent)
	inventory = _pick(inventory, InventoryComponent)
	sprite = _pick(sprite, AnimatedSprite2D)
	collision_shape = _pick(collision_shape, CollisionShape2D)
	state_chart = _pick(state_chart, StateChart)
	# Looked up by name, a direct EditorInterface reference fails to parse in exported builds.
	Engine.get_singleton(&"EditorInterface").mark_scene_as_unsaved()


func _wire_components() -> void:
	if not movement_profile:
		movement_profile = MovementProfile.new()

	if inventory:
		inventory.sanity = sanity
		inventory.body = self
	if movement:
		movement.body = self
		movement.profile = movement_profile
		movement.input_component = input
		movement.facing_component = facing
		movement.collision_shape = collision_shape
		movement.state_chart = state_chart
	if animation:
		animation.sprite = sprite
		animation.movement = movement
		animation.facing = facing


# Editor only, the export if set, otherwise the first child of [param type].
func _pick(current: Node, type: Variant) -> Node:
	return current if current else Component.find_component(self, type)


#region Dialogue API
# Called from .dialogue files, the body is passed in as extra game state.
# Items are ids, see [method ItemData.load_id]. All of these need an [InventoryComponent].
## Gives the item. Returns false if there is no room.
func give_item(id: String, count: int = 1) -> bool:
	return inventory.add(ItemData.load_id(id), count)


func remove_item(id: String, count: int = 1) -> bool:
	return inventory.remove(ItemData.load_id(id), count)


func has_item(id: String, count: int = 1) -> bool:
	return inventory.has(ItemData.load_id(id), count)


func use_item(id: String) -> bool:
	return inventory.use(ItemData.load_id(id))


## Does nothing without a [SanityComponent].
func sanity_add(amount: float) -> void:
	if sanity:
		sanity.add(amount)
#endregion


#region Flags
# See [PlayerBody]. Needs a game state, a scene run directly from the editor has none.
## Returns the flag, false when unset.
func get_flag(flag: String) -> bool:
	return GameState.get_level_flag(GameState.get_current_level_path(), flag)


## Sets the flag. See [method GameState.set_level_flag].
func set_flag(flag: String, value: bool = true) -> void:
	GameState.set_level_flag(GameState.get_current_level_path(), flag, value)
#endregion
