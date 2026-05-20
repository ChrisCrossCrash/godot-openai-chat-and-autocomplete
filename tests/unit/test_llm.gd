extends GutTest

var LLMScript = preload("res://addons/copilot-advanced/LLM.gd")
var llm

func before_each():
	llm = LLMScript.new()
	add_child_autofree(llm)


func test_initial_chat_history_is_empty():
	assert_eq(llm.chat_history.size(), 0)


func test_clean_chat_resets_history():
	llm.chat_history.append("message")
	llm._clean_chat()
	assert_eq(llm.chat_history.size(), 0, "chat_history should be empty after _clean_chat")


func test_set_model_stores_name():
	llm._set_model("llama3")
	assert_eq(llm.model, "llama3")


func test_set_api_key_stores_key():
	llm._set_api_key("test-key-123")
	assert_eq(llm.api_key, "test-key-123")


func test_get_models_returns_empty_array():
	var models = llm._get_models()
	assert_typeof(models, TYPE_ARRAY)
	assert_eq(models.size(), 0)


func test_has_completion_received_signal():
	assert_has_signal(llm, "completion_received")


func test_has_chat_received_signal():
	assert_has_signal(llm, "chat_received")


func test_has_completion_error_signal():
	assert_has_signal(llm, "completion_error")
