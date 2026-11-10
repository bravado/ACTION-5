extends Node
class_name Action5AIController
## One camera-free intent producer for a regular Action5Actor. This FSM only
## decides whether to acquire, pursue, attack or wait; it does NOT duplicate
## the movement FSM, D05 attack timeline, Health or weapon reload clock.

const IntentScript = preload("res://addons/action5/actor/move_intent.gd")
const HealthScript = preload("res://addons/action5/combat/health.gd")
const SensorScript = preload("res://addons/action5/ai/target_sensor.gd")
const NavigationScript = preload("res://addons/action5/ai/navigation.gd")
const PolicyScript = preload("res://addons/action5/ai/attack_policy.gd")
const AimScript = preload("res://addons/action5/combat/actor_target_aim_provider.gd")

signal state_changed(previous: StringName, current: StringName)

@export var actor_path: NodePath = ^".."
@export var health_path: NodePath = ^"../Health"
@export var combat_path: NodePath = ^"../CombatController"
@export var equipment_path: NodePath = ^"../Equipment"
@export var target_sensor_path: NodePath = ^"../TargetSensor"
@export var navigation_path: NodePath = ^"../AINavigation"
@export var attack_policy_path: NodePath = ^"../AttackPolicy"
@export var aim_path: NodePath = ^"../AimTargetProvider"
@export var running: bool = true

@onready var actor: CharacterBody3D = get_node_or_null(actor_path) as CharacterBody3D
@onready var health: HealthScript = get_node_or_null(health_path) as HealthScript
@onready var combat: Node = get_node_or_null(combat_path)
@onready var equipment: Node = get_node_or_null(equipment_path)
@onready var sensor: SensorScript = get_node_or_null(target_sensor_path) as SensorScript
@onready var navigation: NavigationScript = get_node_or_null(navigation_path) as NavigationScript
@onready var policy: PolicyScript = get_node_or_null(attack_policy_path) as PolicyScript
@onready var aim: AimScript = get_node_or_null(aim_path) as AimScript

var state: StringName = &"idle"
var target: Node3D


func _ready() -> void:
    # Intent arrives before Locomotion's default priority-zero physics tick,
    # and before D05's -20 combat tick. No AI-specific movement executor.
    process_physics_priority = -40
    if actor == null or health == null or sensor == null or navigation == null \
            or policy == null or not actor.has_method("apply_move_intent"):
        push_error("ACTION5: AI requires actor, Health, sensor, navigation and policy")
        set_physics_process(false)
        return
    health.died.connect(_on_owner_died)


func set_target(candidate: Node3D) -> void:
    sensor.set_target(candidate)


func _physics_process(_delta: float) -> void:
    if health.current_health <= 0.0 or not bool(actor.get("alive")):
        _on_owner_died(null)
        return
    target = sensor.get_target(actor)
    if not is_instance_valid(target):
        _set_aim(null)
        navigation.reset()
        _send_intent(Vector2.ZERO, Vector2.ZERO)
        _set_state(&"idle")
        return
    _set_aim(target)
    var displacement: Vector3 = target.global_position - actor.global_position
    var toward := Vector2(displacement.x, displacement.z)
    var distance: float = toward.length()
    var heading: Vector2 = toward.normalized() if distance > 0.001 else Vector2.ZERO
    if health.stagger_left > 0:
        _send_intent(Vector2.ZERO, heading)
        _set_state(&"recover")
        return

    if policy.in_range(distance) and sensor.has_line_of_sight(actor, target):
        navigation.reset()
        _send_intent(Vector2.ZERO, heading)
        if is_instance_valid(combat) and combat.get("current_attack") != null:
            _set_state(&"recover")
        else:
            policy.request_action(combat, equipment, heading)
            _set_state(&"attack")
        return

    var direction: Vector2
    if distance < policy.minimum_range:
        # Ranged actors maintain a configurable personal space, still using
        # their ordinary move intent, never writing CharacterBody velocity.
        direction = -heading
    else:
        direction = navigation.direction_to(actor, target.global_position, 0.45)
    _send_intent(direction, heading)
    _set_state(&"pursue")


func _send_intent(move: Vector2, face: Vector2) -> void:
    if not is_instance_valid(actor):
        return
    var intent: IntentScript = IntentScript.new(move, face, face)
    intent.running = running
    actor.call("apply_move_intent", intent)


func _set_aim(next_target: Node3D) -> void:
    if is_instance_valid(aim):
        aim.set_target(next_target)


func _set_state(next_state: StringName) -> void:
    if state == next_state:
        return
    var previous: StringName = state
    state = next_state
    state_changed.emit(previous, state)


func _on_owner_died(_source: Node) -> void:
    target = null
    _set_aim(null)
    if is_instance_valid(sensor):
        sensor.clear_target()
    if is_instance_valid(navigation):
        navigation.reset()
    if is_instance_valid(actor):
        actor.call("apply_move_intent", IntentScript.new())
    _set_state(&"dead")


func _exit_tree() -> void:
    _set_aim(null)
    if is_instance_valid(health) and health.died.is_connected(_on_owner_died):
        health.died.disconnect(_on_owner_died)
