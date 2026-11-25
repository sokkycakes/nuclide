/* Bulwark engine - Steam Input, loaded at run time. ISC licence, see LICENSE.
 * See steaminput.h and docs/spec/steam-input.md. Self-contained: the
 * playtest launcher builds this file unchanged. */
#if !defined(_WIN32) && !defined(_POSIX_C_SOURCE) && !defined(_GNU_SOURCE)
#define _POSIX_C_SOURCE 200809L /* setenv */
#endif
#include "steaminput.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#define si_dlopen(p) ((void *)LoadLibraryA(p))
#define si_dlsym(h, n) ((void *)GetProcAddress((HMODULE)(h), n))
#define si_dlclose(h) FreeLibrary((HMODULE)(h))
#define SI_CALL __cdecl
#elif defined(__3DS__) || defined(__NDS__) || defined(__EMSCRIPTEN__)
#define si_dlopen(p) ((void)(p), (void *)NULL)
#define si_dlsym(h, n) ((void)(h), (void)(n), (void *)NULL)
#define si_dlclose(h) ((void)(h))
#define SI_CALL
#else
#include <dlfcn.h>
#define si_dlopen(p) dlopen(p, RTLD_NOW | RTLD_LOCAL)
#define si_dlsym(h, n) dlsym(h, n)
#define si_dlclose(h) dlclose(h)
#define SI_CALL
#endif

/* --- glyph sets ------------------------------------------------------------- */

static const char *const set_names[SI_SET_COUNT] = {
	"xbox", "xbox360", "ps4", "ps5", "switch", "steamdeck", "steamcontroller",
};

static const char *const button_names[SI_BTN_COUNT] = {
	"none", "south", "east", "west", "north", "lb", "rb", "lt", "rt", "lstick", "rstick", "lclick", "rclick",
	"dpad", "dup", "ddown", "dleft", "dright", "start", "back", "l4", "l5", "r4", "r5", "lpad", "rpad", "cpad",
	"gyro", "lgrip", "rgrip",
};

const char *si_set_name(si_set_t set) { return set >= 0 && set < SI_SET_COUNT ? set_names[set] : "xbox"; }

si_set_t si_set_for_name(const char *name)
{
	for (int i = 0; name && i < SI_SET_COUNT; i++)
		if (!strcmp(name, set_names[i]))
			return (si_set_t)i;
	return SI_SET_COUNT;
}

const char *si_button_name(si_button_t btn) { return btn > 0 && btn < SI_BTN_COUNT ? button_names[btn] : "none"; }

/* each set's folder and file prefix in Xelu's pack, then the file name of
 * each button after the prefix; NULL where the set has no art */
