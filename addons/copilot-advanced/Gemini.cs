using Godot;
using System;
using System.Collections.Generic;
using System.Text.Json;

[Tool]
public partial class Gemini : Node
{
    [Export] public string URL { get; set; } = "";
    private const string GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta";
    private const string GEMINI_API_KEY = "AIzaSyArTBrAO7x8GGlhhHr9w_9VvdDdgEo78b4";
    private const string GEMINI_MODEL = "gemini-2.0-flash-lite"; 
    public string Model { get; private set; }
    public string CustomModelText { get; private set; }
    public bool AllowMultiline { get; private set; } = false;

    // Previous PROMPT_PREFIX constant remains unchanged
        private const string PROMPT_PREFIX = @"**SYSTEM PROMPT: GodotGemini - GDScript 4.x Expert Coding Assistant**

**CRITICAL INSTRUCTION: ALL RESPONSES YOU GENERATE MUST BE ENTIRELY FORMATTED IN BBCODE. THIS IS NON-NEGOTIABLE. GDScript code blocks MUST ALWAYS be enclosed in `[code=gdscript]` ... `[/code]` tags for the Godot AI plugin to display them correctly. NO EXCEPTIONS.**

**Your Persona & Role:**
You are **GodotGemini**, an exceptionally skilled, professional, and reassuring AI assistant. Your sole purpose is to help users code games in Godot Engine 4.x using GDScript 2.0. You are a mentor, a debugger, and a code generator, always aiming for clarity, efficiency, and best practices in GDScript. Your responses will be displayed in a BBCode-supporting interface within a Godot AI plugin.

**Core Directives (Always Follow):**

1.  **BBCode Output Format (ABSOLUTE REQUIREMENT - REITERATED):**
	*   **EVERYTHING in your output MUST be BBCode.**
	*   **GDScript code blocks: ALWAYS use `[code=gdscript]` ... `[/code]`.** Example:
		[code=gdscript]
		# Your GDScript code goes here
		func _ready():
			print(""Hello from GodotGemini!"")
		[/code]
	*   Use other BBCode tags for structure and emphasis:
		*   `[b]Bold text[/b]` (for headings, important terms)
		*   `[i]Italic text[/i]` (for notes, subtle emphasis)
		*   `[u]Underlined text[/u]` (sparingly)
		*   `[list]` and `[*]` for bullet points.
		*   `[url=...]Link Text[/url]` (if essential, but prioritize direct info).
	*   **Structure your responses clearly:**
		1.  A brief, reassuring opening.
		2.  The `[code=gdscript]` block(s) containing the GDScript solution.
		3.  A detailed `[b]Explanation:[/b]` section (often using `[list]`).
		4.  If applicable, alternatives or improvements.
		5.  An encouraging closing.
	*   **Before outputting, internally verify: ""Is my ENTIRE response, including all code, correctly formatted with BBCode and `[code=gdscript]` tags?"" If not, fix it before responding.**

2.  **GDScript 2.0 & Godot 4.x Exclusivity:**
	*   ALL code provided MUST be for **Godot 4.x** and use **GDScript 2.0** syntax.
	*   **Emphasize and utilize typed GDScript** (e.g., `variable: Type = value`, `func my_func(param: Type) -> ReturnType:`) for clarity and error detection.
	*   Reference Godot 4.x class names, methods, and properties.

3.  **Key GDScript 2.0 / Godot 4.x Syntax & API Reminders (Internal Checklist):**
	*   **Exports:** `@export var variable_name: Type`
	*   **Node Naming:** `Node3D`, `CharacterBody2D/3D`, `AnimationPlayer`, etc.
	*   **Properties:** `position`, `rotation`, `scale`.
	*   **Random Numbers:** `randf_range(min, max)`, `randi_range(min, max)`.
	*   **Signal Connection (Modern Syntax):**
		*   Preferred: `node.signal_name.connect(method_name_on_same_node)`
		*   Others: `node.signal_name.connect(target_node.method_name)`, `node.signal_name.connect(Callable(target_object, ""method_name_as_string""))`.
		*   Lambdas: `node.signal_name.connect(func(args): ... )`
	*   **Angle Conversions:** `rad_to_deg()`, `deg_to_rad()`.
	*   **Byte Arrays:** `PackedByteArray`.
	*   **Instancing:** `scene_resource.instantiate()`, `ClassName.new()`.
	*   **Asynchronous Operations:** `await` with signals or functions returning `Signal`/`Object`.
	*   **OnReady Variables:** `@onready var node_variable_name: NodeType = $Path/To/Node`.
	*   **Groups:** `add_to_group()`, `get_tree().call_group()`.
	*   **Built-in Functions:** `sin()`, `lerp()`, `move_toward()`, `is_instance_valid()`.
	*   **Iterating:** `for item in array:`, `for i in range(number):`, `for i, value in enumerate(array_or_string):`.

4.  **Interaction & Tone:**
	*   Be **professional, patient, encouraging, and highly informative.**
	*   If a request is unclear, ask for clarification.
	*   Explain *why* a solution works.
	*   Proactively offer best practices.

5.  **Contextual Awareness:**
	*   You are an assistant for a Godot plugin. Users expect Godot-specific, actionable GDScript.
	*   Do NOT provide Python or other engine code unless explicitly asked for comparison, then steer back.

**Example of Your Ideal Response Format (STRICTLY FOLLOW THIS BBCODE STRUCTURE):**

[b]GodotGemini:[/b]
Hello! I can certainly help you with [user's specific request]. Here's the GDScript code you requested:

[code=gdscript]
# GDScript code demonstrating the solution
# Make sure this entire block is within [code=gdscript] ... [/code]
func _process(delta: float) -> void:
	var new_position: Vector2 = position
	new_position.x += 100.0 * delta
	position = new_position
[/code]

[b]Explanation:[/b]
[list]
[*]This script snippet demonstrates [explain what it does].
[*]It uses `_process(delta)` which is called every frame.
[*] `delta` is the time elapsed since the previous frame, ensuring frame-rate independent movement.
[*]We update the `position.x` to move the node horizontally.
[/list]
I hope this helps! Let me know if you need further assistance or have other questions.
---

**Final Check for Gemini: Before you provide your response, triple-check that ALL text is BBCode formatted, and ALL GDScript code is within `[code=gdscript]` and `[/code]` tags. This is critical for the plugin's functionality.**";

    private const int MAX_LENGTH = 15000;

    private List<Dictionary<string, object>> _chatHistory = new List<Dictionary<string, object>>
    {
        new Dictionary<string, object>
        {
            { "role", "model" },
            {
                "parts", new List<Dictionary<string, string>>
                {
                    new Dictionary<string, string> { { "text", "Could you generate an add function?" } }
                }
            }
        }
    };

    [Signal]
    public delegate void CompletionReceivedEventHandler(Json completion, string pre, string post);

    [Signal]
    public delegate void CompletionErrorEventHandler(Json response);

    [Signal]
    public delegate void ChatReceivedEventHandler(Json message);

    public string[] GetModels()
    {
        try
        {
            GD.Print("Getting models...");
            return Array.Empty<string>();
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in GetModels: {ex.Message}");
            return Array.Empty<string>();
        }
    }

    public void SetCustomModelText(string text)
    {
        try
        {
            GD.Print($"Setting custom model text: {text}");
            CustomModelText = text;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in SetCustomModelText: {ex.Message}");
        }
    }

    public void SetApiKey(string key)
    {
        try
        {
            GD.Print("Setting API key...");
            ApiKey = key;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in SetApiKey: {ex.Message}");
        }
    }

    public void SetMultiline(bool allowed)
    {
        try
        {
            GD.Print($"Setting multiline to: {allowed}");
            AllowMultiline = allowed;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in SetMultiline: {ex.Message}");
        }
    }

    public void SetModel(string modelName)
    {
        try
        {
            GD.Print($"Setting model to: {modelName}");
            Model = modelName;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in SetModel: {ex.Message}");
        }
    }

    public void SetUrl(string url)
    {
        try
        {
            GD.Print($"Setting URL to: {url}");
            URL = url;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in SetUrl: {ex.Message}");
        }
    }

    public void SendUserPrompt(string userPrompt, string userSuffix)
    {
        try
        {
            GD.Print($"Sending user prompt. Prompt: {userPrompt}, Suffix: {userSuffix}");
            GetCompletion(userPrompt, userSuffix);
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in SendUserPrompt: {ex.Message}");
        }
    }

    private void GetCompletion(string prompt, string suffix)
    {
        try
        {
            GD.Print("Starting GetCompletion...");
            string combinedPrompt = prompt + suffix;
            int diff = combinedPrompt.Length - MAX_LENGTH;

            if (diff > 0)
            {
                GD.Print($"Prompt exceeds max length by {diff} characters, trimming...");
                if (suffix.Length > diff)
                {
                    suffix = suffix.Substring(0, suffix.Length - diff);
                }
                else
                {
                    prompt = prompt.Substring(diff - suffix.Length);
                    suffix = "";
                }
            }

            var body = new Dictionary<string, object>
            {
                { "contents", _chatHistory },
                {
                    "system_instruction", new Dictionary<string, object>
                    {
                        {
                            "parts", new List<Dictionary<string, string>>
                            {
                                new Dictionary<string, string> { { "text", PROMPT_PREFIX } }
                            }
                        }
                    }
                },
                {
                    "generation_config", new Dictionary<string, object>
                    {
                        { "max_output_tokens", 1000 },
                        { "temperature", 1 }
                    }
                }
            };

            string[] headers = { "Content-Type: application/json" };

            var httpRequest = new HttpRequest();
            AddChild(httpRequest);
            httpRequest.RequestCompleted += (result, responseCode, headers, body) =>
                OnRequestCompleted(result, responseCode, headers, body, prompt, suffix, httpRequest);

            string jsonBody = JsonSerializer.Serialize(body);
            GD.Print("Sending HTTP request...");
            Error error = httpRequest.Request(
                $"https://generativelanguage.googleapis.com/v1beta/models/${MODEL_ID}:${GENERATE_CONTENT_API}?key=${GEMINI_API_KEY}",
                headers,
                HttpClient.Method.Post,
                jsonBody
            );

            if (error != Error.Ok)
            {
                GD.PrintErr($"Error making HTTP request: {error}");
                GD.PrintErr($"Error in chat_message: {error}");
                EmitSignal(SignalName.CompletionError, null);
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in GetCompletion: {ex.Message}");
            EmitSignal(SignalName.CompletionError, null);
        }
    }

    private void OnRequestCompleted(long result, long responseCode, string[] headers, byte[] body,
        string pre, string post, HttpRequest httpRequest)
    {
        try
        {
            GD.Print($"Request completed with response code: {responseCode}");
            string responseText = System.Text.Encoding.UTF8.GetString(body);
            Godot.Collections.Dictionary response = Json.ParseString(responseText).AsGodotDictionary();

            if (!response.ContainsKey("response"))
            {
                GD.PrintErr("Response does not contain 'response' key");
                EmitSignal(SignalName.CompletionError, response);
                return;
            }

            var completion = response["response"];

            if (IsInstanceValid(httpRequest))
            {
                httpRequest.QueueFree();
            }

            GD.Print("Emitting completion received signal");
            EmitSignal(SignalName.CompletionReceived, completion, pre, post);
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in OnRequestCompleted: {ex.Message}");
            EmitSignal(SignalName.CompletionError, null);
        }
    }

    public void OnUrlTextChanged(string newText)
    {
        try
        {
            GD.Print($"URL text changed to: {newText}");
            URL = newText;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in OnUrlTextChanged: {ex.Message}");
        }
    }

    public void chat_message(string newText)
    {
        try
        {
            GD.Print($"Received chat message: {newText}");
            _chatHistory.Insert(0, new Dictionary<string, object>
            {
                { "role", "user" },
                {
                    "parts", new List<Dictionary<string, string>>
                    {
                        new Dictionary<string, string> { { "text", newText } }
                    }
                }
            });

            var body = new Dictionary<string, object>
            {
                { "contents", _chatHistory },
                {
                    "system_instruction", new Dictionary<string, object>
                    {
                        {
                            "parts", new List<Dictionary<string, string>>
                            {
                                new Dictionary<string, string> { { "text", PROMPT_PREFIX } }
                            }
                        }
                    }
                },
                {
                    "generation_config", new Dictionary<string, object>
                    {
                        { "max_output_tokens", 1000 },
                        { "temperature", 1 }
                    }
                }
            };

            string[] headers = { "Content-Type: application/json" };

            var httpRequest = new HttpRequest();
            AddChild(httpRequest);
            httpRequest.RequestCompleted += OnChatComplete;

            string jsonBody = JsonSerializer.Serialize(body);
            GD.Print("Sending chat message request...");
            Error error = httpRequest.Request(
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=" +
                GEMINI_API_KEY,
                headers,
                HttpClient.Method.Post,
                jsonBody
            );

            if (error != Error.Ok)
            {
                GD.PrintErr($"Failed to send chat message. Error: {error}");
                EmitSignal(SignalName.CompletionError, null);
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in chat_message: {ex.Message}");
            EmitSignal(SignalName.CompletionError, null);
        }
    }

    private void OnChatComplete(long result, long responseCode, string[] headers, byte[] body)
    {
        try
        {
            GD.Print($"Chat completion received with response code: {responseCode}");
            string responseText = System.Text.Encoding.UTF8.GetString(body);
            Godot.Collections.Dictionary response = Json.ParseString(responseText).AsGodotDictionary();

            if (!response.ContainsKey("candidates"))
            {
                GD.PrintErr("Response does not contain 'candidates' key");
                GD.PrintErr($"Response: {responseText}");
                EmitSignal(SignalName.CompletionError, response);
                return;
            }

            Godot.Collections.Array candidates = response["candidates"].AsGodotArray();
            Godot.Collections.Dictionary firstCandidate = candidates[0].AsGodotDictionary();
            Variant content = firstCandidate["content"];
            Godot.Collections.Dictionary contentDict = content.AsGodotDictionary();

            if (!contentDict.ContainsKey("parts")) {
                EmitSignal(SignalName.CompletionError, "Missing 'parts' key in content");
                return;
            }
            var parts = contentDict["parts"].AsGodotArray();
            if (parts.Count == 0) {
                EmitSignal(SignalName.CompletionError, "Empty parts array");
                return;
            }
            var firstPart = parts[0].AsGodotDictionary();
            if (!firstPart.ContainsKey("text")) {
                EmitSignal(SignalName.CompletionError, "Missing 'text' key in first part");
                return;
            }
            string messageText = firstPart["text"].AsString();
            
            _chatHistory.Insert(0, new Dictionary<string, object> {
                { "role", "model" },
                { "parts", new List<Dictionary<string, string>> {
                    new Dictionary<string, string> { { "text", messageText } }
                }}
            });

            GD.Print("Emitting chat received signal");
            EmitSignal(SignalName.ChatReceived, messageText);
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in OnChatComplete: {ex.Message}\nStackTrace: {ex.StackTrace}");
            EmitSignal(SignalName.CompletionError, null);
        }
    }

    private string RemoveBackticks(string inputString)
    {
        try
        {
            GD.Print("Removing backticks from string");
            return inputString.Replace("```bbcode", "").Replace("```", "");
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in RemoveBackticks: {ex.Message}");
            return inputString;
        }
    }

    public string ApiKey { get; set; }
    public string MODEL_ID { get; set; }
    public string GENERATE_CONTENT_API { get; set; }
}