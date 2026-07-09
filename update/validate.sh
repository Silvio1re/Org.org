#!/bin/bash
# update/validate.sh

SOURCE_FILE="playlists/sources.m3u"
OUTPUT_FILE="playlists/main.m3u"
TEMP_ALL="/tmp/all_sources.m3u"
TEMP_CLEAN="/tmp/clean_sources.m3u"

echo "🧪 Proširujem izvore iz $SOURCE_FILE..."

# 1. Proširi izvore i dodaj group-title prema nazivu liste
> "$TEMP_ALL"
echo "#EXTM3U" >> "$TEMP_ALL"

while IFS= read -r line; do
    if [[ $line =~ ^https?://.*\.m3u$ ]]; then
        echo "  Dohvaćam vanjsku listu: $line"
        # Odredi grupu prema nazivu datoteke
        if [[ $line =~ hr\.m3u ]]; then
            group="Hrvatska"
        elif [[ $line =~ de_rakuten\.m3u ]]; then
            group="Njemačka"
        elif [[ $line =~ at\.m3u ]]; then
            group="Austrija"
        else
            group="EU"
        fi
        # Dohvati listu i zamijeni tvg-id s group-title
        curl -s -L "$line" | sed "s/tvg-id=\"[^\"]*\"/group-title=\"$group\"/g" >> "$TEMP_ALL"
    else
        echo "$line" >> "$TEMP_ALL"
    fi
done < "$SOURCE_FILE"

# 2. Očisti listu: spoji EXTINF redak s pripadajućim linkom
> "$TEMP_CLEAN"
echo "#EXTM3U" >> "$TEMP_CLEAN"

while IFS= read -r line; do
    if [[ $line == \#EXTINF* ]]; then
        current_extinf="$line"
    fi
    if [[ $line =~ ^https?:// ]] && [ -n "$current_extinf" ]; then
        echo "$current_extinf" >> "$TEMP_CLEAN"
        echo "$line" >> "$TEMP_CLEAN"
        current_extinf=""
    fi
done < "$TEMP_ALL"

# 3. Ukloni duplikate
> "$OUTPUT_FILE"
echo "#EXTM3U" >> "$OUTPUT_FILE"
awk '!seen[$0]++' "$TEMP_CLEAN" >> "$OUTPUT_FILE"

echo "✅ Lista sastavljena! Ukupno kanala: $(grep -c '^#EXTINF' "$OUTPUT_FILE")"