static const struct {
	const char *prefix;
	const char *files[SI_BTN_COUNT];
} xelu[SI_SET_COUNT] = {
	[SI_SET_XBOX] = {"Xbox Series/XboxSeriesX_",
	                 {[SI_BTN_SOUTH] = "A", [SI_BTN_EAST] = "B", [SI_BTN_WEST] = "X", [SI_BTN_NORTH] = "Y",
	                  [SI_BTN_LB] = "LB", [SI_BTN_RB] = "RB", [SI_BTN_LT] = "LT", [SI_BTN_RT] = "RT",
	                  [SI_BTN_LSTICK] = "Left_Stick", [SI_BTN_RSTICK] = "Right_Stick",
	                  [SI_BTN_LCLICK] = "Left_Stick_Click", [SI_BTN_RCLICK] = "Right_Stick_Click",
	                  [SI_BTN_DPAD] = "Dpad", [SI_BTN_DUP] = "Dpad_Up", [SI_BTN_DDOWN] = "Dpad_Down",
	                  [SI_BTN_DLEFT] = "Dpad_Left", [SI_BTN_DRIGHT] = "Dpad_Right", [SI_BTN_START] = "Menu",
	                  [SI_BTN_BACK] = "View"}},
	[SI_SET_XBOX360] = {"Others/Xbox 360/360_",
	                    {[SI_BTN_SOUTH] = "A", [SI_BTN_EAST] = "B", [SI_BTN_WEST] = "X", [SI_BTN_NORTH] = "Y",
	                     [SI_BTN_LB] = "LB", [SI_BTN_RB] = "RB", [SI_BTN_LT] = "LT", [SI_BTN_RT] = "RT",
	                     [SI_BTN_LSTICK] = "Left_Stick", [SI_BTN_RSTICK] = "Right_Stick",
	                     [SI_BTN_LCLICK] = "Left_Stick_Click", [SI_BTN_RCLICK] = "Right_Stick_Click",
	                     [SI_BTN_DPAD] = "Dpad", [SI_BTN_DUP] = "Dpad_Up", [SI_BTN_DDOWN] = "Dpad_Down",
	                     [SI_BTN_DLEFT] = "Dpad_Left", [SI_BTN_DRIGHT] = "Dpad_Right", [SI_BTN_START] = "Start",
	                     [SI_BTN_BACK] = "Back"}},
	[SI_SET_PS4] = {"Others/PS4/PS4_",
	                {[SI_BTN_SOUTH] = "Cross", [SI_BTN_EAST] = "Circle", [SI_BTN_WEST] = "Square",
	                 [SI_BTN_NORTH] = "Triangle", [SI_BTN_LB] = "L1", [SI_BTN_RB] = "R1", [SI_BTN_LT] = "L2",
	                 [SI_BTN_RT] = "R2", [SI_BTN_LSTICK] = "Left_Stick", [SI_BTN_RSTICK] = "Right_Stick",
	                 [SI_BTN_LCLICK] = "Left_Stick_Click", [SI_BTN_RCLICK] = "Right_Stick_Click",
	                 [SI_BTN_DPAD] = "Dpad", [SI_BTN_DUP] = "Dpad_Up", [SI_BTN_DDOWN] = "Dpad_Down",
	                 [SI_BTN_DLEFT] = "Dpad_Left", [SI_BTN_DRIGHT] = "Dpad_Right", [SI_BTN_START] = "Options",
	                 [SI_BTN_BACK] = "Share", [SI_BTN_CPAD] = "Touch_Pad"}},
	[SI_SET_PS5] = {"PS5/PS5_",
	                {[SI_BTN_SOUTH] = "Cross", [SI_BTN_EAST] = "Circle", [SI_BTN_WEST] = "Square",
	                 [SI_BTN_NORTH] = "Triangle", [SI_BTN_LB] = "L1", [SI_BTN_RB] = "R1", [SI_BTN_LT] = "L2",
	                 [SI_BTN_RT] = "R2", [SI_BTN_LSTICK] = "Left_Stick", [SI_BTN_RSTICK] = "Right_Stick",
	                 [SI_BTN_LCLICK] = "Left_Stick_Click", [SI_BTN_RCLICK] = "Right_Stick_Click",
	                 [SI_BTN_DPAD] = "Dpad", [SI_BTN_DUP] = "Dpad_Up", [SI_BTN_DDOWN] = "Dpad_Down",
	                 [SI_BTN_DLEFT] = "Dpad_Left", [SI_BTN_DRIGHT] = "Dpad_Right", [SI_BTN_START] = "Options",
	                 [SI_BTN_BACK] = "Share", [SI_BTN_CPAD] = "Touch_Pad"}},
	/* Nintendo's labels sit opposite Xbox's: the south button says B */
	[SI_SET_SWITCH] = {"Switch/Switch_",
	                   {[SI_BTN_SOUTH] = "B", [SI_BTN_EAST] = "A", [SI_BTN_WEST] = "Y", [SI_BTN_NORTH] = "X",
	                    [SI_BTN_LB] = "LB", [SI_BTN_RB] = "RB", [SI_BTN_LT] = "LT", [SI_BTN_RT] = "RT",
	                    [SI_BTN_LSTICK] = "Left_Stick", [SI_BTN_RSTICK] = "Right_Stick",
	                    [SI_BTN_LCLICK] = "Left_Stick_Click", [SI_BTN_RCLICK] = "Right_Stick_Click",
	                    [SI_BTN_DPAD] = "Dpad", [SI_BTN_DUP] = "Dpad_Up", [SI_BTN_DDOWN] = "Dpad_Down",
	                    [SI_BTN_DLEFT] = "Dpad_Left", [SI_BTN_DRIGHT] = "Dpad_Right", [SI_BTN_START] = "Plus",
	                    [SI_BTN_BACK] = "Minus"}},
	[SI_SET_STEAMDECK] = {"Steam Deck/SteamDeck_",
	                      {[SI_BTN_SOUTH] = "A", [SI_BTN_EAST] = "B", [SI_BTN_WEST] = "X", [SI_BTN_NORTH] = "Y",
	                       [SI_BTN_LB] = "L1", [SI_BTN_RB] = "R1", [SI_BTN_LT] = "L2", [SI_BTN_RT] = "R2",
	                       [SI_BTN_LSTICK] = "Left_Stick", [SI_BTN_RSTICK] = "Right_Stick",
	                       [SI_BTN_LCLICK] = "Left_Stick_Click", [SI_BTN_RCLICK] = "Right_Stick_Click",
	                       [SI_BTN_DPAD] = "Dpad", [SI_BTN_DUP] = "Dpad_Up", [SI_BTN_DDOWN] = "Dpad_Down",
	                       [SI_BTN_DLEFT] = "Dpad_Left", [SI_BTN_DRIGHT] = "Dpad_Right", [SI_BTN_START] = "Menu",
	                       [SI_BTN_BACK] = "Inventory", [SI_BTN_L4] = "L4", [SI_BTN_L5] = "L5", [SI_BTN_R4] = "R4",
	                       [SI_BTN_R5] = "R5", [SI_BTN_LPAD] = "Left_Track", [SI_BTN_RPAD] = "Right_Track",
	                       [SI_BTN_GYRO] = "Gyro"}},
	/* the original Steam Controller: one stick, which also has the d-pad
	 * when no left pad direction is bound; its grips are its back buttons */
	[SI_SET_STEAMCONTROLLER] = {"Others/Steam/Steam_",
	                            {[SI_BTN_SOUTH] = "A", [SI_BTN_EAST] = "B", [SI_BTN_WEST] = "X", [SI_BTN_NORTH] = "Y",
	                             [SI_BTN_LB] = "LB", [SI_BTN_RB] = "RB", [SI_BTN_LT] = "LT", [SI_BTN_RT] = "RT",
	                             [SI_BTN_LSTICK] = "Stick", [SI_BTN_LCLICK] = "Stick",
	                             [SI_BTN_RSTICK] = "Right_Track", [SI_BTN_RCLICK] = "Right_Track_Center",
	                             [SI_BTN_DPAD] = "Left_Track", [SI_BTN_DUP] = "Left_Track_Up",
	                             [SI_BTN_DDOWN] = "Left_Track_Down", [SI_BTN_DLEFT] = "Left_Track_Left",
	                             [SI_BTN_DRIGHT] = "Left_Track_Right", [SI_BTN_START] = "Start",
	                             [SI_BTN_BACK] = "Back", [SI_BTN_L4] = "Left_Grip", [SI_BTN_R4] = "Right_Grip",
	                             [SI_BTN_LGRIP] = "Left_Grip", [SI_BTN_RGRIP] = "Right_Grip",
	                             [SI_BTN_LPAD] = "Left_Track", [SI_BTN_RPAD] = "Right_Track", [SI_BTN_GYRO] = "Gyro"}},
};

