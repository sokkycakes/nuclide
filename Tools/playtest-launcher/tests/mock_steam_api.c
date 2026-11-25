/* A stand-in libsteam_api with just enough of ISteamInput to test Bulwark's
 * Steam Input code without Steam (which can't sign in on a build machine).
 * Test only: it is not Steam and never talks to Valve. ISC licence.
 *
 * It behaves the way Valve documents ISteamInput:
 *  - nothing has a handle until an action manifest is loaded
 *    (SetInputActionManifestFilePath), and then only the action sets and
 *    actions that manifest declares do;
 *  - an action reports bActive only while its set (or a layer holding it)
 *    is active on that controller;
 *  - SteamAPI_Init needs a running Steam and an app id (SteamAppId, or
 *    steam_appid.txt in the working directory).
 *
 * Driven by MOCK_STEAM_SCRIPT, a file the test appends lines to:
 *   connect <handle> <ESteamInputType>    disconnect <handle>
 *   press <handle> <action>               release <handle> <action>
 *   analog <handle> <action> <x> <y>      origins <action> <origin>...
 *   mode <action> <EInputSourceMode>      wait <frames>
 *   sleep <milliseconds>
 * and it writes what the program did to MOCK_STEAM_LOG (init, manifest,
 * activate, layer, vibrate, led, binding_panel). MOCK_STEAM_RUNNING=0
 * pretends Steam isn't running.
 *
 *   cc -shared -fPIC -o libsteam_api.so tests/steaminput/mock_steam_api.c */
#define _POSIX_C_SOURCE 200809L
#include <ctype.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

#define EXPORT __attribute__((visibility("default")))
#define MAXN 256

typedef uint64_t h64;

#pragma pack(push, 1)
typedef struct {
	bool state, active;
} digital_t;
typedef struct {
	int mode;
	float x, y;
	bool active;
} analog_t;
#pragma pack(pop)

static struct {
	char name[64];
	int set;  /* index into sets */
	bool analog;
	int origins[8], norigins;
} actions[MAXN];
static int nactions;
static struct {
	char name[64];
	bool layer;
} sets[32];
static int nsets;

static struct {
	h64 h;
	int type;
	int set;             /* active set, -1 none */
	bool layers[32];
	bool down[MAXN];
	float ax[MAXN], ay[MAXN];
} ctrls[16];
static int nctrls;

static bool started, input_started;
static long script_pos;
static int script_wait; /* RunFrames left before the script goes on */
static double script_until; /* or the time it goes on at */

static double now_ms(void)
{
	struct timespec t;
	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec * 1000.0 + t.tv_nsec / 1e6;
}
static int analog_mode[MAXN];
static FILE *logf;

static void logline(const char *fmt, ...)
{
	va_list ap;
	if (!logf) {
		const char *p = getenv("MOCK_STEAM_LOG");
		if (!p || !(logf = fopen(p, "a")))
			return;
	}
	va_start(ap, fmt);
	vfprintf(logf, fmt, ap);
	va_end(ap);
	fputc('\n', logf);
	fflush(logf);
}

/* --- a small VDF reader: "key" "value" and "key" { ... } -------------------- */

static const char *vp;

static bool vtok(char *out, size_t size)
{
	size_t n = 0;
	for (;;) {
		while (*vp && isspace((unsigned char)*vp))
			vp++;
		if (vp[0] == '/' && vp[1] == '/') {
			while (*vp && *vp != '\n')
				vp++;
			continue;
		}
		break;
	}
	if (!*vp)
		return false;
	if (*vp == '{' || *vp == '}') {
		out[0] = *vp++;
		out[1] = 0;
		return true;
	}
	if (*vp == '"') {
		vp++;
		while (*vp && *vp != '"') {
			if (*vp == '\\' && vp[1])
				vp++;
			if (n + 1 < size)
				out[n++] = *vp;
			vp++;
		}
		if (*vp)
			vp++;
	} else {
		while (*vp && !isspace((unsigned char)*vp) && *vp != '{' && *vp != '}')
			if (n + 1 < size)
				out[n++] = *vp++;
			else
				vp++;
	}
	out[n] = 0;
	return true;
}

static void vskip(void)
{
	char t[256];
	int depth = 1;
	while (depth && vtok(t, sizeof(t)))
		depth += !strcmp(t, "{") ? 1 : !strcmp(t, "}") ? -1 : 0;
}

static void add_action(int set, const char *name, bool analog)
{
	if (nactions >= MAXN)
		return;
	snprintf(actions[nactions].name, sizeof(actions[0].name), "%.63s", name);
	actions[nactions].set = set;
	actions[nactions].analog = analog;
	nactions++;
}

