#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -q --no-install-recommends plasma-workspace kpackagetool6 qml6-module-org-kde-kirigami \
  qml6-module-qtquick-dialogs qml6-module-org-kde-plasma-plasma5support libnotify-bin kdialog \
  fonts-noto-color-emoji dbus-x11 breeze > /tmp/apt.log 2>&1
echo "EXIT=$?"; tail -3 /tmp/apt.log; command -v plasmawindowed kpackagetool6 notify-send kdialog
