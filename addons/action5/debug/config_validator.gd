extends RefCounted
class_name Action5ConfigValidator
## Opt-in, read-only authoring checks. No runtime component imports this tool.

const View = preload("res://addons/action5/camera/view_profile.gd")
const Attack = preload("res://addons/action5/combat/attack_definition.gd")
const Weapon = preload("res://addons/action5/equipment/weapon_definition.gd")
const Move = preload("res://addons/action5/actor/moves/move.gd")
const Gun = preload("res://addons/action5/equipment/gun.gd")
const Hurtbox = preload("res://addons/action5/combat/hurtbox.gd")
const Model = preload("res://addons/action5/animation/model_validator.gd")


static func _result(errors: Array[String], warnings: Array[String]) -> Dictionary:
    return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings}


static func validate_view(profile: Resource) -> Dictionary:
    var errors: Array[String] = []
    var warnings: Array[String] = []
    if not profile is View:
        errors.append("ViewProfile: expected Action5ViewProfile")
        return _result(errors, warnings)
    if profile.display_name.strip_edges().is_empty():
        errors.append("ViewProfile: set display_name")
    if profile.bounds_min.x >= profile.bounds_max.x or profile.bounds_min.y >= profile.bounds_max.y:
        errors.append("ViewProfile: bounds_min must be smaller than bounds_max")
    if profile.min_pitch_degrees >= profile.max_pitch_degrees:
        errors.append("ViewProfile: min_pitch_degrees must be smaller than max_pitch_degrees")
    if profile.camera_collision and profile.camera_collision_mask == 0:
        errors.append("ViewProfile: camera_collision requires a nonzero camera_collision_mask")
    if profile.mode == View.Mode.FIRST_PERSON and profile.orthographic:
        errors.append("ViewProfile: first-person mode requires orthographic=false")
    return _result(errors, warnings)


static func validate_attack(attack: Resource, profile: Resource = null,
        player: AnimationPlayer = null) -> Dictionary:
    var errors: Array[String] = []
    var warnings: Array[String] = []
    if not attack is Attack:
        errors.append("AttackDefinition: expected Action5AttackDefinition")
        return _result(errors, warnings)
    if not attack.valid():
        errors.append("AttackDefinition '%s': nonempty attack_id, positive hitbox and active_ticks required" % attack.attack_id)
    if attack.animation_channel < 0 or attack.animation_channel > 1:
        errors.append("Attack '%s': animation_channel must be 0 (upper) or 1 (full)" % attack.attack_id)
    if attack.animation_key != &"" and profile != null:
        if not profile.has_method("clip_name"):
            errors.append("Attack '%s': expected SkeletonProfile.clip_name(key)" % attack.attack_id)
        else:
            var clip: StringName = profile.call("clip_name", attack.animation_key)
            if clip == &"":
                errors.append("Attack '%s': add animation_key '%s' to SkeletonProfile.clip_map" % [
                    attack.attack_id, attack.animation_key])
            elif player != null and not player.has_animation(clip):
                errors.append("Attack '%s': AnimationPlayer is missing mapped clip '%s'" % [
                    attack.attack_id, clip])
    return _result(errors, warnings)