const char *si_xelu_file(si_set_t set, si_button_t btn)
{
	static char buf[96];
	if (set < 0 || set >= SI_SET_COUNT || btn <= 0 || btn >= SI_BTN_COUNT || !xelu[set].files[btn])
		return NULL;
	snprintf(buf, sizeof(buf), "%s%s.png", xelu[set].prefix, xelu[set].files[btn]);
	return buf;
}

const char *si_button_label(si_set_t set, si_button_t btn)
{
	static const char *const generic[SI_BTN_COUNT] = {
		"", "A", "B", "X", "Y", "LB", "RB", "LT", "RT", "LS", "RS", "L3", "R3", "D-pad", "Up", "Down", "Left",
		"Right", "Menu", "View", "L4", "L5", "R4", "R5", "Left pad", "Right pad", "Touchpad", "Gyro",
		"Left grip", "Right grip",
	};
	static const char *const sony[] = {"", "Cross", "Circle", "Square", "Triangle", "L1", "R1", "L2", "R2"};
	static const char *const nintendo[] = {"", "B", "A", "Y", "X", "L", "R", "ZL", "ZR"};
	if (btn <= 0 || btn >= SI_BTN_COUNT)
		return "";
	if ((set == SI_SET_PS4 || set == SI_SET_PS5) && btn <= SI_BTN_RT)
		return sony[btn];
	if (set == SI_SET_SWITCH && btn <= SI_BTN_RT)
		return nintendo[btn];
	if (set == SI_SET_STEAMDECK && btn >= SI_BTN_LB && btn <= SI_BTN_RT)
		return (const char *[]){"L1", "R1", "L2", "R2"}[btn - SI_BTN_LB];
	if ((set == SI_SET_PS4 || set == SI_SET_PS5) && (btn == SI_BTN_START || btn == SI_BTN_BACK))
		return btn == SI_BTN_START ? "Options" : set == SI_SET_PS5 ? "Create" : "Share";
	if (set == SI_SET_SWITCH && (btn == SI_BTN_START || btn == SI_BTN_BACK))
		return btn == SI_BTN_START ? "+" : "-";
	return generic[btn];
}

/* --- controller identity ---------------------------------------------------- */

