# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
@icon("res://scripts/entities/table2 duke.png")
## Anything player can interact w/: tree, box, person.
## [method execute_interaction_for_actor] gives [member item] (if any), shows [member dialogue] (if any) +
## returns when it ends ∴ caller can hold interact lock for whole interaction.
## When blocked (missing [member requires_item], missing [member requires_flag] or
## no room) ∅ is given + thing stays.
## Reach is [member interaction_zone], [Area3D] you shape in editor. W/o one it builds
## sphere zone in [method Node._ready]. Zone sits on [constant ZONE_LAYER],
## player [InteractionComponent] detects thing through it.
class_name InteractableThing
extends Node3D

## Emitted when blocked. [param reason] is [constant REQUIRES_ITEM], [constant REQUIRES_FLAG]
## / [constant FULL].
signal blocked(actor: PlayerApi, reason: StringName)
## Emitted when interaction passed every gate + begins. Not emitted when blocked.
## Lets siblings react (NPC stops walking, turns to player) w/o this knowing them.
signal started(actor: PlayerApi)
## Emitted when that interaction ended, before [member free_after] frees node.
signal finished(actor: PlayerApi)

## Physics layer 5 ("interaction"). Only zones are on it + only player sensor scans it.
const ZONE_LAYER: int = 1 << 4
const _ZONE_OWNER_META: StringName = &"interactable_thing"
const REQUIRES_ITEM: StringName = &"requires_item"
const REQUIRES_FLAG: StringName = &"requires_flag"
const FULL: StringName = &"full"

## Off = [method execute_interaction_for_actor] does ∅ + player sensor skips it.
@export var enabled: bool = true
## Plays [member sprite] on interact, paused otherwise.
@export var animate_on_interact: bool = false
## Frees node after interaction ended (pickups).
@export var free_after: bool = false
## Freezes player until interaction ended. Off = player keeps moving (signs, barks).
@export var locks_player: bool = true
## W/ [member free_after]: once freed it stays gone, saved /level in [LevelState].
## Must be unique within level.
@export var persistent_id: String = ""
## Defaults to single [AnimatedSprite3D] below this node when [member animate_on_interact] is set.
@export var sprite: AnimatedSprite3D
## Reach: player inside this area can interact (or triggers it, for [member auto]).
## Found automatically when it is a direct [Area3D] child, assign here only to use another.
## Scene [code]scenes/game/interactable_thing_prefab.tscn[/code] already has one.
## Layer, mask + monitoring are set from code, only shape matters.
## ∅ found = sphere built from [member interact_radius] ([member auto_radius] for [member auto]).
@export var interaction_zone: Area3D
## Reach for interact press, measured from this node origin. Only used when
## [member interaction_zone] is ∅. Ignored for [member auto].
@export var interact_radius: float = 2.0
@export_group("Pickup")
## Given on interaction, all/∅: w/ no room it blocks w/ [constant FULL].
@export var item: ItemData
## How many of [member item] are given.
@export var item_count: int = 1
## ∅ is given until player carries this. It is not taken away.
@export var requires_item: ItemData
## ∅ runs until this flag is set, see [method PlayerApi.set_level_flag].
## Checked before [member requires_item].
@export var requires_flag: String = ""
## Runs when player walks into zone, not on interact press,
## again after leaving + re-entering. Never locks ∴ give it no dialogue.
## Entering while disabled/during locking interaction does not count, walk out + back in.
@export var auto: bool = false
## Radius of built zone for [member auto]. Only used when [member interaction_zone] is ∅.
@export var auto_radius: float = 1.0
@export_group("Dialogue")
## Shown on interaction, starting at [member dialogue_cue]. Gets actor as extra game state.
@export var dialogue: DialogueResource
## Cue in [member dialogue] that starts on interaction, checked on load.
@export var dialogue_cue: String = "start"
## Cue shown when blocked. Needs [member dialogue], ignored for [member auto]. ∅ = silent.
@export var blocked_cue: String = ""

var _is_running: bool = false


## Thing that owns [param zone]/null for any other area.
static func get_interactable_from_zone(zone: Area3D) -> InteractableThing:
	return zone.get_meta(_ZONE_OWNER_META, null)


