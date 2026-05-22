# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot OpenAI Chat and Autocomplete is a Godot 4.x editor addon that provides AI-assisted code completions and chat directly within the Godot editor. It uses LM Studio (or any OpenAI-compatible local server) as its backend.

To develop: open the project in Godot 4.6+, then enable the addon in **Project Settings > Plugins > "Godot OpenAI Chat and Autocomplete"**. No build step is needed for GDScript changes. Restart the editor after modifying [plugin.gd](addons/godot-openai/plugin.gd) or [ai_panel.tscn](addons/godot-openai/ai_panel.tscn).

## Testing

Tests use **GUT (Godot Unit Testing)**, installed as `addons/gut`. Test files live in `tests/` and must be named `test_*.gd`.

**Run tests inside the editor**: open the GUT panel (bottom dock) and click **Run All** or **Run at Cursor**.

**Run tests from the command line** (headless):
```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

**Write a new test file**:
```gdscript
extends GutTest

func before_each():
	# setup per-test state

func test_something():
	assert_eq(actual, expected)
```

GUT configuration (search dirs, prefix/suffix) is in [.gut_editor_config.json](.gut_editor_config.json).

## Architecture

The addon lives entirely in [addons/godot-openai/](addons/godot-openai/) and communicates with any OpenAI-compatible local server (e.g. LM Studio) via its `/v1/chat/completions` endpoint.

### Entry Points

- [plugin.gd](addons/godot-openai/plugin.gd) — `EditorPlugin` entry point. Loads `ai_panel.tscn` as a dock and connects `main_screen_changed`.
- [ai_panel.gd](addons/godot-openai/ai_panel.gd) — Main UI controller. Orchestrates all completion/chat flows, manages settings, and handles keyboard shortcuts.
- [openai_client.gd](addons/godot-openai/openai_client.gd) — Handles all HTTP communication. Emits `completion_received(text, pre, post)`, `chat_received(text)`, `completion_error(error)`, and `models_received(model_ids)` signals back to `ai_panel.gd`. Instantiated via [openai_client.tscn](addons/godot-openai/openai_client.tscn), which provides three pre-created `HTTPRequest` child nodes.

### Signal Connections

`completion_received`, `chat_received`, and `completion_error` from [openai_client.gd](addons/godot-openai/openai_client.gd) are connected to their handlers in `ai_panel.gd` via **`ai_panel.tscn`**. `models_received` is connected in code in `ai_panel._ready()`. The three internal `HTTPRequest` signals are connected in `openai_client._ready()`.

### Completion Data Flow

```
User presses shortcut (default Alt+C / Cmd+C)
  → ai_panel.gd::_request_completion()
  → _get_pre_post() splits code at caret → [pre, post]
  → _get_openai_client() returns openai_client
  → openai_client.send_user_prompt(pre, post)
  → HTTP response → completion_received signal
  → ai_panel._on_code_completion_received()
  → _insert_completion() writes code, highlights new lines
  → TAB accepts, BACKSPACE reverts, any other key accepts silently
```

### Chat Data Flow

```
User types message and clicks Send
  → ai_panel._on_send_chat_message_pressed()
  → _get_openai_client().chat_message(text)
  → HTTP response → chat_received signal
  → ai_panel._on_chat_received()
  → _bot_message() appends RichTextLabel to chat container
```

The Clear button calls `clean_chat()`, which resets `chat_history` and re-injects the system prompt.

### Fill-in-the-Middle Strategy

LM Studio uses a system prompt (`COMPLETION_SYSTEM`) plus a user message with an `!INSERT_CODE_HERE!` marker between prefix and suffix, sent to `/v1/chat/completions`.

### Key Behaviors

- **Code trimming**: Prompts are capped at `MAX_LENGTH` (~15000 chars); suffix is trimmed first.
- **`@tool` annotation**: All scripts run inside the editor, not at game runtime.
- **Encrypted config**: Settings are stored via `ConfigFile.save_encrypted_pass()` at `user://godot-openai.cfg`. The passphrase is hardcoded in `ai_panel.gd::PREFERENCES_PASS`.
- **URL not persisted**: The server URL is **not** saved to config. It defaults to `http://127.0.0.1:1234` on each load.
- **Platform shortcuts**: Modifier keys differ on macOS (Cmd/Option) vs Windows/Linux (Ctrl/Alt). `_is_mac()` checks `OS.get_name() == "macOS"`.

### System Prompts

[openai_client.gd](addons/godot-openai/openai_client.gd) contains system prompt constants (`COMPLETION_SYSTEM` for completions, `CHAT_PREFIX` for chat). All prompts instruct the model to:
- Output only code (no explanations in completion mode)
- Use GDScript 2.0 typed syntax targeting Godot 4.x APIs (`Node3D`, `instantiate()`, `@export`, `@onready`)

### Debugging

- Console output (`Output` panel) logs request/response details via `print_rich()`.
- System prompts and HTTP status codes are printed on each request.
- Encrypted config values can be inspected by temporarily printing them in `_load_config()`.


## Code Style

### Indentation

