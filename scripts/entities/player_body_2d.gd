# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## 2D twin of [PlayerBody]: owns every component on player [CharacterBody2D] and wires
## their dependencies in [method Node._enter_tree]. Same rules, see [PlayerBody].
##
## No interaction yet, [InteractionComponent] is 3D only.
class_name PlayerBody2D
extends CharacterBody2D

@export var movement_profile: MovementProfile

## Set when body enters tree, see [PlayerApi].
var api: PlayerApi


func _enter_tree() -> void:
	# Runs again when body is moved in tree. First wiring still holds.
	if api:
		return
	var input: InputComponent = _find(InputComponent)
	var facing: FacingComponent = _find(FacingComponent)
	var movement: Movement2DComponent = _find(Movement2DComponent)
	var animation: AnimationComponent = _find(AnimationComponent)
	var sanity: SanityComponent = _find(SanityComponent)
	var sanity_visuals: SanityVisualsComponent = _find(SanityVisualsComponent)
	var inventory: InventoryComponent = _find(InventoryComponent)
	var net_sync: NetSyncComponent = _find(NetSyncComponent)
	var sprite: AnimatedSprite2D = _find(AnimatedSprite2D)
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
		movement.facing_component = facing
		movement.collision_shape = _find(CollisionShape2D)
		movement.state_chart = _find(StateChart)
	if animation:
		animation.sprite = sprite
		animation.movement_component = movement
		animation.facing_component = facing
	if net_sync:
		net_sync.body = self
		net_sync.sprite = sprite


func _find(type: Variant) -> Node:
	return Component.find_component(self, type)
