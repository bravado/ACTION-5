# D04 — Skeletal model import, animation and view presentation

ACTION-5 keeps **one authoritative CharacterBody3D** and one 3D rig for all
five cameras. Animation is presentation-only: it consumes actor velocity and
visual action requests, never edits collisions, hit timing or world movement.

## Reference rig and licensing

The original MIT-licensed `demo/assets/action5_training_character.glb`
contains 15 skinned joints (including two articulated knees and two elbows), separately skinned upper arms, forearms, thighs and shins in body/head meshes, and `idle`, `walk`, `run`, `punch`, `kick`, `hit`, `death`, `reload`, `crouch`, `crouch_walk` and three dedicated weapon clips (`bat_vertical`, `bat_horizontal`, `shovel_overhead`). A gold training
prop is a demo-only MeshInstance3D child of the animated right-hand socket.
No third-party model, motion-capture animation or font is included. See
[asset inventory](assets/LICENSES.md).

To regenerate this exact original demo GLB from its checked-in source (no additional packages):

```bash
node tools/generate_training_character.mjs
git diff --exit-code -- demo/assets/action5_training_character.glb
```

CI runs this reproducibility check before import and also regenerates
`tests/fixtures/alternate_training_character.glb` using
`node tools/generate_alternate_training_character.mjs`. The second GLB
has different bone names (`Pelvis`, `Torso`, `Grip_R`, `Grip_L`, `ForearmJoint_R`, `ForearmJoint_L`, `Skull`, `KneeAlternate_L`, `KneeAlternate_R`) and differently named animation clips (`rest`, `stride`, `sprint`, `jab`, `boot`, `flinch`, `collapse`, `rearm`, `squat`, `squat_stride`, `club_chop`, `club_sweep`, `spade_chop`).

The model-replacement regression test **swaps the imported GLB scene**
under `Visual/Model` before initializing the AnimationPresenter and
configures only a duplicated `SkeletonProfile`. It validates that sockets
follow the replacement's bones, mapped animations play and bone-filtered
upper-body actions still work. This tests asset replacement rather than
merely assigning alternate names to the original model.

The authored model faces **world -Z** at rest, with Y upward, feet near
Y=0 and units in meters. The player remains responsible for collision and
movement. Skinned body visuals must not become colliders or drive gameplay.

## Replacing the GLB with a different humanoid

1. Import the appropriately licensed `.glb`/glTF file into Godot.
2. Instantiate that imported scene under the player `Visual` node,
   naming the instance `Model`. Avoid editing the imported asset directly;
   scene overrides belong in your wrapper player scene.
3. Duplicate `addons/action5/animation/default_skeleton_profile.tres` and
   assign it to `AnimationPresenter.profile`. `FirstPersonPresenter`
   automatically uses the AnimationPresenter's imported model; it does not
   have a separate model path, skeleton profile, or head-mesh setting.
4. Map source bone names for `right_hand_bone`, `left_hand_bone`,
   `head_bone` (for attachment sockets), and `upper_body_root_bone`
   (the first animated spine/torso bone; children form the upper-body overlay mask).
   Clips are mapped by `clip_map`: logical animation keys can resolve
   to any imported AnimationPlayer clip name without core code changes.
   The **shared default SkeletonProfile** only requires `idle`; `walk`
   and `run` are optional mappings with safe fallback. It intentionally
   has **no** `punch`, `kick`, `hit`, `death` or `reload` mappings
   or requirements. Add these or any `jump`, `fall`, `airborne`,
   `dodge`, `slide` or custom `Action5Move.move_id` to a specific
   actor's profile as needed. For example,
   `demo/assets/crouch_skeleton_profile.tres` explicitly maps
   `crouch`/`crouch_walk` and requires `idle`, `run`, `punch`,
   `kick`, `hit` and `death` to validate its complete authored demo
   rig. Other rigs are not required to provide combat clips.
5. Run `make import`, then `make test`. The pure
   `Action5ModelValidator.validate(model_root, profile)` returns
   `{"valid": bool, "errors": Array[String], "warnings": Array[String]}`.
   Missing clips listed in that **profile's** `required_clips` or a missing
   Skeleton3D/AnimationPlayer fail validation. Missing optional clips and
   socket bones produce warnings; socket fallbacks are stable static
   attachment anchors.

