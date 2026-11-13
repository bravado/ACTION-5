extends CanvasLayer
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
## D09 demo-only, read-only projection of the existing gameplay components.
## No ownership of attack/ammo clocks, equipment, health or camera mode.

@export var views_path: NodePath = ^"../ViewManager"
@export var view_input_path: NodePath = ^"../ViewInput"
@export var health_path: NodePath = ^"../Player/Health"
@export var combat_path: NodePath = ^"../Player/CombatController"
@export var equipment_path: NodePath = ^"../Player/Equipment"
@export var moves_path: NodePath = ^"../Player/Locomotion/MovementController"
@export var session_path: NodePath = ^"../WorldSession"
@export var exit_path: NodePath = ^"../EncounterSector/ExitTerminal"
@export var actor_input_path: NodePath = ^"../ActorInput"
@export var direction_policy_path: NodePath = ^"../Player/EquippedViewFacing"
@export var interactor_path: NodePath = ^"../Interactor"
@export var player_path: NodePath = ^"../Player"

@onready var status: Label = $Status
@onready var help: Label = $Help
@onready var retro_direction: Label = get_node_or_null(^"RetroDirection") as Label
@onready var display: Control = $Reliquary
@onready var interactor: Node = get_node_or_null(interactor_path)
@onready var player: Node3D = get_node_or_null(player_path) as Node3D
@onready var views: Node = get_node_or_null(views_path)
@onready var view_input: Node = get_node_or_null(view_input_path)
@onready var health: Node = get_node_or_null(health_path)
@onready var combat: Node = get_node_or_null(combat_path)
@onready var equipment: Node = get_node_or_null(equipment_path)
@onready var moves: Node = get_node_or_null(moves_path)
@onready var session: Node = get_node_or_null(session_path)
@onready var actor_input: Node = get_node_or_null(actor_input_path)
@onready var direction_policy: Node = get_node_or_null(direction_policy_path)

var _weapon: Node
var _exit: Node
var _reload_timer: Timer
var _interaction_timer: Timer
var _hud_visible: bool = true
var _last_objective: String = ""
signal help_visibility_changed(open: bool)
signal view_requested(index: int)
signal settings_requested


func _ready() -> void:
    _register_hud_actions()
    _configure_view_choices()
    display.help_visibility_changed.connect(_on_help_visibility_changed)
    display.view_requested.connect(_on_view_requested)
    display.settings_requested.connect(_on_settings_requested)
    _interaction_timer = Timer.new()
    _interaction_timer.wait_time = 0.14
    _interaction_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
    add_child(_interaction_timer)
    _interaction_timer.timeout.connect(_refresh_interaction)
    _interaction_timer.start()
    _reload_timer = Timer.new()
    _reload_timer.wait_time = 0.25
    add_child(_reload_timer)
    _reload_timer.timeout.connect(refresh)
    _connect(views, &"view_changed", _on_view_changed)
    _connect(health, &"health_changed", _on_health_changed)
    _connect(health, &"damaged", _on_player_damaged)
    _connect(combat, &"attack_hit", _on_attack_hit)
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
    _connect(equipment, &"weapon_picked_up", _on_pickup_notice)
    _connect(equipment, &"weapon_dropped", _on_drop_notice)
    _connect(equipment, &"weapon_equipped", _on_equip_notice)
    _connect(moves, &"move_changed", _on_move_changed)
    _connect(session, &"sector_changed", _on_sector_changed)
    Input.joy_connection_changed.connect(_on_joy_connection)
    _sync_retro_direction()
    refresh()


func _connect(source: Variant, event: StringName, callback: Callable) -> void:
    if is_instance_valid(source) and source.has_signal(event) and not source.is_connected(event, callback):
        source.connect(event, callback)


