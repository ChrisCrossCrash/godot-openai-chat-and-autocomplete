@tool
extends HBoxContainer


func setup(
	text: String, theme: Theme, selectable: bool, align_right: bool
) -> void:
	var label := $Label as RichTextLabel
	var spacer := $Spacer as Control
	label.theme = theme
	label.text = text
	label.selection_enabled = selectable
	if align_right:
		spacer.size_flags_horizontal = SIZE_SHRINK_BEGIN
		spacer.custom_minimum_size = Vector2(32, 0)
	else:
		spacer.visible = false
