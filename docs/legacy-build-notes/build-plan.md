# Build Plan

## Goal

Continue shaping Chatty-mini into a Flutter-based Android app for local GGUF chat with minimal chrome, small-phone-first layout, lightweight memory supports, and a scoped sandbox tray.

## Working assumptions

- Flutter is the UI shell
- Android-native Kotlin code bridges into the GGUF runtime
- `llama.cpp` is the default v1 runtime path
- Storage is app-scoped by default
- Everything is optimized around portrait usage on small Android devices
- The current repository already contains a working prototype, so this plan should be read as a refinement roadmap rather than a greenfield checklist

## Milestone 1: Project foundation

Deliverables:

- initialize Flutter project
- define base app theme
- define feature folder structure
- add placeholder screens and routing
- define shared data models

Acceptance signals:

- app boots on Android
- top-level navigation surfaces exist
- no inference required yet

## Milestone 2: Core chat UI

Deliverables:

- main chat screen shell
- minimal top utility bar
- transcript list
- bottom composer
- stop button placeholder
- hot context bump
- rolling summary bump
- mutual expand/collapse behavior

Acceptance signals:

- layout remains usable on a small portrait screen
- memory panels do not permanently break chat width
- top chrome stays minimal

## Milestone 3: Local storage and sandbox

Deliverables:

- create app-scoped directories
- settings persistence
- sandbox file index
- create/open/edit/save/delete text files
- checkbox multi-select delete

Acceptance signals:

- sandbox stays scoped to its own folder
- text files can be edited end-to-end
- empty-state behavior is clean

## Milestone 4: Onboarding flow

Deliverables:

- detect first run
- create runtime/models/sandbox/memory/config folders
- present local-only explanation
- prompt for runtime auto-install accept/decline
- show GGUF placement instructions

Acceptance signals:

- first-run flow is understandable
- user can decline runtime auto-install without breaking the app
- no-model state is visible but non-blocking

## Milestone 5: Model management

Deliverables:

- scan `models/` for GGUF files
- display main AI selector
- display bookkeeper selector
- add preset profiles
- store role-specific model assignments

Acceptance signals:

- multiple GGUF files can be discovered
- main and bookkeeper selections are independent
- presets are usable without exposing too many controls

## Milestone 6: Native runtime bridge

Deliverables:

- Kotlin platform bridge skeleton
- runtime status checks
- install status reporting
- model load/unload bridge methods
- token streaming event pipeline

Acceptance signals:

- Flutter can request runtime status
- Flutter can receive streamed bridge events
- lifecycle methods are stable even before full inference works

## Milestone 7: Real GGUF inference

Deliverables:

- integrate app-compatible `llama.cpp` runtime path
- load selected GGUF
- run prompt generation
- stream tokens to chat UI
- cancel active generation
- expose clear failure states

Acceptance signals:

- at least one supported GGUF can run locally on target hardware
- transcript updates incrementally
- stop/cancel works reliably

## Milestone 8: Bookkeeper

Deliverables:

- rolling summary generation pass
- hot context persistence
- independent bookkeeper execution profile
- manual or automatic summary refresh triggers

Acceptance signals:

- summary stays short and readable
- bookkeeper does not overwhelm device constraints
- memory surfaces remain useful on small screens

## Milestone 9: Polish and hardening

Deliverables:

- small-screen UI tuning
- long transcript tuning
- clearer runtime errors
- reinstall runtime flow
- info/privacy copy
- edge-case cleanup

Acceptance signals:

- app feels stable on low-to-midrange phones
- empty states and failure states are understandable
- UX remains practical and uncluttered

## Suggested implementation structure

```text
app/
  lib/
    app/
    core/
      cockpit/
      runtime/
      settings/
      storage/
    features/
      chat/
      info/
      memory/
      models/
      onboarding/
      sandbox/
      settings/
    shared/
```

## Key risks

### Android runtime packaging

Biggest technical risk:

- shipping or installing a known-good native runtime package cleanly across device ABIs

### Small-device performance

Biggest UX risk:

- preserving a responsive chat experience on weaker phones with limited RAM and thermal headroom

### Storage UX

Biggest product risk:

- making model/runtime placement understandable without exposing desktop-style file complexity

## Scope discipline

To keep v1 healthy:

- do not add desktop modules
- do not add LAN sync
- do not add wide plugin abstractions
- do not let settings sprawl beyond what small-phone users can actually manage

## Immediate next build step

The project already has a Flutter shell, feature layout, storage scaffolding, and native bridge wiring.

The next code focus should be:

- tighten the prototype into a cleaner v1 surface
- verify which runtime flows are production-ready versus still prototype-grade
- harden onboarding, model import, and small-phone usability before adding more scope
