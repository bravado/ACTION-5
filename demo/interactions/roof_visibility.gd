extends Node
## Pure presentation. It never disables the roof's StaticBody3D,
## its CollisionShape or navigation/muzzle query authority.

@export var view_manager_path: NodePath = ^"../../ViewManager"
@export var mesh_path: NodePath = ^"../Roof/Mesh"
@export var hidden_view_indices: PackedInt32Array = PackedInt32Array([3, 4])

@onready var views: Node = get_node_or_null(view_manager_path)
@onready var roof_mesh: GeometryInstance3D = get_node_or_null(mesh_path) as GeometryInstance3D
var _original_shadow_mode: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _ready() -> void:
    if roof_mesh == null or views == null:
        return
    _original_shadow_mode = roof_mesh.cast_shadow
    views.view_changed.connect(_on_view_changed)
    refresh()


func refresh() -> void:
    if not is_instance_valid(views) or not is_instance_valid(roof_mesh):
        return
    var hide: bool = hidden_view_indices.has(int(views.get("active_index")))
    roof_mesh.visible = not hide
    roof_mesh.cast_shadow = (
        GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if hide else _original_shadow_mode
    )


func _on_view_changed(_current: Resource, _previous: Resource) -> void:
    refresh()


func _exit_tree() -> void:
    if is_instance_valid(views) and views.view_changed.is_connected(_on_view_changed):
        views.view_changed.disconnect(_on_view_changed)
    if is_instance_valid(roof_mesh):
        roof_mesh.visible = true
        roof_mesh.cast_shadow = _original_shadow_mode
