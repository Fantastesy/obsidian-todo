#!/bin/sh
# Automatische Updates fuer Obsidian Todo (KDE).
# Wird vom Widget beim Start und alle 6 Stunden aufgerufen, fragt aber hoechstens alle 6 Stunden bei GitHub.
# Gibt es ein neueres Release, wird ObsidianTodo-KDE-Setup-<version>.sh geladen, die SHA-256-Pruefsumme
# verglichen und das Setup mit --silent ausgefuehrt. Einstellungen und Todo-Liste bleiben unveraendert.
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/obsidian-todo"
STAMP="$DIR/last-update-check"
LOG="$DIR/update.log"
# Name mit oder ohne Versionsnummer: ObsidianTodo-KDE-Setup-1.2.0.sh
ASSET_RE='^ObsidianTodo-KDE-Setup(-[0-9.]+)?\.sh$'

log() { printf '%s %s\n' "$(date +%FT%T)" "$*" >> "$LOG"; }

REPO="$(head -n1 "$DIR/repo.txt" 2>/dev/null)"
printf '%s' "$REPO" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || exit 0   # Entwicklerversion
CUR="$(head -n1 "$DIR/version.txt" 2>/dev/null)"

now="$(date +%s)"; last="$(cat "$STAMP" 2>/dev/null || echo 0)"
[ $((now - last)) -lt 21600 ] && exit 0
echo "$now" > "$STAMP"

get() { if command -v curl >/dev/null 2>&1; then curl -fsSL -H "User-Agent: ObsidianTodo-Updater" "$@"; else wget -q -O - --header="User-Agent: ObsidianTodo-Updater" "$1"; fi; }

json="$(get "https://api.github.com/repos/$REPO/releases/latest")" || { log "GitHub nicht erreichbar"; exit 0; }
TAG="$(printf '%s' "$json" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"v\{0,1\}\([^"]*\)"$/\1/')"
[ -n "$TAG" ] || exit 0
[ "$TAG" = "$CUR" ] && exit 0
[ "$(printf '%s\n%s\n' "$CUR" "$TAG" | sort -V | tail -n1)" = "$TAG" ] || exit 0

# Download-Adresse und Pruefsumme der Setup-Datei
if command -v python3 >/dev/null 2>&1; then
    info="$(printf '%s' "$json" | python3 -c 'import json,re,sys
for a in json.load(sys.stdin).get("assets",[]):
    if re.match(sys.argv[1], a.get("name","")): print(a.get("browser_download_url","")); print((a.get("digest") or "").replace("sha256:","")); break' "$ASSET_RE")"
    URL="$(printf '%s\n' "$info" | sed -n 1p)"; SHA="$(printf '%s\n' "$info" | sed -n 2p)"
else
    URL="$(printf '%s' "$json" | grep -oE "\"browser_download_url\": *\"[^\"]*/ObsidianTodo-KDE-Setup(-[0-9.]+)?\.sh\"" | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"; SHA=""
fi
[ -n "$URL" ] || { log "Release $TAG ohne KDE-Setup"; exit 0; }

TMP="$(mktemp)"
get "$URL" > "$TMP" || { log "Download fehlgeschlagen"; rm -f "$TMP"; exit 0; }
if [ -n "$SHA" ] && command -v sha256sum >/dev/null 2>&1; then
    [ "$(sha256sum "$TMP" | cut -d' ' -f1)" = "$SHA" ] || { log "Pruefsumme falsch fuer $TAG - Update abgebrochen"; rm -f "$TMP"; exit 1; }
fi
log "Update $CUR -> $TAG"
chmod +x "$TMP"
bash "$TMP" --silent >> "$LOG" 2>&1
rm -f "$TMP"
