# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [SanityComponent] meter: clamping, zones, depleted + drain w/ nested pauses.
## Meter tests use bare component, drain tests add it to tree ∵ drain runs in physics.
## Sanity reads + writes save ∴ [SaveIsolatedTest].
extends SaveIsolatedTest

# drains whole default meter in ≈1.7 s ∴ few frames show it
const DRAIN_PER_SECOND: float = 60.0
const DRAIN_FRAMES: int = 5


#region Meter
func test_value_is_clamped_to_meter() -> void:
	var sanity: SanityComponent = autofree(SanityComponent.new())
	sanity.set_current_sanity_value(150.0)
	assert_eq(sanity.value, sanity.max_sanity)
	sanity.add_sanity(-500.0)
	assert_eq(sanity.value, 0.0)


# default thresholds 0.25, 0.5, 0.75 of 100
func test_zone_follows_thresholds() -> void:
	var sanity: SanityComponent = autofree(SanityComponent.new())
	watch_signals(sanity)
	sanity.set_current_sanity_value(80.0)
	assert_eq(sanity.zone, 3)
	sanity.set_current_sanity_value(30.0)
	assert_eq(sanity.zone, 1)
	sanity.set_current_sanity_value(10.0)
	assert_eq(sanity.zone, 0)
	assert_signal_emit_count(sanity.zone_changed, 3)


func test_depleted_fires_once_at_zero() -> void:
	var sanity: SanityComponent = autofree(SanityComponent.new())
	sanity.set_current_sanity_value(10.0)
	watch_signals(sanity)
	sanity.add_sanity(-20.0)
	sanity.add_sanity(-5.0)
	assert_signal_emit_count(sanity.depleted, 1)


func test_starts_full_without_save() -> void:
	var sanity: SanityComponent = SanityComponent.new()
	add_child_autofree(sanity)
	assert_eq(sanity.value, sanity.max_sanity)
#endregion


#region Drain
func test_drain_lowers_value() -> void:
	var sanity: SanityComponent = _add_draining_sanity()
	await wait_physics_frames(DRAIN_FRAMES)
	assert_lt(sanity.value, sanity.max_sanity)


func test_nested_pauses_need_every_resume() -> void:
	var sanity: SanityComponent = _add_draining_sanity()
	sanity.pause_sanity_drain()
	sanity.pause_sanity_drain()
	sanity.resume_sanity_drain()
	await wait_physics_frames(DRAIN_FRAMES)
	assert_eq(sanity.value, sanity.max_sanity, "1 pause still open")
	sanity.resume_sanity_drain()
	await wait_physics_frames(DRAIN_FRAMES)
	assert_lt(sanity.value, sanity.max_sanity)
#endregion


#region Helpers
func _add_draining_sanity() -> SanityComponent:
	var sanity: SanityComponent = SanityComponent.new()
	sanity.drain_per_second = DRAIN_PER_SECOND
	add_child_autofree(sanity)
	return sanity
#endregion
