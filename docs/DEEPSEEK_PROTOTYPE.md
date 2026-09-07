# Celine Companion 0.1.0 — development prototype

## Run

Requires Python 3.10+, Project Zomboid B42.20+, a DeepSeek API key and internet access.
Use a new single-player test save. Multiplayer is disabled by the Lua entry point.

1. Copy `42/`, `common/` and root `mod.info` into your chosen PZ user directory's
   `mods/pz-companion-deepseek/` folder. Do not enable upstream `pz-companion` alongside it.
2. Start the runtime from this repository:

   ```powershell
   python runtime/deepseek.py --key-file "D:/path/to/private-key.txt" --pz-user-dir "D:/path/to/test-user-directory"
   ```

   The key file can contain a bare DeepSeek key or a labelled key. It must contain exactly
   one key; other text is never treated as instructions or sent to the model. Alternatively
   omit `--key-file` and supply `DEEPSEEK_API_KEY` in the process environment.
3. Start PZ with `-cachedir=` pointing to that **same** user directory. Enable
   **Celine Companion - DeepSeek Prototype**, then create a new solo test game.
4. Right-click the world and choose **Celine: Summon (experimental)**. If spawning succeeds,
   use **Celine: Chat / last reply**. The last reply appears in the next dialog and as speech.
5. Try `Đi theo anh nhé` then `Đứng chờ anh ở đây`. Direct Follow/Wait menu items
   do not call the API. Manual commands supersede any model action still waiting.
6. Stop the runtime with Ctrl+C when finished. It does not auto-start with Windows.

## Costs, memory and boundaries

Only submitted chat messages make API calls. Default session limit: 100 requests;
override with `--max-requests 20`, for example. The output cap is 320 tokens per call.
Input includes the system persona, up to six prior exchanges, current text, and
only the mode/proximity/game-hour fields. There is no background LLM reasoning.

Key contents are read directly into runtime memory, never copied into the mod, IPC,
SQLite, logs or Git. API requests go only to `https://api.deepseek.com/chat/completions`;
redirects are refused. The selected default model is `deepseek-v4-flash` with thinking disabled.

Conversation data stays in `<PZ-user-dir>/WHG_PZ_Companion/ipc/runtime/memory.sqlite`.
Recent conversation is transmitted to DeepSeek on the next message. Memory uses an ID
saved in the player's mod data, separating new characters/worlds. Six exchanges are kept
per companion, not unlimited autobiographical memory. Request receipts are retained to
prevent double billing after runtime restarts; these receipts also contain prior replies.
To clear all local memory, stop the runtime and remove `memory.sqlite` in this test directory.

The worker keeps API waits off the game thread. Lua gives up after 45 seconds, checks that
the same NPC is alive/nearby before applying an action, and rejects unsupported commands.
The runtime does not retry failed API calls or process old requests after startup.

## NPC limitations — must test in game

The actor uses vanilla `IsoSurvivor`, `SurvivorFactory`, and engine pathfinding. API signatures
were checked against the installed B42 game JAR, but signatures do not prove runtime behavior.
Spawning, models/animations, follow movement, waiting, unload/reload, and save persistence
have **not** passed an actual PZ playtest. No combat, inventory tasks, vehicles, remote
teleporting, or reliable companion death/persistence system is claimed. Follow falls back
to Wait when the player changes floors, enters a vehicle or gets more than 30 tiles away.

If the actor fails to spawn or move, report the first `[error]` stack trace from the test
directory's `console.txt`. Never send the private key file. This prototype does not modify
PZ JARs or install third-party NPC frameworks to hide engine limitations.

## Validation receipt — 2026-09-07

- `python -m unittest discover -s runtime -p test_deepseek.py -v`: 9 passed.
- `python -m unittest discover -s runtime/spike002/tests -v`: 7 passed.
- `lua tests/companion_contract.lua`: command allowlist, mode transition, correlation,
  NaN and response size checks passed, using engine test doubles.
- `luac -p` over all mod Lua files: passed.
- `python runtime/live_smoke.py --key-file <private-file>`: **two paid requests** passed.
  Real Lua transport wrote requests; the Python runtime called DeepSeek; Lua decoded,
  validated and acknowledged replies. First reply returned FOLLOW and remembered the
  base name; second returned WAIT and recalled `Đồi Thông`.
- The smoke check uses file-backed PZ I/O doubles, **not the PZ engine**. It proves the API
  and cross-language file contract, not NPC gameplay.

## Provenance

Fork base: upstream commit `0f99565a33e2d71d43f36bf332cbaf24d4fad8a4`.
New Python/Lua files are independently authored Apache-2.0 code. Existing upstream
LICENSE, NOTICE and asset restrictions are retained. No Willow Hill branding assets,
third-party NPC code or game assets are added. Upstream offline-only design documents
are historical; this fork explicitly opts into a cloud service at the owner's request.

API reference: [DeepSeek chat completions](https://api-docs.deepseek.com/api/create-chat-completion/),
[JSON output](https://api-docs.deepseek.com/guides/json_mode/).
