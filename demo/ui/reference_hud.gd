extends CanvasLayer
## D09 demo-only, read-only projection of the existing gameplay components.
## No ownership of attack/ammo clocks, equipment, health or camera mode.

@export var views_path: NodePath = ^"../ViewManager"
@export var health_path: NodePath = ^"../Player/Health"
@export var combat_path: NodePath = ^"../Player/CombatController"
@export var equipment_path: NodePath = ^"../Player/Equipment"
@export var moves_path: NodePath = ^"../Player/Locomotion/MovementController"
@export var session_path: NodePath = ^"../WorldSession"
@export var exit_path: NodePath = ^"../EncounterSector/ExitTerminal"

@onready var status: Label = $Status
@onready var help: Label = $Help
@onready var views: Node = get_node_or_null(views_path)
@onready var health: Node = get_node_or_null(health_path)
@onready var combat: Node = get_node_or_null(combat_path)
@onready var equipment: Node = get_node_or_null(equipment_path)
@onready var moves: Node = get_node_or_null(moves_path)
@onready var session: Node = get_node_or_null(session_path)

var _weapon: Node
var _exit: Node
var _reload_timer: Timer


func _ready() -> void:
    _reload_timer = Timer.new()
    _reload_timer.wait_time = 0.25
    add_child(_reload_timer)
    _reload_timer.timeout.connect(refresh)
    _connect(views, &"view_changed", _on_view_changed)
    _connect(health, &"health_changed", _on_health_changed)
    _connect(combat, &"attack_started", _on_attack_event)
    _connect(combat, &"attack_finished", _on_attack_event)
    _connect(combat, &"attack_cancelled", _on_attack_event)
    _connect(combat, &"attack_phase_changed", _on_phase_changed)
    _connect(combat, &"attack_registered", _on_attack_registered)
    _connect(combat, &"attack_unregistered", _on_attack_event)
    _connect(equipment, &"weapon_equipped", _on_equipment_event)
    _connect(equipment, &"weapon_unequipped", _on_equipment_event)
    _connect(equipment, &"weapon_dropped", _on_equipment_event)
    _connect(equipment, &"weapon_picked_up", _on_equipment_event)
    _connect(moves, &"move_changed", _on_move_changed)
    _connect(session, &"sector_changed", _on_sector_changed)
    Input.joy_connection_changed.connect(_on_joy_connection)
    _sync_weapon()
    _sync_exit()
    refresh()


func _connect(source: Node, event: StringName, callback: Callable) -> void:
    if is_instance_valid(source) and source.has_signal(event) and not source.is_connected(event, callback):
        source.connect(event, callback)


func _disconnect(source: Node, event: StringName, callback: Callable) -> void:
    if is_instance_valid(source) and source.has_signal(event) and source.is_connected(event, callback):
        source.disconnect(event, callback)


func _sync_weapon() -> void:
    var next_weapon: Node = equipment.get("current_weapon") as Node if is_instance_valid(equipment) else null
    if next_weapon == _weapon:
        return
    _disconnect(_weapon, &"fired", _on_fired)
    _disconnect(_weapon, &"reload_started", _on_reload_started)
    _disconnect(_weapon, &"reload_ended", _on_reload_ended)
    _weapon = next_weapon
    _connect(_weapon, &"fired", _on_fired)
    _connect(_weapon, &"reload_started", _on_reload_started)
    _connect(_weapon, &"reload_ended", _on_reload_ended)
    _update_reload_timer()


func _sync_exit() -> void:
    var next_exit: Node = get_node_or_null(exit_path)
    if _exit == next_exit:
        return
    _disconnect(_exit, &"objective_changed", _on_objective_changed)
    _exit = next_exit
    _connect(_exit, &"objective_changed", _on_objective_changed)


func _update_reload_timer() -> void:
    var reloading: bool = false
    if is_instance_valid(_weapon) and _weapon.has_method("get_ammo_status"):
        reloading = bool((_weapon.call("get_ammo_status") as Dictionary).get("reloading", false))
    if reloading:
        if _reload_timer.is_stopped():
            _reload_timer.start()
    else:
        _reload_timer.stop()


