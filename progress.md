# Development status

- [x] Fork upstream to khoyga007/pz-companion; clone to local workspace.
- [x] Implement DeepSeek runtime, bounded memory and validated FOLLOW/WAIT intent output.
- [x] Add experimental native NPC and PZ dialog integration.
- [x] Pass automated Python/Lua checks and two live API/file-transport round trips.
- [ ] Verify NPC spawn/rendering, chat UI and movement in an actual new solo test save.
- [ ] Verify actor save/reload, death and chunk-unload lifecycle before calling it playable.

No API credentials belong in this file or the repository. Current implementation and
test limitations are documented in docs/DEEPSEEK_PROTOTYPE.md.
