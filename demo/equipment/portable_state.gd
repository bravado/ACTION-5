extends Node
## Optional per-weapon, data-configured state port for door transitions.
## Bat/Shovel have no mutable runtime attributes; only guns add this node.
## New weapons author their own fields or replace this adapter.

@export var fields: PackedStringArray = PackedStringArray([])


func capture_state() -> Dictionary:
    var result: Dictionary = {}
    var weapon: Node = get_parent()
    if not is_instance_valid(weapon):
        return result
    for field in fields:
        result[field] = weapon.get(field)
    return result


func restore_state(snapshot: Dictionary) -> void:
    var weapon: Node = get_parent()
    if not is_instance_valid(weapon):
        return
    for field in fields:
        if snapshot.has(field):
            weapon.set(field, snapshot[field])
