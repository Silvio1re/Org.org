#!/bin/bash
# update/validate.sh

SOURCE_FILE="playlists/sources.m3u"
OUTPUT_FILE="playlists/main.m3u"
TEMP_ALL="/tmp/all_sources.m3u"
TEMP_VALIDATED="/tmp/validated.m3u"

echo "🧪 Proširujem i testiram linkove iz $SOURCE_FILE..."

# 1. Proširi izvore: ako je redak link na .m3u, dohvati njegov sadržaj
> "$TEMP_ALL"
echo "#EXTM3U" >> "$TEMP_ALL"

while IFS= read -r line; do
    if [[ $line =~ ^https?://.*\.m3u$ ]]; then
        echo "  Dohvaćam vanjsku listu: $line"
        curl -s -L "$line" >> "$TEMP_ALL"
    else
        echo "$line" >> "$TEMP_ALL"
    fi
done < "$SOURCE_FILE"

# 2. Testiraj linkove tako da pokušaš preuzeti prvih nekoliko bajtova
> "$TEMP_VALIDATED"
echo "#EXTM3U" >> "$TEMP_VALIDATED"

while IFS= read -r line; do
    if [[ $line =~ ^https?:// && ( $line =~ \.m3u8 || $line =~ \.ts || $line =~ playlist ) ]]; then
        echo "  Testiram: $line"
        # Testiraj tako da preuzmeš prvih 100 KB (ili do 3 sekunde)
        if curl -s -L --max-time 3 --range 0-102400 "$line" | head -c 100 | grep -q "#EXTM3U\|#EXTINF\|mpeg\|video"; then
            echo "    ✅ RADI!"
            if [[ $prev_line == \#EXTINF* ]]; then
                echo "$prev_line" >> "$TEMP_VALIDATED"
            fi
            echo "$line" >> "$TEMP_VALIDATED"
        else
            echo "    ❌ NE RADI"
        fi
    else
        prev_line="$line"
    fi
done < "$TEMP_ALL"

# 3. Spremi rezultat
if [ ! -s "$TEMP_VALIDATED" ] || [ "$(grep -c '^http' "$TEMP_VALIDATED")" -eq 0 ]; then
    echo "⚠️  Nema radnih linkova! Stvaram praznu listu."
    echo "#EXTM3U" > "$OUTPUT_FILE"
    echo "# Nema aktivnih kanala" >> "$OUTPUT_FILE"
    exit 0
fi

mv "$TEMP_VALIDATED" "$OUTPUT_FILE"

echo "✅ Lista ažurirana! Aktivnih linkova: $(grep -c '^http' "$OUTPUT_FILE")"
