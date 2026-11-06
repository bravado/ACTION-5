# ACTION-5 — Camera system (D02)

D02 provides **six live camera/control profiles**, a single persistent `Camera3D`, input selection, smoothing/collision and a browser-friendly selector. All views share the same 3D world, player node, physical state and AI.

| Number | Profile resource | Rendering and camera | Temporary D02 movement |
|---|---|---|---|
| **1** | `side.tres` | True horizontal XY side-scroller (Mario/Altered Beast), looking along world -Z, zero pitch | X only (depth restricted in demo; full policy D03) |
| **2** | `beatemup.tres` | Close, shallow-angle orthographic arcade brawler (Streets of Rage / Golden Axe); foreground wall visual hidden | World X/Z |
| **3** | `isometric.tres` | Tilted orthographic | Screen-relative X/Z |
| **4** | `third_person.tres` | Close, above-right-shoulder perspective, forward look-ahead, orbit + wall avoidance | Camera-relative X/Z |
| **5** | `first_person.tres` | Eye-level perspective and mouse look | Camera-relative X/Z |
| **6** | `retro_topdown.tres` | Vertical overhead orthographic, separate bounds/zoom | Screen-relative X/Z |

**Number-row 1–6 is the primary camera shortcut everywhere, including browsers.** F1–F6 are optional secondary bindings (F5 often refreshes a browser tab). The scene also provides six on-screen buttons and gamepad shoulder buttons for previous/next view.

## Architecture

- `Action5ViewProfile` (Resource): camera mode, projection, follow/zoom/bounds, orbit and collision configuration.
- `Action5ViewManager` (Node): owns the active profile index, emits `view_changed(profile, previous)`, tracks switches and asserts world-state preservation. It never reparents or recreates an actor.
- `Action5CameraRig` (Node3D): owns exactly **one** `Camera3D` and applies the selected Resource; orthographic/perspective projection, smoothed follow, target bounds, third-person wall raycast, first-person eye camera.
- `Action5ViewInput` (Node): registers action bindings *only if the project did not register them already*, translates 1–6/F1–F6 and gamepad shoulder actions to view changes, handles optional captured mouse orbit and focus loss.
- The `demo/` scene listens to the signal for HUD/buttons and uses a lightweight movement adapter. Reusable locomotion, jump and full direction/aim policies are **D03**, intentionally not mixed into the camera library.

The reusable core lives under `addons/action5/camera/` and `addons/action5/views/`; it depends only on Godot, never on `demo/`.

## Integrating in your Godot scene

1. Add a `ViewManager` Node with `res://addons/action5/camera/view_manager.gd`.
2. Add a `CameraRig` Node3D child with `camera_rig.gd`, and exactly one `Camera3D` child under it.
3. Add a `ViewInput` Node with `view_input.gd` and point its `manager_path` at your `ViewManager`.
4. Set `ViewManager.actor_path` to your 3D player; the default is `../Player`. Set `initial_view_index` from 0–5.
5. On startup, when no profile array is assigned, the manager loads the six built-in editable `.tres` files. For a custom game, assign an array of six `Action5ViewProfile` resources in the Inspector.
6. Optionally connect the `view_changed` signal to HUD updates; call `switch_view(index)` or `cycle_view(direction)` from UI.

The first-person camera hides a `Visual` node on the **local actor only**; it does not change collision/hitboxes. Dedicated first-person arms/animations are a later D04 feature. If your character's visual node is named differently, adapt the presentation subscriber.

### Input remapping

Actions `view_1` ... `view_6`, `view_previous` and `view_next` are created at runtime only when absent; existing action event bindings are respected. Default number row and function-key events are appended only to empty actions. To remap, define or customize those actions in Godot Project Settings > Input Map before the `ViewInput` node starts, or change the `InputMap` at runtime in your own settings UI.

Clicks on the view buttons do not activate attacks; scene UI events are handled before `_unhandled_input`. Esc releases captured mouse, and non-orbit modes and focus loss always release capture.

## Camera rules

