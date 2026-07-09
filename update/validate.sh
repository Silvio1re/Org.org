#!/bin/bash
# update/validate.sh

SOURCE_FILE="playlists/sources.m3u"
OUTPUT_FILE="playlists/main.m3u"
TEMP_ALL="/tmp/all_sources.m3u"
TEMP_CLEAN="/tmp/clean_sources.m3u"

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

# 2. Očisti listu: spoji EXTINF redak s pripadajućim linkom
> "$TEMP_CLEAN"
echo "#EXTM3U" >> "$TEMP_CLEAN"

# Čitamo datoteku red po red, pamtimo EXTINF i spajamo ga s linkom
while IFS= read -r line; do
    # Ako je redak EXTINF, spremi ga u varijablu
    if [[ $line == \#EXTINF* ]]; then
        current_extinf="$line"
    fi
    # Ako je redak link (počinje s http), a imamo spremljen EXTINF
    if [[ $line =~ ^https?:// ]] && [ -n "$current_extinf" ]; then
        # Zapiši EXTINF i link
        echo "$current_extinf" >> "$TEMP_CLEAN"
        echo "$line" >> "$TEMP_CLEAN"
        # Očisti varijablu da se ne ponavlja
        current_extinf=""
    fi
done < "$TEMP_ALL"

# 3. Ukloni duplikate (na temelju linkova)
> "$OUTPUT_FILE"
echo "#EXTM3U" >> "$OUTPUT_FILE"

# Pročitaj čistu listu, izvuci jedinstvene linkove
awk '!seen[$0]++' "$TEMP_CLEAN" >> "$OUTPUT_FILE"

echo "✅ Lista sastavljena! Ukupno kanala: $(grep -c '^#EXTINF' "$OUTPUT_FILE")"
