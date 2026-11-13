# ACTION-5 Iron Reliquary — UI appearance and asset inventory

This document describes **D09-03** and its intentionally demo-local skin.
The UI design borrows only broad material and layout inspiration from
late-1990s action RPGs such as Diablo and Symphony of the Night. It does not
contain artwork, logos, backgrounds, icons, fonts or UI screenshots copied
from those commercial games.

## Original assets

All assets in the following paths were created for ACTION-5 as original,
minimal vector illustrations in this contribution. They are covered by
the repository's MIT license:

| File | Content |
| --- | --- |
| `demo/ui/icons/bat.svg` | Stylized wooden bat |
| `demo/ui/icons/shovel.svg` | Stylized shovel |
| `demo/ui/icons/gun.svg` | Stylized pistol |
| `demo/ui/iron_frame.tres` | Original dark-metal / antique-gold panel skin |

The demo uses the built-in Godot font fallback and built-in Control widgets.
There are **no third-party fonts, textures or UI libraries** to attribute.

## Layout / interaction contract

- `demo/ui/iron_reliquary.tscn` is the **single reusable viewport HUD**
  for F1–F5. `iron_reliquary.gd` builds small fixed-anchor status and
  equipment panels with an open middle gap and event-only presentation.
  **Vitality is anchored top-left, Objective bottom-left, and Equipment
  bottom-right**, identically across all five camera views.
- `reference_hud.gd` is the demo-specific read-only adapter. It observes
  Health, Combat, Equipment, ViewManager, Interactor and InputMap. Never
  place health, ammo, reload or interaction decision logic in the UI layer.
- A weapon may optionally provide `Action5WeaponDefinition.hud_icon`.
  Null/missing icons show a neutral generic glyph; no game core depends on
  these textures.
- Bottom-right panel shows the **active item prominently** and the
  **next item in EquipmentController.swap_next() order** in a smaller label.
  The `demo_swap` key hint comes from InputMap (Q by default).
- `hud_toggle` (H by default) hides gameplay HUD chrome without mutating
  gameplay or affecting death/victory and help. `hud_help` (F6 by default)
  opens the controls and camera-selector overlay; C opens camera settings.
- Interaction prompts use `Action5Interactor.get_target(actor)`; exactly
  the same query selects the target for E interactions. Demo interactables
  can optionally implement `get_interaction_label(actor)`.
- Use 4:3/16:9 verification in native/Web at 720p and 1080p, including
  HUD hidden/visible, input focus, reloading, equip swap and scene travel.

## Extension guidance

Games can substitute a completely different skin and HUD without changing
`addons/action5/` gameplay components. Future inventory, profiles, leveling,
save games and quests belong in independent addons such as `bravado/game`,
not this demo's presentation logic.


## Camera shortcut labels (D09-03 adjustment)

The demo's primary shortcuts are **1 First-Person, 2 Beat 'em Up,
3 Isometric / Third-Person, 4 Side-Scroller, 5 Top-Down**. The input
adapter owns the mapping `[3, 1, 2, 0, 4]` for the ViewManager's stable
internal profile indices. `reference_hud.gd` queries the adapter for
numeric labels and the F6 help selector, so the game does not maintain an
independent map of shortcuts. The last profile's in-game display name is
**Top-Down**, even though its existing resource/enum retains the legacy
`retro_topdown` identifier for compatibility.


## D09-03 architecture simplifications (PR #38)

- **Equipment selection:** `Action5EquipmentController.get_next_weapon()` is
  the read-only Q-switch preview; `swap_next()` shares exactly that
  selection. Never recompute inventory index policies in the HUD.
- **Pickup eligibility:** `EquipmentController.can_pickup(weapon)` is a
  side-effect-free preflight shared with `WeaponPickupInteraction.can_interact`
  and checked again at `pickup()` commit time. It includes actual pickup
  radius, weapon validity, inventory space, attack registration and first
  auto-equip mount presence; HUD does not check these individually.
- **Declarative UI:** `iron_reliquary.tscn` owns fixed controls, anchors,
  theme overrides and the notice timer; the shorter `iron_reliquary.gd`
  only projects values and emits view/settings requests. The demo scene no
  longer contains duplicate invisible Help/Status/RetroDirection/buttons.
- **Event-specific updates:** Health, movement and reload ticks update
  only their respective presentation data. Full help/attack metadata is
  regenerated on view/equipment/attack changes and when help opens, or via
  explicit `Hud.refresh()` after remapping inputs. Both H/HUD and F6/Help
  footer/header labels are read from live InputMap.
- **Single visibility state:** The Iron Reliquary presenter alone owns
  gameplay HUD visibility. The adapter only forwards toggles and reads
  `display.is_gameplay_visible()`. Menus remain independent.
