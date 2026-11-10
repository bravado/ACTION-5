extends Node3D
## Demo transition port. Interactions request a scene change, never move the
## actor, own equipment, or change combat state. D08 world-streaming is a
## separate future feature.

signal entered(actor: Node3D)

const TransferScript = preload("res://demo/interactions/scene_handoff.gd")

@export var destination_scene: PackedScene
## Path-based destination supports back doors without circular scene imports.
@export_file("*.tscn") var destination_scene_path: String = ""
@export_range(0.5, 8.0, 0.1) var interaction_radius: float = 2.5
## Configured on the ENTERING doorway. Restore keeps earlier NPC/world
## state if visited; Start fresh discards only the destination's saved state.
## Player inventory and HP cross doors in both modes.
@export_enum("Restore previous", "Start fresh") var entry_policy: int = 0

var transition_pending: bool = false
var _traveller: Node3D


func can_interact(actor: Node3D) -> bool:
    if transition_pending or (destination_scene == null and destination_scene_path.is_empty()) \
            or not is_inside_tree() \
            or not is_instance_valid(actor) or not actor.is_inside_tree():
        return false
    if actor.has_method("set_alive") and not bool(actor.get("alive")):
        return false
    return actor.global_position.distance_to(global_position) <= interaction_radius


func interact(actor: Node3D) -> bool:
    var scene: Node = get_tree().current_scene
    if not can_interact(actor) or scene == null \
            or not scene.is_ancestor_of(self) or not scene.is_ancestor_of(actor):
        return false
    transition_pending = true
    _traveller = actor
    entered.emit(actor)
    # Changing the tree inside an _unhandled_input dispatch can invalidate
    # other input receivers. Defer it and ignore repeated E presses.
    call_deferred("_change_scene")
    return true


func _change_scene() -> void:
    if not is_inside_tree():
        return
    var destination: PackedScene = destination_scene
    if destination == null and not destination_scene_path.is_empty():
        destination = load(destination_scene_path) as PackedScene
    if destination == null:
        transition_pending = false
        push_warning("ACTION5: Door destination scene could not load")
        return
    if not is_instance_valid(_traveller) or not _traveller.is_inside_tree():
        transition_pending = false
        return
    var handoff: Dictionary = TransferScript.capture(_traveller)
    handoff["destination"] = destination.resource_path
    handoff["entry_policy"] = entry_policy
    get_tree().set_meta(TransferScript.META_KEY, handoff)
    var result: Error = get_tree().change_scene_to_packed(destination)
    if result != OK:
        get_tree().remove_meta(TransferScript.META_KEY)
        transition_pending = false
        push_error("ACTION5: Door scene transition failed (%d)" % result)
