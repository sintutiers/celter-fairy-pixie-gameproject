# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Finds the closest [InteractableThing] in range and runs it on interact press.
## Things with [member InteractableThing.auto] run once when the player walks into their
## radius (again after leaving and re-entering) and never lock.
## In range means inside the thing's zone: an [Area3D] sensor on the body scans
## [constant InteractableThing.ZONE_LAYER], see [method InteractableThing.from_zone].
## With [member InteractableThing.locks_player] the lock lasts until [method InteractableThing.run]
## returns. Nothing new starts while one is running.
## The lock lives here, not in the state chart. Movement and sanity listen to
## [signal interact_started], [signal interact_ended] and [member is_locked].
## Dependencies (input_component, body, api) are injected by the body.
class_name InteractionComponent
extends Component

## Emitted when a locking interaction starts.
signal interact_started
## Emitted when a locking interaction ends.
signal interact_ended

## Radius of the player's sensor. Small, so the thing's zone radius is the reach.
const SENSOR_RADIUS: float = 0.05

var input_component: InputComponent
var body: Node3D
## Passed to [method InteractableThing.run].
var api: PlayerApi

## True during a locking interaction.
var is_locked: bool = false

var _busy: bool = false
var _sensor: Area3D


func _physics_process(_delta: float) -> void:
	# No sensor until _on_setup, which is deferred.
	if is_locked or _busy or not _sensor:
		return
	if input_component.get_frame().interact_pressed:
		_interact()


func _on_setup() -> void:
	if not _require({ "body": body, "input_component": input_component, "api": api }):
		set_physics_process(false)
		return
	_add_sensor()


# Child of the body, not of this component: a plain Node has no transform to follow.
func _add_sensor() -> void:
	var shape := SphereShape3D.new()
	shape.radius = SENSOR_RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_sensor = Area3D.new()
	_sensor.name = "InteractionSensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = InteractableThing.ZONE_LAYER
	_sensor.monitorable = false
	_sensor.add_child(collision)
	_sensor.area_entered.connect(_on_zone_entered)
	body.add_child(_sensor)


#region Interaction
func _interact() -> void:
	var target: InteractableThing = _find_closest()
	if not target:
		return
	var locks: bool = target.locks_player
	_busy = true
	if locks:
		_set_locked(true)
	await target.run(api)
	# The press that closed the dialogue can still be latched as a press. Wait it
	# out so it does not restart the interaction.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if locks:
		_set_locked(false)
	_busy = false


# Closest press-to-interact thing whose zone the sensor is in.
func _find_closest() -> InteractableThing:
	var closest: InteractableThing = null
	var closest_dist_sq: float = INF
	var origin: Vector3 = body.global_position
	for zone: Area3D in _sensor.get_overlapping_areas():
		var thing: InteractableThing = InteractableThing.from_zone(zone)
		if not thing or not thing.enabled or thing.auto:
			continue
		var dist_sq: float = origin.distance_squared_to(thing.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = thing
	return closest


func _on_zone_entered(zone: Area3D) -> void:
	if is_locked:
		return
	var thing: InteractableThing = InteractableThing.from_zone(zone)
	if thing and thing.enabled and thing.auto:
		# Not awaited, auto things never lock.
		thing.run(api)
#endregion


#region Lock
func _set_locked(value: bool) -> void:
	is_locked = value
	if value:
		interact_started.emit()
	else:
		interact_ended.emit()
#endregion
