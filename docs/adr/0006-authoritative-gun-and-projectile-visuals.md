# ADR-0006 — Authoritative world shots, replaceable aim and render-only projectiles

Status: Accepted for D06-02 PR #32 implementation, pending owner visual sign-off and merge.

## Decision

D06 extends the approved D05/D06-01 contracts rather than starting a separate
shooter subsystem.

1. **D05 attack timing is authoritative.** A Gun is an ordinary Action5Weapon
   with its own immutable AttackDefinition (non-melee active phase). Its
   instance owns magazine, reserve, reload ticks, muzzle and configured attack
   ID. No ammo or reload state lives in global equipment, an animation, or a
   camera viewmodel. The one D05 active-phase transition invokes the hitscan.
2. **Aim and hit authority are distinct.** The injected actor-local provider
   implements `get_world_target(origin: Vector3, maximum_range: float,
   exclude: Array[RID]) -> Vector3`. The local-player implementation
   translates ActionInputContext/F4 camera/F5 independent aim into a world
   point. A second concrete `Action5ActorTargetAimProvider` accepts an
   NPC-selected Node3D target and works without local input, ViewManager,
   Camera3D, or an F4 presenter. Either way, Gun fires from its actual world
   Muzzle, testing geometry and hurtboxes, excluding its owner. The camera
   ray can never bypass a wall.
3. **Ammo has a single source of truth.** A valid active shot costs one round,
   even if physically blocked. No ammo is spent for cancelled startup,
   invalid aim, empty magazine or reload. A separate optional, duck-typed
   WeaponCommandInputAdapter forwards configured reload commands. Reload
   counts down independently of presentation and is cancelled on unequip;
   view changes do not restart it.
4. **Effects consume events, not hit authority.** The existing
   `Gun.fired(impact, did_damage)` event is emitted only after damage and
   ammo have been determined. An optional GunProjectilePresenter samples
   the physical world Muzzle and the resolved impact, then instantiates
   a configurable ProjectileVisual in the **world scene**. It has no collider
   and no access to Health/CombatController. The effect outlives weapon or
   actor destruction and disposes itself after its short visual travel.
   Muzzle origin is sampled synchronously with `fired`. If a future network
   replay requires immutable asynchronous shot data, extend the event with
   a shot payload in that feature—not preemptively.
5. **Presentation is optional and owns only its own state.** World recoil,
   gun reload animation, F4 gripped pose and projectile are independent
   adapters. The F4 model is never a second gameplay gun. ReloadVisual
   clears its upper-body overlay only if it successfully started that clip
   and that same clip remains active. Optional adapters are absent for
   camera-free NPCs.

## Rejected alternatives

- A physical collider on the *visual* tracer or damage on its arrival:
  duplicates hit authority, changes D05 timing and breaks near-wall tests.
- Hits from the camera ray or F4 model: can shoot through walls/heads and
  conflicts with F1/F2/F3/F5.
- Extending Actor, CombatInputAdapter, AnimationPresenter, MovementController
  or EquipmentController with `is_gun`, `reload`, `npc` or view-mode checks:
  defeats independent component installation.
- A global bullet manager, attack factory, networking layer or additional
  animation clock: no demonstrated need; two authored guns and two aim
  providers already exercise the existing small contracts.

## Extension guide

Another gun needs a scene, AttackDefinition, physical Muzzle Marker3D,
optional independent projectile/viewmodel resources, and configured
per-instance ammo/reload fields. An NPC uses the same Gun scene with
`aim_provider_path` selecting its actor-local target provider; its AI
decision component alone chooses target, navigation and D05 attack requests.
Never import `demo/` from reusable `addons/action5/` scripts.

## Handoff to future issues

- **D07 (#15):** AI FSM + navigation are separate intent/action producers.
  Reuse the camera-free target provider, existing D05 Combat and actor-local
  Equipment. Test two enemies, target death/loss, team filtering, blocked
  muzzle, simultaneous attack requests and view switching with no camera
  references in NPCs.
- **D08 (#16):** world doors/props and collision layers must block the
  *world muzzle* ray whether or not the local camera hides a roof. A simple
  separate `interact(actor)` consumer should replace demo-only pickup keys;
  do not extend core equipment with door IDs.
- **D09 (#17–18):** HUD reads existing weapon/attack/command state; F5
  4-/8-way policy belongs in an injected view aim/selection policy. Keep
  AttackDefinition.facing_sectors at Free when only F5 is quantized, because
  the current CombatController also applies that field in F1–F4.
- **D10 (#19):** opt-in validators can check Muzzle path, available world
  aim provider, collision masks, loaded attack IDs, optional F4 scene and
  projectile scene. No mandatory editor dependency or special Gun parser.
- **D11 (#20):** extend the same Godot/native/browser regression matrix.
  Prove physically blocked and unblocked shots, no double damage, dry fire,
  reload/camera transitions, NPC firing without a camera, projectile
  survival after gun removal and bounded cleanup; check different render
  rates without changing 60-Hz combat ticks.
- **D12 (#21):** `addons/action5/` stays independent of `demo/`;
  example scenes/resources and tests can reference the demo, runtime
  scripts cannot. Include a clean-project smoke test with an NPC weapon,
  no camera and optional render effect.

## Acceptance

The extension is covered by the existing pinned Godot `make check` suite,
native screenshot harness, and real WebGL2 browser smoke. D06-02's
camera-free NPC, world-lived tracer, and reload-clip ownership regressions
passed **958 assertions, 0 failures** in GitHub CI checks (2026-11-09
local / 2026-11-10 UTC); [PR #32](https://github.com/bravado/ACTION-5/pull/32).
A final **latest-head** Full E2E check and manual five-view visual approval
remain the merge acceptance gates; do not conflate smoke captures with art
review.


## Amendment: first-person projectile appearance

F4 intentionally renders a camera-local weapon rather than moving the
physical world Gun to the player's eyes. A purely visual tracer cannot
unconditionally start from the physical muzzle or it may appear to leave
the body behind the viewport. An optional actor-local, duck-typed
visual-origin provider resolves the active F4 `Grip/VisualMuzzle` marker;
exterior views and camera-free AI fall back to the world Muzzle.
The *actual hitscan ray* is still fired by the Gun from the physical
Muzzle and still blocks against world collision and applies damage at
the original impact. The visual effect uses only a different origin,
not a different target/damage/range/physics query. The second Gun
configures its own visual marker. No weapon-ID branches or second
weapon actor were introduced.


## Amendment: adjustable tracer gradient

Only the temporary world-owned `Action5ProjectileVisual` material
controls the brightness and opacity gradient. Its shader derives the
tail-to-tip fraction from the canonical 1-unit CylinderMesh local Y
axis: muzzle-side -Y is brighter/more opaque, impact-side +Y fades.
Opacity and emission also decay over the effect lifetime. Gun ammo,
raycasts, hit point and independent F4 visual-origin policy are
unchanged. Both pistol variants reuse this component with their own
color/size parameters; no new gameplay or camera coupling.


## Amendment: physical body/Hurtbox collision precedence

A ray that collides with layers 1 and 2 may return a target actor's
solid `PhysicsBody3D` before its overlapping Hurtbox Area. The first
collision is still **authoritative for obstruction**: a wall must never
be skipped in pursuit of a downstream Hurtbox. If that first collider
is a physical body, it counts as a damage receiver only when it owns
an enabled `Action5Hurtbox` resolving to its own `Action5Health`.
The existing damage/team/invulnerability filtering follows unchanged.
The real-body regression lives in `tests/d06_gun_suite.gd`; no AI,
camera, movement, animation or equipment core changes are required.
