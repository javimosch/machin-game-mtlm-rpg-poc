#!/bin/sh
# Emberdeep showcase — fire a golden-path sequence of natural-language intents
# at the running game (default http://localhost:8460) and print the router's
# route + confidence for each. The watcher page shows the full narrative.
#   ./demo.sh            # against a running emberdeep
#   GAME=http://host:8460 ./demo.sh
GAME="${GAME:-http://localhost:8460}"
while IFS= read -r intent; do
    [ -z "$intent" ] && continue
    curl -s -m 15 -X POST "$GAME/act" -H 'content-type: application/json' \
        -d "{\"intent\":\"$intent\"}" | python3 -c "
import json,sys
r=json.load(sys.stdin)
print('» %-44s -> %-10s conf %s' % ('$intent', r.get('route','?'), r.get('conf','')))"
    sleep 0.4
done <<'EOF'
grab the torch from the wall
head north through the corridor
what do i see around me
check my inventory
keep going deeper into the dungeon
attack the goblin with my sword
swing at it once more
loot the body
check my health
drink the healing potion
ask the hermit about the relic
where am i
flee back toward the entrance
rest a while
whats the weather outside
EOF
