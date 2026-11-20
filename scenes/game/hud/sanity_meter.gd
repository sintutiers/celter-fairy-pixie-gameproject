# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Sanity of local player as bar, colored /zone. HUD widget, works alone.
class_name SanityMeter
extends ProgressBar

## Fill color /[member SanityComponent.zone], 0 = lowest. Zones past end use last color.
@export var zone_colors: PackedColorArray = PackedColorArray([
	Color(0.55, 0.05, 0.12),
	Color(0.7, 0.35, 0.2),
	Color(0.7, 0.68, 0.5),
	Color(0.8, 0.86, 0.92),
])
## Recolored by zone. Own copy /instance, see resource_local_to_scene in scene.
@export var fill_style: StyleBoxFlat


func _ready() -> void:
	var api: PlayerApi = PlayerApi.find_local_player_api(get_tree())
	if not api or not api.sanity:
		Log.error("%s: no player with SanityComponent in scene" % name)
		hide()
		return
	api.sanity.changed.connect(_on_sanity_changed)
	api.sanity.zone_changed.connect(_on_sanity_zone_changed)
	# player ready before this already sent its load signal
	_on_sanity_changed(api.sanity.value, api.sanity.get_current_sanity_ratio())
	_on_sanity_zone_changed(api.sanity.zone)


func _on_sanity_changed(_value: float, ratio: float) -> void:
	value = ratio


func _on_sanity_zone_changed(zone: int) -> void:
	if zone_colors.is_empty() or not fill_style:
		return
	fill_style.bg_color = zone_colors[mini(zone, zone_colors.size() - 1)]