The model scene must contain at least one `Skeleton3D` and one
`AnimationPlayer`; the validator discovers them recursively. Body meshes
can use arbitrary names and do **not** require a separate or specially
named head mesh. In F4, the camera excludes every local body mesh instead
of relying on names, so a torso or arm cannot intersect the eye-level view.

## Fast articulated unarmed animations (D05)

The original procedural training rig now has **15 skinned joints**: right/left
elbows and knees use real child joints and independently weighted forearm and
shin geometry. The right-hand equipment socket remains `Hand_R`, including through Punch.
F4 draws a separate authored **camera-space visual rig** while preserving
the original world equipment socket and its animated shadow.

Both action clips contain **seven keyed poses**, with anticipation, impact,
retraction and neutral recovery (instead of simply swinging one rigid limb):

- **Punch (0.25 s):** the right elbow folds back to chamber the fist;
  the shoulder thrusts forward while the elbow extends, and the spine twists
  into the strike. The left forearm counterbalances; both hands return to rest.
- **Kick (0.333 s):** the right thigh raises the **knee forward first** while
  the shin folds back. The knee then straightens, driving the foot forward
  and upward. Ankle counterrotation levels the toe; support leg, torso and
  elbows balance the motion before retracting to idle.

The attack resources' startup/active/recovery total matches each clip's length
at **60 physics ticks/s** (Punch 3+3+9 = 15 ticks, Kick 4+3+13 = 20 ticks).
Damage timing still comes exclusively from combat, not from animation.
`tests/d05_animation_suite.gd` validates joint parenting, elbow anticipation,
knee-before-foot extension, movement geometry and duration alignment.
CI regenerates **both** original and replacement GLBs byte-for-byte.

## World-space weapon animations (D06)

The reference generator authors **three real skeletal clips**, one per
configured weapon action, using seven timed poses on shoulder, forearm,
spine and counterbalancing arm. `bat_vertical` lifts the weapon and chops
down, `bat_horizontal` winds up on the right and sweeps across the
torso, and `shovel_overhead` raises both arms before striking downward.
Each clip's duration matches `AttackDefinition.total_ticks()/60`.
World clips are generated deterministically into both GLB fixtures:
`tools/generate_training_character.mjs` and
`tools/generate_alternate_training_character.mjs`. The demo's
`crouch_skeleton_profile.tres` maps/requires the three new keys;
a different imported rig maps the same logical keys to its own clips.
D05 `CombatAnimationAdapter` continues to select the correct upper-body
channel without inspecting weapon IDs. The mounted world weapon follows
the imported skeleton's `Hand_R` attachment in F1/F2/F3/F5.

F4 remains camera-local for framing: it uses the same D05 visual-action
snapshot to select a dedicated `FirstPersonLimbProfile` for each attack
and never writes back to the world skeleton. This is presentation
decoupling, not a fallback to the unarmed Punch clip.

## First-person authored viewmodel animations

F4 intentionally uses **camera-local pose clips**, not direct world
Skeleton3D joint positions: those are skeleton-space (not camera-space)
and can have different rest poses after import or retargeting. A
`CombatVisualState` adapter exposes the authoritative action's normalized
physics-tick progress. An independent `FirstPersonCombatLimbs` component
selects its configured `Action5FirstPersonLimbProfile` resource and
samples its authored `Action5FirstPersonPoseKey` camera-space poses.
`Action5FirstPersonLimbGeometry` currently renders small, rounded
capsules; an author can replace it with a bespoke skinned
`viewmodel_scene` via the same configure/apply_pose interface.

The right arm rests visibly throughout F4 and plays a fast punched pose
from that rest; the knee/leg enters only for Kick and stays below the
crosshair. The original world skinned actor, imported animation tree,
socket tool, animated shadows and physics remain untouched. No second
authoritative gameplay skeleton or hitbox is created.

See [F4 architecture, tradeoffs and authoring contract](first-person-presentation.md).

