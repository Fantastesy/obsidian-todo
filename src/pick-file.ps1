# Datei-Auswahl fuer "+ Datei": gibt die gewaehlten Pfade (eine pro Zeile, UTF-8) aus.
Add-Type -AssemblyName System.Windows.Forms
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# unsichtbares Fenster als Besitzer, damit der Dialog vor allen anderen Fenstern erscheint
$owner = New-Object Windows.Forms.Form
$owner.TopMost = $true
$owner.ShowInTaskbar = $false

$dialog = New-Object Windows.Forms.OpenFileDialog
$dialog.Title = 'Datei an Todo anhängen'
$dialog.Multiselect = $true
$dialog.Filter = 'Alle Dateien (*.*)|*.*'

if ($dialog.ShowDialog($owner) -eq [Windows.Forms.DialogResult]::OK) {
    [Console]::Out.Write(($dialog.FileNames -join "`n"))
}
$owner.Dispose()
