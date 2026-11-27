extends SceneTree
## Run inside a project containing only addon/ and this bootstrap script.
const Validator = preload("res://addons/action5/debug/config_validator.gd")
const View = preload("res://addons/action5/camera/view_profile.gd")
const Attack = preload("res://addons/action5/combat/attack_definition.gd")


func _initialize() -> void:
    var profile: Resource = View.new()
    var attack: Resource = Attack.new()
    attack.attack_id = &"blank_test"
    if not Validator.validate_view(profile)["valid"] or not Validator.validate_attack(attack)["valid"]:
        push_error("ACTION5_BLANK_ADDON_FAIL")
        quit(1)
        return
    print("ACTION5_BLANK_ADDON_OK")
    quit(0)
