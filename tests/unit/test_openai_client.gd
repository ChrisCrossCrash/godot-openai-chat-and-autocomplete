extends GutTest

const OpenAIClientScene := preload("res://addons/godot-openai/openai_client.tscn")

var client: OpenAIClient


func before_each() -> void:
	client = OpenAIClientScene.instantiate()
	add_child_autofree(client)
	client.clean_chat()


func test_initial_chat_history_is_empty() -> void:
	var fresh: OpenAIClient = OpenAIClientScene.instantiate()
	add_child_autofree(fresh)
	assert_eq(fresh.chat_history.size(), 0)


func test_set_model_stores_name() -> void:
	client.set_model("llama3")
	assert_eq(client.model, "llama3")


func test_has_completion_received_signal() -> void:
	assert_has_signal(client, "completion_received")


func test_has_chat_received_signal() -> void:
	assert_has_signal(client, "chat_received")


func test_has_completion_error_signal() -> void:
	assert_has_signal(client, "completion_error")


func test_clean_chat_puts_system_message_first() -> void:
	assert_eq(client.chat_history[0].role, "system")


func test_user_message_is_appended_to_end() -> void:
	client.chat_history.push_back({"role": "user", "content": "Hello!"})
	assert_eq(client.chat_history[-1].role, "user")
	assert_eq(client.chat_history[-1].content, "Hello!")


func test_assistant_reply_is_appended_to_end() -> void:
	client.chat_history.push_back({"role": "user", "content": "Hello!"})
	client.chat_history.push_back({"role": "assistant", "content": "Hi there!"})
	assert_eq(client.chat_history[-1].role, "assistant")
	assert_eq(client.chat_history[-1].content, "Hi there!")


func test_multi_turn_conversation_is_chronological() -> void:
	client.chat_history.push_back({"role": "user", "content": "first message"})
	client.chat_history.push_back({"role": "assistant", "content": "first reply"})
	client.chat_history.push_back({"role": "user", "content": "second message"})

	assert_eq(client.chat_history.size(), 4)
	assert_eq(client.chat_history[0].role, "system")
	assert_eq(client.chat_history[1].content, "first message")
	assert_eq(client.chat_history[2].content, "first reply")
	assert_eq(client.chat_history[3].content, "second message")
