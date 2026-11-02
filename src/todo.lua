-- Obsidian-Todo: zeigt die Checkbox-Zeilen (- [ ] / - [x]) einer Markdown-Datei
-- an und schreibt Aenderungen (abhaken, neu, bearbeiten, aufraeumen) direkt in die Datei zurueck.
-- Eingerueckte Checkboxen unter einem Punkt sind Unteraufgaben (immer sichtbar),
-- andere eingerueckte Zeilen sind Notizen (aufklappbar, Links anklickbar).
-- Datei muss als UTF-16 LE gespeichert sein, sonst behandelt Rainmeter Umlaute als ANSI.

local path, maxItems, maxNotes, maxSubs, rowH, noteH, listTop, width, vault
local lines, display, bom, nl, lastContent, lastOpen, lastDone
local itemY, addY, noteMap, subMap = {}, {}, {}, {}
local expanded = {}
-- laufende Bearbeitung: mode = 'task' | 'note' | 'addnote' | 'sub' | 'addsub'
local edit
local dueIcon, collapsed
-- Archiv und Zeitstempel: "➕ 2026-11-01" erstellt, "✅ 2026-11-03" erledigt, "❌ …" geloescht
local archivePath, createdIcon, doneIcon, cancelIcon
-- Wiederholung "🔁 täglich" und Uhrzeit "⏰ 15:00"
local repeatIcon, timeIcon
local notified, lastMinute = {}, nil
-- Einblenden beim Anmelden/Aufwachen/Entsperren: bis revealUntil ueber allen Fenstern
local revealUntil, lastTick = nil, os.time()
-- Einblenden angefordert, bevor die Datei lesbar war (z. B. Cloud-Ordner direkt nach der Anmeldung)
local pendingReveal

local CHECK = '^%s*[-*+] %[([ xX])%] ?(.*)$'

function Initialize()
	path = SKIN:GetVariable('TodoFile')
	vault = SKIN:GetVariable('VaultName')
	maxItems = tonumber(SKIN:GetVariable('MaxItems')) or 15
	maxNotes = tonumber(SKIN:GetVariable('MaxNotes')) or 30
	maxSubs = tonumber(SKIN:GetVariable('MaxSubs')) or 30
	rowH = tonumber(SKIN:GetVariable('RowH')) or 34
	noteH = tonumber(SKIN:GetVariable('NoteH')) or 28
	listTop = tonumber(SKIN:GetVariable('ListTop')) or 60
	width = tonumber(SKIN:GetVariable('Width')) or 440
	dueIcon = SKIN:GetVariable('DueIcon')
	collapsed = SKIN:GetVariable('Collapsed') == '1'
	archivePath = SKIN:GetVariable('ArchiveFile')
	createdIcon = SKIN:GetVariable('CreatedIcon')
	doneIcon = SKIN:GetVariable('DoneIcon')
	cancelIcon = SKIN:GetVariable('CancelIcon')
	repeatIcon = SKIN:GetVariable('RepeatIcon')
	timeIcon = SKIN:GetVariable('TimeIcon')
	lastContent = nil
	setupMode()
end

-- ---------- Anzeige-Art: 'sidebar' (Seitenleiste am rechten Rand), 'desktop', 'both' ----------
-- Variable Mode aus prefs.inc (schreibt das Einstellungen-Fenster). Der Rand-Streifen (Config ObsidianTodo\Rand)
-- wird hier mit ein- bzw. ausgeschaltet, damit es auch nach Updates ohne Installer-Zutun stimmt.
local RAND = 'ObsidianTodo\\Rand'
local mode, workH
local panel = false              -- 'both': gerade als Panel am Rand (sidebar.lua: PanelOn/PanelOff)
local deskX, deskY               -- 'both': Desktop-Platz, an den die Liste danach zurueckkehrt
local hideOnFirstUpdate = false
function setupMode()
	-- Hintergrund-Deckkraft aus den Einstellungen
	SKIN:Bang('!SetVariable', 'ColorBg', '12,12,18,' .. (tonumber(SKIN:GetVariable('Opacity')) or 218))
	mode = SKIN:GetVariable('Mode') or 'sidebar'
	workH = tonumber(SKIN:GetVariable('WORKAREAHEIGHT')) or 1080
	if mode == 'sidebar' then
		-- versteckt, bis die Maus an den Rand kommt; darf ausserhalb des Bildschirms stehen (Animation)
		SKIN:Bang('!KeepOnScreen', '0')
		SKIN:Bang('!Draggable', '0')
		SKIN:Bang('!ZPos', '2')
		-- !Hide wirkt erst, wenn Rainmeter das Fenster angelegt hat -> im ersten Update
		hideOnFirstUpdate = true
	else
		if mode == 'both' then SKIN:Bang('!SetAnchor', '0', '0') end
		SKIN:Bang('!KeepOnScreen', '1')
		SKIN:Bang('!Draggable', '1')
		SKIN:Bang('!ZPos', '-2')
		SKIN:Bang('!Show')
		-- kommt von der Seitenleiste: wieder oben rechts auf den Desktop
		if SKIN:GetVariable('LastMode') == 'sidebar' then
			local right = (tonumber(SKIN:GetVariable('WORKAREAX')) or 0) + (tonumber(SKIN:GetVariable('WORKAREAWIDTH')) or 1920)
			SKIN:Bang('!SetAnchor', '0', '0')
			SKIN:Bang('!Move', right - 24 - width, (tonumber(SKIN:GetVariable('WORKAREAY')) or 0) + 60)
		end
	end
	if SKIN:GetVariable('LastMode') ~= mode then
		SKIN:Bang('!WriteKeyValue', 'Variables', 'LastMode', mode, '#@#prefs.inc')
	end
	if mode == 'desktop' then
		SKIN:Bang('!DeactivateConfig', RAND)
	else
		SKIN:Bang('!ActivateConfig', RAND, 'Rand.ini')
		SKIN:Bang('!Refresh', RAND)
	end
end

local function readFile()
	local f = io.open(path, 'rb')
	if not f then return nil end
	local c = f:read('*a')
	f:close()
	return c
end

local function indentOf(line)
	local ws = line:match('^(%s*)')
	return #ws:gsub('\t', '    ')
end

-- Faelligkeitsdatum: "📅 2026-11-05" (Format des Obsidian-Tasks-Plugins), freiwillig
local WEEKDAYS = { 'So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa' }
local WD_INPUT = { so = 1, sonntag = 1, mo = 2, montag = 2, di = 3, dienstag = 3, mi = 4, mittwoch = 4,
	['do'] = 5, donnerstag = 5, fr = 6, freitag = 6, sa = 7, samstag = 7 }

