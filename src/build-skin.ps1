# Erzeugt die Rainmeter-Dateien Todo.ini, Formular\Formular.ini, Einstellungen\Einstellungen.ini und Rand\Rand.ini (UTF-16 LE).
# Aufruf: powershell -File build-skin.ps1 -Out <Skin-Ordner> [-Version 1.0.0]
# Benutzerabhaengige Werte (Pfad zur Todo.md, Vault-Name) stehen in @Resources\settings.inc,
# die der Installer schreibt - hier nur Platzhalter.
param([Parameter(Mandatory)][string]$Out, [string]$Version = '0.0.0')
$skin = $Out
New-Item -ItemType Directory -Force $skin | Out-Null
$box = [char]0xE739      # Checkbox (abgerundetes Quadrat)
$boxDone = [char]0xE73D  # CheckboxCompositeReversed (ausgefuellt mit Haken)
$clip = [char]0xE723     # Attach (Bueroklammer)
$cal = [char]0xE787      # Calendar
$rep = [char]0xE8EE      # RepeatAll (wiederkehrend)
$gear = [char]0xE713     # Setting (Zahnrad)
$close = [char]0xE711    # Cancel (X)
$foldUp = [char]0xE70E   # ChevronUp (Liste offen -> einklappen)
$foldDown = [char]0xE70D # ChevronDown (Liste zu -> ausklappen)
$obs = '["obsidian://open?path=#TodoUrl#"]'

$ini = @"
; Obsidian Todo: Desktop-Liste fuer eine Todo.md im Obsidian-Vault
; Erzeugt von build-skin.ps1 - Aenderungen dort machen.
[Rainmeter]
Update=1000
AccurateText=1
DynamicWindowSize=1
; Tastenkuerzel-Helfer (Strg+Alt+T bzw. Win+Shift+T -> Neuer Punkt); laeuft nur einmal, bleibt bei Refresh bestehen
OnRefreshAction=["#@#TodoHotkey.exe" "#PROGRAMPATH#Rainmeter.exe"]
ContextTitle=Todo.md in Obsidian öffnen
ContextAction=$obs
; Seitenleiste: Maus in der Liste haelt sie offen, Verlassen laesst sie hinausfahren (sidebar.lua)
MouseOverAction=[!CommandMeasure MeasureSide "Enter()" "ObsidianTodo\Rand"]
MouseLeaveAction=[!CommandMeasure MeasureSide "Leave()" "ObsidianTodo\Rand"]

[Metadata]
Name=Obsidian Todo
Author=Obsidian Todo
Version=$Version
License=PolyForm Noncommercial 1.0.0
Information=Zeigt die Checkboxen aus Todo.md im Obsidian-Vault an.

[Variables]
; Platzhalter - die echten Werte kommen aus settings.inc (schreibt der Installer)
TodoFile=#@#Todo.md
ArchiveFile=#@#Todo-Archiv.md
VaultName=
TodoUrl=
ArchiveUrl=
@IncludeSettings=#@#settings.inc
MaxItems=15
MaxNotes=30
MaxSubs=30
Width=460
; Anzeige: sidebar (Seitenleiste am rechten Rand) | desktop | both
Mode=sidebar
LastMode=
; eigene Einstellungen (Anzeige, Breite), schreibt das Einstellungen-Fenster; bleiben bei Updates erhalten
@IncludePrefs=#@#prefs.inc
RowH=36
NoteH=30
ListTop=62
FontFace=Segoe UI
IconFace=Segoe Fluent Icons
FontSize=13
ColorBg=12,12,18,218
ColorText=255,255,255,255
ColorDone=175,175,188,240
ColorNote=232,232,240,255
ColorBox=200,200,212,255
ColorCheck=138,108,245,255
ColorAccent=165,185,255,255
ColorHover=255,255,255,22
BoxOpen=$box
BoxDone=$boxDone
ClipIcon=$clip
LinkArrow=↗
DueIcon=📅
CreatedIcon=➕
DoneIcon=✅
CancelIcon=❌
CalIcon=$cal
RepIcon=$rep
RepeatIcon=🔁
TimeIcon=⏰
NotifyText=
ColorOver=255,115,115,255
ColorToday=255,185,90,255
ColorDue=175,175,188,240
Collapsed=0
FoldOpen=$foldUp
FoldClosed=$foldDown
NewItem=
EditText=
EditX=12
EditY=0
EditW=400

[MeasureTodo]
Measure=Script
ScriptFile=#@#todo.lua
UpdateDivider=2