si_set_t si_set_for_device(uint16_t vid, uint16_t pid, int sdl_type)
{
	switch (vid) {
	case SI_VID_VALVE:
		if (pid == 0x1102 || pid == 0x1142)
			return SI_SET_STEAMCONTROLLER; /* wired, and the wireless dongle */
		if (pid != SI_PID_STEAM_VIRTUAL_GAMEPAD)
			return SI_SET_STEAMDECK; /* the Deck (0x1205) and Valve's newer pads share its layout */
		break;
	case 0x054c: /* Sony */
		if (pid == 0x0ce6 || pid == 0x0df2)
			return SI_SET_PS5; /* DualSense, DualSense Edge */
		if (pid == 0x05c4 || pid == 0x09cc || pid == 0x0ba0 || pid == 0x0268)
			return SI_SET_PS4; /* DualShock 4 (two models, dongle), DualShock 3 */
		break;
	case 0x057e: /* Nintendo */
		return SI_SET_SWITCH;
	case 0x045e: /* Microsoft */
		if (pid == 0x028e || pid == 0x028f || pid == 0x0719 || pid == 0x02a1)
			return SI_SET_XBOX360;
		return SI_SET_XBOX;
	}
	switch (sdl_type) {
	case SI_SDLTYPE_XBOX360: return SI_SET_XBOX360;
	case SI_SDLTYPE_PS3: case SI_SDLTYPE_PS4: return SI_SET_PS4;
	case SI_SDLTYPE_PS5: return SI_SET_PS5;
	case SI_SDLTYPE_SWITCH_PRO: case SI_SDLTYPE_JOYCON_LEFT: case SI_SDLTYPE_JOYCON_RIGHT:
	case SI_SDLTYPE_JOYCON_PAIR: return SI_SET_SWITCH;
	default: return SI_SET_XBOX;
	}
}

int si_virtual_gamepad_slot(const char *name)
{
	const char *p = name ? strstr(name, "pad ") : NULL;
	return p && p[4] >= '0' && p[4] <= '9' ? atoi(p + 4) : -1;
}

/* SteamVirtualGamepadInfo: "[slot N]" sections of name=, VID=, PID=, type=, handle= */
bool si_virtual_gamepad_info(int slot, uint16_t *vid, uint16_t *pid, char *name, size_t namesize)
{
	const char *path = getenv("SteamVirtualGamepadInfo");
	char line[512];
	int cur = -1;
	bool found = false;
	FILE *f;
	if (slot < 0 || !path || !*path || !(f = fopen(path, "r")))
		return false;
	while (fgets(line, sizeof(line), f)) {
		char *eq;
		int n;
		line[strcspn(line, "\r\n")] = 0;
		if (sscanf(line, "[slot %d]", &n) == 1) {
			if (found)
				break;
			cur = n;
			continue;
		}
		if (cur != slot || !(eq = strchr(line, '=')))
			continue;
		*eq++ = 0;
		found = true;
		if (!strcmp(line, "VID") && vid)
			*vid = (uint16_t)strtoul(eq, NULL, 0);
		else if (!strcmp(line, "PID") && pid)
			*pid = (uint16_t)strtoul(eq, NULL, 0);
		else if (!strcmp(line, "name") && name && namesize)
			snprintf(name, namesize, "%s", eq);
	}
	fclose(f);
	return found;
}

/* --- launch ------------------------------------------------------------------ */

static unsigned long long env_u64(const char *name)
{
	const char *v = getenv(name);
	return v && *v ? strtoull(v, NULL, 10) : 0;
}

si_launch_t si_launch(void)
{
	/* read once: si_init names an app id itself, which mustn't change the
	 * answer. SteamGameId is a CGameID: app id in the low 24 bits, then the
	 * type, where 2 is a shortcut (a non-Steam game) */
	static int launch = -1;
	unsigned long long gid;
	if (launch >= 0)
		return (si_launch_t)launch;
	gid = env_u64("SteamGameId");
	if (gid && ((gid >> 24) & 0xff) == 2)
		launch = SI_LAUNCH_SHORTCUT;
	else if (env_u64("SteamAppId") || (gid && (gid & 0xffffff)))
		launch = SI_LAUNCH_STEAMAPP;
	else
		launch = SI_LAUNCH_PLAIN;
	return (si_launch_t)launch;
}

const char *si_launch_name(si_launch_t l)
{
	return l == SI_LAUNCH_SHORTCUT ? "non-Steam game" : l == SI_LAUNCH_STEAMAPP ? "Steam app" : "not from Steam";
}

/* --- the flat API --------------------------------------------------------- */

#pragma pack(push, 1) /* isteaminput.h packs these to 1 on every platform */
typedef struct {
	bool state, active;
} si_digital_data_t;
typedef struct {
	int mode;
	float x, y;
	bool active;
} si_analog_data_t;
#pragma pack(pop)

typedef void *iface_t;

