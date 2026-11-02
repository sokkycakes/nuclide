-- env_xenmaker (Sven Co-op): a Xen teleport effect, with lightning beams,
-- sprites and a sound, that can bring in a monster.
--   monstertype          spawned at the maker when it's triggered
--   m_iBeamCount, m_flBeamRadius, m_vBeamColor, m_iBeamAlpha  the beams
--   m_flStartSpriteScale/Framerate/Alpha, m_vStartSpriteColor  first sprite
--   m_flEndSpriteScale/Framerate/Alpha, m_vEndSpriteColor      second sprite
-- A squadmaker with a "xenmaker" key plays this effect each time it spawns
-- a child (its own monstertype is used then, not this one's).
-- Not done yet: the light (m_flLightRadius, m_vLightColor) and spawnflags.

keys = Sven.Keys(self)
monsterType = keys.monstertype or ""

local START_SPRITE = "sprites/fexplo1.spr"
local END_SPRITE = "sprites/xflare1.spr"
local BEAM_SPRITE = "sprites/lgtning.spr"
local SOUND_START = "debris/beamstart7.wav"
local SOUND_END = "debris/beamstart2.wav"

PrecacheModel(START_SPRITE)
PrecacheModel(END_SPRITE)
PrecacheModel(BEAM_SPRITE)
PrecacheSound(SOUND_START)
PrecacheSound(SOUND_END)
if monsterType ~= "" then
	QC.Call("Script_PrecacheEntity", monsterType)
end

-- effect parts waiting to be removed, with the time to remove them
parts = {}

local function spawnPart(class, keyList, life)
	local list = {}
	for i = 1, #keyList, 2 do
		local v = keyList[i + 1]
		if v ~= nil and v ~= "" then
			list[#list + 1] = string.format('"%s" "%s"', keyList[i], v)
		end
	end
	local ent = QC.CallEntity("Script_SpawnEntity", class, table.concat(list, " "))
	if ent ~= nil and ent:IsValid() and ent:entindex() > 0 then
		parts[#parts + 1] = { ent = ent, index = ent:entindex(), dieAt = Time() + life }
	end
end

local function sprite(model, prefix)
	spawnPart("env_sprite", {
		"origin", keys.origin,
		"model", model,
		"framerate", keys["m_fl" .. prefix .. "SpriteFramerate"] or "12",
		"scale", keys["m_fl" .. prefix .. "SpriteScale"] or "1",
		"rendermode", "5",
		"renderamt", keys["m_i" .. prefix .. "SpriteAlpha"] or "255",
		"rendercolor", keys["m_v" .. prefix .. "SpriteColor"] or "255 255 255",
		"spawnflags", "3",
	}, 2)
end

-- Plays the effect: two sprites, a burst of beams to nearby surfaces and
-- the teleport sounds.
function PlayEffect()
	sprite(START_SPRITE, "Start")
	sprite(END_SPRITE, "End")
	local start = keys.targetname
	if start ~= nil and start ~= "" then
		for _ = 1, Sven.Number(keys, "m_iBeamCount", 0) do
			spawnPart("env_beam", {
				"origin", keys.origin,
				"LightningStart", start,
				"Radius", keys.m_flBeamRadius or "255",
				"texture", BEAM_SPRITE,
				"life", "0.5",
				"BoltWidth", "18",
				"NoiseAmplitude", "65",
				"rendercolor", keys.m_vBeamColor or "255 255 255",
				"renderamt", keys.m_iBeamAlpha or "255",
				"spawnflags", "1",
			}, 1)
		end
	end
	Sven.Sound(self, SOUND_START, 1, 1)
	Sven.Sound(self, SOUND_END, 2, 1)
	AddThinkToEnt(self, "Tick")
end

function Tick()
	local left = {}
	for _, part in ipairs(parts) do
		local alive = part.ent:IsValid() and part.ent:entindex() == part.index
		if alive and Time() >= part.dieAt then
			part.ent:FireInput("Kill", "")
		elseif alive then
			left[#left + 1] = part
		end
	end
	parts = left
	if #parts == 0 then
		AddThinkToEnt(self, "")
	end
	return 0.1
end

function InputUse()
	PlayEffect()
	if monsterType ~= "" then
		local child = QC.CallEntity("Script_SpawnEntity", monsterType,
			string.format('"origin" "%s" "angles" "%s"', keys.origin or "0 0 0", keys.angles or "0 0 0"))
		Sven.Debug("env_xenmaker %s: spawned %s", tostring(keys.targetname), monsterType)
		if child == nil or not child:IsValid() or child:entindex() == 0 then
			printl("[sven] env_xenmaker " .. (keys.targetname or "?") .. ": could not spawn " .. monsterType)
		end
	end
end
