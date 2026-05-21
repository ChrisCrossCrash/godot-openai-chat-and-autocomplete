@tool
extends Control

@onready var openai_client: Node = $OpenAIClient
@onready var model_select = $VBoxParent/SettingsCollapsable/SelectModel/Model
@onready var shortcut_modifier_select = $VBoxParent/SettingsCollapsable/ShortcutSetting/HBoxContainer/Modifier
@onready var shortcut_key_select = $VBoxParent/SettingsCollapsable/ShortcutSetting/HBoxContainer/Key
@onready var info: RichTextLabel = $VBoxParent/VBoxContainer/Info
@onready var url_text_input: LineEdit = get_node("%URL")
@onready var reload_button: TextureButton = $VBoxParent/SettingsCollapsable/SelectModel/TextureButton
@onready var loading_indicator: ColorRect = get_node("%Indicator")


# Section part
@onready var settings_section: Control = $VBoxParent/SettingsCollapsable
@onready var chat_section: ScrollContainer = get_node("%ChatSection")


#Chat element
@onready var send_button: Button = get_node("%SendChatMessage")
@onready var input_chat: TextEdit = get_node("%InputChat")
@onready var chat_container: VBoxContainer = get_node("%ChatContainer")

@export var icon_shader : ShaderMaterial
@export var highlight_color : Color

var editor_interface : EditorInterface
var screen = "Script"

var request_code_state = null
var cur_highlight = null
var indicator = null

var cur_model
var cur_shortcut_modifier = "Control" if is_mac() else "Alt"
var cur_shortcut_key = "C"
var allow_multiline = true
var URL


const PREFERENCES_STORAGE_NAME = "user://godot-openai.cfg"
const PREFERENCES_PASS = "F4fv2Jxpasp20VS5VSp2Yp2v9aNVJ21aRK"

func _ready():
	populate_modifiers()
	load_config()

func populate_modifiers():
	#Add available shortcut modifiers based on platform
	shortcut_modifier_select.clear()
	var modifiers = ["Alt", "Ctrl", "Shift"]
	if is_mac(): modifiers = ["Cmd", "Option", "Control", "Shift"]
	for modifier in modifiers:
		shortcut_modifier_select.add_item(modifier)
	apply_by_value(shortcut_modifier_select, cur_shortcut_modifier)

func _unhandled_key_input(event):
	#Handle input
	if event is InputEventKey:
		if cur_highlight:
			#If completion is shown, TAB will accept it
			#and the TAB input ignored
			if event.keycode == KEY_TAB:
				undo_input()
				clear_highlights()
			#BACKSPACE will remove it
			elif event.keycode == KEY_BACKSPACE:
				revert_change()
				clear_highlights()
			#Any other key press will plainly accept it
			else:
				clear_highlights()
		#If shortcut modifier and key are pressed, request completion
		if shortcut_key_pressed(event) and shortcut_modifier_pressed(event):
			request_completion()

func is_mac():
	#Platform check
	return OS.get_name() == "macOS"

func shortcut_key_pressed(event):
	#Check if selected shortcut key is pressed
	var key_string = OS.get_keycode_string(event.keycode)
	return key_string == cur_shortcut_key

func shortcut_modifier_pressed(event):
	#Check if selected shortcut modifier is pressed
	match cur_shortcut_modifier:
		"Control":
			return event.ctrl_pressed
		"Ctrl":
			return event.ctrl_pressed
		"Alt":
			return event.alt_pressed
		"Option":
			return event.alt_pressed
		"Shift":
			return event.shift_pressed
		"Cmd":
			return event.meta_pressed
		_:
			return false

func clear_highlights():
	#Clear all currently highlighted lines
	#and reset request status
	request_code_state = null
	cur_highlight = null
	var editor = get_code_editor()
	for line in range(editor.get_line_count()):
		editor.set_line_background_color(line, Color(0, 0, 0, 0))

func undo_input():
	#Undo last input in code editor
	var editor = get_code_editor()
	editor.undo()

func update_loading_indicator(create = false):
	#Make sure loading indicator is placed at caret position
	if screen != "Script": return
	var editor = get_code_editor()
	if !editor: return
	var line_height = editor.get_line_height()
	if !is_instance_valid(indicator):
		if !create: return
		indicator = ColorRect.new()
		indicator.material = icon_shader
		indicator.custom_minimum_size = Vector2(line_height, line_height)
		editor.add_child(indicator)
	var pos = editor.get_caret_draw_pos()
	var pre_post = get_pre_post()
	#Caret position returned from Godot is not reliable
	#Needs to be adjusted for empty lines
	var is_on_empty_line = pre_post[0].right(1) == "\n"
	var offset = line_height/2-1 if is_on_empty_line else line_height-1
	indicator.position = Vector2(pos.x, pos.y - offset)
	editor.editable = false

