extends Node
## NPC-specific opt-in snapshot adapter: authored on the NPC scene, not in
## Actor, MovementController, Combat, Health or the AI decision core.
##
## Preserve stable gameplay state (dead/alive, HP, position/orientation,
## equipped weapon's mutable fields). Recreate transient pathfinding, attack
## timing, knockback and target references on entry instead of resuming
## stale references to a destroyed scene.

@export var actor_path: NodePath = ^".."
@export var health_path: NodePath = ^"../Health"
@export var equipment_path: NodePath = ^"../Equipment"
@export var visual_path: NodePath = ^"../Visual"

@onready var actor: CharacterBody3D = get_node_or_null(actor_path) as CharacterBody3D
@onready var health: Node = get_node_or_null(health_path)
@onready var equipment: Node = get_node_or_null(equipment_path)
@onready var visual: Node3D = get_node_or_null(visual_path) as Node3D


func capture_state() -> Dictionary:
    if not is_instance_valid(actor) or not is_instance_valid(health):
        return {}
    var result: Dictionary = {
        "transform": actor.global_transform,
        "hp": float(health.get("current_health"))
    }
    if is_instance_valid(visual):
        result["visual_rotation"] = visual.rotation
    if is_instance_valid(equipment):
        var weapon := equipment.get("current_weapon") as Node3D
        if is_instance_valid(weapon):
            var bridge := weapon.get_node_or_null("PortableState")
            if bridge != null and bridge.has_method("capture_state"):
                result["weapon_state"] = bridge.call("capture_state")
    return result


func restore_state(snapshot: Dictionary) -> void:
    if not is_instance_valid(actor) or not is_instance_valid(health) \
            or not snapshot.has("hp"):
        return
    if snapshot.has("transform") and snapshot["transform"] is Transform3D:
        actor.global_transform = snapshot["transform"]
    if is_instance_valid(visual) and snapshot.has("visual_rotation"):
        visual.rotation = snapshot["visual_rotation"]
    var previous: float = float(health.get("current_health"))
    var hp: float = clampf(float(snapshot["hp"]), 0.0, float(health.get("max_health")))
    health.set("current_health", hp)
    health.emit_signal("health_changed", hp, previous)
    if hp <= 0.0:
        # Propagate the ordinary Health lifecycle event to HealthActorAdapter,
        # CombatController and AIController. Restored corpses cannot chase,
        # reload, attack or deal damage.
        health.emit_signal("died", null)
        return
    if actor.has_method("set_alive"):
        actor.call("set_alive", true)
    if is_instance_valid(equipment) and snapshot.has("weapon_state"):
        var weapon := equipment.get("current_weapon") as Node3D
        if is_instance_valid(weapon):
            var bridge := weapon.get_node_or_null("PortableState")
            if bridge != null and bridge.has_method("restore_state"):
                bridge.call("restore_state", snapshot["weapon_state"])
