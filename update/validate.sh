#!/bin/bash
# update/validate.sh

SOURCE_FILE="playlists/sources.m3u"
OUTPUT_FILE="playlists/main.m3u"
TEMP_SOURCES="/tmp/sources_expanded.m3u"
TEMP_VALIDATED="/tmp/validated.m3u"

echo "🧪 Proširujem i testiram linkove iz $SOURCE_FILE..."

# 1. Proširi izvore: ako je link na .m3u, dohvati njegov sadržaj
> "$TEMP_SOURCES"
echo "#EXTM3U" >> "$TEMP_SOURCES"

while IFS= read -r line; do
    # Ako je redak link koji završava na .m3u (vanjska lista)
    if [[ $line =~ ^https?://.*\.m3u$ ]]; then
        echo "  Dohvaćam vanjsku listu: $line"
        # Dohvati sadržaj vanjske liste i dodaj ga u privremeni izvor
        curl -s -L "$line" >> "$TEMP_SOURCES"
    else
        # Inače, samo prepiši redak (EXTINF ili link na stream)
        echo "$line" >> "$TEMP_SOURCES"
    fi
done < "$SOURCE_FILE"

# 2. Sada testiraj sve linkove iz proširene liste
> "$TEMP_VALIDATED"
echo "#EXTM3U" >> "$TEMP_VALIDATED"

while IFS= read -r line; do
    # Traži linkove koji vjerojatno su streamovi (završavaju na .m3u8, .ts, ili sadrže playlist)
    if [[ $line =~ ^https?:// && ( $line =~ \.m3u8 || $line =~ \.ts || $line =~ playlist ) ]]; then
        echo "  Testiram: $line"
        if curl -s -I --max-time 5 "$line" | grep -q "200\|302\|403"; then
            echo "    ✅ RADI!"
            # Spremi prethodni redak (EXTINF) ako postoji
            if [[ $prev_line == \#EXTINF* ]]; then
                echo "$prev_line" >> "$TEMP_VALIDATED"
            fi
            echo "$line" >> "$TEMP_VALIDATED"
        else
            echo "    ❌ NE RADI"
        fi
    else
        # Spremi EXTINF redak za eventualno korištenje
        prev_line="$line"
    fi
done < "$TEMP_SOURCES"

# 3. Spremi rezultat
if [ ! -s "$TEMP_VALIDATED" ] || [ "$(grep -c '^http' "$TEMP_VALIDATED")" -eq 0 ]; then
    echo "⚠️  Nema radnih linkova! Stvaram praznu listu."
    echo "#EXTM3U" > "$OUTPUT_FILE"
    echo "# Nema aktivnih kanala" >> "$OUTPUT_FILE"
    exit 0
fi

mv "$TEMP_VALIDATED" "$OUTPUT_FILE"

echo "✅ Lista ažurirana! Aktivnih linkova: $(grep -c '^http' "$OUTPUT_FILE")"
