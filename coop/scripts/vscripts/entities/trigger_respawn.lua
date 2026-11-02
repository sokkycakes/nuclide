-- trigger_respawn (Sven Co-op): respawns players at the spawn points that
-- are turned on. Spawnflag 1 respawns only the dead ones.

keys = Sven.Keys(self)

function InputUse()
	local flags = Sven.Number(keys, "spawnflags", 0)
	local who = (flags & 1) ~= 0 and "dead" or "all"
	SendToServerConsole("sv coop_respawn " .. who .. "\n")
end
