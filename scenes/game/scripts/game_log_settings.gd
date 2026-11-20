# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Sets which [GameLog] channels are on when game scene starts, so they can be
## changed in inspector of [code]game.tscn[/code]. Level run on its own keeps
## defaults in [member GameLog.channels].
extends Node

## Channel -> on. Channel left out keeps its default, unknown channel is error.
@export var channels: Dictionary[StringName, bool] = {}


# Not _ready: levels load in their own _ready and should log from first line.
func _enter_tree() -> void:
	for channel: StringName in channels:
		if not GameLog.channels.has(channel):
			Log.error("no log channel '%s'" % channel)
			continue
		GameLog.channels[channel] = channels[channel]
