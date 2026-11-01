# Laeuft IN der Windows-Sandbox: installiert ObsidianTodo-Setup.exe unbeaufsichtigt und sammelt Ergebnisse.
$out = 'C:\Users\WDAGUtilityAccount\Desktop\out'
$in = 'C:\Users\WDAGUtilityAccount\Desktop\ObsidianTodo-Test'
Start-Transcript -Path "$out\test.log" -Force | Out-Null
"Start: $(Get-Date -Format s)"

Copy-Item "$in\ObsidianTodo-Setup.exe" "$env:TEMP\setup.exe"
# nicht -Wait: das wartet auch auf alle gestarteten Programme (Rainmeter laeuft dauerhaft weiter)
$p = Start-Process "$env:TEMP\setup.exe" -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=$out\inno.log" -PassThru
$p.WaitForExit()
"Setup Exitcode: $($p.ExitCode)"
Start-Sleep -Seconds 15

"--- Rainmeter ---"
Get-Process Rainmeter, TodoHotkey -ErrorAction SilentlyContinue | Select-Object Name, Path | Format-List
Test-Path "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
"--- Skin-Verknuepfung ---"
$link = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins\ObsidianTodo'
Get-Item $link -Force -ErrorAction SilentlyContinue | Select-Object FullName, LinkType, Target | Format-List
"--- settings.inc ---"
Get-Content "$env:LOCALAPPDATA\Programs\Obsidian Todo\ObsidianTodo\@Resources\settings.inc" -Encoding Unicode -ErrorAction SilentlyContinue
"--- Todo.md ---"
Get-ChildItem ([Environment]::GetFolderPath('MyDocuments')) -Recurse -Filter 'Todo*.md' -ErrorAction SilentlyContinue | Select-Object FullName
"--- obsidian.json ---"
Get-Content "$env:APPDATA\obsidian\obsidian.json" -ErrorAction SilentlyContinue
"--- Rainmeter.ini (aktive Skins) ---"
Get-Content "$env:APPDATA\Rainmeter\Rainmeter.ini" -ErrorAction SilentlyContinue | Select-String '^\[|Active='
"--- Protokoll-Registrierung ---"
(Get-ItemProperty 'HKCU:\Software\Classes\todo-rm\shell\open\command' -ErrorAction SilentlyContinue).'(default)'
"--- Helper-Log ---"
Get-Content "$env:TEMP\ObsidianTodo-Setup.log" -ErrorAction SilentlyContinue

# Screenshot vom Desktop
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$b = [Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object Drawing.Bitmap $b.Width, $b.Height
[Drawing.Graphics]::FromImage($bmp).CopyFromScreen($b.Location, [Drawing.Point]::Empty, $b.Size)
$bmp.Save("$out\desktop.png")
"Ende: $(Get-Date -Format s)"
Stop-Transcript | Out-Null
Set-Content "$out\fertig.txt" 'ok'
