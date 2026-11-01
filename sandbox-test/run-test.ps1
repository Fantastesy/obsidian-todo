# Laeuft IN der Windows-Sandbox: installiert ObsidianTodo-Setup.exe unbeaufsichtigt und prueft das Ergebnis.
$out = 'C:\Users\WDAGUtilityAccount\Desktop\out'
$in = 'C:\Users\WDAGUtilityAccount\Desktop\ObsidianTodo-Test'
$log = "$out\test.log"
function W($s) { Add-Content -Path $log -Value $s -Encoding UTF8 }
function Shot($name) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $b = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object Drawing.Bitmap $b.Width, $b.Height
    [Drawing.Graphics]::FromImage($bmp).CopyFromScreen($b.Location, [Drawing.Point]::Empty, $b.Size)
    $bmp.Save("$out\$name.png")
}
W "Start: $(Get-Date -Format s)"

Copy-Item "$in\ObsidianTodo-Setup.exe" "$env:TEMP\setup.exe"
# nicht -Wait: das wartet auch auf alle gestarteten Programme (Rainmeter laeuft dauerhaft weiter)
$p = Start-Process "$env:TEMP\setup.exe" -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=$out\inno.log" -PassThru
$p.WaitForExit()
W "Setup Exitcode: $($p.ExitCode)"
Start-Sleep -Seconds 15

$rm = (Get-Process Rainmeter -ErrorAction SilentlyContinue | Select-Object -First 1).Path
Shot 'nach-installation'
# Rainmeter-Protokoll einschalten und neu starten
$ini = "$env:APPDATA\Rainmeter\Rainmeter.ini"
Stop-Process -Name Rainmeter -Force; Start-Sleep 2
(Get-Content $ini) -replace '^\[Rainmeter\]$', "[Rainmeter]`r`nLogging=1`r`nDebug=1" | Set-Content $ini -Encoding Unicode
Start-Process $rm; Start-Sleep 10
Shot 'nach-neustart'
W "Rainmeter.ini Abschnitte: $((Select-String -Path $ini -Pattern '^\[ObsidianTodo' -Context 0,4 | Out-String))"
W "Rainmeter: $rm"
W "TodoHotkey laeuft: $([bool](Get-Process TodoHotkey -ErrorAction SilentlyContinue))"
$res = "$env:LOCALAPPDATA\Programs\Obsidian Todo\ObsidianTodo\@Resources"
W "settings.inc: $(Test-Path "$res\settings.inc")  prefs.inc: $(Test-Path "$res\prefs.inc")"
$task = Get-ScheduledTask -TaskName 'ObsidianTodo-Einblenden' -ErrorAction SilentlyContinue
W "Aufgabe Einblenden: $(if ($task) { ($task.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ', ' } else { 'FEHLT' })"
W "Startmenue-Eintrag entfernen: $(Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Obsidian To-do entfernen.lnk")"
W "Helper-Log:"; Get-Content "$env:TEMP\ObsidianTodo-Setup.log" -ErrorAction SilentlyContinue | ForEach-Object { W "   $_" }

# Grosses Fenster ueber die Liste legen (ohne Eingabefeld), dann Einblenden ausloesen
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object Windows.Forms.Form
$form.Text = 'Arbeitsfenster'; $form.WindowState = 'Maximized'; $form.BackColor = 'SteelBlue'
$form.Show(); [Windows.Forms.Application]::DoEvents(); Start-Sleep -Seconds 2
Shot 'vorher-verdeckt'
& $rm '!CommandMeasure' 'MeasureTodo' 'Reveal()' 'ObsidianTodo'
Start-Sleep -Seconds 3; [Windows.Forms.Application]::DoEvents()
Shot 'nachher-eingeblendet'
# Ausblenden
& $rm '!CommandMeasure' 'MeasureTodo' 'HideReveal()' 'ObsidianTodo'
Start-Sleep -Seconds 3; [Windows.Forms.Application]::DoEvents()
Shot 'ausgeblendet'
$form.Close()

# Breite umstellen wie im Hilfe-Fenster
& $rm '!WriteKeyValue' 'Variables' 'Width' '560' "$res\prefs.inc"
& $rm '!Refresh' 'ObsidianTodo'
Start-Sleep -Seconds 3
Shot 'breit'
W "prefs.inc: $((Get-Content "$res\prefs.inc" -Encoding Unicode) -join ' | ')"

# Deinstallieren
$un = Get-ChildItem "$env:LOCALAPPDATA\Programs\Obsidian Todo\unins*.exe" | Select-Object -First 1
$p = Start-Process $un.FullName -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES' -PassThru
$p.WaitForExit(); Start-Sleep -Seconds 5
W "Nach Deinstallation: Aufgabe=$([bool](Get-ScheduledTask -TaskName 'ObsidianTodo-Einblenden' -ErrorAction SilentlyContinue)) Programmordner=$(Test-Path "$env:LOCALAPPDATA\Programs\Obsidian Todo\ObsidianTodo") Todo.md=$(Test-Path "$env:USERPROFILE\Documents\Obsidian Vault\Todo.md")"
Copy-Item "$env:APPDATA\Rainmeter\Rainmeter.log" "$out\Rainmeter.log" -ErrorAction SilentlyContinue
W "Ende: $(Get-Date -Format s)"
Set-Content "$out\fertig.txt" 'ok'
