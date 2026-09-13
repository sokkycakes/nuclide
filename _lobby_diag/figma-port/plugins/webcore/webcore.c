#include "../plugin.h"
#include "../engine.h"
#include "webcore_abi.h"
#include "webcore_helpers.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#endif

static plugfsfuncs_t *fsfuncs;
static plugclientfuncs_t *clientfuncs;
static plugaudiofuncs_t *audiofuncs;
static plugsubconsolefuncs_t *confuncs;
static plugmasterfuncs_t *masterfuncs;
static dllhandle_t *host_dll;
static ftewebcore_api_t host;
static int webcore_host_initialized;
static int webcore_update_active;

#ifdef _WIN32
typedef DWORD webcore_thread_t;
typedef CRITICAL_SECTION webcore_mutex_t;
#define WEBCORE_THREAD_CAPTURE(t) (*(t) = GetCurrentThreadId())
#define WEBCORE_THREAD_IS_CURRENT(t) (*(t) == GetCurrentThreadId())
#define WEBCORE_MUTEX_INIT(m) InitializeCriticalSection(m)
#define WEBCORE_MUTEX_DESTROY(m) DeleteCriticalSection(m)
#define WEBCORE_MUTEX_LOCK(m) EnterCriticalSection(m)
#define WEBCORE_MUTEX_UNLOCK(m) LeaveCriticalSection(m)
#else
typedef pthread_t webcore_thread_t;
typedef pthread_mutex_t webcore_mutex_t;
#define WEBCORE_THREAD_CAPTURE(t) (*(t) = pthread_self())
#define WEBCORE_THREAD_IS_CURRENT(t) pthread_equal(*(t), pthread_self())
#define WEBCORE_MUTEX_INIT(m) pthread_mutex_init((m), NULL)
#define WEBCORE_MUTEX_DESTROY(m) pthread_mutex_destroy(m)
#define WEBCORE_MUTEX_LOCK(m) pthread_mutex_lock(m)
#define WEBCORE_MUTEX_UNLOCK(m) pthread_mutex_unlock(m)
#endif

static webcore_thread_t engine_thread;

typedef struct webcore_browser_s webcore_browser_t;
typedef struct webcore_resource_s
{
	struct webcore_resource_s *next;
	webcore_browser_t *owner;
	void *data;
	const char *mime;
} webcore_resource_t;

struct webcore_browser_s
{
	struct webcore_browser_s *next;
	ftewebcore_view_t *view;
	ftewebcore_callbacks_t callbacks;
	webcore_mutex_t mutex;
	unsigned char *pixels;
	size_t pixels_size;
	int width, height;
	int desired_width, desired_height;
	int mouse_x, mouse_y;
	int updated;
	int closing;
	char url[MAX_OSPATH];
	webcore_resource_t *resources;
};

static webcore_browser_t *browsers;

static int WebCore_InEngineUpdate(void)
{
	return webcore_update_active && WEBCORE_THREAD_IS_CURRENT(&engine_thread);
}

static qboolean WebCore_ArenaHeroAllowed(const char *hero)
{
	char heroes[512];
	const char *cursor;
	size_t i, n;

	if (!cvarfuncs || !hero || !*hero)
		return false;
	n = strlen(hero);
	if (n >= 64)
		return false;
	for (i = 0; i < n; ++i)
	{
		char c = hero[i];
		if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
			(c >= '0' && c <= '9') || c == '_'))
			return false;
	}
	if (!cvarfuncs->GetString("webcore_arena_hero_ids", heroes, sizeof(heroes)))
		return false;
	/* A truncated capability list must never authorize an action. */
	if (strlen(heroes) >= sizeof(heroes) - 1)
		return false;
	for (cursor = heroes; *cursor;)
	{
		const char *start;
		size_t token_len;
		while (*cursor == ' ' || *cursor == '	')
			++cursor;
		start = cursor;
		while (*cursor && *cursor != ' ' && *cursor != '	')
			++cursor;
		token_len = (size_t)(cursor - start);
		if (token_len == n && !strncmp(start, hero, n))
			return true;
	}
	return false;
}

static void WebCore_JSONSkipSpace(const char **cursor)
{
	while (**cursor == ' ' || (unsigned char)**cursor == 0x09 ||
		(unsigned char)**cursor == 0x0d || (unsigned char)**cursor == 0x0a)
		++*cursor;
}

static qboolean WebCore_JSONSkipString(const char **cursor)
{
	const char *p = *cursor;
	if (*p++ != '\"')
		return false;
	while (*p && *p != '\"')
	{
		if ((unsigned char)*p < 0x20)
			return false;
		if (*p++ == '\\')
		{
			if (!*p || !strchr("\"\\/bfnrtu", *p++))
				return false;
		}
	}
	if (*p++ != '\"')
		return false;
	*cursor = p;
	return true;
}

static qboolean WebCore_JSONSkipValue(const char **cursor, int depth)
{
	const char *p;
	if (depth > 16)
		return false;
	WebCore_JSONSkipSpace(cursor);
	p = *cursor;
	if (*p == '\"')
		return WebCore_JSONSkipString(cursor);
	if (!strncmp(p, "true", 4) || !strncmp(p, "null", 4))
	{
		*cursor = p + 4;
		return true;
	}
	if (!strncmp(p, "false", 5))
	{
		*cursor = p + 5;
		return true;
	}
	if (*p == '{' || *p == '[')
	{
		char close = (*p++ == '{') ? '}' : ']';
		*cursor = p;
		WebCore_JSONSkipSpace(cursor);
		if (**cursor == close)
		{
			++*cursor;
			return true;
		}
		for (;;)
		{
			if (close == '}' && !WebCore_JSONSkipString(cursor))
				return false;
			WebCore_JSONSkipSpace(cursor);
			if (close == '}' && *(*cursor)++ != ':')
				return false;
			if (!WebCore_JSONSkipValue(cursor, depth + 1))
				return false;
			WebCore_JSONSkipSpace(cursor);
			if (**cursor == close)
			{
				++*cursor;
				return true;
			}
			if (*(*cursor)++ != ',')
				return false;
			WebCore_JSONSkipSpace(cursor);
		}
	}
	if (*p == '-' || (*p >= '0' && *p <= '9'))
	{
		char *end;
		strtod(p, &end);
		if (end == p)
			return false;
		*cursor = end;
		return true;
	}
	return false;
}

