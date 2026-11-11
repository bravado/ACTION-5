# ADR-0004 — Camera-local viewmodel presentation, not world-bone projection

Status: Accepted — D05 first-person presentation architecture.

## Context

The F4 screenshot showed oversized cylindrical limbs that obscured the
viewport. Previous work made camera-local cylinders from world
Skeleton3D joint differences and multiplied them by arbitrary scales.
That mixes reference systems. Godot's get_bone_global_pose() is
skeleton-local, and glTF rest positions vary between rigs.

## Decision

Keep exactly **one gameplay actor and world animation rig**. Do not
couple Combat, Actor or CameraRig to FPS-specific poses. In F4,
render a dedicated camera-space visual component with authored pose
resources and optionally an artist's replacement viewmodel scene.
Advance those poses from a generic **read-only visual state adapter**
that expresses the existing gameplay action's normalized tick progress.

The shared FirstPersonPresenter still controls camera culling and
world-only shadow copies. The new viewmodel is layer 19, nonphysical,
and shadowless; world body is layer 20 and the world rig remains active.
F1/F2/F3/F5 continue to use the imported world model with no special
branches.

## Alternatives

- World mesh cropping/copying skeleton directly: rejected for near-eye
  presentation because rest-pose transforms and lens framing differ.
- Parallel first-person gameplay character or second authoritative
  AnimationTree: rejected; would duplicate animation ownership and
  diverge with view changes.
- Second camera plus transparent SubViewport: not now. Godot allows
  one active camera per Viewport; an additional compositor adds WebGL2
  cost and rendering complexity. Layer 19 is sufficient for current
  prototype; evaluate an isolated viewport only if independently tuned
  viewmodel FOV/near clipping becomes a real requirement.
- Full-body awareness via IK: separate future presentation plugin,
  not necessary for unarmed Punch/Kick in D05.

## Consequences

New attack: create the game attack resource, world clip mapping and
camera-local pose profile; **no changes to core movement, combat, input,
animation or camera classes**. A future authored viewmodel scene
replaces demo CapsuleMeshes through the same two-method interface.
D06 equipment can use the same registration and visual-state protocol
without weapon-ID dispatch in shared camera code.

Sources: Godot Skeleton3D and Retargeting guides, Camera3D/Viewports,
documented in [first-person-presentation.md](../first-person-presentation.md).
