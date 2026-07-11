#!/bin/bash
# update/validate.sh
# ======================================================
# IPTV M3U validator i sastavljač lista s grupama
# ======================================================
# - Dohvaća vanjske M3U liste
# - Dodaje group-title prema nazivu datoteke
# - Uklanja duplikate po URL-u
# - Generira main.m3u sa svim kanalima (bez provjere dostupnosti)
# ======================================================

SOURCE_FILE="playlists/sources.m3u"
OUTPUT_FILE="playlists/main.m3u"
TEMP_ALL="/tmp/all_sources.m3u"
TEMP_CLEAN="/tmp/clean_sources.m3u"

# Osiguraj da direktorij za izlaznu datoteku postoji
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "🧪 Korak 1: Proširujem izvore iz $SOURCE_FILE..."

# ============================================================
# 1. PROŠIRIVANJE IZVORA (dohvat vanjskih M3U lista)
# ============================================================
echo "#EXTM3U" > "$TEMP_ALL"

while IFS= read -r line || [[ -n "$line" ]]; do
    # Ukloni Carriage Return (\r) oznake (Windows kompatibilnost)
    line="${line//$'\r'/}"
    
    # Preskoči prazne redove i obične komentare (ali ne i #EXTINF)
    [[ -z "$line" || ( "$line" =~ ^[[:space:]]*# && ! "$line" =~ ^#EXTINF ) ]] && continue

    # Ako je redak link na vanjsku M3U listu (s ili bez parametara)
    if [[ $line =~ ^https?://.*\.m3u($|\?) ]]; then
        echo "  Dohvaćam vanjsku listu: $line"

        # Odredi naziv grupe prema nazivu datoteke
        if [[ $line =~ hr\.m3u ]]; then group="Hrvatska"
        elif [[ $line =~ de_rakuten\.m3u ]]; then group="Njemačka"
        elif [[ $line =~ ch\.m3u ]]; then group="Švicarska"
        elif [[ $line =~ uk_rakuten\.m3u ]]; then group="UK"
        elif [[ $line =~ at\.m3u ]]; then group="Austrija"
        elif [[ $line =~ si\.m3u ]]; then group="Slovenija"
        elif [[ $line =~ ba\.m3u ]]; then group="Bosna"
        elif [[ $line =~ rs\.m3u ]]; then group="Srbija"
        elif [[ $line =~ eu\.m3u ]]; then group="EU"
        else group="Ostalo"
        fi

        # Dohvati listu, očisti je od \r, zamijeni/dodaj group-title
        curl -s -L "$line" | tr -d '\r' | sed -E "
            /group-title=/!s/(#EXTINF:-?[0-9]+[^,]*)(,)/\1 group-title=\"$group\"\2/g;
            s/group-title=\"[^\"]*\"/group-title=\"$group\"/g
        " >> "$TEMP_ALL" || echo "  ⚠️ Greška pri dohvaćanju: $line"
    else
        # Inače, samo prepiši redak (EXTINF ili direktan link)
        echo "$line" >> "$TEMP_ALL"
    fi
done < "$SOURCE_FILE"

# ============================================================
# 2. ČIŠĆENJE I UKLANJANJE DUPLIKATA (po URL-u)
# ============================================================
echo "🧹 Korak 2: Čistim strukturu i uklanjam duplikate..."
echo "#EXTM3U" > "$TEMP_CLEAN"

# Spajanje EXTINF i linkova
current_extinf=""
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    [[ -z "$line" ]] && continue

    if [[ $line =~ ^#[Ee][Xx][Tt][Ii][Nn][Ff] ]]; then
        current_extinf="$line"
    elif [[ $line =~ ^https?:// ]] && [ -n "$current_extinf" ]; then
        echo "$current_extinf" >> "$TEMP_CLEAN"
        echo "$line" >> "$TEMP_CLEAN"
        current_extinf=""
    fi
done < "$TEMP_ALL"

# Uklanjanje duplikata po URL-u
echo "#EXTM3U" > "$OUTPUT_FILE"
awk '
    /^#[Ee][Xx][Tt][Ii][Nn][Ff]/ { extinf = $0; next }
    /^https?:\/\// { 
        if (extinf != "" && !seen[$0]++) { 
            print extinf; 
            print $0; 
        }
        extinf = "" 
    }
' "$TEMP_CLEAN" >> "$OUTPUT_FILE"

# ============================================================
# 3. STATISTIKA I ZAVRŠETAK
# ============================================================
TOTAL=$(grep -c -i '^#EXTINF' "$OUTPUT_FILE")
echo "✅ Lista uspješno sastavljena!"
echo "📊 Ukupno kanala spremljeno: $TOTAL"

if [ "$TOTAL" -eq 0 ]; then
    echo "⚠️  UPOZORENJE: Rezultirajuća lista je prazna!"
    echo "    Provjeri sources.m3u i vanjske izvore."
    rm -f "$TEMP_ALL" "$TEMP_CLEAN"
    exit 1
fi

# Očisti privremene datoteke
rm -f "$TEMP_ALL" "$TEMP_CLEAN"

exit 0
