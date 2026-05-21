@tool
extends Control
## Main AI assist panel. Orchestrates code completion requests, multi-turn chat,
## settings persistence, and keyboard shortcut handling.

const PREFERENCES_STORAGE_NAME: String = "user://godot-openai.cfg"
const PREFERENCES_PASS: String = "F4fv2Jxpasp20VS5VSp2Yp2v9aNVJ21aRK"

## Shader applied to the loading indicator overlay drawn at the caret.
@export var icon_shader: ShaderMaterial
## Color applied to lines inserted by a pending completion,
## cleared on accept or revert.
@export var highlight_color: Color

## Injected by plugin.gd after the dock is instantiated. All code editor access
## depends on this; completion requests silently no-op if it is not set.
var editor_interface: EditorInterface

## Tracks the active editor screen; completion requests are suppressed
## when this is not [code]"Script"[/code].
var _screen: String = "Script"
## Snapshot of [pre, post] taken when a completion request was fired. Used to
## detect whether the editor changed mid-flight and discard stale results.
var _request_code_state: Variant = null
## [start_line, end_line] range of the current completion highlight,
## or null when no completion is pending.
var _cur_highlight: Variant = null

var _cur_model: String = ""
var _cur_shortcut_modifier: String = "Control" if _is_mac() else "Alt"
var _cur_shortcut_key: String = "C"
## Overlay node rendered at the caret position while a completion
## request is in flight.
var _indicator: ColorRect

@onready var _openai_client: Node = $OpenAIClient
@onready var _model_select: OptionButton = $VBoxParent/SettingsCollapsible/SelectModel/Model
@onready var _shortcut_modifier_select: OptionButton = $VBoxParent/SettingsCollapsible/ShortcutSetting/HBoxContainer/Modifier
@onready var _shortcut_key_select: OptionButton = $VBoxParent/SettingsCollapsible/ShortcutSetting/HBoxContainer/Key
@onready var _info: RichTextLabel = $VBoxParent/VBoxContainer/Info
@onready var _url_text_input: LineEdit = get_node("%URL")
@onready var _reload_button: TextureButton = $VBoxParent/SettingsCollapsible/SelectModel/TextureButton
@onready var _loading_indicator: ColorRect = get_node("%Indicator")
@onready var _settings_section: Control = $VBoxParent/SettingsCollapsible
@onready var _chat_section: ScrollContainer = get_node("%ChatSection")
@onready var _input_chat: TextEdit = get_node("%InputChat")
@onready var _chat_container: VBoxContainer = get_node("%ChatContainer")


func _ready() -> void:
	_populate_modifiers()
	_load_config()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if _cur_highlight:
		if key_event.keycode == KEY_TAB:
			_undo_input()
			_clear_highlights()
		elif key_event.keycode == KEY_BACKSPACE:
			_revert_change()
			_clear_highlights()
		else:
			_clear_highlights()
	if _shortcut_key_pressed(key_event) and _shortcut_modifier_pressed(key_event):
		_request_completion()


func _process(_delta: float) -> void:
	_update_highlights()
	_update_loading_indicator()


func _on_main_screen_changed(screen: String) -> void:
	_screen = screen


func _on_code_completion_received(
	completion: String,
	pre: String,
	post: String
) -> void:
	print_rich("[b]_on_code_completion_received[/b] - Checking parameter: ",
		completion)
	_remove_loading_indicator()
	if _matches_request_state(pre, post):
		_insert_completion(completion, pre, post)
	else:
		_clear_highlights()


func _on_code_completion_error(error: Variant) -> void:
	_remove_loading_indicator()
	_clear_highlights()
	push_error(error)


func _on_model_selected(index: int) -> void:
	_set_model(_model_select.get_item_text(index))
	_store_config()


func _on_shortcut_modifier_selected(index: int) -> void:
	_set_shortcut_modifier(_shortcut_modifier_select.get_item_text(index))
	_store_config()


func _on_shortcut_key_selected(index: int) -> void:
	_set_shortcut_key(_shortcut_key_select.get_item_text(index))
	_store_config()


func _on_texture_button_button_down() -> void:
	_fetch_models()


func _on_url_text_changed(new_text: String) -> void:
	_openai_client._set_url(new_text)
	_store_config()


func _on_check_button_toggled(toggled_on: bool) -> void:
	_settings_section.visible = toggled_on


func _on_enable_chat_toggled(toggled_on: bool) -> void:
	_chat_section.visible = toggled_on


func _on_send_chat_message_pressed() -> void:
	print_rich("[b]_on_send_chat_message_pressed[/b] - Sending message")
	var text := _input_chat.text
	_user_message(text)
	_input_chat.text = ""
	_get_llm().chat_message(text)


func _on_send_chat_message_2_pressed() -> void:
	_get_llm()._clean_chat()
	for c in _chat_container.get_children():
		c.queue_free()