- **F1:** true horizontal Mario/Altered Beast camera: screen axes are strictly +X and +Y, camera looks along -Z with an identity basis regardless of follow interpolation. The demo hides the SouthWall **mesh** when F1 is selected (collision is unchanged), since an arena's foreground wall would otherwise block the side view. F2 restores the wall. The demo's X-only movement restriction is generalized in D03.
- **F3 vs F6:** F3 preserves tilted geometry; F6 is exactly vertical, and uses camera up/right ground-plane mapping rather than the projected camera-forward vector (which becomes zero at vertical pitch).
- **F2:** the default orthographic size is 7.0 instead of 16, with lower elevation and a tighter stage follow. The near SouthWall **mesh** is hidden for F1/F2, while its collider is preserved and visibility is restored for F3–F6.
- **F4:** default right-shoulder offset (0.75 m), lift (0.65 m), short follow distance (2.9 m), and look-ahead (2.5 m) aim into the arena. Offset rotates with camera yaw and the camera's collision ray still blocks passing through walls. It is a camera-only change, not an actor position change.
- **F5:** snaps to the actor eye position on entry and hides local third-person visuals; no camera reparenting.
- Fixed/angled cameras clamp the tracking target to configurable bounds; follow smoothing can be disabled (speed 0). Switching between orthographic and perspective changes projection immediately; transforms are smoothed except when head clipping or exact overhead alignment requires an immediate snap.

## Customize cameras while playing

Click **Camera Settings [C]** at the right end of the view selector, or press **C**. The panel edits the **currently selected** camera in real time without recreating or repositioning the actor. Use **Reset this camera** to restore the built-in default for the selected mode and **Close** or **C** to hide the panel.

The reusable `Action5CameraSettingsPanel` component lives at `addons/action5/camera/camera_settings_panel.gd` and can be attached to any Godot `PanelContainer` with `manager_path` pointing to a `ViewManager`. It generates sliders from the profile's applicable settings:

- **F2 — Beat'em up:** zoom (`orthographic_size`), camera elevation, camera depth and follow speed.
- **F4 — Third person:** follow distance, elevation/pitch, right/left shoulder offset, shoulder height, look-ahead distance, field of view and follow speed.
- **F1/F3/F6:** orthographic zoom and follow speed.
- **F5:** field of view and eye height.

Settings apply as you move sliders; other camera profiles remain unchanged. Only settings changed from their built-in defaults are saved (so untouched defaults can improve in future releases). Changes are saved to `user://action5_camera_settings.cfg` using Godot's `ConfigFile` and loaded on the next game launch. Each view has a separate section. The shipped `.tres` profiles are never rewritten by runtime UI changes, and the project ignores generated per-user files.

For programmatic UI, use `set_current_value(key, value)`, `reset_current_camera()` and `refresh_controls()`. You can disable persistence via `save_user_settings=false` or change `preferences_path` for another game. The camera rig's `refresh_settings()` updates the camera without resetting mouse yaw or player position.

## Fresh clones and Godot's script registry

The reusable components retain `class_name` declarations for convenient use in the Godot editor, but consumers **explicitly preload dependent scripts by path**. This prevents a direct game launch on a freshly cloned project from failing with cascading `Could not find type "Action5ViewProfile"` / `Action5ViewManager` errors before Godot has generated `.godot/global_script_class_cache.cfg`.

```bash
# Directly run the game on a fresh checkout:
godot --path .

# Editor or asset-import workflow (also valid):
godot --headless --path . --import
godot --editor --path .
```

The CI workflow runs a **cold-start smoke before any import/editor scan**, then runs the full import and test/export matrix. Avoid using the generated `.godot/` directory as a committed dependency.

## Tests and evidence

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_all.gd
```

The tests cycle all six views **20 times**, check actor/camera identity and position/velocity invariants, validate F3/F6 projection differences, verify input bindings, test selector/cycling, and preserve the D01 tests.

GitHub Actions publishes `native-view-1.png` ... `native-view-6.png` and `web-view-1.png` ... `web-view-6.png`, in addition to initial scene screenshots. The browser automation presses keys 1–6 using Playwright and checks distinct rendered screenshots.

**Known limitation (D02):** this is camera mode switching with temporary reference movement, not full third-/first-person combat or fully generalized movement, which belong to later deliverables.
