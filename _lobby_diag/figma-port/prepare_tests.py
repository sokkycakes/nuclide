from pathlib import Path
import json, hashlib
root=Path.cwd(); engine=root.parent/'workspace/fteqw/_worktrees/webcore-cpu-renderer'; out=root/'_lobby_diag/figma-port'
path='plugins/webcore/tests/webcore_plugin_test.c'
s=(engine/path).read_text(encoding='utf-8-sig')
s=s.replace('{ "lobby_action:close", "lobby_close\\n" }', '''{ "lobby_action:close", "lobby_close\\n" },
            { "lobby_action:setruleset:DUEL", "lobby_set ruleset DUEL\\n" },
            { "lobby_action:setlimits:15:30", "lobby_limits 15 30\\n" },
            { "lobby_action:chat:6869", "lobby_chat_hex 6869\\n" }''')
needle='\t\tstatic const struct {\n\t\t\tconst char *request;\n\t\t\tconst char *command;\n\t\t} actions[] = {\n\t\t\t{ "arena_action:join"'
new='''        const char *invalid[] = { "lobby_action:chat:", "lobby_action:chat:1", "lobby_action:chat:zz", "lobby_action:chat:41;quit", "lobby_action:setlimits:181:0", "lobby_action:setlimits:1:2:3", "lobby_action:setlimits:1:-2", "lobby_action:setruleset:DUEL;quit" };
        size_t k, before = strlen(commands);
        for (k = 0; k < countof(invalid); k++)
            assert(!host_callbacks.js_query(host_callbacks.userdata, invalid[k], reply, sizeof(reply)));
        assert(strlen(commands) == before);
'''+needle
assert needle in s
s=s.replace(needle,new)
(out/path).parent.mkdir(parents=True,exist_ok=True)
(out/path).write_text(s,encoding='utf-8')
manifest=json.loads((out/'manifest.json').read_text())
manifest.append({'path':path,'sha256':hashlib.sha256((engine/path).read_bytes()).hexdigest()})
(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
