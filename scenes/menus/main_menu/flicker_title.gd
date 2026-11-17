# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Project name that every few seconds twitches sideways, turns red + some letters swap, then snaps back.
## Root is plain Control, not Container, or Container would undo the twitch.
class_name FlickerTitle
extends Control

# Swaps to letters, not symbols, so it looks misread instead of hacked.
const CORRUPT_CHARACTERS: String = "abcdefghijklmnopqrstuvwxyz"

@export var min_wait: float = 3.0
@export var max_wait: float = 8.0
## Furthest label moves sideways, in pixels.
@export var max_offset: float = 6.0
## Chance per letter of being swapped during flicker.
@export_range(0.0, 1.0) var corrupt_chance: float = 0.15
@export var flicker_color: Color = Color(0.9, 0.3, 0.4)

var _tween: Tween

@onready var _label: Label = $Label


func _ready() -> void:
	_queue_flicker()


func _queue_flicker() -> void:
	_tween = create_tween()
	_tween.tween_interval(randf_range(min_wait, max_wait))
	_tween.tween_callback(_flicker)


func _flicker() -> void:
	# Read at each flicker, so text set by config name label is kept.
	var clean_text: String = _label.text
	var rest_position: Vector2 = _label.position
	_tween = create_tween()
	for i: int in randi_range(2, 4):
		_tween.tween_callback(_twitch.bind(clean_text, rest_position))
		_tween.tween_interval(randf_range(0.03, 0.08))
	_tween.tween_callback(_restore.bind(clean_text, rest_position))
	_tween.tween_callback(_queue_flicker)


func _twitch(clean_text: String, rest_position: Vector2) -> void:
	_label.position = rest_position + Vector2(randf_range(-max_offset, max_offset), 0.0)
	_label.modulate = flicker_color
	_label.text = _corrupt(clean_text)


func _restore(clean_text: String, rest_position: Vector2) -> void:
	_label.position = rest_position
	_label.modulate = Color.WHITE
	_label.text = clean_text


func _corrupt(clean_text: String) -> String:
	var corrupted: String = ""
	for character: String in clean_text:
		if character != " " and randf() < corrupt_chance:
			corrupted += CORRUPT_CHARACTERS[randi() % CORRUPT_CHARACTERS.length()]
		else:
			corrupted += character
	return corrupted
