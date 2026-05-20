# Godot Copilot Selfhost (Based on https://github.com/minosvasilias/godot-copilot)

![Godot Copilot Selfhost logo](public_assets/logo500.png)

AI-assisted development for the Godot engine.

Compatible with `4.x`.

### What does this do?

Godot Copilot uses LM Studio (or any OpenAI-compatible local server) to retrieve AI-generated code completions. Run models locally with zero data sent to third parties.

After installing the plugin, simply press the selected keyboard shortcut to generate code in the code editor at the current caret position, directly within the engine!

### How do I install this?

Clone this repository and copy the `copilot-advanced` addon into the `res://addons` directory of your project

Afterwards, enable the addon in the project settings. No API key is needed — just [install LM Studio](https://lmstudio.ai/), load a model, and start the local server. The `Copilot` tab on the right-hand dock lets you set the server URL and pick a model.

Use the selected keyboard shortcut within the code editor to request completions.

### How much will this cost me?

Everything runs locally for free via [LM Studio](https://lmstudio.ai/). No cloud accounts or API keys required.

For each request, Copilot will attempt to send your entire current script to the model, up to a maximum length, after which the code will be trimmed.

Being a good engineer that doesn't work in 5k-line spaghetti-scripts pays. Literally!

### Does this share sensitive data?

No. All processing happens locally on your machine via LM Studio. No data is sent to any third party.
