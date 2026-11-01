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

Copy-Item (Get-ChildItem "$in\ObsidianTodo-Setup*.exe" | Select-Object -First 1).FullName "$env:TEMP\setup.exe"
# nicht -Wait: das wartet auch auf alle gestarteten Programme (Rainmeter laeuft dauerhaft weiter)
$p = Start-Process "$env:TEMP\setup.exe" -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=$out\inno.log" -PassThru
$p.WaitForExit()
W "Setup Exitcode: $($p.ExitCode)"
Start-Sleep -Seconds 15

$rm = (Get-Process Rainmeter -ErrorAction SilentlyContinue | Select-Object -First 1).Path
Shot 'nach-installation'
Start-Sleep -Seconds 30   # Zeit zum Hinschauen: Liste oben rechts?
# Rainmeter-Protokoll einschalten und neu starten
$ini = "$env:APPDATA\Rainmeter\Rainmeter.ini"
Stop-Process -Name Rainmeter -Force; Start-Sleep 2
(Get-Content $ini) -replace '^\[Rainmeter\]$', "[Rainmeter]`r`nLogging=1`r`nDebug=1" | Set-Content $ini -Encoding Unicode
Start-Process $rm; Start-Sleep 10
Shot 'nach-neustart'
W "Rainmeter.ini [ObsidianTodo]: $(((Get-Content $ini) -join '|') -replace '.*\[ObsidianTodo\]\|([^\[]*).*','$1')"
# Diagnose: Rainmeter-Fenster, Sichtbarkeit je Ebene
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class RW { public delegate bool E(IntPtr h, IntPtr p);
[DllImport("user32.dll")] public static extern bool EnumWindows(E e, IntPtr p);
[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
[DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
public struct RECT { public int L, T, R, B; } }
"@
function SkinShots {
    Add-Type -AssemblyName System.Drawing
    $hw = [IntPtr]::Zero
    [RW]::EnumWindows({ param($h,$p) $t = New-Object Text.StringBuilder 256; [void][RW]::GetWindowText($h,$t,256); if ($t.ToString() -match 'ObsidianTodo\\Todo\.ini$') { $script:hw = $h }; return $true }, [IntPtr]::Zero) | Out-Null
    $r = New-Object RW+RECT; [void][RW]::GetWindowRect($script:hw,[ref]$r); $w = $r.R - $r.L; $h = $r.B - $r.T
    $b = New-Object Drawing.Bitmap $w, $h, ([Drawing.Imaging.PixelFormat]::Format32bppArgb); $g = [Drawing.Graphics]::FromImage($b); $g.Clear([Drawing.Color]::Magenta); $dc = $g.GetHdc(); $ok = [RW]::PrintWindow($script:hw, $dc, 2); $g.ReleaseHdc($dc); $b.Save("$out\skin-printwindow.png")
    $b2 = New-Object Drawing.Bitmap $w, $h; [Drawing.Graphics]::FromImage($b2).CopyFromScreen($r.L, $r.T, 0, 0, $b2.Size, ([Drawing.CopyPixelOperation]::SourceCopy -bor [Drawing.CopyPixelOperation]::CaptureBlt)); $b2.Save("$out\skin-captureblt.png")
    W "PrintWindow=$ok Groesse $w x $h"
}
function Wins {
    $script:ws = @()
    [RW]::EnumWindows({ param($h,$p) $c = New-Object Text.StringBuilder 256; [void][RW]::GetClassName($h,$c,256)
        if ($c.ToString() -match 'Rainmeter') { $t = New-Object Text.StringBuilder 256; [void][RW]::GetWindowText($h,$t,256); $r = New-Object RW+RECT; [void][RW]::GetWindowRect($h,[ref]$r)
            $script:ws += "$($t.ToString()) sichtbar=$([RW]::IsWindowVisible($h)) [$($r.L),$($r.T) - $($r.R),$($r.B)]" }; return $true }, [IntPtr]::Zero) | Out-Null
    $script:ws -join ' || '
}
W "Fenster: $(Wins)"
& $rm '!ZPos' '0' 'ObsidianTodo'; Start-Sleep 2; Shot 'ebene0'; W "Ebene 0: $(Wins)"
& $rm '!ZPos' '2' 'ObsidianTodo'; Start-Sleep 2; Shot 'ebene2'
& $rm '!ZPos' '-2' 'ObsidianTodo'; Start-Sleep 2
SkinShots
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
$form.Show(); [Windows.Forms.Application]::DoEvents(); Start-Sleep -Seconds 6
Shot 'vorher-verdeckt'
& $rm '!CommandMeasure' 'MeasureTodo' 'Reveal()' 'ObsidianTodo'
for ($i = 0; $i -lt 30; $i++) { Start-Sleep -Milliseconds 500; [Windows.Forms.Application]::DoEvents() }   # 15 s: Liste ueber dem blauen Fenster?
Shot 'nachher-eingeblendet'
# Ausblenden
& $rm '!CommandMeasure' 'MeasureTodo' 'HideReveal()' 'ObsidianTodo'
for ($i = 0; $i -lt 16; $i++) { Start-Sleep -Milliseconds 500; [Windows.Forms.Application]::DoEvents() }
Shot 'ausgeblendet'
$form.Close()

# Breite umstellen wie im Hilfe-Fenster
& $rm '!WriteKeyValue' 'Variables' 'Width' '560' "$env:USERPROFILE\Documents\Rainmeter\Skins\ObsidianTodo\@Resources\prefs.inc"
& $rm '!Refresh' 'ObsidianTodo'
Start-Sleep -Seconds 3
Shot 'breit'
W "prefs.inc: $((Get-Content "$res\prefs.inc" -Encoding Unicode) -join ' | ')"

Copy-Item "$env:LOCALAPPDATA\Programs\Obsidian Todo\ObsidianTodo" "$out\installiert" -Recurse -ErrorAction SilentlyContinue
# Deinstallieren
$un = Get-ChildItem "$env:LOCALAPPDATA\Programs\Obsidian Todo\unins*.exe" | Select-Object -First 1
$p = Start-Process $un.FullName -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES' -PassThru
$p.WaitForExit(); Start-Sleep -Seconds 5
W "Nach Deinstallation: Aufgabe=$([bool](Get-ScheduledTask -TaskName 'ObsidianTodo-Einblenden' -ErrorAction SilentlyContinue)) Programmordner=$(Test-Path "$env:LOCALAPPDATA\Programs\Obsidian Todo\ObsidianTodo") Todo.md=$(Test-Path "$env:USERPROFILE\Documents\Obsidian Vault\Todo.md")"
Copy-Item "$env:APPDATA\Rainmeter\Rainmeter.log" "$out\Rainmeter.log" -ErrorAction SilentlyContinue
Copy-Item "$env:LOCALAPPDATA\Programs\Obsidian Todo" "$out\installiert" -Recurse -ErrorAction SilentlyContinue
W "Ende: $(Get-Date -Format s)"
Set-Content "$out\fertig.txt" 'ok'
# Sandbox am Ende selbst schliessen
shutdown.exe /s /t 3
