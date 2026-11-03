# Baut Obsidian Todo: dist\skin\ObsidianTodo (fertiger Rainmeter-Skin) und dist\ObsidianTodo-Setup.exe
# Aufruf: powershell -File build.ps1 [-Repo besitzer/obsidian-todo] [-Iscc <Pfad zu ISCC.exe>]
# ISCC.exe wird sonst ueber die Umgebungsvariable ISCC oder die Standard-Installationsorte gesucht.
param(
    [string]$Repo = '',
    [string]$Iscc = ''
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$src = Join-Path $root 'src'
$dist = Join-Path $root 'dist'
$skin = Join-Path $dist 'skin\ObsidianTodo'
$res = Join-Path $skin '@Resources'
$version = (Get-Content (Join-Path $root 'VERSION') -TotalCount 1).Trim()
if (-not $Repo -and (Test-Path (Join-Path $root 'REPO'))) { $Repo = (Get-Content (Join-Path $root 'REPO') -TotalCount 1).Trim() }

Write-Host "Obsidian Todo $version"
# nur die eigenen Ausgaben loeschen (das Linux-Setup liegt auch in dist\)
if (Test-Path (Join-Path $dist 'skin')) { Remove-Item (Join-Path $dist 'skin') -Recurse -Force }
Get-ChildItem $dist -Filter 'ObsidianTodo-Setup*.exe' -ErrorAction SilentlyContinue | Remove-Item -Force
New-Item -ItemType Directory -Force $res | Out-Null

# 1. Rainmeter-Dateien erzeugen
& (Join-Path $src 'build-skin.ps1') -Out $skin -Version $version

# 2. Lua als UTF-16 LE (sonst zeigt Rainmeter Umlaute/Emoji falsch an), Hilfsskripte kopieren
foreach ($f in 'todo.lua', 'form.lua', 'sidebar.lua', 'settings.lua') {
    [IO.File]::WriteAllText((Join-Path $res $f), [IO.File]::ReadAllText((Join-Path $src $f), [Text.Encoding]::UTF8), [Text.Encoding]::Unicode)
}
foreach ($f in 'notify.ps1', 'pick-file.ps1', 'update.ps1', 'choose-todo.ps1', 'toast-action.vbs') { Copy-Item (Join-Path $src $f) $res }
$ascii = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $res 'version.txt'), $version, $ascii)
[IO.File]::WriteAllText((Join-Path $res 'repo.txt'), $Repo, $ascii)

# 3. Tastenkuerzel-Programm mit dem C#-Compiler aus .NET Framework 4 (auf jedem Windows 10/11 vorhanden)
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:winexe /optimize+ "/out:$(Join-Path $res 'TodoHotkey.exe')" (Join-Path $src 'hotkey.cs')
if ($LASTEXITCODE -ne 0) { throw 'hotkey.cs liess sich nicht kompilieren' }

# 4. Setup bauen
if (-not $Iscc) {
    $Iscc = @($env:ISCC, "$env:LOCALAPPDATA\Programs\Inno Setup 7\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe", "$env:ProgramFiles\Inno Setup 7\ISCC.exe") |
        Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $Iscc) { throw 'ISCC.exe (Inno Setup 7) nicht gefunden - Pfad mit -Iscc angeben' }
& $Iscc /Q "/DAppVersion=$version" (Join-Path $root 'installer\ObsidianTodo.iss')
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup meldet einen Fehler' }
Write-Host "Fertig: $(Join-Path $dist "ObsidianTodo-Setup-$version.exe")"
