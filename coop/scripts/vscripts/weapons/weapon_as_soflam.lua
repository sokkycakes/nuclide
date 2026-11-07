-- weapon_as_soflam (pizza_ya_san): a laser designator. Fire at a spot
-- under open sky and a mortar strike lands there 5 seconds later: 8 shells,
-- 0.75 seconds apart, scattered 150 units (alt fire: 500). Keeping the
-- laser on the spot doubles the shells. One charge (rocket ammo) per
-- strike, then 15 seconds before the next request.
-- Behaviour follows the map's own weapon script.

local COOLDOWN = 15
local SHELLS = 8
local INTERVAL = 0.75
local LEAD_TIME = 5
local BONUS_RANGE = 120

strike = -1          -- shells dropped so far, -1 when no strike is on
nextShell = 0
lastRequest = -COOLDOWN
hitPos = nil
skyPos = nil
wide = false

local radio = { "hgrunt/roger.wav", "hgrunt/yessir.wav", "hgrunt/affirmative.wav" }

local function aimPoint(player)
	local eye = Sven.EyePos(player)
	local dir = Sven.Forward(player)
	local endPos, fraction = Sven.Trace(eye, eye + dir * 8192, player, true)
	return endPos, fraction, dir
end

function OnFire(fireInfo)
	local player = self:GetOwner()
	if player == nil then
		return
	end
	if strike ~= -1 or Time() < lastRequest + COOLDOWN then
		return
	end
	if QC.Call("Script_GetAmmo", player, "ammo_rocket") <= 0 then
		return
	end

	local endPos, fraction, dir = aimPoint(player)
	local up = nil
	if fraction < 1 and not Sven.HitSky(endPos, dir) then
		local top, topFraction = Sven.Trace(endPos, endPos + Vector(0, 0, 8192), player, true)
		if topFraction < 1 and Sven.HitSky(top, Vector(0, 0, 1)) then
			up = top
		end
	end

	Sven.Debug("weapon_as_soflam: aimed at %s, sky above %s", tostring(endPos), tostring(up))
	if up == nil then
		Sven.Sound(player, "hgrunt/negative.wav")
		Sven.CenterPrint(player, "Can not execute fire support to there!!")
		return
	end

	wide = (fireInfo == "fireInfo_soflam_wide")
	hitPos = endPos
	skyPos = up
	strike = 0
	nextShell = Time() + LEAD_TIME
	lastRequest = Time()
	Sven.Sound(player, radio[RandomInt(1, #radio)])
	if wide then
		Sven.CenterPrint(player, "Wide range fire support was requested!!\n\nTake cover!!")
	else
		Sven.CenterPrint(player, "Fire support was requested!!\n\nTake cover!!")
	end
end

local function dropShell(player, bonus)
	local spread = wide and 500 or 150
	local count = bonus and 2 or 1
	for _ = 1, count do
		local from = skyPos + Vector(RandomInt(-spread, spread), RandomInt(-spread, spread), -20)
		local shell = QC.CallEntity("Script_LaunchProjectile", "projectile_sven_mortar", player, from, Vector(90, 0, 0))
		if shell ~= nil and shell:IsValid() and shell:entindex() > 0 then
			shell:SetVelocity(Vector(RandomInt(-50, 50), RandomInt(-50, 50), RandomInt(-400, -250)))
		end
	end
	Sven.Sound(player, "weapons/mortar.wav", 2, 1)
end

function Tick()
	if strike == -1 or Time() < nextShell then
		return 0.05
	end
	local player = self:GetOwner()
	if player == nil then
		strike = -1
		return 0.05
	end
	if strike == 0 then
		QC.Call("Script_UseAmmo", player, "ammo_rocket", 1)
	end
	local aim = aimPoint(player)
	local bonus = (aim - hitPos):Length() < BONUS_RANGE
	Sven.Debug("weapon_as_soflam: shell %d%s", strike + 1, bonus and " (on target, x2)" or "")
	dropShell(player, bonus)
	strike = strike + 1
	nextShell = Time() + INTERVAL
	if strike >= SHELLS then
		strike = -1
	end
	return 0.05
end

for _, s in ipairs(radio) do PrecacheSound(s) end
PrecacheSound("hgrunt/negative.wav")
PrecacheSound("weapons/mortar.wav")
PrecacheModel("models/grenade.mdl")
AddThinkToEnt(self, "Tick")
