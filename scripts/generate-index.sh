#!/bin/bash
set -euo pipefail

GAMES_DIR="${1:-games}"
OUTPUT_DIR="${2:-dist}"
TEMPLATE="landing/index.html"
CARDS_FILE=$(mktemp)

for game_dir in "$GAMES_DIR"/*/; do
    [ -d "$game_dir" ] || continue
    [ -f "$game_dir/main.lua" ] || continue

    slug=$(basename "$game_dir")

    # Try to extract title from conf.lua
    title=""
    if [ -f "$game_dir/conf.lua" ]; then
        title=$(grep 't\.title' "$game_dir/conf.lua" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' || true)
    fi

    # Fallback: prettify the directory name
    if [ -z "$title" ]; then
        title="$slug"
    fi

    first_letter=$(echo "$title" | cut -c1 | tr '[:lower:]' '[:upper:]')

    cat >> "$CARDS_FILE" <<CARD
            <a href="./games/$slug/" class="game-card"><div class="game-icon">$first_letter</div><h2>$title</h2><p>Click to play</p></a>
CARD
done

if [ ! -s "$CARDS_FILE" ]; then
    echo '            <p style="color:#8888aa">No games found yet. Add a game to the games/ directory!</p>' > "$CARDS_FILE"
fi

mkdir -p "$OUTPUT_DIR"

# Replace placeholder with game cards using awk (portable across macOS and Linux)
awk -v cards_file="$CARDS_FILE" '
    /<!-- GAME_LIST -->/ {
        while ((getline line < cards_file) > 0) print line
        next
    }
    { print }
' "$TEMPLATE" > "$OUTPUT_DIR/index.html"

cp landing/style.css "$OUTPUT_DIR/style.css"
rm -f "$CARDS_FILE"

echo "Generated index with games from $GAMES_DIR -> $OUTPUT_DIR/index.html"
