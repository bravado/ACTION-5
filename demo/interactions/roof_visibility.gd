extends CanvasLayer
## D08 roof/atmosphere presentation only. The physical dungeon ceiling
## lives in encounter_sector.tscn; this layer never touches collision,
## navigation, weapon traces or camera settings.
##
## A horizontal 3D roof box crosses the F1/F2 camera frustum and paints
## only the upper part of the screen. A screen-space full-rect tint avoids
## that projection artifact at every aspect ratio and camera zoom.
## Canvas layer 0 draws over 3D and below the HUD's layer 1.

@export var session_path: NodePath = ^"../WorldSession"
@export var view_manager_path: NodePath = ^"../ViewManager"
@export var tinted_sector: StringName = &"encounter"
@export var tinted_view_indices: PackedInt32Array = PackedInt32Array([0, 1, 2, 4])

@onready var session: Node = get_node_or_null(session_path)
@onready var views: Node = get_node_or_null(view_manager_path)
@onready var tint: ColorRect = $Tint


func _ready() -> void:
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if not is_instance_valid(session) or not is_instance_valid(views):
        tint.hide()
        push_error("ACTION5: RoofVisibility requires WorldSession and ViewManager")
        return
    session.sector_changed.connect(_on_sector_changed)
    views.view_changed.connect(_on_view_changed)
    refresh()


func refresh() -> void:
    if not is_instance_valid(tint):
        return
    tint.visible = (
        is_instance_valid(session)
        and is_instance_valid(views)
        and session.get("current_sector") == tinted_sector
        and tinted_view_indices.has(int(views.get("active_index")))
    )


func _on_sector_changed(_previous: StringName, _current: StringName) -> void:
    refresh()


func _on_view_changed(_current: Resource, _previous: Resource) -> void:
    refresh()


func _exit_tree() -> void:
    if is_instance_valid(session) and session.sector_changed.is_connected(_on_sector_changed):
        session.sector_changed.disconnect(_on_sector_changed)
    if is_instance_valid(views) and views.view_changed.is_connected(_on_view_changed):
        views.view_changed.disconnect(_on_view_changed)