## AnimationPresenter and action visuals

`Player/AnimationPresenter` owns a single `AnimationTree` whose
`AnimationNodeBlendTree` composes three *independent playbacks*, without
adding any gameplay FSM. Idle, Walk and Run looping is configured on
**per-presenter `AnimationNodeAnimation` timeline overrides**, never by
modifying an imported `Animation.loop_mode`. A regression test captures
the second imported rig's original `Animation` resources before the
presenter initializes and verifies their identity, lengths, track counts
and loop modes remain unchanged after all three channels play:

1. **Base locomotion** observes the active `Action5Move.move_id`, the
   body's grounded/airborne state and velocity. Registered moves select a
   clip via `SkeletonProfile.clip_map`; unknown or missing clips use
   Idle, and missing optional Walk uses Run.
2. **Upper-body actions** blend tracks for `upper_body_root_bone` and
   all of its child bones *over* the moving base. The exact bone track
   paths come from the imported AnimationPlayer. Hips and legs remain
   driven by locomotion; a missing root or unmatched tracks disables
   this channel safely. A new rig needs only a new profile, not core edits.
3. **Full-body overrides** replace the *visible* pose (including the
   upper overlay) while the underlying locomotion and upper-body playheads
   continue to advance. Clearing the override restores them.

A combat/ability component can use these **presentation-only** calls:

```gdscript
# Upper body: running + reloading (or jumping + firing).
animation_presenter.set_upper_body_action(&"reload")
# ... owning combat component decides when it finishes ...
animation_presenter.clear_upper_body_action()

# Full body: jump kick, roll, hit reaction.
animation_presenter.set_full_body_action(&"kick")
animation_presenter.clear_full_body_action()

# Existing D04 API remains an alias for full-body actions:
animation_presenter.set_action_visual(&"hit")
animation_presenter.clear_action_visual()
```

**Authoring new movements:** Start with
[the complete movement guide](adding-moves.md). A custom
`Action5Move.move_id` selects a logical key from the scene's
`SkeletonProfile.clip_map` without adding any animation-presenter
branches. The crouch example uses
`demo/assets/crouch_skeleton_profile.tres`. Its two looping
animations are authored in the GLB as `crouch-loop` and
`crouch_walk-loop`, and Godot imports them as `crouch`
and `crouch_walk` with `LOOP_LINEAR`. The presenter only
explicitly loops `idle`, `walk`, and `run` via local timeline
overrides: custom movement loops must be authored in the imported
clip. Articulated knees were added to the rig for crouching; test
the actual rendered side profile, not just bone rotations.

An action is **explicitly started and cleared** by its owning component;
animations never determine collision, attack frames, damage or movement
duration. Each channel accepts logical IDs mapped to imported clip names.
For a custom movement, register a new `Action5Move` and add its ID to
`clip_map`; the presenter reads it without adding a new `if` branch.
Upper-body actions and full-body overrides may coexist; full-body wins
visually and the other channels resume without losing their animation
state. The compatibility property `current_clip` reports the dominant
full-body/base animation, while `base_clip`, `upper_body_clip` and
`action_clip` expose each channel separately.

Switching cameras never recreates the actor or restarts any channel.
D05 `Action5CombatController` now owns authoritative startup, active and recovery ticks,
cancellation and hit resolution. See [combat authoring](combat.md).

`get_socket(&"right_hand")`, `get_socket(&"left_hand")` and
`get_socket(&"head")` return persistent Node3D anchors. Where a bone
exists, each is a `BoneAttachment3D` under the imported Skeleton3D,
so its children follow the actual animated hand or head. Without the
specified bone, a non-animated fallback Node3D is still returned and the
validator reports a warning. D06-01 attaches real Bat/Shovel weapons to
these anchors and keeps them installed across all five camera views.

## Local first person (view 4)

`FirstPersonPresenter` listens to the ViewManager `view_changed` signal.
It assigns **only the locally controlled actor's imported body meshes** to
render layer **20** (configurable through `local_body_render_layer`). The
shared Camera3D includes layer 20 for F1–F3/F5 but excludes it in F4.
This prevents the eye-level camera from seeing/intersecting its own cyan
torso, shoulders, arms or head, while keeping the original skinned meshes
visible to other observers with their normal camera masks.