func _ready() -> void:
	GameState.check_persistent_id_is_unique(self, persistent_id)
	if auto and dialogue:
		Log.error("%s: auto things must not have a dialogue" % name)
	if persistent_id != "" and not free_after:
		Log.warn("%s: persistent_id does nothing without free_after" % name)
	_check_dialogue_cues()
	# already taken in earlier visit, gone before its zone exists
	if free_after and persistent_id != "" and GameState.get_level_flag(GameState.get_placed_level_path(self), get_finished_flag_key()):
		queue_free()
		return
	_setup_interaction_zone()
	if not animate_on_interact:
		return
	if not sprite:
		sprite = Component.find_descendant_of_type(self, AnimatedSprite3D, true) as AnimatedSprite3D
	if sprite:
		sprite.pause()


## Runs interaction for [param actor] + returns when it ends.
## [param actor] is also dialogue extra game state.
func execute_interaction_for_actor(actor: PlayerApi) -> void:
	if not enabled or _is_running:
		return
	if requires_flag != "" and not actor.get_level_flag(requires_flag):
		await _block_interaction_for_actor(actor, REQUIRES_FLAG)
		return
	if requires_item and not actor.has_item(requires_item.get_item_id()):
		await _block_interaction_for_actor(actor, REQUIRES_ITEM)
		return
	if item and not actor.give_item(item.get_item_id(), item_count):
		await _block_interaction_for_actor(actor, FULL)
		return
	# saved now, not after dialogue: item already saved in inventory ∴ quitting
	# mid dialogue would leave both pickup + item
	if free_after and persistent_id != "":
		GameState.set_level_flag(GameState.get_placed_level_path(self), get_finished_flag_key())
	_is_running = true
	GameLog.write(&"interact", "started", str(name))
	started.emit(actor)
	if animate_on_interact and sprite:
		sprite.play()
	if dialogue:
		DialogueManager.show_dialogue_balloon(dialogue, dialogue_cue, [actor])
		await DialogueManager.dialogue_ended
	_is_running = false
	GameLog.write(&"interact", "finished", str(name))
	finished.emit(actor)
	if free_after:
		queue_free()


# wrong cue only fails on interact, checked on load ∴ every thing in level
# is checked even after cues move between .dialogue files
func _check_dialogue_cues() -> void:
	if not dialogue:
		return
	var cues: PackedStringArray = dialogue.get_cues()
	for cue: String in [dialogue_cue, blocked_cue]:
		if cue != "" and cue not in cues:
			Log.error("%s: cue \"%s\" not in %s" % [name, cue, dialogue.resource_path])


# player sensor monitors, not zone
func _setup_interaction_zone() -> void:
	if not interaction_zone:
		interaction_zone = _find_child_interaction_zone()
	if not interaction_zone:
		interaction_zone = _build_default_interaction_zone()
	interaction_zone.collision_layer = ZONE_LAYER
	interaction_zone.collision_mask = 0
	interaction_zone.monitoring = false
	interaction_zone.monitorable = true
	interaction_zone.set_meta(_ZONE_OWNER_META, self)


func _find_child_interaction_zone() -> Area3D:
	for child: Node in get_children():
		if child is Area3D:
			return child
	return null


func _build_default_interaction_zone() -> Area3D:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = auto_radius if auto else interact_radius
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	var zone: Area3D = Area3D.new()
	zone.name = "InteractionZone"
	zone.add_child(collision)
	add_child(zone)
	return zone


func _block_interaction_for_actor(actor: PlayerApi, reason: StringName) -> void:
	GameLog.write(&"interact", "blocked", str(name), str(reason))
	blocked.emit(actor, reason)
	if auto or not dialogue or blocked_cue == "":
		return
	_is_running = true
	DialogueManager.show_dialogue_balloon(dialogue, blocked_cue, [actor])
	await DialogueManager.dialogue_ended
	_is_running = false


## Level flag set when this [member free_after] thing is used, see [member persistent_id].
func get_finished_flag_key() -> String:
	return "thing." + persistent_id
