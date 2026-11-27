extends CanvasLayer
class_name Action5DebugHud
## Opt-in read-only developer panel. Not installed by gameplay runtime.
## Never polls when disabled and self-removes in non-debug builds.

var actor: CharacterBody3D
var view_manager: Node
var ai: Node
var show_movement: bool = true
var show_combat: bool = true
var show_ai: bool = true

var _label: Label
var _elapsed: float = 0.0
var _samples: int = 0


func _ready() -> void:
    if not OS.has_feature("debug"):
        queue_free()
        return
    var panel := PanelContainer.new()
    panel.name = "DebugPanel"
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(panel)
    panel.offset_left = 12
    panel.offset_top = 12
    _label = Label.new()
    _label.name = "Readout"
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.add_theme_font_size_override("font_size", 13)
    panel.add_child(_label)
    set_enabled(false)


func bind_sources(actor_source: CharacterBody3D, views: Node, ai_source: Node = null) -> void:
    actor = actor_source
    view_manager = views
    ai = ai_source


func set_enabled(enabled: bool) -> void:
    if not OS.has_feature("debug"):
        return
    visible = enabled
    set_process(enabled)
    if enabled:
        _elapsed = 0.0
        _refresh()


func toggle() -> void:
    set_enabled(not visible)


func set_section_enabled(section: StringName, enabled: bool) -> void:
    match section:
        &"movement":
            show_movement = enabled
        &"combat":
            show_combat = enabled
        &"ai":
            show_ai = enabled
    _refresh()


func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed >= 0.2:
        _elapsed = 0.0
        _refresh()


func _refresh() -> void:
    if not visible or _label == null:
        return
    _samples += 1
    var lines: PackedStringArray = [
        "ACTION-5 DEBUG",
        "FPS: %d  physics tick: %d" % [
            Engine.get_frames_per_second(), Engine.get_physics_frames()
        ]
    ]
    if is_instance_valid(view_manager):
        var profile: Variant = view_manager.get("current_profile")
        if profile != null:
            lines.append("View: %s" % profile.get("display_name"))
    if is_instance_valid(actor) and show_movement:
        var controller: Node = actor.get_node_or_null("Locomotion/MovementController")
        if controller != null:
            lines.append("Move: %s" % controller.get("active_id"))
        lines.append("Velocity: %s" % actor.velocity.snapped(Vector3.ONE * 0.01))
    if is_instance_valid(actor) and show_combat:
        var combat: Node = actor.get_node_or_null("CombatController")
        if combat != null:
            lines.append("Attack: %s  phase: %s  tick: %d" % [
                combat.get("current_id"), combat.get("phase"), int(combat.get("elapsed_ticks"))
            ])
    if show_ai and is_instance_valid(ai):
        lines.append("AI: %s" % ai.get("state"))
    _label.text = "\n".join(lines)


func sample_count() -> int:
    return _samples