static struct {
	void *lib;
	iface_t in;
	bool started; /* SteamAPI_Init succeeded */
	char status[160];
	void (*log)(const char *msg);
	si_handle_t ctrls[SI_MAX_CONTROLLERS];
	int nctrls;

	int(SI_CALL *InitFlat)(char *err);
	bool(SI_CALL *Init)(void);
	void(SI_CALL *Shutdown)(void);
	bool(SI_CALL *IsSteamRunning)(void);
	void(SI_CALL *RunCallbacks)(void);
	bool(SI_CALL *In_Init)(iface_t, bool explicit_frame);
	bool(SI_CALL *In_Shutdown)(iface_t);
	bool(SI_CALL *In_SetManifest)(iface_t, const char *);
	void(SI_CALL *In_RunFrame)(iface_t, bool);
	int(SI_CALL *In_GetConnected)(iface_t, si_handle_t *);
	si_handle_t(SI_CALL *In_GetActionSet)(iface_t, const char *);
	void(SI_CALL *In_ActivateSet)(iface_t, si_handle_t, si_handle_t);
	void(SI_CALL *In_ActivateLayer)(iface_t, si_handle_t, si_handle_t);
	void(SI_CALL *In_DeactivateLayer)(iface_t, si_handle_t, si_handle_t);
	si_handle_t(SI_CALL *In_GetDigital)(iface_t, const char *);
	si_digital_data_t(SI_CALL *In_DigitalData)(iface_t, si_handle_t, si_handle_t);
	int(SI_CALL *In_DigitalOrigins)(iface_t, si_handle_t, si_handle_t, si_handle_t, int *);
	si_handle_t(SI_CALL *In_GetAnalog)(iface_t, const char *);
	si_analog_data_t(SI_CALL *In_AnalogData)(iface_t, si_handle_t, si_handle_t);
	int(SI_CALL *In_AnalogOrigins)(iface_t, si_handle_t, si_handle_t, si_handle_t, int *);
	const char *(SI_CALL *In_GlyphPNG)(iface_t, int origin, int size, unsigned flags);
	const char *(SI_CALL *In_OriginString)(iface_t, int origin);
	void(SI_CALL *In_Vibrate)(iface_t, si_handle_t, unsigned short, unsigned short);
	void(SI_CALL *In_LED)(iface_t, si_handle_t, unsigned char, unsigned char, unsigned char, unsigned);
	bool(SI_CALL *In_BindingPanel)(iface_t, si_handle_t);
	int(SI_CALL *In_InputType)(iface_t, si_handle_t);
	int(SI_CALL *In_GamepadIndex)(iface_t, si_handle_t);
} st;

static void say(const char *fmt, ...)
{
	char buf[512];
	va_list ap;
	if (!st.log)
		return;
	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);
	st.log(buf);
}

static void *open_steam_api(const char *const *dirs)
{
#ifdef _WIN32
	static const char *const names[] = {sizeof(void *) == 8 ? "steam_api64.dll" : "steam_api.dll", NULL};
#elif defined(__APPLE__)
	static const char *const names[] = {"libsteam_api.dylib", NULL};
#else
	static const char *const names[] = {"libsteam_api.so", NULL};
#endif
	const char *over = getenv("BW_STEAM_API_LIB"); /* tests: a stand-in library */
	char path[1024];
	void *h;
	if (over && *over)
		return si_dlopen(over);
	for (int d = 0; dirs && dirs[d]; d++)
		for (int i = 0; names[i]; i++) {
			snprintf(path, sizeof(path), "%s/%s", dirs[d], names[i]);
			if ((h = si_dlopen(path)))
				return h;
		}
	for (int i = 0; names[i]; i++)
		if ((h = si_dlopen(names[i])))
			return h;
	return NULL;
}

#define LOAD(field, name) (*(void **)&st.field = si_dlsym(st.lib, name))

static void set_env(const char *name, const char *value)
{
#ifdef _WIN32
	SetEnvironmentVariableA(name, value);
	_putenv_s(name, value);
#else
	setenv(name, value, 1);
#endif
}

static void unset_env(const char *name)
{
#ifdef _WIN32
	SetEnvironmentVariableA(name, NULL);
	_putenv_s(name, "");
#else
	unsetenv(name);
#endif
}

/* the app id si_init named, taken back by si_shutdown so that a program this
 * one starts afterwards (the launcher's game) sees the launch Steam made */
static struct {
	bool set;
	char appid[64], gameid[64];
	bool had_appid, had_gameid;
} named;

static void save_env(const char *name, char *out, size_t size, bool *had)
{
	const char *v = getenv(name);
	*had = v != NULL;
	snprintf(out, size, "%s", v ? v : "");
}