`Visual`, `Skeleton3D`, animated bones and `BoneAttachment3D` sockets are
**never hidden, detached or recreated**. NPCs retain their default
rendering layers. Reserve layer 20 for the local actor's third-person body.

**Player shadow:** Godot camera culling may also remove a culled mesh
from the shadow pass. For the local body, the presenter creates a
`SHADOW_CASTING_SETTING_SHADOWS_ONLY` copy per imported skinned mesh on
ordinary world layer 1. Each copy shares the mesh, skin and skeleton path,
so the actual animated actor casts a world shadow in every view.

**Reusable local render policy:** The same `FirstPersonPresenter` owns
two distinct configurable camera layers (default: world-body 20 and
first-person-only 19) and handles F3/F4 culling on view changes.
`register_world_visual(mesh)` attaches the same shadow-only policy to
an already socket-mounted equipment renderer; it does nothing for NPCs
and is idempotent. `unregister_world_visual(mesh)` restores the source
rendering and releases its shadow, including when the mesh exits the tree.
`register_first_person_visual(visual)` accepts any authored Node3D
viewmodel scene, parents it to the camera and sets the view-only layer on
all its geometry. `unregister_first_person_visual(visual)` frees it.
When removed independently of the actor, the presenter disconnects its
view callback, restores each imported body mesh's original layers and shadow
mode (including custom settings), unregisters all world equipment visuals,
releases the shadow-only copies and FPS viewmodels, and restores the camera's
original culling bits. The actor and animated sockets remain alive.

The demo keeps its **world-space training tool** mounted on the skinned
hand socket for F1–F3/F5 and world shadows. It **does not instantiate the
old F4 fake hand/forearm/tool**. Instead, an independent camera-local
`FirstPersonCombatLimbs` component displays the articulated right arm
throughout F4 (including idle, running and jumping) and adds only the
configured right leg during Kick. Both follow the original animated
skeleton, without separate gameplay or duplicate animation tracks.
The arm anchor is calibrated to stay in the lower-right viewport at rest,
and the leg anchor keeps the bent knee below the center of the screen.
D06-01 supplies independently authored Bat/Shovel F4 gripping-arm
viewmodels and three unique world-space weapon animations, synchronized
with D05 action state instead of creating another gameplay clock.

Camera-layer culling does not need a head-specific profile property, mesh
naming convention or head-mesh validator warning. The `head_bone` profile
property remains for its independent animated attachment socket. Since
meshes remain globally visible, a second camera with the appropriate
culling mask can still render the complete world-body model.

## Validation

```bash
make import
make test
make build
```

The pre-import smoke tests GDScript without relying on Godot's generated
class cache. Imported `.glb` resources require `make import`; full game
launch, live skeletal animation and Linux/Web exports run **after** that
import. CI tests model validity, required clips, missing-bone fallback,
AnimationTree transitions, animated hand attachments and F3/F4 continuity.

**Not D04:** combat timelines/hitboxes (D05), real weapon state/aim (D06),
enemy AI (D07), advanced retargeting tools and photorealistic assets.


## D06-02 gun/reload/tracer presentation ownership

The physical Gun is attached to the existing world skeleton socket. Its
`WorldRecoil` is a non-authoritative mesh pivot, while the world
`Muzzle` marker is a sibling and therefore never moves with recoil.
The local-player F4 `Action5GunFirstPersonViewmodel` inherits the same
authored grip/arm geometry as Bat and Shovel and switches to an optional
reload profile by inspecting the equipped Gun's read-only visual state.
The separate `GunReloadVisualAdapter` listens to reload start/end and
clears its world upper-body overlay **only** if it successfully started
that clip and it is still active; it must not clear unrelated actions.
An optional world-owned emissive tracer listens to the Gun's already-
resolved `fired` event. None of these nodes changes the D05 action
clock or hit authority. A camera-free NPC can omit all of them. See
[ADR-0006](adr/0006-authoritative-gun-and-projectile-visuals.md).
