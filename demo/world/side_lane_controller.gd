extends Node
## Demo-only side-scroller gameplay lane, independent of camera rig, AI,
## Combat and the movement FSM. Locomotion already supports side_lane_z.
## Explicit remote scenes keep the same X/Y combat plane as the player.
##
## A view switch is allowed to align actors (unlike CameraRig itself).
## Never teleport through solid scenery or a closed physical doorway.

const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")

@export var player_path: NodePath = ^"../Player"
@export var views_path: NodePath = ^"../ViewManager"
@export var location_manager_path: NodePath = ^"../LocationManager"
@export var session_path: NodePath = ^"../WorldSession"
@export var enemy_group: StringName = &"action5_enemy"
@export var enabled: bool = true
## Local Z of the 2D lane. Keep 0 for the center-line physical gate.
@export var connected_lane_z: float = 0.0
@export var detached_lane_z: float = 0.0
## If a lateral sweep is obstructed, try a small, COLLISION-TESTED X nudge
## within the same room, not a teleport through the obstacle or door.
@export_range(0.0, 4.0, 0.25) var max_x_nudge: float = 3.0
@export_range(0.5, 2.0, 0.25) var nudge_step: float = 1.5

@onready var player: CharacterBody3D = get_node_or_null(player_path) as CharacterBody3D
@onready var views: Node = get_node_or_null(views_path)
@onready var locations: Node = get_node_or_null(location_manager_path)
@onready var session: Node = get_node_or_null(session_path)

var _side_active: bool = false
## Tracks only actors whose locomotion we locked, not all entities in tree.
var _locked: Dictionary = {}
## Enemies sharing a 2D plane must not body-block one another. Exceptions
## survive view exit ONLY until their bodies separate, so a transition
## back to 3D cannot trap the melee pursuer behind the ranged enemy.
var _enemy_pairs: Dictionary = {}


func _ready() -> void:
    # After default-priority Locomotion has applied its authoritative
    # move_and_slide, keep only small collision-safe lane corrections.
    process_physics_priority = 50
    if not is_instance_valid(player) or not is_instance_valid(views):
        push_error("ACTION5: SideLaneController needs Player and ViewManager")
        set_physics_process(false)
        return
    views.view_changed.connect(_on_view_changed)
    if is_instance_valid(locations):
        locations.location_changed.connect(_on_location_changed)
    if is_instance_valid(session):
        session.encounter_activation_changed.connect(_on_encounter_activated)
    get_tree().node_added.connect(_on_node_added)
    _on_view_changed(views.current_profile, null)


func _on_view_changed(profile: Resource, _previous: Resource) -> void:
    var next_active: bool = enabled and profile != null \
        and profile.mode == ViewProfileScript.Mode.SIDE
    if not next_active:
        _side_active = false
        _unlock_all()
        return
    _side_active = true
    _sync_lane()


func _on_location_changed(_old: StringName, _new: StringName, _root: Node3D) -> void:
    if _side_active:
        _unlock_all()
        # A cached room should not retain crowd exceptions from a player
        # visit. The new active scene gets its own distinct actor pairs.
        _prune_enemy_pairs(true)
        _sync_lane()


func _on_encounter_activated(active: bool) -> void:
    if active and _side_active:
        call_deferred("_sync_lane")


func _on_node_added(node: Node) -> void:
    if _side_active and node is CharacterBody3D and node.is_in_group(enemy_group):
        call_deferred("_on_enemy_added", weakref(node))


func _on_enemy_added(reference: WeakRef) -> void:
    if not _side_active or not is_inside_tree():
        return
    var actor: CharacterBody3D = reference.get_ref() as CharacterBody3D
    if _belongs_to_active_location(actor):
        _sync_lane()


func _active_root() -> Node3D:
    if is_instance_valid(locations) and is_instance_valid(locations.active_scene):
        return locations.active_scene
    return get_parent() as Node3D


func _lane_world_z() -> float:
    var root: Node3D = _active_root()
    var z: float = detached_lane_z if root != get_parent() else connected_lane_z
    return root.to_global(Vector3(0.0, 0.0, z)).z


func _belongs_to_active_location(actor: CharacterBody3D) -> bool:
    if not is_instance_valid(actor) or not actor.is_inside_tree() \
            or actor.is_queued_for_deletion():
        return false
    var root: Node3D = _active_root()
    if root == get_parent():
        # Inactive remote PackedScenes are also under this root but must
        # keep their own cached actor state until their next activation.
        var ancestor: Node = actor
        while ancestor != null and ancestor != root:
            if ancestor.is_in_group("action5_detached_location"):
                return false
            ancestor = ancestor.get_parent()
        return ancestor == root
    return root == actor or root.is_ancestor_of(actor)


func _sync_lane() -> void:
    if not _side_active or not is_inside_tree():
        return
    if _belongs_to_active_location(player):
        _align(player)
    var enemies: Array[CharacterBody3D] = []
    for candidate in get_tree().get_nodes_in_group(enemy_group):
        var actor := candidate as CharacterBody3D
        if _belongs_to_active_location(actor) and bool(actor.get("alive")):
            if _align(actor):
                enemies.append(actor)
    # Only enemy/enemy pairs: never bypass player, wall or doorway physics.
    for i in range(enemies.size()):
        for j in range(i + 1, enemies.size()):
            _soften_pair(enemies[i], enemies[j])


