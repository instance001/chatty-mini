# Product Spec

## Summary

Chatty-mini is a portrait-first Android app for offline local chat with GGUF models.

It is not a desktop shell and it is not a module host. The product centers on one strong surface: a compact chat workspace supported by lightweight memory and sandbox tools.

## Terminology Boundary

`Hot Context`, `Rolling Summary`, `Cold Log`, `Bookkeeper`, `Main AI`, and
`capsule` are UX/product labels for local context surfaces, prompt/persona text,
and role-specific model lanes. They should stay friendly, but docs and UI must
not imply hidden model memory, personhood, autonomous agency, or unreviewed
state changes.

`safe` and `safer` in model-fit guidance mean lower risk of slow, unstable, or
failed generation on small phones. They are not safety certifications or content
policy guarantees.

## Product principles

- Chat is the main surface and should own most of the screen
- UI should feel practical, quiet, and mobile-native
- Small portrait phones are the design baseline, not an afterthought
- The app should prefer local-only behavior and clear privacy boundaries
- The user should be able to import GGUF files into private app storage with minimal fuss
- The native inference runtime should ship with the app bundle rather than depend on user-installed executable runtime files
- Advanced power-user controls should exist, but should not dominate the default UX

## v1 feature set

### Main chat screen

- Portrait-first layout
- Top utility bar with minimal chrome
- Scrollable chat transcript
- Bottom composer with send action
- Streaming response support
- Stop generation action while generating
- Clear conversation action

### Memory side bumps

Two collapsed edge controls live alongside the chat surface:

- `Hot Context`
- `Rolling Summary`

Behavior:

- Tap to expand
- Tap again to collapse
- If one is expanded, the other retracts
- Expanded panels overlay the chat surface instead of permanently reducing layout width
- Panels should be sized for small portrait screens and remain easy to dismiss

### Top utility bar

The top bar should stay conservative and small.

Controls:

- Sandbox tray
- Character / system prompt
- Model selector
- Settings
- Info / privacy

### Sandbox tray

The sandbox is a tightly scoped local text file tool, not a general file explorer.

Supported file types:

- `.md`
- `.txt`
- `.json`

Supported actions:

- Create file
- Open file
- Read/edit/save file
- Checkbox multi-select delete
- View files inside the sandbox scope only

### Prompt and character controls

The app should support:

- default system prompt
- named prompt capsules
- switching active prompt capsule
- editing and saving prompt capsules

### Model controls

The app should support separate role selection for:

- main AI
- bookkeeper

The UI should:

- scan available imported GGUF files in private app storage
- allow optional user-managed OpenAI, Anthropic, Gemini, xAI, DeepSeek, and custom OpenAI-compatible cloud model entries
- allow independent model selection per role
- expose conservative mobile presets
- allow advanced manual settings when needed

Cloud entries:

- appear in the same role selectors as local GGUF models
- require an explicit base URL, model name, and API key
- store API keys encrypted with Android Keystore
- must be verified before use
- never activate through automatic fallback

### Bookkeeper

The bookkeeper is a lightweight local summarizer and memory maintainer.

Responsibilities:

- update rolling summary
- maintain hot context support data
- stay cheaper and more conservative than the main AI profile

### First-run flow

On first launch, the app should:

1. Create app folders for models, sandbox, memory, config, and optional runtime metadata
2. Explain the local-only nature of the app
3. Explain that the native runtime is bundled with the app build
4. Prompt the user to import one or more GGUF models through the in-app picker
5. Offer a clear path into model selection

If no model is present after setup, the app should show a non-blocking empty-state notice in the main UI.

## Non-goals for v1

- Desktop module hosting
- Arbitrary filesystem browsing
- LAN peer discovery and transfer
- Full workflow bundle exchange
- Plugin ecosystem
- Multimodal support
- Downloaded executable runtime packages for the Play Store build

## Device target

Baseline target:

- small Android portrait phones
- Samsung A21s-class screens and memory constraints

## Data persistence

Planned app-scoped directories:

- `runtime/`
- `models/`
- `sandbox/`
- `memory/`
- `config/`

Notes:

- `runtime/` may still exist for metadata, diagnostics, or future support files
- executable native runtime code should ship inside the Android app bundle for the Play build

## Success criteria for v1

- App launches cleanly on a small portrait Android phone
- Bundled native runtime status is understandable
- User can import a GGUF into app storage and select it
- User can chat locally with minimal UI friction
- User can open and edit sandbox text files
- User can expand hot context or rolling summary without breaking the chat layout
- Main AI and bookkeeper can be configured separately
