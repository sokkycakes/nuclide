-- weapon_grapple (Sven Co-op's barnacle): hold fire to shoot the tongue;
-- once it sticks to something you're pulled to it until you let go.

local RANGE = 1024
local PULL_SPEED = 750

attached = false
anchor = nil
lastFire = 0

function OnFire(fireInfo)
	local player = self:GetOwner()
	if player == nil then
		return
	end
	lastFire = Time()
	if attached then
		return
	end
	local eye = Sven.EyePos(player)
	local dir = Sven.Forward(player)
	local hit, fraction = Sven.Trace(eye, eye + dir * RANGE, player, false)
	if fraction < 1 and not Sven.HitSky(hit, dir) then
		attached = true
		anchor = hit
		Sven.Debug("weapon_grapple: stuck at %s", tostring(hit))
		Sven.Sound(player, "weapons/bgrapple_impact.wav")
	else
		Sven.Debug("weapon_grapple: missed (fraction %.2f)", fraction)
	end
end

local function release(player)
	attached = false
	anchor = nil
end

function OnHolster()
	release(self:GetOwner())
end

function Tick()
	if not attached then
		return 0.05
	end
	local player = self:GetOwner()
	if player == nil or Time() - lastFire > 0.15 then
		release(player)
		return 0.05
	end
	local delta = anchor - Sven.EyePos(player)
	if delta:Length() < 48 then
		player:SetVelocity(Vector(0, 0, 0))
	else
		player:SetVelocity(delta:Normalized() * PULL_SPEED)
	end
	return 0.05
end

PrecacheSound("weapons/bgrapple_impact.wav")
AddThinkToEnt(self, "Tick")
