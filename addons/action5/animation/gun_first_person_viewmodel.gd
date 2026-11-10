extends "res://addons/action5/animation/first_person_weapon_viewmodel.gd"
class_name Action5GunFirstPersonViewmodel
## The one extra visual-only source hook allows reload poses without
## commandeering CombatController's independent attack action clock.

@export var reload_profile: Resource
@export var visual_muzzle_path: NodePath = ^"Grip/VisualMuzzle"
var visual_source: Node


func set_visual_source(source: Node) -> void:
    visual_source = source


func apply_action_pose(action_key: StringName, progress: float) -> void:
    if is_instance_valid(visual_source) and visual_source.has_method("get_visual_action"):
        var state: Dictionary = visual_source.call("get_visual_action")
        if not state.is_empty() and reload_profile != null:
            _apply_profile(reload_profile, float(state.get("progress", 0.0)))
            return
    super.apply_action_pose(action_key, progress)


## Camera-local muzzle position sampled at the instant Gun.fired is emitted.
## This visual origin is never consulted for the physical hitscan.
func get_projectile_visual_origin() -> Variant:
    var marker := get_node_or_null(visual_muzzle_path) as Node3D
    return marker.global_position if is_instance_valid(marker) else null
