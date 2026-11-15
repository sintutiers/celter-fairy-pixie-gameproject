# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Shows sanity loss on screen: greys and darkens view per sanity zone.
## Listens to [signal SanityComponent.zone_changed], so meter knows nothing about visuals.
## Sound and enemy reactions belong in their own listeners, not here.
## @experimental: Placeholder look until art direction is decided.
class_name SanityVisualsComponent
extends Component

const SHADER: Shader = preload("res://scripts/components/sanity_visuals.gdshader")

## Effect strength (0 to 1) per zone, index = [member SanityComponent.zone].
## Needs one entry more than [member SanityComponent.thresholds].
@export var strength_per_zone: PackedFloat32Array = PackedFloat32Array([1.0, 0.6, 0.3, 0.0])
## Seconds to fade from one zone strength to next.
@export var fade_time: float = 1.5

var sanity_component: SanityComponent

var _material: ShaderMaterial = ShaderMaterial.new()
var _tween: Tween


func _on_ready() -> void:
	_material.shader = SHADER
	var rect: ColorRect = ColorRect.new()
	rect.material = _material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer: CanvasLayer = CanvasLayer.new()
	# Over world, under HUD (layer 1) and dialogue balloon (layer 100).
	layer.layer = 0
	layer.add_child(rect)
	add_child(layer)


func _on_setup() -> void:
	if not _require_dependencies({ "sanity_component": sanity_component }):
		return
	if strength_per_zone.size() != sanity_component.thresholds.size() + 1:
		Log.error(
			"%s: strength_per_zone needs %d entries, has %d"
			% [name, sanity_component.thresholds.size() + 1, strength_per_zone.size()],
		)
		return
	_material.set_shader_parameter(&"strength", strength_per_zone[sanity_component.zone])
	sanity_component.zone_changed.connect(_on_sanity_zone_changed)


func _on_sanity_zone_changed(zone: int) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(
		_material,
		"shader_parameter/strength",
		strength_per_zone[zone],
		fade_time,
	)
