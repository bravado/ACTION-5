extends RefCounted
## D06-01: live equipment instances, combat registration, socket/F4 continuity,
## lifecycle and an alternate NPC mount. Never test a hardcoded ID dispatcher.

const WeaponScript = preload("res://addons/action5/equipment/weapon.gd")
const DefinitionScript = preload("res://addons/action5/equipment/weapon_definition.gd")
const EquipmentScript = preload("res://addons/action5/equipment/equipment_controller.gd")
const VisualScript = preload("res://addons/action5/equipment/equipment_visual_adapter.gd")
const CombatScript = preload("res://addons/action5/combat/combat_controller.gd")
const AnimationBridgeScript = preload("res://addons/action5/animation/combat_animation_adapter.gd")
const AttackScript = preload("res://addons/action5/combat/attack_definition.gd")
const MountScript = preload("res://tests/fixtures/equipment_mount_source.gd")


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var actor: CharacterBody3D = level.get_node("Player") as CharacterBody3D
    var equipment: EquipmentScript = actor.get_node("Equipment") as EquipmentScript
    var visual: VisualScript = actor.get_node("EquipmentVisualAdapter") as VisualScript
    var combat: CombatScript = actor.get_node("CombatController") as CombatScript
    var animation: Node = actor.get_node("AnimationPresenter")
    var fps: Node = actor.get_node("FirstPersonPresenter")
    var views: Node = level.get_node("ViewManager")
    var bat: WeaponScript = level.get_node("BatPickup") as WeaponScript
    var shovel: WeaponScript = level.get_node("ShovelPickup") as WeaponScript
    var health: Node = actor.get_node("Health")
    var selector: Node = actor.get_node("EquipmentAttackSelector")
    var action_input: Node = level.get_node("CombatInput")
    var unarmed_limb: Node = actor.get_node("FirstPersonCombatLimbs")

    # D05 ends with a lethal actor test. D06 begins with the same actor,
    # reset explicitly rather than creating a duplicate gameplay character.
    combat.cancel()
    health.set("current_health", health.get("max_health"))
    health.set("stagger_left", 0)
    health.set("invulnerability_left", 0)
    actor.call("set_alive", true)
    actor.call("set_controls_enabled", true)
    actor.call("clear_motion")
    actor.global_position = Vector3(0, 0.15, 0)
    views.call("switch_view", 1)
    for tick in range(2):
        await tree.physics_frame

    # The camera switch rewrites help text; D06 controls must not revert
    # to the older D05-only caption after entering a different view.
    var controls: Label = level.get_node("Hud/Help") as Label
    verify.call(controls.text.contains("D06 EQUIPMENT")
        and controls.text.contains("E: pickup")
        and controls.text.contains("Q: swap")
        and controls.text.contains("Unassigned actions: Punch/Kick")
        and not controls.text.contains("F: swing")
        and controls.text.contains("G: drop"),
        "D06 HUD help lists equipment controls after a camera switch")

    var socket: Node3D = animation.call("get_socket", &"right_hand") as Node3D
    var starting_shadows: int = fps.world_visual_shadows.size()
    var imported_clips: AnimationPlayer = animation.get("animation_player") as AnimationPlayer
    var world_clips_valid: bool = imported_clips != null
    var contact_arms: Dictionary = {}
    for id in [&"bat_vertical", &"bat_horizontal", &"shovel_overhead"]:
        var clip: Animation = (
            imported_clips.get_animation(id)
            if world_clips_valid and imported_clips.has_animation(id) else null
        )
        if clip == null:
            world_clips_valid = false
            continue
        var expected_ticks: int = 17 if id == &"bat_vertical" else (
            21 if id == &"bat_horizontal" else 20
        )
        if absf(clip.length - float(expected_ticks) / 60.0) > 0.025:
            world_clips_valid = false
        for track in range(clip.get_track_count()):
            var bone_path: NodePath = clip.track_get_path(track)
            if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D \
                    and bone_path.get_subname_count() > 0 \
                    and str(bone_path.get_subname(0)) == "UpperArm_R":
                contact_arms[id] = clip.rotation_track_interpolate(
                    track, clip.length * 0.50
                )
                break
    verify.call(world_clips_valid and contact_arms.size() == 3
        and (contact_arms[&"bat_vertical"] as Quaternion).angle_to(
            contact_arms[&"bat_horizontal"]) > 0.35
        and (contact_arms[&"bat_vertical"] as Quaternion).angle_to(
            contact_arms[&"shovel_overhead"]) > 0.20,
        "Imported world rig has three different keyed equipment arm animations, with authored durations")
    verify.call(equipment != null and visual != null and socket != null
        and bat.definition.weapon_id == &"bat" and shovel.definition.weapon_id == &"shovel",
        "D06 installs the generic equipment, socket and distinct weapon definitions")

    var original_bat_position: Vector3 = bat.global_position
    bat.global_position = Vector3(30, 0.45, 30)
    verify.call(not equipment.pickup(bat),
        "Distant world pickups cannot enter inventory")
    bat.global_position = original_bat_position

    verify.call(equipment.pickup(bat) and equipment.current_weapon == bat
        and equipment.inventory.size() == 1 and bat.is_equipped,
        "Pickup makes the existing physical Bat instance the equipped item")
    verify.call(bat.get_parent() == socket and bat.get_world_meshes().size() == 2
        and combat.get_attack(&"bat_swing") == bat.definition.attacks[0]
        and combat.get_attack(&"bat_horizontal") == bat.definition.attacks[1],
        "Bat equips one instance and registers two independent configured attacks")
    verify.call(visual._registered_meshes.size() == 2
        and fps.world_visual_shadows.size() == starting_shadows + 1
        and visual._viewmodel != null and visual._viewmodel.get_parent() == views.get_active_camera(),
        "Local multi-mesh Bat keeps one world shadow per mesh and one camera-only viewmodel")

    # Distinct resources claim the two physical buttons independently.
    verify.call(action_input.get("action_selection_source") == selector
        and bat.definition.attacks.size() == 2
        and bat.definition.valid()
        and bat.definition.attacks[0].input_action == &"actor_punch"
        and bat.definition.attacks[1].input_action == &"actor_kick"
        and selector.call("get_attack_for_input", &"actor_punch", combat.get_attack(&"punch"))
            == combat.get_attack(&"bat_swing")
        and selector.call("get_attack_for_input", &"actor_kick", combat.get_attack(&"kick"))
            == combat.get_attack(&"bat_horizontal"),
        "Bat left maps to vertical swing; right maps to distinct horizontal strike")
    verify.call(bat.definition.attacks[0].animation_key == &"bat_vertical"
        and bat.definition.attacks[1].animation_key == &"bat_horizontal"
        and bat.definition.attacks[0].animation_channel == 0
        and bat.definition.attacks[1].animation_channel == 0,
        "Both Bat attacks select unique upper-body world clips, never unarmed Punch/Kick")
    verify.call(bat.definition.attacks[1].hitbox_size.x >
        bat.definition.attacks[0].hitbox_size.x
        and bat.definition.attacks[1].hitbox_size.y <
            bat.definition.attacks[0].hitbox_size.y
        and bat.definition.attacks[1].damage != bat.definition.attacks[0].damage
        and bat.definition.attacks[1].visual_action_key == &"bat_horizontal",
        "Horizontal attack has a wider, flatter contact volume and unique visual key")
    combat.cancel()
    # D05's destructive input suite may have used the same action
    # within the current physics frame. Release and drain the old edge
    # before testing a fresh equipped action request.
    Input.action_release(&"actor_kick")
    for tick in range(2):
        await tree.physics_frame
    # Input.action_press must be issued in an idle frame to register the
    # just-pressed edge observed by this manually invoked physics adapter.
    await tree.process_frame
    combat.cancel()
    action_input.set("release_to_rearm", false)
    Input.action_press(&"actor_kick")
    var pressed: bool = Input.is_action_just_pressed(&"actor_kick")
    action_input.call("_physics_process", 1.0 / 60.0)
    Input.action_release(&"actor_kick")
    verify.call(pressed and combat._pending_id == &"bat_horizontal",
        "Right attack input requests Bat horizontal, never Kick")
    combat.cancel()
    Input.action_release(&"actor_punch")
    for tick in range(2):
        await tree.physics_frame
    await tree.process_frame
    action_input.set("release_to_rearm", false)
    Input.action_press(&"actor_punch")
    var pressed_left: bool = Input.is_action_just_pressed(&"actor_punch")
    action_input.call("_physics_process", 1.0 / 60.0)
    Input.action_release(&"actor_punch")
    verify.call(pressed_left and combat._pending_id == &"bat_swing",
        "Left attack input requests the equipped Bat swing, not Punch")
    combat.cancel()
    action_input.set("release_to_rearm", true)
    for tick in range(2):
        await tree.physics_frame
    combat.cancel()

    views.call("switch_view", 3)
    await tree.process_frame
    unarmed_limb.call("refresh_presentation")
    var bat_view: Node3D = visual._viewmodel as Node3D
    var grip: Node3D = bat_view.get_node_or_null("Grip") as Node3D
    var gripped_arm: Node3D = bat_view.get("arm") as Node3D
    var resting_grip: Vector3 = grip.position if grip != null else Vector3.ZERO
    bat_view.call("apply_action_pose", &"bat_swing", 0.50)
    var vertical_contact: Vector3 = grip.position
    bat_view.call("apply_action_pose", &"bat_horizontal", 0.50)
    var horizontal_contact: Vector3 = grip.position
    verify.call(bat_view.has_method("apply_action_pose")
        and gripped_arm != null and grip != null
        and (gripped_arm.get("profile") as Resource).get("animation_key") == &"bat_horizontal"
        and grip.position.is_equal_approx(gripped_arm.get_node("Extremity").position)
        and absf(horizontal_contact.x - vertical_contact.x) > 0.65
        and horizontal_contact.x < vertical_contact.x
        and vertical_contact.distance_to(resting_grip) > 0.3
        and not unarmed_limb.get_limb_root(&"punch").visible
        and not unarmed_limb.get_limb_root(&"kick").visible,
        "F4 horizontal strike sweeps laterally with its attached hand and weapon")
    bat_view.call("apply_action_pose", &"", 0.0)
    verify.call(gripped_arm.get("profile") == bat_view.get("grip_profile")
        and grip.position.distance_to(resting_grip) < 0.01,
        "F4 alternate sweep returns to the single resting hand with no second copy")
    verify.call(combat.request_attack(&"bat_horizontal", Vector2.RIGHT),
        "F4 right-side Bat action starts through the normal D05 timeline")
    for tick in range(9):
        await tree.physics_frame
    visual.call("refresh_presentation")
    var horizontal_snapshot: Dictionary = actor.get_node(
        "CombatVisualState").call("get_visual_action")
    verify.call(horizontal_snapshot.get("key", &"") == &"bat_horizontal"
        and horizontal_snapshot.get("action_id", &"") == &"bat_horizontal"
        and (gripped_arm.get("profile") as Resource).get("animation_key") == &"bat_horizontal"
        and float(bat_view.get("pose_progress")) > 0.2
        and grip.position.is_equal_approx(gripped_arm.get_node("Extremity").position),
        "Real F4 Bat horizontal attack selects its own profile without another combat clock")
    combat.cancel()
    visual.call("refresh_presentation")
    verify.call(gripped_arm.get("profile") == bat_view.get("grip_profile")
        and is_zero_approx(float(bat_view.get("pose_progress"))),
        "F4 bat horizontal action resets to the original rest profile on cancel")
    views.call("switch_view", 2)

    # F3 <-> F4 only changes rendering, never item identity, socket or action.
    views.call("switch_view", 2)
    views.call("switch_view", 3)
    verify.call(equipment.current_weapon == bat and bat.get_parent() == socket
        and fps.first_person and visual._viewmodel != null,
        "F3/F4 switching preserves one authoritative equipped world Bat")
    views.call("switch_view", 2)
    verify.call(not fps.first_person and bat.get_parent() == socket,
        "Returning to F3 does not detach or recreate weapon")

    var near: Node3D = level.get_node("NearDummy") as Node3D
    var target: Node = near.get_node("Health")
    near.global_position = actor.global_position + Vector3(1.5, -0.15, 0)
    target.set("current_health", target.get("max_health"))
    target.set("invulnerability_left", 0)
    target.set("blocking", false)
    target.set("immune", false)
    target.set("team_id", 2)
    # D05's lifecycle tests remove the optional animation bridge. Reattach
    # it for actual world-pose verification, without changing Combat's API.
    var bat_animation_bridge: Node = actor.get_node_or_null("CombatAnimationAdapter")
    var temporary_bat_bridge: bool = bat_animation_bridge == null
    if temporary_bat_bridge:
        bat_animation_bridge = AnimationBridgeScript.new()
        bat_animation_bridge.name = "D06BatWorldAnimationBridge"
        actor.add_child(bat_animation_bridge)
    verify.call(equipment.request_equipped_action(0, Vector2.RIGHT),
        "Bat delegates its configured swing to the D05 physics action runner")
    for tick in range(11):
        await tree.physics_frame
        if tick == 3:
            var action_visual: Dictionary = (
                actor.get_node("CombatVisualState").call("get_visual_action")
            )
            verify.call(action_visual.get("key", &"") == &"bat_swing"
                and combat.current_attack.animation_key == &"bat_vertical"
                and animation.get("upper_body_clip") == &"bat_vertical"
                and animation.get("action_clip") == &"",
                "World rig plays authored Bat vertical upper-body clip; F4 retains its independent pose")
    verify.call(float(target.get("current_health")) ==
        float(target.get("max_health")) - 16.0 and combat.hit_count == 1,
        "Bat vertical swing hits the nearby target once across two hurtboxes")
    combat.cancel()
    target.set("current_health", target.get("max_health"))
    target.set("invulnerability_left", 0)
    verify.call(equipment.request_equipped_action(1, Vector2.RIGHT),
        "Secondary Bat action can be requested independently of primary")
    for tick in range(13):
        await tree.physics_frame
        if tick == 3:
            verify.call(animation.get("upper_body_clip") == &"bat_horizontal"
                and animation.get("action_clip") == &"",
                "Bat horizontal uses distinct world upper-body clip and never Kick")
    verify.call(float(target.get("current_health")) ==
        float(target.get("max_health")) - 13.0 and combat.hit_count == 1,
        "Horizontal Bat sweep uses its own contact volume/damage and deduplicates hits")
    combat.cancel()
    verify.call(animation.get("upper_body_clip") == &"",
        "Cancelling Bat action restores locomotion-only animation")
    if temporary_bat_bridge:
        bat_animation_bridge.queue_free()
        await tree.process_frame

    # An externally resolved hit uses the same action clock but must never
    # run a melee box query. D06-02 gun effects can consume the existing
    # attack_phase_changed(active) signal and trace from a physical muzzle.
    combat.cancel()
    var external_action: AttackScript = AttackScript.new()
    external_action.attack_id = &"test_external_effect"
    external_action.use_melee_hit_query = false
    external_action.startup_ticks = 0
    external_action.active_ticks = 2
    external_action.recovery_ticks = 0
    external_action.damage = 99.0
    target.set("current_health", target.get("max_health"))
    target.set("invulnerability_left", 0)
    verify.call(combat.register_attack(external_action)
        and combat.request_attack(&"test_external_effect", Vector2.RIGHT),
        "External-only action registers and uses the normal D05 physics clock")
    for tick in range(4):
        await tree.physics_frame
    verify.call(is_equal_approx(
        float(target.get("current_health")), float(target.get("max_health"))
    ) and combat.hit_count == 0,
        "Data-driven external hit action never performs unintended melee damage")
    verify.call(combat.unregister_attack(&"test_external_effect"),
        "External-only action unregisters through the same generic lifecycle")

    # Removing a buffered weapon action must not cancel a different active
    # action. Conversely removing the active action retains another buffer.
    var active_action: AttackScript = AttackScript.new()
    active_action.attack_id = &"test_unrelated_active"
    active_action.use_melee_hit_query = false
    active_action.startup_ticks = 0
    active_action.active_ticks = 12
    active_action.recovery_ticks = 0
    var queued_action: AttackScript = AttackScript.new()
    queued_action.attack_id = &"test_queued_removed"
    queued_action.use_melee_hit_query = false
    queued_action.startup_ticks = 0
    queued_action.active_ticks = 4
    queued_action.recovery_ticks = 0
    verify.call(combat.register_attack(active_action)
        and combat.register_attack(queued_action)
        and combat.request_attack(active_action.attack_id, Vector2.RIGHT),
        "Independent active and buffered definitions register with the D05 clock")
    await tree.physics_frame
    var active_tick: int = combat.elapsed_ticks
    verify.call(combat.current_id == active_action.attack_id
        and combat.request_attack(queued_action.attack_id, Vector2.RIGHT)
        and combat.unregister_attack(queued_action.attack_id)
        and combat.current_id == active_action.attack_id
        and combat.elapsed_ticks == active_tick and combat._pending_id == &"",
        "Unregistering only a pending attack leaves the unrelated active clock intact")
    await tree.physics_frame
    verify.call(combat.current_id == active_action.attack_id
        and combat.elapsed_ticks == active_tick + 1,
        "Unrelated active attack keeps advancing after buffered removal")
    combat.cancel()
    verify.call(combat.register_attack(queued_action)
        and combat.request_attack(active_action.attack_id, Vector2.RIGHT),
        "Reverse cancellation case can register and request both actions")
    await tree.physics_frame
    verify.call(combat.request_attack(queued_action.attack_id, Vector2.RIGHT)
        and combat.unregister_attack(active_action.attack_id)
        and combat.current_attack == null
        and combat._pending_id == queued_action.attack_id,
        "Removing an active attack preserves a different queued action")
    await tree.physics_frame
    verify.call(combat.current_id == queued_action.attack_id
        and combat.elapsed_ticks == 1,
        "Preserved queued attack starts on the next physics tick")
    combat.cancel()
    combat.unregister_attack(queued_action.attack_id)

    verify.call(equipment.pickup(shovel) and equipment.inventory.size() == 2
        and equipment.current_weapon == bat and shovel.equipment_owner == equipment,
        "Second weapon is a stowed independent instance until explicitly swapped")

    # A second actor with fully working equipment/combat/mount ports cannot
    # steal a hidden/stowed item that still belongs to this actor.
    var rival := CharacterBody3D.new()
    rival.name = "IndependentCollector"
    var rival_combat: CombatScript = CombatScript.new()
    rival_combat.name = "CombatController"
    rival.add_child(rival_combat)
    var rival_mount: Node = MountScript.new()
    rival_mount.name = "SocketProvider"
    rival.add_child(rival_mount)
    var rival_socket := Node3D.new()
    rival_socket.name = "Socket"
    rival_mount.add_child(rival_socket)
    var rival_equipment: EquipmentScript = EquipmentScript.new()
    rival_equipment.name = "Equipment"
    rival_equipment.mount_source_path = ^"../SocketProvider"
    rival.add_child(rival_equipment)
    level.add_child(rival)
    rival.global_position = shovel.global_position
    verify.call(not rival_equipment.pickup(shovel)
        and rival_equipment.inventory.is_empty() and equipment.inventory.has(shovel)
        and shovel.equipment_owner == equipment and shovel.get_parent() == equipment,
        "Another actor cannot claim an already-owned stowed Shovel")

    verify.call(equipment.swap_next() and equipment.current_weapon == shovel
        and not bat.is_equipped and not bat.visible and shovel.is_equipped,
        "Swap moves the Shovel to the same socket and stows Bat")
    verify.call(combat.get_attack(&"bat_swing") == null
        and combat.get_attack(&"bat_horizontal") == null
        and combat.get_attack(&"shovel_swing") != null
        and shovel.definition.attacks[0].get("damage") == 24.0,
        "Unequip unregisters Bat's attack and Shovel uses its own authored parameters")
    verify.call(selector.call("get_attack_for_input", &"actor_punch",
        combat.get_attack(&"punch")) == combat.get_attack(&"shovel_swing")
        and selector.call("get_attack_for_input", &"actor_kick",
        combat.get_attack(&"kick")) == combat.get_attack(&"kick")
        and visual._viewmodel != null
        and visual._viewmodel.get_node_or_null("Grip") != null,
        "Shovel keeps right-click Kick while the Bat had its own horizontal attack")

    # F4 still renders a default Kick for weapons without a right binding.
    views.call("switch_view", 3)
    verify.call(combat.request_attack(&"kick", Vector2.RIGHT),
        "Shovel leaves the unassigned secondary input mapped to normal Kick")
    for tick in range(4):
        await tree.physics_frame
        if combat.current_id == &"kick":
            break
    unarmed_limb.call("refresh_presentation")
    verify.call(combat.current_id == &"kick"
        and unarmed_limb.get_limb_root(&"kick").visible
        and visual._viewmodel != null,
        "Unassigned Shovel Kick retains the real first-person leg")
    combat.cancel()
    views.call("switch_view", 2)

    # Shovel uses its own imported overhead clip, not Punch or Kick.
    # The same world skeleton and socket animate in every camera view.
    verify.call(shovel.definition.attacks[0].animation_key == &"shovel_overhead"
        and int(shovel.definition.attacks[0].animation_channel) == 0
        and shovel.definition.attacks[0].visual_action_key == &"shovel_swing",
        "Shovel binds its own authored overhead world action and separate F4 grip")
    # D05's lifecycle suite intentionally removes the optional animation
    # bridge. Reattach it only while verifying real world animation output.
    # Production Player.tscn already includes this component.
    var world_animation_bridge: Node = actor.get_node_or_null("CombatAnimationAdapter")
    var temporary_animation_bridge: bool = world_animation_bridge == null
    if temporary_animation_bridge:
        world_animation_bridge = AnimationBridgeScript.new()
        world_animation_bridge.name = "D06TemporaryAnimationBridge"
        actor.add_child(world_animation_bridge)
    verify.call(equipment.request_equipped_action(0, Vector2.RIGHT),
        "Equipped Shovel requests its registered attack")
    for tick in range(4):
        await tree.physics_frame
        if combat.current_id == &"shovel_swing":
            break
    var shovel_snapshot: Dictionary = actor.get_node(
        "CombatVisualState").call("get_visual_action")
    verify.call(combat.current_id == &"shovel_swing"
        and animation.get("upper_body_clip") == &"shovel_overhead"
        and animation.get("action_clip") == &""
        and world_animation_bridge.get("_active_channel") == 0
        and shovel_snapshot.get("key", &"") == &"shovel_swing",
        "Shovel plays a distinct world overhead clip without affecting leg locomotion or F4")
    combat.cancel()
    verify.call(animation.get("upper_body_clip") == &"",
        "Cancelling Shovel clears its upper-body overlay without affecting locomotion")
    if temporary_animation_bridge:
        world_animation_bridge.queue_free()
        await tree.process_frame

    verify.call(equipment.request_equipped_action(0, Vector2.RIGHT)
        and equipment.swap_next() and combat.get_attack(&"shovel_swing") == null
        and combat._pending_id == &"" and combat.current_attack == null,
        "Swapping during a pending action cancels that specific attack before unregistration")

    verify.call(equipment.swap_next() and equipment.current_weapon == shovel
        and equipment.drop_current() and shovel.get_parent() == level
        and not shovel.is_equipped and shovel.visible
        and shovel.equipment_owner == null,
        "Dropping restores Shovel's world instance and releases ownership")
    rival.global_position = shovel.global_position
    verify.call(rival_equipment.pickup(shovel)
        and rival_equipment.current_weapon == shovel
        and shovel.equipment_owner == rival_equipment
        and rival_equipment.drop_current() and shovel.equipment_owner == null,
        "Dropped Shovel transfers to another actor and can return to the world")
    rival.queue_free()
    for tick in range(2):
        await tree.process_frame
    verify.call(not equipment.request_equipped_action(0, Vector2.RIGHT)
        and combat.get_attack(&"shovel_swing") == null,
        "Dropped weapon cannot still request or execute its attack")

    verify.call(equipment.swap_next() and equipment.current_weapon == bat
        and combat.get_attack(&"bat_horizontal") == bat.definition.attacks[1]
        and equipment.drop_current() and equipment.inventory.is_empty()
        and combat.get_attack(&"bat_horizontal") == null,
        "Swap selects remaining stowed Bat after a drop; both items can be dropped")
    for tick in range(2):
        await tree.process_frame
    verify.call(fps.world_visual_shadows.size() == starting_shadows
        and visual._registered_meshes.is_empty() and visual._viewmodel == null,
        "Dropping all equipment removes FPS registrations and restores D04 baseline")
    views.call("switch_view", 3)
    await tree.process_frame
    unarmed_limb.call("refresh_presentation")
    verify.call(selector.call("get_attack_for_input", &"actor_punch",
        combat.get_attack(&"punch")) == combat.get_attack(&"punch")
        and selector.call("get_attack_for_input", &"actor_kick",
        combat.get_attack(&"kick")) == combat.get_attack(&"kick")
        and unarmed_limb.get_limb_root(&"punch").visible,
        "After dropping, Punch/Kick and the unarmed F4 resting arm return")
    views.call("switch_view", 2)

    # Third independently authored weapon: no changes to the generic
    # controller, actor, renderer or input adapter.
    var custom_attack: AttackScript = AttackScript.new()
    custom_attack.attack_id = &"test_club_swing"
    custom_attack.input_action = &"actor_kick"
    custom_attack.animation_key = &"punch"
    custom_attack.visual_action_key = &"test_club_swing"
    custom_attack.damage = 7.0
    custom_attack.hitbox_size = Vector3(0.65, 1.0, 1.1)
    var custom_def: DefinitionScript = DefinitionScript.new()
    custom_def.weapon_id = &"test_club"
    custom_def.display_name = "Test club"
    custom_def.attacks = [custom_attack]
    var third: WeaponScript = WeaponScript.new()
    third.name = "IndependentClub"
    third.definition = custom_def
    for i in range(2):
        var mesh := MeshInstance3D.new()
        mesh.name = "Part" + str(i)
        mesh.mesh = BoxMesh.new()
        third.add_child(mesh)
    level.add_child(third)
    third.global_position = actor.global_position + Vector3(0.4, 0.4, 0.3)
    verify.call(equipment.pickup(third) and equipment.current_weapon == third
        and third.get_parent() == socket and third.get_world_meshes().size() == 2,
        "Independent third weapon installs through resources and the same mount")
    verify.call(combat.get_attack(&"test_club_swing") == custom_attack
        and is_equal_approx(custom_attack.hitbox_size.x, 0.65),
        "Third weapon registers its exact configured attack and hit dimensions")
    verify.call(selector.call("get_attack_for_input", &"actor_punch",
        combat.get_attack(&"punch")) == combat.get_attack(&"punch")
        and selector.call("get_attack_for_input", &"actor_kick",
        combat.get_attack(&"kick")) == custom_attack,
        "Right-only custom weapon leaves Punch intact and replaces only Kick")
    var conflict: AttackScript = AttackScript.new()
    conflict.attack_id = &"test_conflicting_action"
    conflict.input_action = &"actor_kick"
    var invalid_definition: DefinitionScript = DefinitionScript.new()
    invalid_definition.weapon_id = &"test_duplicate_binding"
    invalid_definition.attacks = [custom_attack, conflict]
    verify.call(not invalid_definition.valid(),
        "Weapon validation rejects two attacks assigned to the same input")
    # A third item intentionally has NO camera-local scene. It must keep
    # its world meshes on visible render layers and retain the F4 hand,
    # instead of registering meshes for culling with no replacement.
    var world_fallback_visible: bool = true
    for mesh in third.get_world_meshes():
        world_fallback_visible = (
            world_fallback_visible and mesh.visible and mesh.layers == 1
            and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        )
    views.call("switch_view", 3)
    await tree.process_frame
    unarmed_limb.call("refresh_presentation")
    # The demo training tool is hidden while equipped; without an F4
    # replacement, the fallback world meshes cast their own shadows and
    # require no duplicated FirstPersonPresenter shadow registrations.
    verify.call(world_fallback_visible and visual._viewmodel == null
        and visual._registered_meshes.is_empty()
        and fps.world_visual_shadows.is_empty()
        and fps.first_person and views.get_active_camera().get_cull_mask_value(1)
        and unarmed_limb.get_limb_root(&"punch").visible,
        "Third weapon without an F4 scene remains world-visible and keeps the unarmed hand")
    views.call("switch_view", 2)
    verify.call(equipment.drop_current()
        and combat.get_attack(&"test_club_swing") == null,
        "Third weapon cleans up its attack registry on drop")
    for tick in range(2):
        await tree.process_frame

    # An item may register attacks without assigning any button. The base
    # Punch/Kick mappings remain available with equipment held.
    var unassigned_attack: AttackScript = AttackScript.new()
    unassigned_attack.attack_id = &"test_unassigned"
    var unassigned_definition: DefinitionScript = DefinitionScript.new()
    unassigned_definition.weapon_id = &"test_unassigned_item"
    unassigned_definition.attacks = [unassigned_attack]
    var unassigned_weapon: WeaponScript = WeaponScript.new()
    unassigned_weapon.definition = unassigned_definition
    unassigned_weapon.name = "IndependentUnassigned"
    level.add_child(unassigned_weapon)
    unassigned_weapon.global_position = actor.global_position + Vector3(0.3, 0.4, 0.2)
    verify.call(equipment.pickup(unassigned_weapon)
        and combat.get_attack(&"test_unassigned") == unassigned_attack
        and selector.call("get_attack_for_input", &"actor_punch",
            combat.get_attack(&"punch")) == combat.get_attack(&"punch")
        and selector.call("get_attack_for_input", &"actor_kick",
            combat.get_attack(&"kick")) == combat.get_attack(&"kick"),
        "Weapon with zero assigned inputs preserves both Punch and Kick")
    verify.call(equipment.drop_current()
        and combat.get_attack(&"test_unassigned") == null,
        "Unassigned weapon unregisters cleanly on drop")
    unassigned_weapon.queue_free()
    for tick in range(2):
        await tree.process_frame

    # Two independently configured attacks may each claim one existing
    # input, without creating a weapon-type branch or reusing list indices.
    var dual_left: AttackScript = AttackScript.new()
    dual_left.attack_id = &"test_dual_left"
    dual_left.input_action = &"actor_punch"
    var dual_right: AttackScript = AttackScript.new()
    dual_right.attack_id = &"test_dual_right"
    dual_right.input_action = &"actor_kick"
    var dual_definition: DefinitionScript = DefinitionScript.new()
    dual_definition.weapon_id = &"test_dual_binding"
    dual_definition.attacks = [dual_left, dual_right]
    var dual_weapon: WeaponScript = WeaponScript.new()
    dual_weapon.name = "IndependentDualBinding"
    dual_weapon.definition = dual_definition
    level.add_child(dual_weapon)
    dual_weapon.global_position = actor.global_position + Vector3(0.3, 0.4, 0.2)
    verify.call(equipment.pickup(dual_weapon) and dual_definition.valid()
        and combat.get_attack(&"test_dual_left") == dual_left
        and combat.get_attack(&"test_dual_right") == dual_right
        and selector.call("get_attack_for_input", &"actor_punch",
            combat.get_attack(&"punch")) == dual_left
        and selector.call("get_attack_for_input", &"actor_kick",
            combat.get_attack(&"kick")) == dual_right,
        "Two explicitly bound equipment actions independently replace Punch and Kick")
    verify.call(equipment.drop_current()
        and combat.get_attack(&"test_dual_left") == null
        and combat.get_attack(&"test_dual_right") == null,
        "Removing dual-action equipment unregisters both assigned actions")
    dual_weapon.queue_free()
    for tick in range(2):
        await tree.process_frame

    # A right-only weapon deliberately reuses the unarmed "punch" world
    # visual key. The unassigned Punch remains visible in F4; executing
    # the equipped action with that same clip must not show a fake fist.
    var alias_attack: AttackScript = AttackScript.new()
    alias_attack.attack_id = &"test_right_alias"
    alias_attack.input_action = &"actor_kick"
    alias_attack.animation_key = &"punch"
    var alias_definition: DefinitionScript = DefinitionScript.new()
    alias_definition.weapon_id = &"test_right_alias_item"
    alias_definition.attacks = [alias_attack]
    alias_definition.first_person_scene = bat.definition.first_person_scene
    var alias_weapon: WeaponScript = WeaponScript.new()
    alias_weapon.name = "AliasWeapon"
    alias_weapon.definition = alias_definition
    level.add_child(alias_weapon)
    alias_weapon.global_position = actor.global_position + Vector3(0.4, 0.4, 0.2)
    verify.call(equipment.pickup(alias_weapon)
        and selector.call("get_attack_for_input", &"actor_punch",
            combat.get_attack(&"punch")) == combat.get_attack(&"punch")
        and selector.call("get_attack_for_input", &"actor_kick",
            combat.get_attack(&"kick")) == alias_attack
        and visual._viewmodel != null,
        "Right-only weapon reuses the Punch world clip without claiming left input")
    views.call("switch_view", 3)
    verify.call(combat.request_attack(&"punch", Vector2.RIGHT),
        "Unassigned Punch starts normally while holding the right-only weapon")
    for tick in range(4):
        await tree.physics_frame
        if combat.current_id == &"punch":
            break
    unarmed_limb.call("refresh_presentation")
    visual.call("refresh_presentation")
    verify.call(combat.current_id == &"punch"
        and unarmed_limb.get_limb_root(&"punch").visible
        and is_zero_approx(float(visual._viewmodel.get("pose_progress"))),
        "F4 unassigned Punch remains visible and weapon grip stays idle despite shared key")
    combat.cancel()
    verify.call(combat.request_attack(&"test_right_alias", Vector2.RIGHT),
        "Right-only equipped action can start with a shared visual clip")
    for tick in range(4):
        await tree.physics_frame
        if combat.current_id == &"test_right_alias":
            break
    unarmed_limb.call("refresh_presentation")
    visual.call("refresh_presentation")
    verify.call(combat.current_id == &"test_right_alias"
        and not unarmed_limb.get_limb_root(&"punch").visible
        and float(visual._viewmodel.get("pose_progress")) > 0.0,
        "Equipped action hides bare fist and animates grip despite shared Punch clip")
    combat.cancel()
    views.call("switch_view", 2)
    verify.call(equipment.drop_current(), "Shared-clip weapon drops cleanly")
    alias_weapon.queue_free()
    for tick in range(2):
        await tree.process_frame

    # D07 NPC reuses the same EquipmentController without a first-person
    # renderer. The mount is a tiny duck-typed provider; no CameraRig.
    var npc := CharacterBody3D.new()
    npc.name = "IndependentArmedNPC"
    var npc_combat: CombatScript = CombatScript.new()
    npc_combat.name = "CombatController"
    npc.add_child(npc_combat)
    var mount: Node = MountScript.new()
    mount.name = "SocketProvider"
    npc.add_child(mount)
    var npc_socket := Node3D.new()
    npc_socket.name = "Socket"
    mount.add_child(npc_socket)
    var npc_equipment: EquipmentScript = EquipmentScript.new()
    npc_equipment.name = "Equipment"
    npc_equipment.mount_source_path = ^"../SocketProvider"
    npc.add_child(npc_equipment)
    level.add_child(npc)
    npc.global_position = third.global_position + Vector3(-0.4, 0, 0)
    verify.call(npc_equipment.pickup(third) and third.get_parent() == npc_socket
        and npc_combat.get_attack(&"test_club_swing") == custom_attack,
        "NPC installs identical weapon with replaceable mount and no local camera")
    var npc_meshes: Array[MeshInstance3D] = third.get_world_meshes()
    var normal_rendering: bool = true
    for mesh in npc_meshes:
        normal_rendering = normal_rendering and mesh.layers == 1
    verify.call(normal_rendering and fps.world_visual_shadows.size() == starting_shadows,
        "NPC world weapon renders normally with no FPS layers or duplicate shadows")
    npc.queue_free()
    for tick in range(2):
        await tree.process_frame
    verify.call(not is_instance_valid(third)
        and fps.world_visual_shadows.size() == starting_shadows,
        "Freeing equipped NPC cleans its weapon without leaking local registrations")
