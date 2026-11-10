extends RefCounted
## One-use, demo-only handoff for scene-loading doors. Equipment remains
## actor-owned within each scene; this snapshot holds only value data
## between destruction of the old scene and creation of the next.
## No global inventory, autoload or shared gameplay-core modifications.

const META_KEY: StringName = &"action5_demo_scene_handoff"
const VERSION: int = 1


static func capture(actor: Node3D) -> Dictionary:
    var payload: Dictionary = {
        "version": VERSION,
        "weapons": [],
        "equipped_index": -1
    }
    if not is_instance_valid(actor):
        return payload
    var equipment := actor.get_node_or_null("Equipment") as Node
    if equipment == null:
        return payload
    var inventory: Array = equipment.get("inventory")
    var equipped: Node = equipment.get("current_weapon") as Node
    var records: Array[Dictionary] = []
    for weapon_node in inventory:
        var weapon := weapon_node as Node3D
        if not is_instance_valid(weapon):
            continue
        # Instanced weapon roots retain scene_file_path after reparenting.
        # This is an authored scene, not a guessed resource name or ID.
        var scene_path: String = weapon.scene_file_path
        if scene_path.is_empty():
            push_warning("ACTION5: Cannot carry a weapon without a PackedScene path")
            continue
        var record: Dictionary = {"scene": scene_path, "state": {}}
        var bridge := weapon.get_node_or_null("PortableState") as Node
        if bridge != null and bridge.has_method("capture_state"):
            record["state"] = bridge.call("capture_state")
        if weapon == equipped:
            payload["equipped_index"] = records.size()
        records.append(record)
    payload["weapons"] = records

    var stage := actor.get_parent() as Node3D
    var world_pickups := stage.get_node_or_null("WorldPickupState") if stage != null else null
    if world_pickups != null and world_pickups.has_method("capture_state"):
        payload["world_pickups"] = world_pickups.call("capture_state")
    var scene_state := stage.get_node_or_null("SceneVisitState") if stage != null else null
    if scene_state != null and scene_state.has_method("capture_state"):
        payload["scene_states"] = scene_state.call("capture_state")

    var health := actor.get_node_or_null("Health") as Node
    if health != null:
        payload["health"] = float(health.get("current_health"))
    return payload


## Call only after the destination player and its Equipment are ready.
## Apply exactly once: a restart must not replay the previous door handoff.
static func restore(actor: Node3D, payload: Dictionary) -> bool:
    if not is_instance_valid(actor) or not actor.is_inside_tree() \
            or int(payload.get("version", -1)) != VERSION:
        return false
    var equipment := actor.get_node_or_null("Equipment") as Node
    var stage := actor.get_parent() as Node3D
    if equipment == null or stage == null:
        return false
    # Apply the previous visit's map history before rebuilding the player's
    # carried equipment. Pickups are tracked by scene-local paths, not by
    # weapon types: two identical weapons in different locations remain
    # independent.
    var world_pickups := stage.get_node_or_null("WorldPickupState")
    var restart_destination: bool = int(payload.get("entry_policy", 0)) == 1
    if world_pickups != null and world_pickups.has_method("restore_state"):
        world_pickups.call("restore_state", payload.get("world_pickups", {}),
            restart_destination)
    var scene_state := stage.get_node_or_null("SceneVisitState")
    if scene_state != null and scene_state.has_method("restore_state"):
        scene_state.call("restore_state", payload.get("scene_states", {}),
            restart_destination)
    var records: Array = payload.get("weapons", [])
    var restored: Array[Node3D] = []
    var complete: bool = true
    for entry in records:
        if not entry is Dictionary:
            complete = false
            continue
        var scene_path: String = str(entry.get("scene", ""))
        var scene := load(scene_path) as PackedScene
        if scene == null:
            complete = false
            push_warning("ACTION5: Unknown transferred weapon scene: " + scene_path)
            continue
        var weapon := scene.instantiate() as Node3D
        if weapon == null:
            complete = false
            continue
        # Using the existing pickup port lets Equipment own registration,
        # socket attachment and all destruction/unequip lifecycle rules.
        stage.add_child(weapon)
        weapon.global_position = actor.global_position
        if not bool(equipment.call("pickup", weapon)):
            complete = false
            weapon.queue_free()
            continue
        restored.append(weapon)
        var bridge := weapon.get_node_or_null("PortableState") as Node
        if bridge != null and bridge.has_method("restore_state"):
            bridge.call("restore_state", entry.get("state", {}))

    var equipped_index: int = int(payload.get("equipped_index", -1))
    if equipped_index >= 0 and equipped_index < restored.size():
        if not bool(equipment.call("equip", restored[equipped_index])):
            complete = false
    elif equipped_index >= 0:
        complete = false

    var health := actor.get_node_or_null("Health") as Node
    if health != null and payload.has("health"):
        var previous: float = float(health.get("current_health"))
        var restored_health: float = clampf(float(payload["health"]), 1.0,
            float(health.get("max_health")))
        health.set("current_health", restored_health)
        if health.has_signal("health_changed"):
            health.emit_signal("health_changed", restored_health, previous)
    return complete
