# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Owns every component on player [CharacterBody3D] + wires their dependencies
## in [method Node._enter_tree]. This is only wiring site, components never look up
## each other themselves.
##
## Components are found by type among descendants ∴ one of each. Missing one is
## skipped + whoever depends on it reports that in [method Component._on_setup].
## Adding component takes two steps: add node to scene, wire it here.
## [MovementProfile] is [Resource] + cannot be found in tree ∴ it is exported.
## W/o one, movement reports it + stays off.
## Dialogue + interactables only call [member api] methods. Other code (HUD, debug
## commands, [SanityArea]) reads components through it.
class_name PlayerBody
extends CharacterBody3D

## Tuning values given to movement component, see [MovementProfile].
@export var movement_profile: MovementProfile

## Set when body enters tree, see [PlayerApi].
var api: PlayerApi


func _enter_tree() -> void:
	# runs again when body is moved in tree, first wiring still holds
	if api:
		return
	var input: InputComponent = _find_descendant_of_type(InputComponent)
	var movement: Movement3DComponent = _find_descendant_of_type(Movement3DComponent)
	var interaction: InteractionComponent = _find_descendant_of_type(InteractionComponent)
	var animation: AnimationComponent = _find_descendant_of_type(AnimationComponent)
	var sanity: SanityComponent = _find_descendant_of_type(SanityComponent)
	var sanity_visuals: SanityVisualsComponent = _find_descendant_of_type(SanityVisualsComponent)
	var inventory: InventoryComponent = _find_descendant_of_type(InventoryComponent)
	var net_sync: NetSyncComponent = _find_descendant_of_type(NetSyncComponent)
	var sprite: AnimatedSprite3D = _find_descendant_of_type(AnimatedSprite3D)
	api = PlayerApi.new(inventory, sanity)
	add_to_group(PlayerApi.GROUP)

	if sanity and interaction:
		interaction.interact_started.connect(sanity.pause_sanity_drain)
		interaction.interact_ended.connect(sanity.resume_sanity_drain)
	if sanity_visuals:
		sanity_visuals.sanity_component = sanity
	if inventory:
		inventory.sanity_component = sanity
		inventory.api = api
	if movement:
		movement.body = self
		movement.profile = movement_profile
		movement.input_component = input
		movement.interaction_component = interaction
		movement.collision_shape = _find_descendant_of_type(CollisionShape3D)
		movement.state_chart = _find_descendant_of_type(StateChart)
	if interaction:
		interaction.body = self
		interaction.api = api
		interaction.input_component = input
	if animation:
		animation.sprite = sprite
		animation.movement_component = movement
	if net_sync:
		net_sync.body = self
		net_sync.sprite = sprite


func _find_descendant_of_type(type: Variant) -> Node:
	return Component.find_descendant_of_type(self, type)
