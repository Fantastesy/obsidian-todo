#!/bin/bash
for p in libplasma6 libplasma-dev plasma-framework kpackagetool6 libkf6package-bin plasma-workspace plasma-desktop \
  qml6-module-org-kde-kirigami qml6-module-qtquick-dialogs qml6-module-org-kde-plasma-plasma5support plasma5support \
  libnotify-bin kdialog qml-module-org-kde-kirigami2; do
  printf '%-45s %s\n' "$p" "$(apt-cache policy "$p" 2>/dev/null | sed -n 3p | xargs)"
done
apt-cache search --names-only 'plasma5support|libplasma|kpackage' | head -20