static qboolean WebCore_ValidArenaSnapshot(const char *snapshot, size_t capacity)
{
	const char *p;
	qboolean active = false, have_active = false;

	if (!snapshot || !snapshot[0] || strlen(snapshot) >= capacity - 1)
		return false;
	p = snapshot;
	WebCore_JSONSkipSpace(&p);
	if (*p++ != '{')
		return false;
	WebCore_JSONSkipSpace(&p);
	while (*p != '}')
	{
		const char *key = p;
		size_t keylen;
		if (!WebCore_JSONSkipString(&p))
			return false;
		keylen = (size_t)(p - key);
		WebCore_JSONSkipSpace(&p);
		if (*p++ != ':')
			return false;
		WebCore_JSONSkipSpace(&p);
		if (keylen == 8 && !strncmp(key, "\"active\"", 8))
		{
			if (!strncmp(p, "true", 4)) { active = true; p += 4; }
			else if (!strncmp(p, "false", 5)) { active = false; p += 5; }
			else return false;
			have_active = true;
		}
		else if (!WebCore_JSONSkipValue(&p, 0))
			return false;
		WebCore_JSONSkipSpace(&p);
		if (*p == '}')
			break;
		if (*p++ != ',')
			return false;
		WebCore_JSONSkipSpace(&p);
		if (*p == '}')
			return false;
	}
	if (*p++ != '}')
		return false;
	WebCore_JSONSkipSpace(&p);
	return have_active && active && !*p;
}

static const char *WebCore_MimeType(const char *path)
{
	const char *extension = strrchr(path, '.');
	if (!extension) return "application/octet-stream";
	/* Bare types only: "text/html; charset=..." becomes TextDocument in WebKit. */
	if (!strcasecmp(extension, ".html") || !strcasecmp(extension, ".htm")) return "text/html";
	if (!strcasecmp(extension, ".css")) return "text/css";
	if (!strcasecmp(extension, ".js") || !strcasecmp(extension, ".mjs")) return "text/javascript";
	if (!strcasecmp(extension, ".json")) return "application/json";
	if (!strcasecmp(extension, ".png")) return "image/png";
	if (!strcasecmp(extension, ".jpg") || !strcasecmp(extension, ".jpeg")) return "image/jpeg";
	if (!strcasecmp(extension, ".svg")) return "image/svg+xml";
	if (!strcasecmp(extension, ".woff")) return "font/woff";
	if (!strcasecmp(extension, ".woff2")) return "font/woff2";
	if (!strcasecmp(extension, ".ttf")) return "font/ttf";
	if (!strcasecmp(extension, ".otf")) return "font/otf";
	if (!strcasecmp(extension, ".wav")) return "audio/wav";
	if (!strcasecmp(extension, ".ogg")) return "audio/ogg";
	if (!strcasecmp(extension, ".mp3")) return "audio/mpeg";
	return "application/octet-stream";
}

static int WebCore_ResourceOpen(void *userdata, const char *url,
	const void **data, size_t *size, const char **mime_type, void **resource)
{
	webcore_browser_t *browser = (webcore_browser_t *)userdata;
	char clean_path[MAX_OSPATH];
	webcore_resource_t *opened;

	/* Engine thread only. Prefer Tick/update, but deferred image loads may
	 * arrive after host.update() returns — still serve them. */
	if (!browser || !WEBCORE_THREAD_IS_CURRENT(&engine_thread) ||
		!data || !size || !mime_type || !resource)
	{
		Con_Printf("WebCore: resource_open rejected (thread/args) \"%s\"\n",
			url ? url : "(null)");
		return 0;
	}
	if (!WebCore_MapLocalURL(url, clean_path, sizeof(clean_path)))
	{
		Con_Printf("WebCore: bad fte URL \"%s\"\n", url ? url : "(null)");
		return 0;
	}

	opened = (webcore_resource_t *)malloc(sizeof(*opened));
	if (!opened)
		return 0;
	memset(opened, 0, sizeof(*opened));
	opened->data = fsfuncs->LoadFile(clean_path, size);
	opened->mime = WebCore_MimeType(clean_path);
	if (!opened->data)
	{
		Con_Printf("WebCore: failed to load \"%s\"\n", clean_path);
		free(opened);
		return 0;
	}
	*data = opened->data;
	*mime_type = opened->mime;
	*resource = opened;
	opened->owner = browser;
	opened->next = browser->resources;
	browser->resources = opened;
	/* Log image/SVG opens — CSS/JS noise is skipped. */
	if (opened->mime && (!strncmp(opened->mime, "image/", 6) ||
		!strcmp(opened->mime, "image/svg+xml")))
		Con_Printf("WebCore: loaded %s (%u bytes, %s)\n",
			clean_path, (unsigned)*size, opened->mime);
	return 1;
}

static void WebCore_FreeResource(webcore_resource_t *opened)
{
	if (opened->data)
		plugfuncs->Free(opened->data);
	free(opened);
}

static void WebCore_ResourceClose(void *userdata, void *resource)
{
	webcore_resource_t *opened = (webcore_resource_t *)resource;
	webcore_browser_t *browser = (webcore_browser_t *)userdata;
	webcore_resource_t **link;

	if (!browser || !opened || !WEBCORE_THREAD_IS_CURRENT(&engine_thread) ||
		opened->owner != browser)
		return;
	for (link = &browser->resources; *link && *link != opened;
		link = &(*link)->next)
		;
	if (!*link)
		return;
	*link = opened->next;
	opened->owner = NULL;
	WebCore_FreeResource(opened);
}

/* Same console commands Slint title/pause menus fire via Cbuf_AddText. */
static int WebCore_CbufAllowed(const char *cmd)
{
	static const char *const allowed[] = {
		"menu_maps", "menu_newmulti", "menu_options", "quit",
		"menu_hostmenu", "menu_changeteam", "menu_callvote",
		"disconnect", "togglemenu", "webcore_closemenu",
		"menu_lobby_create", "menu_webcore", "menu_webcore_lobby", "menu_webcore_title",
		"lobby_create_lan", "lobby_create_online", "lobby_ready", "lobby_start", "lobby_cancel", "lobby_close",
		NULL
	};
	size_t i, n;

	if (!cmd || !*cmd)
		return 0;
	n = strlen(cmd);
	if (n >= 64)
		return 0;
	for (i = 0; i < n; ++i)
	{
		char c = cmd[i];
		if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
			(c >= '0' && c <= '9') || c == '_' || c == '-'))
			return 0;
	}
	for (i = 0; allowed[i]; ++i)
	{
		if (!strcmp(cmd, allowed[i]))
			return 1;
	}
	return 0;
}

