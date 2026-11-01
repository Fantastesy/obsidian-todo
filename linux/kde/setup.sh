#!/usr/bin/env bash
# Obsidian Todo - Setup fuer KDE Plasma 6 (alle Distributionen)
#
#   chmod +x ObsidianTodo-KDE-Setup.sh && ./ObsidianTodo-KDE-Setup.sh
#
# Optionen:
#   --silent      Update ohne Rueckfragen (nutzt die gespeicherte Einrichtung)
#   --uninstall   Widget entfernen (Todo.md und Archiv bleiben erhalten)
#
# Das fertige Setup enthaelt das Widget als Anhang (siehe linux/build-kde.sh).
set -u

APP="Obsidian Todo"
PLUGIN_ID="io.github.fantastesy.obsidiantodo"
SHORTCUT="Meta+Shift+T"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/obsidian-todo"
CONF="$CONF_DIR/config"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/obsidian-todo"
LOG="${TMPDIR:-/tmp}/obsidian-todo-setup.log"
SILENT=0
UNINSTALL=0
for a in "$@"; do
    case "$a" in
        --silent) SILENT=1 ;;
        --uninstall) UNINSTALL=1 ;;
    esac
done

log() { printf '%s %s\n' "$(date +%FT%T)" "$*" >> "$LOG"; }

# ---------- Dialoge (kdialog, sonst Terminal) ----------
HAVE_KDIALOG=0; command -v kdialog >/dev/null 2>&1 && [ -z "${OBSIDIAN_TODO_NO_GUI:-}" ] && HAVE_KDIALOG=1
info() {
    log "INFO $1"
    [ "$SILENT" = 1 ] && return
    if [ "$HAVE_KDIALOG" = 1 ]; then kdialog --title "$APP" --msgbox "$1"; else printf '\n%s\n' "$1"; fi
}
fail() {
    log "FEHLER $1"
    if [ "$SILENT" = 1 ]; then
        command -v notify-send >/dev/null 2>&1 && notify-send -a "$APP" "Update fehlgeschlagen" "$1"
    elif [ "$HAVE_KDIALOG" = 1 ]; then kdialog --title "$APP" --error "$1"
    else printf '\nFEHLER: %s\n' "$1" >&2; fi
    exit 1
}
ask_yesno() {   # $1 Frage -> 0 = ja
    if [ "$HAVE_KDIALOG" = 1 ]; then kdialog --title "$APP" --yesno "$1"; return $?; fi
    local r; read -r -p "$1 [J/n] " r; [ -z "$r" ] || [ "$r" = j ] || [ "$r" = J ] || [ "$r" = y ]
}
ask_dir() {     # $1 Titel, $2 Startordner -> Ordner auf stdout
    if [ "$HAVE_KDIALOG" = 1 ]; then kdialog --title "$1" --getexistingdirectory "$2"; return $?; fi
    local r; read -r -p "$1 [$2]: " r; printf '%s\n' "${r:-$2}"
}
progress() {    # kurze Statusmeldung
    log "$1"
    [ "$SILENT" = 1 ] && return
    if [ "$HAVE_KDIALOG" = 1 ]; then kdialog --title "$APP" --passivepopup "$1" 8 >/dev/null 2>&1 & else printf '%s\n' "$1"; fi
}

# ---------- Werkzeuge ----------
download() {    # $1 URL, $2 Ziel
    if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"
    else return 1; fi
}
fetch() {       # $1 URL -> stdout
    if command -v curl >/dev/null 2>&1; then curl -fsSL -H "User-Agent: ObsidianTodo-Setup" "$1"
    else wget -q -O - --header="User-Agent: ObsidianTodo-Setup" "$1"; fi
}
# Plasma-Skript ueber D-Bus ausfuehren (qdbus6, qdbus oder gdbus - je nach Distribution)
plasma_script() {
    local s="$1"
    for q in qdbus6 qdbus-qt6 qdbus; do
        if command -v "$q" >/dev/null 2>&1; then
            "$q" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$s" >/dev/null 2>&1 && return 0
        fi
    done
    if command -v gdbus >/dev/null 2>&1; then
        gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell \
            --method org.kde.PlasmaShell.evaluateScript "$s" >/dev/null 2>&1 && return 0
    fi
    return 1
}

# ---------- Widget-Paket finden (Anhang dieses Skripts oder Entwicklerordner) ----------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SELF="$(readlink -f "$0")"
if grep -q '^__PAYLOAD_BELOW__$' "$SELF" 2>/dev/null; then
    sed -n '/^__PAYLOAD_BELOW__$/,$p' "$SELF" | tail -n +2 | base64 -d | tar -xz -C "$WORK" || fail "Das Setup ist beschädigt. Bitte neu herunterladen."
    PKG="$WORK/package"; UPD="$WORK/update.sh"; VERSION="$(cat "$WORK/version.txt")"; REPO="$(cat "$WORK/repo.txt")"