func _disconnect(source: Variant, event: StringName, callback: Callable) -> void:
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
    display.set_objective(objective)
    if not _last_objective.is_empty() and _last_objective != objective:
        display.notify(objective)
    _last_objective = objective
    display.set_view("%d · %s" % [_shortcut_number(int(views.get("active_index"))),
        str(profile.get("display_name")).to_upper()])
    var instructions: String = "ACTION-5 | " + objective
    var view_hints := PackedStringArray()
    for slot in range((views.get("profiles") as Array).size()):
        var index: int = _profile_index_for_shortcut(slot)
        if index < 0:
            continue
        var item: Resource = (views.get("profiles") as Array)[index] as Resource
        view_hints.append("%s %s" % [
            _binding(StringName("view_" + str(slot + 1))),
            str(item.get("display_name"))
        ])
    instructions += "\nViews: " + "  ·  ".join(view_hints) + " | Controller: " + _binding(&"view_previous") + "/" + _binding(&"view_next")
    var controls: Resource = null
    if is_instance_valid(actor_input):
        controls = actor_input.call("get_active_controls") as Resource
    if controls != null:
        var horizontal: String = "%s/%s" % [
            _binding(controls.get("move_left_action")),
            _binding(controls.get("move_right_action"))
        ]
        if not str(controls.get("extra_left_action")).is_empty():
            horizontal += " or %s/%s" % [
                _binding(controls.get("extra_left_action")),
                _binding(controls.get("extra_right_action"))
            ]
        instructions += "\nMove left/right: %s" % horizontal
        if bool(controls.get("vertical_movement")):
            instructions += " | Forward/back: %s/%s" % [
                _binding(controls.get("move_up_action")),
                _binding(controls.get("move_down_action"))
            ]
        var jump_keys: String = _binding(controls.get("jump_action"))
        if not str(controls.get("extra_jump_action")).is_empty():
            jump_keys += " or " + _binding(controls.get("extra_jump_action"))
        instructions += " | Jump: %s" % jump_keys
        if not str(controls.get("held_move_action")).is_empty():
            instructions += " | Hold %s: %s" % [
                str(controls.get("held_move_id")).capitalize(),
                _binding(controls.get("held_move_action"))
            ]
        if not str(controls.get("extra_aim_left_action")).is_empty():
            instructions += " | Independent aim: %s/%s/%s/%s" % [
                _binding(controls.get("extra_aim_left_action")),
                _binding(controls.get("extra_aim_right_action")),
                _binding(controls.get("extra_aim_up_action")),
                _binding(controls.get("extra_aim_down_action"))
            ]
        if not str(controls.get("turn_left_action")).is_empty():
            instructions += " | Turn: %s/%s" % [
                _binding(controls.get("turn_left_action")),
                _binding(controls.get("turn_right_action"))
            ]
    instructions += " | Run: %s | Interact: %s | Swap: %s | Drop: %s" % [
        _binding(&"actor_run"), _binding(&"demo_interact"),
        _binding(&"demo_swap"), _binding(&"demo_drop")
    ]
    var actions := PackedStringArray()
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
    var commands: PackedStringArray = command_hints(_weapon)
    instructions += "\nActions: " + (" | ".join(actions) if not actions.is_empty() else "none")
    if not commands.is_empty():
        instructions += " | " + " | ".join(commands)
    if help.text != instructions:
        help.text = instructions
    display.set_help_text(instructions)
    var definition: Resource = _weapon.get("definition") as Resource if is_instance_valid(_weapon) else null
    var icon: Texture2D = definition.get("hud_icon") as Texture2D if definition != null else null
    var ammo: Dictionary = _weapon.call("get_ammo_status") if is_instance_valid(_weapon) \
        and _weapon.has_method("get_ammo_status") else {}
    var weapon_name: String = str(definition.get("display_name")) if definition != null else "Unarmed"
    var next_name: String = _next_weapon_name()
    # Short action names belong in the compact weapon panel. Detailed
    # keyboard/gamepad combinations live in F6 Help, not a clipped HUD line.
    var short_actions := PackedStringArray()
    for hint in actions:
        var text_hint: String = hint
        var bracket: int = text_hint.find(" [")
        short_actions.append((text_hint.substr(0, bracket) if bracket >= 0 else text_hint).to_upper())
    display.set_health(float(health.get("current_health")) if is_instance_valid(health) else 0.0,
        float(health.get("max_health")) if is_instance_valid(health) else 1.0)
    display.set_equipment(weapon_name, icon, ammo, next_name,
        _binding(&"demo_swap") if not next_name.is_empty() else "",
        " · ".join(short_actions))
    display.set_reticle(not ammo.is_empty()
        and int(profile.get("mode")) == ViewProfileScript.Mode.FIRST_PERSON)
    var activity: String = ""
    if attack != "none":
        activity = "ATTACK  ·  " + attack.replace("_", " ").to_upper()
    elif is_instance_valid(moves):
        var movement: String = str(moves.get("active_id"))
        if movement != "grounded" and not movement.is_empty():
            activity = movement.replace("_", " ").to_upper()
    display.set_player_state(activity)
    _update_reload_timer()


