from pathlib import Path
p=Path('../workspace/fteqw/_worktrees/webcore-cpu-renderer/engine/common/lobby_transport.c')
s=p.read_text(encoding='utf-8')
old='''\t\tif (map && *map)
\t\t\tLobby_Transport_BroadcastRule("map", map);
\t}
}
'''
new='''\t\tif (map && *map)
\t\t\tLobby_Transport_BroadcastRule("map", map);
\t}
    /* Recover state for late joins or a missed transition. */
    {
        char value[32];
        Q_snprintfz(value, sizeof(value), "%i", (int)Lobby_GetState());
        Lobby_Transport_BroadcastRule("lobby_state", value);
        if (Lobby_GetState() == LOBBY_STATE_COUNTDOWN) {
            Q_snprintfz(value, sizeof(value), "%.3f", Lobby_GetCountdownRemaining());
            Lobby_Transport_BroadcastRule("countdown_remaining", value);
        }
    }
}
'''
assert s.count(old)==1
s=s.replace(old,new)
p.write_text(s,encoding='utf-8')
Path('C:/bld/fteqw_src2/engine/common/lobby_transport.c').write_text(s,encoding='utf-8')
