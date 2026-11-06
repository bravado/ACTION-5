# ADR-0002 — Actor movement, facing and input intents

**Status:** D03 movement-component extension, pending technical gate
**Date:** 2026-11-06

## Context

A single physical 3D actor must support five input/camera modes with no actor recreation, duplicated world state, teleportation on view changes or raw-key dependencies in the actor's physics. The side-scroller requires current-Z lane retention; the vertical overhead camera requires world ground-plane projection that does not degenerate.

## Decision

- **Authoritative actor:** `Action5Actor : CharacterBody3D` is the only physical owner of position, velocity, collisions, alive/disabled state and local visual orientation.
- **Command boundary:** `Action5MoveIntent : RefCounted` carries a planar **world X/Z** move vector, separate facing/aim vectors, jump edge, run state, dodge edge and selected camera mode. It has no input or camera dependencies.
- **Input:** `Action5ActorInputAdapter : Node` reads the Godot `InputMap` at physics ticks, manages gamepad/keyboard deadzones, focus and controller disconnect; it never updates the actor's transform. User remapping is respected.
- **Projection:** `Action5MovementPolicy` is a stateless mapping for view modes 1–5. It uses camera up/right for top-down mode, screen relative movement for isometric, yaw for first-person and world-space X/Z for brawler.
- **Movement:** `Action5Locomotion : Node` remains the only 3D physics solver. It applies `move_and_slide`, floors, acceleration, gravity/jump and step/slope rules. The body remains a single `CharacterBody3D` in every view.
- **Extensible move FSM:** `Action5MovementController` automatically discovers child `Action5Move` components, owns the single active move, enforces priority and `can_exit`, emits transitions and selects grounded/airborne fallback after completion. Built-in Dodge and Slide are ordinary installed moves. A custom move must not require editing actor, input adapter or solver branches.
- **Context / command boundary:** `Action5MoveContext` exposes the current body state and movement intent. Components emit one-tick requests such as `request_horizontal_velocity()` and `finish_move()`; **only the solver** applies velocity and physical collision. No move may call `move_and_slide` or rewrite actor transform.
- **Input extensibility:** A move declares its `action_name`, optional keyboard/gamepad defaults and a stable `move_id`. The InputMap adapter iterates the registered moves instead of testing concrete move flags. Existing user remappings remain authoritative.
- **Independent controllers:** future combat and action capabilities will use their own coordination mechanism rather than multiplying locomotion states into combinations such as RunningAndShooting.
- **Side lane:** entering F1 records the *current* world Z, without moving the actor. Only movement applied on following physics ticks is constrained; leaving F1 removes the lock without snapping to a different Z lane.
- **Facing:** `Action5FacingPresenter : Node3D` controls only visual yaw, interpolated separately from physics. Four/eight-way quantization and independent aim never quantize translational velocity.
- **World:** demo input and HUD are consumers of these modules; addon scripts never reference `demo/`.

## Consequences

No D03 gameplay subsystem needs to poll raw keys from an Actor, weapon or combat node. Jump gravity remains in the same world, including side view. The 60 Hz physics tick is not a guarantee of network determinism.

This D03 implementation uses built-in Godot slope and floor snapping. More advanced step climbing/navmesh/ledge logic remains out of scope until a game requires it. D04 can drive AnimationTree from locomotion/facing without moving the character's skeleton to decide physics.
