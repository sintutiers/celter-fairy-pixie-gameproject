# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## TDD conventions grep can check, on every .gd w/ SPDX header outside [constant EXCLUDED_DIRECTORIES].
## Maaack template scripts have no header ∴ they are left alone.
## Judgment rules (abstraction, naming quality, comment tone) stay review work, regex gets them wrong.
extends GutTest

const SPDX_HEADER: String = "# SPDX-FileCopyrightText:"
## Same skips as .githooks/pre-commit: not our code/not valid GDScript.
const EXCLUDED_DIRECTORIES: Array[String] = [
	"res://addons",
	"res://godot_state_charts_examples",
	"res://spacetime_bindings",
	"res://scripts/ARCHIVE SCRIPTS",
	"res://scripts/templates",
]
## Only these read [Input], rest gets [InputFrame] through [InputComponent] ∴ replays + tests drive it.
const INPUT_READING_SCRIPTS: Array[String] = ["res://scripts/components/player_input_component.gd"]

# path > source of every script w/ SPDX header, read once
var _sources: Dictionary[String, String] = {}


#region Setup/Teardown
func before_all() -> void:
	for path: String in _find_scripts("res://"):
		var source: String = FileAccess.get_file_as_string(path)
		if source.begins_with(SPDX_HEADER):
			_sources[path] = source
#endregion


#region Tests
func test_scripts_folder_has_spdx_headers() -> void:
	var violations: PackedStringArray = PackedStringArray()
	for path: String in _find_scripts("res://scripts"):
		if path not in _sources:
			violations.append(path)
	_assert_no_violations(violations, "script w/o SPDX header (Adding New Stuff)")


func test_one_class_per_file_named_after_it() -> void:
	var class_name_pattern: RegEx = RegEx.create_from_string("(?m)^class_name (\\w+)")
	var inner_class_pattern: RegEx = RegEx.create_from_string("(?m)^class \\w+")
	var violations: PackedStringArray = PackedStringArray()
	for path: String in _sources:
		var found: RegExMatch = class_name_pattern.search(_sources[path])
		# PlayerBody2D = player_body_2d.gd ∴ compared w/o case + underscores
		if found and found.get_string(1).to_lower() != path.get_file().get_basename().replace("_", "").to_lower():
			violations.append("%s: class_name %s" % [path, found.get_string(1)])
		if inner_class_pattern.search(_sources[path]):
			violations.append("%s: inner class" % path)
	_assert_no_violations(violations, "one class per file, file named after class (rule 10)")


func test_components_get_dependencies_from_body() -> void:
	var violations: PackedStringArray = _find_code_lines(
		RegEx.create_from_string("get_parent\\(|get_node\\(\\s*\"\\.\\.|\\$\"?\\.\\."),
		func(path: String) -> bool: return path.begins_with("res://scripts/components/"),
	)
	_assert_no_violations(violations, "component looks up own dependency, body wires it (Component Wiring)")


func test_only_input_components_read_input() -> void:
	var violations: PackedStringArray = _find_code_lines(
		RegEx.create_from_string("\\bInput\\."),
		func(path: String) -> bool: return path not in INPUT_READING_SCRIPTS,
	)
	_assert_no_violations(violations, "reads Input directly, use InputComponent.get_frame() (ANTIPATTERNS)")


func test_shared_names_are_constants() -> void:
	var violations: PackedStringArray = _find_code_lines(
		RegEx.create_from_string("\\b(play|send_event|travel)\\(\\s*&?\""),
		func(_path: String) -> bool: return true,
	)
	_assert_no_violations(violations, "typed-out name, use Animations/StateEvents constant (rule 10)")


func test_public_members_have_doc_comment() -> void:
	var member_pattern: RegEx = RegEx.create_from_string(
		"^(static func [a-zA-Z]|func [a-zA-Z]|signal |class_name |@export\\w*(\\([^)]*\\))? var )",
	)
	# annotations that may sit between doc comment + member
	var annotation_pattern: RegEx = RegEx.create_from_string("^@(icon|tool|abstract|export_group|export_subgroup|export_category)\\b")
	var violations: PackedStringArray = PackedStringArray()
	for path: String in _sources:
		# test names are the docs + GUT hooks are not API
		if path.begins_with("res://scripts/test/"):
			continue
		var lines: PackedStringArray = _sources[path].split("\n")
		for index: int in lines.size():
			if not member_pattern.search(lines[index]):
				continue
			var above: int = index - 1
			while above >= 0 and annotation_pattern.search(lines[above]):
				above -= 1
			if above < 0 or not lines[above].begins_with("##"):
				violations.append("%s:%d: %s" % [path, index + 1, lines[index]])
	_assert_no_violations(violations, "public member w/o ## doc comment above it (API DOCS)")


# project only warns (Maaack template scripts are untyped) ∴ rule 14 is enforced here for our code
func test_everything_is_typed() -> void:
	var violations: PackedStringArray = _find_code_lines(
		# var x = / var x := , for x in , func x(): w/o return type
		RegEx.create_from_string("^\\s*(static\\s+)?(var|const)\\s+\\w+\\s*:?=|^\\s*for\\s+\\w+\\s+in\\b|func\\s*\\w*\\([^)]*\\)\\s*:"),
		func(_path: String) -> bool: return true,
	)
	violations.append_array(_find_untyped_parameters())
	_assert_no_violations(violations, "declaration w/o type (rule 14)")