else
    here="$(dirname "$SELF")"
    PKG="$here/package"; UPD="$here/update.sh"; VERSION="dev"; REPO=""
fi
[ -f "$PKG/metadata.json" ] || fail "Widget-Dateien nicht gefunden."

# ---------- Deinstallieren ----------
if [ "$UNINSTALL" = 1 ]; then
    plasma_script "desktops().concat(panels()).forEach(function(c){ c.widgets('$PLUGIN_ID').forEach(function(w){ w.remove(); }); });"
    kpackagetool6 -t Plasma/Applet -r "$PLUGIN_ID" >/dev/null 2>&1
    rm -rf "$DATA_DIR" "$CONF_DIR"
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/obsidian-todo-update.desktop"
    info "$APP wurde entfernt. Deine Todo.md und das Archiv sind noch da."
    exit 0
fi

# ---------- Voraussetzungen ----------
case "${XDG_CURRENT_DESKTOP:-}" in
    *KDE*) ;;
    *) [ "$SILENT" = 1 ] || fail "Dieses Setup ist für KDE Plasma. Erkannt wurde: ${XDG_CURRENT_DESKTOP:-unbekannt}." ;;
esac
# jede Plasma-Sitzung setzt KDE_SESSION_VERSION; sonst plasmashell ohne Grafik fragen
PLASMA_VER="${KDE_SESSION_VERSION:-}"
if [ -z "$PLASMA_VER" ] && command -v plasmashell >/dev/null 2>&1; then
    # ohne Sitzung (z. B. per SSH): an der verlinkten Plasma-Bibliothek erkennen
    # Plasma 6 und neuer bauen auf Qt 6 auf (libPlasma selbst zaehlt eigene Versionen)
    ldd "$(command -v plasmashell)" 2>/dev/null | grep -q 'libQt6Core\.so' && PLASMA_VER=6
fi
[ "${PLASMA_VER%%.*}" -ge 6 ] 2>/dev/null || fail "Benötigt KDE Plasma 6 (gefunden: ${PLASMA_VER:-keins})."
command -v kpackagetool6 >/dev/null 2>&1 || fail "kpackagetool6 fehlt (Paket kpackagetool6 bzw. kpackage)."

