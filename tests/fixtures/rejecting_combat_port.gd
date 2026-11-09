extends Node
## D06 test-only combat port: reject exactly one definition while keeping
## a real registry, to prove that the equipment swap is atomic.
## The production controller still speaks only get/register/unregister.

var reject_id: StringName = &""
var registry: Dictionary = {}
var registration_attempts: Array[StringName] = []


func get_attack(id: StringName) -> Resource:
    return registry.get(id) as Resource


func register_attack(attack: Resource) -> bool:
    var id: StringName = attack.get("attack_id")
    registration_attempts.append(id)
    if id == reject_id or registry.has(id):
        return false
    registry[id] = attack
    return true


func unregister_attack(id: StringName) -> bool:
    if not registry.has(id):
        return false
    registry.erase(id)
    return true
