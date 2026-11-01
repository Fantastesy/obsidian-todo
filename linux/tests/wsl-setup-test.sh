#!/bin/bash
# Setup-Test in WSL: frischer Benutzer, Setup im Terminal-Modus mit vorgegebenen Antworten
U=setuptest; H=/home/$U
pkill -u $U 2>/dev/null; userdel -rf $U >/dev/null 2>&1; useradd -m -s /bin/bash $U
mkdir -p $H/Dokumente && chown -R $U:$U $H
bash /mnt/h/Projekte/obsidian-todo/linux/build-kde.sh || exit 1
cp /mnt/h/Projekte/obsidian-todo/dist/ObsidianTodo-KDE-Setup.sh $H/ && chown $U:$U $H/ObsidianTodo-KDE-Setup.sh
# Antworten: Obsidian installieren? n | Vault-Ordner: Standard | Todo-Ordner: Standard
su - $U -c "export XDG_CURRENT_DESKTOP=KDE OBSIDIAN_TODO_NO_GUI=1 LANG=de_DE.UTF-8; printf 'n\n\n\n' | bash ./ObsidianTodo-KDE-Setup.sh" 2>&1 | tail -15
echo "===== Ergebnis ====="
cat $H/.config/obsidian-todo/config
ls -la "$H/Dokumente/Obsidian Vault" "$H/.local/share/obsidian-todo" 2>&1
su - $U -c "kpackagetool6 -t Plasma/Applet -l | grep obsidian"
cat $H/.config/obsidian/obsidian.json 2>/dev/null; echo
echo "===== Update-Lauf (silent) ====="
su - $U -c "export XDG_CURRENT_DESKTOP=KDE; bash ./ObsidianTodo-KDE-Setup.sh --silent; echo exit=\$?"
tail -3 /tmp/obsidian-todo-setup.log
