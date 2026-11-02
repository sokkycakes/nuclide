-- weaponbox (Sven Co-op): a box of ammo placed by the map.
--   bullet9mm, buckshot, bullet556, bullet357, ARgrenades, bolts,
--   uranium, rockets, handgrenade, ...   amounts of each ammo
--   m_flCustomRespawnTime                seconds until it comes back
-- It's spawned as an item_sven_weaponbox pickup that carries the ammo.

local AMMO = {
	bullet9mm = "ammo_9mm", buckshot = "ammo_buckshot", bullet556 = "ammo_556",
	bullet357 = "ammo_357", ARgrenades = "ammo_m203_grenade", bolts = "ammo_bolt",
	uranium = "ammo_uranium", rockets = "ammo_rocket", handgrenade = "ammo_handgrenade",
	satchelcharge = "ammo_satchel", tripmine = "ammo_tripmine", snarks = "ammo_snark",
}

keys = Sven.Keys(self)

local list = {}
local function add(k, v)
	if v ~= nil and v ~= "" then
		list[#list + 1] = string.format('"%s" "%s"', k, v)
	end
end
add("origin", keys.origin)
add("angles", keys.angles)
add("targetname", keys.targetname)
for key, ammo in pairs(AMMO) do
	if Sven.Number(keys, key, 0) > 0 then
		add("inv_ammo_" .. ammo:sub(6), keys[key])
	end
end
if Sven.Number(keys, "m_flCustomRespawnTime", 0) > 0 then
	add("respawn", keys.m_flCustomRespawnTime)
end

QC.Call("Script_PrecacheEntity", "item_sven_weaponbox")
box = QC.CallEntity("Script_SpawnEntity", "item_sven_weaponbox", table.concat(list, " "))
