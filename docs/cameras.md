# ACTION-5 camera system (D02)

ACTION-5 provides **five interchangeable camera modes in one persistent 3D world**. The scene keeps the same actor, physics, enemies, equipment and level state during a switch. There is only one active `Camera3D`, and **isometric and third-person/over-the-shoulder are two zoom configurations of mode 3**, not two modes.

## Camera modes and default inputs

| Key | Profile resource | Camera framing | D02 demo movement |
|---|---|---|---|
| **1** | `side.tres` | Fixed horizontal, orthographic XY side view (Mario / Altered Beast). Looking along world −Z, no downward tilt | X only; Z lane policy formalized in D03 |
| **2** | `beatemup.tres` | Low, close orthographic arcade brawler (Streets of Rage / Golden Axe). Default ortho zoom 7 | World X/Z |
| **3** | `isometric.tres` | **One orthographic, adjustable isometric/shoulder profile.** Zoom out for inclined dungeon view; zoom in for camera close above the shoulder | Camera/screen-relative X/Z |
| **4** | `first_person.tres` | Eye-level perspective, yaw/pitch mouse look, local mesh hidden | Camera-relative X/Z |
| **5** | `retro_topdown.tres` | Precisely vertical orthographic overhead, distinct from inclined isometric (Zelda / Commando) | Screen-relative X/Z using camera up/right, never projected forward |

**Number row 1–5** is the primary shortcut on both desktop and Web. F1–F5 is an optional secondary binding, because browsers may reserve function keys. There are five visible in-game selector buttons and configurable gamepad shoulder-button cycling. `Ctrl+1–5` is *not* a supported browser fallback: browsers use Ctrl+number for tab navigation.

Use **WASD/arrows** for diagnostic movement. Click the game in mode 3 or 4 for mouse-look; press **Esc** or switch to a fixed camera to release the pointer. The reference movement adapter is intentionally temporary: the authoritative reusable locomotion and aiming policies are in D03.

## One isometric/shoulder profile

Mode 3 is `res://addons/action5/views/isometric.tres`. At the default `orthographic_size = 17`, the orbit camera is above/behind the actor with inclined isometric geometry. At `orthographic_size = 4`, it moves closer to the actor's right shoulder while keeping **orthographic** projection. Between these values, the camera rig interpolates wide and close orbit distances, yaw, pitch, shoulder offset, shoulder lift and aim look-ahead.

The close-up is *not* a sixth mode, a perspective-projection toggle or a second player actor. It remains the same `Action5ViewProfile` and `Camera3D`, and the `ViewManager` selection remains at index 2 (key 3).

The close-camera wall raycast prevents passing through world geometry. It excludes the followed actor from collision queries. The camera snaps when a wall blocks it rather than interpolating through the obstacle.

## Live settings (C)

Click **Camera Settings [C]**, or press **C**, to open the Godot UI panel. It changes the **selected view resource live** and never changes the actor transform or velocity. Use **Reset this camera** to restore the shipped defaults, or **Close** to hide it.

- **Mode 1 and 5:** orthographic zoom and follow speed.
- **Mode 2:** orthographic zoom, camera height, camera depth and follow speed.
- **Mode 3:** orthographic zoom, wide/close orbit distances, wide isometric pitch, close shoulder pitch, left/right shoulder offset, shoulder lift, look-ahead and follow speed.
- **Mode 4:** field of view, eye height and **Invert Y-axis (mouse)** (checkbox, **off by default**). With inversion off, mouse down looks down; enabling inversion makes mouse down look up.

The source component is `addons/action5/camera/camera_settings_panel.gd`. An app can call `set_current_value(key, value)`, `reset_current_camera()` or `refresh_controls()`; controls are generated from mode-applicable properties.

**Persistence:** The panel stores **only user overrides** in `user://action5_camera_settings.cfg`, using stable named sections (`profile_side`, `profile_beatemup`, `profile_isometric`, `profile_first_person`, `profile_retro_topdown`). Values that match defaults are not written so future default camera tuning is not frozen.

A one-time migration from the original *six-numbered-slot* configuration moves old third-person shoulder settings from former view 4 into the close settings of isometric view 3; old first-person view 5 and overhead view 6 settings move to the new modes 4 and 5. Existing wide isometric zoom is preserved. The settings UI can be instantiated in another project using the exported `manager_path` and can disable persistence using `save_user_settings = false`. The shipped `.tres` resource files are never overwritten at runtime.

## Integration

The addon components are scene-independent and live exclusively within `addons/action5/`:

- **`Action5ViewProfile`** — editable `Resource` defining a view.
- **`Action5ViewManager`** — tracks five profiles, active mode and changes, emits `view_changed(current, previous)`. Never owns or changes actor physics.
- **`Action5CameraRig`** — one persistent `Camera3D`, projection, follow smoothing, zoom, orbit, bounds, close-camera collision and the vertical-overhead up axis.
- **`Action5ViewInput`** — input actions `view_1` … `view_5`, optional function keys and gamepad cycle; respects user remapping rather than overwriting non-empty bindings.
- **`Action5CameraSettingsPanel`** — reusable controls, per-profile visibility and persistence.

To install the camera system in a Godot scene, create a `ViewManager` Node with `view_manager.gd`, containing a `CameraRig` Node3D with `camera_rig.gd` and a `Camera3D` child. Set `ViewManager.actor_path` to the existing player and use the built-in five `.tres` resources or assign a custom array of five `Action5ViewProfile` resources. Add a sibling `ViewInput` Node with `view_input.gd` and point its `manager_path` to the `ViewManager`. Add optional UI by connecting `view_changed` or by using the settings panel.

## Import-first development and test evidence

```bash
make import
make test
make run
# Optional native + browser exports:
make build
make serve-web
```

Every Make target that runs, tests or exports imports Godot resources first. `.godot/` contains generated class/resource registry state and is ignored by Git. The addon also explicitly preloads its script dependencies so a cold launch need not depend on an existing generated class registry.

D02 regression tests cover switching all **five** modes 20 times, preserving actor/camera identities and physics state, true side/overhead projections, wide-to-close isometric zoom within one resource, camera collision, editable settings, reset, saved overrides and legacy preference migration.

GitHub CI runs Godot 4.7.2 headless tests, a native Linux export, Web export with Chromium WebGL2 startup and number-key/selector smoke checks. Evidence artifacts include `native-view-1.png` through `native-view-5.png`, `native-isometric-shoulder.png`, `native-isometric-settings.png`, corresponding five Web views and camera UI evidence. See the current D02 pull request for its validated build and run artifacts.

**D02 boundary:** the actor remains a simple placeholder. Full jumping, reusable action intents, facing/aim policies, combat and animations are *not* delivered until D03–D07. D02 must pass review before D03 work starts.
