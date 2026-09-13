from pathlib import Path
import hashlib, json
ROOT = Path.cwd()
ENGINE = ROOT.parent / 'workspace/fteqw/_worktrees/webcore-cpu-renderer'
OUT = ROOT / '_lobby_diag/figma-port'
manifest = []

def load(path):
    return (ENGINE / path).read_text(encoding='utf-8-sig')
def replace(text, old, new):
    assert text.count(old) == 1, (old[:100], text.count(old))
    return text.replace(old, new)
def save(path, text):
    original = ENGINE / path
    staged = OUT / path
    staged.parent.mkdir(parents=True, exist_ok=True)
    staged.write_text(text, encoding='utf-8')
    manifest.append({'path': path, 'sha256': hashlib.sha256(original.read_bytes()).hexdigest()})

path = 'engine/common/lobby_session.c'
s = load(path)
s = replace(s, 'static struct\n{\n\tqboolean', '''#define LOBBY_CHAT_HISTORY 10
#define LOBBY_CHAT_BYTES 240

typedef struct {
    unsigned id;
    int seat;
    char name[64];
    char text[LOBBY_CHAT_BYTES + 1];
} lobby_chat_t;

static struct
{
    lobby_chat_t chat[LOBBY_CHAT_HISTORY];
    unsigned chat_sequence;
    int chat_count;
\tqboolean''')
s = replace(s, 'static cvar_t lobby_snapshot_cv', 'static cvar_t lobby_chat_cv = CVARF("lobby_chat_snapshot", "[]", CVAR_NOSAVE);\nstatic cvar_t lobby_snapshot_cv')
s = replace(s, 'static void Lobby_PublishSnapshot(void)', '''static void Lobby_PublishChat(void)
{
    char json[8192], name[256], text[1024];
    size_t used = 1;
    int i;
    json[0] = '[';
    json[1] = 0;
    for (i = 0; i < lobby.chat_count; i++) {
        lobby_chat_t *m = &lobby.chat[i];
        Lobby_JsonEscape(name, sizeof(name), m->name);
        Lobby_JsonEscape(text, sizeof(text), m->text);
        if (Q_snprintfz(json + used, sizeof(json) - used,
            "%s{\\"id\\":%u,\\"seat\\":%i,\\"name\\":%s,\\"text\\":%s}",
            i ? "," : "", m->id, m->seat, name, text))
            break;
        used = strlen(json);
    }
    Q_snprintfz(json + used, sizeof(json) - used, "]");
    Cvar_Set(&lobby_chat_cv, json);
}

static void Lobby_PublishSnapshot(void)''')
s = replace(s, '\t\tCvar_Set(&lobby_active_cv, "0");', '\t\tCvar_Set(&lobby_active_cv, "0");\n        Cvar_Set(&lobby_chat_cv, "[]");')
needle = '\tLobby_JsonEscape(esc, sizeof(esc), map ? map : "");'
extra = '''    Q_snprintfz(json + used, sizeof(json) - used, "\\"\\",\\"uiVersion\\":1,\\"max\\":%i,\\"canChat\\":%s,\\"settings\\":{",
        lobby.is_host ? Lobby_GetMaxPlayers() : atoi(InfoBuf_ValueForKey(&lobby.settings, "maxplayers")),
        can_ready ? "true" : "false");
    used = strlen(json);
    {
        const char *keys[] = { "ruleset", "servertype", "timelimit", "fraglimit" };
        int k;
        for (k = 0; k < 4; k++) {
            Lobby_JsonEscape(esc, sizeof(esc), InfoBuf_ValueForKey(&lobby.settings, keys[k]));
            Q_snprintfz(json + used, sizeof(json) - used, "%s\\"%s\\":%s", k ? "," : "", keys[k], esc);
            used = strlen(json);
        }
    }
    Q_snprintfz(json + used, sizeof(json) - used, "},\\"map\\":");
    used = strlen(json);
'''
# The previous writer has emitted the map key. Emit settings before its final value.
s = replace(s, needle, extra + needle)
s = replace(s, '\tCvar_Set(&lobby_snapshot_cv, json);', '\tCvar_Set(&lobby_snapshot_cv, json);\n    Lobby_PublishChat();')
s = replace(s, '\tCvar_Register(&lobby_snapshot_cv, "Lobby");', '\tCvar_Register(&lobby_snapshot_cv, "Lobby");\n    Cvar_Register(&lobby_chat_cv, "Lobby");')
s = replace(s, '\tInfoBuf_SetKey(&lobby.settings, "servertype", "LISTEN SERVER");', '''\tInfoBuf_SetKey(&lobby.settings, "servertype", "LISTEN SERVER");
    InfoBuf_SetKey(&lobby.settings, "timelimit", "0");
    InfoBuf_SetKey(&lobby.settings, "fraglimit", "0");
    InfoBuf_SetKey(&lobby.settings, "maxplayers", va("%i", Lobby_GetMaxPlayers()));''')
