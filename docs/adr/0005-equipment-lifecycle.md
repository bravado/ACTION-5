# ADR-0005 — One weapon instance with independent equipment and presentation

Status: Proposed — D06-01 in progress.

## Context

D05 has a single authoritative attack clock, an independent Health
component, generic animation channels and an F4 visual-registration
interface. D06 requires Bat/Shovel, then Gun, without weapon-type cases
in shared actor, locomotion, camera or animation classes.

## Decision

- Each `Action5Weapon` remains the **same Node3D instance** on the floor,
  inside inventory, mounted to an animated socket and after dropping.
  Immutable `Action5WeaponDefinition` holds ID/socket, authored attacks,
  grip position and optional authored F4 scene; mutable state belongs to
  the instance (Gun's ammo/reload in D06-02).
- `Action5EquipmentController` owns slots, pickup radius, selection,
  mount lifecycle and attack registration only. It resolves a duck-typed
  `get_mount(socket_id)` provider; never loads a model or examines a
  Camera3D, view enum, render layer or weapon type.
- `Action5EquipmentVisualAdapter` optionally maps the mount port onto
  `AnimationPresenter.get_socket()`, registers/unregisters each world mesh
  through `FirstPersonPresenter` and adds one camera-local render-only
  viewmodel for the **local** player. NPCs can instead supply any mount
  provider, with no FPS or camera. F4 viewmodels never supply physical
  muzzle/impact transforms.
- D05 `CombatController` is extended once with generic
  `unregister_attack(id)`, paired with `register_attack()`. Unequipping
  cancels matching current/buffered actions, then unregisters the IDs.
  Weapons own their attack data and use `request_attack()`; no second
  action clock, damage resolver or action-name branch is created.
- The demo maps E pickup, Q swap and G drop through its local input
  adapter. LMB/RMB and J/K are unchanged InputMap actions, but an optional
  `EquipmentAttackSelector` resolves them to the equipped weapon's
  first/second action definition (one action serves both buttons).
  When unequipped, they resolve to unarmed Punch/Kick. No raw keyboard
  input belongs to a weapon or the reusable equipment controller.
- `FirstPersonCombatLimbs` uses a duck-typed visibility gate to hide
  unarmed F4 limbs while a weapon is held. The equipped F4 viewmodel
  provides its own arm and grip pose profile; the weapon meshes are
  parented to the same animated grip as the hand. All pose progress
  comes from `CombatVisualState`, not from another action timer.

## Consequences and D06-02 handoff

Adding a new melee weapon requires a scene, a definition and attack
resources. Neither the equipment controller nor the existing Bat/Shovel
implementations should change. Visual models may be multi-mesh; teardown
and NPC mounting must not create double shadows or lingering registrations.

D06-02 Gun uses this **same equipment lifecycle** with dedicated per-instance
ammo/reload and ranged-hit behavior. View-specific aim resolution returns a
world target; a ray from the **real world muzzle** to that target determines
obstruction, excluding the shooter. Do not reuse a camera ray as a physical
shot, reparent the authoritative weapon into camera space, or dispatch
`weapon_type == gun` in equipment or combat core. See PLAN.md D06 and
GitHub issues #13, #14 and #15.

## Evidence required before acceptance

Real Godot import and physics tests for Bat, Shovel and an independently
authored third instance; pickup/equip/swap/drop/reattach; registration and
cancellation; F3↔F4 continuity; multi-mesh local shadows and camera-only
viewmodel cleanup; NPC use without FPS; native/WebGL2 screenshots.