func _next_weapon_name() -> String:
    if not is_instance_valid(equipment):
        return ""
    var items: Array = equipment.get("inventory") as Array
    if items.is_empty():
        return ""
    var index: int = items.find(_weapon)
    if index >= 0 and items.size() < 2:
        return ""
    var next: Node = items[0] as Node if index < 0 else items[(index + 1) % items.size()] as Node
    if not is_instance_valid(next):
        return ""
    var definition: Resource = next.get("definition") as Resource
    return str(definition.get("display_name")) if definition != null else next.name


## The input adapter is the single source of shortcut-to-profile ordering.
## The HUD only formats the selected action and builds presentation buttons.
func _profile_index_for_shortcut(slot: int) -> int:
    if is_instance_valid(view_input) and view_input.has_method("profile_index_for_shortcut"):
        return int(view_input.call("profile_index_for_shortcut", slot))
    return slot


func _shortcut_number(index: int) -> int:
    if is_instance_valid(view_input) and view_input.has_method("shortcut_for_profile_index"):
        return int(view_input.call("shortcut_for_profile_index", index)) + 1
    return index + 1


func _configure_view_choices() -> void:
    if not is_instance_valid(views):
        return
    var choices: Array[Dictionary] = []
    var profiles: Array = views.get("profiles") as Array
    for slot in range(profiles.size()):
        var index: int = _profile_index_for_shortcut(slot)
        if index < 0 or index >= profiles.size():
            continue
        var profile: Resource = profiles[index] as Resource
        var short_name: String = str(profile.get("display_name")).get_slice(" / ", 0)
        if short_name.contains("-") and short_name != "Top-Down":
            short_name = short_name.get_slice("-", 0)
        short_name = short_name.get_slice(" ", 0).to_upper()
        choices.append({
            "index": index,
            "label": "%d · %s" % [slot + 1, short_name]
        })
    display.set_view_choices(choices)


func _register_hud_actions() -> void:
    for config in [{"name": &"hud_toggle", "key": KEY_H},
            {"name": &"hud_help", "key": KEY_F6}]:
        var action: StringName = config["name"]
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        if InputMap.action_get_events(action).is_empty():
            var event := InputEventKey.new()
            event.keycode = config["key"]
            InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_pressed() or (event is InputEventKey and event.echo):
        return
    if event.is_action_pressed(&"hud_toggle"):
        set_hud_visible(not _hud_visible)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"hud_help"):
        set_help_open(not display.is_help_open())
        get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.keycode == KEY_ESCAPE and display.is_help_open():
        set_help_open(false)
        get_viewport().set_input_as_handled()


func set_hud_visible(value: bool) -> void:
    _hud_visible = value
    display.set_gameplay_visible(value)
    _sync_retro_direction()
    if value:
        _refresh_interaction()


func is_hud_visible() -> bool:
    return _hud_visible


func set_help_open(value: bool) -> void:
    display.set_help_open(value)


func is_help_open() -> bool:
    return display.is_help_open()


func _on_help_visibility_changed(open: bool) -> void:
    help_visibility_changed.emit(open)


func _on_view_requested(index: int) -> void:
    view_requested.emit(index)


func _on_settings_requested() -> void:
    settings_requested.emit()


func _refresh_interaction() -> void:
    if not _hud_visible or not is_instance_valid(interactor) or not is_instance_valid(player) \
            or not interactor.has_method("get_target"):
        display.set_interaction("")
        return
    var target: Node3D = interactor.call("get_target", player) as Node3D
    if not is_instance_valid(target):
        display.set_interaction("")
        return
    var action: String = str(target.call("get_interaction_label", player)) \
        if target.has_method("get_interaction_label") else "Interact"
    display.set_interaction("%s · %s" % [_binding(&"demo_interact"), action])


