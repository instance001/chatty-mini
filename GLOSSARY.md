# Glossary (Repo Excerpt)

For the full glossary, see: https://github.com/instance001/Whatisthisgithub/blob/main/GLOSSARY.md

This file contains only the glossary entries for this repository. Mapping tag legends and global notes live in the full glossary.

## chatty-mini
| Term | Alternate term(s) | Alt map | External map | Relation to existing terminology | What it is | What it is not | Source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Chatty-mini | chatty-mini | = | ~ | Local-first, cloud-optional Android GGUF chat app | Portrait-first Android Flutter app for local GGUF chat on small phones, with optional user-configured cloud providers, private app storage, personas, sandbox files, and memory side rails | Not a cloud-required chatbot; not an account service; not a desktop-first dashboard; not tied to one model provider | chatty-mini/README.md; chatty-mini/docs/USER_MANUAL.md |
| Bundled runtime | native runtime | ~ | ~ | Packaged local inference engine | Native local engine bundled with the app build to load and run imported GGUF models without a separate manual runtime install | Not a cloud service; not a model file itself | chatty-mini/README.md; chatty-mini/docs/USER_MANUAL.md |
| Model inventory | imported model library | ~ | ~ | In-app GGUF management surface | App surface for importing GGUF files through Android's picker, storing them in private app storage, and assigning them to roles | Not direct browsing of hidden Android folders; not a bundled model catalog | chatty-mini/README.md; chatty-mini/docs/USER_MANUAL.md |
| Main AI | main model role | ~ | ~ | Primary generation role | Model assignment used for the main conversation when chatting locally | Not the Bookkeeper role; not automatically cloud-backed | chatty-mini/docs/USER_MANUAL.md |
| Bookkeeper | support model role | ~ | ~ | Recap/memory support role | Optional lighter role intended for recap or memory-oriented support tasks | Not the primary conversation model; not required for first use | chatty-mini/README.md; chatty-mini/docs/USER_MANUAL.md |
| Hot Context and Rolling Summary side rails | Hot Context, Summary bump | ~ | ~ | Visible compact memory panels | Side panels backed by private memory files such as `hot_context.md` and `rolling_summary.md` to keep active task context and recap close to the chat surface | Not full transcript storage; not cloud memory | chatty-mini/README.md; chatty-mini/docs/USER_MANUAL.md |
| Sandbox tray | sandbox | ~ | ~ | Private in-app file workspace | Local workspace for lightweight `.md`, `.txt`, and `.json` files that can be opened, edited, exported, and used in sandbox task mode | Not unrestricted filesystem access; not automatic external storage sync | chatty-mini/README.md; chatty-mini/docs/USER_MANUAL.md |
| Sandbox task mode | sandbox task | = | ~ | File-intent composer mode | Composer mode that marks the next message as specifically about sandbox file content or file editing intent | Not an automatic save operation; not normal chat mode | chatty-mini/README.md; chatty-mini/docs/USER_MANUAL.md |
| Model health assessment | Reasonable, Caution, High Risk | ~ | ~ | Small-phone fit heuristic | Runtime health signal estimating whether the selected model is realistic for available device memory and phone constraints | Not a quality score; not a guarantee that generation will succeed | chatty-mini/README.md; chatty-mini/docs/USER_MANUAL.md |
| Character prompt profiles | persona profiles | ~ | ~ | Saved system prompt layer | Saved personas or system prompts that can be activated, duplicated, exported, imported, and inserted before user messages | Not fine-tuning; not separate model weights | chatty-mini/README.md; chatty-mini/docs/USER_MANUAL.md |
