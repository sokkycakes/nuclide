-- Sven Co-op map support for the co-op game, on Bulwark's script layer.
-- Written from the maps' own entity data and Sven Co-op's public
-- documentation of map entities and map .cfg files; no Sven Co-op or
-- AngelScript code is used.

Sven = {}

-- The map's keys for a scripted entity, as a table.
function Sven.Keys(ent)
	local raw = ent:GetField("script_spawndata") or ""
	local keys = {}
	for k, v in raw:gmatch('"([^"]*)"%s+"([^"]*)"') do
		keys[k] = v
	end
	return keys
end

function Sven.Number(keys, name, default)
	return tonumber(keys[name] or "") or default
end

-- Fires a map target the way a trigger_relay would.
function Sven.Fire(target, activator, delay)
	if target ~= nil and target ~= "" then
		EntFire(target, "Trigger", "", delay or 0, activator)
	end
end

function Sven.EntityByIndex(index)
	local e = Entities.First()
	while e ~= nil do
		if e:entindex() == index then
			return e
		end
		e = Entities.Next(e)
	end
	return nil
end

-- Players are "player" until the co-op game makes them "player_mp".
function Sven.Players()
	local list = {}
	for _, class in ipairs({ "player", "player_mp" }) do
		local e = Entities.FindByClassname(nil, class)
		while e ~= nil do
			list[#list + 1] = e
			e = Entities.FindByClassname(e, class)
		end
	end
	return list
end

-- Reads a text file through the server's QC file builtins. QC's fgets
-- gives "" for both an empty line and the end of the file, so reading
-- stops after a run of empty results.
function Sven.ReadLines(path)
	local fh = QC.Call("fopen", path, 0)
	if fh == nil or fh < 0 then
		return nil
	end
	local lines, empty = {}, 0
	while empty < 16 do
		local line = QC.CallString("fgets", fh)
		if line == nil or line == "" then
			empty = empty + 1
		else
			for _ = 1, empty do lines[#lines + 1] = "" end
			empty = 0
			lines[#lines + 1] = line
		end
	end
	QC.Call("fclose", fh)
	return lines
end

-- Map .cfg files ---------------------------------------------------------
--
-- Each line is "name [value]". The ones that set up players:
--   weapon_<x>          a weapon everyone spawns with
--   ammo_<x> <n>        n pickups' worth of that ammo
--   startarmor <n>      armour on spawn, starthealth <n> health
--   player_weaponstrip  spawn with nothing but what the cfg lists
--   nomedkit            no medkit (the co-op game doesn't hand one out)
-- Server settings (mp_timelimit, nextmap) are left to the server's own
-- config: setting them from a map load made Bulwark leave the map.
-- map_script and globalmodellist name AngelScript files and model swaps,
-- which aren't run.

-- Sven names of map cfg ammo, to the co-op game's ammo type and how much
-- one pickup gives.
Sven.AmmoTypes = {
	["9mm"] = { "ammo_9mm", 17 },
	["9mmclip"] = { "ammo_9mm", 17 },
	["9mmbox"] = { "ammo_9mm", 200 },
	["buckshot"] = { "ammo_buckshot", 12 },
	["357"] = { "ammo_357", 6 },
	["ARgrenades"] = { "ammo_m203_grenade", 2 },
	["rpgclip"] = { "ammo_rocket", 1 },
	["gaussclip"] = { "ammo_uranium", 20 },
	["crossbow"] = { "ammo_bolt", 5 },
	["556"] = { "ammo_556", 100 },
}

-- Sven weapon names that the co-op game knows by another name.
Sven.WeaponNames = {
	weapon_glock = "weapon_9mmhandgun",
}

Sven.Loadout = nil

function Sven.LoadMapConfig()
	local map = GetMapName()
	local lines = Sven.ReadLines("maps/" .. map .. ".cfg")
	if lines == nil then
		return
	end

	local loadout = { weapons = {}, ammo = {}, strip = false, armor = nil, health = nil }
	local ignored = {}

	for _, line in ipairs(lines) do
		line = line:gsub("//.*$", "")
		local name, value = line:match("^%s*(%S+)%s*(.-)%s*$")
		if name ~= nil then
			value = value:gsub('^"(.*)"$', "%1")
			if name:sub(1, 7) == "weapon_" then
				loadout.weapons[#loadout.weapons + 1] = Sven.WeaponNames[name] or name
			elseif name:sub(1, 5) == "ammo_" then
				loadout.ammo[#loadout.ammo + 1] = { name:sub(6), tonumber(value) or 1 }
			elseif name == "player_weaponstrip" then
				loadout.strip = true
			elseif name == "startarmor" then
				loadout.armor = tonumber(value)
			elseif name == "starthealth" then
				loadout.health = tonumber(value)
			elseif name == "nomedkit" then
				loadout.nomedkit = true
			else
				ignored[#ignored + 1] = name
			end
		end
	end

	Sven.Loadout = loadout
	printl(string.format("[sven] maps/%s.cfg: %d weapons, %d ammo, strip %s; not handled: %s",
		map, #loadout.weapons, #loadout.ammo, tostring(loadout.strip), table.concat(ignored, " ")))
end

function Sven.GiveLoadout(player)
	local loadout = Sven.Loadout
	if loadout == nil then
		return
	end

	-- inputs queue to the next frame, after the game's own spawn loadout
	if loadout.strip then
		player:FireInput("RemoveAllItems")
		player:FireInput("GiveItem", "item_suit")
	end
	for _, weapon in ipairs(loadout.weapons) do
		player:FireInput("GiveItem", weapon)
	end
	for _, ammo in ipairs(loadout.ammo) do
		local kind = Sven.AmmoTypes[ammo[1]]
		if kind ~= nil then
			player:FireInput("GiveAmmo", string.format("%s %d", kind[1], kind[2] * ammo[2]))
		end
	end
	if loadout.armor ~= nil then
		player:SetField("armor", loadout.armor)
	end
	if loadout.health ~= nil then
		player:SetHealth(loadout.health)
	end
end

function OnGameEvent_player_spawn(params)
	local player = Sven.EntityByIndex(tonumber(params.entindex) or -1)
	if player ~= nil then
		Sven.GiveLoadout(player)
	end
end