/* "actions" { "<set>" { "title" .. "StickPadGyro" { "<name>" {..} }
 * "AnalogTrigger" { "<name>" ".." } "Button" { "<name>" ".." } } } and the
 * same under "action_layers", with "parent_set_name" */
static void parse_sets(bool layer)
{
	char t[256], k[256];
	while (vtok(k, sizeof(k)) && strcmp(k, "}")) {
		int set = nsets;
		if (!vtok(t, sizeof(t)) || strcmp(t, "{"))
			return;
		if (nsets < 32) {
			snprintf(sets[nsets].name, sizeof(sets[0].name), "%.63s", k);
			sets[nsets++].layer = layer;
		}
		while (vtok(k, sizeof(k)) && strcmp(k, "}")) {
			bool analog = !strcmp(k, "StickPadGyro") || !strcmp(k, "AnalogTrigger");
			bool button = !strcmp(k, "Button");
			if (!vtok(t, sizeof(t)))
				return;
			if (strcmp(t, "{"))
				continue; /* "title" "..." */
			if (!analog && !button) {
				vskip();
				continue;
			}
			while (vtok(k, sizeof(k)) && strcmp(k, "}")) {
				add_action(set, k, analog);
				if (!vtok(t, sizeof(t)))
					return;
				if (!strcmp(t, "{"))
					vskip();
			}
		}
	}
}

static bool load_manifest(const char *path)
{
	char t[256], k[256];
	char *text;
	long size;
	FILE *f = fopen(path, "rb");
	if (!f)
		return false;
	fseek(f, 0, SEEK_END);
	size = ftell(f);
	fseek(f, 0, SEEK_SET);
	text = calloc(1, size + 1);
	if (fread(text, 1, size, f) != (size_t)size)
		size = 0;
	fclose(f);
	vp = text;
	nsets = nactions = 0;
	/* "Action Manifest" { "configurations" {..} "actions" {..} "action_layers" {..} "localization" {..} } */
	if (!vtok(k, sizeof(k)) || !vtok(t, sizeof(t)) || strcmp(t, "{")) {
		free(text);
		return false;
	}
	while (vtok(k, sizeof(k)) && strcmp(k, "}")) {
		if (!vtok(t, sizeof(t)))
			break;
		if (strcmp(t, "{"))
			continue;
		if (!strcmp(k, "actions"))
			parse_sets(false);
		else if (!strcmp(k, "action_layers"))
			parse_sets(true);
		else
			vskip();
	}
	free(text);
	logline("manifest %s sets=%d actions=%d", path, nsets, nactions);
	for (int i = 0; i < nsets; i++) {
		char line[2048] = "";
		for (int a = 0; a < nactions; a++)
			if (actions[a].set == i && strlen(line) + strlen(actions[a].name) + 4 < sizeof(line))
				strcat(strcat(line, " "), actions[a].name), strcat(line, actions[a].analog ? "~" : "");
		logline("set %s%s:%s", sets[i].name, sets[i].layer ? " (layer)" : "", line);
	}
	return nsets > 0;
}

/* --- the script -------------------------------------------------------------- */

static int find_ctrl(h64 h)
{
	for (int i = 0; i < nctrls; i++)
		if (ctrls[i].h == h)
			return i;
	return -1;
}

static int find_action(const char *name)
{
	for (int i = 0; i < nactions; i++)
		if (!strcmp(actions[i].name, name))
			return i;
	return -1;
}

