@tool
extends EditorPlugin
## Registers the AI assist ai_panel and connects it to the editor's
## screen-change signal.

const SCENE_PATH: String = "res://addons/godot-openai/ai_panel.tscn"

## The instantiated AI panel ai_panel. Held so it can be removed on plugin disable.
var ai_panel: Node


func _enter_tree() -> void:
	if not ai_panel:
		ai_panel = load(SCENE_PATH).instantiate()
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, ai_panel)
		main_screen_changed.connect(ai_panel._on_main_screen_changed)
		ai_panel.editor_interface = EditorInterface


func _exit_tree() -> void:
	remove_control_from_docks(ai_panel)
	ai_panel.queue_free()
