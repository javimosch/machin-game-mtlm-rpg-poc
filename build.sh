#!/bin/sh
# mtlm-rpg — agent-played dungeon that routes every intent through mtlm-router.
set -e
cd "$(dirname "$0")"
mkdir -p bin
machin encode framework/machweb.src src/world.src src/game.src > emberdeep.mfl
machin build emberdeep.mfl -o bin/emberdeep
echo "built bin/emberdeep"
echo "run:  RPG_ROUTER=http://127.0.0.1:8321/v1/route ./bin/emberdeep   (watch: http://localhost:8460)"
