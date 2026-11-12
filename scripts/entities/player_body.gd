@tool
# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Owns every component on the player [CharacterBody3D] and wires their dependencies
## in [method Node._enter_tree]. This is the only wiring site, components never look up
## their siblings themselves.
##
## The slots are filled in the editor with [member fill_components] and saved in the scene,
## nothing is searched at runtime. An empty slot means the component is absent.
## A component that is in the scene but not in a slot gets no dependencies and reports
## that itself in [method Component._on_setup].
## [MovementProfile] is a [Resource] and cannot be found in the tree, so a fresh
## instance is used when none is exported.
## Dialogue, interactables and debug commands use [member api], never the components.
## [b]Note:[/b] This is a [code]@tool[/code] script only for [member fill_components].
## Wiring is skipped in the editor, see [method Node._enter_tree].
class_name PlayerBody
extends CharacterBody3D

## Editor only. Fills every empty slot below from the children.
@export_tool_button("Fill components") var fill_components: Callable = _fill_exports

@export_group("Components")
@export var input: InputComponent
@export var facing: FacingComponent
@export var movement: Movement3DComponent
@export var interaction: InteractionComponent
@export var animation: AnimationComponent
@export var sanity: SanityComponent
@export var inventory: InventoryComponent
@export var net_sync: NetSyncComponent
@export_group("Data")
@export var movement_profile: MovementProfile

@export_group("Scene Nodes")
@export var sprite: AnimatedSprite3D
@export var collision_shape: CollisionShape3D
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
	movement = _pick(movement, Movement3DComponent)
	interaction = _pick(interaction, InteractionComponent)
	animation = _pick(animation, AnimationComponent)
	sanity = _pick(sanity, SanityComponent)
	inventory = _pick(inventory, InventoryComponent)
	net_sync = _pick(net_sync, NetSyncComponent)
	sprite = _pick(sprite, AnimatedSprite3D)
	collision_shape = _pick(collision_shape, CollisionShape3D)
	state_chart = _pick(state_chart, StateChart)
	# Looked up by name, a direct EditorInterface reference fails to parse in exported builds.
	Engine.get_singleton(&"EditorInterface").mark_scene_as_unsaved()


func _wire_components() -> void:
	if not movement_profile:
		movement_profile = MovementProfile.new()
	api = PlayerApi.new(inventory, sanity)
	add_to_group(PlayerApi.GROUP)

	if sanity:
		sanity.interact_component = interaction
	if inventory:
		inventory.sanity = sanity
		inventory.api = api
	if movement:
		movement.body = self
		movement.profile = movement_profile
		movement.input_component = input
		movement.facing_component = facing
		movement.interact_component = interaction
		movement.collision_shape = collision_shape
		movement.state_chart = state_chart
	if interaction:
		interaction.body = self
		interaction.api = api
		interaction.input_component = input
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
