# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Safe space: sanity does not drain while player is inside.
## Needs [CollisionShape3D] child and mask on physics layer 2 ("player").
## @experimental: Placeholder until FDD decides how safe spaces work.
class_name Sanctuary
extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var sanity: SanityComponent = _sanity_of(body)
	if sanity:
		sanity.pause()


func _on_body_exited(body: Node3D) -> void:
	var sanity: SanityComponent = _sanity_of(body)
	if sanity:
		sanity.unpause()


# Through api, same as PlayerApi.find, so body can be any player body.
func _sanity_of(body: Node3D) -> SanityComponent:
	var api: PlayerApi = body.get(&"api") as PlayerApi
	if not api or not api.sanity:
		push_error("%s: %s has no SanityComponent, drain not paused" % [name, body.name])
		return null
	return api.sanity