static func validate_weapon(definition: Resource, world: Node = null,
        skeleton: Skeleton3D = null, profile: Resource = null,
        player: AnimationPlayer = null) -> Dictionary:
    var errors: Array[String] = []
    var warnings: Array[String] = []
    if not definition is Weapon:
        errors.append("WeaponDefinition: expected Action5WeaponDefinition")
        return _result(errors, warnings)
    if definition.weapon_id == &"":
        errors.append("WeaponDefinition: set a nonempty weapon_id")
    if definition.socket_id == &"":
        errors.append("Weapon '%s': set socket_id" % definition.weapon_id)
    if skeleton != null and profile != null:
        var bone: StringName = profile.call("socket_bone", definition.socket_id) if profile.has_method("socket_bone") else &""
        if bone == &"" or skeleton.find_bone(str(bone)) < 0:
            errors.append("Weapon '%s': socket '%s' requires a mapped bone on Skeleton3D" % [
                definition.weapon_id, definition.socket_id])
    var ids: Dictionary = {}
    var bindings: Dictionary = {}
    for entry in definition.attacks:
        var report: Dictionary = validate_attack(entry, profile, player)
        errors.append_array(report["errors"])
        warnings.append_array(report["warnings"])
        if not entry is Attack:
            continue
        if ids.has(entry.attack_id):
            errors.append("Weapon '%s': duplicate attack_id '%s'" % [definition.weapon_id, entry.attack_id])
        ids[entry.attack_id] = true
        if entry.input_action == &"":
            errors.append("Weapon '%s': attack '%s' needs an explicit input_action" % [
                definition.weapon_id, entry.attack_id])
        elif bindings.has(entry.input_action):
            errors.append("Weapon '%s': duplicate input_action '%s'" % [
                definition.weapon_id, entry.input_action])
        else:
            bindings[entry.input_action] = true
    if world != null:
        var meshes: Array = world.find_children("*", "MeshInstance3D", true, false)
        if world is MeshInstance3D:
            meshes.append(world)
        if meshes.is_empty():
            errors.append("Weapon '%s': world model needs a MeshInstance3D" % definition.weapon_id)
    # Missing F4 scenes are supported camera-free setups.
    if definition.first_person_scene != null:
        var visual: Node = definition.first_person_scene.instantiate()
        if not visual.has_method("apply_pose"):
            errors.append("Weapon '%s': F4 root must implement apply_pose" % definition.weapon_id)
        if visual.has_method("get_projectile_visual_origin"):
            var marker_path: Variant = visual.get("visual_muzzle_path")
            if marker_path is NodePath and not visual.get_node_or_null(marker_path) is Marker3D:
                errors.append("Weapon '%s': visual_muzzle_path must resolve to Marker3D" % definition.weapon_id)
        visual.free()
    return _result(errors, warnings)


static func validate_gun(gun: Node, aim_provider: Node) -> Dictionary:
    var errors: Array[String] = []
    var warnings: Array[String] = []
    if not gun is Gun:
        errors.append("Gun: expected Action5Gun")
        return _result(errors, warnings)
    if not gun.get_node_or_null(gun.muzzle_path) is Marker3D:
        errors.append("Gun '%s': muzzle_path must resolve to a world Marker3D" % gun.name)
    if aim_provider == null or not aim_provider.has_method("get_world_target"):
        errors.append("Gun '%s': aim provider must implement get_world_target(origin, range, excludes)" % gun.name)
    if (gun.ray_mask & 3) != 3:
        errors.append("Gun '%s': ray_mask must include layer 1 solids and layer 2 Hurtboxes" % gun.name)
    var found: bool = false
    if gun.definition != null:
        for entry in gun.definition.attacks:
            if entry is Attack and entry.attack_id == gun.fire_attack_id:
                found = true
                if entry.use_melee_hit_query:
                    errors.append("Gun '%s': fire attack requires use_melee_hit_query=false" % gun.name)
    if not found:
        errors.append("Gun '%s': fire_attack_id '%s' must exist in WeaponDefinition.attacks" % [
            gun.name, gun.fire_attack_id])
    return _result(errors, warnings)


static func validate_moves(controller: Node) -> Dictionary:
    var errors: Array[String] = []
    var warnings: Array[String] = []
    if controller == null:
        errors.append("MovementController: missing controller")
        return _result(errors, warnings)
    var root: Node = controller.get_node_or_null("Moves")
    if root == null:
        errors.append("MovementController: add Moves child")
        return _result(errors, warnings)
    var ids: Dictionary = {}
    var inputs: Dictionary = {}
    for child in root.get_children():
        if not child is Move:
            continue
        if child.move_id == &"":
            errors.append("Move '%s': set move_id" % child.name)
        elif ids.has(child.move_id):
            errors.append("Move '%s': duplicate move_id '%s'" % [child.name, child.move_id])
        ids[child.move_id] = true
        if child.action_name != &"":
            if inputs.has(child.action_name):
                errors.append("Move '%s': duplicate action_name '%s'" % [child.name, child.action_name])
            inputs[child.action_name] = true
    for property_name in ["grounded_move", "airborne_move"]:
        var fallback: StringName = controller.get(property_name)
        if not ids.has(fallback):
            errors.append("MovementController: %s '%s' is missing from Moves" % [
                property_name, fallback])
    return _result(errors, warnings)


