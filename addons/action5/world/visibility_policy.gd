extends Resource
class_name Action5VisibilityPolicy
## Authoring-only presentation rules. Mode bit positions follow Action5ViewProfile.Mode.
## Shared Resource instances are read-only at runtime.

@export_flags("Side", "Beat 'em Up", "Isometric", "First Person", "Top Down") var hidden_modes: int = 0
@export_flags("Side", "Beat 'em Up", "Isometric", "First Person", "Top Down") var fade_modes: int = 0
@export_range(0.1, 30.0, 0.1) var fade_start_distance: float = 3.8
@export_range(0.0, 29.0, 0.1) var fully_faded_distance: float = 1.1
@export_range(0.05, 1.0, 0.05) var closest_opacity: float = 0.2
@export_range(1.0, 30.0, 0.5) var fade_speed: float = 11.0


func hides_in(mode: int) -> bool:
    return mode >= 0 and (hidden_modes & (1 << mode)) != 0


func fades_in(mode: int) -> bool:
    return mode >= 0 and (fade_modes & (1 << mode)) != 0


func opacity_at(distance: float) -> float:
    var span: float = maxf(fade_start_distance - fully_faded_distance, 0.01)
    var proximity: float = clampf((fade_start_distance - distance) / span, 0.0, 1.0)
    proximity = proximity * proximity * (3.0 - 2.0 * proximity)
    return lerpf(1.0, closest_opacity, proximity)