func test_private_members_stay_in_own_class() -> void:
	var private_access_pattern: RegEx = RegEx.create_from_string("\\b([A-Za-z_]\\w*)\\._[a-z]\\w*")
	var class_name_pattern: RegEx = RegEx.create_from_string("(?m)^class_name (\\w+)")
	var violations: PackedStringArray = PackedStringArray()
	for path: String in _sources:
		var own_class: RegExMatch = class_name_pattern.search(_sources[path])
		var allowed: Array[String] = ["self", "super", own_class.get_string(1) if own_class else "self"]
		var lines: PackedStringArray = _sources[path].split("\n")
		for index: int in lines.size():
			if lines[index].strip_edges().begins_with("#"):
				continue
			for found: RegExMatch in private_access_pattern.search_all(lines[index]):
				if found.get_string(1) not in allowed:
					violations.append("%s:%d: %s" % [path, index + 1, lines[index].strip_edges()])
	_assert_no_violations(violations, "_private member used outside its class (FUNCTION NAMING)")


# unknown channel only errors once that line runs
func test_game_log_channels_exist() -> void:
	var channel_pattern: RegEx = RegEx.create_from_string("GameLog\\.write\\(\\s*&\"(\\w+)\"")
	var violations: PackedStringArray = PackedStringArray()
	for path: String in _sources:
		for found: RegExMatch in channel_pattern.search_all(_sources[path]):
			if StringName(found.get_string(1)) not in GameLog.channels:
				violations.append("%s: %s" % [path, found.get_string(1)])
	_assert_no_violations(violations, "GameLog channel not in GameLog.channels (Debug)")


func test_components_extend_component() -> void:
	var component_script: Script = Component
	var violations: PackedStringArray = PackedStringArray()
	for path: String in _sources:
		if not path.begins_with("res://scripts/components/") or path == component_script.resource_path:
			continue
		var base: Script = load(path) as Script
		while base and base != component_script:
			base = base.get_base_script()
		if not base:
			violations.append(path)
	_assert_no_violations(violations, "script in scripts/components/ does not extend Component (Components)")


# fix warning instead of hiding it
func test_no_warning_ignore() -> void:
	var violations: PackedStringArray = _find_code_lines(
		RegEx.create_from_string("^\\s*@warning_ignore"),
		func(_path: String) -> bool: return true,
	)
	_assert_no_violations(violations, "@warning_ignore hides warning, fix it instead")
#endregion


#region Helpers
func _find_scripts(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	if directory in EXCLUDED_DIRECTORIES:
		return paths
	# DirAccess skips hidden folders ∴ .godot + worktree copies are not read
	for folder: String in DirAccess.get_directories_at(directory):
		paths.append_array(_find_scripts(directory.path_join(folder)))
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() == "gd":
			paths.append(directory.path_join(file))
	return paths


# "path:line: code" for every non comment line matching [param pattern] in scripts [param is_checked] accepts
func _find_code_lines(pattern: RegEx, is_checked: Callable) -> PackedStringArray:
	var found_lines: PackedStringArray = PackedStringArray()
	for path: String in _sources:
		if not is_checked.call(path):
			continue
		var lines: PackedStringArray = _sources[path].split("\n")
		for index: int in lines.size():
			if not lines[index].strip_edges().begins_with("#") and pattern.search(lines[index]):
				found_lines.append("%s:%d: %s" % [path, index + 1, lines[index].strip_edges()])
	return found_lines


# "path:line: code" for every parameter w/o type, also in signatures over several lines
func _find_untyped_parameters() -> PackedStringArray:
	var signature_start_pattern: RegEx = RegEx.create_from_string("\\bfunc\\s*\\w*\\(")
	var found_lines: PackedStringArray = PackedStringArray()
	for path: String in _sources:
		var lines: PackedStringArray = _sources[path].split("\n")
		var index: int = 0
		while index < lines.size():
			var start: RegExMatch = signature_start_pattern.search(lines[index])
			if not start or lines[index].strip_edges().begins_with("#"):
				index += 1
				continue
			var signature_line: int = index
			var parameters: String = _read_parameters(lines, index, start.get_end())
			for parameter: String in _split_top_level(parameters):
				# name: Type = default, only part before = matters
				if parameter.strip_edges() != "" and ":" not in parameter.get_slice("=", 0):
					found_lines.append("%s:%d: %s" % [path, signature_line + 1, parameter.strip_edges()])
			index += 1
	return found_lines


# text between "(" at [param column] + its matching ")", may span lines
func _read_parameters(lines: PackedStringArray, line_index: int, column: int) -> String:
	var depth: int = 1
	var parameters: String = ""
	var text: String = lines[line_index].substr(column)
	while true:
		for character: String in text:
			if character == "(":
				depth += 1
			elif character == ")":
				depth -= 1
				if depth == 0:
					return parameters
			parameters += character
		line_index += 1
		if line_index >= lines.size():
			return parameters
		parameters += " "
		text = lines[line_index]
	return parameters


# commas inside default values (Vector2(1, 2)) are not parameter breaks
func _split_top_level(parameters: String) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var current: String = ""
	for character: String in parameters:
		if character in "([{":
			depth += 1
		elif character in ")]}":
			depth -= 1
		if character == "," and depth == 0:
			parts.append(current)
			current = ""
		else:
			current += character
	parts.append(current)
	return parts


func _assert_no_violations(violations: PackedStringArray, rule: String) -> void:
	assert_eq(violations.size(), 0, "%s:\n%s" % [rule, "\n".join(violations)])
#endregion