/* Local copies of hostcachekey_t (cl_master.h) — plugins don't include that header. */
enum {
	WC_SLKEY_PING = 0,
	WC_SLKEY_MAP,
	WC_SLKEY_NAME,
	WC_SLKEY_ADDRESS,
	WC_SLKEY_NUMPLAYERS,
	WC_SLKEY_MAXPLAYERS,
	WC_SLKEY_SERVERINFO = 22
};

static size_t WebCore_JsonEscape(char *out, size_t outsz, const char *in)
{
	size_t used = 0;
	if (!out || outsz < 3)
		return 0;
	out[used++] = '"';
	if (in)
	{
		while (*in && used + 6 < outsz)
		{
			unsigned char c = (unsigned char)*in++;
			if (c == '"' || c == '\\')
			{
				out[used++] = '\\';
				out[used++] = (char)c;
			}
			else if (c >= 0x20)
				out[used++] = (char)c;
		}
	}
	if (used + 1 >= outsz)
		return 0;
	out[used++] = '"';
	out[used] = '\0';
	return used;
}

static int WebCore_InfoHasLobby(const char *info)
{
	const char *p;
	if (!info || !*info)
		return 0;
	p = info;
	while (*p)
	{
		char key[64], val[64];
		size_t k = 0, v = 0;
		if (*p == '\\')
			p++;
		while (*p && *p != '\\' && k + 1 < sizeof(key))
			key[k++] = *p++;
		key[k] = '\0';
		if (*p == '\\')
			p++;
		while (*p && *p != '\\' && v + 1 < sizeof(val))
			val[v++] = *p++;
		val[v] = '\0';
		if (!strcmp(key, "lobby") && val[0] && strcmp(val, "0"))
			return 1;
	}
	return 0;
}

static size_t WebCore_BuildGetLobby(char *result, size_t resultsz)
{
	char snap[8192];

	if (!cvarfuncs || resultsz < 32)
		return 0;

	snap[0] = '\0';
	cvarfuncs->GetString("lobby_snapshot", snap, sizeof(snap));
	if (snap[0] == '{' && strlen(snap) + 1 < resultsz)
	{
		Q_strlcpy(result, snap, resultsz);
		return strlen(result);
	}

	/* Inactive / missing snapshot */
	Q_strlcpy(result, "{\"active\":false,\"revision\":0,\"players\":[],\"phase\":\"IDLE\"}", resultsz);
	return strlen(result);
}

static size_t WebCore_BuildHostCache(char *result, size_t resultsz)
{
	unsigned int total, i;
	size_t used = 0;
	char adr[128], name[256], map[128], esc[512];
	struct serverinfo_s *sv;

	if (!masterfuncs || resultsz < 4)
		return 0;

	masterfuncs->CheckPollSockets();
	total = masterfuncs->TotalCount();
	result[used++] = '[';
	result[used] = '\0';

	for (i = 0; i < total && used + 64 < resultsz; ++i)
	{
		const char *sname, *smap, *sadr, *sinfo;
		int humans, maxp, is_lobby;
		float ping;

		sv = masterfuncs->InfoForNum((int)i);
		if (!sv)
			continue;
		sname = masterfuncs->ReadKeyString(sv, WC_SLKEY_NAME);
		smap = masterfuncs->ReadKeyString(sv, WC_SLKEY_MAP);
		sadr = masterfuncs->ServerToString(adr, sizeof(adr), sv);
		sinfo = masterfuncs->ReadKeyString(sv, WC_SLKEY_SERVERINFO);
		humans = (int)masterfuncs->ReadKeyFloat(sv, WC_SLKEY_NUMPLAYERS);
		maxp = (int)masterfuncs->ReadKeyFloat(sv, WC_SLKEY_MAXPLAYERS);
		ping = masterfuncs->ReadKeyFloat(sv, WC_SLKEY_PING);
		is_lobby = WebCore_InfoHasLobby(sinfo ? sinfo : "");

		if (!sadr || !*sadr)
			continue;

		Q_strlcpy(name, sname ? sname : "", sizeof(name));
		Q_strlcpy(map, smap ? smap : "", sizeof(map));

		if (used > 1)
			result[used++] = ',';
		result[used] = '\0';
		Q_snprintfz(result + used, resultsz - used, "{\"addr\":");
		used = strlen(result);
		WebCore_JsonEscape(esc, sizeof(esc), sadr);
		Q_snprintfz(result + used, resultsz - used, "%s,\"name\":", esc);
		used = strlen(result);
		WebCore_JsonEscape(esc, sizeof(esc), name);
		Q_snprintfz(result + used, resultsz - used, "%s,\"map\":", esc);
		used = strlen(result);
		WebCore_JsonEscape(esc, sizeof(esc), map);
		Q_snprintfz(result + used, resultsz - used,
			"%s,\"players\":%i,\"max\":%i,\"ping\":%i,\"lobby\":%s}",
			esc, humans, maxp, (int)ping, is_lobby ? "true" : "false");
		used = strlen(result);
	}
	if (used + 1 < resultsz)
	{
		result[used++] = ']';
		result[used] = '\0';
	}
	return used;
}

