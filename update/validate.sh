#!/bin/bash
# update/validate.sh
# ======================================================
# IPTV M3U validator i sastavljač lista s grupama
# ======================================================
# - Podržava vanjske M3U liste (auto-dohvat)
# - Dodaje group-title prema nazivu datoteke
# - Čuva razmake i posebne znakove (IFS=)
# - Čita i zadnji red bez newline (|| [[ -n "$line" ]])
# - Uklanja duplikate po linku
# - Ispisuje broj kanala na kraju
# ======================================================

SOURCE_FILE="playlists/sources.m3u"
OUTPUT_FILE="playlists/main.m3u"
TEMP_ALL="/tmp/all_sources.m3u"
TEMP_CLEAN="/tmp/clean_sources.m3u"

echo "🧪 Proširujem izvore iz $SOURCE_FILE..."

# ============================================================
# 1. PROŠIRIVANJE IZVORA (dohvat vanjskih M3U lista)
# ============================================================
> "$TEMP_ALL"
echo "#EXTM3U" >> "$TEMP_ALL"

while IFS= read -r line || [[ -n "$line" ]]; do
    # Preskoči prazne redove i obične komentare (ali ne i #EXTINF)
    [[ -z "$line" || ( "$line" =~ ^[[:space:]]*# && ! "$line" =~ ^#EXTINF ) ]] && continue

    # Ako je redak link na vanjsku M3U listu
    if [[ $line =~ ^https?://.*\.m3u$ ]]; then
        echo "  Dohvaćam vanjsku listu: $line"

        # Odredi naziv grupe prema nazivu datoteke
        if [[ $line =~ hr\.m3u ]]; then
            group="Hrvatska"
        elif [[ $line =~ de_rakuten\.m3u ]]; then
            group="Njemačka"
        elif [[ $line =~ ch\.m3u ]]; then
            group="Švicarska"
        elif [[ $line =~ uk_rakuten\.m3u ]]; then
            group="UK"
        elif [[ $line =~ at\.m3u ]]; then
            group="Austrija"
        elif [[ $line =~ si\.m3u ]]; then
            group="Slovenija"
        elif [[ $line =~ ba\.m3u ]]; then
            group="Bosna"
        elif [[ $line =~ rs\.m3u ]]; then
            group="Srbija"
        elif [[ $line =~ eu\.m3u ]]; then
            group="EU"
        else
            group="Ostalo"
        fi

        # Dohvati listu i dodaj group-title
        # - prvo zamijeni tvg-id ako postoji
        # - ako nema tvg-id, dodaj group-title prije zareza
        curl -s -L "$line" | \
            sed -E "s/tvg-id=\"[^\"]*\"/group-title=\"$group\"/g; s/(#EXTINF:-1[^,]*)(,)/\1 group-title=\"$group\"\2/g" \
            >> "$TEMP_ALL" || echo "  ⚠️ Greška pri dohvaćanju: $line"
    else
        # Inače, samo prepiši redak (EXTINF ili direktan link)
        echo "$line" >> "$TEMP_ALL"
    fi
done < "$SOURCE_FILE"

# ============================================================
# 2. ČIŠĆENJE: spajanje #EXTINF i pripadajućeg linka
# ============================================================
> "$TEMP_CLEAN"
echo "#EXTM3U" >> "$TEMP_CLEAN"

current_extinf=""
while IFS= read -r line || [[ -n "$line" ]]; do
    # Preskoči potpuno prazne redove
    [[ -z "$line" ]] && continue

    # Ako je redak EXTINF, spremi ga
    if [[ $line == \#EXTINF* ]]; then
        current_extinf="$line"
    fi

    # Ako je redak link, a imamo spremljen EXTINF
    if [[ $line =~ ^https?:// ]] && [ -n "$current_extinf" ]; then
        echo "$current_extinf" >> "$TEMP_CLEAN"
        echo "$line" >> "$TEMP_CLEAN"
        current_extinf=""  # Resetiraj za sljedeći kanal
    fi
done < "$TEMP_ALL"

# ============================================================
# 3. UKLANJANJE DUPLIKATA (po linku, a ne po cijelom retku)
# ============================================================
> "$OUTPUT_FILE"
echo "#EXTM3U" >> "$OUTPUT_FILE"

awk '
    BEGIN { seen_link = "" }
    /^#EXTINF/ { extinf = $0; next }
    /^https?:\/\// && !seen[$0] { 
        print extinf; 
        print $0; 
        seen[$0] = 1; 
        extinf = "" 
    }
' "$TEMP_CLEAN" >> "$OUTPUT_FILE"

# ============================================================
# 4. STATISTIKA I ZAVRŠETAK
# ============================================================
TOTAL=$(grep -c '^#EXTINF' "$OUTPUT_FILE")
echo "✅ Lista sastavljena! Ukupno kanala: $TOTAL"

# Ako nema kanala, upozori
if [ "$TOTAL" -eq 0 ]; then
    echo "⚠️  UPOZORENJE: Lista je prazna! Provjeri sources.m3u i vanjske izvore."
    exit 1
fi

exit 0
