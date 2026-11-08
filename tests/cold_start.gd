extends SceneTree
## Pre-import parser smoke: imported .glb scenes require Godot's first editor
## import, but addon scripts must parse without a generated class registry.

const ActorScript = preload("res://addons/action5/actor/action_actor.gd")
const ProfileScript = preload("res://addons/action5/animation/skeleton_profile.gd")
const ValidatorScript = preload("res://addons/action5/animation/model_validator.gd")
const AnimationPresenterScript = preload("res://addons/action5/animation/animation_presenter.gd")
const FirstPersonPresenterScript = preload("res://addons/action5/animation/first_person_presenter.gd")


func _initialize() -> void:
    var profile: ProfileScript = ProfileScript.new()
    if profile.clip_name(&"idle") != &"idle":
        push_error("ACTION5: Cold-start SkeletonProfile mapping failed")
        quit(1)
        return
    print("ACTION5_COLD_START_SCRIPTS_OK")
    quit(0)
