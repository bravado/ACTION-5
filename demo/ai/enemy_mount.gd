extends Node
## Demo-only mount provider. Animated characters hold equipment on the
## skeleton's configured bone socket so Bat/Gun follow attack poses.
## A static marker retains a render-optional fallback for headless actors.

@export var animation_path: NodePath = ^"../AnimationPresenter"
@export var fallback_path: NodePath = ^"../Visual/Socket"


func get_mount(socket_id: StringName) -> Node3D:
    var presenter: Node = get_node_or_null(animation_path)
    if is_instance_valid(presenter) and presenter.has_method("get_socket"):
        var attached: Node3D = presenter.call("get_socket", socket_id) as Node3D
        if is_instance_valid(attached):
            return attached
    return get_node_or_null(fallback_path) as Node3D