static void restore_env(const char *name, const char *value, bool had)
{
	if (had)
		set_env(name, value);
	else
		unset_env(name);
}

static void restore_named_app(void)
{
	if (!named.set)
		return;
	restore_env("SteamAppId", named.appid, named.had_appid);
	restore_env("SteamGameId", named.gameid, named.had_gameid);
	named.set = false;
}

static bool file_exists(const char *path)
{
	FILE *f = fopen(path, "rb");
	if (f)
		fclose(f);
	return f != NULL;
}

bool si_init(const si_config_t *cfg)
{
	static const char *const accessors[] = {"SteamAPI_SteamInput_v006", "SteamAPI_SteamInput_v005",
	                                        "SteamAPI_SteamInput_v002", "SteamAPI_SteamInput_v001", NULL};
	iface_t(SI_CALL * accessor)(void) = NULL;
	si_launch_t launch = si_launch();
	unsigned long long appid = env_u64("SteamAppId");
	char err[1024] = "";
	if (st.in)
		return true;
	st.log = cfg ? cfg->log : NULL;
	snprintf(st.status, sizeof(st.status), "off");
	if (!(st.lib = open_steam_api(cfg ? cfg->libdirs : NULL))) {
		say("Steam Input: no libsteam_api beside the program; using plain controller input");
		snprintf(st.status, sizeof(st.status), "off: no libsteam_api");
		return false;
	}
	LOAD(InitFlat, "SteamAPI_InitFlat");
	LOAD(Init, "SteamAPI_Init");
	LOAD(Shutdown, "SteamAPI_Shutdown");
	LOAD(IsSteamRunning, "SteamAPI_IsSteamRunning");
	LOAD(RunCallbacks, "SteamAPI_RunCallbacks");
	for (int i = 0; accessors[i] && !accessor; i++)
		*(void **)&accessor = si_dlsym(st.lib, accessors[i]);
	if ((!st.InitFlat && !st.Init) || !accessor) {
		say("Steam Input: this libsteam_api has no SteamAPI_Init or no ISteamInput");
		goto fail;
	}
	if (st.IsSteamRunning && !st.IsSteamRunning()) {
		say("Steam Input: Steam isn't running; using plain controller input");
		snprintf(st.status, sizeof(st.status), "off: Steam isn't running");
		goto fail;
	}
	/* Steam names the app for a real Steam launch. As a non-Steam game (or
	 * from a terminal) nothing does, so name one, as steam_appid.txt would */
	if (!appid && !file_exists("steam_appid.txt") && cfg && cfg->appid) {
		char id[32];
		snprintf(id, sizeof(id), "%u", cfg->appid);
		save_env("SteamAppId", named.appid, sizeof(named.appid), &named.had_appid);
		save_env("SteamGameId", named.gameid, sizeof(named.gameid), &named.had_gameid);
		named.set = true;
		set_env("SteamAppId", id);
		set_env("SteamGameId", id);
		appid = cfg->appid;
	}
	if (st.InitFlat) {
		int r = st.InitFlat(err);
		if (r != 0) {
			say("Steam Input: SteamAPI_InitFlat failed (%d): %s", r, err);
			goto fail;
		}
	} else if (!st.Init()) {
		say("Steam Input: SteamAPI_Init failed (is Steam running and signed in?)");
		goto fail;
	}
	st.started = true;
	if (!(st.in = accessor())) {
		say("Steam Input: no ISteamInput interface");
		goto fail;
	}
	LOAD(In_Init, "SteamAPI_ISteamInput_Init");
	LOAD(In_Shutdown, "SteamAPI_ISteamInput_Shutdown");
	LOAD(In_SetManifest, "SteamAPI_ISteamInput_SetInputActionManifestFilePath");
	LOAD(In_RunFrame, "SteamAPI_ISteamInput_RunFrame");
	LOAD(In_GetConnected, "SteamAPI_ISteamInput_GetConnectedControllers");
	LOAD(In_GetActionSet, "SteamAPI_ISteamInput_GetActionSetHandle");
	LOAD(In_ActivateSet, "SteamAPI_ISteamInput_ActivateActionSet");
	LOAD(In_ActivateLayer, "SteamAPI_ISteamInput_ActivateActionSetLayer");
	LOAD(In_DeactivateLayer, "SteamAPI_ISteamInput_DeactivateActionSetLayer");
	LOAD(In_GetDigital, "SteamAPI_ISteamInput_GetDigitalActionHandle");
	LOAD(In_DigitalData, "SteamAPI_ISteamInput_GetDigitalActionData");
	LOAD(In_DigitalOrigins, "SteamAPI_ISteamInput_GetDigitalActionOrigins");
	LOAD(In_GetAnalog, "SteamAPI_ISteamInput_GetAnalogActionHandle");
	LOAD(In_AnalogData, "SteamAPI_ISteamInput_GetAnalogActionData");
	LOAD(In_AnalogOrigins, "SteamAPI_ISteamInput_GetAnalogActionOrigins");
	LOAD(In_GlyphPNG, "SteamAPI_ISteamInput_GetGlyphPNGForActionOrigin");
	LOAD(In_OriginString, "SteamAPI_ISteamInput_GetStringForActionOrigin");
	LOAD(In_Vibrate, "SteamAPI_ISteamInput_TriggerVibration");
	LOAD(In_LED, "SteamAPI_ISteamInput_SetLEDColor");
	LOAD(In_BindingPanel, "SteamAPI_ISteamInput_ShowBindingPanel");
	LOAD(In_InputType, "SteamAPI_ISteamInput_GetInputTypeForHandle");
	LOAD(In_GamepadIndex, "SteamAPI_ISteamInput_GetGamepadIndexForController");
	if (!st.In_Init || !st.In_RunFrame || !st.In_GetConnected || !st.In_GetActionSet || !st.In_ActivateSet ||
	    !st.In_GetDigital || !st.In_DigitalData || !st.In_GetAnalog || !st.In_AnalogData) {
		say("Steam Input: this libsteam_api lacks ISteamInput functions");
		goto fail;
	}
	if (!st.In_Init(st.in, true)) {
		say("Steam Input: ISteamInput::Init failed");
		goto fail;
	}
	if (cfg && cfg->manifest && st.In_SetManifest) {
		if (!st.In_SetManifest(st.in, cfg->manifest))
			say("Steam Input: Steam didn't take the action manifest %s", cfg->manifest);
		else
			say("Steam Input: action manifest %s", cfg->manifest);
	}
	snprintf(st.status, sizeof(st.status), "ISteamInput on app %llu (%s)", appid, si_launch_name(launch));
	say("Steam Input: %s", st.status);
	return true;
fail:
	if (st.started && st.Shutdown)
		st.Shutdown();
	si_dlclose(st.lib);
	{
		char status[sizeof(st.status)];
		void (*log)(const char *) = st.log;
		snprintf(status, sizeof(status), "%s", strcmp(st.status, "off") ? st.status : "off: Steam refused");
		memset(&st, 0, sizeof(st));
		memcpy(st.status, status, sizeof(status));
		st.log = log;
	}
	restore_named_app();
	return false;
}

