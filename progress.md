# Development status

- [x] Fork upstream to khoyga007/pz-companion; clone to local workspace.
- [x] Implement DeepSeek runtime, bounded memory and validated FOLLOW/WAIT intent output.
- [x] Add experimental native NPC and PZ dialog integration.
- [x] Pass automated Python/Lua checks and two live API/file-transport round trips.
- [ ] Verify NPC spawn/rendering, chat UI and movement in an actual new solo test save.
- [ ] Verify actor save/reload, death and chunk-unload lifecycle before calling it playable.

## Shelved 2026-09-07 — companion body does not render

Yang paused the project here. Summon no longer throws; the actor spawns, is tagged,
speaks and updates, but is never drawn. The last run logged zero exceptions.

Fixed on the way (all in Companion.spawn, all verified against projectzomboid.jar 42.20.4):
- getObjectList() returns a Set in B42; iterate getObjectListForLua(), write to the Set.
- IsoSurvivor is a character-creation avatar only: no getVisual() override, no BodyDamage
  in its constructor. Replaced with IsoPlayer plus setNpc(true), which attaches the engine
  AIComponent. Argument order differs: IsoPlayer.new(cell, desc, x, y, z).
- The companion now shares the IsoPlayer class with real players, so the reuse loop tags
  the actor with CelineCompanionActor and skips the summoning player.
- setCurrent() only assigns a field; added setMovingSquareNow() so she joins the square's
  moving object list, the list the renderer walks.

Still unexplained, for whoever resumes: she is on the square's moving list, in the cell
object list, sceneCulled false, and nothing throws. Next suspects, none tested:
- The render pass may reach characters through IsoPlayer.players[]; the actor is in no slot
  and its playerIndex stays 0, since the constructor never touches players[] or numPlayers.
- The model may need an explicit ModelManager attach or a resetModel after dressing.
- Compare against a mod that renders a walking IsoPlayer NPC. BanditsWeekOne
  (workshop 3403180543) spawns one at BWOVehicles.lua:600 but deliberately sets it
  invisible, so it proves the constructor call and setNpc name only, not visibility.

Unrelated, cosmetic: Vietnamese text renders as '?'. media/fonts/Config_English.bmfc
declares chars=...,160-591,768-879,... and omits U+1E00-U+1EFF, where most precomposed
Vietnamese letters live. The font atlas lacks the glyphs; the encoding is fine.

No API credentials belong in this file or the repository. Current implementation and
test limitations are documented in docs/DEEPSEEK_PROTOTYPE.md.
