# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Loads every level game lists (SceneLister in game.tscn) + runs it for [constant RUN_FRAMES].
## Load checks (rule 3: [method Component._require_dependencies], state chart events, cues,
## sanity thresholds, ETC) push error + GUT fails test on any push_error ∴ broken scene fails CI.
## Also checks every [member InteractableThing.requires_flag] is set somewhere, else thing stays locked.
## New level in SceneLister is tested w/o touching this file.
## Level + [SanityComponent] read + write save ∴ [SaveIsolatedTest], ∅ save also keeps tutorials closed.
extends SaveIsolatedTest

const GAME_SCENE_PATH: String = "res://scenes/game/game.tscn"
# _on_setup is deferred + spawned player drops onto floor in these
const RUN_FRAMES: int = 30

var _level_paths: Array[String] = _read_level_paths()


#region Tests
func test_level_runs_without_errors(level_path: String = use_parameters(_level_paths)) -> void:
	var level_scene: PackedScene = load(level_path) as PackedScene
	assert_not_null(level_scene, "%s loads as scene" % level_path)
	if not level_scene:
		return
	add_child_autofree(level_scene.instantiate())
	await wait_physics_frames(RUN_FRAMES)
	assert_not_null(PlayerApi.find_local_player_api(get_tree()), "%s has player" % level_path)


# flags have no list ∴ set somewhere = in .dialogue/by used pickup/entered sanctuary of same level
func test_required_flags_are_set_somewhere(level_path: String = use_parameters(_level_paths)) -> void:
	var level_scene: PackedScene = load(level_path) as PackedScene
	assert_not_null(level_scene, "%s loads as scene" % level_path)
	if not level_scene:
		return
	# not in tree ∴ ∅ runs, only exported values are read
	var level: Node = autofree(level_scene.instantiate())
	var nodes: Array[Node] = level.find_children("*", "", true, false)
	var set_flags: PackedStringArray = _find_flags_set_in_dialogue()
	for node: Node in nodes:
		if node is InteractableThing and (node as InteractableThing).persistent_id != "":
			set_flags.append((node as InteractableThing).get_finished_flag_key())
		elif node is SanityArea and (node as SanityArea).persistent_id != "":
			set_flags.append((node as SanityArea).get_entered_flag_key())
	var never_set: PackedStringArray = PackedStringArray()
	for node: Node in nodes:
		var thing: InteractableThing = node as InteractableThing
		if thing and thing.requires_flag != "" and thing.requires_flag not in set_flags:
			never_set.append("%s: %s" % [level.get_path_to(thing), thing.requires_flag])
	assert_eq(never_set.size(), 0, "requires_flag nothing sets, thing stays locked:\n%s" % "\n".join(never_set))
#endregion


#region Helpers
# same list LevelManager + console level use, read w/o running game.tscn
func _read_level_paths() -> Array[String]:
	var level_paths: Array[String] = []
	var game_scene_state: SceneState = (load(GAME_SCENE_PATH) as PackedScene).get_state()
	for node_index: int in game_scene_state.get_node_count():
		if game_scene_state.get_node_name(node_index) != &"SceneLister":
			continue
		for property_index: int in game_scene_state.get_node_property_count(node_index):
			if game_scene_state.get_node_property_name(node_index, property_index) == &"files":
				var files: Array = game_scene_state.get_node_property_value(node_index, property_index)
				level_paths.assign(files)
	if level_paths.is_empty():
		Log.error("no SceneLister files in %s, no level is tested" % GAME_SCENE_PATH)
	return level_paths


func _find_flags_set_in_dialogue() -> PackedStringArray:
	var set_level_flag_pattern: RegEx = RegEx.create_from_string("\\bset_level_flag\\(\\s*\"([^\"]*)\"")
	var flags: PackedStringArray = PackedStringArray()
	for path: String in DebugCommands.find_dialogue_files("res://"):
		for found: RegExMatch in set_level_flag_pattern.search_all(FileAccess.get_file_as_string(path)):
			flags.append(found.get_string(1))
	return flags
#endregion
