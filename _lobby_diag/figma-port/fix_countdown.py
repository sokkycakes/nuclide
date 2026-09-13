from pathlib import Path
root = Path('C:/Users/sokky/Documents/Godot/bulwark_proto_funny/workspace/fteqw/_worktrees/webcore-cpu-renderer')
p = root/'engine/common/lobby_session.c'
s = p.read_text(encoding='utf-8')
old = '''\t\tlobby.backend->send_rule("countdown_end", buf);
'''
new = old + '''        /* Relative duration is portable across independently started clients. */
        Q_snprintfz(buf, sizeof(buf), "%.3f", secs);
        lobby.backend->send_rule("countdown_remaining", buf);
'''
assert s.count(old)==1
s = s.replace(old,new)
old = '''\tInfoBuf_SetKey(&lobby.settings, key, value);
\tif (!strcmp(key, "ingame") && atoi(value))'''
new = '''\tInfoBuf_SetKey(&lobby.settings, key, value);
    if (!lobby.is_host && !strcmp(key, "lobby_state"))
    {
        int state = atoi(value);
        if (state >= LOBBY_STATE_WAITING && state <= LOBBY_STATE_CLOSING)
        {
            /* Apply the host state without sending it back over the transport. */
            lobby.state = (lobby_state_t)state;
            if (state != LOBBY_STATE_COUNTDOWN)
                lobby.countdown_end = 0;
            Lobby_Emit(LOBBY_EVT_STATE_CHANGED, -1, value);
        }
    }
    else if (!lobby.is_host && !strcmp(key, "countdown_remaining"))
    {
        float remaining = atof(value);
        lobby.countdown_end = realtime + bound(0, remaining, 3600);
    }
\tif (!strcmp(key, "ingame") && atoi(value))'''
assert s.count(old)==1
s=s.replace(old,new)
p.write_text(s,encoding='utf-8')
Path('C:/bld/fteqw_src2/engine/common/lobby_session.c').write_text(s,encoding='utf-8')
