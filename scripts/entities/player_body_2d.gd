# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## 2D twin of [PlayerBody]: owns every component on player [CharacterBody2D] + wires
## their dependencies in [method Node._enter_tree]. Same rules, see [PlayerBody].
##
## No interaction yet, [InteractionComponent] is 3D only.
class_name PlayerBody2D
extends CharacterBody2D

## Tuning values given to movement component, see [MovementProfile].
@export var movement_profile: MovementProfile

## Set when body enters tree, see [PlayerApi].
var api: PlayerApi


func _enter_tree() -> void:
	# runs again when body is moved in tree, first wiring still holds
	if api:
		return
	var input: InputComponent = _find_descendant_of_type(InputComponent)
	var movement: Movement2DComponent = _find_descendant_of_type(Movement2DComponent)
	var animation: AnimationComponent = _find_descendant_of_type(AnimationComponent)
	var sanity: SanityComponent = _find_descendant_of_type(SanityComponent)
	var sanity_visuals: SanityVisualsComponent = _find_descendant_of_type(SanityVisualsComponent)
	var inventory: InventoryComponent = _find_descendant_of_type(InventoryComponent)
	var net_sync: NetSyncComponent = _find_descendant_of_type(NetSyncComponent)
	var sprite: AnimatedSprite2D = _find_descendant_of_type(AnimatedSprite2D)
	api = PlayerApi.new(inventory, sanity)
	add_to_group(PlayerApi.GROUP)

	if sanity_visuals:
		sanity_visuals.sanity_component = sanity
	if inventory:
		inventory.sanity_component = sanity
		inventory.api = api
	if movement:
		movement.body = self
		movement.profile = movement_profile
		movement.input_component = input
		movement.collision_shape = _find_descendant_of_type(CollisionShape2D)
		movement.state_chart = _find_descendant_of_type(StateChart)
	if animation:
		animation.sprite = sprite
		animation.movement_component = movement
	if net_sync:
		net_sync.body = self
		net_sync.sprite = sprite


func _find_descendant_of_type(type: Variant) -> Node:
	return Component.find_descendant_of_type(self, type)