Use **tabs** for indentation. Never use spaces.

### Line Length

Aim for a soft maximum of **80 characters** per line. Exceeding it occasionally is fine — don't contort code to fit — but long lines should be the exception.

### Multi-line Function Signatures

When a function signature doesn't fit on one line, put each parameter on its own line indented one tab, and place the closing `) -> ReturnType:` at zero indent (same level as `func`):

```gdscript
func _on_request_completed(
	_result: int,
	_response_code: int,
	body: PackedByteArray,
	pre: String
) -> void:
```

### Type Hints

Always annotate variable declarations and function signatures with type hints. Prefer explicit types over `Variant`.

For variables, use `:=` to infer the type from the assigned value rather than spelling it out explicitly. Always annotate function return types and parameters.

```gdscript
# Good
var speed := 5.0
func get_label() -> String:

# Avoid
var speed = 5.0
func get_label():
```

Use an explicit type annotation when inference would produce a broader type than intended — for example, `instantiate()` returns `Node`, so the specific type must be declared manually:

```gdscript
var player: CharacterBody2D = player_scene.instantiate()
```

### Comments

Comment **sparingly**. Comments should answer *why*, not *what* — the code itself should make the what obvious.

```gdscript
# Good: explains a non-obvious decision
# Slight delay prevents physics body from sleeping before impulse registers
await get_tree().physics_frame

# Avoid: restates what the code already says
# Set speed to 5
speed = 5.0
```

Use `##` documentation comments when it would be useful to surface information as a tooltip in the editor — on a class, an exported variable, or any method where the name and signature alone don't tell the full story. Omit them where the implementation is self-evident.

```gdscript
## The maximum speed the player can reach, in units per second.
@export var max_speed: float = 10.0
```

### Node Ordering Conventions

Follow Godot's recommended declaration order within a class:

1. `class_name`
2. `extends`
3. `## Class-level doc comment`
4. Signals
5. Enums
6. Constants
7. `@export` variables
8. Public variables
9. Private variables (prefix with `_`)
10. `@onready` variables
11. Built-in virtual methods (`_ready`, `_process`, `_physics_process`, etc.)
12. Public methods
13. Private methods (prefix with `_`)
14. Inner classes (`class InnerName:`)

---

## Example File

```gdscript
class_name ItemSlot
extends Node3D
## Represents a single slot in the player's physical inventory space.
## Tracks occupancy and exposes methods for placing and removing items.

signal item_placed(item: RigidBody3D)
signal item_removed(item: RigidBody3D)

enum SlotState {
	EMPTY,
	OCCUPIED,
	RESERVED,
}

const SNAP_DISTANCE: float = 0.25

## Whether this slot accepts items automatically from the conveyor.
@export var auto_accept: bool = false

## The item category this slot is restricted to, if any.
@export var filter_category: String = ""

var state := SlotState.EMPTY

var _current_item: RigidBody3D = null
var _snap_tween: Tween = null

@onready var _collision_area: Area3D = $CollisionArea
@onready var _highlight_mesh: MeshInstance3D = $HighlightMesh


func _ready() -> void:
	_collision_area.body_entered.connect(_on_body_entered)
	_highlight_mesh.visible = false


func _physics_process(_delta: float) -> void:
	if state == SlotState.RESERVED and _current_item == null:
		# Reservation timed out externally — clean up so the slot doesn't stay locked.
		state = SlotState.EMPTY


## Places an item into this slot, snapping it into position.
## Returns false if the slot is already occupied or the item is filtered out.
func place_item(item: RigidBody3D) -> bool:
	if state != SlotState.EMPTY:
		return false
	if not _passes_filter(item):
		return false

	_current_item = item
	state = SlotState.OCCUPIED
	_snap_item_to_position(item)
	item_placed.emit(item)
	return true


## Removes and returns the current item, leaving the slot empty.
## Returns null if the slot is already empty.
func remove_item() -> RigidBody3D:
	if state == SlotState.EMPTY:
		return null

	var item := _current_item
	_current_item = null
	state = SlotState.EMPTY
	item_removed.emit(item)
	return item


## Returns true if the item is allowed in this slot.[br]
## An empty [member filter_category] means all items are accepted.
## Otherwise, the item must have a matching "category" meta value.
func _passes_filter(item: RigidBody3D) -> bool:
	if filter_category.is_empty():
		return true
	return item.get_meta("category", "") == filter_category


## Temporarily freezes the item's physics body and tweens it to this slot's position.[br]
## Physics is re-enabled after the tween completes so the solver doesn't fight the animation.
func _snap_item_to_position(item: RigidBody3D) -> void:
	# Disable physics influence during snap so the tween isn't fought by the solver.
	item.freeze = true

	_snap_tween = create_tween()
	_snap_tween.tween_property(item, "global_position", global_position, 0.1)
	await _snap_tween.finished

	item.freeze = false


## Shows the highlight mesh when a physics body enters the collision area.[br]
## The highlight is hidden again by [method place_item] once an item is accepted.
func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and state == SlotState.EMPTY:
		_highlight_mesh.visible = true
```
