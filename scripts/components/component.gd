# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
@icon("res://scripts/components/teto_kidnapp_miku.png")
## Base class for everything that lives on character as component.
## Extend it, not [Node] to get [method _on_ready] + [method _on_setup] hooks.
##
## Body (ancestor that owns components) injects dependencies in its
## [method Node._enter_tree]. That runs top-down ∴ they are set in both hooks.
## Dependencies are plain typed fields, not [code]@export[/code]. Body finds
## components + assigns them once, see [PlayerBody]. Check them in [method _on_setup].
##
## [method _on_setup] is deferred ∴ every sibling has finished [method Node._ready] by then.
## ⚠ Hooks are not chained. They do ∅ here ∴ components extending
## [Component] directly need no [code]super()[/code]. Subclasses of other components
## (e.g. [Movement3DComponent]) must call it, parent does real work.
class_name Component
extends Node


## Returns descendant of [param root] that is [param type]/null.
## Pushes error when there are several + returns first.
## Pushes warning when ∅ is found + [param warn] is true.
static func find_descendant_of_type(root: Node, type: Variant, warn: bool = false) -> Node:
	var found: Node = null
	for node: Node in root.find_children("*", "", true, false):
		if not is_instance_of(node, type):
			continue
		if found:
			Log.error("%s: more than one %s, using %s and not %s" % [root.name, type, found.name, node.name])
			break
		found = node
	if not found and warn:
		Log.warn("%s: no %s found." % [root.name, type])
	return found


func _ready() -> void:
	_on_ready()
	_on_setup.call_deferred()


## Runs in [method Node._ready]. Dependencies are set, siblings may not be ready yet.
func _on_ready() -> void:
	pass


## Runs deferred, at idle time after [method Node._ready] ∴ every sibling is ready.
## Check dependencies here, see [method _require_dependencies].
func _on_setup() -> void:
	pass


## Pushes one error naming every null dependency ([code]{ "label": value }[/code]).
## Returns true when all are set ∴ caller can bail out.
func _require_dependencies(dependencies: Dictionary) -> bool:
	var missing: PackedStringArray = PackedStringArray()
	for dependency_name: String in dependencies:
		if not dependencies[dependency_name]:
			missing.append(dependency_name)
	if not missing.is_empty():
		Log.error("%s: missing required dependencies: %s" % [name, ", ".join(missing)])
	return missing.is_empty()
