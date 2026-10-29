-- trigger_changevalue (Sven Co-op): sets a key on its target entities.
--   target           entities to change (by targetname)
--   m_iszValueName   the key
--   m_iszNewValue    the new value
--   m_iValueType     0 replaces; 1 adds, 2 multiplies, 3 subtracts (numbers)

keys = Sven.Keys(self)

local function apply(ent, name, value, kind)
	local old = ent:GetField(name)
	if old == nil then
		printl(string.format("[sven] trigger_changevalue %s: %s has no field %s",
			tostring(keys.targetname), ent:GetClassname(), name))
		return
	end
	if type(old) == "number" then
		local n = tonumber(value) or 0
		if kind == 1 then n = old + n
		elseif kind == 2 then n = old * n
		elseif kind == 3 then n = old - n
		end
		ent:SetField(name, n)
	else
		ent:SetField(name, value)
	end
	Sven.Debug("trigger_changevalue %s: %s %s = %s", tostring(keys.targetname),
		ent:GetClassname(), name, tostring(ent:GetField(name)))
end

function InputUse()
	local target = keys.target
	local name = keys.m_iszValueName
	if target == nil or name == nil then
		return
	end
	local value = keys.m_iszNewValue or ""
	local kind = Sven.Number(keys, "m_iValueType", 0)
	local e = Entities.FindByName(nil, target)
	while e ~= nil do
		apply(e, name, value, kind)
		e = Entities.FindByName(e, target)
	end
end
