#!/bin/bash
# update/validate.sh
# ======================================================
# IPTV M3U validator, sastavljač lista i Live Checker
# ======================================================

SOURCE_FILE="playlists/sources.m3u"
OUTPUT_FILE="playlists/main.m3u"
TEMP_ALL="/tmp/all_sources.m3u"
TEMP_CLEAN="/tmp/clean_sources.m3u"
TEMP_ALIVE="/tmp/alive_sources.m3u"

# Osiguraj da direktorij za izlaznu datoteku postoji
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "🧪 Korak 1: Proširujem izvore iz $SOURCE_FILE..."

# ============================================================
# 1. PROŠIRIVANJE IZVORA (dohvat vanjskih M3U lista)
# ============================================================
echo "#EXTM3U" > "$TEMP_ALL"

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    [[ -z "$line" || ( "$line" =~ ^[[:space:]]*# && ! "$line" =~ ^#EXTINF ) ]] && continue

    # Fleksibilniji regex za M3U linkove (neki imaju parametre na kraju poput ?token=...)
    if [[ $line =~ ^https?://.*\.m3u($|\?) ]]; then
        echo "  Dohvaćam vanjsku listu: $line"

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

        curl -s -L "$line" | tr -d '\r' | sed -E "
            /group-title=/!s/(#EXTINF:-?[0-9]+[^,]*)(,)/\1 group-title=\"$group\"\2/g;
            s/group-title=\"[^\"]*\"/group-title=\"$group\"/g
        " >> "$TEMP_ALL" || echo "  ⚠️ Greška pri dohvaćanju: $line"
    else
        echo "$line" >> "$TEMP_ALL"
    fi
done < "$SOURCE_FILE"

# ============================================================
# 2. ČIŠĆENJE I UKLANJANJE DUPLIKATA (po URL-u)
# ============================================================
echo "🧹 Korak 2: Čistim strukturu i uklanjam duplikate..."
echo "#EXTM3U" > "$TEMP_CLEAN"

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

echo "#EXTM3U" > "$TEMP_ALL"
awk '
    /^#[Ee][Xx][Tt][Ii][Nn][Ff]/ { extinf = $0; next }
    /^https?:\/\// { 
        if (extinf != "" && !seen[$0]++) { 
            print extinf; 
            print $0; 
        }
        extinf = "" 
    }
' "$TEMP_CLEAN" >> "$TEMP_ALL"

# ============================================================
# 3. PARALELNA PROVJERA DOSTUPNOSTI (Live Checker)
# ============================================================
echo "🔍 Korak 3: Pokrećem provjeru dostupnosti streamova (paralelno)..."
echo "#EXTM3U" > "$TEMP_ALIVE"

provjeri_stream() {
    local extinf="$1"
    local url="$2"
    
    local status
    status=$(curl -s -o /dev/null -I -L -w "%{http_code}" \
        -H "User-Agent: VLC/3.0.18" \
        --connect-timeout 3 --max-time 5 "$url")
    
    if [[ "$status" =~ ^(200|301|302|307|308|403)$ ]]; then
        printf "%s\n%s\n" "$extinf" "$url"
    fi
}
export -f provjeri_stream

# POPRAVLJENO: Koristi se pravi Tab znak (\t) unutar awk i ispravan xargs poziv
awk '
    /^#[Ee][Xx][Tt][Ii][Nn][Ff]/ { extinf = $0; next }
    /^https?:\/\// { if (extinf != "") print extinf "\t" $0; extinf = "" }
' "$TEMP_ALL" | \
xargs -d '\n' -P 10 -I {} bash -c '
    line="{}"
    extinf="${line%%	*}"
    url="${line##*	}"
    provjeri_stream "$extinf" "$url"
' >> "$TEMP_ALIVE"

cat "$TEMP_ALIVE" > "$OUTPUT_FILE"

# ============================================================
# 4. STATISTIKA I ZAVRŠETAK
# ============================================================
TOTAL=$(grep -c -i '^#EXTINF' "$OUTPUT_FILE")
echo "✅ Lista uspješno sastavljena!"
echo "📊 Ukupno aktivnih kanala spremljeno: $TOTAL"

if [ "$TOTAL" -eq 0 ]; then
    echo "⚠️  UPOZORENJE: Rezultirajuća lista je potpuno prazna!"
    echo "    Mogući razlozi: Svi streamovi su ugašeni ili vas je server blokirao zbog prebrzih zahtjeva."
    rm -f "$TEMP_ALL" "$TEMP_CLEAN" "$TEMP_ALIVE"
    exit 1
fi

rm -f "$TEMP_ALL" "$TEMP_CLEAN" "$TEMP_ALIVE"
exit 0