static void run_script(void)
{
	const char *p = getenv("MOCK_STEAM_SCRIPT");
	char line[512], a[64], b[64];
	unsigned long long h;
	float x, y;
	FILE *f;
	if (script_wait > 0 && --script_wait > 0)
		return;
	if (script_until > 0 && now_ms() < script_until)
		return;
	script_until = 0;
	if (!p || !(f = fopen(p, "r")))
		return;
	fseek(f, script_pos, SEEK_SET);
	while (fgets(line, sizeof(line), f)) {
		int c, t;
		if (!strchr(line, '\n'))
			break; /* half written: read it next frame */
		script_pos = ftell(f);
		if (sscanf(line, "wait %d", &t) == 1) {
			script_wait = t;
			break;
		} else if (sscanf(line, "sleep %d", &t) == 1) {
			script_until = now_ms() + t;
			break;
		} else if (sscanf(line, "mode %63s %d", a, &c) == 2 && (t = find_action(a)) >= 0) {
			analog_mode[t] = c;
		} else if (sscanf(line, "connect %llu %d", &h, &t) == 2 && find_ctrl(h) < 0 && nctrls < 16) {
			memset(&ctrls[nctrls], 0, sizeof(ctrls[0]));
			ctrls[nctrls].h = h, ctrls[nctrls].type = t, ctrls[nctrls].set = -1;
			nctrls++;
		} else if (sscanf(line, "disconnect %llu", &h) == 1 && (c = find_ctrl(h)) >= 0) {
			ctrls[c] = ctrls[--nctrls];
		} else if (sscanf(line, "press %llu %63s", &h, a) == 2 && (c = find_ctrl(h)) >= 0 && (t = find_action(a)) >= 0) {
			ctrls[c].down[t] = true;
		} else if (sscanf(line, "release %llu %63s", &h, a) == 2 && (c = find_ctrl(h)) >= 0 && (t = find_action(a)) >= 0) {
			ctrls[c].down[t] = false;
		} else if (sscanf(line, "analog %llu %63s %f %f", &h, a, &x, &y) == 4 && (c = find_ctrl(h)) >= 0 &&
		           (t = find_action(a)) >= 0) {
			ctrls[c].ax[t] = x, ctrls[c].ay[t] = y;
		} else if (sscanf(line, "origins %63s %63[0-9 ]", a, b) >= 1 && (t = find_action(a)) >= 0) {
			char *s = line + strlen("origins ") + strlen(a);
			actions[t].norigins = 0;
			while (*s && actions[t].norigins < 8) {
				char *e;
				long o = strtol(s, &e, 10);
				if (e == s)
					break;
				actions[t].origins[actions[t].norigins++] = (int)o;
				s = e;
			}
		}
	}
	fclose(f);
}

/* --- the API ---------------------------------------------------------------- */

EXPORT bool SteamAPI_IsSteamRunning(void)
{
	const char *r = getenv("MOCK_STEAM_RUNNING");
	return !r || strcmp(r, "0");
}

EXPORT int SteamAPI_InitFlat(char *err)
{
	const char *app = getenv("SteamAppId");
	FILE *f;
	if (!SteamAPI_IsSteamRunning()) {
		snprintf(err, 1024, "mock: Steam isn't running");
		return 2;
	}
	if ((!app || !*app || !strcmp(app, "0")) && !(f = fopen("steam_appid.txt", "r"))) {
		snprintf(err, 1024, "mock: no app id (SteamAppId or steam_appid.txt)");
		return 1;
	}
	started = true;
	logline("init appid=%s gameid=%s", app ? app : "(steam_appid.txt)", getenv("SteamGameId") ? getenv("SteamGameId") : "");
	return 0;
}

EXPORT void SteamAPI_Shutdown(void)
{
	if (started)
		logline("shutdown");
	started = input_started = false;
}

EXPORT void SteamAPI_RunCallbacks(void) {}

static int iface_token;
EXPORT void *SteamAPI_SteamInput_v006(void) { return started ? &iface_token : NULL; }

EXPORT bool SteamAPI_ISteamInput_Init(void *self, bool explicit_frame)
{
	input_started = started;
	logline("input_init explicit=%d", explicit_frame);
	return input_started;
}

EXPORT bool SteamAPI_ISteamInput_Shutdown(void *self)
{
	logline("input_shutdown");
	input_started = false;
	return true;
}

EXPORT bool SteamAPI_ISteamInput_SetInputActionManifestFilePath(void *self, const char *path)
{
	if (path[0] != '/' && !(isalpha((unsigned char)path[0]) && path[1] == ':')) {
		logline("manifest_not_absolute %s", path);
		return false;
	}
	return load_manifest(path);
}

EXPORT void SteamAPI_ISteamInput_RunFrame(void *self, bool reserved) { run_script(); }

EXPORT int SteamAPI_ISteamInput_GetConnectedControllers(void *self, h64 *out)
{
	for (int i = 0; i < nctrls; i++)
		out[i] = ctrls[i].h;
	return input_started ? nctrls : 0;
}

/* handles: set i is i+1, action i is i+1, so 0 stays "none" */
EXPORT h64 SteamAPI_ISteamInput_GetActionSetHandle(void *self, const char *name)
{
	for (int i = 0; i < nsets; i++)
		if (!strcmp(sets[i].name, name))
			return (h64)i + 1;
	return 0;
}

static const char *set_name(h64 s) { return s >= 1 && s <= (h64)nsets ? sets[s - 1].name : "?"; }

EXPORT void SteamAPI_ISteamInput_ActivateActionSet(void *self, h64 ctrl, h64 set)
{
	for (int i = 0; i < nctrls; i++)
		if ((ctrl == UINT64_MAX || ctrls[i].h == ctrl) && ctrls[i].set != (int)set - 1) {
			ctrls[i].set = (int)set - 1;
			logline("activate %llu %s", (unsigned long long)ctrls[i].h, set_name(set));
		}
}