static func validate_receiver(body: CharacterBody3D) -> Dictionary:
    var errors: Array[String] = []
    var warnings: Array[String] = []
    if body == null:
        errors.append("Receiver: expected CharacterBody3D")
        return _result(errors, warnings)
    if (body.collision_layer & 1) == 0:
        errors.append("Receiver '%s': body needs physical collision layer 1" % body.name)
    var found: bool = false
    for node in body.find_children("*", "Area3D", true, false):
        if not node is Hurtbox:
            continue
        found = true
        if not node.has_active_shape():
            errors.append("Hurtbox '%s': enable a CollisionShape3D" % node.name)
        if (node.collision_layer & 2) == 0 or not node.monitorable:
            errors.append("Hurtbox '%s': enable monitorable collision layer 2" % node.name)
        var health: Node = node.get_health()
        if health == null or health.get_parent() != body:
            errors.append("Hurtbox '%s': health_path must resolve to actor-owned Health" % node.name)
    if not found:
        errors.append("Receiver '%s': add an Action5Hurtbox" % body.name)
    return _result(errors, warnings)


static func validate_model(root: Node, profile: Resource) -> Dictionary:
    return Model.validate(root, profile)


## Validate one authored level, not the whole running world. Optional marker
## paths are relative to the level root. Decorative scenes can opt out of
## physical/navigation requirements. No runtime registration or polling.
static func validate_level(root: Node3D, require_collision: bool = true,
        require_navigation: bool = true, marker_paths: Array[NodePath] = []) -> Dictionary:
    var errors: Array[String] = []
    var warnings: Array[String] = []
    if not is_instance_valid(root):
        errors.append("Level root must be a Node3D")
        return _result(errors, warnings)
    var has_collision := false
    var has_navigation := false
    var targets: Array[Action5VisibilityTarget] = []
    var pending: Array[Node] = [root]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        if node is CollisionShape3D and node.shape != null and not node.disabled \
                and node.get_parent() is StaticBody3D:
            has_collision = true
        if node is GridMap and node.mesh_library != null and node.collision_layer != 0:
            for item in node.mesh_library.get_item_list():
                if not node.mesh_library.get_item_shapes(item).is_empty():
                    has_collision = true
                    break
        if node is NavigationRegion3D and node.enabled:
            has_navigation = true
            if node.navigation_mesh == null or node.navigation_mesh.get_polygon_count() == 0:
                warnings.append("%s: assign or bake a NavigationMesh before play" % root.get_path_to(node))
        if node is Action5VisibilityTarget:
            targets.append(node)
        for child in node.get_children():
            pending.append(child)
    if require_collision and not has_collision:
        errors.append("%s: author static collision or a collision-enabled GridMap" % root.name)
    if require_navigation and not has_navigation:
        errors.append("%s: add an enabled NavigationRegion3D and bake navigation" % root.name)
    for path in marker_paths:
        if not root.get_node_or_null(path) is Marker3D:
            errors.append("%s: marker path %s must resolve to Marker3D" % [root.name, path])
    var owners: Dictionary = {}
    for target in targets:
        var context := str(root.get_path_to(target))
        if target.policy == null:
            errors.append("%s: assign a visibility policy" % context)
        var visual_root: Node = target.get_node_or_null(target.visual_root_path)
        if visual_root == null or (visual_root != root and not root.is_ancestor_of(visual_root)):
            errors.append("%s: visual_root_path must resolve within the level" % context)
            continue
        var visuals := target.visuals()
        if visuals.is_empty():
            errors.append("%s: visual_root_path has no MeshInstance3D or GridMap" % context)
        for visual in visuals:
            var id := visual.get_instance_id()
            if owners.has(id):
                errors.append("%s: overlapping visibility target with %s for %s" %
                    [context, owners[id], root.get_path_to(visual)])
            else:
                owners[id] = context
    return _result(errors, warnings)
