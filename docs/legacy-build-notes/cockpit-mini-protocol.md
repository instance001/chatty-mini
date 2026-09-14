# Cockpit Mini Protocol

## Purpose

Cockpit Mini is the internal event and state contract for Chatty-mini.

Its job is to keep the app's moving pieces predictable without recreating the heavier desktop-era protocol surface.

This protocol is internal-first in v1. It is not a LAN sync protocol, not a plugin API, and not a public extension contract.

Terminology boundary: protocol `memory`, `models`, `privacy`, and `trust`
domains are app-state domains. They do not imply hidden model memory,
surveillance, guaranteed privacy, or a security certification. Network use must
remain explicit through selected cloud model entries.

## Design goals

- Keep app state observable
- Keep runtime and UI boundaries clean
- Support Flutter-to-native coordination
- Make status, diagnostics, and error handling easier
- Stay small enough to evolve during implementation and prototype hardening

## State domains

### `app`

App-level status:

- first run state
- onboarding completion
- current app version
- local-only mode flags

### `runtime`

Runtime status:

- missing
- bundled-check
- ready
- failed

Fields:

- runtime version
- install mode
- active backend info if available
- last runtime error

### `models`

Model inventory and selection:

- discovered models
- selected main AI model
- selected bookkeeper model
- last scan time
- scan errors

### `chat`

Chat execution state:

- idle
- preparing
- generating
- cancelling
- completed
- failed

Fields:

- active conversation id
- active request id
- token stream status
- last generation error

### `memory`

Memory state:

- hot context entries
- rolling summary text
- last bookkeeper run
- memory update status

### `sandbox`

Sandbox state:

- file index
- active open file
- editor dirty state
- last sandbox error

### `settings`

Configuration state:

- generation presets
- active prompt capsule
- advanced overrides

### `privacy`

Privacy and trust surface:

- local-only notice accepted
- bundled runtime status acknowledged
- external network usage state

## Event naming

Events should use lower-case dotted strings.

Examples:

- `app.first_run_detected`
- `app.onboarding_completed`
- `runtime.status_checked`
- `runtime.ready_confirmed`
- `runtime.health_warning`
- `runtime.failed`
- `models.scan_requested`
- `models.scan_completed`
- `models.selection_changed`
- `chat.request_started`
- `chat.stream_token`
- `chat.request_completed`
- `chat.request_cancelled`
- `chat.request_failed`
- `memory.hot_context_updated`
- `memory.summary_refresh_requested`
- `memory.summary_updated`
- `sandbox.file_created`
- `sandbox.file_opened`
- `sandbox.file_saved`
- `sandbox.file_deleted`
- `settings.prompt_capsule_changed`

## Suggested state shapes

These are conceptual shapes, not locked implementation classes.

### Runtime status

```json
{
  "state": "ready",
  "version": "app-compatible-runtime-v1",
  "installMode": "bundled",
  "backend": "cpu",
  "message": "Runtime ready."
}
```

### Model record

```json
{
  "id": "tinyllama-q4",
  "fileName": "tinyllama-1.1b-chat-v1-q4.gguf",
  "fullPath": "/models/tinyllama-1.1b-chat-v1-q4.gguf",
  "architecture": "llama",
  "sizeBytes": 734003200
}
```

### Chat request status

```json
{
  "conversationId": "conv_001",
  "requestId": "req_014",
  "state": "generating",
  "selectedMainModelId": "tinyllama-q4"
}
```

### Sandbox editor state

```json
{
  "relativePath": "notes/today.md",
  "isDirty": true,
  "fileType": "markdown"
}
```

## Flutter and native bridge contract

The Flutter layer should communicate with a narrow native bridge rather than embedding runtime assumptions across the UI.

Suggested native bridge capabilities:

- `getRuntimeStatus`
- `scanModels`
- `loadModel`
- `startGeneration`
- `cancelGeneration`
- `runBookkeeperSummary`
- `unloadModel`

Suggested streamed events back into Flutter:

- `models.scan.completed`
- `chat.stream_token`
- `chat.request_completed`
- `chat.request_failed`
- `bookkeeper.summary_completed`

## Guardrails

- Do not let this grow into a network protocol in v1
- Do not use it as a justification for premature abstraction
- Prefer explicit typed models over loose dynamic maps where practical
- Keep fields small and purpose-specific

## v1 rule of thumb

If a state change affects:

- onboarding
- runtime readiness
- model selection
- generation lifecycle
- memory lifecycle
- sandbox file lifecycle

it likely deserves a cockpit event or state update.
