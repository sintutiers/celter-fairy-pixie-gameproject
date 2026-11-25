# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Sanity meter. Changes through [method add_sanity]/flat [member drain_per_second].
## Drain stops through [method pause_sanity_drain]: locking interactions pause it
## ([signal InteractionComponent.interact_started], wired by [PlayerBody]),
## [SanityArea] while player is inside.
## Value is kept in save, see [method GameState.mirror_sanity] ∴ it survives level changes + restarts.
## W/o game state it starts at [member max_sanity] every time.
class_name SanityComponent
extends Component

## Emitted on every change, also after saved value loaded.
signal changed(value: float, ratio: float)
## Emitted when ratio crosses one of [member thresholds], up/down.
signal zone_changed(zone: int)
## Emitted when value hits 0.
signal depleted

## Top of meter, also start value when ∅ is saved.
@export var max_sanity: float = 100.0
## 0 = no drain.
@export var drain_per_second: float = 0.0
## Ratios (0 to 1, ascending) that split meter into zones.
@export var thresholds: PackedFloat32Array = PackedFloat32Array([0.25, 0.5, 0.75])

## Current sanity. Read only, change it through [method add_sanity]/[method set_current_sanity_value].
var value: float
## Number of [member thresholds] ratio is at/above. 0 = lowest zone.
var zone: int = 0

var _pause_count: int = 0


func _physics_process(delta: float) -> void:
	if _pause_count > 0 or drain_per_second <= 0.0:
		return
	add_sanity(-drain_per_second * delta)


## Returns value / max_sanity, from 0 to 1.
func get_current_sanity_ratio() -> float:
	return value / max_sanity


## Adds [param amount] (negative drains), clamped to 0 + [member max_sanity].
func add_sanity(amount: float) -> void:
	set_current_sanity_value(value + amount)


## Pauses drain. Balance w/ [method resume_sanity_drain], safe to nest.
func pause_sanity_drain() -> void:
	_pause_count += 1


## Resumes drain once every caller has called [method resume_sanity_drain].
## Pushes error when called more often than [method pause_sanity_drain].
func resume_sanity_drain() -> void:
	if _pause_count == 0:
		Log.error("%s: resume_sanity_drain without matching pause_sanity_drain" % name)
		return
	_pause_count -= 1


## Sets meter to [param new_value], clamped to 0 + [member max_sanity].
## Mirrors it into save + emits [signal changed] +
## [signal zone_changed] + [signal depleted] when they apply. Same value does ∅.
func set_current_sanity_value(new_value: float) -> void:
	new_value = clampf(new_value, 0.0, max_sanity)
	# exact on purpose: is_equal_approx scales w/ value + swallows slow drain
	if new_value == value:
		return
	value = new_value
	# only mirrored: drain changes it every physics frame, file written in _exit_tree
	GameState.mirror_sanity(value)
	changed.emit(value, get_current_sanity_ratio())

	var new_zone: int = _get_sanity_zone_for_ratio(get_current_sanity_ratio())
	if new_zone != zone:
		zone = new_zone
		GameLog.write(&"sanity", "zone", zone, "at", "%.1f" % value)
		zone_changed.emit(zone)

	if value <= 0.0:
		GameLog.write(&"sanity", "depleted")
		depleted.emit()


func _on_ready() -> void:
	# here, not _on_setup: ratio below divides by it
	if max_sanity <= 0.0:
		Log.error("%s: max_sanity must be above 0, is %s" % [name, max_sanity])
	value = max_sanity
	var saved: float = GameState.get_saved_sanity(max_sanity)
	# placeholder until FDD decides what sanity 0 does: level lost, restart refills
	# loading 0 would restart into meter that can never deplete again
	if saved > 0.0:
		value = minf(saved, max_sanity)
	zone = _get_sanity_zone_for_ratio(get_current_sanity_ratio())
	changed.emit(value, get_current_sanity_ratio())


func _on_setup() -> void:
	var ascending: PackedFloat32Array = thresholds.duplicate()
	ascending.sort()
	if ascending != thresholds:
		Log.error("%s: thresholds must be ascending, zones are wrong" % name)


# level change, restart + quit all free player ∴ this covers them
func _exit_tree() -> void:
	GameState.save()


# index after last threshold at/below ratio ∴ thresholds must be ascending
func _get_sanity_zone_for_ratio(ratio: float) -> int:
	return thresholds.bsearch(ratio, false)
