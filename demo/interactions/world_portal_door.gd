extends "res://demo/interactions/world_door.gd"
## A world-local passage: open the physical gate and move the SAME actor
## between sectors of one live SceneTree. No scene recreation for Restore.
## NPC/scripted callers use the same interact(actor) protocol.

@export var session_path: NodePath = ^"../WorldSession"
@export_enum("arena", "encounter") var destination_sector: String = "encounter"
@export_enum("Restore previous", "Start fresh") var entry_policy: int = 0


func interact(actor: Node3D) -> bool:
    if not can_interact(actor):
        return false
    var session := get_node_or_null(session_path)
    if session == null or not session.has_method("travel_to"):
        return false
    if not bool(session.call("travel_to", actor, StringName(destination_sector),
            entry_policy == 1)):
        return false
    # Opening affects collision and NavigationLink3D; sector changes only
    # when the actor traverses, not when its camera/view mode changes.
    set_open(true)
    return true