EXPORT void SteamAPI_ISteamInput_ActivateActionSetLayer(void *self, h64 ctrl, h64 layer)
{
	for (int i = 0; i < nctrls; i++)
		if ((ctrl == UINT64_MAX || ctrls[i].h == ctrl) && layer >= 1 && layer <= 32 && !ctrls[i].layers[layer - 1]) {
			ctrls[i].layers[layer - 1] = true;
			logline("layer_on %llu %s", (unsigned long long)ctrls[i].h, set_name(layer));
		}
}

EXPORT void SteamAPI_ISteamInput_DeactivateActionSetLayer(void *self, h64 ctrl, h64 layer)
{
	for (int i = 0; i < nctrls; i++)
		if ((ctrl == UINT64_MAX || ctrls[i].h == ctrl) && layer >= 1 && layer <= 32 && ctrls[i].layers[layer - 1]) {
			ctrls[i].layers[layer - 1] = false;
			logline("layer_off %llu %s", (unsigned long long)ctrls[i].h, set_name(layer));
		}
}

static h64 action_handle(const char *name, bool analog)
{
	for (int i = 0; i < nactions; i++)
		if (!strcmp(actions[i].name, name) && actions[i].analog == analog)
			return (h64)i + 1;
	return 0;
}

EXPORT h64 SteamAPI_ISteamInput_GetDigitalActionHandle(void *self, const char *name) { return action_handle(name, false); }
EXPORT h64 SteamAPI_ISteamInput_GetAnalogActionHandle(void *self, const char *name) { return action_handle(name, true); }

static bool action_live(int c, int a)
{
	int s = actions[a].set;
	return s == ctrls[c].set || (s >= 0 && s < 32 && ctrls[c].layers[s]);
}

EXPORT digital_t SteamAPI_ISteamInput_GetDigitalActionData(void *self, h64 ctrl, h64 action)
{
	digital_t d = {0};
	int c = find_ctrl(ctrl), a = (int)action - 1;
	if (c < 0 || a < 0 || a >= nactions || actions[a].analog)
		return d;
	d.active = action_live(c, a);
	d.state = d.active && ctrls[c].down[a];
	return d;
}

EXPORT analog_t SteamAPI_ISteamInput_GetAnalogActionData(void *self, h64 ctrl, h64 action)
{
	analog_t d = {0};
	int c = find_ctrl(ctrl), a = (int)action - 1;
	if (c < 0 || a < 0 || a >= nactions || !actions[a].analog)
		return d;
	d.active = action_live(c, a);
	d.mode = analog_mode[a] ? analog_mode[a] : 6; /* k_EInputSourceMode_JoystickMove */
	if (d.active)
		d.x = ctrls[c].ax[a], d.y = ctrls[c].ay[a];
	return d;
}

static int origins(h64 set, h64 action, int *out)
{
	int a = (int)action - 1;
	if (a < 0 || a >= nactions || (int)set - 1 != actions[a].set)
		return 0;
	memcpy(out, actions[a].origins, actions[a].norigins * sizeof(int));
	return actions[a].norigins;
}

EXPORT int SteamAPI_ISteamInput_GetDigitalActionOrigins(void *self, h64 ctrl, h64 set, h64 action, int *out)
{
	return origins(set, action, out);
}

EXPORT int SteamAPI_ISteamInput_GetAnalogActionOrigins(void *self, h64 ctrl, h64 set, h64 action, int *out)
{
	return origins(set, action, out);
}

EXPORT const char *SteamAPI_ISteamInput_GetGlyphPNGForActionOrigin(void *self, int origin, int size, unsigned flags) { return NULL; }
EXPORT const char *SteamAPI_ISteamInput_GetStringForActionOrigin(void *self, int origin) { return "mock origin"; }

EXPORT int SteamAPI_ISteamInput_GetInputTypeForHandle(void *self, h64 ctrl)
{
	int c = find_ctrl(ctrl);
	return c >= 0 ? ctrls[c].type : 0;
}

EXPORT int SteamAPI_ISteamInput_GetGamepadIndexForController(void *self, h64 ctrl) { return find_ctrl(ctrl); }

EXPORT void SteamAPI_ISteamInput_TriggerVibration(void *self, h64 ctrl, unsigned short l, unsigned short r)
{
	logline("vibrate %llu %u %u", (unsigned long long)ctrl, l, r);
}

EXPORT void SteamAPI_ISteamInput_SetLEDColor(void *self, h64 ctrl, unsigned char r, unsigned char g, unsigned char b,
                                             unsigned flags)
{
	logline("led %llu %u %u %u", (unsigned long long)ctrl, r, g, b);
}

EXPORT bool SteamAPI_ISteamInput_ShowBindingPanel(void *self, h64 ctrl)
{
	logline("binding_panel %llu", (unsigned long long)ctrl);
	return true;
}
