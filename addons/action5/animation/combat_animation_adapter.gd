extends Node
class_name Action5CombatAnimationAdapter
## Optional presentation adapter. The combat timeline, hits and health work
## without this node or an animation renderer. Only this class plays visuals.

const CombatScript = preload("res://addons/action5/combat/combat_controller.gd")
const HealthScript = preload("res://addons/action5/combat/health.gd")

@export var combat_path: NodePath = ^"../CombatController"
@export var health_path: NodePath = ^"../Health"
@export var animation_path: NodePath = ^"../AnimationPresenter"
@export var hit_animation_key: StringName = &"hit"
@export var death_animation_key: StringName = &"death"

@onready var combat: CombatScript = get_node_or_null(combat_path) as CombatScript
@onready var health: HealthScript = get_node_or_null(health_path) as HealthScript
## A replaceable generic visual port: no concrete animation class dependency.
@onready var animation_presenter: Node = get_node_or_null(animation_path)

var _active_channel: int = -1
var _reacting: bool = false
var _death_visual_active: bool = false


func _ready() -> void:
    process_physics_priority = 10
    if combat == null:
        push_warning("ACTION5: CombatAnimationAdapter needs a combat source")
        set_physics_process(false)
        return
    combat.attack_started.connect(_on_attack_started)
    combat.attack_finished.connect(_on_attack_ended)
    combat.attack_cancelled.connect(_on_attack_ended)
    if health != null:
        health.damaged.connect(_on_owner_damaged)
        health.died.connect(_on_owner_died)
    set_physics_process(health != null)
    # A new adapter may attach halfway through an existing attack or stagger.
    if health != null and health.current_health <= 0.0:
        _on_owner_died(null)
    elif health != null and health.stagger_left > 0:
        _on_owner_damaged(0.0, null)
    elif combat.current_attack != null:
        _on_attack_started(combat.current_id)


func _on_attack_started(id: StringName) -> void:
    if not is_instance_valid(combat):
        return
    # A revived actor can begin another action without rebuilding its
    # presenter. Never leave the previous death overlay above the game.
    if _death_visual_active:
        _clear_visual(&"clear_full_body_action")
        _death_visual_active = false
    var definition: Resource = combat.get_attack(id)
    if definition == null:
        return
    _clear_attack_visual()
    var key: StringName = definition.get("animation_key")
    if key == &"":
        return
    var channel: int = int(definition.get("animation_channel"))
    if _set_visual(channel, key):
        _active_channel = channel


func _on_attack_ended(_id: StringName) -> void:
    _clear_attack_visual()


func _clear_attack_visual() -> void:
    if _active_channel == 0:
        _clear_visual(&"clear_upper_body_action")
    elif _active_channel == 1:
        _clear_visual(&"clear_full_body_action")
    _active_channel = -1


func _set_visual(channel: int, key: StringName) -> bool:
    if key == &"" or not is_instance_valid(animation_presenter):
        return false
    var method: StringName = &"set_full_body_action" if channel == 1 else &"set_upper_body_action"
    if not animation_presenter.has_method(method):
        return false
    return bool(animation_presenter.call(method, key))


func _clear_visual(method: StringName) -> void:
    if is_instance_valid(animation_presenter) and animation_presenter.has_method(method):
        animation_presenter.call(method)


func _on_owner_damaged(_amount: float, _source: Node) -> void:
    if not is_instance_valid(health) or health.current_health <= 0.0:
        return
    if health.stagger_left > 0 and not _death_visual_active:
        _reacting = _set_visual(1, hit_animation_key)


func _on_owner_died(_source: Node) -> void:
    _clear_attack_visual()
    # A model without a configured death clip must not remain stuck in Hit.
    if _reacting:
        _clear_visual(&"clear_full_body_action")
    _reacting = false
    _death_visual_active = _set_visual(1, death_animation_key)


func _physics_process(_delta: float) -> void:
    if _reacting and (not is_instance_valid(health) or health.stagger_left <= 0):
        _reacting = false
        if not _death_visual_active:
            _clear_visual(&"clear_full_body_action")


func _exit_tree() -> void:
    if is_instance_valid(combat):
        if combat.attack_started.is_connected(_on_attack_started):
            combat.attack_started.disconnect(_on_attack_started)
        if combat.attack_finished.is_connected(_on_attack_ended):
            combat.attack_finished.disconnect(_on_attack_ended)
        if combat.attack_cancelled.is_connected(_on_attack_ended):
            combat.attack_cancelled.disconnect(_on_attack_ended)
    if is_instance_valid(health):
        if health.damaged.is_connected(_on_owner_damaged):
            health.damaged.disconnect(_on_owner_damaged)
        if health.died.is_connected(_on_owner_died):
            health.died.disconnect(_on_owner_died)
    _clear_attack_visual()
    if _reacting or _death_visual_active:
        _clear_visual(&"clear_full_body_action")
    _reacting = false
    _death_visual_active = false
