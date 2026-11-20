# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## While console [code]explain[/code] is on ([member DebugCommands.explain]) shows what just happened:
## every sanity, inventory + ledger change ([signal GameLog.wrote]), design notes written as
## [code]##[/code] doc comments above dialogue lines + options, + condition of every locked option.
## ∴ .dialogue files hold only dialogue, logic + notes.
## [codeblock]
## ## 3 ways to open gate: bread, jar, debt.
## Tree: Bread. Table. Behind you.
## [/codeblock]
class_name ExplainFeed
extends Label

## Only these channels are shown, rest is not something dialogue does.
const CHANNELS: Array[StringName] = [&"sanity", &"inventory", &"ledger"]

## Oldest lines drop off past this.
@export var max_lines: int = 8
## Seconds after last new line until feed has faded out.
@export var fade_time: float = 8.0

var _lines: PackedStringArray = []
# doc comments are only in resource, not on DialogueLine/DialogueResponse
var _resource: DialogueResource
var _tween: Tween


func _ready() -> void:
	text = ""
	GameLog.wrote.connect(_on_game_log_wrote)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.got_dialogue.connect(_on_got_dialogue)
	# responses menu has no signal for its buttons ∴ they are changed as they are added
	get_tree().node_added.connect(_on_node_added)


func _on_game_log_wrote(channel: StringName, written: String) -> void:
	if DebugCommands.explain and channel in CHANNELS:
		_add_feed_line("%s: %s" % [channel, written])


func _on_dialogue_started(resource: DialogueResource) -> void:
	_resource = resource


func _on_got_dialogue(line: DialogueLine) -> void:
	var notes: String = _get_notes_for_line_id(line.id)
	if DebugCommands.explain and notes != "":
		_add_feed_line("note: " + notes)


# menu sets text, disabled + "response" meta before add_child ∴ all are there now
func _on_node_added(node: Node) -> void:
	var button: Button = node as Button
	if not DebugCommands.explain or not button or not button.has_meta(&"response"):
		return
	var response: DialogueResponse = button.get_meta(&"response")
	if not response.is_allowed:
		button.text += "  [needs %s]" % response.condition_as_text
	var notes: String = _get_notes_for_line_id(response.id)
	if notes != "":
		button.text += "  (%s)" % notes


func _get_notes_for_line_id(id: String) -> String:
	if not _resource or not _resource.lines.has(id):
		return ""
	return _resource.lines[id].get(&"notes", "")


func _add_feed_line(feed_line: String) -> void:
	_lines.append(feed_line)
	if _lines.size() > max_lines:
		_lines = _lines.slice(_lines.size() - max_lines)
	text = "\n".join(_lines)
	modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	# faded feed starts ∅, else old lines come back w/ next one
	_tween.tween_callback(func() -> void: _lines.clear())
