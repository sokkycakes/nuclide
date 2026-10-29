-- squadmaker (Sven Co-op): spawns monsters, items or weapons of one class.
-- Works like Half-Life's monstermaker, plus keys that dress up each child.
--   monstertype          the class to spawn (a monster, item_* or weapon_*)
--   monstercount         how many to spawn in all (-1 for no limit)
--   m_imaxlivechildren   how many may be alive at once
--   delay                seconds between spawns
--   netname              targetname given to each child
--   target               fired each time a child spawns
--   displayname          the child's name shown to players
--   new_model, new_body  replacement model and body (-1 keeps the default)
--   health               the child's health (0 keeps the default)
--   classify, respawn_as_playerally  makes the child an ally of players
--   trigger_condition, trigger_target  fired by the child, as on monsters
--   weapons, squadname, render keys    passed on to the child
--   spawnflags 1         starts on (so does a squadmaker with no targetname)
--   spawnflags 4         cyclic: each trigger spawns one child
-- Keys not handled yet: spawn_mode, soundlist, gag, notsolid,
-- min/maxhullsize, bloodcolor, is_squad_leader, freeroam and the
-- spawnflags above 4.

keys = Sven.Keys(self)
monsterType = keys.monstertype or ""
remaining = Sven.Number(keys, "monstercount", -1)
maxLive = Sven.Number(keys, "m_imaxlivechildren", -1)
spawnDelay = Sven.Number(keys, "delay", 0)
spawnFlags = Sven.Number(keys, "spawnflags", 0)
isCyclic = (spawnFlags & 4) ~= 0
children = {}
running = false
nextSpawn = 0

local isMonster = monsterType:sub(1, 8) == "monster_"

-- "key" "value" pairs for each child, in the map's own format.
local function childKeys()
	local list = {}
	local function add(k, v)
		if v ~= nil and v ~= "" then
			list[#list + 1] = string.format('"%s" "%s"', k, v)
		end
	end
	add("origin", keys.origin)
	add("angles", keys.angles)
	add("targetname", keys.netname)
	add("model", keys.new_model)
	if Sven.Number(keys, "new_body", -1) >= 0 then
		add("body", keys.new_body)
	end
	if Sven.Number(keys, "health", 0) > 0 then
		add("health", keys.health)
	end
	add("netname", keys.displayname)
	add("TriggerCondition", keys.trigger_condition)
	add("TriggerTarget", keys.trigger_target)
	add("team", Sven.TeamFor(keys))
	if Sven.Number(keys, "weapons", 0) > 0 then
		add("weapons", keys.weapons)
	end
	add("squadname", keys.squadname)
	add("rendermode", keys.rendermode)
	add("renderamt", keys.renderamt)
	add("renderfx", keys.renderfx)
	if keys.rendercolor ~= "0 0 0" then
		add("rendercolor", keys.rendercolor)
	end
	return table.concat(list, " ")
end

local childKeyString = childKeys()

if keys.new_model ~= nil and keys.new_model ~= "" then
	PrecacheModel(keys.new_model)
end

-- A monster counts while it lives; anything else while it exists.
local function isLive(child)
	if not child.ent:IsValid() or child.ent:entindex() ~= child.index then
		return false
	end
	if child.ent:GetClassname() ~= monsterType then
		return false
	end
	if isMonster then
		return child.ent:GetHealth() > 0
	end
	return true
end

local function liveCount()
	local live = {}
	for _, child in ipairs(children) do
		if isLive(child) then
			live[#live + 1] = child
		end
	end
	children = live
	return #live
end

local function canSpawn()
	if remaining == 0 then
		return false
	end
	return maxLive < 0 or liveCount() < maxLive
end

local function spawnChild()
	local ent = QC.CallEntity("Script_SpawnEntity", monsterType, childKeyString)
	if ent == nil or not ent:IsValid() or ent:entindex() == 0 then
		-- the class doesn't exist here, so stop trying
		printl("[sven] squadmaker " .. (keys.targetname or "?") .. ": could not spawn " .. monsterType)
		remaining = 0
		return false
	end
	children[#children + 1] = { ent = ent, index = ent:entindex() }
	if remaining > 0 then
		remaining = remaining - 1
	end
	Sven.Debug("squadmaker %s: spawned %s #%d", tostring(keys.targetname), monsterType, ent:entindex())
	Sven.Fire(keys.target, self)
	return true
end

function Tick()
	if not running then
		return 1
	end
	if remaining == 0 then
		running = false
		return 1
	end
	if Time() >= nextSpawn and canSpawn() then
		spawnChild()
		nextSpawn = Time() + spawnDelay
	end
	return math.max(math.min(nextSpawn - Time(), 1), 0.1)
end

local function setRunning(on)
	running = on
	if running then
		AddThinkToEnt(self, "Tick")
	else
		AddThinkToEnt(self, "")
	end
end

function InputUse()
	if isCyclic then
		if canSpawn() then
			spawnChild()
		end
		return
	end
	local mode = self:GetField("script_triggermode")
	if mode == 0 then
		setRunning(false)
	elseif mode == 1 then
		setRunning(true)
	else
		setRunning(not running)
	end
end

if not isCyclic and ((spawnFlags & 1) ~= 0 or keys.targetname == nil or keys.targetname == "") then
	setRunning(true)
end
