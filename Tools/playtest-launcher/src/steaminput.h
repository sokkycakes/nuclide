/* Bulwark engine - Steam Input, loaded at run time. ISC licence, see LICENSE.
 *
 * A small layer over the Steamworks flat API's ISteamInput, plus the parts
 * of controller handling every Steam-aware program here needs whether or
 * not Steam is around: which glyph set a controller wants, and what Steam's
 * virtual gamepad really is when the program runs as a non-Steam game.
 *
 * It has no dependency on the engine or on SDL, so the playtest launcher
 * (nuclide Tools/playtest-launcher) builds the same two files. Nothing from
 * the Steamworks SDK is needed to build it: libsteam_api is looked up when
 * si_init runs, and a program without it simply has no Steam Input.
 * docs/spec/steam-input.md has the whole story. */
#ifndef BW_STEAMINPUT_H
#define BW_STEAMINPUT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* glyph sets: one folder of Xelu's prompts each (data/panorama/images/glyphs) */
typedef enum {
	SI_SET_XBOX,            /* Xbox Series and Xbox One, and anything unknown */
	SI_SET_XBOX360,
	SI_SET_PS4,
	SI_SET_PS5,
	SI_SET_SWITCH,
	SI_SET_STEAMDECK,       /* also the 2026 Steam Controller and Steam Frame controllers */
	SI_SET_STEAMCONTROLLER, /* the original (2015) Steam Controller */
	SI_SET_COUNT
} si_set_t;

/* buttons by position, as SDL's game controller API and Steam Input name
 * them: SOUTH is A on Xbox, Cross on PlayStation and B on Switch */
typedef enum {
	SI_BTN_NONE,
	SI_BTN_SOUTH, SI_BTN_EAST, SI_BTN_WEST, SI_BTN_NORTH,
	SI_BTN_LB, SI_BTN_RB, SI_BTN_LT, SI_BTN_RT,
	SI_BTN_LSTICK, SI_BTN_RSTICK, SI_BTN_LCLICK, SI_BTN_RCLICK,
	SI_BTN_DPAD, SI_BTN_DUP, SI_BTN_DDOWN, SI_BTN_DLEFT, SI_BTN_DRIGHT,
	SI_BTN_START, SI_BTN_BACK,
	SI_BTN_L4, SI_BTN_L5, SI_BTN_R4, SI_BTN_R5,
	SI_BTN_LPAD, SI_BTN_RPAD, SI_BTN_CPAD,
	SI_BTN_GYRO, SI_BTN_LGRIP, SI_BTN_RGRIP,
	SI_BTN_COUNT
} si_button_t;

const char *si_set_name(si_set_t set);       /* "steamdeck", folder names */
si_set_t si_set_for_name(const char *name);  /* SI_SET_COUNT when unknown */
const char *si_button_name(si_button_t btn); /* "south", file names */
/* the Xelu prompt for a button in a set: "SteamDeck/SteamDeck_A.png", as in
 * Xelu's pack, or NULL when the set has no art for it */
const char *si_xelu_file(si_set_t set, si_button_t btn);
/* a short label for a button with no art: "L4", "A", "Cross" */
const char *si_button_label(si_set_t set, si_button_t btn);

/* --- controller identity, with or without Steam ---------------------------- */

#define SI_VID_VALVE 0x28de
#define SI_PID_STEAM_VIRTUAL_GAMEPAD 0x11ff

/* SDL_GameControllerType values, so callers can pass SDL's guess without
 * this file including SDL (SDL_CONTROLLER_TYPE_*) */
enum {
	SI_SDLTYPE_UNKNOWN = 0, SI_SDLTYPE_XBOX360, SI_SDLTYPE_XBOXONE, SI_SDLTYPE_PS3, SI_SDLTYPE_PS4,
	SI_SDLTYPE_SWITCH_PRO, SI_SDLTYPE_VIRTUAL, SI_SDLTYPE_PS5, SI_SDLTYPE_AMAZON_LUNA,
	SI_SDLTYPE_GOOGLE_STADIA, SI_SDLTYPE_NVIDIA_SHIELD, SI_SDLTYPE_JOYCON_LEFT, SI_SDLTYPE_JOYCON_RIGHT,
	SI_SDLTYPE_JOYCON_PAIR
};

/* the glyph set for a USB vendor and product, with SDL's type as a hint */
si_set_t si_set_for_device(uint16_t vid, uint16_t pid, int sdl_type);

