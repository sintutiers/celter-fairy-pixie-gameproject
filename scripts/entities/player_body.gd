# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Owns every component on the player [CharacterBody3D] and wires their dependencies
## in [method Node._enter_tree]. This is the only wiring site, components never look up
## their siblings themselves.
##
## Components are found by type among the descendants, so one of each. A missing one is
## skipped, and whoever depends on it reports that in [method Component._on_setup].
## Adding a component takes two steps: add the node to the scene, wire it here.
## [MovementProfile] is a [Resource] and cannot be found in the tree, so a fresh
## instance is used when none is exported.
## Dialogue, interactables and debug commands use [member api], never the components.
class_name PlayerBody
extends CharacterBody3D

@export var movement_profile: MovementProfile

## Set when the body enters the tree, see [PlayerApi].
var api: PlayerApi


func _enter_tree() -> void:
	if not movement_profile:
		movement_profile = MovementProfile.new()
	var input: InputComponent = _find(InputComponent)
	var facing: FacingComponent = _find(FacingComponent)
	var movement: Movement3DComponent = _find(Movement3DComponent)
	var interaction: InteractionComponent = _find(InteractionComponent)
	var animation: AnimationComponent = _find(AnimationComponent)
	var sanity: SanityComponent = _find(SanityComponent)
	var sanity_visuals: SanityVisualsComponent = _find(SanityVisualsComponent)
	var inventory: InventoryComponent = _find(InventoryComponent)
	var net_sync: NetSyncComponent = _find(NetSyncComponent)
	var sprite: AnimatedSprite3D = _find(AnimatedSprite3D)
	api = PlayerApi.new(inventory, sanity)
	add_to_group(PlayerApi.GROUP)

	if sanity:
		sanity.interact_component = interaction
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
		movement.interact_component = interaction
		movement.collision_shape = _find(CollisionShape3D)
		movement.state_chart = _find(StateChart)
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


func _find(type: Variant) -> Node:
	return Component.find_component(self, type)
