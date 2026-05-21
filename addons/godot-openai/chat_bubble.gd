@tool
extends HBoxContainer

func setup(
	text: String,
	theme: Theme,
	selectable: bool,
	align_right: bool
) -> void:
	var label := $Label as RichTextLabel
	var spacer := $Spacer as Control
	label.theme = theme
	label.text = text
	label.selection_enabled = selectable
	if align_right:
		spacer.size_flags_stretch_ratio = 0.3
		label.size_flags_stretch_ratio = 0.7
	else:
		spacer.visible = false
