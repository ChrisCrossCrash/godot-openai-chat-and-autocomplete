extends GutTest

const OpenAIClientScript = preload("res://addons/godot-openai/openai_client.gd")

var client: Node


func before_each() -> void:
	client = OpenAIClientScript.new()
	add_child_autofree(client)
	client._clean_chat()


func test_initial_chat_history_is_empty() -> void:
	var fresh: Node = OpenAIClientScript.new()
	add_child_autofree(fresh)
	assert_eq(fresh.chat_history.size(), 0)


func test_set_model_stores_name() -> void:
	client._set_model("llama3")
	assert_eq(client.model, "llama3")


func test_set_api_key_stores_key() -> void:
	client._set_api_key("test-key-123")
	assert_eq(client.api_key, "test-key-123")


func test_get_models_returns_empty_array() -> void:
	var models: Array = client._get_models()
	assert_typeof(models, TYPE_ARRAY)
	assert_eq(models.size(), 0)


func test_has_completion_received_signal() -> void:
	assert_has_signal(client, "completion_received")


func test_has_chat_received_signal() -> void:
	assert_has_signal(client, "chat_received")


func test_has_completion_error_signal() -> void:
	assert_has_signal(client, "completion_error")


func test_clean_chat_puts_system_message_first() -> void:
	assert_eq(client.chat_history[0].role, "system")


func test_user_message_is_appended_to_end() -> void:
	client._append_to_history({"role": "user", "content": "Hello!"})
	assert_eq(client.chat_history[-1].role, "user")
	assert_eq(client.chat_history[-1].content, "Hello!")


func test_assistant_reply_is_appended_to_end() -> void:
	client._append_to_history({"role": "user", "content": "Hello!"})
	client._append_to_history({"role": "assistant", "content": "Hi there!"})
	assert_eq(client.chat_history[-1].role, "assistant")
	assert_eq(client.chat_history[-1].content, "Hi there!")


func test_multi_turn_conversation_is_chronological() -> void:
	client._append_to_history({"role": "user", "content": "first message"})
	client._append_to_history({"role": "assistant", "content": "first reply"})
	client._append_to_history({"role": "user", "content": "second message"})

	assert_eq(client.chat_history.size(), 4)
	assert_eq(client.chat_history[0].role, "system")
	assert_eq(client.chat_history[1].content, "first message")
	assert_eq(client.chat_history[2].content, "first reply")
	assert_eq(client.chat_history[3].content, "second message")