# ---------- Obsidian finden ----------
OBS_CONFIGS=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/obsidian.json"
    "$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"
    "$HOME/snap/obsidian/current/.config/obsidian/obsidian.json"
)
obsidian_installed() {
    command -v obsidian >/dev/null 2>&1 && return 0
    command -v flatpak >/dev/null 2>&1 && flatpak info md.obsidian.Obsidian >/dev/null 2>&1 && return 0
    [ -d /snap/obsidian ] && return 0
    ls "$HOME"/Applications/Obsidian*.AppImage "$HOME"/.local/bin/Obsidian*.AppImage >/dev/null 2>&1 && return 0
    command -v xdg-mime >/dev/null 2>&1 && [ -n "$(xdg-mime query default x-scheme-handler/obsidian 2>/dev/null)" ] && return 0
    return 1
}
# alle bekannten Vaults (Pfad je Zeile)
list_vaults() {
    for f in "${OBS_CONFIGS[@]}"; do
        [ -f "$f" ] || continue
        if command -v python3 >/dev/null 2>&1; then
            python3 -c 'import json,sys
for v in json.load(open(sys.argv[1])).get("vaults",{}).values():
    p=v.get("path")
    if p: print(p)' "$f" 2>/dev/null
        else
            grep -o '"path":"[^"]*"' "$f" | sed 's/^"path":"//; s/"$//; s/\\\//\//g; s/\\\\/\\/g'
        fi
    done | while IFS= read -r p; do [ -d "$p" ] && printf '%s\n' "$p"; done | sort -u
}
# Vault in obsidian.json eintragen (Flatpak-Obsidian hat eine eigene Datei)
register_vault() {
    local vault="$1" f
    if command -v flatpak >/dev/null 2>&1 && flatpak info md.obsidian.Obsidian >/dev/null 2>&1; then f="${OBS_CONFIGS[1]}"
    elif [ -d /snap/obsidian ]; then f="${OBS_CONFIGS[2]}"
    else f="${OBS_CONFIGS[0]}"; fi
    mkdir -p "$(dirname "$f")"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$f" "$vault" <<'PY'
import json, os, secrets, sys, time
f, vault = sys.argv[1], sys.argv[2].rstrip('/')
data = {}
if os.path.exists(f):
    try: data = json.load(open(f))
    except Exception: data = {}
vaults = data.setdefault('vaults', {})
if not any(v.get('path', '').rstrip('/') == vault for v in vaults.values()):
    vaults[secrets.token_hex(8)] = {'path': vault, 'ts': int(time.time() * 1000)}
    json.dump(data, open(f, 'w'))
PY
    elif [ ! -f "$f" ]; then
        printf '{"vaults":{"%s":{"path":"%s","ts":%s000}}}' "$(head -c8 /dev/urandom | od -An -tx1 | tr -d ' \n')" "$vault" "$(date +%s)" > "$f"
    else
        log "obsidian.json nicht geaendert (python3 fehlt)"
    fi
}
install_obsidian() {
    if command -v flatpak >/dev/null 2>&1; then
        progress "Obsidian wird über Flatpak installiert …"
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >>"$LOG" 2>&1
        flatpak install --user -y --noninteractive flathub md.obsidian.Obsidian >>"$LOG" 2>&1 && return 0
    fi
    # sonst offizielles AppImage nach ~/Applications
    progress "Obsidian wird heruntergeladen …"
    local arch pat url
    arch="$(uname -m)"
    if [ "$arch" = aarch64 ]; then pat='Obsidian-[0-9.]*-arm64\.AppImage'; else pat='Obsidian-[0-9.]*\.AppImage'; fi
    url="$(fetch https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep -o "\"browser_download_url\": *\"[^\"]*/$pat\"" | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
    [ -n "$url" ] || return 1
    mkdir -p "$HOME/Applications" "$HOME/.local/share/applications"
    download "$url" "$HOME/Applications/Obsidian.AppImage" || return 1
    chmod +x "$HOME/Applications/Obsidian.AppImage"
    cat > "$HOME/.local/share/applications/obsidian.desktop" <<EOF
[Desktop Entry]
Name=Obsidian
Exec="$HOME/Applications/Obsidian.AppImage" --no-sandbox %u
Type=Application
Icon=obsidian
Terminal=false
MimeType=x-scheme-handler/obsidian;
Categories=Office;
EOF
    command -v xdg-mime >/dev/null 2>&1 && xdg-mime default obsidian.desktop x-scheme-handler/obsidian
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1
    return 0
}

# ---------- Einrichtung waehlen ----------
VAULT=""; TODO_DIR=""
if [ -f "$CONF" ]; then
    VAULT="$(sed -n 's/^VAULT=//p' "$CONF")"
    TODO_DIR="$(dirname "$(sed -n 's/^TODO_FILE=//p' "$CONF")")"
fi

if [ "$SILENT" = 0 ]; then
    info "Willkommen bei $APP!

Damit bekommst du eine Todo-Liste als KDE-Widget, die direkt in deinem Obsidian-Vault gespeichert wird."

    if ! obsidian_installed; then
        if ask_yesno "Obsidian ist nicht installiert. Soll es mitinstalliert werden?

