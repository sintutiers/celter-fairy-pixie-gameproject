# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Owns every component on player [CharacterBody3D] and wires their dependencies
## in [method Node._enter_tree]. This is only wiring site, components never look up
## each other themselves.
##
## Components are found by type among descendants, so one of each. Missing one is
## skipped, and whoever depends on it reports that in [method Component._on_setup].
## Adding component takes two steps: add node to scene, wire it here.
## [MovementProfile] is [Resource] and cannot be found in tree, so it is exported.
## Without one, movement reports it and stays off.
## Dialogue and interactables only call [member api] methods. Other code (HUD, debug
## commands, [Sanctuary]) reads components through it.
class_name PlayerBody
extends CharacterBody3D

@export var movement_profile: MovementProfile

## Set when body enters tree, see [PlayerApi].
var api: PlayerApi


func _enter_tree() -> void:
	# Runs again when body is moved in tree. First wiring still holds.
	if api:
		return
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

	if sanity and interaction:
		interaction.interact_started.connect(sanity.pause)
		interaction.interact_ended.connect(sanity.unpause)
	if sanity_visuals:
		sanity_visuals.sanity_component = sanity
	if inventory:
		inventory.sanity_component = sanity
		inventory.api = api
	if movement:
		movement.body = self
		movement.profile = movement_profile
		movement.input_component = input
		movement.facing_component = facing
		movement.interaction_component = interaction
		movement.collision_shape = _find(CollisionShape3D)
		movement.state_chart = _find(StateChart)
	if interaction:
		interaction.body = self
		interaction.api = api
		interaction.input_component = input
	if animation:
		animation.sprite = sprite
		animation.movement_component = movement
		animation.facing_component = facing
	if net_sync:
		net_sync.body = self
		net_sync.sprite = sprite


func _find(type: Variant) -> Node:
	return Component.find_component(self, type)
