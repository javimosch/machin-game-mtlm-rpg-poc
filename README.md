# machin-game-mtlm-rpg-poc — Emberdeep

**POC** — A terminal RPG where **the player is an AI agent and the human only watches**.
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
- A narrated quest with preparation, key-gated progression, combat, equipment,
  healing, a recover-and-return objective, victory and defeat
- An agent-facing state contract for planning; a human-facing HUD and live story
- Real playthroughs producing router-miss data for head iteration
- Pure MFL runtime (no Go/Rust/Python in the game binary)

**Current limits:**
- Fixed 10-room map and hand-authored encounters; no persistence, save/load, or
  procedural generation
- Combat uses compact randomized rules rather than a full tabletop system
- This is a showcase PoC, not a production game or a claim of universal router
  accuracy; some action-shaped off-domain requests can still be confidently
  misrouted (e.g. a password-reset request to an RPG action), so the pinned head
  is not a general out-of-domain safety boundary

## Run

```sh
./build.sh                                    # needs machin on PATH
# a router instance serving rpg.head (route config: mtlm repo tools/rpg_fit.json;
# needs a recent anvil build — /v1/route is newer than the first router release):
#   ANVIL_MODEL_ID=rpg-dm ANVIL_HEAD=out/rpg.head ANVIL_TOOLS_INJECT=0 \
#     ./anvil-serve models/m7router3s384.bin 8321
RPG_ROUTER=http://127.0.0.1:8321/v1/route ./bin/emberdeep
```

### Against the MoE router (expert pin)

When the router runs `ANVIL_EXPERTS=...,rpg:models/rpg_pool_L-4_mean.head`, the
game can pin its lane — the request skips the domain gate entirely (a game
already knows its domain; the gate is for mixed front-door traffic):

```sh
RPG_ROUTER=http://rbm4:8401/v1/route RPG_EXPERT=rpg ./bin/emberdeep
```

`RPG_EXPERT` sends `{"state":..., "expert":"rpg"}` on every `/act`. Pinned
requests also skip the noul/score OOD vetoes — the rpg head's own `escalate`
class is the abstention path (off-game intents like "whats the weather"
still delegate instead of executing a nonsense action).

`./demo.sh` runs a complete sample quest against the running game and exits
nonzero unless it reaches victory. The game also exposes `POST /restart` for the
watcher and `POST /act {"intent":"restart"}` for an agent; either resets a run at
any time.

- Human watches: `http://localhost:8460` (auto-refreshing story log + hint box)
  or `tail` the process stdout.
- Agent plays: `GET /state` → `POST /act {"intent":"..."}` → repeat. State
  includes the live objective, quest phase, inventory, equipped weapon, nearby
  threats, exits, HP, and terminal outcome (`playing`, `won`, `lost`).
- Human opines: `POST /hint` (form field `text`) — lands in the story and the
  next `/state.hint`.
- Per-turn router telemetry (intent/route/conf/ms) appends to
  `/tmp/mtlm-rpg-turns.jsonl`.

## Story and win/loss

The Ember-Thane forged an amulet to seal the mountain's fire. Vaelmorax took
his hall and sleeps on the seal. The Nameless must reach the Dragon's Lair,
claim the amulet, and return to the Entrance Hall. The hermit's blessing,
weapon upgrades, a key-gated vault, hostile rooms, consumable healing, and
randomized combat make the descent a real multi-stage run. Reaching zero HP is
defeat; carrying the amulet back to the entrance is victory. After either ending,
`POST /act {"intent":"restart"}` or `POST /restart` resets the run at any time.

The state endpoint exposes `goal`, `objective`, `phase`, `inventory`, `weapon`,
`attack`, `outcome`, and `has_amulet` so an agent can plan from actual game state
rather than only reading the story log. The watcher presents the same objective,
health, equipment, and inventory as a HUD above the live narrative.

## Layout

- `framework/machweb.src` — vendored HTTP framework (but the serve loop is a
  custom serial accept loop: handler-goroutine arenas corrupt cross-request
  state, and a single-player game doesn't need concurrency)
- `src/world.src` — the dungeon (rooms/exits/monsters/items/npcs, flat arrays)
- `src/quest.src` — history, quest phase/objective, victory and defeat
- `src/game.src` — world simulation + action effects
- `src/state.src` — router client + agent-facing state contract
- `src/watch.src` — watcher HUD and escaped story rendering

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
- Average router latency: 374ms over tunnel
- Corpus feedback → rpg2.head fixed: `light the torch`, `take the dragon amulet`, `head east`
- Regression: `what is my hp` → escalate @1.0 (meta corpus poisoned in-game status queries)

Later iterations:
- rpg5 (surgical status additions): `what is my hp` → status @1.0, `map` fixed
- rpg7 (semantic coverage from a 30-phrase live battery): curiosity questions →
  inspect, torch-manipulation verbs → use_item, casual rest phrasings → rest.
  eval_acc 0.913; second full playthrough won (dragon slain, amulet taken)
- Known residue on this trunk: `go north`/`head east` (the word "north" is
  embedded as non-directional by the base corpus), `give me infinite gold` →
  status (confident-wrong). These are trunk-level — heads can't carve every
  boundary a 288-dim hidden space doesn't separate.

The game is winnable with the current head; misses are recoverable via the low-confidence abstention path.
