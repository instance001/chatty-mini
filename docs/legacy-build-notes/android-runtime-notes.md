# Android Runtime Notes

## Recommended v1 runtime path

For Chatty-mini v1, the recommended inference direction is:

- Flutter UI
- Kotlin native bridge on Android
- bundled native runtime inside the Android app
- `llama.cpp` as the GGUF runtime path

## Why this changed

For a Google Play-oriented app, packaged native runtime code is a cleaner direction than asking users to download executable runtime files after install.

That means:

- ship native code in the app bundle
- treat GGUF models as user-managed data
- avoid runtime-code path fragility and policy risk from downloaded executable code

## Why `llama.cpp`

The app's product promise is:

- import a GGUF through the app with low user fuss
- keep user fuss low
- avoid requiring model conversion before use

That still makes `llama.cpp` the most practical default fit for v1.

## First-run runtime UX

Suggested flow:

1. Explain that the app runs locally on-device
2. Explain that the native runtime is already bundled with the app build
3. Show runtime readiness status
4. Prompt for GGUF import through the in-app picker
5. Offer model selection

## Runtime responsibilities

The native runtime layer should own:

- native library loading
- model loading
- prompt execution
- token streaming
- cancellation
- model unload
- native error translation into user-facing statuses

## Packaging direction

For the Play Store build:

- native runtime code should ship in the Android App Bundle
- user-downloaded models remain data, not executable code
- ABI scope should stay intentionally narrow at first, ideally `arm64-v8a`

## Practical caution

Android local inference is still the hardest technical part of this app.

The UI and storage work are much easier by comparison.