func remove_loading_indicator():
	#Free loading indicator, and return editor to editable state
	if is_instance_valid(indicator): indicator.queue_free()
	var editor = get_code_editor()
	editor.editable = true

# Write 3 lines here

func insert_completion(content: String, pre, post):
	#Overwrite code editor text to insert received completion
	info.text = content
	var editor = get_code_editor()
	var scroll = editor.scroll_vertical

	var caret_text = pre + content
	var lines_from = pre.split("\n")
	var lines_to = caret_text.split("\n")

	cur_highlight = [lines_from.size(), lines_to.size()]

	editor.set_text(pre + content + post)
	editor.set_caret_line(lines_to.size())
	editor.set_caret_column(lines_to[-1].length())
	editor.scroll_vertical = scroll
	editor.update_code_completion_options(false)

func revert_change():
	#Revert inserted completion
	var code_edit = get_code_editor()
	var scroll = code_edit.scroll_vertical
	var old_text = request_code_state[0] + request_code_state[1]
	var lines_from = request_code_state[0].strip_edges(false, true).split("\n")
	code_edit.set_text(old_text)
	code_edit.set_caret_line(lines_from.size()-1)
	code_edit.set_caret_column(lines_from[-1].length())
	code_edit.scroll_vertical = scroll
	clear_highlights()

func _process(delta):
	update_highlights()
	update_loading_indicator()

func update_highlights():
	#Make sure highlighted lines persist until explicitly removed
	#via key input
	if cur_highlight:
		var editor = get_code_editor()
		for line in range(cur_highlight[0]-1, cur_highlight[1]):
			editor.set_line_background_color(line, highlight_color)

func on_main_screen_changed(_screen):
	#Track current editor screen (2D, 3D, Script)
	screen = _screen

func get_current_script():
	#Get currently edited script
	if !editor_interface: return
	var script_editor = editor_interface.get_script_editor()
	return script_editor.get_current_script()

func get_code_editor():
	#Get currently used code editor
	#This does not return the shader editor!
	if !editor_interface: return
	var script_editor = editor_interface.get_script_editor()
	var base_editor = script_editor.get_current_editor()
	if base_editor:
		var code_edit = base_editor.get_base_editor()
		return code_edit
	return null

func request_completion():
	print_rich("[b]request_completion[/b] - Asking to complete the code")
	#Get current code and request completion from active model
	#if request_code_state: return
	#update_loading_indicator(true)
	var pre_post = get_pre_post()
	var llm = get_llm()
	print_rich("[b]request_completion[/b] - LLM found", llm)
	if !llm: return
	llm._send_user_prompt(pre_post[0], pre_post[1])
	request_code_state = pre_post


#Make an add function

func get_pre_post():
	#Split current code based on caret position
	var editor: Control = get_code_editor()
	var text = editor.get_text()
	var pos = Vector2(editor.get_caret_line(), editor.get_caret_column())
	var pre = ""
	var post = ""
	for i in range(pos.x):
		pre += editor.get_line(i) + "\n"
	pre += editor.get_line(pos.x).substr(0,pos.y)
	post += editor.get_line(pos.x).substr(pos.y) + "\n"
	for ii in range(pos.x+1, editor.get_line_count()):
		post += editor.get_line(ii) + "\n"
	return [pre, post]

#Wrinte ad add function

func get_llm():
	return openai_client

func matches_request_state(pre, post):
	#Check if code passed for completion request matches current code
	return request_code_state[0] == pre and request_code_state[1] == post

func set_model(model_name):
	#Apply selected model
	print_rich("[b]set_model[/b] - Setted model: ", model_name)
	cur_model = model_name
	var llm = get_llm()
	llm._set_model(model_name)


func set_shortcut_modifier(modifier):
	#Apply selected shortcut modifier
	cur_shortcut_modifier = modifier

func set_shortcut_key(key):
	#Apply selected shortcut key
	cur_shortcut_key = key


func _on_code_completion_received(completion, pre, post):
	#Attempt to insert received code completion
	print_rich("[b]_on_code_completion_received[/b] - Checking parameter: ", completion)
	remove_loading_indicator()
	if matches_request_state(pre, post):
		insert_completion(completion, pre, post)
	else:
		clear_highlights()

func _on_code_completion_error(error):
	#Display error
	remove_loading_indicator()
	clear_highlights()
	push_error(error)



func _on_model_selected(index):
	#Apply setting and store in config file
	set_model(model_select.get_item_text(index))
	store_config()