local function today()
	local d = os.date('*t')
	return os.time({ year = d.year, month = d.month, day = d.day, hour = 12 })
end

local function dueOf(text)
	local y, m, d = text:match(dueIcon .. '%s*(%d%d%d%d)%-(%d%d)%-(%d%d)')
	if not y then return nil end
	return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

-- Wiederholung "🔁 …" reicht bis zum naechsten Symbol (Emojis beginnen mit Byte 226 bzw. 240),
-- damit auch "🔁 alle 2 Wochen" oder "🔁 Mo,Mi,Fr" gehen
local function repPattern() return '%s*' .. repeatIcon .. '[^\226\240]*[^%s\226\240]' end

local function stripDue(text)
	text = text:gsub('%s*' .. dueIcon .. '%s*%d%d%d%d%-%d%d%-%d%d', '')
	text = text:gsub(repPattern(), '')
	return (text:gsub('%s*' .. timeIcon .. '%s*%d%d?:%d%d', ''))
end

-- Wiederholung und Uhrzeit
local RULES = { ['täglich'] = 'täglich', taeglich = 'täglich', werktags = 'werktags',
	['wöchentlich'] = 'wöchentlich', woechentlich = 'wöchentlich', monatlich = 'monatlich',
	['jährlich'] = 'jährlich', jaehrlich = 'jährlich' }
local function ruleOf(text)
	local r = text:match(repeatIcon .. '%s*([^\226\240]*[^%s\226\240])')
	return r
end
local function timeOf(text)
	local h, m = text:match(timeIcon .. '%s*(%d%d?):(%d%d)')
	if h then return tonumber(h), tonumber(m) end
end

-- naechster Termin nach "due" (nicht vor heute)
-- Regeln: täglich, werktags, wöchentlich, monatlich, jährlich, "alle N Tage|Wochen|Monate|Jahre", "Mo,Mi,Fr"
local WDNUM = { So = 1, Mo = 2, Di = 3, Mi = 4, Do = 5, Fr = 6, Sa = 7 }
local function nextDate(due, rule)
	local days
	if rule == 'werktags' then rule = 'Mo,Di,Mi,Do,Fr' end
	-- Wochentagsliste: nur Kuerzel und Kommas, nie drei Buchstaben am Stueck
	if rule:match('^[%a,]+$') and not rule:find('%a%a%a') then
		for d in rule:gmatch('%a%a') do
			if WDNUM[d] then days = days or {}; days[WDNUM[d]] = true end
		end
	end
	local n, unit = rule:match('^alle (%d+) (%S+)$')
	n = tonumber(n)
	local function step(t)
		local d = os.date('*t', t)
		if days then
			-- naechster passender Wochentag
			repeat
				d.day = d.day + 1
				d.hour = 12
				d = os.date('*t', os.time(d))
			until days[d.wday]
		elseif n then
			if unit == 'Wochen' then d.day = d.day + 7 * n
			elseif unit == 'Monate' then d.month = d.month + n
			elseif unit == 'Jahre' then d.year = d.year + n
			else d.day = d.day + n end
		elseif rule == 'wöchentlich' then d.day = d.day + 7
		elseif rule == 'monatlich' then d.month = d.month + 1
		elseif rule == 'jährlich' then d.year = d.year + 1
		else d.day = d.day + 1 end
		d.hour = 12
		return os.time(d)
	end
	local n = step(due or today())
	while n < today() do n = step(n) end
	return n
end

-- Zeitstempel (➕ erstellt, ✅ erledigt): auf dem Desktop und im Textfeld unsichtbar, bleiben beim Bearbeiten erhalten
local DATE = '%d%d%d%d%-%d%d%-%d%d'
local function stamp(icon) return ' ' .. icon .. ' ' .. os.date('%Y-%m-%d') end
local function stripStamps(text)
	for _, icon in ipairs({ createdIcon, doneIcon }) do text = text:gsub('%s*' .. icon .. '%s*' .. DATE, '') end
	return text
end
local function stampsOf(text)
	local s = ''
	for _, icon in ipairs({ createdIcon, doneIcon }) do
		local d = text:match(icon .. '%s*(' .. DATE .. ')')
		if d then s = s .. ' ' .. icon .. ' ' .. d end
	end
	return s
end

-- "@heute", "@morgen", "@übermorgen", "@fr"/"@freitag", "@05.11.", "@05.11.2027"
local function resolveDate(tok)
	local base = today()
	tok = tok:lower()
	if tok == 'heute' then return base end
	if tok == 'morgen' then return base + 86400 end
	if tok == 'übermorgen' or tok == 'uebermorgen' then return base + 2 * 86400 end
	local wd = WD_INPUT[tok]
	if wd then
		return base + ((wd - os.date('*t', base).wday) % 7) * 86400
	end
	local d, m, y = tok:match('^(%d%d?)%.(%d%d?)%.?(%d*)$')
	if d then
		local year = tonumber(y) or os.date('*t', base).year
		if year < 100 then year = year + 2000 end
		local t = os.time({ year = year, month = tonumber(m), day = tonumber(d), hour = 12 })
		-- ohne Jahr und schon vorbei -> naechstes Jahr
		if y == '' and t < base then t = os.time({ year = year + 1, month = tonumber(m), day = tonumber(d), hour = 12 }) end
		return t
	end
end

-- "@täglich" -> "🔁 täglich", "@15:00" -> "⏰ 15:00"; Wiederholung/Uhrzeit ohne Datum -> ab heute
local function convertDates(text)
	text = text:gsub('@(%S+)', function(tok)
		local rule = RULES[tok:lower()]
		if rule then return repeatIcon .. ' ' .. rule end
		local h, m = tok:match('^(%d%d?):(%d%d)$')
		if h then return timeIcon .. ' ' .. string.format('%02d:%s', tonumber(h), m) end
		local t = resolveDate(tok)
		if t then return dueIcon .. ' ' .. os.date('%Y-%m-%d', t) end
	end)
	if (ruleOf(text) or timeOf(text)) and not dueOf(text) then
		text = text .. ' ' .. dueIcon .. ' ' .. os.date('%Y-%m-%d')
	end
	return text
end

-- fuers Textfeld zurueck: "📅 2026-11-05" -> "@05.11.2026", "🔁 täglich" -> "@täglich", "⏰ 15:00" -> "@15:00"
local function datesToInput(text)
	text = text:gsub(repeatIcon .. '%s*(%S+)', '@%1')
	text = text:gsub(timeIcon .. '%s*(%d%d?:%d%d)', '@%1')
	return (text:gsub(dueIcon .. '%s*(%d%d%d%d)%-(%d%d)%-(%d%d)', function(y, m, d) return '@' .. d .. '.' .. m .. '.' .. y end))
end

