extends Node3D
## Optional presentation subscriber for any switch exposing state_changed
## and activated. It never controls the switch or the light source.

@export var source_path: NodePath = ^".."
@export var off_indicator_path: NodePath = ^"../IndicatorOff"
@export var on_indicator_path: NodePath = ^"../IndicatorOn"
@export var label_path: NodePath = ^"../Label3D"

@onready var source: Node = get_node_or_null(source_path)
@onready var off_indicator: Node3D = get_node_or_null(off_indicator_path) as Node3D
@onready var on_indicator: Node3D = get_node_or_null(on_indicator_path) as Node3D
@onready var status_label: Label3D = get_node_or_null(label_path) as Label3D


func _ready() -> void:
    if not is_instance_valid(source) or not source.has_signal("state_changed"):
        push_warning("ACTION5 demo: switch status display requires a state_changed signal")
        return
    source.state_changed.connect(_on_state_changed)
    _on_state_changed(bool(source.get("activated")))


func _on_state_changed(activated: bool) -> void:
    if is_instance_valid(off_indicator):
        off_indicator.visible = not activated
    if is_instance_valid(on_indicator):
        on_indicator.visible = activated
    if is_instance_valid(status_label):
        status_label.text = "LIGHT SWITCH [E] · " + ("ON" if activated else "OFF")