func _soften_pair(a: CharacterBody3D, b: CharacterBody3D) -> void:
    var key: String = "%d:%d" % [
        mini(a.get_instance_id(), b.get_instance_id()),
        maxi(a.get_instance_id(), b.get_instance_id())
    ]
    if _enemy_pairs.has(key):
        return
    var added_ab: bool = not a.get_collision_exceptions().has(b)
    var added_ba: bool = not b.get_collision_exceptions().has(a)
    if added_ab:
        a.add_collision_exception_with(b)
    if added_ba:
        b.add_collision_exception_with(a)
    _enemy_pairs[key] = {
        "a": weakref(a), "b": weakref(b),
        "added_ab": added_ab, "added_ba": added_ba
    }


func _prune_enemy_pairs(force: bool = false) -> void:
    for key in _enemy_pairs.keys():
        var entry: Dictionary = _enemy_pairs[key]
        var a: CharacterBody3D = (entry["a"] as WeakRef).get_ref() as CharacterBody3D
        var b: CharacterBody3D = (entry["b"] as WeakRef).get_ref() as CharacterBody3D
        if not is_instance_valid(a) or not is_instance_valid(b):
            _enemy_pairs.erase(key)
            continue
        # Leave temporary separation enabled while returning to free 3D:
        # removing it at the exact moment of the view switch can wedge
        # two NPCs in a single line before navigation spreads them out.
        if force or (not _side_active and a.global_position.distance_to(
                b.global_position) > 1.5):
            # Never remove exceptions that were already authored by an
            # independent collision policy before this adapter ran.
            if bool(entry["added_ab"]):
                a.remove_collision_exception_with(b)
            if bool(entry["added_ba"]):
                b.remove_collision_exception_with(a)
            _enemy_pairs.erase(key)


func _align(actor: CharacterBody3D) -> bool:
    if not _belongs_to_active_location(actor) or not actor.can_process():
        return false
    var locomotion: Node = actor.get_node_or_null("Locomotion")
    if locomotion == null or not locomotion.has_method("lock_side_lane"):
        return false
    var lane: float = _lane_world_z()
    if absf(actor.global_position.z - lane) > 0.02:
        if not _move_to_lane(actor, lane):
            # Never force an NPC through a wall just to hide the depth axis.
            push_warning("ACTION5: Side lane blocked for " + str(actor.get_path()))
            return false
    actor.velocity.z = 0.0
    locomotion.call("lock_side_lane")
    _locked[actor.get_instance_id()] = weakref(actor)
    return true


func _move_to_lane(actor: CharacterBody3D, lane: float) -> bool:
    var delta_z: float = lane - actor.global_position.z
    # First try keeping the original X. Only use X offsets if necessary.
    var offsets: Array[float] = [0.0]
    var steps: int = floori(max_x_nudge / maxf(nudge_step, 0.1))
    for i in range(1, steps + 1):
        offsets.append(float(i) * nudge_step)
        offsets.append(-float(i) * nudge_step)
    for dx in offsets:
        var lateral := Vector3(dx, 0.0, 0.0)
        if absf(dx) > 0.001 and actor.test_move(actor.global_transform, lateral):
            continue
        var shifted := actor.global_transform.translated(lateral)
        if actor.test_move(shifted, Vector3(0.0, 0.0, delta_z)):
            continue
        actor.global_position += lateral + Vector3(0.0, 0.0, delta_z)
        return true
    return false


func _physics_process(_delta: float) -> void:
    _prune_enemy_pairs()
    if not _side_active:
        return
    for id in _locked.keys():
        var actor: CharacterBody3D = (_locked[id] as WeakRef).get_ref() as CharacterBody3D
        if not is_instance_valid(actor) or not actor.is_inside_tree() \
                or actor.is_queued_for_deletion():
            _locked.erase(id)
            continue
        if not actor.can_process() or not _belongs_to_active_location(actor):
            continue
        if absf(actor.global_position.z - _lane_world_z()) > 0.08:
            _align(actor)


func _unlock_all() -> void:
    for id in _locked.keys():
        var actor: CharacterBody3D = (_locked[id] as WeakRef).get_ref() as CharacterBody3D
        if is_instance_valid(actor):
            var locomotion: Node = actor.get_node_or_null("Locomotion")
            if locomotion != null and locomotion.has_method("unlock_side_lane"):
                locomotion.call("unlock_side_lane")
    _locked.clear()


func _exit_tree() -> void:
    _unlock_all()
    _prune_enemy_pairs(true)
    if is_instance_valid(views) and views.view_changed.is_connected(_on_view_changed):
        views.view_changed.disconnect(_on_view_changed)
    if is_instance_valid(locations) \
            and locations.location_changed.is_connected(_on_location_changed):
        locations.location_changed.disconnect(_on_location_changed)
    if is_instance_valid(session) \
            and session.encounter_activation_changed.is_connected(_on_encounter_activated):
        session.encounter_activation_changed.disconnect(_on_encounter_activated)
    if get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.disconnect(_on_node_added)
