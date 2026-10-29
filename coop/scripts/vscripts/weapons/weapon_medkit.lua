-- weapon_medkit (Sven Co-op): heals the player or friendly NPC in front of
-- you. Each use spends 10 supplies; supplies come back over time. A use
-- that heals nobody gives the supplies back.

local HEAL = 10

local function healable(ent, player)
	if ent == nil or ent == player or ent:GetHealth() <= 0 then
		return false
	end
	if Sven.IsPlayer(ent) then
		return true
	end
	-- friendly monsters (Nuclide's alliance 0)
	return ent:GetField("m_iAlliance") == 0 and ent:GetClassname():sub(1, 8) == "monster_"
end

function OnFire(fireInfo)
	local player = self:GetOwner()
	if player == nil then
		return
	end
	local eye = Sven.EyePos(player)
	local _, fraction, target = Sven.Trace(eye, eye + Sven.Forward(player) * 64, player, false)
	local healed = 0
	if fraction < 1 and healable(target, player) then
		local max = target:GetMaxHealth()
		if max <= 0 then
			max = 100
		end
		healed = math.max(0, math.min(HEAL, max - target:GetHealth()))
		if healed > 0 then
			target:SetHealth(target:GetHealth() + healed)
			Sven.Sound(player, "items/smallmedkit1.wav", 1, 1)
		end
	end
	Sven.Debug("weapon_medkit: %s healed %d", target and target:GetClassname() or "nothing", healed)
	if healed < HEAL then
		player:FireInput("GiveAmmo", string.format("ammo_medkit %d", HEAL - healed))
	end
end

PrecacheSound("items/smallmedkit1.wav")
