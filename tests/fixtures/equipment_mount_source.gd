extends Node
## NPC/test fixture mount provider. No AnimationPresenter or local camera.

func get_mount(_socket_id: StringName) -> Node3D:
    return get_node_or_null("Socket") as Node3D
