# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Log of what player does, split in channels that console command
## [code]log[/code] turns on + off. Autoload.
## Lines go to Godot output, [LimboConsole] + Godot log file ([code]user://logs/godot.log[/code]).
## Formatted by [Log] ∴ every line starts w/ file + line that wrote it.
extends Node

## Emitted on every [method write], also for channel that is off, as plain text
## w/o file + line. Lets [ExplainFeed] show changes w/o each system knowing it.
signal wrote(channel: StringName, text: String)

## Channel to on. Value here is state at every start, console changes not saved.
var channels: Dictionary[StringName, bool] = { &"movement": false, &"sanity": true, &"inventory": true, &"interact": true, &"dialogue": true, &"ledger": true }


func _ready() -> void:
	LimboConsole.register_command(toggle_channel, "log", "Toggles a log channel, lists all without one. Usage: log <channel>")
	# not channels.keys: on Dictionary that reads key "keys", not method
	LimboConsole.add_argument_autocomplete_source(
		"log",
		0,
		func() -> Array:
			return channels.keys(),
	)
	DialogueManager.passed_cue.connect(_on_passed_cue)
	DialogueManager.got_dialogue.connect(_on_got_dialogue)


## Writes [param values] as one line when [param channel] is on + Log.gd level ≤ INFO.
## Channel missing from [member channels] is error.
## [codeblock]
## GameLog.write(&"sanity", "zone", zone, "at", "%.1f" % value)
## [/codeblock]
func write(channel: StringName, ...values: Array) -> void:
	# formatted only when something listens, movement writes every few frames
	if wrote.has_connections():
		wrote.emit(channel, " ".join(PackedStringArray(values.map(func(value: Variant) -> String: return str(value)))))
	# below INFO ∴ Log.gd level silences channels too, not only Log.debug/info
	if not channels[channel] or Log.get_log_level() > Log.Levels.INFO:
		return
	values.push_front("[%s]" % channel)
	var line: String = _get_caller_prefix() + Log.to_printable(values, { skip_callsite = true })
	print_rich(line)
	LimboConsole.print_line(line, false)


# Log.gd >= 0.3 finds callsite itself + would name this file ∴ prefix of write() caller is built here
# same look as Log.gd prefix, ∅ in release export where get_stack() is empty
func _get_caller_prefix() -> String:
	var stack: Array = get_stack()
	# 0 = here, 1 = write, 2 = its caller
	if stack.size() < 3:
		return ""
	var caller: Dictionary = stack[2]
	var source: String = caller.get("source", "")
	var prefix: String = "[%s:%s]: " % [source.get_file().get_basename(), caller.get("line", 0)]
	return Log.color_wrap(prefix, { type = "SRC", disable_colors = Log.get_disable_colors() })


## Flips [param channel]/lists every channel when ∅.
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