func _on_shortcut_modifier_selected(index):
	#Apply setting and store in config file
	set_shortcut_modifier(shortcut_modifier_select.get_item_text(index))
	store_config()

func _on_shortcut_key_selected(index):
	#Apply setting and store in config file
	set_shortcut_key(shortcut_key_select.get_item_text(index))
	store_config()

func store_config():
	#Store current setting in config file
	var config = ConfigFile.new()
	config.set_value("preferences", "model", cur_model)
	config.set_value("preferences", "shortcut_modifier", cur_shortcut_modifier)
	config.set_value("preferences", "shortcut_key", cur_shortcut_key)
	config.save_encrypted_pass(PREFERENCES_STORAGE_NAME, PREFERENCES_PASS)

func load_config():
	#Retrieve current settings from config file
	var config = ConfigFile.new()
	var err = config.load_encrypted_pass(PREFERENCES_STORAGE_NAME, PREFERENCES_PASS)
	openai_client._set_url(url_text_input.text)
	fetch_models()
	if err != OK: return
	cur_model = config.get_value("preferences", "model", cur_model)
	apply_by_value(model_select, cur_model)
	set_model(model_select.get_item_text(model_select.selected))
	cur_shortcut_modifier = config.get_value("preferences", "shortcut_modifier", cur_shortcut_modifier)
	apply_by_value(shortcut_modifier_select, cur_shortcut_modifier)
	cur_shortcut_key = config.get_value("preferences", "shortcut_key", cur_shortcut_key)
	apply_by_value(shortcut_key_select, cur_shortcut_key)


func apply_by_value(option_button, value):
	#Select item for option button based on value instead of index
	for i in option_button.item_count:
		if option_button.get_item_text(i) == value:
			option_button.select(i)

func fetch_models():
	reload_button.visible = false
	loading_indicator.visible = true
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", self._on_models_loaded)
	var error = http_request.request(url_text_input.text+"/v1/models/")
	if error != OK:
		reload_button.visible = true
		loading_indicator.visible = false
		pass
		# handle the error

func _on_models_loaded(result, response_code, headers, body):
	reload_button.visible = true
	loading_indicator.visible = false
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Error fetching models")
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var json = test_json_conv.get_data()
	model_select.clear()
	for model in json.data:
		model_select.add_item(model.id)
	model_select.select(0)
	openai_client._set_model(json.data[0].id)

func _on_texture_button_button_down() -> void:
	fetch_models()


func _on_url_text_changed(new_text: String) -> void:
	openai_client._set_url(new_text)
	store_config()


func _on_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		settings_section.visible = true
	else:
		settings_section.visible = false


func _on_enable_chat_toggled(toggled_on: bool) -> void:
	if toggled_on:
		chat_section.visible = true
	else:
		chat_section.visible = false


func _bot_message(text: String) -> void:
	var label: RichTextLabel = RichTextLabel.new()
	var theme = ResourceLoader.load("res://addons/godot-openai/asset/BotTheme.tres")
	label.theme = theme
	label.text = text
	label.bbcode_enabled = true
	label.fit_content = true
	label.selection_enabled = true
	chat_container.add_child(label)
	#Create horizontal separator
	var hseparator: HSeparator = HSeparator.new()
	hseparator.custom_minimum_size = Vector2(0,35)
	chat_container.add_child(hseparator)
	#Scroll to end
	await get_tree().process_frame
	chat_section.scroll_vertical = chat_section.get_v_scroll_bar().max_value


func _user_message(text: String) -> void:
	var label: RichTextLabel = RichTextLabel.new()
	var theme = ResourceLoader.load("res://addons/godot-openai/asset/UserTheme.tres")
	label.theme = theme
	label.text = text
	label.bbcode_enabled = true
	label.fit_content = true
	chat_container.add_child(label)
	#Create horizontal separator
	var hseparator: HSeparator = HSeparator.new()
	hseparator.custom_minimum_size = Vector2(0,35)
	chat_container.add_child(hseparator)
	#Scroll to end
	await get_tree().process_frame
	chat_section.scroll_vertical = chat_section.get_v_scroll_bar().max_value

func _on_send_chat_message_pressed() -> void:
	print_rich("[b]_on_send_chat_message_pressed[/b] - Sending message")
	#Send chat message
	if !input_chat:
		input_chat = get_node("%InputChat")
	var text = input_chat.text
	#Logic to call the API
	_user_message(text)
	input_chat.text = ""
	get_llm().chat_message(text)


func _on_send_chat_message_2_pressed() -> void:
	get_llm()._clean_chat()
	for c in chat_container.get_children():
		c.queue_free()


func _on_chat_received(text: Variant) -> void:
	_bot_message(text)
