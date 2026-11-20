# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## One physics frame of input. Built by [InputComponent].
## [code]_pressed[/code] + [code]_released[/code] fields are true for that frame only.
class_name InputFrame
extends RefCounted

## Movement axes, length <= 1.
var move: Vector2
var run: bool
var jump_pressed: bool
var jump_released: bool
var crouch: bool
var dash_pressed: bool
var interact_pressed: bool
