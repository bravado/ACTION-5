extends RefCounted
## D06-01: live equipment instances, combat registration, socket/F4 continuity,
## lifecycle and an alternate NPC mount. Never test a hardcoded ID dispatcher.

const WeaponScript = preload("res://addons/action5/equipment/weapon.gd")
const DefinitionScript = preload("res://addons/action5/equipment/weapon_definition.gd")
const EquipmentScript = preload("res://addons/action5/equipment/equipment_controller.gd")
const VisualScript = preload("res://addons/action5/equipment/equipment_visual_adapter.gd")
const CombatScript = preload("res://addons/action5/combat/combat_controller.gd")
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
        and controls.text.contains("LMB/RMB/J/K: equipped weapon")
        and not controls.text.contains("F: swing")
        and controls.text.contains("G: drop"),
        "D06 HUD help lists equipment controls after a camera switch")

    var socket: Node3D = animation.call("get_socket", &"right_hand") as Node3D
    var starting_shadows: int = fps.world_visual_shadows.size()
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
        and combat.get_attack(&"bat_swing") != null,
        "Bat attaches to animated right-hand socket and registers only configured attack")
    verify.call(visual._registered_meshes.size() == 2
        and fps.world_visual_shadows.size() == starting_shadows + 1
        and visual._viewmodel != null and visual._viewmodel.get_parent() == views.get_active_camera(),
        "Local multi-mesh Bat keeps one world shadow per mesh and one camera-only viewmodel")

    # Both existing attack intents select the equipped definition. No
    # additional F button and no Punch/Kick when holding a single-action
    # melee weapon; the shared combat input adapter never imports equipment.
    verify.call(action_input.get("action_selection_source") == selector
        and selector.call("get_attack_for_input", &"actor_punch", combat.get_attack(&"punch"))
            == combat.get_attack(&"bat_swing")
        and selector.call("get_attack_for_input", &"actor_kick", combat.get_attack(&"kick"))
            == combat.get_attack(&"bat_swing"),
        "Equipped Bat replaces both left/right attack intents with Bat swing")
    combat.cancel()
    action_input.set("release_to_rearm", false)
    Input.action_press(&"actor_kick")
    action_input.call("_physics_process", 1.0 / 60.0)
    Input.action_release(&"actor_kick")
    verify.call(combat._pending_id == &"bat_swing"
        and combat._pending_id != &"kick",
        "Real right-click action mapping requests equipped Bat instead of unarmed Kick")
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
    bat_view.call("apply_pose", 0.48)
    var contact_grip: Vector3 = grip.position if grip != null else Vector3.ZERO
    verify.call(bat_view.has_method("apply_pose")
        and gripped_arm != null and grip != null
        and grip.position.is_equal_approx(gripped_arm.get_node("Extremity").position)
        and contact_grip.distance_to(resting_grip) > 0.3
        and not unarmed_limb.get_limb_root(&"punch").visible
        and not unarmed_limb.get_limb_root(&"kick").visible,
        "F4 Bat has one authored gripping arm; held mesh follows hand and unarmed overlays hide")
    visual.call("refresh_presentation")
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
    verify.call(equipment.request_equipped_action(0, Vector2.RIGHT),
        "Bat delegates its configured swing to the D05 physics action runner")
    for tick in range(11):
        await tree.physics_frame
    verify.call(float(target.get("current_health")) ==
        float(target.get("max_health")) - 16.0 and combat.hit_count == 1,
        "Bat configured damage/hitbox hits a nearby target once across two hurtboxes")

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

    verify.call(equipment.pickup(shovel) and equipment.inventory.size() == 2
        and equipment.current_weapon == bat,
        "Second weapon is a stowed independent instance until explicitly swapped")
    verify.call(equipment.swap_next() and equipment.current_weapon == shovel
        and not bat.is_equipped and not bat.visible and shovel.is_equipped,
        "Swap moves the Shovel to the same socket and stows Bat")
    verify.call(combat.get_attack(&"bat_swing") == null
        and combat.get_attack(&"shovel_swing") != null
        and shovel.definition.attacks[0].get("damage") == 24.0,
        "Unequip unregisters Bat's attack and Shovel uses its own authored parameters")
    verify.call(selector.call("get_attack_for_input", &"actor_punch",
        combat.get_attack(&"punch")) == combat.get_attack(&"shovel_swing")
        and selector.call("get_attack_for_input", &"actor_kick",
        combat.get_attack(&"kick")) == combat.get_attack(&"shovel_swing")
        and visual._viewmodel != null
        and visual._viewmodel.get_node_or_null("Grip") != null,
        "Shovel uses the same click routing and independent F4 gripping model")

    verify.call(equipment.request_equipped_action(0, Vector2.RIGHT)
        and equipment.swap_next() and combat.get_attack(&"shovel_swing") == null
        and combat._pending_id == &"" and combat.current_attack == null,
        "Swapping during a pending action cancels that specific attack before unregistration")

    verify.call(equipment.swap_next() and equipment.current_weapon == shovel
        and equipment.drop_current() and shovel.get_parent() == level
        and not shovel.is_equipped and shovel.visible,
        "Dropping restores Shovel's real world instance and appearance")
    for tick in range(2):
        await tree.process_frame
    verify.call(not equipment.request_equipped_action(0, Vector2.RIGHT)
        and combat.get_attack(&"shovel_swing") == null,
        "Dropped weapon cannot still request or execute its attack")

    verify.call(equipment.swap_next() and equipment.current_weapon == bat
        and equipment.drop_current() and equipment.inventory.is_empty(),
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
    custom_attack.animation_key = &"punch"
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
    verify.call(visual._registered_meshes.size() == 2,
        "Third weapon receives two independent world-mesh shadow registrations")
    verify.call(equipment.drop_current()
        and combat.get_attack(&"test_club_swing") == null,
        "Third weapon cleans up its attack registry on drop")
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
