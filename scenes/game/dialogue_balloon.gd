# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Dialogue Manager example balloon + [code][#sanity_glitch][/code] tag: text of that line trembles + flickers.
## [code][#jumpscare][/code] tag slams [member jumpscare_texture] over whole screen for a moment.
## Only how it is shown changes, line text stays clean for logs, explain + screen readers.
## Use it rarely, if every line glitches it stops meaning anything.
## [codeblock]
## Fairy: [#sanity_glitch] There you are.
## [/codeblock]
## Tag goes right after character name, as in Dialogue Manager docs. Before [code]Fairy:[/code] it breaks name.
class_name DialogueBalloon
extends DialogueManagerExampleBalloon

const GLITCH_TAG: String = "sanity_glitch"
const JUMPSCARE_TAG: String = "jumpscare"

## Max tilt of glitching text, in degrees.
@export var glitch_angle: float = 0.8
## Max part of alpha flicker takes away. Kept low ∴ it never becomes strobe.
@export_range(0.0, 1.0) var glitch_flicker: float = 0.35
## Seconds between jitters.
@export var glitch_interval: float = 0.08
@export_group("Jumpscare")
## Covers screen on [code][#jumpscare][/code] lines.
@export var jumpscare_texture: Texture2D
## Played w/ it. ∅ = silent.
@export var jumpscare_sound: AudioStream
## Seconds it stays before fading.
@export var jumpscare_duration: float = 0.7
## Max shake in pixels, fades out over [member jumpscare_duration].
@export var jumpscare_shake: float = 40.0

var _is_glitching: bool = false
var _glitch_timer: float = 0.0


func _ready() -> void:
	super()
	responses_menu.child_entered_tree.connect(_on_responses_menu_child_entered_tree)


func apply_dialogue_line() -> void:
	_is_glitching = dialogue_line.has_tag(GLITCH_TAG)
	if not _is_glitching:
		dialogue_label.rotation = 0.0
		dialogue_label.modulate.a = 1.0
	if dialogue_line.has_tag(JUMPSCARE_TAG):
		_play_jumpscare()
	await super()


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	GameLog.write(&"dialogue", "picked", response.text)
	super(response)


# menu sets text, disabled + "response" meta before add_child ∴ all are there now
func _on_responses_menu_child_entered_tree(node: Node) -> void:
	if DebugCommands.explain and node is Button:
		ExplainFeed.annotate_response_button(node as Button, dialogue_resource)


func _process(delta: float) -> void:
	super(delta)
	if not _is_glitching:
		return
	_glitch_timer -= delta
	if _glitch_timer > 0.0:
		return
	_glitch_timer = glitch_interval
	# containers set position + size, not rotation/modulate ∴ these stay
	dialogue_label.pivot_offset = dialogue_label.size / 2.0
	dialogue_label.rotation = deg_to_rad(randf_range(-glitch_angle, glitch_angle))
	dialogue_label.modulate.a = 1.0 - randf() * glitch_flicker


# added last ∴ drawn over balloon, ignores mouse ∴ line can still be clicked through
func _play_jumpscare() -> void:
	if not jumpscare_texture:
		Log.error("jumpscare tag but balloon has no jumpscare_texture")
		return
	var overlay: TextureRect = TextureRect.new()
	overlay.texture = jumpscare_texture
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.pivot_offset = overlay.size / 2.0
	overlay.scale = Vector2.ONE * 1.5
	overlay.modulate = Color(1.0, 0.25, 0.25)
	if jumpscare_sound:
		SoundManager.play_sound(jumpscare_sound)
	var tween: Tween = overlay.create_tween()
	tween.tween_property(overlay, ^"scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(overlay, ^"modulate", Color.WHITE, 0.25)
	tween.parallel().tween_method(_shake_jumpscare.bind(overlay), 1.0, 0.0, jumpscare_duration)
	tween.tween_property(overlay, ^"modulate:a", 0.0, 0.2)
	tween.tween_callback(overlay.queue_free)


func _shake_jumpscare(strength: float, overlay: TextureRect) -> void:
	overlay.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * jumpscare_shake * strength