s = replace(s, '\tif (lobby.state >= LOBBY_STATE_STARTING)\n\t\treturn false;\n\n\tInfoBuf_SetKey(&lobby.settings, key, value);', '''    if (lobby.state >= LOBBY_STATE_COUNTDOWN)
        return false;
    if (!strcmp(key, "ruleset") && strcmp(value, "DUEL") && strcmp(value, "DEATHMATCH") && strcmp(value, "TEAMDM") && strcmp(value, "DOMINATION"))
        return false;
    if (!strcmp(key, "timelimit") || !strcmp(key, "fraglimit")) {
        const char *p;
        if (!*value || strlen(value) > 3) return false;
        for (p = value; *p; p++) if (*p < '0' || *p > '9') return false;
        if (!strcmp(key, "timelimit") && atoi(value) > 180) return false;
    }
    InfoBuf_SetKey(&lobby.settings, key, value);''')
s = replace(s, '\tif (!strcmp(key, "map"))\n\t{', '\tif (!strcmp(key, "map") || !strcmp(key, "ruleset") || !strcmp(key, "timelimit") || !strcmp(key, "fraglimit"))\n\t{')
s = replace(s, '\tCbuf_AddText("deathmatch 1\\n", RESTRICT_LOCAL);', '''    {
        const char *ruleset = InfoBuf_ValueForKey(&lobby.settings, "ruleset");
        const char *game = !Q_strcasecmp(ruleset, "DUEL") ? "duel" :
            !Q_strcasecmp(ruleset, "TEAMDM") ? "teamdm" :
            !Q_strcasecmp(ruleset, "DOMINATION") ? "domination" : "deathmatch";
        Cbuf_AddText(va("set g_gametype %s\\n", game), RESTRICT_LOCAL);
        Cbuf_AddText(va("timelimit %i\\n", bound(0, atoi(InfoBuf_ValueForKey(&lobby.settings, "timelimit")), 180)), RESTRICT_LOCAL);
        Cbuf_AddText(va("fraglimit %i\\n", bound(0, atoi(InfoBuf_ValueForKey(&lobby.settings, "fraglimit")), 999)), RESTRICT_LOCAL);
    }
\tCbuf_AddText("deathmatch 1\\n", RESTRICT_LOCAL);''')
s = replace(s, '''\tif (!msg)
\t\treturn;
\tLobby_Emit(LOBBY_EVT_CHAT, seat, msg);''', '''    lobby_chat_t *entry;
    lobby_player_t *player = Lobby_FindPlayerBySeat(seat);
    if (!lobby.active || !player || !msg || !*msg || strlen(msg) > LOBBY_CHAT_BYTES)
        return;
    if (lobby.chat_count == LOBBY_CHAT_HISTORY) {
        memmove(lobby.chat, lobby.chat + 1, sizeof(lobby.chat[0]) * (LOBBY_CHAT_HISTORY - 1));
        lobby.chat_count--;
    }
    entry = &lobby.chat[lobby.chat_count++];
    entry->id = ++lobby.chat_sequence;
    entry->seat = seat;
    Q_strncpyz(entry->name, player->name, sizeof(entry->name));
    Q_strncpyz(entry->text, msg, sizeof(entry->text));
    Lobby_Emit(LOBBY_EVT_CHAT, seat, msg);''')
s = replace(s, 'static void Lobby_Create_f(void)', '''static int Lobby_HexDigit(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static void Lobby_ChatHex_f(void)
{
    char text[LOBBY_CHAT_BYTES + 1];
    const char *hex = Cmd_Argv(1);
    size_t i, n = strlen(hex);
    if (Cmd_Argc() != 2 || !lobby.active || lobby.local_seat < 0 ||
        lobby.state < LOBBY_STATE_WAITING || lobby.state >= LOBBY_STATE_STARTING ||
        !lobby.backend || !lobby.backend->send_chat || !n || (n & 1) || n > LOBBY_CHAT_BYTES * 2)
        return;
    for (i = 0; i < n; i += 2) {
        int a = Lobby_HexDigit(hex[i]), b = Lobby_HexDigit(hex[i + 1]);
        if (a < 0 || b < 0) return;
        text[i / 2] = (char)((a << 4) | b);
        if ((unsigned char)text[i / 2] < 0x20 || text[i / 2] == 0x7f) return;
    }
    text[n / 2] = 0;
    if (lobby.backend->send_chat(lobby.local_seat, text))
        Lobby_Kex_OnChat(lobby.local_seat, text);
}

static void Lobby_Limits_f(void)
{
    const char *minutes = Cmd_Argv(1), *frags = Cmd_Argv(2), *p;
    if (Cmd_Argc() != 3 || !*minutes || !*frags || strlen(minutes) > 3 || strlen(frags) > 3) return;
    for (p = minutes; *p; p++) if (*p < '0' || *p > '9') return;
    for (p = frags; *p; p++) if (*p < '0' || *p > '9') return;
    if (atoi(minutes) > 180) return;
    if (Lobby_SetSetting("timelimit", minutes)) Lobby_SetSetting("fraglimit", frags);
}

static void Lobby_Create_f(void)''')
s = replace(s, '\tCmd_AddCommandD("lobby_set", Lobby_Set_f, "Host sets a lobby key/value pair.");', '''\tCmd_AddCommandD("lobby_set", Lobby_Set_f, "Host sets a lobby key/value pair.");
    Cmd_AddCommandD("lobby_chat_hex", Lobby_ChatHex_f, "Send UTF-8 hex text to the current lobby.");
    Cmd_AddCommandD("lobby_limits", Lobby_Limits_f, "Host sets time and frag limits.");''')
