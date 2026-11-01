-- Seitenleiste fuer die Rainmeter-Todo-Liste (Config ObsidianTodo\Rand).
-- Ein unsichtbarer, 1 Pixel schmaler Streifen am rechten Rand des Hauptbildschirms, immer im Vordergrund.
-- Beruehrt die Maus den Rand, faehrt die Liste (Config ObsidianTodo) von aussen herein; verlaesst die Maus
-- die Liste, faehrt sie nach kurzer Zeit wieder hinaus und wird versteckt.
-- Anzeige-Art (Variable Mode aus prefs.inc): 'sidebar' | 'both' (Liste liegt auf dem Desktop und kommt am
-- Rand nach vorne) | 'desktop' (dieser Streifen wird nicht gebraucht).
-- Laeuft mit Update=16 (ca. 60 Bilder pro Sekunde), tut aber nur waehrend einer Animation etwas.

local LIST = 'ObsidianTodo'
local FRAMES = 12          -- Dauer der Animation in Bildern (~0,2 s)
local LEAVE_DELAY = 1      -- Sekunden nach Verlassen der Liste wieder hinaus (Uhrzeit, nicht Bilder:
                           -- Rainmeter schafft nicht ueberall 60 Bilder pro Sekunde)
local MARGIN = 8           -- Abstand zum Bildschirmrand oben, unten und rechts (wie eine schwebende KDE-Leiste)

local mode, width, right, top
local state = 'hidden'     -- hidden | sliding_in | shown | sliding_out
local frame = 0
local leaveAt = nil        -- Uhrzeit (os.time), ab der hinausgefahren wird (nil = Maus in der Liste oder Liste zu)
local revealing = false    -- vom Einblenden (Anmelden/Aufwachen) geoeffnet: bleibt, bis RevealEnd()

local function num(v, d) return tonumber(SKIN:GetVariable(v)) or d end

function Initialize()
	mode = SKIN:GetVariable('Mode') or 'sidebar'
	width = num('Width', 460)
	local wx, wy = num('WORKAREAX', 0), num('WORKAREAY', 0)
	right = wx + num('WORKAREAWIDTH', 1920)
	top = wy
	-- Streifen an den rechten Rand, ueber die volle Hoehe
	SKIN:Bang('!SetOption', 'MeterEdge', 'H', num('WORKAREAHEIGHT', 1080))
	SKIN:Bang('!UpdateMeter', 'MeterEdge')
	-- letzte Pixelspalte (dort bleibt die Maus am Rand haengen)
	SKIN:Bang('!Move', right - 1, top)
end

-- Position der Liste fuer einen Fortschritt p (0 = draussen, 1 = ganz drin), sanft abbremsend
local function place(p)
	local e = 1 - (1 - p) ^ 3
	local x = math.floor(right - (width + MARGIN) * e + 0.5)
	SKIN:Bang('!Move', x, top + MARGIN, LIST)
end

local function slideIn()
	if mode == 'both' then
		SKIN:Bang('!ZPos', '2', LIST)
		state = 'shown'
		return
	end
	if state == 'shown' or state == 'sliding_in' then return end
	if state == 'hidden' then
		frame = 0
		place(0)
		SKIN:Bang('!ZPos', '2', LIST)
		SKIN:Bang('!Show', LIST)
	else
		frame = FRAMES - frame   -- war gerade beim Hinausfahren: von dort aus umkehren
	end
	state = 'sliding_in'
end

local function slideOut()
	if mode == 'both' then
		SKIN:Bang('!ZPos', '-2', LIST)
		state = 'hidden'
		return
	end
	if state == 'hidden' or state == 'sliding_out' then return end
	if state == 'sliding_in' then frame = FRAMES - frame else frame = 0 end
	state = 'sliding_out'
end

function Update()
	if state == 'sliding_in' then
		frame = frame + 1
		place(math.min(1, frame / FRAMES))
		if frame >= FRAMES then state = 'shown' end
	elseif state == 'sliding_out' then
		frame = frame + 1
		place(math.max(0, 1 - frame / FRAMES))
		if frame >= FRAMES then
			state = 'hidden'
			SKIN:Bang('!Hide', LIST)
		end
	end
	if leaveAt and os.time() > leaveAt then
		leaveAt = nil
		if not revealing then slideOut() end
	end
	return 0
end

-- ---------- Aufrufe ----------
-- Maus beruehrt den Rand
function EdgeHit()
	slideIn()
	-- falls die Maus gar nicht in die Liste geht, trotzdem wieder hinaus
	leaveAt = os.time() + 2 * LEAVE_DELAY
end
-- Maus in der Liste (aus Todo.ini, [Rainmeter] MouseOverAction)
function Enter() leaveAt = nil end
-- Maus hat die Liste verlassen
function Leave() if state ~= 'hidden' then leaveAt = os.time() + LEAVE_DELAY end end
-- Einblenden beim Anmelden/Aufwachen/Entsperren (todo.lua bestimmt die Dauer)
function Reveal() revealing = true; leaveAt = nil; slideIn() end
function RevealEnd() revealing = false; leaveAt = os.time() + LEAVE_DELAY end
-- sofort hinaus (z. B. Knopf "Ausblenden")
function Out() revealing = false; leaveAt = nil; slideOut() end
