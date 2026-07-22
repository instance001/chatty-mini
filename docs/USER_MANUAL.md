# Chatty-mini User Manual

This manual assumes zero prior knowledge.

If you have never used a local model, never heard of GGUF, and do not know what a runtime is, this guide is for you.

## What Chatty-mini Is

Chatty-mini is an Android app that lets you chat with a language model stored on your own phone.

In simple terms:

- the app itself is the chat program
- the model is the "brain" file you import
- the runtime is the local engine that reads that model file
- no cloud AI account is required for local chatting inside this app
- optional cloud providers can be configured later if you choose that route

Chatty-mini is designed for small portrait phones, so most of the screen is reserved for chat.

## What "Local" Means

When Chatty-mini says it is local, it means the model runs on your device instead of being sent to an online AI service.

That usually means:

- better privacy
- offline use is possible
- speed depends on your phone
- larger models may be slow or may fail on low-memory devices

Local is the baseline, not a lock-in. If you configure a cloud provider, Chatty-mini treats that as a deliberate lane choice for that request.

## What a GGUF File Is

A `GGUF` file is a model file.

You can think of it like:

- a game ROM for an emulator
- a document file for a word processor
- a music file for a player

Chatty-mini cannot chat without at least one GGUF model file being imported.

## What the Runtime Is

The runtime is the native local engine that loads and runs the GGUF model.

In Chatty-mini, the runtime is bundled with the app build. That means you do not normally need to manually install a separate runtime after install.

## First-Time Setup

After installing the app:

1. Open Chatty-mini.
2. Confirm the app shows that storage and runtime are ready.
3. Open the model inventory from the top bar.
4. Import one or more `.gguf` files using Android's file picker.
5. Assign a model to `Main AI`.
6. Optionally assign a model to `Bookkeeper`.
7. Return to the main screen and start chatting.

## Main Screen Overview

The main screen is intentionally simple.

### Header

The top bar contains buttons for:

- Sandbox tray
- Character prompt / persona tray
- Model inventory
- Settings area
- App info / memory area

### Status Strip

This is the short line near the top showing compact state such as:

- local mode
- ready state
- current preset
- active persona

### Runtime Health Row

This is the compact row that summarizes whether the app is ready and how suitable the current model is for the device.

Tap it to open detailed runtime information.

### Chat Area

This is the main conversation window.

The newest streamed text should stay near the composer as replies arrive.

### Composer

This is where you type your message and send it to the local model.

### Hot Context And Rolling Summary

The left `Hot Context` bump and right `Summary` bump are live memory panels.

They read from private memory files:

- `hot_context.md`
- `rolling_summary.md`

Open the Cold Log / memory tray to edit those files. Changes are reflected in the side bump displays and included in the local generation prompt.

## Importing a Model

To import a GGUF:

1. Tap the model button in the top bar.
2. Tap `Import GGUF`.
3. Android will open its file picker.
4. Choose a `.gguf` file.
5. Wait for the import to complete.
6. Assign that imported model to `Main AI`.

Important:

- imported models are copied into private app storage
- they are not meant to be browsed directly through hidden Android app folders
- import and deletion are handled inside Chatty-mini

## Choosing Main AI and Bookkeeper

Chatty-mini supports two logical roles:

### Main AI

This is the model used for the main conversation.

If you only use one model, this is the most important assignment.

### Bookkeeper

This is a lighter support role meant for recap / memory-oriented tasks.

You can assign:

- the same model as Main AI
- a different smaller model
- no separate model if you are not using that workflow yet

## Understanding Model Health

The app checks how realistic the current model choice is for a small phone.

You may see labels like:

- `Reasonable`
- `Caution`
- `High Risk`

These do not mean the model is bad.

They mean:

- how heavy the model is for your device memory
- how risky loading/generation may be
- whether a smaller model would likely be safer

If you see `High Risk`, the model may still import, but load/generation can become slow, unstable, or fail on your phone.

## Character Prompt Profiles

Character profiles are saved personas or system prompts.

They let you tell the model how to behave before your message is even considered.

Examples:

- practical coding assistant
- story co-writer
- blunt editor
- research summarizer
- bookkeeping persona

### What They Do

The active character prompt is automatically inserted into the generation prompt before your user message.

That means the active persona can change:

- tone
- style
- priorities
- response structure

### How to Use Them

1. Tap the face / character button in the top bar.
2. Create a new profile or edit an existing one.
3. Give it a name.
4. Write the system prompt text.
5. Save it.
6. Mark it active if desired.

The active profile is saved across app restarts.

### Duplicate, Export, and Import

You can:

