# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot Copilot Selfhost is a Godot 4.x editor addon that provides AI-assisted code completions and chat directly within the Godot editor. It supports multiple LLM providers: Ollama (local), LM Studio (local), Google Gemini (cloud), and OpenAI-compatible APIs.

To develop: open the project in Godot 4.6+, then enable the addon in **Project Settings > Plugins > "Copilot selfhost"**. No build step is needed for GDScript changes. Restart the editor after modifying [Plugin.gd](addons/copilot-advanced/Plugin.gd) or [CopilotUI.tscn](addons/copilot-advanced/CopilotUI.tscn).

## Architecture

The addon lives entirely in [addons/copilot-advanced/](addons/copilot-advanced/) and follows a provider-based design with signal-driven communication.

### Entry Points

- [Plugin.gd](addons/copilot-advanced/Plugin.gd) — `EditorPlugin` entry point. Loads `CopilotUI.tscn` as a dock and connects `main_screen_changed`.
- [Copilot.gd](addons/copilot-advanced/Copilot.gd) — Main UI controller. Orchestrates all completion/chat flows, manages settings, and handles keyboard shortcuts.

### Provider System

[LLM.gd](addons/copilot-advanced/LLM.gd) is the abstract base class all providers extend. Each provider:
1. Implements `_send_user_prompt(pre, post)` and `_set_model(model_name)`
2. Makes an HTTP request to its API endpoint
3. Emits `completion_received(completion_text, pre, post)` on success

| File | Provider | Endpoints |
|------|----------|-----------|
| [OllamaCompletion.gd](addons/copilot-advanced/OllamaCompletion.gd) | Ollama | `/api/generate`, `/api/chat` |
| [LmStudioCompletion.gd](addons/copilot-advanced/LmStudioCompletion.gd) | LM Studio | `/v1/completions`, `/v1/chat/completions` |
| [GeminiCompletion.gd](addons/copilot-advanced/GeminiCompletion.gd) | Google Gemini | `generativelanguage.googleapis.com/v1beta` |
| [OpenAIChat.gd](addons/copilot-advanced/OpenAIChat.gd) | OpenAI-compatible | `/v1/chat/completions` |
| [GithubCopilot.gd](addons/copilot-advanced/GithubCopilot.gd) | GitHub Copilot | legacy, not wired into the dropdown |

**Important**: `OpenAIChat.gd` exists but is **not currently wired** into `get_llm()` in `Copilot.gd` — the provider dropdown only maps indices 0=Ollama, 1=LmStudio, 2=Gemini.

### Signal Connections

Provider signals (`completion_received`, `chat_received`, `completion_error`) are connected to their handlers in `Copilot.gd` via **`CopilotUI.tscn`**, not in code. When adding a new provider node to the scene tree, wire its signals there.

### Completion Data Flow

```
User presses shortcut (default Alt+C / Cmd+C)
  → Copilot.gd::request_completion()
  → get_pre_post() splits code at caret → [pre, post]
  → get_llm() selects active provider (0=Ollama, 1=LmStudio, 2=Gemini)
  → provider._send_user_prompt(pre, post)
  → HTTP response → completion_received signal
  → Copilot._on_code_completion_received()
  → insert_completion() writes code, highlights new lines
  → TAB accepts, BACKSPACE reverts, any other key accepts silently
```

### Chat Data Flow

```
User types message and clicks Send
  → Copilot._on_send_chat_message_pressed()
  → get_llm().chat_message(text)
  → HTTP response → chat_received signal
  → Copilot._on_lm_studio_completion_chat_received()
  → _botMessage() appends RichTextLabel to chat container
```

Switching providers calls `_clean_chat()` on the previously active provider, which resets `chat_history` and re-injects the system prompt.

### Fill-in-the-Middle Strategies

Each provider uses a different approach to indicate the insertion point:

| Provider | Strategy |
|----------|----------|
| Ollama | `##<GEMINI_COMPLETE_HERE>##` marker concatenated between prefix and suffix |
| LM Studio | `PROMPT_PREFIX` prepended; native FIM via `prompt`+`suffix` fields |
| Gemini | `##<GEMINI_COMPLETE_HERE>##` marker in `contents`, system prompt via `system_instruction` |
| OpenAI | `!INSERT_CODE_HERE!` marker inserted between prefix and suffix |

### Key Behaviors

- **Code trimming**: Prompts are capped at `MAX_LENGTH` (~15000 chars); suffix is trimmed first.
- **`@tool` annotation**: All scripts run inside the editor, not at game runtime.
- **Encrypted config**: Settings (including API keys) are stored via `ConfigFile.save_encrypted_pass()` at `user://copilot-advanced.cfg`. The passphrase is hardcoded in `Copilot.gd::PREFERENCES_PASS`.
- **URL not persisted**: The provider base URL is **not** saved to config. It resets to the default (`localhost:11434` for Ollama, `127.0.0.1:1234` for LM Studio) whenever the provider dropdown changes.
- **Platform shortcuts**: Modifier keys differ on macOS (Cmd/Option) vs Windows/Linux (Ctrl/Alt). `is_mac()` checks `OS.get_name() == "macOS"`.

### Adding a New Provider

1. Create a script extending `LLM.gd`.
2. Implement `_send_user_prompt(pre, post)`, `_set_model(model_name)`, and optionally `_get_models()` and `chat_message(text)`.
3. Emit `completion_received(text, pre, post)` on success; emit `completion_error(error)` on failure.
4. Add the node to `CopilotUI.tscn` under the `LLMs` node and connect its signals to `Copilot.gd` handlers there.
5. Register it in `Copilot.gd::get_llm()` with the next dropdown index and add it to the provider `OptionButton` in `CopilotUI.tscn`.

### System Prompts

Each provider file contains its own system prompt constants (`PROMPT_PREFIX`, `FILL_IN_THE_MIDDLE`, `SYSTEM_TEMPLATE`). All prompts instruct the model to:
- Output only code (no explanations in completion mode)
- Use GDScript 2.0 typed syntax targeting Godot 4.x APIs (`Node3D`, `instantiate()`, `@export`, `@onready`)

### Debugging

- Console output (`Output` panel) logs request/response details via `print_rich()`.
- System prompts and HTTP status codes are printed on each request.
- Encrypted config values can be inspected by temporarily printing them in `load_config()`.
