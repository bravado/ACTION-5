extends Node
## Demo-only appearance. Tint the imported NPC meshes without changing their
## shared .glb materials or touching Combat/AI/Equipment.
@export var model_path: NodePath = ^"../Visual/Model"
@export var tint: Color = Color(0.9, 0.30, 0.22, 0.26)


func _ready() -> void:
    var model: Node = get_node_or_null(model_path)
    if model == null:
        return
    for node in model.find_children("*", "MeshInstance3D", true, false):
        var mesh := node as MeshInstance3D
        if mesh == null:
            continue
        var overlay := StandardMaterial3D.new()
        overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        overlay.albedo_color = tint
        mesh.material_overlay = overlay
