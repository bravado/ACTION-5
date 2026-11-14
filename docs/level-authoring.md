# Level authoring: GridMap, imported scenes and modular geometry

ACTION-5 does **not** define a mandatory geometry format. A level is an
ordinary Godot `Node3D` / `PackedScene`. Compose GridMaps, inherited or
wrapped glTF/GLB scenes, modular `.tscn` prefabs, and handmade meshes inside
one level, or use entirely different techniques for separate locations.
The level's physical world is always 3D in every camera mode.

## Author a level

1. Create a scene rooted at `Node3D` and place static geometry using any
   supported Godot 3D authoring tool. Import Blender assets as GLB and wrap
   the imported scene rather than modifying the generated import data.
2. Add physical collision to walkable/solid geometry. A GridMap uses a
   `MeshLibrary` with collision shapes; imported models require explicitly
   configured collision. Visibility never generates or changes collision.
3. Add a `NavigationRegion3D` and bake navigation in the Godot editor for
   the **actual** walkable geometry. Connect regions with `NavigationLink3D`
   for doors as appropriate; navigation is not a camera rendering policy.
4. Place reusable enemy, weapon, door, portal and spawn-point scenes.
   Existing `WorldDoor` and `LocationPortal` handle physical vs detached
   travel independently of the authored geometry.
5. Instance the environment as a sector inside a shared game world (or
   load it through the existing `LocationManager`). Do not duplicate
   Player, CameraRig, Equipment, Combat or input controllers in levels.

A representative scene:

```text
Village (Node3D)
├── ImportedEnvironment (GLB instance)
├── TileFloors (GridMap)
├── Houses (PackedScene instances)
├── DynamicProps (interactable scenes)
├── NavigationRegion3D
├── Arrival (Marker3D)
└── VisibilityTargets (optional; generally parent within each visual)
```

The current demo uses two connected areas plus cached detached locations.
The demo's fixed sector-crossing threshold, camera bounds and room-occlusion
arrays are **composition-specific**, not required level interfaces. New
connected geometries must configure those demo systems or use their own
scene adapters. The visibility integration does not convert the demo's hand-built
geometry into a GridMap or change its navigation topology. The
follow-up work is tracked in [level authoring issue #41](https://github.com/bravado/ACTION-5/issues/41).

## Visibility policies

Attach `Action5VisibilityTarget` as a child of an authored **visual**
root (StaticBody3D, Node3D wrapper, MeshInstance3D or GridMap), assign
an `Action5VisibilityPolicy` Resource, and add one
`Action5VisibilityController` to the shared world. Set its actor and
view-manager NodePaths. The target is discovered when the level is inserted,
including cached detached `PackedScene` locations.

- `visual_root_path`: sibling/parent path to the geometry whose visual
  descendants should be controlled. Imported GLB hierarchy is supported.
- `proximity_shape_path`: optional `CollisionShape3D` with `BoxShape3D`
  for precise long-wall horizontal footprint distance. If missing, bounds
  of contained `MeshInstance3D` nodes determine proximity.
- `hidden_modes`: hide visuals in selected camera modes, immediately.
- `fade_modes`: apply proximity opacity to eligible mesh surfaces in
  selected views. The same mode may have hide and fade enabled; hide wins.
- `fade_start_distance`, `fully_faded_distance`,
  `closest_opacity`, `fade_speed`: configurable visual transition.

The demo uses `demo/world/visibility/outer_wall.tres` for ordinary
exterior walls and `foreground_wall.tres` for the additional side-view
hide. They intentionally preserve opaque FPS and top-down exteriors.
To make a roof hide in top-down only, set `hidden_modes` to Top Down,
leaving fading disabled. To make a tree fade in isometric, select
Isometric under `fade_modes`; the tree's collision stays unchanged.

Only `StandardMaterial3D` can alpha-fade, including either a mesh-wide
`material_override` or compatible mesh surfaces. The renderer creates
cached private material duplicates for Godot's Compatibility/WebGL2
renderer; it restores the exact original overrides, authored visibility
and shadow flags when opacity returns to normal, when a target is
removed (even if its mesh survives), or when the controller exits.
Hide-only targets do not allocate translucent material duplicates.
Other material types and `GridMap` support hide/show only. A GridMap's
cells are not separately addressable `MeshInstance3D` objects; for
individual fades, isolate visual chunks in separate GridMaps or prefab
meshes instead of generating one Node3D per tile.

Do **not** overlap multiple VisibilityTargets on the same mesh; each
visual must have one presenter owner. `RoomVisibility` operates at the
parent scene level; this view policy does not override a hidden room or
change enemy discovery, physical doors, collision, navigation or raycasts.
For nontrivial room occlusion (including closed-door hiding), continue
using the game-level room-visibility adapter separately.

## Runtime and performance

The controller registers target nodes on scene insertion rather than
scanning all geometry each frame. It processes only opted-in targets,
prunes unloaded/reparented instances, and reuses any transparent material
copies. The present update loop also visits hide-only targets each frame;
those targets do not allocate fade materials. Avoid attaching targets
to unrelated level geometry that never requires a visibility policy.
For huge environments, split authored geometry into independently
controllable chunks and profile native and WebGL2 builds before adding
automatic occlusion raycasts or per-cell material changes.

## Acceptance

`tests/world_visibility_suite.gd` checks a nested imported-style geometry
wrapper, independent view masks, material surfaces and mesh-wide overrides,
authored-state restoration on target removal, physical collision,
dynamic unloading and GridMap group visibility.
The existing D08 suites cover arena/dungeon/remote visibility, view
switching and fresh-entry re-instancing.
