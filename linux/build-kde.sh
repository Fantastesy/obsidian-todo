#!/usr/bin/env bash
# Baut dist/ObsidianTodo-KDE-Setup.sh: das Setup-Skript mit dem Widget als Anhang (tar.gz, Base64).
#   bash linux/build-kde.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
ver="$(head -n1 "$root/VERSION" | tr -d '\r')"
repo="$(head -n1 "$root/REPO" 2>/dev/null | tr -d '\r' || true)"
out="$root/dist"
mkdir -p "$out"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -r "$root/linux/kde/package" "$tmp/package"
cp "$root/linux/kde/update.sh" "$tmp/update.sh"
printf '%s\n' "$ver" > "$tmp/version.txt"
printf '%s\n' "$repo" > "$tmp/repo.txt"
# Version ins Widget schreiben, Windows-Zeilenenden entfernen
sed -i "s/\"Version\": \"[^\"]*\"/\"Version\": \"$ver\"/" "$tmp/package/metadata.json"
find "$tmp" -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name '*.json' \) -exec sed -i 's/\r$//' {} +

rm -f "$out"/ObsidianTodo-KDE-Setup*.sh
f="$out/ObsidianTodo-KDE-Setup-$ver.sh"
sed 's/\r$//' "$root/linux/kde/setup.sh" > "$f"
printf '\n__PAYLOAD_BELOW__\n' >> "$f"
tar -C "$tmp" -cz package update.sh version.txt repo.txt | base64 >> "$f"
chmod +x "$f"
echo "Fertig: $f ($(du -h "$f" | cut -f1), Version $ver)"
