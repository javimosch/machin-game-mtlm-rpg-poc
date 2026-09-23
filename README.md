# machin-game-mtlm-rpg-poc — Emberdeep

**POOC** — A terminal RPG where **the player is an AI agent and the human only watches**.
Every player intent is classified by a self-hosted **mtlm-router** head
(`rpg.head`, trained on the frozen `m7router3s384` trunk) into one of 12 typed
actions — move, attack, flee, talk, inspect, loot, use_item, rest, inventory,
map, status, help — plus `escalate` for off-game nonsense and a low-confidence
abstain path.

It's a dogfood of the "customer-specific route head, no per-customer fine-tune"
thesis: the game is just another tenant with its own head on the frozen trunk.

**What this demonstrates:**
- Typed routing with confidence calibration and abstention
- Customer-specific heads on a shared frozen trunk
- Real playthroughs producing router-miss data for head iteration
- Pure MFL runtime (no Go/Rust/Python in the game binary)

**What this does NOT demonstrate:**
- Game design is basic (10 rooms, hardcoded combat, simple balance)
- No persistence, no save/load, no procedural generation
- Router is not authoritative yet (55% agreement on first head, rpg2 improves misses)

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

See [`machin-learn/.agents/skills/mfl-gotchas/SKILL.md`](https://github.com/javimosch/machin-learn/blob/master/.agents/skills/mfl-gotchas/SKILL.md#25-machweb-handler-globals-dangle---serial-accept-loop-for-stateful-servers)
for the full documented lesson.

## Dogfood results

First playthrough (rpg v1):
- 134 turns, dragon slain
- Router misses that cost the run: `equip the sword` → loot @0.73 (never equipped → low attack → died)
- Average router latency: 374ms over SSH tunnel
- Corpus feedback → rpg2.head fixed: `light the torch`, `take the dragon amulet`, `head east`
- Regression: `what is my hp` → escalate @1.0 (meta corpus poisoned in-game status queries)

The game is winnable with the current head; misses are recoverable via the low-confidence abstention path.
