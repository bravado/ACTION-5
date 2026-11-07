extends "res://addons/action5/actor/action_actor.gd"
## Demo-only placeholder assets. The reusable FPS presenter owns render layers,
## shadows, camera attachment and cleanup; equipment gameplay belongs to D06.

const FirstPersonScript = preload("res://addons/action5/animation/first_person_presenter.gd")

@export var world_tool_scene: PackedScene = preload("res://demo/assets/training_tool.tscn")
@export var first_person_tool_scene: PackedScene = preload("res://demo/assets/first_person_training_tool.tscn")


func _ready() -> void:
    var socket: Node3D = $AnimationPresenter.get_socket(&"right_hand")
    if socket == null or world_tool_scene == null:
        return
    var world_tool := world_tool_scene.instantiate() as MeshInstance3D
    if world_tool == null:
        push_warning("ACTION5: demo training tool must be a MeshInstance3D")
        return
    socket.add_child(world_tool)

    var fps: FirstPersonScript = $FirstPersonPresenter as FirstPersonScript
    # NPCs retain the ordinary hand-attached tool with normal world shadows.
    if fps == null or not fps.register_world_visual(world_tool):
        return
    if first_person_tool_scene == null:
        return
    var view_tool := first_person_tool_scene.instantiate() as Node3D
    if view_tool != null and not fps.register_first_person_visual(view_tool):
        view_tool.free()
