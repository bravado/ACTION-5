extends Node3D
## Optional, read-only world-space diagnostic lines; no gameplay queries
## when disabled. All sources are supplied by the composing game.
const Hurtbox = preload("res://addons/action5/combat/hurtbox.gd")
const Gun = preload("res://addons/action5/equipment/gun.gd")

var _actor: CharacterBody3D
var _views: Node
var _equipment: Node
var _aim: Node
var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _display: MeshInstance3D
var _sections := {&"hurtboxes": true, &"aim": true, &"bounds": true}
var _samples: int = 0
var _lines: int = 0
var _elapsed: float = 0.0


func _ready() -> void:
    if not OS.has_feature("debug"):
        queue_free()
        return
    _material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material.vertex_color_use_as_albedo = true
    _display = MeshInstance3D.new()
    _display.mesh = _mesh
    _display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_display)
    _display.top_level = true
    _display.global_transform = Transform3D.IDENTITY
    set_enabled(false)


func bind_sources(actor: CharacterBody3D, views: Node, equipment: Node = null,
        aim: Node = null) -> void:
    _actor = actor
    _views = views
    _equipment = equipment
    _aim = aim


func set_enabled(enabled: bool) -> void:
    if not OS.has_feature("debug") or _display == null:
        return
    visible = enabled
    set_physics_process(enabled)
    _elapsed = 0.1
    if not enabled:
        _mesh.clear_surfaces()
        _lines = 0


func toggle() -> void:
    set_enabled(not visible)


func set_section_enabled(section: StringName, enabled: bool) -> void:
    if _sections.has(section):
        _sections[section] = enabled
        _elapsed = 0.1


func sample_count() -> int:
    return _samples


func line_count() -> int:
    return _lines


func _physics_process(delta: float) -> void:
    _elapsed += delta
    if _elapsed < 0.1:
        return
    _elapsed = 0.0
    _refresh()


func _refresh() -> void:
    _samples += 1
    _lines = 0
    _mesh.clear_surfaces()
    if not is_instance_valid(_actor):
        return
    # Generate vertices first so empty categories never create an empty surface.
    var segments: Array[Dictionary] = []
    if _sections[&"hurtboxes"]:
        for node in _actor.find_children("*", "Area3D", true, false):
            if node is Hurtbox and node.has_active_shape():
                var half: Vector3 = node.motion_half_extents()
                _box(segments, node.global_transform, AABB(-half, half * 2.0), Color.GREEN_YELLOW)
    if _sections[&"aim"] and is_instance_valid(_equipment) and is_instance_valid(_aim):
        var weapon: Node = _equipment.get("current_weapon")
        if weapon is Gun and _aim.has_method("get_world_target"):
            var muzzle := weapon.get_node_or_null(weapon.muzzle_path) as Marker3D
            if muzzle != null:
                var origin := muzzle.global_position
                var exclude: Array[RID] = [_actor.get_rid()]
                for node in _actor.find_children("*", "CollisionObject3D", true, false):
                    exclude.append((node as CollisionObject3D).get_rid())
                var target: Vector3 = _aim.call("get_world_target", origin, weapon.maximum_range, exclude)
                if target.is_finite():
                    var direction := target - origin
                    if direction.length_squared() > 0.0001:
                        _segment(segments, origin, origin + direction.limit_length(weapon.maximum_range), Color.ORANGE)
                _box(segments, Transform3D(Basis.IDENTITY, origin),
                    AABB(Vector3.ONE * -0.06, Vector3.ONE * 0.12), Color.YELLOW)
    if _sections[&"bounds"] and is_instance_valid(_views):
        var profile: Resource = _views.get("current_profile")
        if profile != null and profile.get("bound_camera_target"):
            var low: Vector2 = profile.get("bounds_min")
            var high: Vector2 = profile.get("bounds_max")
            var y := _actor.global_position.y + 0.05
            _box(segments, Transform3D.IDENTITY,
                AABB(Vector3(low.x, y, low.y), Vector3(high.x - low.x, 0.05, high.y - low.y)),
                Color.CYAN)
    if segments.is_empty():
        return
    _mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material)
    for segment in segments:
        _mesh.surface_set_color(segment["color"])
        _mesh.surface_add_vertex(segment["a"])
        _mesh.surface_set_color(segment["color"])
        _mesh.surface_add_vertex(segment["b"])
    _mesh.surface_end()
    _lines = segments.size()


func _segment(segments: Array[Dictionary], a: Vector3, b: Vector3, color: Color) -> void:
    segments.append({"a": a, "b": b, "color": color})


func _box(segments: Array[Dictionary], transform: Transform3D, box: AABB, color: Color) -> void:
    for i in range(8):
        for bit in [1, 2, 4]:
            if (i & bit) == 0:
                _segment(segments, transform * box.get_endpoint(i),
                    transform * box.get_endpoint(i | bit), color)
