#!/bin/bash
# im Container (insession) ausfuehren: listet alle Fenster mit Typ und Schicht ueber ein KWin-Skript.
# Ausgabe kommt per callDBus an einen nicht vorhandenen Dienst und wird mit dbus-monitor mitgelesen.
cat > /tmp/kwin-list.js <<'JS'
var out = [];
var ws = workspace.stackingOrder;
for (var i = 0; i < ws.length; i++) {
  var w = ws[i];
  out.push(i + " " + w.resourceClass + " '" + w.caption + "' dock=" + w.dock + " notification=" + w.notification
    + " normal=" + w.normalWindow + " keepAbove=" + w.keepAbove + " closeable=" + w.closeable
    + " layer=" + w.layer + " x=" + Math.round(w.x) + " w=" + Math.round(w.width) + " active=" + (workspace.activeWindow === w));
}
callDBus("org.test.log", "/", "org.test.log", "log", out.join("\n"));
JS
timeout 4 dbus-monitor "interface='org.test.log'" > /tmp/kwin-list.out 2>/dev/null &
sleep 0.5
id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/kwin-list.js kwinlist$$)
qdbus6 org.kde.KWin /Scripting/Script$id org.kde.kwin.Script.run >/dev/null 2>&1 || qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
sleep 2
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript kwinlist$$ >/dev/null
wait
sed -n '/string "/,/"$/p' /tmp/kwin-list.out | sed 's/^ *string "//; s/"$//' | grep -E "plasmashell|kwrite"
