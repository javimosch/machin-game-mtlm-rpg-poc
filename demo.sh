#!/bin/sh
set -eu
GAME="${GAME:-http://localhost:8460}"
post() {
    intent="$1"
    body=$(python3 -c 'import json,sys; print(json.dumps({"intent":sys.argv[1]}))' "$intent")
    response=$(curl -fsS -m 20 -X POST "$GAME/act" -H 'content-type: application/json' -d "$body")
    python3 -c 'import json,sys; r=json.loads(sys.argv[2]); s=r.get("state",{}); print("» %-38s → %-9s HP %s/%s · %-16s · %s"%(sys.argv[1],r.get("route","restart"),s.get("hp","?"),s.get("maxhp","?"),s.get("room",""),s.get("objective","")))' "$intent" "$response"
    sleep 0.15
}
post "restart"
while IFS= read -r intent; do
    [ -z "$intent" ] || post "$intent"
done <<'EOF'
take the torch
light the torch
go north
go east to the armory
take the rusty sword
equip the rusty sword
head west
west to the shrine
take the healing potion
speak with the hermit
east to the corridor
north into the goblin den
attack the goblin
attack the goblin
attack the goblin
attack the goblin
loot the iron key
north to the flooded cellar
east into the crypt
attack the skeleton
attack the skeleton
attack the skeleton
attack the skeleton
attack the skeleton
north across the bridge
north into the vault
take the steel sword
equip the steel sword
north into the dragon's lair
drink the healing potion
attack the dragon
attack the dragon
attack the dragon
attack the dragon
attack the dragon
loot the dragon amulet
south to the vault
south across the bridge
south into the crypt
west into the cellar
south through the goblin den
south to the dark corridor
south into the entrance hall
EOF
curl -fsS -m 5 "$GAME/state" | python3 -c 'import json,sys; s=json.load(sys.stdin); print("Outcome:",s["outcome"],"—",s["phase"],"—",s["room"]); print("Final objective:",s["objective"]); sys.exit(0 if s["outcome"]=="won" else 1)'
