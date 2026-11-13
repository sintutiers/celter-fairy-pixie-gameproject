@tool
# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## 2D twin of [PlayerBody]: owns every component on the player [CharacterBody2D] and wires
## their dependencies in [method Node._enter_tree]. Same rules, see [PlayerBody].
##
## No interaction yet, [InteractionComponent] is 3D only.
## [b]Note:[/b] This is a [code]@tool[/code] script only for [member fill_components].
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
@export var sanity_visuals: SanityVisualsComponent
@export var inventory: InventoryComponent
@export var net_sync: NetSyncComponent
@export_group("Data")
@export var movement_profile: MovementProfile

@export_group("Scene Nodes")
@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var state_chart: StateChart

## Set when the body enters the tree, see [PlayerApi].
var api: PlayerApi


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
	sanity_visuals = _pick(sanity_visuals, SanityVisualsComponent)
	inventory = _pick(inventory, InventoryComponent)
	net_sync = _pick(net_sync, NetSyncComponent)
	sprite = _pick(sprite, AnimatedSprite2D)
	collision_shape = _pick(collision_shape, CollisionShape2D)
	state_chart = _pick(state_chart, StateChart)
	# Looked up by name, a direct EditorInterface reference fails to parse in exported builds.
	Engine.get_singleton(&"EditorInterface").mark_scene_as_unsaved()


func _wire_components() -> void:
	if not movement_profile:
		movement_profile = MovementProfile.new()
	api = PlayerApi.new(inventory, sanity)
	add_to_group(PlayerApi.GROUP)

	if sanity_visuals:
		sanity_visuals.sanity = sanity
	if inventory:
		inventory.sanity = sanity
		inventory.api = api
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
	if net_sync:
		net_sync.body = self
		net_sync.sprite = sprite


# Editor only, the export if set, otherwise the first child of [param type].
func _pick(current: Node, type: Variant) -> Node:
	return current if current else Component.find_component(self, type)