- duplicate a profile
- export one profile
- export all profiles
- import profile packs from sandbox JSON files

Exports go into the sandbox as JSON so they can be managed in-app.

## Sandbox Tray

The sandbox is a simple local text-file workspace inside the app.

It supports:

- `.md`
- `.txt`
- `.json`

You can use it for:

- notes
- scratch drafting
- JSON task state
- structured local working files

### What You Can Do in the Sandbox

- create files
- open files
- edit files
- save files
- select files
- delete files

## Deterministic Sandbox Task Mode

This is the composer option called `Sandbox task`.

It exists so the model does not need to guess whether your next prompt is meant to affect a sandbox file.

When enabled, Chatty-mini explicitly tells the model that the next request is related to sandbox file work.

### Modes

#### Target

Use this when your next request is about an existing sandbox file.

Example:

- "Rewrite this note into a cleaner checklist."
- "Update the JSON with today's date."
- "Summarize this markdown into a short status note."

When `Target` mode is selected, Chatty-mini also includes the current contents of the chosen file in the prompt context.

#### New File

Use this when you want the next request to create or populate a new sandbox file.

Example:

- "Create a meeting notes template."
- "Draft a changelog file."
- "Make a JSON starter for a task queue."

### How to Use Sandbox Task Mode

1. In the composer area, turn on `Sandbox task`.
2. Choose `Target` or `New file`.
3. If using `Target`, choose the existing sandbox file.
4. If using `New file`, enter the new file name.
5. Type your prompt.
6. Send it.

This does not automatically save the model's reply into the sandbox by itself.

It tells the model that your next message is specifically about sandbox file content or file editing intent.

## Hot Context and Summary Side Rails

These are the side bumps on the chat screen.

They can expand one at a time.

### Hot Context

This is short working memory for the active task.

Think of it as:

- current aim
- constraints
- immediate context

### Rolling Summary

This is a shorter recap area that can help keep an evolving task understandable over time.

## Cold Log and Session Logs

Chatty-mini also includes longer-lived memory/log areas.

### Cold Log

Cold log files are persistent memory files stored inside the app.

You can:

- open them
- edit them
- clear contents
- delete them

### Session Logging

Session logging stores raw conversation logs locally inside app storage when enabled.

You can configure:

- whether logging is on
- how many recent logs to keep
- clearing all session logs

## Runtime Details Sheet

Tap the runtime health row on the main screen to open runtime details.

This sheet shows:

- runtime state
- packaging mode
- version
- backend
- RAM and free memory
- model fit assessment
- active character prompt
- selected model
- refresh control

This keeps the main screen clean while still making the diagnostics available when needed.

## Tips for Small Phones

- Prefer smaller GGUF models first.
- Treat `High Risk` model health as a warning, not a challenge.
- Keep prompts concise when testing a new model.
- Use tighter presets if memory is limited.
- Import only the models you actually want to keep.
- Delete old models inside the app so storage does not get crowded.

## If the App Feels Slow

Possible reasons:

- the model is too large for the phone
- Android is low on free memory
- the preset is too ambitious
- too many background apps are open

What to try:

1. Close other apps.
2. Use a smaller GGUF.
3. Use a tighter preset.
4. Refresh the runtime.
5. Reopen the app if Android became memory-tight.

## If a Model Imports But Chats Poorly

That can happen even if import succeeds.

Import success only means the file was copied into app storage. It does not guarantee:

- good speed
- good quality
- stable generation
- enough device memory

Try:

- a different preset
- a smaller model
- a different quantization

## Common Terms

### Local inference

The model runs on your device.

### Runtime

The engine that loads and runs the model.

### GGUF

The model file format used by this app.

### Preset

A saved bundle of generation settings such as token limit, temperature, and context.

### Persona / character prompt

A saved system prompt describing how the model should behave.

### Sandbox

A private in-app workspace for lightweight text and JSON files.

## Privacy Expectations

Chatty-mini is built around local-first behavior, but you should still treat your device as the trust boundary.

That means:

- imported models live on the device
- sandbox files live on the device
- memory/log files live on the device
- chats are intended to stay local in this app flow
- cloud providers receive content only when you choose a configured cloud model for the request

You should still use normal device hygiene:

- lock your phone
- be careful with exported sandbox files
- avoid storing sensitive material casually if others share the device

## Very Short Version

If you want the shortest possible onboarding:

1. Open the app.
2. Import a `.gguf`.
3. Assign it to `Main AI`.
4. Check the runtime row says things look ready enough.
5. Type a message.
6. Chat.

If you want more control:

- set a character prompt
- use sandbox task mode
- manage logs and sandbox files from the trays
