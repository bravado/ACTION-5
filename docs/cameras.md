# ACTION-5 — Camera system (D02)

D02 provides **six live camera/control profiles**, a single persistent `Camera3D`, input selection, smoothing/collision and a browser-friendly selector. All views share the same 3D world, player node, physical state and AI.

| Number | Profile resource | Rendering and camera | Temporary D02 movement |
|---|---|---|---|
| **1** | `side.tres` | Fixed side-on orthographic | X only (depth restricted in demo; full policy D03) |
| **2** | `beatemup.tres` | Elevated side-on orthographic | World X/Z |
| **3** | `isometric.tres` | Tilted orthographic | Screen-relative X/Z |
| **4** | `third_person.tres` | Following perspective, orbit + wall avoidance | Camera-relative X/Z |
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

- **F1:** camera follows the character while facing a fixed stage direction, orthographic. The demo's simple X-only restriction is intentionally upgraded in D03.
- **F3 vs F6:** F3 preserves tilted geometry; F6 is exactly vertical, and uses camera up/right ground-plane mapping rather than the projected camera-forward vector (which becomes zero at vertical pitch).
- **F4:** a raycast between focus and desired chase-camera position (against the configured collision mask) moves the camera in front of obstacles.
- **F5:** snaps to the actor eye position on entry and hides local third-person visuals; no camera reparenting.
- Fixed/angled cameras clamp the tracking target to configurable bounds; follow smoothing can be disabled (speed 0). Switching between orthographic and perspective changes projection immediately; transforms are smoothed except when head clipping or exact overhead alignment requires an immediate snap.

## Tests and evidence

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_all.gd
```

The tests cycle all six views **20 times**, check actor/camera identity and position/velocity invariants, validate F3/F6 projection differences, verify input bindings, test selector/cycling, and preserve the D01 tests.

GitHub Actions publishes `native-view-1.png` ... `native-view-6.png` and `web-view-1.png` ... `web-view-6.png`, in addition to initial scene screenshots. The browser automation presses keys 1–6 using Playwright and checks distinct rendered screenshots.

**Known limitation (D02):** this is camera mode switching with temporary reference movement, not full third-/first-person combat or fully generalized movement, which belong to later deliverables.
