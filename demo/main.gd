extends Node3D

const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const InputAdapterScript = preload("res://addons/action5/input/actor_input_adapter.gd")
const MoveControllerScript = preload("res://addons/action5/actor/moves/movement_controller.gd")
const MovementPolicyScript = preload("res://addons/action5/actor/movement_policy.gd")
## D03 reference scene: movement and facing live in reusable addon components.

@onready var _player: CharacterBody3D = $Player
@onready var _views: ViewManagerScript = $ViewManager
@onready var _input: InputAdapterScript = $ActorInput
@onready var _moves: MoveControllerScript = $Player/Locomotion/MovementController
@onready var _combat: Node = $Player/CombatController
@onready var _health: Node = $Player/Health
@onready var _equipment: Node = $Player/Equipment

var _combat_was_active: bool = false
@onready var _status: Label = $Hud/Status
@onready var _help: Label = $Hud/Help
@onready var _mode_buttons: HBoxContainer = $Hud/ModeButtons
@onready var _camera_settings: PanelContainer = $Hud/CameraSettings
@onready var _settings_toggle: Button = $Hud/SettingsToggle

func _ready() -> void:
    _views.view_changed.connect(_on_view_changed)
    _moves.move_changed.connect(_on_move_changed)
    _combat.attack_started.connect(_on_attack_started)
    _combat.attack_hit.connect(_on_attack_hit)
    _health.health_changed.connect(_on_health_changed)
    _equipment.weapon_picked_up.connect(_on_weapon_picked_up)
    _equipment.weapon_equipped.connect(_on_weapon_equipped)
    _equipment.weapon_dropped.connect(_on_weapon_dropped)
    _settings_toggle.pressed.connect(_toggle_camera_settings)
    # Settings can also be closed by its own Close button, not only C.
    _camera_settings.visibility_changed.connect(_on_camera_settings_visibility_changed)
    _input.set_enabled(not _camera_settings.visible)
    for i in range(5):
        var button := _mode_buttons.get_node("Mode" + str(i + 1)) as Button
        button.pressed.connect(_on_mode_button_pressed.bind(i))
    _on_view_changed(_views.current_profile, null)


## Kept as a stable D02 smoke-test hook; production input mapping is in addon.
func _map_demo_movement(axes: Vector2) -> Vector2:
    return MovementPolicyScript.to_world(
        axes, _views.current_profile.mode, _views.get_active_camera().global_basis
    )


func _on_mode_button_pressed(index: int) -> void:
    _views.switch_view(index)
    # Re-clicking an already selected view does not emit view_changed.
    _release_ui_focus()


func _toggle_camera_settings() -> void:
    _camera_settings.visible = not _camera_settings.visible
    if _camera_settings.visible:
        _camera_settings.call("refresh_controls")
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _release_ui_focus()


func _on_camera_settings_visibility_changed() -> void:
    # This also handles the Close button inside the settings panel.
    _release_ui_focus()
    # Only the panel's UI gate is owned here; the adapter owns window focus.
    _input.set_enabled(not _camera_settings.visible)
    print("ACTION5_CAMERA_SETTINGS_VISIBLE ", "open" if _camera_settings.visible else "closed")


func _release_ui_focus() -> void:
    # Buttons must not intercept Space (actor_jump) after a mouse click or
    # when changing the view with number keys. Sliders remain keyboard-usable
    # while the settings panel is open, until a view switch/close.
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused != null:
        focused.release_focus()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_C:
            _toggle_camera_settings()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_B and not _camera_settings.visible:
            _combat.set("debug_hitboxes", not bool(_combat.get("debug_hitboxes")))
            get_viewport().set_input_as_handled()
        elif not _camera_settings.visible:
            var consumed: bool = false
            match event.keycode:
                KEY_E:
                    consumed = _pickup_closest_weapon()
                KEY_Q:
                    consumed = bool(_equipment.call("swap_next"))
                KEY_G:
                    consumed = bool(_equipment.call("drop_current"))
            if consumed:
                get_viewport().set_input_as_handled()


func _pickup_closest_weapon() -> bool:
    var closest: Node3D
    var best: float = float(_equipment.get("pickup_radius"))
    for candidate in get_tree().get_nodes_in_group("action5_weapon_pickup"):
        var weapon := candidate as Node3D
        if weapon == null or bool(weapon.get("is_equipped")):
            continue
        # Stowed items are still scene nodes, but no longer world pickups.
        if weapon.get("equipment_owner") != null:
            continue
        if (_equipment.get("inventory") as Array).has(weapon):
            continue
        var distance: float = weapon.global_position.distance_to(_player.global_position)
        if distance <= best:
            closest = weapon
            best = distance
    return closest != null and bool(_equipment.call("pickup", closest))


## Diagnostic display and CI log are generic: no checks for specific moves.
func _on_attack_started(id: StringName) -> void:
    print("ACTION5_ATTACK_STARTED id=", id)


func _on_attack_hit(id: StringName, target: Node) -> void:
    print("ACTION5_ATTACK_HIT id=", id, " target=", target.name)


## D06 demo-only diagnostics: browser CI sends real keys, not script hooks.
func _on_weapon_picked_up(weapon: Node3D) -> void:
    var definition: Resource = weapon.get("definition")
    print("ACTION5_WEAPON_PICKUP id=", definition.get("weapon_id"))


