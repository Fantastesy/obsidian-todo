#!/usr/bin/env bash
# Schnelltest: Widget im laufenden Test-Container (docker-kde-test.sh) neu einspielen und Plasma neu starten.
#   bash linux/tests/docker-kde-update.sh
# Danach Befehle an das Widget:   bash linux/tests/docker-kde-update.sh cmd "show"
#                       Bild:     bash linux/tests/docker-kde-update.sh shot name
set -u
export MSYS_NO_PATHCONV=1
command -v docker >/dev/null || export PATH="/h/Windows stuff/Docker Desktop/resources/bin:$PATH"
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/linux/tests"
c=obsidian-todo-kde
case "${1:-update}" in
cmd)
    docker exec $c bash -c "printf '%s\n' '$2' > /tmp/obsidian-todo-test.cmd; chown abc /tmp/obsidian-todo-test.cmd"
    sleep "${3:-3}"
    docker exec $c cat /tmp/obsidian-todo-test.out 2>/dev/null && echo
    ;;
shot)
    docker exec $c insession bash -c "spectacle -b -n -f -o /tmp/$2.png; sleep 2"
    docker cp $c:/tmp/$2.png "$(cd "$out" && (pwd -W 2>/dev/null || pwd))/$2.png" >/dev/null 2>&1 && echo "Bild: $2.png"
    ;;
log)
    docker exec $c bash -c 'cat /tmp/plasma.log 2>/dev/null | grep -iv "kf.\|kwin\|^$" | grep -i "obsidian\|qml\|error\|warn" | tail -30'
    ;;
update)
    tmp="$(mktemp -d)"
    cp -r "$root/linux/kde/package" "$tmp/package"
    find "$tmp" -type f -exec sed -i 's/\r$//' {} +
    docker exec $c rm -rf /tmp/pkg
    docker cp "$(cd "$tmp" && (pwd -W 2>/dev/null || pwd))/package" $c:/tmp/pkg >/dev/null
    rm -rf "$tmp"
    docker exec $c bash -c 'chown -R abc /tmp/pkg'
    docker exec $c insession bash -c 'kpackagetool6 -t Plasma/Applet -u /tmp/pkg >/dev/null 2>&1 && echo "Widget aktualisiert"
        pkill -x plasmashell; sleep 2
        (setsid plasmashell > /tmp/plasma.log 2>&1 &) ; sleep 12; pgrep -x plasmashell >/dev/null && echo "Plasma laeuft"'
    ;;
esac