static size_t WebCore_JSQuery(void *userdata, const char *request,
	char *reply, size_t reply_size)
{
	char result[8192];
	size_t required;
	(void)userdata;

	if (!WebCore_InEngineUpdate() || !request)
		return 0;
	if (!strcmp(request, "getstats"))
	{
		unsigned int stats[256];
		size_t count = clientfuncs->GetStats(0, stats, countof(stats));
		size_t i, used = 0;
		result[used++] = '[';
		for (i = 0; i < count && used + 14 < sizeof(result); ++i)
		{
			char piece[16];
			size_t written;
			Q_snprintfz(piece, sizeof(piece), "%s%u", i ? "," : "", stats[i]);
			written = strlen(piece);
			if (used + written >= sizeof(result))
				break;
			memcpy(result + used, piece, written);
			used += written;
		}
		result[used++] = ']';
		result[used] = '\0';
	}
	else if (!strcmp(request, "gethud"))
	{
		/* Prefer CSQC-published cvars (webcore_hud_*), fall back to GetStats. */
		unsigned int stats[256];
		size_t count;
		unsigned health = 100, health_max = 100, ammo = 0;
		unsigned secs = 0, minutes = 0;
		int speed_i = 0;
		int score_left = 0, score_right = 0;
		char timer[32];
		char tmp[64];
		char p1[64], p2[64];
		char p1esc[128], p2esc[128];
		unsigned ammo_current = 0, ammo_max = 0, charges = 0;

		count = clientfuncs->GetStats(0, stats, countof(stats));
		if (count > 0)
			health = stats[0];
		if (count > 3)
			ammo = stats[3];
		if (count > 17)
		{
			unsigned stime = stats[17];
			if (stime > 86400u)
				secs = stime / 1000u;
			else
				secs = stime;
		}

		if (cvarfuncs && cvarfuncs->GetString("webcore_hud_health", tmp, sizeof(tmp)) && tmp[0])
			health = (unsigned)atoi(tmp);
		if (cvarfuncs && cvarfuncs->GetString("webcore_hud_health_max", tmp, sizeof(tmp)) && tmp[0])
			health_max = (unsigned)atoi(tmp);
		if (cvarfuncs && cvarfuncs->GetString("webcore_hud_ammo", tmp, sizeof(tmp)) && tmp[0])
			ammo = (unsigned)atoi(tmp);
		if (cvarfuncs && cvarfuncs->GetString("webcore_hud_clip", tmp, sizeof(tmp)) && tmp[0])
			ammo_current = (unsigned)atoi(tmp);
		if (cvarfuncs && cvarfuncs->GetString("webcore_hud_ammo_max", tmp, sizeof(tmp)) && tmp[0])
			ammo_max = (unsigned)atoi(tmp);
		if (cvarfuncs && cvarfuncs->GetString("webcore_hud_charges", tmp, sizeof(tmp)) && tmp[0])
			charges = (unsigned)atoi(tmp);
		if (cvarfuncs && cvarfuncs->GetString("webcore_hud_speed", tmp, sizeof(tmp)) && tmp[0])
			speed_i = atoi(tmp);
		else if (clientfuncs->GetPredInfo)
		{
			vec3_t vel = {0};
			float hspeed;
			clientfuncs->GetPredInfo(0, vel);
			hspeed = (float)sqrt((double)vel[0] * vel[0] + (double)vel[1] * vel[1]);
			/* Quake units/sec — same scale CSQC publishes on webcore_hud_speed. */
			speed_i = (int)(hspeed + 0.5f);
		}
		if (speed_i < 0)
			speed_i = 0;
		if (speed_i > 999)
			speed_i = 999;

		if (cvarfuncs && cvarfuncs->GetString("webcore_hud_timer", timer, sizeof(timer)) && timer[0])
			; /* keep CSQC timer */
		else
		{
			minutes = secs / 60u;
			secs = secs % 60u;
			Q_snprintfz(timer, sizeof(timer), "%02u:%02u", minutes, secs);
		}

		p1[0] = p2[0] = '\0';
		if (cvarfuncs && cvarfuncs->GetString("webcore_hud_score_left", tmp, sizeof(tmp)) && tmp[0])
			score_left = atoi(tmp);
		if (cvarfuncs && cvarfuncs->GetString("webcore_hud_score_right", tmp, sizeof(tmp)) && tmp[0])
			score_right = atoi(tmp);
		if (cvarfuncs)
		{
			cvarfuncs->GetString("webcore_hud_player1", p1, sizeof(p1));
			cvarfuncs->GetString("webcore_hud_player2", p2, sizeof(p2));
		}
		if (!WebCore_JsonEscape(p1esc, sizeof(p1esc), p1)
			|| !WebCore_JsonEscape(p2esc, sizeof(p2esc), p2))
			return 0;

		Q_snprintfz(result, sizeof(result),
			"{\"health\":%u,\"healthMax\":%u,\"ammo\":%u,\"ammoCurrent\":%u,\"ammoMax\":%u,\"charges\":%u,"
			"\"timer\":\"%s\",\"speed\":%d,"
			"\"scoreLeft\":%d,\"scoreRight\":%d,"
			"\"exLevel\":\"3\",\"reload\":\"0.0\","
			"\"player1\":%s,\"player2\":%s}",
			health, health_max, ammo, ammo_current, ammo_max, charges, timer, speed_i,
			score_left, score_right, p1esc, p2esc);
	}
	else if (!strcmp(request, "getlobby"))
	{
		if (!WebCore_BuildGetLobby(result, sizeof(result)))
			return 0;
	}
    else if (!strcmp(request, "getlobbychat"))
    {
        if (!cvarfuncs || !cvarfuncs->GetString("lobby_chat_snapshot", result, sizeof(result)) || result[0] != '[')
            Q_strlcpy(result, "[]", sizeof(result));
    }
	else if (!strcmp(request, "getarena"))
	{
		if (!cvarfuncs || !cvarfuncs->GetString("webcore_arena_snapshot", result, sizeof(result))
			|| !WebCore_ValidArenaSnapshot(result, sizeof(result)))
			return 0;
	}
	else if (!strcmp(request, "hostcache_refresh"))
	{
		if (!masterfuncs)
			return 0;
		masterfuncs->QueryServers();
		masterfuncs->CheckPollSockets();
		Q_strlcpy(result, "{\"ok\":true}", sizeof(result));
	}
	else if (!strcmp(request, "gethostcache"))
	{
		if (!WebCore_BuildHostCache(result, sizeof(result)))
			Q_strlcpy(result, "[]", sizeof(result));
	}
	else if (!strncmp(request, "lobby_join:", 11))
	{
		const char *addr = request + 11;
		char line[256];
		size_t i, n;
		if (!cmdfuncs || !addr || !*addr)
			return 0;
		n = strlen(addr);
		if (n >= 200)
			return 0;
		for (i = 0; i < n; ++i)
		{
			char c = addr[i];
			if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
				(c >= '0' && c <= '9') || c == '.' || c == ':' ||
				c == '_' || c == '-' || c == '/' || c == '@'))
				return 0;
		}
		if (reply && reply_size > 2)
		{
			Q_snprintfz(line, sizeof(line), "lobby_join %s\n", addr);
			cmdfuncs->AddText(line, false);
			memcpy(reply, "ok", 3);
		}
		return 2;
	}
	else if (!strncmp(request, "clipboard_copy:", 15))
	{
		const char *text = request + 15;
		char line[96];
		size_t i, n;
		if (!cmdfuncs || !text || !*text)
			return 0;
		n = strlen(text);
		if (n >= 64)
			return 0;
		/* Room codes are deliberately restricted to the same safe alphabet as
		 * the lobby command path before crossing into the engine console. */
		for (i = 0; i < n; ++i)
		{
			char c = text[i];
			if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
				(c >= '0' && c <= '9')))
				return 0;
		}
		if (!reply || reply_size <= 2)
			return 2;
		Q_snprintfz(line, sizeof(line), "webcore_copy %s\n", text);
		cmdfuncs->AddText(line, false);
		memcpy(reply, "ok", 3);
		return 2;
	}
	else if (!strncmp(request, "lobby_action:", 13))
	{
		static const char action_reply[] = "{\"ok\":true}";
		const char *action = request + 13;
		const char *cmd = NULL;
		char line[512];
		if (!cmdfuncs || !action || !*action)
			return 0;
		if (!strcmp(action, "ready"))
			cmd = "lobby_ready 1";
		else if (!strcmp(action, "unready"))
			cmd = "lobby_ready 0";
		else if (!strcmp(action, "start"))
			cmd = "lobby_start";
		else if (!strcmp(action, "cancel"))
			cmd = "lobby_cancel";
		else if (!strcmp(action, "leave") || !strcmp(action, "close"))
			cmd = "lobby_close";
        else if (!strncmp(action, "setruleset:", 11))
        {
            const char *rule = action + 11;
            if (strcmp(rule, "DUEL") && strcmp(rule, "DEATHMATCH") && strcmp(rule, "TEAMDM") && strcmp(rule, "DOMINATION")) return 0;
            Q_snprintfz(line, sizeof(line), "lobby_set ruleset %s\n", rule);
        }
        else if (!strncmp(action, "setlimits:", 10))
        {
            const char *value = action + 10, *colon = strchr(value, ':');
            size_t i, n = strlen(value);
            if (!colon || colon == value || !colon[1] || n > 7 || (colon - value) > 3 || strlen(colon + 1) > 3) return 0;
            for (i = 0; i < n; i++) if (value + i != colon && (value[i] < '0' || value[i] > '9')) return 0;
            if (atoi(value) > 180) return 0;
            Q_snprintfz(line, sizeof(line), "lobby_limits %i %i\n", atoi(value), atoi(colon + 1));
        }
        else if (!strncmp(action, "chat:", 5))
        {
            const char *hex = action + 5;
            size_t i, n = strlen(hex);
            if (!n || (n & 1) || n > 480) return 0;
            for (i = 0; i < n; i++) if (!((hex[i] >= '0' && hex[i] <= '9') || (hex[i] >= 'a' && hex[i] <= 'f') || (hex[i] >= 'A' && hex[i] <= 'F'))) return 0;
            Q_snprintfz(line, sizeof(line), "lobby_chat_hex %s\n", hex);
        }
		else if (!strncmp(action, "setmap:", 7))
		{
			const char *map = action + 7;
			size_t i, n;
			if (!map || !*map)
				return 0;
			n = strlen(map);
			if (n >= 64)
				return 0;
			for (i = 0; i < n; ++i)
			{
				char c = map[i];
				if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
					(c >= '0' && c <= '9') || c == '_' || c == '-' || c == '/'))
					return 0;
			}
			Q_snprintfz(line, sizeof(line), "lobby_set map %s\n", map);
		}
		else
			return 0;

		if (cmd)
			Q_snprintfz(line, sizeof(line), "%s\n", cmd);
		required = strlen(action_reply);
		if (!reply || reply_size <= required)
			return required;
		cmdfuncs->AddText(line, false);
		memcpy(reply, action_reply, required + 1);
		return required;
	}
	else if (!strncmp(request, "arena_action:", 13))
	{
		static const char action_reply[] = "{\"ok\":true}";
		const char *action = request + 13;
		const char *cmd = NULL;
		char line[128];
		if (!cmdfuncs || !action || !*action)
			return 0;
		if (!strcmp(action, "join"))
			cmd = "cmd joinTeam 1";
		else if (!strcmp(action, "spectate"))
		{
			/* Leave queue / opt out: spectate then drop the fullscreen menu
			   so control returns immediately (warmup stays WARMUP). */
			required = strlen(action_reply);
			if (!reply || reply_size <= required)
				return required;
			cmdfuncs->AddText("cmd spectate\n", false);
			cmdfuncs->AddText("webcore_closemenu\n", false);
			memcpy(reply, action_reply, required + 1);
			return required;
		}
		else if (!strcmp(action, "play"))
			cmd = "cmd play";
		else if (!strcmp(action, "choosehero"))
			cmd = "cmd choosehero";
		else if (!strcmp(action, "ready"))
			cmd = "cmd ready";
		else if (!strcmp(action, "unready"))
			cmd = "cmd notready";
		else if (!strcmp(action, "close"))
		{
			/* Closing UI must not mutate arena class or inventory state. */
			required = strlen(action_reply);
			if (!reply || reply_size <= required)
				return required;
			cmdfuncs->AddText("webcore_closemenu\n", false);
			memcpy(reply, action_reply, required + 1);
			return required;
		}
		else if (!strncmp(action, "hero:", 5) && WebCore_ArenaHeroAllowed(action + 5))
			Q_snprintfz(line, sizeof(line), "cmd selecthero %s\n", action + 5);
		else
			return 0;

		if (cmd)
			Q_snprintfz(line, sizeof(line), "%s\n", cmd);
		required = strlen(action_reply);
		if (!reply || reply_size <= required)
			return required;
		cmdfuncs->AddText(line, false);
		memcpy(reply, action_reply, required + 1);
		return required;
	}
	else if (!strncmp(request, "cbuf:", 5))
	{
		const char *cmd = request + 5;
		if (!cmdfuncs || !WebCore_CbufAllowed(cmd))
			return 0;
		if (reply && reply_size > 2)
		{
			char line[72];
			Q_snprintfz(line, sizeof(line), "%s\n", cmd);
			cmdfuncs->AddText(line, false);
			memcpy(reply, "ok", 3);
		}
		return 2;
	}
	else if (!strncmp(request, "localsound:", 11))
	{
		/* Quake menu chrome: menu1=nav, menu2=confirm, menu3=back.
		   Allowlist by stem — FTE S_LoadSound tries .wav/.opus/.ogg. */
		static const char *const allowed[] = {
			"misc/menu1",
			"misc/menu2",
			"misc/menu3",
			NULL
		};
		char stem[64];
		const char *sample = request + 11;
		char *dot;
		size_t i, n;
		if (!audiofuncs || !audiofuncs->LocalSound || !sample || !*sample)
			return 0;
		n = strlen(sample);
		if (n >= sizeof(stem))
			return 0;
		memcpy(stem, sample, n + 1);
		dot = strrchr(stem, '.');
		if (dot && (!strcasecmp(dot, ".wav") || !strcasecmp(dot, ".ogg")
				|| !strcasecmp(dot, ".opus") || !strcasecmp(dot, ".mp3")))
			*dot = 0;
		for (i = 0; allowed[i]; ++i)
		{
			if (!strcmp(stem, allowed[i]))
			{
				if (reply && reply_size > 2)
				{
					/* Extensionless: engine picks first present supported format.
					   Channel 0 = CHAN_AUTO — never override an in-flight play
					   (channel 256 restarts/cuts itself on every nav tick). */
					audiofuncs->LocalSound(stem, 0, 1);
					memcpy(reply, "ok", 3);
				}
				return 2;
			}
		}
		return 0;
	}
	else
		return 0;

	required = strlen(result);
	if (reply && reply_size > required)
		memcpy(reply, result, required + 1);
	return required;
}

