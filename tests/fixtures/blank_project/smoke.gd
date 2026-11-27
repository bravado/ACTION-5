extends SceneTree
## Run in a project with only the reusable addon and this example.
const Validator = preload("res://addons/action5/debug/config_validator.gd")
const View = preload("res://addons/action5/camera/view_profile.gd")
const Attack = preload("res://addons/action5/combat/attack_definition.gd")
const Intent = preload("res://addons/action5/actor/move_intent.gd")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var profile: Resource = View.new()
    var attack: Resource = Attack.new()
    attack.attack_id = &"blank_test"
    if not Validator.validate_view(profile)["valid"] or not Validator.validate_attack(attack)["valid"]:
        _fail("resource validation")
        return
    var world := (load("res://example.tscn") as PackedScene).instantiate()
    root.add_child(world)
    world.set_physics_process(false)
    var actor := world.get_node("Player") as CharacterBody3D
    var views: Node = world.get_node("ViewManager")
    if not Validator.validate_moves(actor.get_node("Locomotion/MovementController"))["valid"]:
        _fail("movement configuration")
        return
    for tick in range(30):
        await physics_frame
    if not actor.is_on_floor():
        _fail("actor never reached the physical floor")
        return
    var start := actor.global_position
    var camera: Camera3D = views.call("get_active_camera")
    for index in range(5):
        if not views.call("switch_view", index) or views.call("get_active_camera") != camera:
            _fail("view switch replaced or lost camera")
            return
    actor.call("apply_move_intent", Intent.new(Vector2.RIGHT, Vector2.RIGHT))
    for tick in range(30):
        await physics_frame
    if actor.global_position.x <= start.x + 0.5 or not actor.is_on_floor():
        _fail("real actor failed to move on the authored floor")
        return
    world.free()
    print("ACTION5_BLANK_ADDON_OK")
    quit(0)


func _fail(reason: String) -> void:
    push_error("ACTION5_BLANK_ADDON_FAIL: " + reason)
    quit(1)
