# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Log of what player does, split in channels that console command
## [code]log[/code] turns on and off. Autoload.
## Lines go to Godot output, [LimboConsole] and [constant FILE_PATH].
## Formatted by [Log], so every line starts with file and line that wrote it.
extends Node

## Emitted on every [method write], also for channel that is off, as plain text
## without file and line. Lets [ExplainFeed] show changes without each system knowing it.
signal wrote(channel: StringName, text: String)

## Overwritten on every start.
const FILE_PATH: String = "user://game.log"

## Channel -> on. Value here is state at every start, console changes are not saved.
var channels: Dictionary[StringName, bool] = { &"movement": false, &"sanity": true, &"inventory": true, &"interact": true, &"dialogue": true, &"ledger": true }

var _file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)


func _ready() -> void:
	LimboConsole.register_command(toggle_channel, "log", "Toggles a log channel, lists all without one. Usage: log <channel>")
	# Not channels.keys: on Dictionary that reads key "keys", not method.
	LimboConsole.add_argument_autocomplete_source(
		"log",
		0,
		func() -> Array:
			return channels.keys(),
	)
	if not _file:
		Log.error("cannot write %s: %s" % [FILE_PATH, error_string(FileAccess.get_open_error())])
	DialogueManager.passed_cue.connect(_on_passed_cue)
	DialogueManager.got_dialogue.connect(_on_got_dialogue)
	# Balloon has no signal for picked option, only its menu does.
	get_tree().node_added.connect(_on_node_added)


## Writes [param values] as one line when [param channel] is on.
## Channel missing from [member channels] is error.
## [codeblock]
## GameLog.write(&"sanity", "zone", zone, "at", "%.1f" % value)
## [/codeblock]
func write(channel: StringName, ...values: Array) -> void:
	# Formatted only when something listens, movement writes every few frames.
	if wrote.has_connections():
		wrote.emit(channel, " ".join(PackedStringArray(values.map(func(value: Variant) -> String: return str(value)))))
	if not channels[channel]:
		return
	values.push_front("[%s]" % channel)
	var stack: Array = get_stack()
	var line: String = Log.to_printable(values, { stack = stack })
	print_rich(line)
	LimboConsole.print_line(line, false)
	if not _file:
		return
	_file.store_line(Log.to_printable(values, { stack = stack, disable_colors = true }))
	# Flushed per line, so crash keeps what led up to it.
	_file.flush()


## Flips [param channel], or lists every channel when empty.
func toggle_channel(channel: String = "") -> void:
	if channel == "":
		for listed: StringName in channels:
			LimboConsole.info("%s %s" % [listed, "on" if channels[listed] else "off"])
		return
	var key: StringName = channel
	if not channels.has(key):
		LimboConsole.error("no log channel '%s'" % channel)
		return
	channels[key] = not channels[key]
	LimboConsole.info("log %s %s" % [channel, "on" if channels[key] else "off"])


func _on_passed_cue(cue: String) -> void:
	write(&"dialogue", "cue", cue)


func _on_got_dialogue(line: DialogueLine) -> void:
	write(&"dialogue", "%s: %s" % [line.character, line.text])


func _on_node_added(node: Node) -> void:
	if node is DialogueResponsesMenu:
		(node as DialogueResponsesMenu).response_selected.connect(_on_response_selected)


func _on_response_selected(response: DialogueResponse) -> void:
	write(&"dialogue", "picked", response.text)
