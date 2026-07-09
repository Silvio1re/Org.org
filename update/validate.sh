#!/bin/bash
# update/validate.sh

SOURCE_FILE="playlists/sources.m3u"
OUTPUT_FILE="playlists/main.m3u"
TEMP_FILE="/tmp/validated.m3u"

echo "🧪 Testiram linkove iz $SOURCE_FILE..."

> "$TEMP_FILE"
echo "#EXTM3U" > "$TEMP_FILE"

while IFS= read -r line; do
    if [[ $line =~ ^https?:// ]]; then
        echo "  Testiram: $line"
        if curl -s -I --max-time 5 "$line" | grep -q "200\|302\|403"; then
            echo "    ✅ RADI!"
            echo "$prev_line" >> "$TEMP_FILE"
            echo "$line" >> "$TEMP_FILE"
        else
            echo "    ❌ NE RADI"
        fi
    else
        prev_line="$line"
    fi
done < "$SOURCE_FILE"

if [ ! -s "$TEMP_FILE" ] || [ "$(grep -c '^http' "$TEMP_FILE")" -eq 0 ]; then
    echo "⚠️  Nema radnih linkova! Zadržavam staru listu."
    exit 0
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "✅ Lista ažurirana! Aktivnih linkova: $(grep -c '^http' "$OUTPUT_FILE")"
