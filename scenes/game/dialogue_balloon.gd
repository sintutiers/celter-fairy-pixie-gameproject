# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Dialogue Manager example balloon + [code][#sanity_glitch][/code] tag: text of that line trembles and flickers.
## Only how it is shown changes, line text stays clean for logs, explain and screen readers.
## Use it rarely, if every line glitches it stops meaning anything.
## [codeblock]
## Fairy: [#sanity_glitch] There you are.
## [/codeblock]
## Tag goes right after character name, as in Dialogue Manager docs. Before [code]Fairy:[/code] it breaks the name.
class_name DialogueBalloon
extends DialogueManagerExampleBalloon

const GLITCH_TAG: String = "sanity_glitch"

## Max tilt of glitching text, in degrees.
@export var glitch_angle: float = 0.8
## Max part of alpha a flicker takes away. Kept low, so it never becomes a strobe.
@export_range(0.0, 1.0) var glitch_flicker: float = 0.35
## Seconds between jitters.
@export var glitch_interval: float = 0.08

var _glitching: bool = false
var _glitch_timer: float = 0.0


func apply_dialogue_line() -> void:
	_glitching = dialogue_line.has_tag(GLITCH_TAG)
	if not _glitching:
		dialogue_label.rotation = 0.0
		dialogue_label.modulate.a = 1.0
	await super()


func _process(delta: float) -> void:
	super(delta)
	if not _glitching:
		return
	_glitch_timer -= delta
	if _glitch_timer > 0.0:
		return
	_glitch_timer = glitch_interval
	# Containers set position + size, not rotation or modulate, so these stay.
	dialogue_label.pivot_offset = dialogue_label.size / 2.0
	dialogue_label.rotation = deg_to_rad(randf_range(-glitch_angle, glitch_angle))
	dialogue_label.modulate.a = 1.0 - randf() * glitch_flicker
