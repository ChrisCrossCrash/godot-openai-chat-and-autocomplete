@tool
class_name OpenAIClient
extends Node
## HTTP client for OpenAI-compatible backends. Handles fill-in-the-middle
## completions and multi-turn chat via /v1/chat/completions.

## Emitted when the LLM returns a completion. [param pre] and [param post]
## are the (possibly trimmed) context sent to the API, not the full editor text.
signal completion_received(completion: String, pre: String, post: String)
signal chat_received(text: String)
## Emitted on HTTP error or when the API response contains no
## [code]choices[/code] key.
signal completion_error(error: Variant)
## Emitted after [method fetch_models] completes. Empty array indicates failure.
signal models_received(model_ids: PackedStringArray)

## Marker placed between prefix and suffix in the user message so the
## model knows where to insert code.
const INSERT_TAG: String = "!INSERT_CODE_HERE!"
const COMPLETION_SYSTEM: String = """You are a code completion assistant for GDScript in Godot 4.x (GDScript 2.0 syntax).
Key syntax rules:
- Use @export annotation for exports
- Use Node3D instead of Spatial, and position instead of translation
- Use randf_range and randi_range instead of rand_range
- Connect signals via node.SIGNAL_NAME.connect(Callable(TARGET_OBJECT, TARGET_FUNC))
- Use rad_to_deg instead of rad2deg
- Use PackedByteArray instead of PoolByteArray
- Use instantiate instead of instance
- You can't use enumerate(OBJECT). Instead, use "for i in len(OBJECT):"

Remember, this is not Python. It's GDScript for use in Godot 4.x.

You may only respond with code, never add explanations. The user message contains a !INSERT_CODE_HERE! tag. Only respond with code to insert at that point. Never repeat the full script — only the inserted portion. Treat this as autocompletion: continue any unfinished word or expression before the tag.

Indentation: GDScript uses tabs only, never spaces. Count the tabs that appear before !INSERT_CODE_HERE! on its line — call that number N. Do NOT add leading whitespace to your very first output character (those N tabs are already in place). Every subsequent line you output must begin with N tabs as the base, plus one extra tab per additional nesting level. Never reset to column 0 for any line.

Example: if the context is "func foo():\n\t!INSERT_CODE_HERE!" (N=1), a correct two-branch output is:
if condition:\n\t\treturn true\nreturn false
where every line after the first starts with one base tab."""
## System message injected at position 0 of every conversation. Re-injected when
## the chat is cleared so the model always has the GDScript context.
const CHAT_PREFIX: String = """This is a GDScript script using Godot 4.x.
That means the new GDScript 2.0 syntax is used. Here are some of the important changes that were introduced in Godot 4:
- Use @export annotation for exports
- Use Node3D instead of Spatial, and position instead of translation
- Use randf_range and randi_range instead of rand_range
- Connect signals via node.SIGNAL_NAME.connect(Callable(TARGET_OBJECT, TARGET_FUNC))
- Use rad_to_deg instead of rad2deg
- Use PackedByteArray instead of PoolByteArray
- Use instantiate instead of instance
- You can't use enumerate(OBJECT). Instead, use "for i in len(OBJECT):"

Remember, this is not Python. It's GDScript for use in Godot 4.x.
You are a helpful assistant specializing in GDScript and Godot 4.x development.
"""
## Maximum combined character length of prompt prefix + suffix. If exceeded,
## the suffix is trimmed first; if that is still not enough, the prefix is
## trimmed from its start.
const MAX_LENGTH: int = 15000
const HEADERS: PackedStringArray = ["Content-Type: application/json"]

var model: String = ""
## When true the stop sequence is [code]"\n\n"[/code], allowing
## multi-line completions. When false the stop is [code]"\n"[/code].
var allow_multiline: bool = false
var chat_history: Array[Dictionary] = []

var _url: String = ""
var _pending_pre: String = ""
var _pending_post: String = ""

@onready var chat_req: HTTPRequest = $ChatHTTPRequest
@onready var completion_req: HTTPRequest = $CompletionHTTPRequest
@onready var fetch_models_req: HTTPRequest = $FetchModelsHTTPRequest


func _ready() -> void:
	completion_req.request_completed.connect(_on_request_completed)
	chat_req.request_completed.connect(_on_chat_complete)
	fetch_models_req.request_completed.connect(_on_fetch_models_completed)


func set_model(model_name: String) -> void:
	print_rich("[b]set_model[/b] - Set model: ", model_name)
	model = model_name


func set_url(url: String) -> void:
	_url = url


func fetch_models() -> void:
	var error := fetch_models_req.request(_url + "/v1/models/")
	if error != OK:
		models_received.emit(PackedStringArray())


## Trims [param prompt] and [param suffix] to [constant MAX_LENGTH] combined,
## then fires the HTTP request. The trimmed values are stored so
## [signal completion_received] carries what was actually sent.
func send_user_prompt(prompt: String, suffix: String) -> void:
	var diff := (prompt + suffix).length() - MAX_LENGTH
	if diff > 0:
		if suffix.length() > diff:
			suffix = suffix.substr(0, diff)
		else:
			prompt = prompt.substr(diff - suffix.length())
			suffix = ""
	_pending_pre = prompt
	_pending_post = suffix
	var messages: Array[Dictionary] = [
		{"role": "system", "content": COMPLETION_SYSTEM},
		{"role": "user", "content": prompt + INSERT_TAG + suffix}
	]
	var body := {
		"model": model,
		"messages": messages,
		"temperature": 0.5,
		"max_tokens": 500,
		"stop": "\n\n" if allow_multiline else "\n"
	}
	var error := completion_req.request(
		_url + "/v1/chat/completions",
		HEADERS,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if error != OK:
		completion_error.emit(null)


## Resets [member chat_history] to a single system message,
## discarding all prior turns.
func clean_chat() -> void:
	print_rich("[b]clean_chat[/b] - Deleting chat history")
	chat_history = [{"role": "system", "content": CHAT_PREFIX}]


func _on_request_completed(
	_result: int,
	_response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var parser := JSON.new()
	parser.parse(body.get_string_from_utf8())
	var response: Dictionary = parser.get_data()
	if not response.has("choices"):
		completion_error.emit(response)
		return
	var completion: String = response.choices[0].message.content
	completion_received.emit(completion, _pending_pre, _pending_post)


func chat_message(text: String) -> void:
	chat_history.push_back({"role": "user", "content": text})
	var body := {
		"model": model,
		"messages": chat_history,
		"temperature": 0.7,
		"max_tokens": -1,
		"stream": false
	}
	print_rich(
		"[b]chat_message[/b] - Calling url:",
		_url + "/v1/chat/completions",
		" - ",
		body
	)
	var error := chat_req.request(
		_url + "/v1/chat/completions",
		HEADERS,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if error != OK:
		completion_error.emit(null)


func _on_chat_complete(
	_result: int,
	_response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var parser := JSON.new()
	parser.parse(body.get_string_from_utf8())
	var response: Dictionary = parser.get_data()
	if not response.has("choices"):
		completion_error.emit(response)
		return
	var completion: Dictionary = response.choices[0].message
	chat_history.push_back(completion)
	chat_received.emit(completion.content)


func _on_fetch_models_completed(
	result: int,
	_response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		models_received.emit(PackedStringArray())
		return
	var parser := JSON.new()
	parser.parse(body.get_string_from_utf8())
	var json := parser.get_data()
	var ids := PackedStringArray()
	for m in json.data:
		ids.append(m.id)
	if ids.size() > 0:
		set_model(ids[0])
	models_received.emit(ids)
