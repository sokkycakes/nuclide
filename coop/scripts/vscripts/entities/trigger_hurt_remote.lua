-- trigger_hurt_remote (Sven Co-op): damages its target entities when
-- triggered.
--   target   entities to hurt (by targetname)
--   dmg      damage; a negative value heals

keys = Sven.Keys(self)

function InputUse()
	local target = keys.target
	if target == nil then
		return
	end
	local dmg = Sven.Number(keys, "dmg", 10)
	local e = Entities.FindByName(nil, target)
	while e ~= nil do
		if dmg >= 0 then
			e:FireInput("Damage", string.format("%d", math.min(dmg, 1e9)), 0, activator)
		else
			e:SetHealth(math.min(e:GetHealth() - dmg, e:GetMaxHealth()))
		end
		e = Entities.FindByName(e, target)
	end
end
