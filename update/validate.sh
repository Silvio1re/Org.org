#!/bin/bash
# update/validate.sh

SOURCE_FILE="playlists/sources.m3u"
OUTPUT_FILE="playlists/main.m3u"
TEMP_ALL="/tmp/all_sources.m3u"

echo "🧪 Proširujem izvore iz $SOURCE_FILE..."

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

# 2. Filtriraj samo redove koji sadrže #EXTINF ili linkove, bez testiranja
> "$OUTPUT_FILE"
echo "#EXTM3U" >> "$OUTPUT_FILE"

grep -E "#EXTINF|https?://" "$TEMP_ALL" | \
    grep -v "https?://.*\.m3u$" | \
    sort -u >> "$OUTPUT_FILE"

echo "✅ Lista sastavljena! Ukupno kanala: $(grep -c '^#EXTINF' "$OUTPUT_FILE")"
