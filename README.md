# mtlm-rpg — Emberdeep

A terminal RPG where **the player is an AI agent and the human only watches**.
Every player intent is classified by a self-hosted **mtlm-router** head
(`rpg.head`, trained on the frozen `m7router3s384` trunk) into one of 12 typed
actions — move, attack, flee, talk, inspect, loot, use_item, rest, inventory,
map, status, help — plus `escalate` for off-game nonsense and a low-confidence
abstain path. It's a dogfood of the "customer-specific route head, no fine-tune"
thesis: the game is just another tenant.

## Run

```sh
./build.sh                                    # needs machin on PATH
# a router instance serving rpg.head:
#   ANVIL_MODEL_ID=rpg-dm ANVIL_HEAD=out/rpg.head ANVIL_TOOLS_INJECT=0 \
#     ./anvil-serve-v6 models/m7router3s384.bin 8321
RPG_ROUTER=http://127.0.0.1:8321/v1/route ./bin/emberdeep
```

- Human watches: `http://localhost:8460` (auto-refreshing story log + hint box)
  or `tail` the process stdout.
- Agent plays: `GET /state` → `POST /act {"intent":"..."}` → repeat.
- Human opines: `POST /hint` (form field `text`) — lands in the story and the
  next `/state.hint`.
- Per-turn router telemetry (intent/route/conf/ms) appends to
  `/tmp/mtlm-rpg-turns.jsonl`.

## Layout

- `framework/machweb.src` — vendored HTTP framework (but the serve loop is a
  custom serial accept loop: handler-goroutine arenas corrupt cross-request
  state, and a single-player game doesn't need concurrency)
- `src/world.src` — the dungeon (rooms/exits/monsters/items/npcs, flat arrays)
- `src/game.src` — engine + intent router client + endpoints

## Gotcha that mattered

`machweb`'s `serve_router` runs each handler in a goroutine whose arena is freed
at request end — any computed string/slice stored in a global dangles. The game
sidesteps it entirely with a serial accept loop (see `main`): main-goroutine
arena never resets, so globals are just normal globals.
