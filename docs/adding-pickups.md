# Add a weapon pickup in the Godot editor

This guide describes the **current ACTION-5 demo weapon-pickup contract**.
You can reuse an existing weapon scene or author a new one without editing
`Action5EquipmentController`, `Action5Interactor`, `WorldSession`,
input handling or the camera code. These are **weapon** pickups: collectible
health, keys or other inventory items would need their own interaction and
ownership policies, not a weapon-shaped workaround.

## Quick path: place another copy of an existing weapon

1. Open `demo/main.tscn` in the Godot editor. Drag an existing reusable
   scene, e.g. `demo/equipment/bat.tscn`, into the **Scene** tree as a child
   of the arena root. This must be a **scene instance**, not a new empty
   `Node3D` or a copy of only its meshes.
2. Give the scene instance a distinct stable name such as
   `SecondBatPickup`, and position it on reachable ground. This instance
   already contains its world meshes, weapon definition, pickup group and
   `PickupInteraction` child.
3. For **arena pickups that must respawn when the arena uses Start fresh**,
   select the existing `PickupSpawns` node in `demo/main.tscn`.
   In the Inspector, append `../SecondBatPickup` to **Pickup Paths**
   (an `Array[NodePath]`, resolved relative to `PickupSpawns`).
   Do not create a `SecondBatPickupWorldState` node.
4. Run the game and approach the weapon. **E** should pick it up, **Q**
   should change weapons when you carry more than one, and **G** should
   drop the selected instance back into the world. The default player
   equipment capacity is two; a full inventory is not a pickup failure.

If you do **not** need this authored arena spawn to be recreated on Start
fresh, omit step 3. The weapon is still interactable, and dropping it does
not require registration in `PickupSpawns`.

## Author a new weapon prefab

1. Follow [equipment authoring](equipment.md#add-a-melee-weapon-without-changing-core-code)
   to create your `Action5AttackDefinition` resources (unique attack IDs,
   mappings and optional F4 grip visuals), followed by an
   `Action5WeaponDefinition` with a distinct `weapon_id`,
   `display_name`, socket and attacks.
2. Create a reusable `PackedScene` such as `demo/equipment/axe.tscn`.
   Use a `Node3D` root with `res://addons/action5/equipment/weapon.gd`
   (`Action5Weapon`) and assign its `definition`. Give the root the
   `action5_weapon_pickup` group so room-visibility tracking can recognize
   loose weapons. For a firearm use `Action5Gun` and its required
   muzzle/fire/reload configuration instead.
3. Add world-rendered meshes to the prefab. Add a **direct child**
   `Node3D` named `PickupInteraction` with
   `res://demo/interactions/weapon_pickup_interaction.gd` attached.
   The child automatically joins `action5_interactable` in `_ready()`.
   Keep it **inside the weapon prefab**, not beside the scene instance:
   it must follow the same weapon when the actor picks up, drops or
   re-parents it.
4. Save the scene and **instance it into the desired level** using the
   editor. Give each authored instance a stable name, e.g. `AxePickup`,
   and a reachable transform. If the level uses an individual spawn-reset
   policy like the arena, register its path with that level's
   `PickupSpawns` as shown above.

A simplified prefab hierarchy looks like this (the root uses
`Action5Weapon` and the interaction child uses the demo's
`weapon_pickup_interaction.gd`):

```text
Axe [Node3D, Action5Weapon, group: action5_weapon_pickup]
├── Handle [MeshInstance3D]
├── Blade [MeshInstance3D]
└── PickupInteraction [Node3D, weapon_pickup_interaction.gd]
```

The group on the **weapon root** (`action5_weapon_pickup`) is used for
tracking loose world items. The interaction child joins the **different**
`action5_interactable` group for E selection. **Adding the weapon root
to a group by itself does not make E work.** There is no separate direct
`Equipment.pickup()` fallback in the main scene.

## Decide whether the spawn needs persistence

| Where the pickup lives | What to configure | What happens |
| --- | --- | --- |
| Main arena (`demo/main.tscn`) with Start fresh support | Add its instance path to the single `PickupSpawns.pickup_paths` array | `WorldSession` captures availability and calls `reset_to_initial()` for fresh arena entries. New world copies are created from the saved prefab, transform and name; carried items are untouched. |
| Connected dungeon (`demo/world/encounter_sector.tscn`) | Just instance the prefab in that scene | Ordinary travel retains the live dungeon; **Start fresh recreates the entire authored encounter scene**, including its pickups. No per-weapon state node or `PickupSpawns` is needed. |
| Cached detached room (for example `demo/world/remote_chamber.tscn`) | Just instance the prefab if retaining the cached room is desired | Cached scene instances survive travel by default. Do not register them in the arena's `PickupSpawns`. |
| Dynamically spawned weapon or dropped inventory item | No authored spawn registration | Interactions remain prefab-local; world-drop location and loose-item cleanup are managed by Equipment and world/session composition, not the original pickup slot. |

`PickupSpawns` belongs to **scene composition** under `demo/world/`, not
to `addons/action5/`. It registers existing **instanced PackedScene
roots** that resolve from configured `NodePath` values, whose parents
must be `Node3D`. It implements `capture_state()`,
`restore_state(snapshot)` and `reset_to_initial()` and joins
`action5_scene_persistable` automatically. Snapshot keys are the
configured relative paths (for example `../BatPickup`), not weapon
types or runtime instance IDs. A carried weapon is never deleted to
recreate the world spawn: a **new instance** is created instead.
All paths must resolve at the time `PickupSpawns` enters the scene
tree; add the authored instances before entering play mode.

## Validate the result

Use `make import` and `make check`, then perform a visual test in the
editor or with `make run`:

- Approach with room for another weapon in inventory, then use **E**.
  `Action5Interactor` selects the `PickupInteraction` through distance,
  current-scene eligibility and real wall/door line-of-sight checks.
  `Equipment.can_pickup()` also checks ownership, definition validity,
  attack registration, mount availability and the equipped slots.
- Drop it with **G**, pick up the **same instance** again, and switch views.
  The pickup and equipment logic should not depend on camera mode.
- For a configured arena slot, set `WorldSession.arena_entry_policy`
  to **Start fresh**, leave the arena and return. Confirm that the authored
  pickup is back at its original transform while a carried original stays
  in inventory. With **Restore previous**, it should not respawn simply
  because you crossed the gateway.
- For the dungeon, verify that ordinary visits preserve collected items,
  while **Start fresh** replaces its original scene content.

If E cannot collect the item, inspect the prefab's
`PickupInteraction` child, root `definition`, player `Equipment`
capacity, proximity, and any physical obstruction. If a pickup works but
does not respawn with the arena's Start fresh policy, inspect the
configured `PickupSpawns.pickup_paths` entry, ensure it points to a
**scene instance** with an intact `scene_file_path`, and verify the
entry policy is actually enabled. Do not restore the deleted
`world_pickup.gd` or create another weapon-specific state wrapper.

See [ADR-0007](adr/0007-scene-travel-prototype-vs-persistent-world.md) for
the scene lifecycle decision and `tests/d08_world_suite.gd` for the
regression checks.
