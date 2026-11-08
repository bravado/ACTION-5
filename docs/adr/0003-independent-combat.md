# ADR-0003 — Independent tick-based combat and external motion

Status: Proposed (D05 PR #28).

D03 locomotion remains the **sole** writer of CharacterBody3D.velocity.
D04 animation channels are visual state, not action clocks. D05 therefore
uses a separate actor-local CombatController with immutable attack
configuration resources and per-instance runtime state. Hit resolution is
a physics-tick Area3D shape query with Health-based deduplication. This is
smaller than a second actor FSM or a generalized action framework and
proves extensions with Punch/Kick/a third attack.

Damage, stun, health and death are independent of the rendered rig.
Health is a pure damage-state component; it does not inspect siblings or
invoke Actor or Locomotion methods. Nonlethal knockback emits
`knockback_requested` and lethal damage emits `died`. The optional
`HealthActorAdapter` subscribes to these events and forwards them to the
generic `apply_external_impulse` / `set_alive` interfaces. A static target
or an unrelated damageable object can omit this adapter entirely.
Detaching it disconnects its signal handlers.
The optional `CombatAnimationAdapter` listens to combat/health signals,
then starts or clears generic visual channels. No animation class, clip
name or view mode is imported by CombatController. A camera change, missing
adapter or replacement visual cannot alter the authoritative action clock.
Stagger visual expiry belongs to this adapter, not the combat timeline.
Only the reusable `Locomotion.apply_external_impulse()` port changes
shared physics: a decay-limited X/Z addition inside its existing solver.
That contract also supports environmental pushes and is projected away
from the locked side-view Z lane. No combat system directly sets velocity.

Input is bridged by a separate attack adapter with release-to-rearm after
UI/focus gating. The core input adapter publishes a typed read-only
`ActionInputContext` containing the current world aim, facing, mode,
camera and permission flag. CombatInputAdapter depends only on a replaceable
provider implementing `get_action_input_context()`, not on actor
internals or the concrete ActorInputAdapter/ViewManager classes. Missing
sources fail closed. Aim direction uses a separate component and preserves
full 3D camera rays for D06 while melee hitboxes remain world-local.
CombatController never reads a body-relative Visual/Facing node:
explicit world-X/Z aim determines heading, while an omitted direction
reuses its previous resolved heading (world north initially). This
remains valid on a bare CharacterBody3D without visual, locomotion or
camera nodes. All five cameras share the same attack state. D06 should
reuse this contract and avoid weapon-ID switches in core code.