void si_shutdown(void)
{
	if (!st.lib)
		return;
	if (st.in && st.In_Shutdown)
		st.In_Shutdown(st.in);
	if (st.started && st.Shutdown)
		st.Shutdown();
	si_dlclose(st.lib);
	memset(&st, 0, sizeof(st));
	snprintf(st.status, sizeof(st.status), "off");
	restore_named_app();
}

bool si_active(void) { return st.in != NULL; }
const char *si_status(void) { return st.status[0] ? st.status : "off"; }

void si_frame(void)
{
	si_handle_t h[SI_MAX_CONTROLLERS];
	int n;
	if (!st.in)
		return;
	if (st.RunCallbacks)
		st.RunCallbacks();
	st.In_RunFrame(st.in, false);
	n = st.In_GetConnected(st.in, h);
	n = n < 0 ? 0 : n > SI_MAX_CONTROLLERS ? SI_MAX_CONTROLLERS : n;
	memcpy(st.ctrls, h, n * sizeof(h[0]));
	st.nctrls = n;
}

int si_controllers(si_handle_t *out)
{
	if (!st.in)
		return 0;
	memcpy(out, st.ctrls, st.nctrls * sizeof(out[0]));
	return st.nctrls;
}

int si_input_type(si_handle_t ctrl) { return st.in && st.In_InputType ? st.In_InputType(st.in, ctrl) : 0; }

si_set_t si_set_for_controller(si_handle_t ctrl)
{
	/* ESteamInputType */
	switch (si_input_type(ctrl)) {
	case 1: return SI_SET_STEAMCONTROLLER;
	case 2: return SI_SET_XBOX360;
	case 5: case 12: return SI_SET_PS4;
	case 8: case 9: case 10: case 16: return SI_SET_SWITCH;
	case 13: return SI_SET_PS5;
	case 14: case 15: case 17: case 18: return SI_SET_STEAMDECK; /* Deck, SteamOS handhelds, 2026 pads */
	default: return SI_SET_XBOX;
	}
}

int si_gamepad_index(si_handle_t ctrl)
{
	return st.in && st.In_GamepadIndex ? st.In_GamepadIndex(st.in, ctrl) : -1;
}

