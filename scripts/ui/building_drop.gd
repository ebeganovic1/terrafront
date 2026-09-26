extends Control

signal placement_requested(action: String, screen_position: Vector2)
signal placement_hovered(action: String, screen_position: Vector2)
signal placement_ended

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		mouse_filter = Control.MOUSE_FILTER_STOP
	elif what == NOTIFICATION_DRAG_END:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		placement_ended.emit()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("type") != "building":
		return false
	placement_hovered.emit(data.action, at_position + global_position)
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	placement_requested.emit(data.action, at_position + global_position)
