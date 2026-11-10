extends Node
## Restores one pending door handoff only in the intended destination.
## Fixture scenes and ordinary restart/load with no pending handoff stay fresh.

const HandoffScript = preload("res://demo/interactions/scene_handoff.gd")

@export var actor_path: NodePath = ^"../Player"


func _ready() -> void:
    call_deferred("_restore")


func _restore() -> void:
    var tree: SceneTree = get_tree()
    var stage: Node = get_parent()
    if stage != tree.current_scene or not tree.has_meta(HandoffScript.META_KEY):
        return
    var payload: Dictionary = tree.get_meta(HandoffScript.META_KEY)
    if str(payload.get("destination", "")) != stage.scene_file_path:
        return
    # Consume before equipment signals can trigger any other scene action.
    tree.remove_meta(HandoffScript.META_KEY)
    var actor := get_node_or_null(actor_path) as Node3D
    if not HandoffScript.restore(actor, payload):
        push_warning("ACTION5: Scene handoff could not restore all equipment")
