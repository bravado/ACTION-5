extends Resource
class_name Action5ViewFacingPolicy
## Per-view aim quantization, independent of shared attack timing.
@export_range(0, 4, 1) var view_mode: int = 4
@export_range(0, 32, 1) var sector_count: int = 0

func valid() -> bool:
    return view_mode >= 0 and view_mode <= 4 and (sector_count == 0 or sector_count >= 2)