static void WebCore_Paint(void *userdata, const void *pixels,
	int width, int height, int stride, const ftewebcore_rect_t *dirty_rects,
	size_t dirty_count)
{
	webcore_browser_t *browser = (webcore_browser_t *)userdata;
	ftewebcore_rect_t dirty;
	size_t required;

	if (!browser || !pixels || width <= 0 || height <= 0 ||
		(size_t)width > SIZE_MAX / 4 / (size_t)height)
		return;
	required = (size_t)width * (size_t)height * 4;

	WEBCORE_MUTEX_LOCK(&browser->mutex);
	if (browser->closing)
	{
		WEBCORE_MUTEX_UNLOCK(&browser->mutex);
		return;
	}
	if (browser->width != width || browser->height != height ||
		browser->pixels_size != required)
	{
		unsigned char *replacement = (unsigned char *)malloc(required);
		if (!replacement)
		{
			WEBCORE_MUTEX_UNLOCK(&browser->mutex);
			return;
		}
		free(browser->pixels);
		browser->pixels = replacement;
		browser->pixels_size = required;
		browser->width = width;
		browser->height = height;
		dirty.x = dirty.y = 0;
		dirty.width = width;
		dirty.height = height;
	}
	else if (!WebCore_CoalesceDirtyRects(width, height, dirty_rects,
		dirty_count, &dirty))
	{
		WEBCORE_MUTEX_UNLOCK(&browser->mutex);
		return;
	}
	if (WebCore_CopyDirtyBGRA(browser->pixels, width, height, pixels, stride,
		&dirty))
	{
		static int logged_paint;
		if (!logged_paint)
		{
			const unsigned char *p = (const unsigned char *)pixels;
			Con_Printf("WebCore: paint %dx%d first_px=#%02x%02x%02x%02x\n",
				width, height, p[2], p[1], p[0], p[3]);
			logged_paint = 1;
		}
		browser->updated = 1;
	}
	WEBCORE_MUTEX_UNLOCK(&browser->mutex);
}