(Die Todo-Liste funktioniert auch ohne – du kannst sie dann nur nicht in Obsidian öffnen.)"; then
            install_obsidian || info "Obsidian konnte nicht installiert werden. Du kannst es später von obsidian.md installieren."
        fi
    fi

    mapfile -t VAULTS < <(list_vaults)
    CHOICE="__new__"
    if [ "${#VAULTS[@]}" -gt 0 ]; then
        if [ "$HAVE_KDIALOG" = 1 ]; then
            args=()
            for i in "${!VAULTS[@]}"; do
                st=off; { [ "${VAULTS[$i]}" = "$VAULT" ] || { [ -z "$VAULT" ] && [ "$i" = 0 ]; }; } && st=on
                args+=("$i" "${VAULTS[$i]}" "$st")
            done
            args+=("__new__" "Neuen Vault anlegen" off)
            CHOICE="$(kdialog --title "$APP" --radiolist "In welchem Obsidian-Vault soll die Todo-Liste gespeichert werden?" "${args[@]}")" || exit 0
        else
            printf 'Gefundene Vaults:\n'; for i in "${!VAULTS[@]}"; do printf '  %s) %s\n' "$i" "${VAULTS[$i]}"; done
            read -r -p "Nummer wählen (leer = neuer Vault): " CHOICE; [ -z "$CHOICE" ] && CHOICE="__new__"
        fi
    fi
    if [ "$CHOICE" = "__new__" ]; then
        docs="$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documents")"
        mkdir -p "$docs/Obsidian Vault"
        VAULT="$(ask_dir "Ordner für den neuen Vault wählen" "$docs/Obsidian Vault")" || exit 0
        [ -n "$VAULT" ] || exit 0
        mkdir -p "$VAULT/.obsidian"
        rmdir "$docs/Obsidian Vault" 2>/dev/null   # nur weg, wenn ungenutzt und leer
        NEW_VAULT=1
    else
        VAULT="${VAULTS[$CHOICE]}"
        NEW_VAULT=0
    fi
    VAULT="${VAULT%/}"

    # vorhandene Todo.md vorschlagen
    suggest="$VAULT"
    [ "$VAULT" = "$(sed -n 's/^VAULT=//p' "$CONF" 2>/dev/null)" ] && [ -n "$TODO_DIR" ] && suggest="$TODO_DIR"
    if [ "$suggest" = "$VAULT" ]; then
        found="$(find "$VAULT" -maxdepth 2 -name Todo.md -not -path '*/.*' 2>/dev/null | head -1)"
        [ -n "$found" ] && suggest="$(dirname "$found")"
    fi
    while :; do
        TODO_DIR="$(ask_dir "Ordner für Todo.md (im Vault)" "$suggest")" || exit 0
        TODO_DIR="${TODO_DIR%/}"
        case "$TODO_DIR/" in "$VAULT"/*) break ;; esac
        info "Der Ordner muss im Vault liegen:
$VAULT"
    done
    [ "$NEW_VAULT" = 1 ] && register_vault "$VAULT"
else
    [ -n "$VAULT" ] && [ -n "$TODO_DIR" ] || fail "Keine gespeicherte Einrichtung gefunden."
fi

# ---------- Dateien ----------
TODO_FILE="$TODO_DIR/Todo.md"
ARCHIVE_FILE="$TODO_DIR/Todo-Archiv.md"
mkdir -p "$TODO_DIR"
[ -f "$TODO_FILE" ] || printf '# Todo\n\n- [ ] Mein erster Punkt\n' > "$TODO_FILE"
[ -f "$ARCHIVE_FILE" ] || printf '# Todo-Archiv\n' > "$ARCHIVE_FILE"

mkdir -p "$CONF_DIR"
cat > "$CONF" <<EOF
# Obsidian Todo - geschrieben vom Setup
VAULT=$VAULT
VAULT_NAME=$(basename "$VAULT")
TODO_FILE=$TODO_FILE
ARCHIVE_FILE=$ARCHIVE_FILE
EOF

# ---------- Widget installieren ----------
FIRST_INSTALL=1
if kpackagetool6 -t Plasma/Applet -s "$PLUGIN_ID" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$PLUGIN_ID"; then
    FIRST_INSTALL=0
    kpackagetool6 -t Plasma/Applet -u "$PKG" >>"$LOG" 2>&1 || fail "Widget konnte nicht aktualisiert werden (Details: $LOG)."
else
    kpackagetool6 -t Plasma/Applet -i "$PKG" >>"$LOG" 2>&1 || fail "Widget konnte nicht installiert werden (Details: $LOG)."
fi

# Updates
mkdir -p "$DATA_DIR"
cp "$UPD" "$DATA_DIR/update.sh"; chmod +x "$DATA_DIR/update.sh"
printf '%s\n' "$VERSION" > "$DATA_DIR/version.txt"
printf '%s\n' "$REPO" > "$DATA_DIR/repo.txt"

# ---------- Auf den Desktop setzen (nur wenn noch nirgends vorhanden) ----------
if [ "$SILENT" = 0 ]; then
    plasma_script "
var id = '$PLUGIN_ID', found = false;
desktops().concat(panels()).forEach(function (c) { if (c.widgets(id).length) found = true; });
if (!found) {
    var d = desktops()[0];
    for (var i = 0; i < desktops().length; i++) if (desktops()[i].screen === 0) d = desktops()[i];
    var w = d.addWidget(id);
    w.globalShortcut = '$SHORTCUT';
    var g = screenGeometry(d.screen);
    w.geometry = new QRectF(g.width - 520, 60, 480, 560);
    w.reloadConfig();
}" || log "Widget konnte nicht automatisch auf den Desktop gesetzt werden"
fi

log "fertig: $TODO_FILE (Version $VERSION)"
if [ "$SILENT" = 1 ]; then
    command -v notify-send >/dev/null 2>&1 && notify-send -a "$APP" -i checkbox "$APP aktualisiert" "Version $VERSION ist installiert. Sie wird nach dem nächsten Anmelden aktiv."
else
    info "Fertig!

Die Liste liegt oben rechts auf deinem Desktop und speichert in:
$TODO_FILE

Neuer Punkt von überall: $SHORTCUT
Falls das Widget fehlt: Rechtsklick auf den Desktop → „Miniprogramme hinzufügen“ → „Obsidian Todo“."
fi
exit 0