func _item_name(weapon: Node3D) -> String:
    var definition: Resource = weapon.get("definition") as Resource if is_instance_valid(weapon) else null
    return str(definition.get("display_name")) if definition != null else "item"


func _on_pickup_notice(weapon: Node3D) -> void:
    display.notify("Picked up " + _item_name(weapon))


func _on_equip_notice(weapon: Node3D) -> void:
    display.notify("Equipped " + _item_name(weapon))


func _on_drop_notice(weapon: Node3D) -> void:
    display.notify("Dropped " + _item_name(weapon))


func _on_player_damaged(amount: float, _source: Node) -> void:
    display.notify("HIT · -%d HP" % ceili(amount))


func _on_attack_hit(_id: StringName, _target: Node) -> void:
    display.notify("HIT CONFIRMED")


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


func command_hints(weapon: Node) -> PackedStringArray:
    var result := PackedStringArray()
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
    _sync_retro_direction()
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
    refresh()


func _on_move_changed(_previous: StringName, _current: StringName) -> void:
    refresh()


func _on_sector_changed(_previous: StringName, _current: StringName) -> void:
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


## A read-only view-local compass. It never changes gameplay direction,
## timing, ammo, equipment or focus. Only enabled while overhead is active.
func _sync_retro_direction() -> void:
    if retro_direction == null:
        return
    var retro: bool = is_instance_valid(views) and views.get("current_profile") != null \
        and int(views.get("current_profile").get("mode")) == ViewProfileScript.Mode.RETRO_TOPDOWN
    # Existing text still serves tests; visual feedback lives in Reliquary.
    retro_direction.visible = false
    # The facing snapshot updates on the physics clock, not each render frame.
    # This bounds HUD allocation work on high-refresh native/WebGL2 displays.
    set_physics_process(retro and _hud_visible)


func _physics_process(_delta: float) -> void:
    if retro_direction == null or not is_instance_valid(actor_input):
        return
    var context: RefCounted = actor_input.call("get_action_input_context")
    if context == null:
        return
    var heading: Vector2 = context.get("facing_world")
    var sectors: int = 8
    if is_instance_valid(direction_policy):
        if direction_policy.has_method("get_sectors"):
            sectors = int(direction_policy.call("get_sectors", ViewProfileScript.Mode.RETRO_TOPDOWN, sectors))
    var current: Node = equipment.get("current_weapon") as Node if is_instance_valid(equipment) else null
    var definition: Resource = current.get("definition") as Resource if is_instance_valid(current) else null
    var weapon_name: String = str(definition.get("display_name")) if definition != null else "Unarmed"
    var facing_label: String = "%d-WAY" % sectors if sectors >= 2 else "FREE"
    var text_line: String = "TOP-DOWN | %s | %s | Heading %s | WASD move / Arrows or right stick aim" % [
        weapon_name, facing_label, _compass_heading(heading)
    ]
    if retro_direction.text != text_line:
        retro_direction.text = text_line
    if _hud_visible:
        display.set_view("%d · TOP-DOWN | %s %s" % [_shortcut_number(int(views.get("active_index"))),
            facing_label, _compass_heading(heading)
        ])


func _compass_heading(direction: Vector2) -> String:
    if direction.length_squared() < 0.001:
        return "-"
    var result: String = ""
    if direction.y < -0.38:
        result = "N"
    elif direction.y > 0.38:
        result = "S"
    if direction.x > 0.38:
        result += "E"
    elif direction.x < -0.38:
        result += "W"
    return result if not result.is_empty() else "-"


func _exit_tree() -> void:
    _disconnect(_weapon, &"fired", _on_fired)
    _disconnect(_weapon, &"reload_started", _on_reload_started)
    _disconnect(_weapon, &"reload_ended", _on_reload_ended)
    _disconnect(_exit, &"objective_changed", _on_objective_changed)
    if Input.joy_connection_changed.is_connected(_on_joy_connection):
        Input.joy_connection_changed.disconnect(_on_joy_connection)
