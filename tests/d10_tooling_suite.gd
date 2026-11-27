extends RefCounted
## Real resources and scene nodes, including malformed user-authored fixtures.

const Validator = preload("res://addons/action5/debug/config_validator.gd")
const DebugHud = preload("res://addons/action5/debug/debug_hud.gd")
const Attack = preload("res://addons/action5/combat/attack_definition.gd")
const Weapon = preload("res://addons/action5/equipment/weapon_definition.gd")
const Aim = preload("res://addons/action5/combat/actor_target_aim_provider.gd")


func _has(report: Dictionary, substring: String) -> bool:
    for error in report["errors"]:
        if str(error).contains(substring):
            return true
    return false


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var view: Resource = load("res://addons/action5/views/first_person.tres")
    verify.call(Validator.validate_view(view)["valid"], "D10 shipped F4 ViewProfile validates")
    var bad_view: Resource = view.duplicate(true)
    bad_view.orthographic = true
    verify.call(_has(Validator.validate_view(bad_view), "orthographic=false"),
        "D10 incorrect F4 projection reports actionable correction")

    var actor: CharacterBody3D = level.get_node("Player") as CharacterBody3D
    var presenter: Node = actor.get_node("AnimationPresenter")
    var profile: Resource = presenter.get("profile")
    var model: Node = actor.get_node("Visual/Model")
    verify.call(Validator.validate_model(model, profile)["valid"],
        "D10 real imported rig validates")
    var missing_rig := Node3D.new()
    verify.call(_has(Validator.validate_model(missing_rig, profile), "Skeleton3D"),
        "D10 missing rig reports missing Skeleton3D")
    missing_rig.free()

    var attack: Resource = load("res://demo/equipment/gun_fire.tres")
    verify.call(Validator.validate_attack(attack)["valid"],
        "D10 independently authored attack validates")
    var no_id: Resource = attack.duplicate(true)
    no_id.attack_id = &""
    verify.call(_has(Validator.validate_attack(no_id), "attack_id"),
        "D10 attack without ID is rejected")
    var no_clip: Resource = attack.duplicate(true)
    no_clip.animation_key = &"nonexistent_custom_clip"
    verify.call(_has(Validator.validate_attack(no_clip, profile), "clip_map"),
        "D10 missing world clip mapping reports missing key")

    var gun: Node3D = (load("res://demo/equipment/gun.tscn") as PackedScene).instantiate()
    var definition: Resource = gun.get("definition")
    verify.call(Validator.validate_weapon(definition, gun)["valid"],
        "D10 authored gun and optional visual validate")
    var camera_free: Resource = definition.duplicate(true)
    camera_free.first_person_scene = null
    verify.call(Validator.validate_weapon(camera_free, gun)["valid"]
        and Validator.validate_weapon(camera_free, gun)["warnings"].is_empty(),
        "D10 camera-free weapon needs no F4 viewmodel")
    var duplicate: Resource = definition.duplicate(true)
    duplicate.attacks.append(definition.attacks[0])
    verify.call(_has(Validator.validate_weapon(duplicate), "duplicate attack_id")
        and _has(Validator.validate_weapon(duplicate), "duplicate input_action"),
        "D10 duplicate weapon actions and bindings are rejected")
    var no_mesh := Node3D.new()
    verify.call(_has(Validator.validate_weapon(definition, no_mesh), "MeshInstance3D"),
        "D10 missing physical world mesh produces actionable error")
    no_mesh.free()
    var aim: Node = Aim.new()
    verify.call(Validator.validate_gun(gun, aim)["valid"],
        "D10 generic camera-free aim provider accepted")
    gun.set("ray_mask", 1)
    verify.call(_has(Validator.validate_gun(gun, aim), "layer 2"),
        "D10 invalid gun ray mask is diagnosed")
    gun.set("ray_mask", 3)
    gun.set("muzzle_path", ^"Missing")
    verify.call(_has(Validator.validate_gun(gun, aim), "Marker3D"),
        "D10 missing gun world muzzle is diagnosed")
    gun.set("muzzle_path", ^"Muzzle")
    var wrong_aim := Node.new()
    verify.call(_has(Validator.validate_gun(gun, wrong_aim), "get_world_target"),
        "D10 incompatible aim port explains required method")
    wrong_aim.free()
    aim.free()
    gun.free()

    var movement: Node = actor.get_node("Locomotion/MovementController")
    verify.call(Validator.validate_moves(movement)["valid"],
        "D10 existing movement components validate without core changes")
    var missing_moves := Node.new()
    verify.call(_has(Validator.validate_moves(missing_moves), "Moves"),
        "D10 missing Moves root gives diagnostic")
    missing_moves.free()

    verify.call(Validator.validate_receiver(actor)["valid"],
        "D10 real receiver resolves owned enabled Hurtbox/Health")
    var original_layer: int = actor.collision_layer
    actor.collision_layer = 0
    verify.call(_has(Validator.validate_receiver(actor), "layer 1"),
        "D10 physical layer mismatch is diagnosed")
    actor.collision_layer = original_layer

    if OS.has_feature("debug"):
        var overlay := DebugHud.new()
        level.add_child(overlay)
        overlay.bind_sources(actor, level.get_node("ViewManager"))
        verify.call(not overlay.visible and not overlay.is_processing()
            and overlay.sample_count() == 0,
            "D10 hidden overlay makes no periodic samples")
        overlay.set_enabled(true)
        verify.call(overlay.visible and overlay.sample_count() > 0
            and overlay.get_node("DebugPanel/Readout").text.contains("FPS"),
            "D10 overlay can report FPS and actor snapshot")
        overlay.set_section_enabled(&"combat", false)
        verify.call(not overlay.get_node("DebugPanel/Readout").text.contains("Attack:"),
            "D10 combat overlay category is independently switchable")
        overlay.set_enabled(false)
        var old_samples: int = overlay.sample_count()
        await tree.process_frame
        verify.call(not overlay.is_processing() and overlay.sample_count() == old_samples,
            "D10 disabled overlay has zero frame-poll work")
        overlay.queue_free()
        await tree.process_frame