func refresh() -> void:
    if not is_instance_valid(views) or not is_instance_valid(combat) or not is_instance_valid(equipment):
        return
    _sync_weapon()
    _sync_exit()
    var profile: Resource = views.get("current_profile") as Resource
    if profile == null:
        return
    var hp: int = ceili(float(health.get("current_health"))) if is_instance_valid(health) else 0
    var attack: String = str(combat.get("current_id"))
    if attack.is_empty():
        attack = "none"
    var sector: String = str(session.get("current_sector")) if is_instance_valid(session) else "arena"
    var line: String = "VIEW %d / %d | %s | %s | Move %s | HP %d | Attack %s (%s) | %s" % [
        int(views.get("active_index")) + 1, (views.get("profiles") as Array).size(),
        str(profile.get("display_name")), sector, str(moves.get("active_id")) if is_instance_valid(moves) else "-",
        hp, attack, str(combat.get("phase")), weapon_summary(_weapon)
    ]
    if status.text != line:
        status.text = line
    var objective: String = "Find the east gate and enter the dungeon"
    if is_instance_valid(_exit):
        if bool(_exit.get("complete")):
            objective = "COMPLETE"
        elif bool(_exit.call("is_unlocked")):
            objective = "Reach the EXIT beacon in the dungeon"
        elif sector == "encounter":
            objective = "Defeat the dungeon enemies to unlock EXIT"
    var instructions: String = "ACTION-5 | " + objective
    var view_hints: Array[String] = []
    for i in range((views.get("profiles") as Array).size()):
        var item: Resource = (views.get("profiles") as Array)[i] as Resource
        view_hints.append("%s %s" % [_binding(StringName("view_" + str(i + 1))), str(item.get("display_name"))])
    instructions += "\nViews: " + "  ·  ".join(view_hints) + " | Controller: " + _binding(&"view_previous") + "/" + _binding(&"view_next")
    instructions += "\nMove: %s/%s/%s/%s | Jump: %s | Run: %s | E: %s | Q: %s | G: %s" % [
        _binding(&"move_up"), _binding(&"move_left"), _binding(&"move_down"), _binding(&"move_right"),
        _binding(&"actor_jump"), _binding(&"actor_run"), _binding(&"demo_interact"),
        _binding(&"demo_swap"), _binding(&"demo_drop")
    ]
    var actions: Array[String] = []
    if combat.has_method("get_attacks"):
        var seen: Dictionary = {}
        for definition in combat.call("get_attacks"):
            if not definition is Resource:
                continue
            var action: StringName = definition.get("input_action")
            if action == &"" or seen.has(action):
                continue
            seen[action] = true
            var selected: Resource = definition
            var selector: Node = equipment.get_node_or_null(^"../EquipmentAttackSelector")
            if is_instance_valid(selector) and selector.has_method("get_attack_for_input"):
                selected = selector.call("get_attack_for_input", action, definition) as Resource
            if selected != null:
                actions.append("%s [%s]" % [
                    str(selected.get("attack_id")).replace("_", " ").capitalize(), _binding(action)
                ])
    var commands: Array[String] = command_hints(_weapon)
    instructions += "\nActions: " + (" | ".join(actions) if not actions.is_empty() else "none")
    if not commands.is_empty():
        instructions += " | " + " | ".join(commands)
    if help.text != instructions:
        help.text = instructions
    _update_reload_timer()


## InputMap is authoritative. Optional command defaults are shown before
## their input adapter registers the action on the first physics frame.
func _binding(action: StringName, fallback_key: int = 0) -> String:
    var hints: Array[String] = []
    if InputMap.has_action(action):
        for event in InputMap.action_get_events(action):
            if event is InputEventKey or event is InputEventMouseButton:
                hints.append(event.as_text())
            elif event is InputEventJoypadButton:
                hints.append(event.as_text())
            if hints.size() >= 2:
                break
    if hints.is_empty() and fallback_key != 0:
        var key := InputEventKey.new()
        key.keycode = fallback_key
        hints.append(key.as_text())
    return "/".join(hints) if not hints.is_empty() else "unbound"


func weapon_summary(weapon: Node) -> String:
    if not is_instance_valid(weapon):
        return "Unarmed"
    var definition: Resource = weapon.get("definition") as Resource
    var name: String = str(definition.get("display_name")) if definition != null else weapon.name
    if weapon.has_method("get_ammo_status"):
        var ammo: Dictionary = weapon.call("get_ammo_status")
        name += " | Ammo %d/%d" % [int(ammo.get("magazine", 0)), int(ammo.get("reserve", 0))]
        if bool(ammo.get("reloading", false)):
            name += " | Reload %d ticks" % int(ammo.get("reload_left", 0))
    return name


func command_hints(weapon: Node) -> Array[String]:
    var result: Array[String] = []
    if not is_instance_valid(weapon) or not weapon.has_method("get_command_bindings"):
        return result
    for command in weapon.call("get_command_bindings"):
        if not command is Dictionary:
            continue
        var action: StringName = command.get("action", &"")
        if action != &"":
            result.append("%s [%s]" % [
                str(action).replace("_", " ").capitalize(),
                _binding(action, int(command.get("key", 0)))
            ])
    return result


func _on_view_changed(_current: Resource, _previous: Resource) -> void:
    refresh()


func _on_health_changed(_value: float, _previous: float) -> void:
    refresh()


func _on_attack_event(_id: StringName) -> void:
    refresh()


func _on_phase_changed(_id: StringName, _phase: StringName, _tick: int) -> void:
    refresh()


func _on_attack_registered(_definition: Resource) -> void:
    refresh()


func _on_equipment_event(_item: Node3D) -> void:
    _sync_weapon()
    refresh()


func _on_move_changed(_previous: StringName, _current: StringName) -> void:
    refresh()


func _on_sector_changed(_previous: StringName, _current: StringName) -> void:
    _sync_exit()
    refresh()


func _on_fired(_impact: Vector3, _hit: bool) -> void:
    refresh()


func _on_reload_started() -> void:
    refresh()


func _on_reload_ended(_completed: bool) -> void:
    refresh()


func _on_objective_changed() -> void:
    refresh()


func _on_joy_connection(_device: int, _connected: bool) -> void:
    refresh()


func _exit_tree() -> void:
    _disconnect(_weapon, &"fired", _on_fired)
    _disconnect(_weapon, &"reload_started", _on_reload_started)
    _disconnect(_weapon, &"reload_ended", _on_reload_ended)
    _disconnect(_exit, &"objective_changed", _on_objective_changed)
    if Input.joy_connection_changed.is_connected(_on_joy_connection):
        Input.joy_connection_changed.disconnect(_on_joy_connection)
