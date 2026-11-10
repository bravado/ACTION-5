extends Node
## NPC socket provider: attached to actor, but returns a world-facing marker
## under Visual so a Gun's physical muzzle turns with the normal facing port.

func get_mount(_socket_id: StringName) -> Node3D:
    return get_node_or_null("../Visual/Socket") as Node3D
