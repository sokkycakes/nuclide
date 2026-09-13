from pathlib import Path
import json, hashlib
root=Path.cwd(); engine=root.parent/'workspace/fteqw/_worktrees/webcore-cpu-renderer'; out=root/'_lobby_diag/figma-port'
manifest=[]
def save(path, text):
    staged=out/'followup'/path; staged.parent.mkdir(parents=True,exist_ok=True); staged.write_text(text,encoding='utf-8')
    manifest.append({'path':path,'sha256':hashlib.sha256((engine/path).read_bytes()).hexdigest()})
path='plugins/webcore/webcore.c'; s=(engine/path).read_text(encoding='utf-8-sig')
needle='static int WebCore_EnsureHost(void)'
fontcode='''/* Register shipped TTFs privately in this process. No CSS font-face loader or
 * machine font installation is needed by the WinCairo menu. */
#ifdef _WIN32
static HANDLE webcore_menu_fonts[3];
#endif
static void WebCore_LoadMenuFonts(void)
{
#ifdef _WIN32
    static const char *paths[] = {
        "data/web/hud/assets/fonts/TradeGothicNextLTProBdCn.ttf",
        "data/web/lobby-menu/assets/fonts/Inter-Regular.ttf",
        "data/web/lobby-menu/assets/fonts/Inter-Bold.ttf"
    };
    size_t i;
    if (!fsfuncs) return;
    for (i = 0; i < 3; i++) {
        size_t size = 0;
        void *data;
        DWORD count = 0;
        if (webcore_menu_fonts[i]) continue;
        data = fsfuncs->LoadFile(paths[i], &size);
        if (!data) continue;
        if (size > 12 && size < 4194304)
            webcore_menu_fonts[i] = AddFontMemResourceEx(data, (DWORD)size, NULL, &count);
        plugfuncs->Free(data);
    }
#endif
}
static void WebCore_FreeMenuFonts(void)
{
#ifdef _WIN32
    size_t i;
    for (i = 0; i < 3; i++) {
        if (webcore_menu_fonts[i]) RemoveFontMemResourceEx(webcore_menu_fonts[i]);
        webcore_menu_fonts[i] = NULL;
    }
#endif
}

'''
assert needle in s;s=s.replace(needle,fontcode+needle)
needle='\twebcore_host_initialized = 1;';assert needle in s;s=s.replace(needle,'    WebCore_LoadMenuFonts();\n'+needle)
needle='\twebcore_update_active = 0;\n\treturn 0;';assert needle in s;s=s.replace(needle,'    WebCore_FreeMenuFonts();\n'+needle)
save(path,s)
# Each sender has an independent reliable sequence counter; distinguish their packets.
path='engine/common/lobby_transport.c';s=(engine/path).read_text(encoding='utf-8-sig')
s=s.replace('static unsigned lobby_seen_seq[LOBBY_SEEN_RING];','static unsigned lobby_seen_seq[LOBBY_SEEN_RING];\nstatic netadr_t lobby_seen_adr[LOBBY_SEEN_RING];')
s=s.replace('if (lobby_seen_seq[i] == seq)','if (lobby_seen_seq[i] == seq && NET_CompareAdr(&lobby_seen_adr[i], &net_from))')
start=s.index('static void Lobby_Transport_RememberSeq(unsigned seq)');end=s.index('\nstatic qboolean Lobby_Transport_ParseUdpAdr',start)
s=s[:start]+'''static void Lobby_Transport_RememberSeq(unsigned seq)
{
    int slot;
    if (lobby_seen_n < LOBBY_SEEN_RING) slot = lobby_seen_n++;
    else {
        memmove(lobby_seen_seq, lobby_seen_seq + 1, (LOBBY_SEEN_RING - 1) * sizeof(lobby_seen_seq[0]));
        memmove(lobby_seen_adr, lobby_seen_adr + 1, (LOBBY_SEEN_RING - 1) * sizeof(lobby_seen_adr[0]));
        slot = LOBBY_SEEN_RING - 1;
    }
    lobby_seen_seq[slot] = seq;
    lobby_seen_adr[slot] = net_from;
}
''' + s[end:]
save(path,s)
(out/'followup-manifest.json').write_text(json.dumps(manifest,indent=2))
print('Staged private font registration and per-sender chat reliability.')
