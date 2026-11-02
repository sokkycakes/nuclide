-- Runs in the root scope when a map loads. Sven Co-op map support lives in
-- sven/*.lua; the entity classes Nuclide lacks are in entities/*.lua.
IncludeScript("sven/sven.lua")
Sven.LoadMapConfig()
