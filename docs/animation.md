# D04 — Skeletal model import, animation and view presentation

ACTION-5 keeps **one authoritative CharacterBody3D** and one 3D rig for all
five cameras. Animation is presentation-only: it consumes actor velocity and
visual action requests, never edits collisions, hit timing or world movement.

## Reference rig and licensing

The original MIT-licensed `demo/assets/action5_training_character.glb`
contains 11 bones, separate skinned body/head meshes, and `idle`, `walk`,
`run`, `punch`, `kick`, `hit`, `death`, `reload` clips. A gold training
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
has different bone names (`Pelvis`, `Torso`, `Grip_R`, `Grip_L`,
`Skull`) and differently named animation clips (`rest`, `stride`,
`sprint`, `jab`, `boot`, `flinch`, `collapse`, `rearm`).

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
   Clips are mapped by `clip_map`:
   logical `idle` / `run` / `punch` etc. can resolve to any imported
   AnimationPlayer animation name, without core code changes. Map at
   least `idle`, `run`, `punch`, `kick`, `hit`, `death`.
   `walk` and `reload` are optional. You may also add entries to
   `clip_map` for `jump`, `fall`, `airborne`, `dodge`, `slide`
   or any custom `Action5Move.move_id`; the demo rig intentionally
   omits these clips and uses safe visual fallbacks instead.
5. Run `make import`, then `make test`. The pure
   `Action5ModelValidator.validate(model_root, profile)` returns
   `{"valid": bool, "errors": Array[String], "warnings": Array[String]}`.
   Missing required clips or Skeleton3D/AnimationPlayer fail validation;
   missing socket bones produce warnings and stable static fallback anchors.

The model scene must contain at least one `Skeleton3D` and one
`AnimationPlayer`; the validator discovers them recursively. Body meshes
can use arbitrary names and do **not** require a separate or specially
named head mesh. In F4, the camera excludes every local body mesh instead
of relying on names, so a torso or arm cannot intersect the eye-level view.

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
D05 combat still owns authoritative startup, active and recovery ticks,
cancellation and hit resolution.

`get_socket(&"right_hand")`, `get_socket(&"left_hand")` and
`get_socket(&"head")` return persistent Node3D anchors. Where a bone
exists, each is a `BoneAttachment3D` under the imported Skeleton3D,
so its children follow the actual animated hand or head. Without the
specified bone, a non-animated fallback Node3D is still returned and the
validator reports a warning. D06 should attach real weapons to these
anchors and keep them installed across camera switches.

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

The demo's placeholder world training tool and camera-local tool/hand/forearm
are now declarative scenes under `demo/assets/`. `demo/player.gd` only
instantiates the two scenes and registers them; it never assigns a render
layer, duplicates a shadow caster, switches a camera, or inspects a view
profile. The camera-local tool is intentionally an unshaded placeholder:
matching production-quality first-person equipment and gameplay actions
belong to D06.

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