func _on_weapon_equipped(weapon: Node3D) -> void:
    var definition: Resource = weapon.get("definition")
    var adapter: Node = _player.get_node("EquipmentVisualAdapter")
    var f4_visual: Node3D = adapter.get("_viewmodel") as Node3D
    print("ACTION5_WEAPON_EQUIPPED id=", definition.get("weapon_id"),
        " meshes=", weapon.call("get_world_meshes").size(),
        " f4_visual=", int(f4_visual != null))
    if _views.current_profile != null:
        _refresh_status(_views.current_profile)


func _on_weapon_dropped(weapon: Node3D) -> void:
    var definition: Resource = weapon.get("definition")
    var adapter: Node = _player.get_node("EquipmentVisualAdapter")
    print("ACTION5_WEAPON_DROPPED id=", definition.get("weapon_id"),
        " f4_visual=", int(adapter.get("_viewmodel") != null))
    if _views.current_profile != null:
        _refresh_status(_views.current_profile)


## Avoid laying out the HUD 60 times/sec while idle: software WebGL2
## rendering is CPU-bound and should not slow actual physics/movement.
func _physics_process(_delta: float) -> void:
    var active: bool = _combat.get("current_attack") != null
    if (active or _combat_was_active) and _views.current_profile != null:
        _refresh_status(_views.current_profile)
    _combat_was_active = active


func _on_health_changed(_value: float, _previous: float) -> void:
    if _views.current_profile != null:
        _refresh_status(_views.current_profile)


func _on_move_changed(previous: StringName, current: StringName) -> void:
    print("ACTION5_MOVE_CHANGED previous=%s current=%s" % [previous, current])
    if _views.current_profile != null:
        _refresh_status(_views.current_profile)


func _refresh_status(profile: ViewProfileScript) -> void:
    var health: Node = _player.get_node_or_null("Health")
    var hp: int = ceili(float(health.get("current_health"))) if health != null else 0
    var action_label: String = str(_combat.get("current_id"))
    if action_label.is_empty():
        action_label = "none"
    var next_text: String = "VIEW %d / 5 | %s | Move %s | HP %d | Attack %s %s [%d] | Switches %d" % [
        _views.active_index + 1, profile.display_name, _moves.active_id, hp,
        action_label, _combat.get("phase"), _combat.get("elapsed_ticks"), _views.switch_count
    ]
    var held: Node3D = _equipment.get("current_weapon") as Node3D
    if held != null:
        var item_definition: Resource = held.get("definition")
        next_text += " | Weapon " + str(item_definition.get("display_name"))
    if _status.text != next_text:
        _status.text = next_text


func _on_view_changed(current: ViewProfileScript, _previous: ViewProfileScript) -> void:
    if current == null:
        return
    # Remove stale GUI focus left by view buttons or camera sliders.
    _release_ui_focus()
    _refresh_status(current)
    # Demo instrumentation (not gameplay): browser CI verifies the imported
    # rig and attachment survive local F3/F4 rendering policy changes.
    var fps: Node = _player.get_node_or_null("FirstPersonPresenter")
    var anim: Node = _player.get_node_or_null("AnimationPresenter")
    if fps != null and anim != null:
        var body_meshes: Array = fps.get("body_meshes")
        var body_layer: int = int(fps.get("local_body_render_layer"))
        var camera_culls_body: bool = not _views.get_active_camera().get_cull_mask_value(body_layer)
        var body_on_layer: bool = not body_meshes.is_empty()
        for mesh in body_meshes:
            body_on_layer = (
                body_on_layer and mesh.visible
                and mesh.layers == (1 << (body_layer - 1))
            )
        var body_hidden: bool = body_on_layer and camera_culls_body
        var socket: Node3D = anim.call("get_socket", &"right_hand") as Node3D
        var attached: bool = socket != null and socket.get_node_or_null("TrainingTool") != null
        var camera: Camera3D = _views.get_active_camera()
        var combat_limb: Node = _player.get_node_or_null("FirstPersonCombatLimbs")
        var resting_arm: Node3D = (
            combat_limb.call("get_limb_root", &"punch") as Node3D
            if combat_limb != null else null
        )
        var arm_in_view: bool = (
            resting_arm != null and resting_arm.visible
            and camera.get_cull_mask_value(int(fps.get("first_person_render_layer")))
        )
        print("ACTION5_D04_PRESENTATION view=%d body_hidden=%d rig=%d tool=%d actor_z=%.2f viewmodel=%d" % [
            _views.active_index + 1,
            int(body_hidden),
            int(anim.get("skeleton") != null),
            int(attached),
            _player.global_position.z,
            int(arm_in_view),
        ])
    for i in range(5):
        var button := _mode_buttons.get_node("Mode" + str(i + 1)) as Button
        button.disabled = i == _views.active_index
    _help.text = "ACTION-5 // D06 EQUIPMENT DEMO\n1–5: views | WASD: move | Space: jump | Shift: run | LMB/J: punch | RMB/K: kick\nE: pickup | Q: swap | G: drop | LMB/RMB/J/K: equipped weapon"
    var front_wall_mesh := get_node("SouthWall/MeshInstance3D") as MeshInstance3D
    front_wall_mesh.visible = (
        current.mode != ViewProfileScript.Mode.SIDE
        and current.mode != ViewProfileScript.Mode.BEATEMUP
    )
    if not current.is_orbit_mode():
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
