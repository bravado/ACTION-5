extends Node
## Demo-only per-sector framing. Movement and camera yaw remain in their
## existing actor/view components; only the *world-space clamp rectangle*
## changes when the same player moves into a translated sector.
##
## Duplicate profile Resources so each game instance owns its bounds: no
## changes leak into the shared .tres defaults or another open game scene.

const ProfileScript = preload("res://addons/action5/camera/view_profile.gd")

@export var view_manager_path: NodePath = ^"../ViewManager"
@export var session_path: NodePath = ^"../WorldSession"
@export var dungeon_path: NodePath = ^"../EncounterSector"

@onready var views: Node = get_node_or_null(view_manager_path)
@onready var session: Node = get_node_or_null(session_path)
@onready var dungeon: Node3D = get_node_or_null(dungeon_path) as Node3D

var _baseline_bounds: Array[Dictionary] = []


func _ready() -> void:
    if views == null or session == null or dungeon == null:
        push_error("ACTION5: SectorCameraBounds needs ViewManager, WorldSession and dungeon")
        return
    # This component is placed after ViewManager and CameraSettings in the
    # scene, so preferences have already been loaded into each profile.
    var originals: Array = views.get("profiles")
    if originals.is_empty():
        push_error("ACTION5: SectorCameraBounds needs initialized view profiles")
        return
    for i in range(originals.size()):
        var profile := originals[i] as ProfileScript
        if profile == null:
            push_error("ACTION5: SectorCameraBounds received invalid view profile")
            return
        _baseline_bounds.append({
            "min": profile.bounds_min,
            "max": profile.bounds_max,
        })
        originals[i] = profile.duplicate(true)
    views.set("profiles", originals)
    # Preserve the selected profile and camera angles without invoking
    # switch_view() or resetting the player's facing when the resources
    # become instance-local.
    var active: int = int(views.get("active_index"))
    if active >= 0 and active < originals.size():
        views.set("current_profile", originals[active])
        views.get_node("CameraRig").set("profile", originals[active])
    session.sector_changed.connect(_on_sector_changed)
    set_sector(session.current_sector)


func set_sector(sector: StringName) -> void:
    if views == null or _baseline_bounds.is_empty():
        return
    # The dungeon is authored as a translated PackedScene, not a rotated
    # copy. Arena screen-right must remain +world-X everywhere.
    var offset := Vector2.ZERO
    if sector == &"encounter":
        var origin := get_parent() as Node3D
        offset = Vector2(
            dungeon.global_position.x - origin.global_position.x,
            dungeon.global_position.z - origin.global_position.z
        )
    var profiles: Array = views.get("profiles")
    for i in range(_baseline_bounds.size()):
        var profile := profiles[i] as ProfileScript
        if profile == null:
            continue
        profile.bounds_min = (_baseline_bounds[i]["min"] as Vector2) + offset
        profile.bounds_max = (_baseline_bounds[i]["max"] as Vector2) + offset
    # A scene jump exceeds the camera's follow-smoothing distance.
    # Reframe immediately without rotating the view or changing WASD axes.
    var rig := views.get_node_or_null("CameraRig")
    if rig != null and rig.has_method("refresh_settings"):
        rig.call("refresh_settings")


func _on_sector_changed(_previous: StringName, current: StringName) -> void:
    set_sector(current)


func _exit_tree() -> void:
    if is_instance_valid(session) and session.sector_changed.is_connected(_on_sector_changed):
        session.sector_changed.disconnect(_on_sector_changed)