static int WebCore_EnsureHost(void)
{
	ftewebcore_get_api_fn get_api = NULL;
	dllfunction_t functions[] = {
		{(void **)&get_api, "ftewebcore_get_api"},
		{NULL}
	};

	if (webcore_host_initialized)
		return 1;
	/* Same search pattern as CEF: bare name, then ./ beside the engine binary. */
	host_dll = plugfuncs->LoadDLL("ftewebcore", functions);
	if (!host_dll)
		host_dll = plugfuncs->LoadDLL("./ftewebcore", functions);
	if (!host_dll)
	{
		Con_Printf("WebCore plugin: unable to load ftewebcore host DLL "
			"(need ftewebcore.dll + Cairo runtime: cairo-2, pixman-1-0, "
			"freetype, fontconfig-1, libpng16, libexpat, z, bz2, brotli*).\n");
		return 0;
	}
	/* Resolve only the versioned entry point; the host owns its internals. */
	memset(&host, 0, sizeof(host));
	host.struct_size = sizeof(host);
	if (!get_api(FTEWEBCORE_ABI_VERSION, &host) ||
		host.abi_version != FTEWEBCORE_ABI_VERSION ||
		!host.initialize || !host.shutdown || !host.update ||
		!host.create_view || !host.destroy_view || !host.navigate ||
		!host.resize || !host.mouse_move || !host.mouse_button ||
		!host.mouse_wheel || !host.key)
	{
		Con_Printf("WebCore plugin: incompatible ftewebcore host ABI.\n");
		memset(&host, 0, sizeof(host));
		plugfuncs->CloseDLL(host_dll);
		host_dll = NULL;
		return 0;
	}
	if (!host.initialize())
	{
		Con_Printf("WebCore plugin: ftewebcore host initialization failed.\n");
		memset(&host, 0, sizeof(host));
		plugfuncs->CloseDLL(host_dll);
		host_dll = NULL;
		return 0;
	}
	webcore_host_initialized = 1;
	return 1;
}

static void *WebCore_Create(const char *name)
{
	webcore_browser_t *browser;
	const char *url;

	if (!strcmp(name, "webcore"))
		url = "fte://data/index.html";
	else if (!strncmp(name, "webcore:", 8))
		url = name + 8;
	else
		return NULL;
	if (!WebCore_ValidateLocalURL(url, NULL) || !WebCore_EnsureHost())
		return NULL;

	browser = (webcore_browser_t *)calloc(1, sizeof(*browser));
	if (!browser)
		return NULL;
	WEBCORE_MUTEX_INIT(&browser->mutex);
	browser->desired_width = 640;
	browser->desired_height = 480;
	Q_strlcpy(browser->url, url, sizeof(browser->url));
	browser->callbacks.struct_size = sizeof(browser->callbacks);
	browser->callbacks.userdata = browser;
	browser->callbacks.resource_open = WebCore_ResourceOpen;
	browser->callbacks.resource_close = WebCore_ResourceClose;
	browser->callbacks.js_query = WebCore_JSQuery;
	browser->callbacks.paint = WebCore_Paint;
	browser->view = host.create_view(url, browser->desired_width,
		browser->desired_height, &browser->callbacks);
	if (!browser->view)
	{
		WEBCORE_MUTEX_DESTROY(&browser->mutex);
		free(browser);
		return NULL;
	}
	browser->next = browsers;
	browsers = browser;
	return browser;
}

