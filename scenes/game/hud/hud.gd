# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Player HUD, drop in any level with player. Every widget finds local player itself and
## works alone, so level that wants less removes nodes (Editable Children) or uses widget scenes directly.
class_name Hud
extends CanvasLayer

## Shows [DebugStateLabel]. Off: still developer view, not for players.
@export var show_debug_state: bool = false

@onready var _debug_state_label: DebugStateLabel = %DebugStateLabel


func _ready() -> void:
	_debug_state_label.visible = show_debug_state