func _on_chat_received(text: String) -> void:
	_bot_message(text)


func _on_models_loaded(
	result: int,
	_response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_reload_button.visible = true
	_loading_indicator.visible = false
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Error fetching models")
	var parser := JSON.new()
	parser.parse(body.get_string_from_utf8())
	var json := parser.get_data()
	_model_select.clear()
	for model in json.data:
		_model_select.add_item(model.id)
	_model_select.select(0)
	_openai_client._set_model(json.data[0].id)


func _populate_modifiers() -> void:
	_shortcut_modifier_select.clear()
	var modifiers: Array[String] = ["Alt", "Ctrl", "Shift"]
	if _is_mac():
		modifiers = ["Cmd", "Option", "Control", "Shift"]
	for modifier in modifiers:
		_shortcut_modifier_select.add_item(modifier)
	_apply_by_value(_shortcut_modifier_select, _cur_shortcut_modifier)


func _is_mac() -> bool:
	return OS.get_name() == "macOS"


func _shortcut_key_pressed(event: InputEventKey) -> bool:
	return OS.get_keycode_string(event.keycode) == _cur_shortcut_key


func _shortcut_modifier_pressed(event: InputEventKey) -> bool:
	match _cur_shortcut_modifier:
		"Control", "Ctrl":
			return event.ctrl_pressed
		"Alt", "Option":
			return event.alt_pressed
		"Shift":
			return event.shift_pressed
		"Cmd":
			return event.meta_pressed
		_:
			return false


func _clear_highlights() -> void:
	_request_code_state = null
	_cur_highlight = null
	var editor := _get_code_editor()
	for line in range(editor.get_line_count()):
		editor.set_line_background_color(line, Color(0, 0, 0, 0))


func _undo_input() -> void:
	_get_code_editor().undo()


## Positions the loading indicator at the caret. Pass [param create] =
## [code]true[/code] on the first call to instantiate the indicator;
## subsequent calls just reposition it.
func _update_loading_indicator(create: bool = false) -> void:
	if _screen != "Script":
		return
	var editor := _get_code_editor()
	if not editor:
		return
	var line_height := editor.get_line_height()
	if not is_instance_valid(_indicator):
		if not create:
			return
		_indicator = ColorRect.new()
		_indicator.material = icon_shader
		_indicator.custom_minimum_size = Vector2(line_height, line_height)
		editor.add_child(_indicator)
	var pos := editor.get_caret_draw_pos()
	var pre_post := _get_pre_post()
	# Caret position from Godot is unreliable; adjust offset for empty lines.
	var is_on_empty_line := pre_post[0].right(1) == "\n"
	var offset := line_height / 2 - 1 if is_on_empty_line else line_height - 1
	_indicator.position = Vector2(pos.x, pos.y - offset)
	editor.editable = false


func _remove_loading_indicator() -> void:
	if is_instance_valid(_indicator):
		_indicator.queue_free()
	var editor := _get_code_editor()
	editor.editable = true


## Replaces the entire editor text with pre + content + post and highlights
## the inserted lines. Revert is possible via [member _request_code_state].
func _insert_completion(content: String, pre: String, post: String) -> void:
	_info.text = content
	var editor := _get_code_editor()
	var scroll := editor.scroll_vertical
	var caret_text := pre + content
	var lines_from := pre.split("\n")
	var lines_to := caret_text.split("\n")
	_cur_highlight = [lines_from.size(), lines_to.size()]
	editor.set_text(pre + content + post)
	editor.set_caret_line(lines_to.size())
	editor.set_caret_column(lines_to[-1].length())
	editor.scroll_vertical = scroll
	editor.update_code_completion_options(false)


func _revert_change() -> void:
	var code_edit := _get_code_editor()
	var scroll := code_edit.scroll_vertical
	var pre: String = _request_code_state[0]
	var post: String = _request_code_state[1]
	var lines_from := pre.strip_edges(false, true).split("\n")
	code_edit.set_text(pre + post)
	code_edit.set_caret_line(lines_from.size() - 1)
	code_edit.set_caret_column(lines_from[-1].length())
	code_edit.scroll_vertical = scroll
	_clear_highlights()


func _update_highlights() -> void:
	if _cur_highlight:
		var editor := _get_code_editor()
		var from: int = _cur_highlight[0]
		var to: int = _cur_highlight[1]
		for line in range(from - 1, to):
			editor.set_line_background_color(line, highlight_color)


func _get_code_editor() -> CodeEdit:
	if not editor_interface:
		return null
	var script_editor := editor_interface.get_script_editor()
	var base_editor := script_editor.get_current_editor()
	if base_editor:
		# Returns null for shader editor and other non-CodeEdit editors.
		return base_editor.get_base_editor() as CodeEdit
	return null


func _request_completion() -> void:
	print_rich("[b]request_completion[/b] - Asking to complete the code")
	var pre_post := _get_pre_post()
	var llm := _get_llm()
	print_rich("[b]request_completion[/b] - LLM found", llm)
	if not llm:
		return
	llm._send_user_prompt(pre_post[0], pre_post[1])
	_request_code_state = pre_post


## Splits the active editor text at the caret into [pre, post].[br]
## pre = all text up to (not including) the caret; post = all text after.
func _get_pre_post() -> Array[String]:
	var editor := _get_code_editor()
	var pos := Vector2i(editor.get_caret_line(), editor.get_caret_column())
	var pre: String = ""
	var post: String = ""
	for i in range(pos.x):
		pre += editor.get_line(i) + "\n"
	pre += editor.get_line(pos.x).substr(0, pos.y)
	post += editor.get_line(pos.x).substr(pos.y) + "\n"
	for ii in range(pos.x + 1, editor.get_line_count()):
		post += editor.get_line(ii) + "\n"
	var result: Array[String] = [pre, post]
	return result


func _get_llm() -> Node:
	return _openai_client


## Returns true if the editor content still matches the snapshot in
## [member _request_code_state]. A false result means the user typed during
## the request and the incoming completion should be discarded.
func _matches_request_state(pre: String, post: String) -> bool:
	return _request_code_state[0] == pre and _request_code_state[1] == post


func _set_model(model_name: String) -> void:
	print_rich("[b]set_model[/b] - Set model: ", model_name)
	_cur_model = model_name
	_get_llm()._set_model(model_name)


func _set_shortcut_modifier(modifier: String) -> void:
	_cur_shortcut_modifier = modifier


func _set_shortcut_key(key: String) -> void:
	_cur_shortcut_key = key


func _store_config() -> void:
	var config := ConfigFile.new()
	config.set_value("preferences", "model", _cur_model)
	config.set_value("preferences", "shortcut_modifier", _cur_shortcut_modifier)
	config.set_value("preferences", "shortcut_key", _cur_shortcut_key)
	config.save_encrypted_pass(PREFERENCES_STORAGE_NAME, PREFERENCES_PASS)


func _load_config() -> void:
	var config := ConfigFile.new()
	var err := config.load_encrypted_pass(PREFERENCES_STORAGE_NAME, PREFERENCES_PASS)
	_openai_client._set_url(_url_text_input.text)
	_fetch_models()
	if err != OK:
		return
	_cur_model = config.get_value("preferences", "model", _cur_model)
	_apply_by_value(_model_select, _cur_model)
	_set_model(_model_select.get_item_text(_model_select.selected))
	_cur_shortcut_modifier = config.get_value(
		"preferences", "shortcut_modifier", _cur_shortcut_modifier)
	_apply_by_value(_shortcut_modifier_select, _cur_shortcut_modifier)
	_cur_shortcut_key = config.get_value(
		"preferences", "shortcut_key", _cur_shortcut_key)
	_apply_by_value(_shortcut_key_select, _cur_shortcut_key)


## Selects an [OptionButton] item whose display text matches [param value].
## [OptionButton] has no built-in select-by-value API.
func _apply_by_value(option_button: OptionButton, value: String) -> void:
	for i in option_button.item_count:
		if option_button.get_item_text(i) == value:
			option_button.select(i)


func _fetch_models() -> void:
	_reload_button.visible = false
	_loading_indicator.visible = true
	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_models_loaded)
	var error := http_request.request(_url_text_input.text + "/v1/models/")
	if error != OK:
		_reload_button.visible = true
		_loading_indicator.visible = false


func _bot_message(text: String) -> void:
	var label := RichTextLabel.new()
	var theme: Theme = ResourceLoader.load(
		"res://addons/godot-openai/asset/BotTheme.tres")
	label.theme = theme
	label.text = text
	label.bbcode_enabled = true
	label.fit_content = true
	label.selection_enabled = true
	_chat_container.add_child(label)
	var hseparator := HSeparator.new()
	hseparator.custom_minimum_size = Vector2(0, 35)
	_chat_container.add_child(hseparator)
	await get_tree().process_frame
	_chat_section.scroll_vertical = _chat_section.get_v_scroll_bar().max_value


func _user_message(text: String) -> void:
	var label := RichTextLabel.new()
	var theme: Theme = ResourceLoader.load(
		"res://addons/godot-openai/asset/UserTheme.tres")
	label.theme = theme
	label.text = text
	label.bbcode_enabled = true
	label.fit_content = true
	_chat_container.add_child(label)
	var hseparator := HSeparator.new()
	hseparator.custom_minimum_size = Vector2(0, 35)
	_chat_container.add_child(hseparator)
	await get_tree().process_frame
	_chat_section.scroll_vertical = _chat_section.get_v_scroll_bar().max_value