static qboolean VARGS WebCore_DisplayFrame(void *context, qboolean nosound,
	qboolean forcevideo, double mediatime,
	void (QDECL *uploadtexture)(void *, uploadfmt_t, int, int, void *, void *),
	void *upload_context)
{
	webcore_browser_t *browser = (webcore_browser_t *)context;
	(void)nosound;
	(void)mediatime;
	WEBCORE_MUTEX_LOCK(&browser->mutex);
	if ((browser->updated || forcevideo) && browser->pixels)
	{
		static int logged_upload;
		if (!logged_upload)
		{
			Con_Printf("WebCore: uploading %dx%d frame\n",
				browser->width, browser->height);
			logged_upload = 1;
		}
		uploadtexture(upload_context, TF_BGRA32, browser->width,
			browser->height, browser->pixels, NULL);
		browser->updated = 0;
	}
	else if (forcevideo && !browser->pixels)
	{
		static int logged_empty;
		if (!logged_empty)
		{
			Con_Printf("WebCore: decodeframe with no pixels yet\n");
			logged_empty = 1;
		}
		/* First paint hasn't happened yet — upload transparent black so the
		 * cinematic texture isn't uninitialized garbage/white.  The real
		 * paint arrives within 1-2 frames and replaces this. */
		{
			int tw = browser->desired_width;
			int th = browser->desired_height;
			size_t tsz = (size_t)tw * (size_t)th * 4;
			void *px = malloc(tsz);
			if (px)
			{
				memset(px, 0, tsz);
				uploadtexture(upload_context, TF_BGRA32, tw, th, px, NULL);
				free(px);
			}
		}
	}
	WEBCORE_MUTEX_UNLOCK(&browser->mutex);
	return qtrue;
}

static void VARGS WebCore_Destroy(void *context)
{
	webcore_browser_t *browser = (webcore_browser_t *)context;
	webcore_browser_t **link;
	webcore_resource_t *resource;
	ftewebcore_view_t *view;

	if (!browser)
		return;
	WEBCORE_MUTEX_LOCK(&browser->mutex);
	if (!WebCore_BeginClose(&browser->closing))
	{
		WEBCORE_MUTEX_UNLOCK(&browser->mutex);
		return;
	}
	browser->closing = 1;
	view = browser->view;
	browser->view = NULL;
	WEBCORE_MUTEX_UNLOCK(&browser->mutex);
	if (view && host.destroy_view)
		host.destroy_view(view);
	for (link = &browsers; *link && *link != browser; link = &(*link)->next)
		;
	if (*link)
		*link = browser->next;
	free(browser->pixels);
	browser->pixels = NULL;
	browser->pixels_size = 0;
	while ((resource = browser->resources) != NULL)
	{
		browser->resources = resource->next;
		resource->owner = NULL;
		WebCore_FreeResource(resource);
	}
	WEBCORE_MUTEX_DESTROY(&browser->mutex);
	free(browser);
}

static void VARGS WebCore_CursorMove(void *context, float x, float y)
{
	webcore_browser_t *browser = (webcore_browser_t *)context;
	browser->mouse_x = (int)(x * browser->desired_width);
	browser->mouse_y = (int)(y * browser->desired_height);
	if (browser->view)
		host.mouse_move(browser->view, browser->mouse_x, browser->mouse_y);
}

static void VARGS WebCore_Key(void *context, int code, int unicode, int event)
{
	webcore_browser_t *browser = (webcore_browser_t *)context;
	if (!browser->view)
		return;
	if (code >= K_MOUSE1 && code <= K_MOUSE3)
		host.mouse_button(browser->view, code - K_MOUSE1, !event);
	else if (code == K_MWHEELUP || code == K_MWHEELDOWN)
	{
		if (!event)
			host.mouse_wheel(browser->view, 0,
				code == K_MWHEELUP ? 120 : -120);
	}
	else
		host.key(browser->view, code, (uint32_t)unicode, !event);
}

/* Cairo CPU paints scale with pixel count. Full native res (1440p/4K)
 * cannot keep CSS animations near 60fps; clamp and let the cinematic
 * shader upscale. Keep aspect so letterboxing stays correct. */
#ifndef WEBCORE_MAX_PAINT_W
#define WEBCORE_MAX_PAINT_W 1280
#endif
#ifndef WEBCORE_MAX_PAINT_H
#define WEBCORE_MAX_PAINT_H 720
#endif

static void WebCore_ClampPaintSize(int *width, int *height)
{
	int w, h;
	float sx, sy, s;

	if (!width || !height)
		return;
	w = *width;
	h = *height;
	if (w <= WEBCORE_MAX_PAINT_W && h <= WEBCORE_MAX_PAINT_H)
		return;
	sx = (float)WEBCORE_MAX_PAINT_W / (float)w;
	sy = (float)WEBCORE_MAX_PAINT_H / (float)h;
	s = (sx < sy) ? sx : sy;
	w = (int)((float)w * s + 0.5f);
	h = (int)((float)h * s + 0.5f);
	if (w < 1)
		w = 1;
	if (h < 1)
		h = 1;
	*width = w;
	*height = h;
}

static qboolean VARGS WebCore_SetSize(void *context, int width, int height)
{
	webcore_browser_t *browser = (webcore_browser_t *)context;
	if (width <= 0 || height <= 0)
		return qfalse;
	WebCore_ClampPaintSize(&width, &height);
	if (browser->desired_width != width || browser->desired_height != height)
	{
		browser->desired_width = width;
		browser->desired_height = height;
		if (browser->view)
			host.resize(browser->view, width, height);
	}
	return qtrue;
}

static void VARGS WebCore_GetSize(void *context, int *width, int *height)
{
	webcore_browser_t *browser = (webcore_browser_t *)context;
	*width = browser->desired_width;
	*height = browser->desired_height;
}

static void VARGS WebCore_ChangeStream(void *context, const char *stream)
{
	webcore_browser_t *browser = (webcore_browser_t *)context;
	if (!browser->view || !stream)
		return;
	if (!strcmp(stream, "cmd:focus") && host.set_focus)
		host.set_focus(browser->view, 1);
	else if (!strcmp(stream, "cmd:unfocus") && host.set_focus)
		host.set_focus(browser->view, 0);
	else if (!strcmp(stream, "cmd:transparent") && host.execute_javascript)
		/* Host sentinel — not executed as page JS. */
		host.execute_javascript(browser->view, "__fte_transparent:1");
	else if (!strcmp(stream, "cmd:opaque") && host.execute_javascript)
		host.execute_javascript(browser->view, "__fte_transparent:0");
	else if (!strncmp(stream, "javascript:", 11) &&
		host.execute_javascript)
		host.execute_javascript(browser->view, stream + 11);
	else if (WebCore_ValidateLocalURL(stream, NULL) &&
		host.navigate(browser->view, stream))
		Q_strlcpy(browser->url, stream, sizeof(browser->url));
}

