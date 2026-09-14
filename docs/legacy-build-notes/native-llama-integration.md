# Native Llama Integration

## Purpose

This document tracks the current native `llama.cpp` integration shape for Chatty-mini.

The app now has:

- Flutter UI and storage scaffolding
- bundled runtime status
- model inventory
- JNI-backed local inference
- Android native build wiring for vendored `llama.cpp`

## Current recommendation

For a GGUF-first Android app, the practical path remains `llama.cpp` with:

- Android NDK build
- JNI bridge layer
- app-packaged native library inside the Android App Bundle
- Flutter method and event channels on top

Primary source references:

- [llama.cpp Android docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/android.md)
- [llama.cpp build docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md)
- [llama.cpp Snapdragon backend notes](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/snapdragon/README.md)

## Current integration shape

### Layer 1: Flutter

Flutter owns:

- chat UI
- model selection
- onboarding
- sandbox and memory surfaces
- generation lifecycle state

### Layer 2: Kotlin

Kotlin owns:

- method and event channels
- argument validation
- background threading
- cancellation requests
- relay back into Flutter

### Layer 3: C++ / JNI

C++ owns:

- llama backend initialization
- model load and unload
- prompt tokenization
- completion generation
- cancellation checks
- native resource cleanup

## Vendored upstream snapshot

Vendored path:

- `app/android/app/src/main/cpp/llama_upstream/`

Pinned upstream commit:

- `e3546c7948e3af463d0b401e6421d5a4c2faf565`

Bundling approach:

- `chatty_llama.so` is produced by our app build
- `llama.cpp` and `llama-common` are linked statically into that shared library
- unused upstream folders such as `examples/` and `tools/` are trimmed from the vendored copy

## Runtime contract

For the Play-facing build:

- native inference code ships inside the app bundle
- user-managed GGUF files remain data in the app-scoped `models/` directory
- the app-scoped `runtime/` folder is reserved for metadata or future support files, not downloaded executable code

Suggested runtime metadata fields:

```json
{
  "version": "llama-runtime-v1",
  "backend": "cpu",
  "abi": "arm64-v8a",
  "source": "packaged",
  "layout": "bundled-native"
}
```

## ABI policy

Preferred first-launch ABI policy:

- `arm64-v8a` first

Why:

- simpler packaging
- closer to the intended device class
- smaller native debugging surface

## JNI contract

Current JNI surface:

- `nativeGetEngineInfo()`
- `nativeLoadModel(modelPath, contextSize, gpuLayers)`
- `nativeBuildStubCompletion(modelPath, prompt)`
- `nativeRequestCancel()`
- `nativeUnloadModel()`

Notes:

- the native method name still includes `Stub` for continuity with the earlier scaffold
- it now performs real `llama.cpp` inference rather than fake text generation
- Flutter currently receives pseudo-streamed chunks from Kotlin after a native completion returns

## Generation lifecycle

### Load

1. Flutter selects a GGUF model.
2. Kotlin validates the app-private model path.
3. JNI loads the model and creates the llama context.
4. Kotlin reports ready or failed state back to Flutter.

### Generate

1. Flutter submits a user prompt.
2. Kotlin starts a background thread.
3. JNI runs a local completion against the loaded model.
4. Kotlin breaks the native response into small chunks and forwards them through the event channel.
5. Flutter renders an assistant draft.

### Cancel

1. Flutter sends a cancel request.
2. Kotlin marks the active request as cancelled.
3. JNI checks the native cancellation flag during generation.
4. The generation exits cleanly.

### Unload

1. Model switch or shutdown triggers unload.
2. JNI releases the sampler, context, batch, and model.

## Constraints for small phones

Default assumptions:

- CPU-first path before mobile GPU complexity
- conservative context size
- conservative generated-token count
- one active generation at a time

## Play Store implications

Important packaging note for Google Play:

- do not plan on downloading executable native code such as `.so` files after install
- package native runtime code inside the Android App Bundle
- treat post-install downloads as model or data delivery only

Relevant references:

- [About Android App Bundles](https://developer.android.com/guide/app-bundle)
- [Support 64-bit architectures](https://developer.android.com/google/play/requirements/64-bit)
- [Target API requirements](https://developer.android.com/google/play/requirements/target-sdk)
- [16 KB page size requirement](https://developer.android.com/guide/practices/page-sizes)
- [Device and Network Abuse policy note on downloading executable code](https://support.google.com/googleplay/android-developer/answer/16559646?hl=en)

## Current status

This phase is complete:

1. JNI and CMake skeleton are in place.
2. The app compiles a bundled native library.
3. Kotlin is wired to JNI methods.
4. Flutter can load a GGUF and trigger local generation.
5. `llama.cpp` is linked into the Android build instead of a fake native stub.

The next refinement is true token-by-token native streaming instead of chunking the fully generated response after native completion.
