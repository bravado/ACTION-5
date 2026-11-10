extends Node
class_name Action5GunReloadVisualAdapter
## Optional world animation listener. Ammo and action timing remain in Gun
## and D05; this can be removed for headless/NPC actors.

@export var equipment_path: NodePath = ^"../Equipment"
@export var animation_path: NodePath = ^"../AnimationPresenter"
@export var reload_clip: StringName = &"reload"

@onready var equipment: Node = get_node_or_null(equipment_path)
@onready var presenter: Node = get_node_or_null(animation_path)

var _source: Node
var _owns_reload_visual: bool = false


func _ready() -> void:
    if equipment == null:
        return
    equipment.weapon_equipped.connect(_on_equipped)
    equipment.weapon_unequipped.connect(_on_unequipped)
    if equipment.current_weapon != null:
        _on_equipped(equipment.current_weapon)


func _on_equipped(weapon: Node3D) -> void:
    _on_unequipped(_source)
    if weapon.has_signal("reload_started") and weapon.has_signal("reload_ended"):
        _source = weapon
        weapon.reload_started.connect(_on_reload_started)
        weapon.reload_ended.connect(_on_reload_ended)


func _on_unequipped(_weapon: Node3D) -> void:
    if is_instance_valid(_source):
        if _source.reload_started.is_connected(_on_reload_started):
            _source.reload_started.disconnect(_on_reload_started)
        if _source.reload_ended.is_connected(_on_reload_ended):
            _source.reload_ended.disconnect(_on_reload_ended)
    _source = null
    _on_reload_ended(false)


func _on_reload_started() -> void:
    if is_instance_valid(presenter) and presenter.has_method("set_upper_body_action"):
        _owns_reload_visual = bool(presenter.call("set_upper_body_action", reload_clip))


func _on_reload_ended(_completed: bool) -> void:
    if not _owns_reload_visual:
        return
    _owns_reload_visual = false
    if not is_instance_valid(presenter) or not presenter.has_method("clear_upper_body_action"):
        return
    # Never clear an upper-body clip belonging to another action adapter.
    var current_clip: Variant = presenter.get("upper_body_clip")
    if current_clip == null or current_clip == reload_clip:
        presenter.call("clear_upper_body_action")


func _exit_tree() -> void:
    _on_unequipped(_source)
    if is_instance_valid(equipment):
        if equipment.weapon_equipped.is_connected(_on_equipped):
            equipment.weapon_equipped.disconnect(_on_equipped)
        if equipment.weapon_unequipped.is_connected(_on_unequipped):
            equipment.weapon_unequipped.disconnect(_on_unequipped)