static qboolean VARGS WebCore_GetProperty(void *context, const char *field,
	char *out, size_t *outsize)
{
	webcore_browser_t *browser = (webcore_browser_t *)context;
	const char *fallback = NULL;
	size_t required;

	if (!field || !outsize)
		return qfalse;
	if (!strcmp(field, "url"))
		fallback = browser->url;
	required = host.get_property && browser->view
		? host.get_property(browser->view, field, out, out ? *outsize : 0)
		: 0;
	if (!required && fallback)
	{
		required = strlen(fallback);
		if (out && *outsize >= required)
			memcpy(out, fallback, required);
	}
	if (!required || (out && *outsize < required))
		return qfalse;
	*outsize = required;
	return qtrue;
}

static void WebCore_PushHudState(void)
{
	webcore_browser_t *browser;
	char json[2048];
	char script[2304];
	size_t json_size;

	if (!host.execute_javascript)
		return;
	json_size = WebCore_JSQuery(NULL, "gethud", json, sizeof(json));
	if (!json_size || json_size >= sizeof(json))
		return;
	json[json_size] = 0;
	Q_snprintfz(script, sizeof(script),
		"window.WebCoreHud_Receive&&window.WebCoreHud_Receive(%s);", json);
	for (browser = browsers; browser; browser = browser->next)
	{
		if (browser->view && strstr(browser->url, "/data/web/hud/"))
			host.execute_javascript(browser->view, script);
	}
}

static qintptr_t WebCore_Tick(qintptr_t *args)
{
	(void)args;
	if (webcore_host_initialized && !webcore_update_active &&
		WEBCORE_THREAD_IS_CURRENT(&engine_thread))
	{
		webcore_update_active = 1;
		WebCore_PushHudState();
		host.update();
		webcore_update_active = 0;
	}
	return 0;
}

static qintptr_t WebCore_Shutdown(qintptr_t *args)
{
	(void)args;
	while (browsers)
		WebCore_Destroy(browsers);
	if (webcore_host_initialized)
	{
		host.shutdown();
		webcore_host_initialized = 0;
	}
	memset(&host, 0, sizeof(host));
	if (host_dll)
	{
		plugfuncs->CloseDLL(host_dll);
		host_dll = NULL;
	}
	webcore_update_active = 0;
	return 0;
}

static qboolean QDECL WebCore_MayUnload(void)
{
	return browsers == NULL;
}

static void WebCore_ExecuteCommand(void)
{
	static int sequence;
	char f[128];
	char videomap[8192];
	char arg[8000];

	if (!confuncs)
	{
		Con_Printf("webcore: SubConsole interface unavailable\n");
		return;
	}
	if (!WebCore_EnsureHost())
	{
		Con_Printf("webcore: host unavailable\n");
		return;
	}

	Q_snprintf(f, sizeof(f), "webcore:%i", ++sequence);
	cmdfuncs->Argv(1, arg, sizeof(arg));
	if (!arg[0])
		Q_strlcpy(arg, "fte://data/web/webcore-test/font-smoke.html", sizeof(arg));
	if (!WebCore_ValidateLocalURL(arg, NULL))
	{
		Con_Printf("webcore: rejected non-local URL (fte://data/ only)\n");
		return;
	}

	Q_snprintf(videomap, sizeof(videomap), "webcore:%s", arg);
	confuncs->SetConsoleString(f, "title", arg);
	confuncs->SetConsoleFloat(f, "iswindow", true);
	confuncs->SetConsoleFloat(f, "forceutf8", true);
	confuncs->SetConsoleFloat(f, "wnd_w", 640 + 16);
	confuncs->SetConsoleFloat(f, "wnd_h", 480 + 16 + 8);
	confuncs->SetConsoleString(f, "backvideomap", videomap);
	confuncs->SetConsoleFloat(f, "linebuffered", 2);
	confuncs->SetActive(f);
}

qboolean Plug_Init(void)
{
	static media_decoder_funcs_t decoder;

	WEBCORE_THREAD_CAPTURE(&engine_thread);
	fsfuncs = (plugfsfuncs_t *)plugfuncs->GetEngineInterface(
		plugfsfuncs_name, sizeof(*fsfuncs));
	clientfuncs = (plugclientfuncs_t *)plugfuncs->GetEngineInterface(
		plugclientfuncs_name, sizeof(*clientfuncs));
	audiofuncs = (plugaudiofuncs_t *)plugfuncs->GetEngineInterface(
		plugaudiofuncs_name, sizeof(*audiofuncs));
	confuncs = (plugsubconsolefuncs_t *)plugfuncs->GetEngineInterface(
		plugsubconsolefuncs_name, sizeof(*confuncs));
	cvarfuncs = (plugcvarfuncs_t *)plugfuncs->GetEngineInterface(
		plugcvarfuncs_name, sizeof(*cvarfuncs));
	masterfuncs = (plugmasterfuncs_t *)plugfuncs->GetEngineInterface(
		plugmasterfuncs_name, sizeof(*masterfuncs));
	if (!fsfuncs || !clientfuncs ||
		!plugfuncs->ExportFunction("Tick", WebCore_Tick) ||
		!plugfuncs->ExportFunction("Shutdown", WebCore_Shutdown) ||
		!plugfuncs->ExportFunction("MayUnload", WebCore_MayUnload) ||
		!WebCore_EnsureHost())
	{
		Con_Printf("WebCore plugin failed: required host or engine interface missing.\n");
		return qfalse;
	}
	if (!audiofuncs)
		Con_Printf("WebCore: Audio interface missing (localsound disabled)\n");
	if (!cvarfuncs)
		Con_Printf("WebCore: Cvar interface missing (getlobby disabled)\n");
	if (!masterfuncs)
		Con_Printf("WebCore: Master interface missing (hostcache disabled)\n");

	memset(&decoder, 0, sizeof(decoder));
	decoder.structsize = sizeof(decoder);
	decoder.drivername = "webcore";
	decoder.createdecoder = WebCore_Create;
	decoder.decodeframe = WebCore_DisplayFrame;
	decoder.shutdown = WebCore_Destroy;
	decoder.cursormove = WebCore_CursorMove;
	decoder.key = WebCore_Key;
	decoder.setsize = WebCore_SetSize;
	decoder.getsize = WebCore_GetSize;
	decoder.changestream = WebCore_ChangeStream;
	decoder.getproperty = WebCore_GetProperty;
	if (!plugfuncs->ExportInterface("Media_VideoDecoder", &decoder,
		sizeof(decoder)))
	{
		WebCore_Shutdown(NULL);
		Con_Printf("WebCore plugin failed: Media_VideoDecoder unavailable.\n");
		return qfalse;
	}
	if (confuncs)
		cmdfuncs->AddCommand("webcore", WebCore_ExecuteCommand,
			"Open a local WebCore page in a subconsole (debug).");
	return qtrue;
}
