extends Node
## Mock generic animation API: no combat or core animation imports.
var upper_body_clip: StringName = &""
var full_body_clip: StringName = &""
var events: Array[String] = []


func set_upper_body_action(key: StringName) -> bool:
    upper_body_clip = key
    events.append("upper:" + str(key))
    return true


func clear_upper_body_action() -> void:
    upper_body_clip = &""
    events.append("upper:clear")


func set_full_body_action(key: StringName) -> bool:
    full_body_clip = key
    events.append("full:" + str(key))
    return true


func clear_full_body_action() -> void:
    full_body_clip = &""
    events.append("full:clear")