/* Steam's virtual gamepad, as a program Steam started sees it (including a
 * non-Steam game): Steam writes what each virtual pad really is to the file
 * named by the SteamVirtualGamepadInfo environment variable. slot is the
 * "pad N" in the device name on Linux and the XInput index on Windows.
 * True and the real vid/pid when the file has the slot. */
bool si_virtual_gamepad_info(int slot, uint16_t *vid, uint16_t *pid, char *name, size_t namesize);
/* the slot of a Steam virtual gamepad from its device name ("... pad 2"), or -1 */
int si_virtual_gamepad_slot(const char *name);

/* --- how the program was started -------------------------------------------- */

typedef enum {
	SI_LAUNCH_PLAIN,    /* not by Steam */
	SI_LAUNCH_STEAMAPP, /* as a Steam app (SteamAppId set) */
	SI_LAUNCH_SHORTCUT  /* as a non-Steam game: SteamGameId names a shortcut */
} si_launch_t;

si_launch_t si_launch(void);
const char *si_launch_name(si_launch_t l);

/* --- ISteamInput ------------------------------------------------------------ */

typedef uint64_t si_handle_t; /* InputHandle_t and the action and set handles */

typedef struct {
	/* folders to look for libsteam_api in before the system's search path
	 * (the executable's own folder, the base folder), NULL-terminated */
	const char *const *libdirs;
	/* absolute path of the In-Game Actions manifest
	 * (SetInputActionManifestFilePath); NULL leaves Steam's own */
	const char *manifest;
	/* the app id to start Steam with when nothing else names one: when run
	 * as a non-Steam game or from a terminal. 480 is Valve's Spacewar, which
	 * every Steam account can run, so it is right for testing. 0 means only
	 * a real Steam launch (SteamAppId) or steam_appid.txt */
	unsigned appid;
	/* where to report what happened; NULL is quiet */
	void (*log)(const char *msg);
} si_config_t;

/* loads libsteam_api, starts the Steam API and ISteamInput. False (and a
 * log line saying why) when there's no library, no running Steam, or Steam
 * refuses: callers then use their ordinary controller path */
bool si_init(const si_config_t *cfg);
void si_shutdown(void);
bool si_active(void);
/* what si_init found, for a status line: "ISteamInput on app 480 (non-Steam game)" */
const char *si_status(void);

/* once a frame: runs Steam's callbacks and ISteamInput's frame, and
 * refreshes the controller list */
void si_frame(void);

#define SI_MAX_CONTROLLERS 16
#define SI_MAX_ORIGINS 8
int si_controllers(si_handle_t *out); /* fills up to SI_MAX_CONTROLLERS */
int si_input_type(si_handle_t ctrl);  /* ESteamInputType */
si_set_t si_set_for_controller(si_handle_t ctrl);
/* the controller's index among the XInput-style pads Steam emulates, -1 none */
int si_gamepad_index(si_handle_t ctrl);

si_handle_t si_action_set(const char *name);
si_handle_t si_digital_action(const char *name);
si_handle_t si_analog_action(const char *name);
/* ctrl 0 activates the set on every controller (STEAM_INPUT_HANDLE_ALL_CONTROLLERS) */
void si_activate_set(si_handle_t ctrl, si_handle_t set);
void si_activate_layer(si_handle_t ctrl, si_handle_t layer, bool on);

bool si_digital(si_handle_t ctrl, si_handle_t action, bool *active);
/* x right, y up (Steam's convention); mode is EInputSourceMode */
void si_analog(si_handle_t ctrl, si_handle_t action, float *x, float *y, int *mode, bool *active);
int si_digital_origins(si_handle_t ctrl, si_handle_t set, si_handle_t action, int *origins);
int si_analog_origins(si_handle_t ctrl, si_handle_t set, si_handle_t action, int *origins);

/* an origin (EInputActionOrigin) as glyph set and button; false when unknown */
bool si_origin_glyph(int origin, si_set_t *set, si_button_t *btn);
/* Steam's own picture of an origin (a PNG path), or NULL */
const char *si_steam_glyph(int origin);
const char *si_origin_string(int origin);

void si_rumble(si_handle_t ctrl, float low, float high);
void si_led(si_handle_t ctrl, float r, float g, float b);
bool si_show_binding_panel(si_handle_t ctrl);

#ifdef __cplusplus
}
#endif

#endif
