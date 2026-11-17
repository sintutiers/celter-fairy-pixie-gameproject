# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Shows sanity loss on screen: greys, darkens and warps view per sanity zone, and shakes 3D camera.
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
## How far camera sways at full strength, in metres. 0 = no shake.
@export var shake_distance: float = 0.04
## Higher = faster sway.
@export var shake_speed: float = 5.0

var sanity_component: SanityComponent

var _material: ShaderMaterial = ShaderMaterial.new()
var _tween: Tween


func _on_ready() -> void:
	_material.shader = SHADER
	# Unset parameter reads back as null, _process needs number.
	_material.set_shader_parameter(&"strength", 0.0)
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


# Through camera offsets, not its transform: camera addon owns transform and
# only writes offsets while it blends between cameras.
func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return
	var strength: float = _material.get_shader_parameter(&"strength")
	var reach: float = shake_distance * strength
	var time: float = Time.get_ticks_msec() / 1000.0 * shake_speed
	# Two speeds that never line up, so sway does not visibly repeat.
	camera.h_offset = sin(time) * reach
	camera.v_offset = sin(time * 1.3) * reach
	# Sleeps at full sanity, after offsets are back at 0. Zone change wakes it.
	set_process(reach > 0.0 or (_tween != null and _tween.is_running()))


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
	set_process(true)
