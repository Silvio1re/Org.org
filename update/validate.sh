#!/bin/bash
# update/validate.sh

SOURCE_FILE="playlists/sources.m3u"
OUTPUT_FILE="playlists/main.m3u"
TEMP_FILE="/tmp/validated.m3u"

echo "🧪 Testiram linkove iz $SOURCE_FILE..."

# Provjeri postoji li izvorna datoteka
if [ ! -f "$SOURCE_FILE" ]; then
    echo "❌ GREŠKA: Datoteka $SOURCE_FILE ne postoji!"
    exit 1
fi

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

# Ako nema radnih linkova, kreiraj praznu listu (neće biti greške)
if [ ! -s "$TEMP_FILE" ] || [ "$(grep -c '^http' "$TEMP_FILE")" -eq 0 ]; then
    echo "⚠️  Nema radnih linkova! Stvaram praznu listu."
    echo "#EXTM3U" > "$OUTPUT_FILE"
    echo "# Nema aktivnih kanala" >> "$OUTPUT_FILE"
    exit 0  # Završava bez greške
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "✅ Lista ažurirana! Aktivnih linkova: $(grep -c '^http' "$OUTPUT_FILE")"
