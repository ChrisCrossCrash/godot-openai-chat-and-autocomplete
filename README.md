# Godot Copilot Selfhost (Based on https://github.com/minosvasilias/godot-copilot)

![Godot Copilot Selfhost logo](public_assets/logo500.png)

AI-assisted development for the Godot engine.

Compatible with `4.x`.
### What does this do?

Godot Copilot uses multiple AI providers including Gemini, Ollama, and LM Studio to retrieve AI-generated code completions. You can choose to run models locally (Ollama, LM Studio) or use cloud-based APIs (Gemini).

After installing the plugin, simply press the selected keyboard shortcut to generate code in the code editor at the current caret position, directly within the engine!

### Check out my profile and the tutorial page for more information!

- [Profile](https://tnl.one/s/drakonkat)
- [Tutorial](https://tnl.one/s/gdcopilot)


### How do I install this?

Follow these steps:
- Search for "Copilot selfhost" in the Godot asset library directly within the engine. Download the addon and enable in the project settings. (To be added)
- You may also clone this repository and copy the `copilot-advanced` addon into the `res://addons` directory of your project

Afterwards, enable the addon in the project settings, and enter your API key in the `Copilot selfhost` tab located on the right-hand dock:
- For Gemini: Get your API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
- For Ollama: No API key needed, just install and run Ollama locally
- For LM Studio: No API key needed, just [install](https://lmstudio.ai/) and configure a server to run models locally

Use the selected keyboard shortcut within the code editor to request completions.

If you have difficulties, please follow the [tutorial](https://tnl.one/s/gdcopilot) linked above or open an [issue](https://github.com/drakonkat/godot-copilot-selfhost/issues).

### How much will this cost me?

- **Free options**:
  - [Ollama](https://ollama.ai/) - Run open-source models locally
  - [LM Studio](https://lmstudio.ai/) - Configure a server to run models locally

- **Freemium options**:
  - [Gemini](https://aistudio.google.com) Check [Google AI pricing](https://ai.google.dev/pricing) for the latest rates

For each request, Copilot will attempt to send your entire current script to the model, up to a maximum length, after which the code will be trimmed.

Being a good engineer that doesn't work in 5k-line spaghetti-scripts pays. Literally!


### Does this share sensitive data?

This depends on which provider you choose:

- **Ollama & LM Studio**: No data is shared with any third party as everything is processed locally on your machine.
- **Gemini**: Refer to [Google's AI privacy policies](https://policies.google.com/) for the latest information on how they handle your data.


### Which models are suggested?

For local deployment:
- **Ollama**: Llama 3 is a good starting point for most users
- **LM Studio**: CodeLlama and similar coding-focused models perform well

For cloud-based APIs:
- **Gemini**: Good with the flash API you have like 3000 request for day

If you have better suggestions for specific models that work well with GDScript, please open an issue.

### Is there a guide to install the local providers?

- **LM Studio**: Visit my [tutorial](https://scribehow.com/page/How_to_configure_LM_studio_server_for_godot__GLMaYLu9SyaOMrMEkuYxVQ?referrer=documents).
- **Ollama**: Visit [ollama.ai](https://ollama.ai/) for installation instructions for your operating system.