[MeasureInput]
Measure=Plugin
Plugin=InputText
DynamicVariables=1
X=16
Y=[MeterAdd:Y]
W=(#Width#-32)
H=#RowH#
SolidColor=32,32,42,255
FontColor=#ColorText#
FontFace=#FontFace#
FontSize=#FontSize#
FocusDismiss=1
DefaultValue=
Command1=[!SetVariable NewItem """`$UserInput`$"""][!CommandMeasure MeasureTodo "Add()"]

[MeasureEdit]
Measure=Plugin
Plugin=InputText
DynamicVariables=1
X=#EditX#
Y=#EditY#
W=#EditW#
H=#RowH#
SolidColor=32,32,42,255
FontColor=#ColorText#
FontFace=#FontFace#
FontSize=#FontSize#
FocusDismiss=1
DefaultValue=#EditText#
Command1=[!SetVariable NewItem """`$UserInput`$"""][!CommandMeasure MeasureTodo "SaveEdit()"]

[MeasureFilePick]
Measure=Plugin
Plugin=RunCommand
Program=powershell.exe
Parameter=-NoProfile -ExecutionPolicy Bypass -STA -File "#@#pick-file.ps1"
State=Hide
OutputType=UTF8
Timeout=-1
FinishAction=[!CommandMeasure MeasureTodo "FilePicked()"]

; Windows-Erinnerung fuer Punkte mit Uhrzeit (Text setzt todo.lua)
[MeasureNotify]
Measure=Plugin
Plugin=RunCommand
Program=powershell.exe
Parameter=-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "#@#notify.ps1" "#NotifyText#"
State=Hide
DynamicVariables=1
Timeout=-1

; Automatische Updates: beim Laden und dann alle 6 Stunden (update.ps1 prueft selbst hoechstens alle 6 h bei GitHub)
[MeasureUpdate]
Measure=Plugin
Plugin=RunCommand
Program=powershell.exe
Parameter=-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "#@#update.ps1"
State=Hide
Timeout=-1

[MeasureUpdateTimer]
Measure=Calc
Formula=1
UpdateDivider=21600
OnUpdateAction=[!CommandMeasure MeasureUpdate "Run"]

[MeterBg]
Meter=Shape
DynamicVariables=1
Shape=Rectangle 0,0,#Width#,120,12 | Fill Color #ColorBg# | StrokeWidth 0

[MeterTitle]
Meter=String
X=20
Y=16
FontFace=#FontFace#
FontSize=(#FontSize#+4)
FontWeight=700
FontColor=#ColorText#
AntiAlias=1
Text=Todo
LeftMouseUpAction=$obs
ToolTipText=In Obsidian öffnen

[MeterCount]
Meter=String
DynamicVariables=1
; beim Einblenden steht hier "Ausblenden" (todo.lua)
LeftMouseUpAction=[!CommandMeasure MeasureTodo "HideReveal(true)"]
X=(#Width#-62)
Y=22
StringAlign=Right
FontFace=#FontFace#
FontSize=(#FontSize#-1)
FontWeight=500
FontColor=#ColorDone#
AntiAlias=1
Text=

; Zahnrad neben dem Titel: Einstellungen ein-/ausblenden
[MeterHelp]
Meter=String
X=78
Y=14
W=38
H=38
Padding=10,10,0,0
FontFace=#IconFace#
FontSize=(#FontSize#-2)
FontColor=#ColorDone#
SolidColor=0,0,0,1
AntiAlias=1
Text=$gear
ToolTipText=Einstellungen und Hilfe
LeftMouseUpAction=[!ToggleConfig "ObsidianTodo\Einstellungen" "Einstellungen.ini"]
MouseOverAction=[!SetOption MeterHelp SolidColor "#ColorHover#"][!UpdateMeter MeterHelp][!Redraw]
MouseLeaveAction=[!SetOption MeterHelp SolidColor "0,0,0,1"][!UpdateMeter MeterHelp][!Redraw]

; Pfeil zum Ein-/Ausklappen der ganzen Liste
[MeterFold]
Meter=String
DynamicVariables=1
X=(#Width#-56)
Y=12
W=44
H=40
Padding=12,10,0,0
FontFace=#IconFace#
FontSize=(#FontSize#-3)
FontColor=#ColorDone#
SolidColor=0,0,0,1
AntiAlias=1
Text=#FoldOpen#
ToolTipText=Liste ein-/ausklappen
LeftMouseUpAction=[!CommandMeasure MeasureTodo "ToggleCollapse()"]
MouseOverAction=[!SetOption MeterFold SolidColor "#ColorHover#"][!UpdateMeter MeterFold][!Redraw]
MouseLeaveAction=[!SetOption MeterFold SolidColor "0,0,0,1"][!UpdateMeter MeterFold][!Redraw]


"@

# Checkbox-Zeile: Kaestchen als eigener Meter (<name>Box, Icon-Schrift, Farbe per Lua),
# Text rechts daneben, damit umgebrochene Zeilen unter dem Text weiterlaufen
function CheckMeter($name, $x, $h, $size, $weight, $left, $right, $tip) {
    $tx = $x + 33
@"
[${name}Box]
Meter=String
DynamicVariables=1
Hidden=1
X=$x
Y=0
W=30
Padding=8,13,0,0
FontFace=#FontFace#
FontSize=$size
FontWeight=$weight
FontColor=#ColorText#
SolidColor=0,0,0,1
AntiAlias=1
InlinePattern=^(.)
InlineSetting=Face | #IconFace#
InlinePattern2=^(.)
InlineSetting2=Size | ($size-2)
InlinePattern3=^(.)
InlineSetting3=
Text=
LeftMouseUpAction=$left
RightMouseUpAction=$right

[$name]
Meter=String
DynamicVariables=1
Hidden=1
X=$tx
Y=0
W=(#Width#-96-33)
Padding=0,6,8,6
ClipString=2
FontFace=#FontFace#
FontSize=$size
FontWeight=$weight
FontColor=#ColorText#
SolidColor=0,0,0,1
AntiAlias=1
InlinePattern=([$cal$rep].*)`$
InlineSetting=Color | #ColorDue#
InlinePattern2=([$cal$rep])
InlineSetting2=Face | #IconFace#
InlinePattern3=([$cal$rep].*)`$
InlineSetting3=Size | ($size-2)
InlinePattern4=^(.*)`$
InlineSetting4=
Text=
LeftMouseUpAction=$left
RightMouseUpAction=$right
MouseOverAction=[!SetOption $name SolidColor "#ColorHover#"][!UpdateMeter $name][!Redraw]
MouseLeaveAction=[!SetOption $name SolidColor "0,0,0,1"][!UpdateMeter $name][!Redraw]


"@
}
for ($i = 1; $i -le 15; $i++) {
    $ini += CheckMeter "Item$i" 12 '#RowH#' '#FontSize#' 600 "[!CommandMeasure MeasureTodo `"Toggle($i)`"]" "[!CommandMeasure MeasureTodo `"Edit($i)`"]" 'Linksklick: abhaken | Rechtsklick: bearbeiten'
}
for ($i = 1; $i -le 30; $i++) {
    $ini += CheckMeter "Sub$i" 36 '#NoteH#' '(#FontSize#-1)' 500 "[!CommandMeasure MeasureTodo `"ToggleSub($i)`"]" "[!CommandMeasure MeasureTodo `"EditSub($i)`"]" 'Unteraufgabe - Linksklick: abhaken | Rechtsklick: bearbeiten'
}
for ($i = 1; $i -le 15; $i++) {
$ini += @"
[Progress$i]
Meter=String
DynamicVariables=1
Hidden=1
X=(#Width#-136)
Y=0
W=50
H=#RowH#
Padding=0,7,0,0
StringAlign=Left
FontFace=#FontFace#
FontSize=(#FontSize#-2)
FontWeight=500
FontColor=#ColorDone#
AntiAlias=1
Text=

[Clip$i]
Meter=String
DynamicVariables=1
Hidden=1
X=(#Width#-82)
Y=0
W=70
H=#RowH#
Padding=0,6,0,0
StringAlign=Left
FontFace=#FontFace#
FontSize=(#FontSize#-1)
FontWeight=500
FontColor=#ColorDone#
SolidColor=0,0,0,1
AntiAlias=1
InlinePattern=^(.)
InlineSetting=Face | #IconFace#
InlinePattern2=^(.)
InlineSetting2=Size | (#FontSize#+1)
Text=
LeftMouseUpAction=[!CommandMeasure MeasureTodo "ToggleNotes($i)"]
MouseOverAction=[!SetOption Clip$i SolidColor "#ColorHover#"][!UpdateMeter Clip$i][!Redraw]
MouseLeaveAction=[!SetOption Clip$i SolidColor "0,0,0,1"][!UpdateMeter Clip$i][!Redraw]

[NoteAdd$i]
Meter=String
DynamicVariables=1
Hidden=1
X=46
Y=0
W=96
H=#NoteH#
Padding=0,4,0,0
FontFace=#FontFace#
FontSize=(#FontSize#-2)
FontWeight=500
FontColor=#ColorAccent#
SolidColor=0,0,0,1
AntiAlias=1
Text=+ Notiz
LeftMouseUpAction=[!CommandMeasure MeasureTodo "AddNote($i)"]

[SubAdd$i]
Meter=String
DynamicVariables=1
Hidden=1
X=150
Y=0
W=140
H=#NoteH#
Padding=0,4,0,0
FontFace=#FontFace#
FontSize=(#FontSize#-2)
FontWeight=500
FontColor=#ColorAccent#
SolidColor=0,0,0,1
AntiAlias=1
Text=+ Unteraufgabe
LeftMouseUpAction=[!CommandMeasure MeasureTodo "AddSub($i)"]

[FileAdd$i]
Meter=String
DynamicVariables=1
Hidden=1
X=302
Y=0
W=110
H=#NoteH#
Padding=0,4,0,0
FontFace=#FontFace#
FontSize=(#FontSize#-2)
FontWeight=500
FontColor=#ColorAccent#
SolidColor=0,0,0,1
AntiAlias=1
Text=+ Datei
LeftMouseUpAction=[!CommandMeasure MeasureTodo "PickFile($i)"]


"@
}
for ($i = 1; $i -le 30; $i++) {
$ini += @"
[Note$i]
Meter=String
DynamicVariables=1
Hidden=1
X=46
Y=0
W=(#Width#-66)
Padding=0,4,0,4
ClipString=2
FontFace=#FontFace#
FontSize=(#FontSize#-2)
FontWeight=500
FontColor=#ColorNote#
SolidColor=0,0,0,1
AntiAlias=1
InlinePattern=^(.*)`$
InlineSetting=
Text=
RightMouseUpAction=[!CommandMeasure MeasureTodo "EditNote($i)"]


"@
}
$ini += @"
[MeterMore]
Meter=String
DynamicVariables=1
Hidden=1
X=20
Y=0
FontFace=#FontFace#
FontSize=(#FontSize#-1)
FontWeight=500
FontColor=#ColorDone#
AntiAlias=1
Text=
LeftMouseUpAction=$obs

[MeterAdd]
Meter=String
DynamicVariables=1
X=20
Y=0
H=#RowH#
FontFace=#FontFace#
FontSize=#FontSize#
FontWeight=500
FontColor=#ColorAccent#
SolidColor=0,0,0,1
AntiAlias=1
Text=+ Neuer Punkt
LeftMouseUpAction=[!CommandMeasure MeasureTodo "OpenDialog(0)"]

[MeterClean]
Meter=String
DynamicVariables=1
Hidden=1
X=(#Width#-20)
Y=0
StringAlign=Right
FontFace=#FontFace#
FontSize=(#FontSize#-2)
FontWeight=500
FontColor=#ColorDone#
SolidColor=0,0,0,1
AntiAlias=1
Text=Erledigte archivieren
LeftMouseUpAction=[!CommandMeasure MeasureTodo "Cleanup()"]
"@

$ini = [regex]::Replace($ini, '(?m)^(\[(?!Rainmeter\]|Metadata\]|Variables\]|Measure|MeterBg\]|MeterTitle\]|MeterCount\]|MeterFold\]|MeterHelp\])[^\]]+\]\n)', '$1Group=List'+"`n")
[IO.File]::WriteAllText("$skin\Todo.ini", $ini, [Text.Encoding]::Unicode)

# ---------- Formular: eigene Config ObsidianTodo\Formular (neuer Punkt / bearbeiten), Logik in form.lua ----------
$fw = 560
$chevL = [char]0xE76B; $chevR = [char]0xE76C
function Act($call) { '[!CommandMeasure MeasureForm "' + $call + '"]' }
function Label($name, $text) {
@"
[$name]
Meter=String
X=22
Y=0
FontFace=#FontFace#
FontSize=10
FontWeight=600
FontColor=#ColorDone#
AntiAlias=1
Text=$text


"@
}
# Knopf mit abgerundetem Hintergrund (die Flaeche zeichnet form.lua in MeterShapes)
function Chip($name, $x, $y, $text, $call, $extra = '') {
@"
[$name]
Meter=String
X=$x
Y=$y
Padding=12,6,12,6
FontFace=#FontFace#
FontSize=11
FontWeight=600
FontColor=#ColorNote#
SolidColor=0,0,0,1
AntiAlias=1
Text=$text
LeftMouseUpAction=$(Act $call)
$extra

"@
}
$form = @"
; Formular der Obsidian-Todo-Liste. Erzeugt von ..\@Resources\build-skin.ps1 - Aenderungen dort machen.
[Rainmeter]
Update=1000
AccurateText=1
DynamicWindowSize=1

[Variables]
Width=$fw
FontFace=Segoe UI
IconFace=Segoe Fluent Icons
ColorBg=12,12,18,235
ColorText=255,255,255,255
ColorNote=225,225,235,255
ColorDone=175,175,188,240
ColorAccent=165,185,255,255
ColorCheck=138,108,245,255
ColorOver=255,115,115,255
Input=
InText=
InX=20
InY=0
InW=480
InH=34
InSize=12
InStyle=Normal

[MeasureInput]
Measure=Plugin
Plugin=InputText
DynamicVariables=1
X=#InX#
Y=#InY#
W=#InW#
H=#InH#
; Farbe wie die Feldflaeche, damit das Eingabefeld nicht als eigener Kasten auffaellt
SolidColor=30,32,39,255
FontColor=#ColorText#
FontFace=#FontFace#
FontSize=#InSize#
StringStyle=#InStyle#
FocusDismiss=1
DefaultValue=#InText#
Command1=[!SetVariable Input """`$UserInput`$"""][!CommandMeasure MeasureForm "InputDone()"]

[MeasureFilePick]
Measure=Plugin
Plugin=RunCommand
Program=powershell.exe
Parameter=-NoProfile -ExecutionPolicy Bypass -STA -File "#@#pick-file.ps1"
State=Hide
OutputType=UTF8
Timeout=-1
FinishAction=[!CommandMeasure MeasureForm "FilePicked()"]

; Logik nach den Eingabe-Measures, damit das Textfeld beim ersten Durchlauf schon bereit ist
[MeasureForm]
Measure=Script
ScriptFile=#@#form.lua

[MeterBg]
Meter=Shape
Shape=Rectangle 0,0,$fw,200,12 | Fill Color #ColorBg# | StrokeWidth 0

[MeterShapes]
Meter=Shape
Shape=Rectangle 0,0,0,0 | StrokeWidth 0

[MeterHead]
Meter=String
X=22
Y=16
FontFace=#FontFace#
FontSize=17
FontWeight=700
FontColor=#ColorText#
AntiAlias=1
Text=Neuer Punkt

[MeterClose]
Meter=String
X=($fw-50)
Y=12
W=40
H=40
Padding=13,12,0,0
FontFace=#IconFace#
FontSize=11
FontColor=#ColorDone#
SolidColor=0,0,0,1
AntiAlias=1
Text=$close
ToolTipText=Abbrechen
LeftMouseUpAction=$(Act "Click('cancel')")


"@
$form += Label 'LblTitle' 'To-do'
$form += @"
[FieldTitle]
Meter=String
X=20
Y=0
W=($fw-40-28)
Padding=16,6,12,7
ClipString=2
FontFace=#FontFace#
FontSize=13
FontWeight=600
FontColor=#ColorText#
SolidColor=0,0,0,1
AntiAlias=1
Text=
LeftMouseUpAction=$(Act "Click('title')")


"@
$form += Label 'LblDate' 'Fällig am'
$form += Chip 'DateNone' 20 0 'Kein Datum' "Click('nodate')"
$form += Chip 'DateToday' '6R' 'r' 'Heute' "Click('date', 0)"
$form += Chip 'DateTomorrow' '6R' 'r' 'Morgen' "Click('date', 1)"
$form += Chip 'DateWeek' '6R' 'r' 'In 1 Woche' "Click('date', 7)"
$form += Chip 'DateCal' '6R' 'r' 'Datum wählen' "Click('cal')"
# Kalender: Jahr (« ») und Monat (‹ ›) mit Pfeilen, Klick auf den Monat -> Monatsauswahl,
# Wochentage, 6 x 7 Tage (Spaltenbreite 74)
$form += @"
[CalPrevY]
Meter=String
X=20
Y=0
Hidden=1
Padding=12,4,12,6
FontFace=#FontFace#
FontSize=14
FontWeight=600
FontColor=#ColorNote#
SolidColor=0,0,0,1
AntiAlias=1
Text=«
ToolTipText=Jahr zurück
LeftMouseUpAction=$(Act "Click('year', -1)")

[CalNextY]
Meter=String
X=($fw-62)
Y=0
Hidden=1
Padding=12,4,12,6
FontFace=#FontFace#
FontSize=14
FontWeight=600
FontColor=#ColorNote#
SolidColor=0,0,0,1
AntiAlias=1
Text=»
ToolTipText=Jahr vor
LeftMouseUpAction=$(Act "Click('year', 1)")

[CalPrev]
Meter=String
X=70
Y=0
Hidden=1
Padding=12,8,12,8
FontFace=#IconFace#
FontSize=10
FontColor=#ColorNote#
SolidColor=0,0,0,1
AntiAlias=1
Text=$chevL
LeftMouseUpAction=$(Act "Click('month', -1)")

[CalMonth]
Meter=String
X=($fw/2)
Y=0
Hidden=1
StringAlign=Center
FontFace=#FontFace#
FontSize=12
FontWeight=700
FontColor=#ColorText#
SolidColor=0,0,0,1
AntiAlias=1
Text=
ToolTipText=Monat oder Jahr auswählen
LeftMouseUpAction=$(Act "Click('monthview')")

[CalNext]
Meter=String
X=($fw-110)
Y=0
Hidden=1
Padding=12,8,12,8
FontFace=#IconFace#
FontSize=10
FontColor=#ColorNote#
SolidColor=0,0,0,1
AntiAlias=1
Text=$chevR
LeftMouseUpAction=$(Act "Click('month', 1)")


"@
$wd = 'Mo','Di','Mi','Do','Fr','Sa','So'
for ($k = 0; $k -lt 7; $k++) {
    $form += @"
[Wd$($k+1)]
Meter=String
X=$(20 + $k*74 + 37)
Y=0
Hidden=1
StringAlign=Center
FontFace=#FontFace#
FontSize=10
FontWeight=600
FontColor=#ColorDone#
AntiAlias=1
Text=$($wd[$k])


"@
}
for ($k = 1; $k -le 42; $k++) {
    $col = ($k - 1) % 7
    $form += @"
[Day$k]
Meter=String
X=$(20 + $col*74 + 37)
Y=0
W=60
H=26
Hidden=1
Padding=0,6,0,0
StringAlign=Center
FontFace=#FontFace#
FontSize=11
FontWeight=600
FontColor=#ColorNote#
SolidColor=0,0,0,1
AntiAlias=1
Text=
LeftMouseUpAction=$(Act "Click('day', $k)")


"@
}
# Monatsauswahl (X setzt form.lua)
$months3 = 'Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'
for ($k = 1; $k -le 12; $k++) {
    $form += @"
[Mon$k]
Meter=String
X=0
Y=0
W=110
H=26
Hidden=1
Padding=0,6,0,0
StringAlign=Center
FontFace=#FontFace#
FontSize=11
FontWeight=600
FontColor=#ColorNote#
SolidColor=0,0,0,1
AntiAlias=1
Text=$($months3[$k-1])
LeftMouseUpAction=$(Act "Click('pickmonth', $k)")


"@
}
$form += Label 'LblTime' 'Uhrzeit (mit Windows-Erinnerung)'
$form += Chip 'TimeNone' 20 0 'Keine' "Click('notime')"
$times = '09:00','12:00','15:00','18:00','21:00'
for ($k = 1; $k -le 5; $k++) { $form += Chip "Time$k" '6R' 'r' $times[$k-1] "Click('time', $k)" }
$form += Chip 'TimeOther' '6R' 'r' 'Andere' "Click('timeother')"
# Uhr: grosse Anzeige HH:MM (Stunde/Minute anklickbar) und 24 Zahlen auf dem Zifferblatt (Position setzt form.lua)
$form += @"
[ClockH]
Meter=String
X=($fw/2-8)
Y=0
Hidden=1
StringAlign=Right
Padding=8,0,4,0
FontFace=#FontFace#
FontSize=26
FontWeight=700
FontColor=#ColorText#
SolidColor=0,0,0,1
AntiAlias=1
Text=12
ToolTipText=Stunde wählen
LeftMouseUpAction=$(Act "Click('clockmode', 'h')")

[ClockColon]
Meter=String
X=($fw/2)
Y=0
Hidden=1
StringAlign=Center
FontFace=#FontFace#
FontSize=26
FontWeight=700
FontColor=#ColorDone#
AntiAlias=1
Text=:

[ClockM]
Meter=String
X=($fw/2+8)
Y=0
Hidden=1
Padding=4,0,8,0
FontFace=#FontFace#
FontSize=26
FontWeight=700
FontColor=#ColorDone#
SolidColor=0,0,0,1
AntiAlias=1
Text=00
ToolTipText=Minute wählen
LeftMouseUpAction=$(Act "Click('clockmode', 'm')")


"@
for ($k = 1; $k -le 24; $k++) {
    $form += @"
[Clock$k]
Meter=String
X=0
Y=0
W=34
H=34
Hidden=1
StringAlign=CenterCenter
FontFace=#FontFace#
FontSize=11
FontWeight=600
FontColor=#ColorNote#
SolidColor=0,0,0,1
AntiAlias=1
Text=
LeftMouseUpAction=$(Act "Click('clock', $k)")


"@
}
$form += Chip 'ClockCancel' 20 0 'Abbrechen' "Click('clockcancel')"
$form += Chip 'ClockOk' '6R' 'r' 'Übernehmen' "Click('clockok')"
$form += Label 'LblRule' 'Wiederholen'
# Jaehrlich hat keinen eigenen Knopf mehr (passt sonst nicht in eine Zeile) -> Individuell, "Alle 1 Jahre"
$rules = 'Nie','Täglich','Werktags','Wöchentlich','Monatlich'
for ($k = 1; $k -le 5; $k++) { $form += Chip "Rule$k" $(if ($k -eq 1) { 20 } else { '6R' }) $(if ($k -eq 1) { 0 } else { 'r' }) $rules[$k-1] "Click('rule', $k)" }
$form += Chip 'Rule7' '6R' 'r' 'Individuell' "Click('custom')"
# eigene Wiederholung: "Alle [-] N [+] Tage|Wochen|Monate|Jahre" oder Wochentage
$form += @"
[CustAlle]
Meter=String
X=22
Y=0
Hidden=1
Padding=0,6,0,6
FontFace=#FontFace#
FontSize=11
FontWeight=600
FontColor=#ColorNote#
AntiAlias=1
Text=Alle


"@
$form += Chip 'CustMinus' '10R' 'r' '–' "Click('custn', -1)"
$form += @"
[CustN]
Meter=String
X=4R
Y=r
W=30
Hidden=1
Padding=0,6,0,6
StringAlign=Left
FontFace=#FontFace#
FontSize=12
FontWeight=700
FontColor=#ColorText#
AntiAlias=1
Text=1
InlinePattern=.*
InlineSetting=Face | #FontFace#


"@
$form += Chip 'CustPlus' '4R' 'r' '+' "Click('custn', 1)"
$units = 'Tage','Wochen','Monate','Jahre'
for ($k = 1; $k -le 4; $k++) { $form += Chip "CustU$k" $(if ($k -eq 1) { '6R' } else { '6R' }) 'r' $units[$k-1] "Click('custu', $k)" }
$form += @"
[CustOder]
Meter=String
X=22
Y=0
Hidden=1
FontFace=#FontFace#
FontSize=10
FontWeight=600
FontColor=#ColorDone#
AntiAlias=1
Text=oder an bestimmten Wochentagen:


"@
for ($k = 1; $k -le 7; $k++) { $form += Chip "CustWd$k" $(if ($k -eq 1) { 20 } else { '6R' }) $(if ($k -eq 1) { 0 } else { 'r' }) $wd[$k-1] "Click('custwd', $k)" }
$form += @"
[Summary]
Meter=String
X=20
Y=0
W=($fw-40-24)
Padding=12,8,12,8
ClipString=2
FontFace=#FontFace#
FontSize=11
FontWeight=600
FontColor=#ColorAccent#
AntiAlias=1
Text=


"@
$form += Label 'LblNotes' 'Notizen, Links, Dateien'
for ($k = 1; $k -le 8; $k++) {
    $form += @"
[Note$k]
Meter=String
X=20
Y=0
W=($fw-40-24-40)
Hidden=1
Padding=12,7,12,7
ClipString=2
FontFace=#FontFace#
FontSize=11
FontColor=#ColorNote#
SolidColor=0,0,0,1
AntiAlias=1
Text=
ToolTipText=Klicken zum Bearbeiten
LeftMouseUpAction=$(Act "Click('note', $k)")

[NoteDel$k]
Meter=String
X=($fw-58)
Y=0
Hidden=1
Padding=12,9,12,7
FontFace=#IconFace#
FontSize=9
FontColor=#ColorDone#
SolidColor=0,0,0,1
AntiAlias=1
Text=$close
ToolTipText=Notiz entfernen
LeftMouseUpAction=$(Act "Click('notedel', $k)")


"@
}
$form += Chip 'NoteAdd' 20 0 '+ Notiz / Link' "Click('noteadd')"
$form += Chip 'FileAdd' '6R' 'r' '+ Datei' "Click('file')"
$form += Chip 'BtnDelete' 20 0 'Löschen' "Click('delete')"
$form += Chip 'BtnCancel' 0 0 'Abbrechen' "Click('cancel')"
$form += Chip 'BtnSave' 0 0 'Speichern' "Click('save')"
$form = $form.Replace("[BtnSave]`nMeter=String", "[BtnSave]`nMeter=String`nFontWeight=700").Replace("[BtnSave]`r`nMeter=String", "[BtnSave]`r`nMeter=String`r`nFontWeight=700")
New-Item -ItemType Directory -Force "$skin\Formular" | Out-Null
[IO.File]::WriteAllText("$skin\Formular\Formular.ini", $form, [Text.Encoding]::Unicode)

# ---------- Einstellungen-Fenster: Config ObsidianTodo\Einstellungen, geoeffnet ueber das Zahnrad ----------
# Anzeige (Seitenleiste/Desktop/beides) und Breite schreiben in prefs.inc (bleibt bei Updates erhalten).
# Darunter die Kurzhilfe: "#..." = Ueberschrift, sonst "Stichwort: Erklaerung" (Stichwort fett)
$helpLines = @(
    '#So funktioniert''s'
    'Klick: Punkt abhaken (nochmal klicken = rückgängig)'
    'Rechtsklick: Punkt bearbeiten oder löschen'
    '+ Neuer Punkt: neuen Punkt anlegen, überall auch mit Strg+Alt+T'
    'Enter: speichert den Punkt sofort (Datum vorher wählen oder später ergänzen)'
    'Titel „Todo“: Liste in Obsidian öffnen'
    'Seitenleiste: Maus an den rechten Bildschirmrand – die Liste fährt herein'
    'Anmelden, Aufwachen, Entsperren: die Liste kommt kurz von selbst (10 Sekunden pro offenem Punkt)'
    'Farben: orange = heute fällig, rot = überfällig'
    'Erledigte archivieren: abgehakte Punkte wandern ins Archiv'
)
$hw = 600
$archive = '["obsidian://open?path=#ArchiveUrl#"]'
function SetChip($name, $x, $y, $text, $action) {
@"
[$name]
Meter=String
X=$x
Y=$y
Padding=14,6,14,6
FontFace=#FontFace#
FontSize=11
FontWeight=600
FontColor=#ColorNote#
SolidColor=255,255,255,16
AntiAlias=1
Text=$text
LeftMouseUpAction=$action


"@
}
function Caption($name, $text) {
@"
[$name]
Meter=String
X=22
Y=22R
FontFace=#FontFace#
FontSize=13
FontWeight=700
FontColor=#ColorAccent#
AntiAlias=1
Text=$text


"@
}
$sel = '[!SetOption {0} SolidColor "138,108,245,255"][!SetOption {0} FontColor "#ColorText#"]'
$hini = @"
; Einstellungen der Obsidian-Todo-Liste. Erzeugt von build-skin.ps1 - Aenderungen dort machen.
[Rainmeter]
Update=1000
AccurateText=1
DynamicWindowSize=1
; immer im Vordergrund und mittig auf dem Hauptbildschirm (auch wenn die Liste in der Seitenleiste steckt)
OnRefreshAction=[!ZPos 2][!SetWindowPosition "50%" "50%" "50%" "50%"]

[Variables]
ArchiveUrl=
@IncludeSettings=#@#settings.inc
Width=460
Mode=sidebar
@IncludePrefs=#@#prefs.inc
FontFace=Segoe UI
IconFace=Segoe Fluent Icons
ColorBg=12,12,18,235
ColorText=255,255,255,255
ColorNote=200,200,212,255
ColorDone=175,175,188,240
ColorAccent=165,185,255,255
ColorHover=255,255,255,22

; ausgewaehlte Knoepfe lila
[MeasureMode]
Measure=String
String=#Mode#
IfMatch=^sidebar$
IfMatchAction=$($sel -f 'Mode1')
IfMatch2=^desktop$
IfMatchAction2=$($sel -f 'Mode2')
IfMatch3=^both$
IfMatchAction3=$($sel -f 'Mode3')

[MeasureWidth]
Measure=Calc
Formula=#Width#
IfCondition=MeasureWidth < 420
IfTrueAction=$($sel -f 'Width1')
IfCondition2=(MeasureWidth >= 420) && (MeasureWidth < 520)
IfTrueAction2=$($sel -f 'Width2')
IfCondition3=MeasureWidth >= 520
IfTrueAction3=$($sel -f 'Width3')

[MeterBg]
Meter=Shape
DynamicVariables=1
Shape=Rectangle 0,0,$hw,([MeterEnd:Y]+[MeterEnd:H]+18),12 | Fill Color #ColorBg# | StrokeWidth 0

[MeterTitle]
Meter=String
X=22
Y=16
FontFace=#FontFace#
FontSize=17
FontWeight=700
FontColor=#ColorText#
AntiAlias=1
Text=Einstellungen

[MeterClose]
Meter=String
X=($hw-50)
Y=12
W=40
H=40
Padding=13,12,0,0
FontFace=#IconFace#
FontSize=11
FontColor=#ColorDone#
SolidColor=0,0,0,1
AntiAlias=1
Text=$close
LeftMouseUpAction=[!DeactivateConfig]
MouseOverAction=[!SetOption MeterClose SolidColor "#ColorHover#"][!UpdateMeter MeterClose][!Redraw]
MouseLeaveAction=[!SetOption MeterClose SolidColor "0,0,0,1"][!UpdateMeter MeterClose][!Redraw]


"@
$hini += (Caption 'CapMode' 'Anzeige').Replace('Y=22R', 'Y=62')
$modes = @(@('Mode1', 'Seitenleiste', 'sidebar'), @('Mode2', 'Desktop', 'desktop'), @('Mode3', 'Beides', 'both'))
$x = '22'; $y = '10R'
foreach ($m in $modes) {
    $hini += SetChip $m[0] $x $y $m[1] "[!WriteKeyValue Variables Mode $($m[2]) `"#@#prefs.inc`"][!Refresh ObsidianTodo][!Refresh]"
    $x = '8R'; $y = 'r'
}
$hini += @"
[ModeInfo]
Meter=String
X=22
Y=8R
W=($hw-44)
ClipString=2
FontFace=#FontFace#
FontSize=10
FontColor=#ColorDone#
AntiAlias=1
Text=Seitenleiste: unsichtbar, fährt am rechten Bildschirmrand herein. Desktop: liegt auf dem Hintergrund. Beides: liegt auf dem Desktop und kommt am Rand nach vorne.


"@
$hini += Caption 'CapWidth' 'Breite'
$x = '22'; $y = '10R'
foreach ($w in @(@('Width1', 'Schmal', 380), @('Width2', 'Normal', 460), @('Width3', 'Breit', 560))) {
    $hini += SetChip $w[0] $x $y $w[1] "[!WriteKeyValue Variables Width $($w[2]) `"#@#prefs.inc`"][!Refresh ObsidianTodo][!Refresh ObsidianTodo\Rand][!Refresh]"
    $x = '8R'; $y = 'r'
}
$n = 0
foreach ($l in $helpLines) {
    $n++
    if ($l.StartsWith('#')) { $hini += Caption "Line$n" $l.Substring(1); continue }
    $hini += @"
[Line$n]
Meter=String
X=22
Y=4R
W=($hw-44)
ClipString=2
FontFace=#FontFace#
FontSize=11
FontColor=#ColorNote#
AntiAlias=1
InlinePattern=^([^:]+:)
InlineSetting=Weight | 700
InlinePattern2=^([^:]+:)
InlineSetting2=Color | #ColorText#
Text=$l


"@
}
$hini += @"
[MeterArchive]
Meter=String
X=22
Y=18R
FontFace=#FontFace#
FontSize=11
FontWeight=600
FontColor=#ColorAccent#
SolidColor=0,0,0,1
AntiAlias=1
Text=Archiv öffnen ↗
LeftMouseUpAction=$archive

[MeterEnd]
Meter=String
X=($hw-22)
Y=r
StringAlign=Right
FontFace=#FontFace#
FontSize=10
FontColor=#ColorDone#
AntiAlias=1
Text=Version $Version
"@
New-Item -ItemType Directory -Force "$skin\Einstellungen" | Out-Null
[IO.File]::WriteAllText("$skin\Einstellungen\Einstellungen.ini", $hini, [Text.Encoding]::Unicode)

# ---------- Rand-Streifen fuer die Seitenleiste: Config ObsidianTodo\Rand (Logik in sidebar.lua) ----------
$rand = @"
; Unsichtbarer Streifen am rechten Bildschirmrand: Maus dagegen -> Liste faehrt herein. Erzeugt von build-skin.ps1.
[Rainmeter]
; schnelle Aktualisierung nur fuer die Animation; ohne Animation tut sidebar.lua nichts
Update=16
AccurateText=1
OnRefreshAction=[!ZPos 2][!Draggable 0][!KeepOnScreen 0][!ClickThrough 0][!SnapEdges 0]

[Variables]
Width=460
Mode=sidebar
@IncludePrefs=#@#prefs.inc

[MeasureSide]
Measure=Script
ScriptFile=#@#sidebar.lua

; 1 Pixel breit; Deckkraft 1 von 255 reicht, damit Rainmeter die Maus bemerkt
[MeterEdge]
Meter=Image
W=1
H=1080
SolidColor=0,0,0,1
MouseOverAction=[!CommandMeasure MeasureSide "EdgeHit()"]
"@
New-Item -ItemType Directory -Force "$skin\Rand" | Out-Null
[IO.File]::WriteAllText("$skin\Rand\Rand.ini", $rand, [Text.Encoding]::Unicode)
