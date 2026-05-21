@tool
extends EditorPlugin
## Registers the AI assist dock and connects it to the editor's
## screen-change signal.

## Informational version string, not enforced at runtime.
const VERSION: String = "1.1.0"
const SCENE_PATH: String = "res://addons/godot-openai/ai_panel.tscn"

## The instantiated AI panel dock. Held so it can be removed on plugin disable.
var dock: Node


func _enter_tree() -> void:
	if not dock:
		dock = load(SCENE_PATH).instantiate()
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, dock)
		main_screen_changed.connect(dock._on_main_screen_changed)
		dock.editor_interface = EditorInterface


func _exit_tree() -> void:
	remove_control_from_docks(dock)
	dock.queue_free()
