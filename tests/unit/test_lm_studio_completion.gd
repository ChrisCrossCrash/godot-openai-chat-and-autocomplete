extends GutTest

var LmStudioCompletionScript = preload("res://addons/copilot-advanced/LmStudioCompletion.gd")
var lm

func before_each():
	lm = LmStudioCompletionScript.new()
	add_child_autofree(lm)
	lm._clean_chat()


func test_clean_chat_puts_system_message_first():
	assert_eq(lm.chat_history[0].role, "system")


func test_user_message_is_appended_to_end():
	lm._append_to_history({"role": "user", "content": "Hello!"})
	assert_eq(lm.chat_history[-1].role, "user")
	assert_eq(lm.chat_history[-1].content, "Hello!")


func test_assistant_reply_is_appended_to_end():
	lm._append_to_history({"role": "user", "content": "Hello!"})
	lm._append_to_history({"role": "assistant", "content": "Hi there!"})
	assert_eq(lm.chat_history[-1].role, "assistant")
	assert_eq(lm.chat_history[-1].content, "Hi there!")


func test_multi_turn_conversation_is_chronological():
	lm._append_to_history({"role": "user", "content": "first message"})
	lm._append_to_history({"role": "assistant", "content": "first reply"})
	lm._append_to_history({"role": "user", "content": "second message"})

	assert_eq(lm.chat_history.size(), 4)
	assert_eq(lm.chat_history[0].role, "system")
	assert_eq(lm.chat_history[1].content, "first message")
	assert_eq(lm.chat_history[2].content, "first reply")
	assert_eq(lm.chat_history[3].content, "second message")
