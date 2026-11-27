# D10 — Debugging and validation

All developer tooling is **opt-in** in `addons/action5/debug/`. The release runtime
does not load it through Actor, MovementController, AnimationPresenter,
CombatController, Equipment or Gun. It never references `demo/`.

## F7 diagnostic HUD

In the reference demo **F7** creates/shows/hides the debug HUD in debug
builds. The panel reads FPS and physics tick, view, active movement/velocity
and combat action/phase/tick. In another game, construct it explicitly:

```gdscript
const DebugHud = preload("res://addons/action5/debug/debug_hud.gd")

var hud := DebugHud.new()
add_child(hud)
hud.bind_sources($Player, $ViewManager)
hud.set_section_enabled(&"combat", false)
hud.set_enabled(true)
```

You can pass a third AI controller source to `bind_sources`. Each category
(movement/combat/AI) can be disabled independently. Hidden overlays have
processing disabled, and release builds discard the HUD immediately.
The demo's B key still toggles the existing melee hitbox debug rendering,
but only in debug builds. The separate F8 geometry overlay is described below.

## Read-only authoring checks

```gdscript
const Validator = preload("res://addons/action5/debug/config_validator.gd")
var report: Dictionary = Validator.validate_moves($Player/Locomotion/MovementController)
if not report["valid"]:
    for error in report["errors"]:
        push_warning(error)
```

Each validator returns `valid`, `errors`, and `warnings`. It never changes
resources or actor state.

| Method | Supported checks |
|---|---|
| `validate_view(profile)` | Projection, bounds, pitch, camera mask |
| `validate_attack(attack, profile=null, player=null)` | Attack ID, animation channel, optional world clip mapping |
| `validate_weapon(definition, world=null, skeleton=null, profile=null, player=null)` | Attack IDs, duplicate inputs, world meshes, configured socket and optional F4 model |
| `validate_gun(gun, aim_provider)` | World Muzzle marker, aim provider interface, ray layers, fire attack and melee query |
| `validate_moves(controller)` | Generic registered child move IDs/input claims and fallback moves |
| `validate_receiver(body)` | Physical layer 1 body, active layer 2 Hurtbox and actor-owned Health |
| `validate_model(model, profile)` | Imported Skeleton3D, AnimationPlayer, bones and clip map |

Pass the actual imported `Skeleton3D`, `AnimationPlayer`, and
`SkeletonProfile` to opt into strict socket/clip checks. A missing F4
viewmodel is intentionally supported and is not a warning. New custom
moves, attacks and weapons are evaluated using the same methods without
per-name conditions or core changes.

The supported model contract is **one compatible Skeleton3D and one
AnimationPlayer per imported actor**. Multi-rig retargeting is not provided.

## Clean addon installation

1. Create an empty **Godot 4.7.2** GDScript project using Compatibility.
2. Copy just `addons/action5/` to your new project's `addons/action5/`.
3. Optionally enable **Project Settings → Plugins → ACTION-5**. The runtime
   does not require the editor plugin to be enabled.
4. Create a CharacterBody3D with CollisionShape3D, Action5Actor script,
   Locomotion and MovementController/Moves with Grounded/Airborne children.
   Compose the single Camera3D/ViewManager using the provided view profiles;
   see [moves](adding-moves.md) and [cameras](cameras.md) for authoring.
5. Call the optional validators against your authored resources and nodes.
6. In this repository, `make blank-addon` copies only the addon to an
   isolated temporary project and performs import/script smoke. It must
   succeed without `demo/`, the real project `tests/`, or a plugin UI.

This check establishes dependency isolation, **not** a complete playable
blank-project walkthrough. The latter still requires manual verification.
Level authoring remains independent; see [LEVEL-01](https://github.com/bravado/ACTION-5/issues/42).

## Level diagnostics

Call `Validator.validate_level(level_root, true, true, [^"Arrival"])` explicitly to inspect an authored level for static collision, navigation, configured marker paths and visibility target ownership. Pass false for collision/navigation on decorative scenes and omit marker paths when not needed. A missing baked navigation mesh is a warning because the reference arena creates its navigation at runtime. The check is read-only and performs no per-frame work. It does not validate arbitrary sector traversal (LEVEL-02).

## World geometry diagnostics

F8 toggles the optional geometry overlay independently from F7 and B. Bind an actor, view manager, optional equipment and aim port using `bind_sources`. The categories `hurtboxes`, `aim` and `bounds` may be independently toggled with `set_section_enabled`. Green outlines show the conservative hurtbox motion bounds, orange the selected target direction from the world muzzle (not an authoritative damage prediction), yellow the muzzle marker and cyan the active camera target bounds. The overlay draws world-space lines with depth testing and does not create collisions or modify gameplay. It samples at 10 Hz while enabled and clears all geometry and disables physics processing when hidden. The test logs elapsed time and zero-sample counts over 60 physics ticks; this is callback-work evidence, not a GPU frame-time benchmark.

Additional checks: `validate_limb_profile` checks the existing first-person pose contract, `validate_direction_source` checks explicitly configured direction policy ports, and `validate_weapon` checks duplicate/invalid view-facing policies.