local function dueLabel(due, done, v, h, mi)
	local n = math.floor((due - today()) / 86400 + 0.5)
	local label
	if n == 0 then label = 'heute'
	elseif n == 1 then label = 'morgen'
	elseif n == -1 then label = 'gestern'
	elseif n > 1 and n < 7 then label = WEEKDAYS[os.date('*t', due).wday]
	else label = os.date('%d.%m.', due) end
	if h then label = label .. ' ' .. string.format('%02d:%02d', h, mi) end
	if done then return label, v.colDone end
	if n < 0 then return label, v.colOver end
	-- heute und Uhrzeit schon vorbei -> rot
	local now = os.date('*t')
	if n == 0 and h and now.hour * 60 + now.min >= h * 60 + mi then return label, v.colOver end
	if n == 0 then return label, v.colToday end
	return label, v.colDue
end

local function parse(c)
	bom = ''
	if c:sub(1, 3) == '\239\187\191' then
		bom = c:sub(1, 3)
		c = c:sub(4)
	end
	nl = c:find('\r\n', 1, true) and '\r\n' or '\n'
	lines = {}
	local open, done = {}, {}
	local current
	for line in (c .. '\n'):gmatch('(.-)\r?\n') do
		lines[#lines + 1] = line
		local mark, text = line:match(CHECK)
		local inside = current and not line:match('^%s*$') and indentOf(line) > current.indent
		if inside and mark then
			current.subs[#current.subs + 1] = { line = #lines, done = mark ~= ' ', text = text }
			current.last = #lines
		elseif inside then
			local note = line:gsub('^%s+', ''):gsub('^[-*+] ', '')
			current.notes[#current.notes + 1] = note
			current.noteLines[#current.noteLines + 1] = #lines
			current.last = #lines
		elseif mark then
			current = { line = #lines, last = #lines, indent = indentOf(line), done = mark ~= ' ', text = text,
				notes = {}, noteLines = {}, subs = {} }
			table.insert(current.done and done or open, current)
		elseif current and line:match('^%s*$') then
			-- Leerzeile: gehoert nur dazu, wenn danach noch eingerueckt weitergeht
		else
			current = nil
		end
	end
	-- offene Punkte mit Datum nach Faelligkeit zuerst, dann die ohne Datum in Dateireihenfolge
	for k, t in ipairs(open) do
		t.order = k
		t.due = dueOf(t.text)
		local h, mi = timeOf(t.text)
		if t.due and h then t.due = t.due + (h - 12) * 3600 + mi * 60 end
	end
	table.sort(open, function(a, b)
		local da, db = a.due or math.huge, b.due or math.huge
		if da ~= db then return da < db end
		return a.order < b.order
	end)
	-- erledigte darunter
	display = open
	for _, t in ipairs(done) do display[#display + 1] = t end
	return #open, #done
end

local function save()
	local f = io.open(path, 'wb')
	if not f then return end
	f:write(bom .. table.concat(lines, nl))
	f:close()
	lastContent = nil
end

local function trim(s)
	return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- [[Link]] und [[Link|Alias]] lesbar machen
local function pretty(text)
	return (text:gsub('%[%[(.-)%]%]', function(s) return s:match('|(.*)$') or s end))
end

local function urlEncode(s)
	return (s:gsub('[^%w%-%._~]', function(ch) return string.format('%%%02X', ch:byte()) end))
end

-- erster Link einer Notizzeile: Webadresse, [[Obsidian-Notiz]] oder Windows-Pfad
local function linkOf(note)
	local url = note:match('https?://[^%s%)%]>"]+')
	if url then return url end
	local wiki = note:match('%[%[([^%]|#]+)')
	if wiki then return 'obsidian://open?vault=' .. urlEncode(vault) .. '&file=' .. urlEncode(trim(wiki)) end
	local p = note:match('%a:\\[^"<>|*?]*')
	if p then return (p:gsub('[%s%.,;:]+$', '')) end
	return nil
end

-- lange Webadressen in der Anzeige auf "domain.de ↗" kuerzen (die Datei bleibt unveraendert)
local function shortLinks(text)
	local arrow = SKIN:GetVariable('LinkArrow')
	return (text:gsub('https?://[^%s%)%]>"]+', function(url)
		local host = url:match('^https?://([^/:?#]+)') or url
		return host:gsub('^www%.', '') .. ' ' .. arrow
	end))
end

-- Windows-Pfade in der Anzeige auf den Datei-/Ordnernamen kuerzen (die Datei bleibt unveraendert)
local function shortPaths(text)
	return (text:gsub('%a:\\[^"<>|*?]*', function(p)
		return p:gsub('[\\%s]+$', ''):match('([^\\]+)$') or p
	end))
end

-- Kaestchen (eigener Meter <name>Box) und Text einer Checkbox-Zeile setzen, ggf. mit Datum
local function setCheck(m, done, text, v, y)
	local b = m .. 'Box'
	SKIN:Bang('!SetOption', b, 'Text', done and v.boxDone or v.boxOpen)
	SKIN:Bang('!SetOption', b, 'InlineSetting3', 'Color | ' .. (done and v.colCheck or v.colBox))
	SKIN:Bang('!SetOption', b, 'Y', y)
	SKIN:Bang('!ShowMeter', b)
	local shown = shortLinks(pretty(stripDue(stripStamps(text))))
	local due, dueCol = dueOf(text), v.colDone
	if due then
		local label
		local h, mi = timeOf(text)
		label, dueCol = dueLabel(due, done, v, h, mi)
		shown = shown .. '   ' .. (ruleOf(text) and v.repIcon or v.calIcon) .. ' ' .. label
	end
	SKIN:Bang('!SetOption', m, 'Text', shown)
	SKIN:Bang('!SetOption', m, 'FontColor', done and v.colDone or v.colText)
	-- InlineSetting (Datumsfarbe) nie leer lassen, sonst ignoriert Rainmeter InlineSetting2-4
	SKIN:Bang('!SetOption', m, 'InlineSetting', 'Color | ' .. dueCol)
	SKIN:Bang('!SetOption', m, 'InlineSetting4', done and 'Strikethrough' or '')
	SKIN:Bang('!SetOption', m, 'Y', y)
	SKIN:Bang('!ShowMeter', m)
end
local function hideCheck(m)
	SKIN:Bang('!HideMeter', m)
	SKIN:Bang('!HideMeter', m .. 'Box')
end
-- Hoehe einer Zeile nach dem Umbrechen (mindestens minH)
local function heightOf(m, minH)
	SKIN:Bang('!UpdateMeter', m)
	return math.max(SKIN:GetMeter(m):GetH(), minH)
end

-- Zaehler oben rechts; waehrend die Liste eingeblendet ist: Knopf 'Ausblenden'
local function setCount(openCount)
	if revealUntil then
		SKIN:Bang('!SetOption', 'MeterCount', 'Text', 'Ausblenden ✕')
		SKIN:Bang('!SetOption', 'MeterCount', 'FontColor', SKIN:GetVariable('ColorAccent'))
	else
		SKIN:Bang('!SetOption', 'MeterCount', 'Text', openCount .. ' offen')
		SKIN:Bang('!SetOption', 'MeterCount', 'FontColor', SKIN:GetVariable('ColorDone'))
	end
end

local function render(openCount, doneCount)
	lastOpen, lastDone = openCount, doneCount
	setCount(openCount)
	-- Seitenleiste (oder "Beides" gerade als Panel am Rand): Liste ist ohnehin bildschirmhoch -> kein Einklappen,
	-- Pfeil weg und "x offen" an den rechten Rand
	local asPanel = mode == 'sidebar' or panel
	local isCollapsed = collapsed and not asPanel
	if asPanel then
		SKIN:Bang('!HideMeter', 'MeterFold')
		SKIN:Bang('!HideMeter', 'FoldBtn')
		SKIN:Bang('!SetOption', 'MeterCount', 'X', width - 20)
	else
		SKIN:Bang('!ShowMeter', 'MeterFold')
		SKIN:Bang('!ShowMeter', 'FoldBtn')
		SKIN:Bang('!SetOption', 'MeterCount', 'X', width - 62)
	end
	SKIN:Bang('!SetOption', 'MeterFold', 'Text', SKIN:GetVariable(isCollapsed and 'FoldClosed' or 'FoldOpen'))
	if isCollapsed then
		SKIN:Bang('!HideMeterGroup', 'List')
		SKIN:Bang('!SetOption', 'MeterBg', 'Shape', 'Rectangle 0,0,' .. width .. ',' .. (listTop - 4) .. ',12 | Fill Color #ColorBg# | StrokeWidth 0')
		SKIN:Bang('!UpdateMeter', '*')
		SKIN:Bang('!Redraw')
		return
	end
	SKIN:Bang('!ShowMeter', 'MeterAdd')
	SKIN:Bang('!ShowMeter', 'AddBtn')
	local v = {
		boxOpen = SKIN:GetVariable('BoxOpen'), boxDone = SKIN:GetVariable('BoxDone'),
		colText = SKIN:GetVariable('ColorText'), colDone = SKIN:GetVariable('ColorDone'), repIcon = SKIN:GetVariable('RepIcon'),
		colBox = SKIN:GetVariable('ColorBox'), colCheck = SKIN:GetVariable('ColorCheck'), calIcon = SKIN:GetVariable('CalIcon'),
		colOver = SKIN:GetVariable('ColorOver'), colToday = SKIN:GetVariable('ColorToday'), colDue = SKIN:GetVariable('ColorDue'),
		colLink = SKIN:GetVariable('ColorAccent'), font = SKIN:GetVariable('FontFace'),
	}
	local colNote = SKIN:GetVariable('ColorNote')
	local clipIcon = SKIN:GetVariable('ClipIcon')
	local y = listTop
	local n, s = 0, 0
	noteMap, subMap = {}, {}
	for i = 1, maxItems do
		local m = 'Item' .. i
		local t = display[i]
		if t then
			local count = #t.notes
			local open = expanded[t.text]
			local subsDone = 0
			for _, sub in ipairs(t.subs) do if sub.done then subsDone = subsDone + 1 end end

			setCheck(m, t.done, t.text, v, y)
			itemY[i] = y

			-- Fortschritt der Unteraufgaben links neben der Bueroklammer
			if #t.subs > 0 then
				SKIN:Bang('!SetOption', 'Progress' .. i, 'Text', subsDone .. '/' .. #t.subs)
				SKIN:Bang('!SetOption', 'Progress' .. i, 'Y', y)
				SKIN:Bang('!ShowMeter', 'Progress' .. i)
				SKIN:Bang('!SetOption', m, 'ClipStringW', width - 183)
			else
				SKIN:Bang('!HideMeter', 'Progress' .. i)
				SKIN:Bang('!SetOption', m, 'ClipStringW', width - 129)
			end

			SKIN:Bang('!SetOption', 'Clip' .. i, 'Text', clipIcon .. (count > 0 and (' ' .. count) or ''))
			-- Knopf mittig in der ersten Zeile des Punkts, Symbol + Anzahl darauf zentriert
			local by = y + math.floor((rowH - 30) / 2)
			SKIN:Bang('!SetOption', 'Clip' .. i .. 'Btn', 'Y', by)
			SKIN:Bang('!ShowMeter', 'Clip' .. i .. 'Btn')
			SKIN:Bang('!SetOption', 'Clip' .. i, 'Y', by + 4)
			SKIN:Bang('!SetOption', 'Clip' .. i, 'FontColor', open and v.colLink or v.colDone)
			SKIN:Bang('!ShowMeter', 'Clip' .. i)
			y = y + heightOf(m, rowH)

			for _, sub in ipairs(t.subs) do
				if s >= maxSubs then break end
				s = s + 1
				local sm = 'Sub' .. s
				subMap[s] = { task = i, line = sub.line, y = y }
				setCheck(sm, sub.done, sub.text, v, y)
				y = y + heightOf(sm, noteH + 2)
			end

			if open then
				for k, note in ipairs(t.notes) do
					if n >= maxNotes then break end
					n = n + 1
					local nm = 'Note' .. n
					local link = linkOf(note)
					noteMap[n] = { task = i, line = t.noteLines[k], y = y }
					SKIN:Bang('!SetOption', nm, 'Text', shortPaths(shortLinks(pretty(note))))
					SKIN:Bang('!SetOption', nm, 'FontColor', link and v.colLink or colNote)
					SKIN:Bang('!SetOption', nm, 'InlineSetting', link and 'Underline' or '')
					SKIN:Bang('!SetOption', nm, 'LeftMouseUpAction', link and ('["' .. link .. '"]') or '')
					SKIN:Bang('!SetOption', nm, 'Y', y)
					SKIN:Bang('!ShowMeter', nm)
					y = y + heightOf(nm, noteH)
				end
				SKIN:Bang('!SetOption', 'NoteAdd' .. i, 'Y', y)
				SKIN:Bang('!SetOption', 'SubAdd' .. i, 'Y', y)
				SKIN:Bang('!ShowMeter', 'NoteAdd' .. i)
				SKIN:Bang('!ShowMeter', 'SubAdd' .. i)
				SKIN:Bang('!SetOption', 'FileAdd' .. i, 'Y', y)
				SKIN:Bang('!ShowMeter', 'FileAdd' .. i)
				addY[i] = y
				y = y + noteH + 4
			else
				SKIN:Bang('!HideMeter', 'NoteAdd' .. i)
				SKIN:Bang('!HideMeter', 'SubAdd' .. i)
				SKIN:Bang('!HideMeter', 'FileAdd' .. i)
			end
			if #t.subs > 0 and not open then y = y + 4 end
		else
			hideCheck(m)
			for _, p in ipairs({ 'Clip' .. i, 'Clip' .. i .. 'Btn', 'Progress' .. i, 'NoteAdd' .. i, 'SubAdd' .. i, 'FileAdd' .. i }) do
				SKIN:Bang('!HideMeter', p)
			end
		end
	end
	for k = n + 1, maxNotes do SKIN:Bang('!HideMeter', 'Note' .. k) end
	for k = s + 1, maxSubs do hideCheck('Sub' .. k) end

	local hidden = #display - maxItems
	if #display == 0 then
		SKIN:Bang('!SetOption', 'MeterMore', 'Text', 'Alles erledigt')
		SKIN:Bang('!SetOption', 'MeterMore', 'Y', y)
		SKIN:Bang('!ShowMeter', 'MeterMore')
		y = y + rowH
	elseif hidden > 0 then
		SKIN:Bang('!SetOption', 'MeterMore', 'Text', '+ ' .. hidden .. ' weitere in Obsidian')
		SKIN:Bang('!SetOption', 'MeterMore', 'Y', y)
		SKIN:Bang('!ShowMeter', 'MeterMore')
		y = y + rowH
	else
		SKIN:Bang('!HideMeter', 'MeterMore')
	end

	y = y + 6
	-- Knopf "+ Neuer Punkt": so breit wie der Text, Text mittig in der Hoehe
	local addW = 130
	local ma = SKIN:GetMeter('MeterAdd')
	if ma and ma:GetW() > 0 then addW = ma:GetW() + 23 end
	SKIN:Bang('!SetVariable', 'AddW', addW)
	SKIN:Bang('!SetOption', 'AddBtn', 'Y', y)
	SKIN:Bang('!SetOption', 'MeterAdd', 'Y', y + math.floor((32 - (ma and ma:GetH() or 22)) / 2))
	SKIN:Bang('!SetOption', 'MeterClean', 'Y', y + 7)
	if doneCount > 0 then SKIN:Bang('!ShowMeter', 'MeterClean') else SKIN:Bang('!HideMeter', 'MeterClean') end
	y = y + math.max(rowH, 32) + 16

	-- Seitenleiste: Hintergrund ueber die ganze Bildschirmhoehe (oben und unten je 8 Pixel Abstand)
	local bgH = y
	if mode == 'sidebar' or panel then bgH = math.max(y, workH - 16) end
	SKIN:Bang('!SetOption', 'MeterBg', 'Shape', 'Rectangle 0,0,' .. width .. ',' .. bgH .. ',12 | Fill Color #ColorBg# | StrokeWidth 0')
	setCount(openCount)
	SKIN:Bang('!UpdateMeter', '*')
	SKIN:Bang('!Redraw')
end

local function refresh(force)
	local c = readFile()
	if not c then
		SKIN:Bang('!SetOption', 'MeterCount', 'Text', 'Datei fehlt')
		return 0
	end
	if c == lastContent and not force then return nil end
	lastContent = c
	local o, d = parse(c)
	render(o, d)
	return o
end

-- Punkt wiederfinden, auch wenn die Datei inzwischen geaendert wurde
local function findTask(lineNo, orig)
	for _, t in ipairs(display) do
		if t.line == lineNo and lines[t.line] == orig then return t end
	end
	for _, t in ipairs(display) do
		if lines[t.line] == orig then return t end
	end
end

-- Zeile innerhalb eines Punkts (Notiz oder Unteraufgabe) wiederfinden
local function findChild(t, lineNo, orig)
	if lines[lineNo] == orig and lineNo > t.line and lineNo <= t.last then return lineNo end
	for k = t.line + 1, t.last do
		if lines[k] == orig then return k end
	end
end

-- Textfeld an Position x/y oeffnen
local function openEditor(text, x, y, w)
	SKIN:Bang('!SetVariable', 'EditText', text)
	SKIN:Bang('!SetVariable', 'EditX', x)
	SKIN:Bang('!SetVariable', 'EditY', y)
	SKIN:Bang('!SetVariable', 'EditW', w)
	SKIN:Bang('!UpdateMeasure', 'MeasureEdit')
	SKIN:Bang('!CommandMeasure', 'MeasureEdit', 'ExecuteBatch 1')
end

-- abhaken setzt "✅ heute", zuruecknehmen entfernt es wieder
local function flip(lineNo)
	local line = lines[lineNo]
	local nowDone = line:match('%[ %]') ~= nil
	line = line:gsub('%[([ xX])%]', nowDone and '[x]' or '[ ]', 1)
	line = line:gsub('%s*' .. doneIcon .. '%s*' .. DATE, '')
	if nowDone then line = line .. stamp(doneIcon) end
	lines[lineNo] = line
end

-- ---------- Archiv (Todo-Archiv.md): erledigte und geloeschte Punkte statt wegwerfen ----------
local MONTHS = { 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember' }

-- Bloecke (Listen von Zeilen) unter der Ueberschrift des aktuellen Monats anhaengen
local function archive(blocks)
	if #blocks == 0 then return true end
	local f = io.open(archivePath, 'rb')
	local c = f and f:read('*a') or nil
	if f then f:close() end
	if not c or c == '' then
		c = '---\ntags: [todo, archiv]\n---\n\n# Todo-Archiv\n\nErledigte und gelöschte Punkte aus [[Todo]], mit allen Notizen und Unteraufgaben. '
			.. '➕ = erstellt, ✅ = erledigt, ❌ = gelöscht (`- [-]`).\n'
	end
	local d = os.date('*t')
	local heading = '## ' .. MONTHS[d.month] .. ' ' .. d.year
	local lastHeading
	for h in c:gmatch('\n(## [^\r\n]*)') do lastHeading = h end
	local out = { (c:gsub('[\r\n]*$', '')) }
	if lastHeading ~= heading then out[#out + 1] = '\n\n' .. heading .. '\n' end
	for _, b in ipairs(blocks) do out[#out + 1] = '\n' .. table.concat(b, '\n') end
	out[#out + 1] = '\n'
	f = io.open(archivePath, 'wb')
	if not f then return false end
	f:write(table.concat(out))
	f:close()
	return true
end

-- Zeilen eines Punkts (ohne seine Einrueckung) fuers Archiv; mark: 'x' erledigt, '-' geloescht
local function blockOf(t, mark)
	local indent = lines[t.line]:match('^(%s*)')
	local b = {}
	for k = t.line, t.last do
		local line = lines[k]
		if line:sub(1, #indent) == indent then line = line:sub(#indent + 1) end
		if line:match('%S') then b[#b + 1] = line end
	end
	local head = b[1]
	if mark == '-' then
		head = head:gsub('%[[ xX]%]', '[-]', 1) .. stamp(cancelIcon)
	elseif not head:find(doneIcon, 1, true) then
		head = head .. stamp(doneIcon)  -- in Obsidian ohne Datum abgehakt
	end
	b[1] = head
	return b
end

-- ---------- Wiederkehrende Punkte ----------
-- abgehakter "🔁"-Punkt (Desktop oder Obsidian): Kopie mit ✅ ins Archiv,
-- der Punkt selbst wird wieder offen und rutscht auf den naechsten Termin
local function rollRecurring()
	local blocks, changes = {}, {}
	for _, t in ipairs(display) do
		local rule = t.done and ruleOf(t.text)
		if rule then
			local line = lines[t.line]
			local copy = line:sub(#line:match('^(%s*)') + 1):gsub(repPattern(), '')
			if not copy:find(doneIcon, 1, true) then copy = copy .. stamp(doneIcon) end
			blocks[#blocks + 1] = { copy }
			local nxt = dueIcon .. ' ' .. os.date('%Y-%m-%d', nextDate(dueOf(t.text), RULES[rule] or rule))
			line = line:gsub('%[[xX]%]', '[ ]', 1):gsub('%s*' .. doneIcon .. '%s*' .. DATE, '')
			if dueOf(line) then line = line:gsub(dueIcon .. '%s*' .. DATE, nxt) else line = line .. ' ' .. nxt end
			changes[t.line] = line
			for _, sub in ipairs(t.subs) do
				if sub.done then changes[sub.line] = lines[sub.line]:gsub('%[[xX]%]', '[ ]', 1):gsub('%s*' .. doneIcon .. '%s*' .. DATE, '') end
			end
		end
	end
	if #blocks == 0 or not archive(blocks) then return false end
	for k, line in pairs(changes) do lines[k] = line end
	return true
end

-- Windows-Erinnerung, sobald ein offener Punkt mit Uhrzeit faellig ist (einmal pro Termin,
-- nach "In 15 Min nochmal" erneut). Jede Erinnerung bekommt eine Nummer fuer die Knoepfe (ToastAction).
local reminderIds, reminderCount, snoozed = {}, 0, {}
local function checkReminders()
	-- Einstellungen: RemindOn (1/0), RemindLead (Minuten vorher)
	if SKIN:GetVariable('RemindOn') == '0' then return end
	local lead = tonumber(SKIN:GetVariable('RemindLead')) or 0
	local due = {}
	local now = os.date('*t')
	for _, t in ipairs(display) do
		local h, mi = timeOf(t.text)
		local day = dueOf(t.text)
		local again = snoozed[t.text] and os.time() >= snoozed[t.text]
		if not t.done and h and day and (not notified[t.text] or again)
			and (day < today() or (day == today() and now.hour * 60 + now.min >= h * 60 + mi - lead)) then
			notified[t.text] = true
			snoozed[t.text] = nil
			reminderCount = reminderCount + 1
			reminderIds[reminderCount] = t.text
			local name = trim(pretty(stripDue(stripStamps(t.text)))):gsub('["|~]', '')
			due[#due + 1] = reminderCount .. '~' .. name .. string.format(' (%02d:%02d)', h, mi)
		end
	end
	if #due == 0 then return end
	SKIN:Bang('!SetVariable', 'NotifyText', table.concat(due, ' | '))
	SKIN:Bang('!UpdateMeasure', 'MeasureNotify')
	SKIN:Bang('!CommandMeasure', 'MeasureNotify', 'Run')
end

function Update()
	if hideOnFirstUpdate then hideOnFirstUpdate = false; SKIN:Bang('!Hide') end
	-- Aufwachen aus dem Standby: waehrend des Schlafs laeuft kein Update -> grosse Zeitluecke
	local now = os.time()
	if now - lastTick > 90 then Reveal() end
	lastTick = now
	if revealUntil and now >= revealUntil then HideReveal() end
	if pendingReveal then
		if now - pendingReveal > 300 then pendingReveal = nil
		elseif lastOpen then Reveal() end
	end
	-- jede Minute neu zeichnen, damit "heute 15:00" rechtzeitig rot wird
	local minute = os.date('%H:%M')
	refresh(minute ~= lastMinute)
	lastMinute = minute
	if not display then return 0 end
	if rollRecurring() then save(); refresh(true) end
	checkReminders()
	return #display
end

function Toggle(i)
	refresh(true)
	local t = display[i]
	if not t then return end
	flip(t.line)
	save()
	refresh(true)
	if rollRecurring() then save(); refresh(true) end
end

-- Knoepfe in der Windows-Erinnerung (ueber toast-action.vbs): 'done' hakt ab, 'snooze' erinnert in 15 Minuten erneut
function ToastAction(action, id)
	local key = reminderIds[tonumber(id)]
	if not key then return end
	if action == 'snooze' then
		snoozed[key] = os.time() + 15 * 60
		return
	end
	if action ~= 'done' then return end
	refresh(true)
	for _, t in ipairs(display) do
		if t.text == key and not t.done then
			flip(t.line)
			save()
			refresh(true)
			if rollRecurring() then save(); refresh(true) end
			return
		end
	end
end

function ToggleSub(k)
	local sm = subMap[k]
	if not sm then return end
	local orig = lines[sm.line]
	refresh(true)
	if lines[sm.line] ~= orig then return end
	flip(sm.line)
	save()
	refresh(true)
end

-- Klick auf den Titel: ganze Liste ein-/ausklappen (bleibt nach Neustart erhalten)
function ToggleCollapse()
	collapsed = not collapsed
	-- nicht in die Datei schreiben: beim Start ist die Liste immer aufgeklappt
	SKIN:Bang('!SetVariable', 'Collapsed', collapsed and '1' or '0')
	render(lastOpen or 0, lastDone or 0)
end

-- Notizen unter einem Punkt auf-/zuklappen
function ToggleNotes(i)
	local t = display and display[i]
	if not t then return end
	expanded[t.text] = not expanded[t.text] or nil
	render(lastOpen, lastDone)
end

-- Zeilen hinter den letzten Todo-Punkt (samt Notizen) einfuegen, sonst ans Ende (vor eine leere Schlusszeile)
local function insertAtEnd(block)
	local pos = 0
	for _, t in ipairs(display) do if t.last > pos then pos = t.last end end
	if pos == 0 then
		pos = #lines
		while pos > 0 and lines[pos] == '' do pos = pos - 1 end
	end
	for k, l in ipairs(block) do table.insert(lines, pos + k, l) end
	if lines[#lines] ~= '' then lines[#lines + 1] = '' end
end

-- Schnell-Eingabe (Textfeld, @-Kurzbefehle); der Desktop nutzt inzwischen das Formular
function Add()
	local text = convertDates(trim(SKIN:GetVariable('NewItem') or ''))
	if text == '' then return end
	refresh(true)
	insertAtEnd({ '- [ ] ' .. text .. stamp(createdIcon) })
	save()
	refresh(true)
end

-- ---------- Formular (Config ObsidianTodo\Formular, form.lua) fuer neue Punkte und Rechtsklick > bearbeiten ----------
local dialog
-- i = 0: neuer Punkt, sonst Punkt i bearbeiten; top = 1: per Tastenkuerzel geoeffnet -> ueber allen Fenstern
function OpenDialog(i, top)
	refresh(true)
	local f
	if i == 0 then
		dialog = { mode = 'new' }
		f = { 'mode=new' }
	else
		local t = display[i]
		if not t then return end
		dialog = { mode = 'edit', line = t.line, orig = lines[t.line] }
		local h, mi = timeOf(t.text)
		local rule = ruleOf(t.text)
		f = { 'mode=edit', 'title=' .. trim(stripDue(stripStamps(t.text))),
			'date=' .. (t.text:match(dueIcon .. '%s*(' .. DATE .. ')') or ''),
			'time=' .. (h and string.format('%02d:%02d', h, mi) or ''),
			'rule=' .. (rule and (RULES[rule] or rule) or '') }
		for _, n in ipairs(t.notes) do f[#f + 1] = 'note=' .. n end
	end
	local out = io.open(SKIN:GetVariable('@') .. 'dialog-in.txt', 'wb')
	if not out then dialog = nil return end
	out:write(table.concat(f, '\n'))
	out:close()
	-- Formular erscheint dort, wo sonst die Hilfe steht; ist es schon offen, liest es die neuen Werte ein
	SKIN:Bang('!DeactivateConfig', 'ObsidianTodo\\Einstellungen')
	SKIN:Bang('!ActivateConfig', 'ObsidianTodo\\Formular', 'Formular.ini')
	SKIN:Bang('!Refresh', 'ObsidianTodo\\Formular')
	SKIN:Bang('!ZPos', top == 1 and '1' or '-2', 'ObsidianTodo\\Formular')
end

function Edit(i) OpenDialog(i) end

function DialogDone()
	local d = dialog
	dialog = nil
	if not d then return end
	local r, notes = {}, {}
	local fh = io.open(SKIN:GetVariable('@') .. 'form-out.txt', 'rb')
	if not fh then return end
	local out = fh:read('*a')
	fh:close()
	os.remove(SKIN:GetVariable('@') .. 'form-out.txt')
	for l in out:gmatch('[^\r\n]+') do
		local k, v = l:match('^(%w+)=(.*)$')
		if k == 'note' then
			v = trim(v)
			if v ~= '' then notes[#notes + 1] = v end
		elseif k then r[k] = trim(v) end
	end
	if r.action ~= 'save' and r.action ~= 'delete' then return end
	refresh(true)
	local t
	if d.mode == 'edit' then
		t = findTask(d.line, d.orig)
		if not t then return end
	end

	if r.action == 'delete' then
		if not t or not archive({ blockOf(t, '-') }) then return end
		for k = t.last, t.line, -1 do table.remove(lines, k) end
		save()
		return refresh(true)
	end

	if (r.title or '') == '' then return end
	local text = r.title
	if (r.rule or '') ~= '' then text = text .. ' ' .. repeatIcon .. ' ' .. r.rule end
	if (r.time or '') ~= '' then text = text .. ' ' .. timeIcon .. ' ' .. r.time end
	if (r.date or '') ~= '' then text = text .. ' ' .. dueIcon .. ' ' .. r.date end

	if d.mode == 'new' then
		text = text .. stamp(createdIcon)
		local block = { '- [ ] ' .. text }
		for _, n in ipairs(notes) do block[#block + 1] = '    - ' .. n end
		insertAtEnd(block)
		if #notes > 0 then expanded[text] = true end
	else
		-- Punkt neu zusammensetzen: Kopfzeile, Unteraufgaben wie gehabt, dann die Notizen aus dem Formular
		local indent = lines[t.line]:match('^(%s*)')
		text = text .. stampsOf(t.text)
		local block = { lines[t.line]:match('^(%s*[-*+] %[[ xX]%])') .. ' ' .. text }
		for _, sub in ipairs(t.subs) do block[#block + 1] = lines[sub.line] end
		for _, n in ipairs(notes) do block[#block + 1] = indent .. '    - ' .. n end
		if expanded[t.text] then expanded[text] = true end
		for k = t.last, t.line, -1 do table.remove(lines, k) end
		for k, l in ipairs(block) do table.insert(lines, t.line + k - 1, l) end
	end
	save()
	refresh(true)
end

-- Rechtsklick auf Notiz: Notiz bearbeiten
function EditNote(n)
	local nm = noteMap[n]
	if not nm then return end
	local t = display[nm.task]
	local orig = lines[nm.line]
	edit = { mode = 'note', line = nm.line, orig = orig, taskLine = t.line, taskOrig = lines[t.line] }
	openEditor((orig:gsub('^%s+', ''):gsub('^[-*+] ', '')), 40, nm.y, width - 56)
end

-- Rechtsklick auf Unteraufgabe: Text bearbeiten
function EditSub(k)
	local sm = subMap[k]
	if not sm then return end
	local t = display[sm.task]
	local orig = lines[sm.line]
	local _, text = orig:match(CHECK)
	edit = { mode = 'sub', line = sm.line, orig = orig, taskLine = t.line, taskOrig = lines[t.line], stamps = stampsOf(text or '') }
	openEditor(datesToInput(stripStamps(text or '')), 40, sm.y, width - 56)
end

-- "+ Notiz" / "+ Unteraufgabe": neue Zeile unter dem Punkt
function AddNote(i)
	local t = display[i]
	if not t then return end
	edit = { mode = 'addnote', taskLine = t.line, taskOrig = lines[t.line] }
	openEditor('', 40, addY[i] or listTop, width - 56)
end

function AddSub(i)
	local t = display[i]
	if not t then return end
	edit = { mode = 'addsub', taskLine = t.line, taskOrig = lines[t.line] }
	openEditor('', 40, addY[i] or listTop, width - 56)
end

-- "+ Datei": Windows-Dateiauswahl starten, Ergebnis kommt in FilePicked()
local pendingFile
function PickFile(i)
	local t = display[i]
	if not t then return end
	pendingFile = { taskLine = t.line, taskOrig = lines[t.line] }
	SKIN:Bang('!CommandMeasure', 'MeasureFilePick', 'Run')
end

function FilePicked()
	local e = pendingFile
	pendingFile = nil
	if not e then return end
	local out = SKIN:GetMeasure('MeasureFilePick'):GetStringValue() or ''
	refresh(true)
	local t = findTask(e.taskLine, e.taskOrig)
	if not t then return end
	local indent = e.taskOrig:match('^(%s*)') .. '    '
	local pos = t.last
	for p in out:gmatch('[^\r\n]+') do
		p = trim(p)
		if p:match('^%a:\\') or p:match('^\\\\') then
			pos = pos + 1
			table.insert(lines, pos, indent .. '- ' .. p)
		end
	end
	if pos == t.last then return end
	expanded[t.text] = true
	save()
	refresh(true)
end

-- Enter im Textfeld; leerer Text loescht Punkt, Notiz bzw. Unteraufgabe
function SaveEdit()
	if not edit then return end
	local e = edit
	edit = nil
	local text = convertDates(trim(SKIN:GetVariable('NewItem') or ''))
	refresh(true)

	if e.mode == 'task' then
		local t = findTask(e.line, e.orig)
		if not t then return refresh(true) end
		if text == '' then
			-- geloeschter Punkt kommt samt Notizen als "- [-] … ❌ heute" ins Archiv
			if not archive({ blockOf(t, '-') }) then return refresh(true) end
			for k = t.last, t.line, -1 do table.remove(lines, k) end
		else
			text = text .. e.stamps
			if expanded[t.text] then expanded[text] = true end
			lines[t.line] = e.orig:match('^(%s*[-*+] %[[ xX]%])') .. ' ' .. text
		end

	elseif e.mode == 'note' or e.mode == 'sub' then
		local t = findTask(e.taskLine, e.taskOrig)
		if not t then return refresh(true) end
		local ln = findChild(t, e.line, e.orig)
		if not ln then return refresh(true) end
		if text == '' then
			table.remove(lines, ln)
		else
			local prefix = e.orig:match('^(%s*[-*+] %[[ xX]%] )') or e.orig:match('^(%s*[-*+] )') or e.orig:match('^(%s*)')
			lines[ln] = prefix .. text .. (e.stamps or '')
		end

	elseif e.mode == 'addnote' or e.mode == 'addsub' then
		if text == '' then return end
		local t = findTask(e.taskLine, e.taskOrig)
		if not t then return refresh(true) end
		local indent = e.taskOrig:match('^(%s*)') .. '    '
		if e.mode == 'addsub' then
			-- hinter die letzte Unteraufgabe, sonst direkt unter den Punkt
			local pos = t.line
			for _, sub in ipairs(t.subs) do if sub.line > pos then pos = sub.line end end
			table.insert(lines, pos + 1, indent .. '- [ ] ' .. text .. stamp(createdIcon))
		else
			table.insert(lines, t.last + 1, indent .. '- ' .. text)
			expanded[t.text] = true
		end
	end

	save()
	refresh(true)
end

-- erledigte Punkte samt Notizen und erledigte Unteraufgaben ins Archiv verschieben
function Cleanup()
	refresh(true)
	local remove, blocks = {}, {}
	for _, t in ipairs(display) do
		if t.done then
			blocks[#blocks + 1] = blockOf(t, 'x')
			for k = t.line, t.last do remove[k] = true end
		else
			local parent = trim(stripDue(stripStamps(t.text)))
			for _, sub in ipairs(t.subs) do
				if sub.done then
					local line = '- [x] ' .. sub.text
					if not sub.text:find(doneIcon, 1, true) then line = line .. stamp(doneIcon) end
					blocks[#blocks + 1] = { line .. ' · Unteraufgabe von „' .. parent .. '“' }
					remove[sub.line] = true
				end
			end
		end
	end
	-- nur entfernen, wenn das Archiv geschrieben werden konnte
	if not archive(blocks) then return end
	local kept = {}
	for n, line in ipairs(lines) do if not remove[n] then kept[#kept + 1] = line end end
	lines = kept
	save()
	refresh(true)
end

-- ---------- Einblenden (Anmelden, Aufwachen, Entsperren) ----------
-- Die Liste kommt fuer 10 Sekunden pro offenem Punkt (hoechstens 2 Minuten) ueber alle Fenster,
-- danach zurueck auf den Desktop. Aufgerufen per Aufgabenplanung (Anmelden/Entsperren) und aus Update().
function Reveal()
	if not lastOpen then refresh(true) end
	-- Datei noch nicht lesbar: merken und nachholen, sobald die Punkte da sind (hoechstens 5 Minuten)
	if not lastOpen then pendingReveal = os.time() return end
	if lastOpen == 0 then return end
	pendingReveal = nil
	local per = tonumber(SKIN:GetVariable('RevealPerItem')) or 10
	if per <= 0 then return end
	revealUntil = os.time() + math.min(120, per * lastOpen)
	if mode ~= 'desktop' then
		SKIN:Bang('!CommandMeasure', 'MeasureSide', 'Reveal()', RAND)
	else
		SKIN:Bang('!ZPos', '2')
	end
	render(lastOpen, lastDone)
end

-- button = true: Knopf "Ausblenden" (sofort weg); sonst Zeit abgelaufen (Seitenleiste bleibt, solange die Maus drin ist)
function HideReveal(button)
	if not revealUntil then return end
	revealUntil = nil
	if mode ~= 'desktop' then
		SKIN:Bang('!CommandMeasure', 'MeasureSide', button and 'Out()' or 'RevealEnd()', RAND)
	else
		SKIN:Bang('!ZPos', '-2')
	end
	render(lastOpen, lastDone)
end

-- 'both': vom Desktop-Platz zum bildschirmhohen Panel am Rand und zurueck (aufgerufen von sidebar.lua)
function PanelOn()
	if panel then return end
	panel = true
	deskX, deskY = SKIN:GetX(), SKIN:GetY()
	SKIN:Bang('!Hide')
	SKIN:Bang('!KeepOnScreen', '0')
	SKIN:Bang('!Draggable', '0')
	if lastOpen then render(lastOpen, lastDone) end
end
function PanelOff()
	if not panel then return end
	panel = false
	SKIN:Bang('!Hide')
	SKIN:Bang('!ZPos', '-2')
	if deskX then SKIN:Bang('!Move', deskX, deskY) end
	SKIN:Bang('!KeepOnScreen', '1')
	SKIN:Bang('!Draggable', '1')
	if lastOpen then render(lastOpen, lastDone) end
	SKIN:Bang('!Show')
end