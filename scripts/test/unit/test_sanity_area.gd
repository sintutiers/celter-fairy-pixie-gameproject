# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [SanityArea] pauses drain only while player is inside + gives first entry bonus once,
## also after reload w/ [member SanityArea.persistent_id]. Player is driven through
## body_entered + body_exited ∴ no physics overlap needed. Entry is saved ∴ [SaveIsolatedTest].
extends SaveIsolatedTest

# uid:// key is used as is ∴ needs no real level scene
const LEVEL_PATH: String = "uid://test_level"
const START_SANITY: float = 50.0
const DRAIN_FRAMES: int = 5

var _sanity: SanityComponent
var _body: PlayerBody


#region Setup/Teardown
# body not in tree ∴ it wires ∅, only carries api area looks up
func before_each() -> void:
	super()
	_sanity = SanityComponent.new()
	add_child_autofree(_sanity)
	_sanity.set_current_sanity_value(START_SANITY)
	_body = autofree(PlayerBody.new())
	_body.api = PlayerApi.new(null, _sanity)
#endregion


#region Tests
func test_first_entry_bonus_is_given_once() -> void:
	var area: SanityArea = _add_area("")
	area.body_entered.emit(_body)
	area.body_exited.emit(_body)
	area.body_entered.emit(_body)
	assert_eq(_sanity.value, START_SANITY + area.first_entry_sanity)


func test_bonus_stays_used_after_reload_with_persistent_id() -> void:
	GameState.start_game()
	GameState.set_current_level_path(LEVEL_PATH)
	var area: SanityArea = _add_area("test_spring")
	area.body_entered.emit(_body)
	area.body_exited.emit(_body)
	# same area in level loaded again, after game restart
	GameState.unload()
	var reloaded: SanityArea = _add_area("test_spring")
	reloaded.body_entered.emit(_body)
	assert_eq(_sanity.value, START_SANITY + area.first_entry_sanity)


func test_drain_is_paused_only_while_inside() -> void:
	_sanity.drain_per_second = 60.0
	var area: SanityArea = _add_area("")
	area.first_entry_sanity = 0.0
	area.body_entered.emit(_body)
	var inside_value: float = _sanity.value
	await wait_physics_frames(DRAIN_FRAMES)
	assert_eq(_sanity.value, inside_value, "paused inside")
	area.body_exited.emit(_body)
	await wait_physics_frames(DRAIN_FRAMES)
	assert_lt(_sanity.value, inside_value, "drains again outside")
#endregion


#region Helpers
# shape + player layer ∴ area passes its own load check
func _add_area(persistent_id: String) -> SanityArea:
	var area: SanityArea = SanityArea.new()
	area.collision_mask = SanityArea.PLAYER_LAYER
	area.persistent_id = persistent_id
	area.add_child(CollisionShape3D.new())
	add_child_autofree(area)
	return area
#endregion