# Avoid duplicate map property while adding snapshot fields.
s = replace(s, '"%s,\\"map\\":", esc);', '"%s,\\"uiVersion\\":", esc);')
s = replace(s, '"\\"\\",\\"uiVersion\\":1,\\"max\\":%i,', '"1,\\"max\\":%i,')
save(path, s)

path = 'engine/common/lobby_transport.c'
s = load(path)
s = replace(s, '''\tcase 'C':
\t\tif (!val)
\t\t\tbreak;
\t\tLobby_Kex_OnChat(seat, val);
\t\tbreak;''', '''    case 'C':
        if (!val || !*val || strlen(val) > LOBBY_CHAT_BYTES || !Lobby_FindPlayerBySeat(seat))
            break;
        if (Lobby_IsHost() ? !Lobby_Transport_PeerOwnsAdr(seat, &net_from) : !Lobby_Transport_PeerOwnsAdr(0, &net_from))
            break;
        Lobby_Kex_OnChat(seat, val);
        if (Lobby_IsHost()) Lobby_Transport_Relay(seat, raw, (size_t)strlen(raw));
        break;''')
s = replace(s, '''\t\t/* Clients may only send rules from host; host applies own. Spoofed seat ignored. */
\t\tif (!Lobby_IsHost() && seat != -1 && seat != 0)
\t\t\tbreak;''', '''        /* Only the host may configure the session. */
        if (Lobby_IsHost() || !Lobby_Transport_PeerOwnsAdr(0, &net_from) || (seat != -1 && seat != 0))
            break;''')
needle = '\tif (Lobby_GetRoomCode()[0])'
insert = '''    {
        const char *keys[] = { "ruleset", "servertype", "timelimit", "fraglimit", "maxplayers" };
        int k;
        for (k = 0; k < 5; k++) {
            n = Lobby_FmtMsg(rule, sizeof(rule), "K:-1:%s=%s", keys[k], InfoBuf_ValueForKey(Lobby_GetSettings(), keys[k]));
            if (n > 0) Lobby_Transport_SendReliableAdr(to, rule, (size_t)n);
        }
    }
'''
s = replace(s, needle, insert + needle)
save(path, s)

path = 'plugins/webcore/webcore.c'
s = load(path)
s = replace(s, '\telse if (!strcmp(request, "getarena"))', '''    else if (!strcmp(request, "getlobbychat"))
    {
        if (!cvarfuncs || !cvarfuncs->GetString("lobby_chat_snapshot", result, sizeof(result)) || result[0] != '[')
            Q_strlcpy(result, "[]", sizeof(result));
    }
\telse if (!strcmp(request, "getarena"))''')
s = replace(s, '\t\tchar line[96];\n\t\tif (!cmdfuncs || !action', '\t\tchar line[512];\n\t\tif (!cmdfuncs || !action')
needle = '\t\telse if (!strncmp(action, "setmap:", 7))'
insert = '''        else if (!strncmp(action, "setruleset:", 11))
        {
            const char *rule = action + 11;
            if (strcmp(rule, "DUEL") && strcmp(rule, "DEATHMATCH") && strcmp(rule, "TEAMDM") && strcmp(rule, "DOMINATION")) return 0;
            Q_snprintfz(line, sizeof(line), "lobby_set ruleset %s\\n", rule);
        }
        else if (!strncmp(action, "setlimits:", 10))
        {
            const char *value = action + 10, *colon = strchr(value, ':');
            size_t i, n = strlen(value);
            if (!colon || colon == value || !colon[1] || n > 7 || (colon - value) > 3 || strlen(colon + 1) > 3) return 0;
            for (i = 0; i < n; i++) if (value + i != colon && (value[i] < '0' || value[i] > '9')) return 0;
            if (atoi(value) > 180) return 0;
            Q_snprintfz(line, sizeof(line), "lobby_limits %i %i\\n", atoi(value), atoi(colon + 1));
        }
        else if (!strncmp(action, "chat:", 5))
        {
            const char *hex = action + 5;
            size_t i, n = strlen(hex);
            if (!n || (n & 1) || n > 480) return 0;
            for (i = 0; i < n; i++) if (!((hex[i] >= '0' && hex[i] <= '9') || (hex[i] >= 'a' && hex[i] <= 'f') || (hex[i] >= 'A' && hex[i] <= 'F'))) return 0;
            Q_snprintfz(line, sizeof(line), "lobby_chat_hex %s\\n", hex);
        }
'''
s = replace(s, needle, insert + needle)
save(path, s)
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print('Staged:', ', '.join(x['path'] for x in manifest))

