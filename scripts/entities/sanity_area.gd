# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Area that changes sanity drain while player is inside. Defaults make sanctuary:
## drain paused + first entry restores [member first_entry_sanity], once /area.
## W/ [member pauses_drain] off + [member extra_drain_per_second] set it is
## thing that eats sanity when player is close.
## Needs [CollisionShape3D] child + mask on physics layer 2 ("player").
class_name SanityArea
extends Area3D

## Physics layer 2 ("player"), must be in [member CollisionObject3D.collision_mask].
const PLAYER_LAYER: int = 1 << 1

## Stops sanity drain while inside, see [method SanityComponent.pause_sanity_drain].
@export var pauses_drain: bool = true
## Added to [member SanityComponent.drain_per_second] while inside. Pauses w/ normal
## drain ∴ sanctuary + locking interactions stop it too.
@export var extra_drain_per_second: float = 0.0
## Added to sanity on first entry. 0 = ∅.
@export var first_entry_sanity: float = 10.0
## Saves first entry /level in [LevelState] ∴ it stays used after reload.
## Must be unique within level. ∅ = used again every time level loads.
@export var persistent_id: String = ""

# also covers play w/o game state, where ∅ is saved
var _has_been_entered: bool = false


func _ready() -> void:
	GameState.check_persistent_id_is_unique(self, persistent_id)
	# w/o shape/player layer player never enters + area does ∅
	if not get_children().any(func(child: Node) -> bool: return child is CollisionShape3D or child is CollisionPolygon3D):
		Log.error("%s: no CollisionShape3D child, player never enters" % name)
	if collision_mask & PLAYER_LAYER == 0:
		Log.error("%s: collision_mask misses player layer 2, player never enters" % name)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var sanity: SanityComponent = _get_sanity_component_of_body(body)
	if not sanity:
		return
	if pauses_drain:
		sanity.pause_sanity_drain()
	sanity.drain_per_second += extra_drain_per_second
	GameLog.write(&"sanity", "entered", str(name), "drain per second", sanity.drain_per_second)
	_restore_sanity_on_first_entry(sanity)


func _on_body_exited(body: Node3D) -> void:
	var sanity: SanityComponent = _get_sanity_component_of_body(body)
	if not sanity:
		return
	if pauses_drain:
		sanity.resume_sanity_drain()
	sanity.drain_per_second -= extra_drain_per_second
	GameLog.write(&"sanity", "left", str(name), "drain per second", sanity.drain_per_second)


func _restore_sanity_on_first_entry(sanity: SanityComponent) -> void:
	if _has_been_entered or first_entry_sanity == 0.0:
		return
	_has_been_entered = true
	if persistent_id != "" and GameState.has_game_state():
		var level_path: String = GameState.get_placed_level_path(self)
		if GameState.get_level_flag(level_path, get_entered_flag_key()):
			return
		GameState.set_level_flag(level_path, get_entered_flag_key())
	GameLog.write(&"sanity", "first entry of", str(name), first_entry_sanity)
	sanity.add_sanity(first_entry_sanity)


# old class name stays in key: changing it breaks saves
## Level flag set on first entry, see [member persistent_id].
func get_entered_flag_key() -> String:
	return "sanctuary." + persistent_id


# through api like PlayerApi.find_local_player_api ∴ body can be any player body
func _get_sanity_component_of_body(body: Node3D) -> SanityComponent:
	var api: PlayerApi = body.get(&"api")
	if not api or not api.sanity:
		Log.error("%s: %s has no SanityComponent, area does nothing" % [name, body.name])
		return null
	return api.sanity
