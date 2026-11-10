# ADR-0006 — Authoritative world shots, replaceable aim and render-only projectiles

Status: Accepted and verified for D06-02 PR #32 (owner visuals passed 2026-11-10; squash merge pending).

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

## Acceptance (2026-11-10)

[Latest-head CI #42809417312](https://github.com/bravado/ACTION-5/actions/runs/42809417312)
passed **974/974 pinned Godot assertions** and the native/WebGL2
Full E2E pipeline. Coverage includes real body-first
`CharacterBody3D` → owned Hurtbox resolution, walls, team and disabled
Hurtbox, one-shot ammo/timing, camera-free NPC, independent reload
visual ownership, F4 muzzle alignment, and the world-owned tracer
with gradient/lifetime cleanup. The **owner confirmed F1–F5 visual
testing passed on 2026-11-10**. No unresolved P1/P2 architectural
finding was found in this final review. PR #32 remains open for
explicit squash merge; close issue #14 afterwards.

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


## Final architecture / simplification review (2026-11-10)

Review scope: Gun, both aim providers, optional weapon-command adapter,
world recoil/reload view adapters, F4 gun model, physical body/Hurtbox
mapping, world-owned projectile/trail, second configured gun, physical
integration suite, native/WebGL2 tests and handoff to D07–D12.

**Keep:** D05's single attack clock; D06-01 inventory/registration;
per-instance Gun ammo/reload state; actor-local duck-typed aim port;
physical muzzle with first-collider obstruction; explicit owned
Hurtbox/Health damage receiver; optional F4 visual origin and
world-owned tracer. Two guns and two concrete aim providers prove these
boundaries without new core branches. Only the tiny render-only
EquipmentVisualAdapter hook extends an existing shared addon class.

**Considered, not adopted:**
- A generic `ProjectileManager` or physical bullet framework: would
  add a second damage authority and lifetime/clock management to a
  hitscan-only milestone. Current projectiles are independently
  self-expiring visuals.
- A shared `AmmoService`/reload FSM: there is no cross-gun shared ammo
  requirement. The Gun's existing per-instance countdown is simpler.
- A global hit-registry/collider cache: body-first lookup occurs only
  when a physical body is the first actual ray collider. Retain the
  direct Hurtbox/Health association rather than new registration or
  invalidation lifecycles. Profile against many D07 actors before
  optimizing this path.
- Gun IDs, `is_ranged` flags or camera/NPC conditions in core actor,
  CombatController, MovementController, AnimationPresenter or Equipment:
  unnecessary; the existing aim and optional visual/command ports
  select behavior by configuration.
- Consolidating D06-02's distinct visuals into the gameplay Gun class:
  couples rendering and F4-specific pose to hit authority and prevents
  headless NPC reuse.
- Abstracting the 974-assertion physical fixtures into a new test
  framework: the existing runner, scenarios and exported browser
  smoke provide the needed evidence. Extract helpers only when D07's
  *second* enemy scenario demonstrates repeated fixture setup.

**D07 boundary:** add one small target/decision/navigation intent
producer per NPC, not a new combat/gun framework; the shipped
`Action5ActorTargetAimProvider` already supplies world points. D07
should test target death/loss, two simultaneous enemies, body-first
hit receivers, wall collision and camera switching. A missing target
must fail closed without reusing the player's camera. Other milestones
retain their distinct D08 world interactions, D09 view policy/HUD,
D10 diagnostics, D11 full test matrix and D12 clean addon packaging.

**Outcome:** no further code refactor is justified as a D06-02 merge
prerequisite. Optional D07 profiling and test-fixture consolidation
remain explicitly non-blocking.