si_handle_t si_action_set(const char *name) { return st.in ? st.In_GetActionSet(st.in, name) : 0; }
si_handle_t si_digital_action(const char *name) { return st.in ? st.In_GetDigital(st.in, name) : 0; }
si_handle_t si_analog_action(const char *name) { return st.in ? st.In_GetAnalog(st.in, name) : 0; }

void si_activate_set(si_handle_t ctrl, si_handle_t set)
{
	/* STEAM_INPUT_HANDLE_ALL_CONTROLLERS is UINT64_MAX */
	if (st.in && set)
		st.In_ActivateSet(st.in, ctrl ? ctrl : UINT64_MAX, set);
}

void si_activate_layer(si_handle_t ctrl, si_handle_t layer, bool on)
{
	if (!st.in || !layer)
		return;
	if (on && st.In_ActivateLayer)
		st.In_ActivateLayer(st.in, ctrl ? ctrl : UINT64_MAX, layer);
	else if (!on && st.In_DeactivateLayer)
		st.In_DeactivateLayer(st.in, ctrl ? ctrl : UINT64_MAX, layer);
}

bool si_digital(si_handle_t ctrl, si_handle_t action, bool *active)
{
	si_digital_data_t d = {0};
	if (st.in && action)
		d = st.In_DigitalData(st.in, ctrl, action);
	if (active)
		*active = d.active;
	return d.active && d.state;
}

void si_analog(si_handle_t ctrl, si_handle_t action, float *x, float *y, int *mode, bool *active)
{
	si_analog_data_t d = {0};
	if (st.in && action)
		d = st.In_AnalogData(st.in, ctrl, action);
	if (x)
		*x = d.active ? d.x : 0;
	if (y)
		*y = d.active ? d.y : 0;
	if (mode)
		*mode = d.mode;
	if (active)
		*active = d.active;
}

int si_digital_origins(si_handle_t ctrl, si_handle_t set, si_handle_t action, int *origins)
{
	int n = st.in && st.In_DigitalOrigins && action ? st.In_DigitalOrigins(st.in, ctrl, set, action, origins) : 0;
	return n < 0 ? 0 : n > SI_MAX_ORIGINS ? SI_MAX_ORIGINS : n;
}

int si_analog_origins(si_handle_t ctrl, si_handle_t set, si_handle_t action, int *origins)
{
	int n = st.in && st.In_AnalogOrigins && action ? st.In_AnalogOrigins(st.in, ctrl, set, action, origins) : 0;
	return n < 0 ? 0 : n > SI_MAX_ORIGINS ? SI_MAX_ORIGINS : n;
}

#include "steaminput_origins.h"

bool si_origin_glyph(int origin, si_set_t *set, si_button_t *btn)
{
	/* the table is sorted by origin */
	int lo = 0, hi = SI_ORIGIN_TABLE_COUNT - 1;
	while (lo <= hi) {
		int mid = (lo + hi) / 2;
		if (si_origin_table[mid].origin == origin) {
			if (set)
				*set = (si_set_t)si_origin_table[mid].set;
			if (btn)
				*btn = (si_button_t)si_origin_table[mid].button;
			return true;
		}
		if (si_origin_table[mid].origin < origin)
			lo = mid + 1;
		else
			hi = mid - 1;
	}
	return false;
}

const char *si_steam_glyph(int origin)
{
	/* k_ESteamInputGlyphSize_Medium, k_ESteamInputGlyphStyle_Knockout */
	return st.in && st.In_GlyphPNG ? st.In_GlyphPNG(st.in, origin, 1, 0) : NULL;
}

const char *si_origin_string(int origin)
{
	return st.in && st.In_OriginString ? st.In_OriginString(st.in, origin) : NULL;
}

void si_rumble(si_handle_t ctrl, float low, float high)
{
	if (st.in && st.In_Vibrate)
		st.In_Vibrate(st.in, ctrl, (unsigned short)(low < 0 ? 0 : low > 1 ? 65535 : low * 65535),
		              (unsigned short)(high < 0 ? 0 : high > 1 ? 65535 : high * 65535));
}

void si_led(si_handle_t ctrl, float r, float g, float b)
{
#define C8(v) (unsigned char)((v) < 0 ? 0 : (v) > 1 ? 255 : (v) * 255)
	/* k_ESteamInputLEDFlag_SetColor */
	if (st.in && st.In_LED)
		st.In_LED(st.in, ctrl, C8(r), C8(g), C8(b), 0);
#undef C8
}

bool si_show_binding_panel(si_handle_t ctrl) { return st.in && st.In_BindingPanel && st.In_BindingPanel(st.in, ctrl); }
