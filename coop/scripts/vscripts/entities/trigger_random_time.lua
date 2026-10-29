-- trigger_random_time (Sven Co-op): while on, fires one of its targets at
-- random intervals.
--   target1..targetN  the targets (target_count says how many)
--   min_delay, max_delay  seconds between firings
-- Triggering it turns it on and off. Removing it (killtarget) stops it.

keys = Sven.Keys(self)
running = false

local function targets()
	local list = {}
	local count = Sven.Number(keys, "target_count", 16)
	for i = 1, count do
		local t = keys["target" .. i]
		if t ~= nil and t ~= "" then
			list[#list + 1] = t
		end
	end
	if #list == 0 and keys.target ~= nil then
		list[1] = keys.target
	end
	return list
end

local function nextDelay()
	local lo = Sven.Number(keys, "min_delay", 1)
	local hi = Sven.Number(keys, "max_delay", lo)
	if hi <= lo then
		return lo
	end
	return RandomFloat(lo, hi)
end

nextFire = 0

function Tick()
	if not running then
		return 1
	end
	if Time() >= nextFire then
		local list = targets()
		if #list > 0 then
			local pick = list[RandomInt(1, #list)]
			Sven.Debug("trigger_random_time %s: fires %s", tostring(keys.targetname), pick)
			Sven.Fire(pick, self)
		end
		nextFire = Time() + nextDelay()
	end
	return math.max(nextFire - Time(), 0.05)
end

function InputUse()
	local mode = self:GetField("script_triggermode")
	if mode == 0 then
		running = false
	elseif mode == 1 then
		running = true
	else
		running = not running
	end
	if running then
		nextFire = Time() + nextDelay()
		AddThinkToEnt(self, "Tick")
	else
		AddThinkToEnt(self, "")
	end
end
