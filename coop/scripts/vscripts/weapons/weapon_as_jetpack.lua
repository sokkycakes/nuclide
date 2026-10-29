-- weapon_as_jetpack (pizza_ya_san): an automatic pistol with a jetpack.
-- Hold alt fire to fly: gravity drops to 0.3 and you're pushed up and
-- along. Fuel is uranium, about one every 0.6 seconds of flight. Gravity
-- comes back a second after the last push.
-- Behaviour follows the map's own weapon script. Its reload changes the
-- boost level (1-10); here it stays at 10.

local LOW_GRAVITY = 0.3
local POWER = 10
local TICKS_PER_FUEL = 12  -- alt fire runs every 0.05s
local MAX_RISE = 600       -- not in the map's script; keeps a held boost sane

lastBoost = -10
fuelTicks = 0
lowGravity = false

local function restoreGravity(player)
	if lowGravity and player ~= nil then
		player:SetField("gravity", 1)
	end
	lowGravity = false
end

function OnFire(fireInfo)
	if fireInfo ~= "fireInfo_jetpack_boost" then
		return
	end
	local player = self:GetOwner()
	if player == nil or (player:GetField("waterlevel") or 0) >= 3 then
		return
	end
	if QC.Call("Script_GetAmmo", player, "ammo_uranium") <= 0 then
		return
	end

	player:SetField("gravity", LOW_GRAVITY)
	lowGravity = true
	lastBoost = Time()

	-- the map's script pushes every 0.01s; we push every 0.05s, so 5 times as hard
	local v = player:GetVelocity()
	local ax = (v.x < 10) and 0 or 0.15
	local ay = (v.y < 10) and 0 or 0.15
	local push = Vector(10 * ax, 10 * ay, 10 + 3 * POWER) * 5
	v = v + push
	if v.z > MAX_RISE then
		v = Vector(v.x, v.y, MAX_RISE)
	end
	player:SetVelocity(v)
	Sven.Debug("weapon_as_jetpack: boost, velocity %s", tostring(v))

	fuelTicks = fuelTicks + 1
	if fuelTicks >= TICKS_PER_FUEL then
		fuelTicks = 0
		QC.Call("Script_UseAmmo", player, "ammo_uranium", 1)
	end
	if fuelTicks % 6 == 1 then
		Sven.Sound(player, "ambience/steamburst1.wav", 2, 0.8)
	end
end

function OnHolster()
	restoreGravity(self:GetOwner())
end

function Tick()
	if lowGravity and Time() > lastBoost + 1 then
		restoreGravity(self:GetOwner())
	end
	return 0.1
end

PrecacheSound("ambience/steamburst1.wav")
AddThinkToEnt(self, "Tick")
