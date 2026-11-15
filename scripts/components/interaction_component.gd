# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Finds closest [InteractableThing] in range and runs it on interact press.
## Things with [member InteractableThing.auto] run once when player walks into their
## radius (again after leaving and re-entering) and never lock.
## In range means inside thing zone: [Area3D] sensor on body scans
## [constant InteractableThing.ZONE_LAYER], see [method InteractableThing.get_interactable_from_zone].
## With [member InteractableThing.locks_player] lock lasts until [method InteractableThing.execute_interaction_for_actor]
## returns. Nothing new starts while one is running.
## Lock lives here, not in state chart. Movement and sanity react to
## [signal interact_started] and [signal interact_ended].
## Dependencies (input_component, body, api) are injected by body.
class_name InteractionComponent
extends Component

## Emitted when locking interaction starts.
signal interact_started
## Emitted when locking interaction ends.
signal interact_ended

## Radius of player sensor. Small, so thing zone radius is reach.
const SENSOR_RADIUS: float = 0.05

var input_component: InputComponent
var body: Node3D
## Passed to [method InteractableThing.execute_interaction_for_actor].
var api: PlayerApi

## True during locking interaction.
var is_locked: bool = false

var _busy: bool = false
var _sensor: Area3D


func _physics_process(_delta: float) -> void:
	# No sensor until _on_setup, which is deferred.
	if is_locked or _busy or not _sensor:
		return
	if input_component.get_frame().interact_pressed:
		await _interact_with_nearest_interactable()


func _on_setup() -> void:
	if not _require_dependencies({ "body": body, "input_component": input_component, "api": api }):
		set_physics_process(false)
		return
	_add_interaction_sensor()


# Child of body, not of this component: plain Node has no transform to follow.
func _add_interaction_sensor() -> void:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = SENSOR_RADIUS
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	_sensor = Area3D.new()
	_sensor.name = "InteractionSensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = InteractableThing.ZONE_LAYER
	_sensor.monitorable = false
	_sensor.add_child(collision)
	_sensor.area_entered.connect(_on_interaction_zone_entered)
	body.add_child(_sensor)


#region Interaction
func _interact_with_nearest_interactable() -> void:
	var target: InteractableThing = _find_nearest_interactable()
	if not target:
		return
	var locks: bool = target.locks_player
	_busy = true
	if locks:
		_set_interaction_locked(true)
	await target.execute_interaction_for_actor(api)
	# Press that closed dialogue can still be latched as press. Wait it
	# out so it does not restart interaction.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if locks:
		_set_interaction_locked(false)
	_busy = false


# Closest press-to-interact thing whose zone sensor is in.
func _find_nearest_interactable() -> InteractableThing:
	var closest: InteractableThing = null
	var closest_dist_sq: float = INF
	var origin: Vector3 = body.global_position
	for zone: Area3D in _sensor.get_overlapping_areas():
		var thing: InteractableThing = InteractableThing.get_interactable_from_zone(zone)
		if not thing or not thing.enabled or thing.auto:
			continue
		var dist_sq: float = origin.distance_squared_to(thing.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = thing
	return closest


func _on_interaction_zone_entered(zone: Area3D) -> void:
	if is_locked:
		return
	var thing: InteractableThing = InteractableThing.get_interactable_from_zone(zone)
	if thing and thing.enabled and thing.auto:
		# Auto things never lock, so waiting here blocks nothing.
		await thing.execute_interaction_for_actor(api)
#endregion


#region Lock
func _set_interaction_locked(value: bool) -> void:
	is_locked = value
	if value:
		interact_started.emit()
	else:
		interact_ended.emit()
#endregion
