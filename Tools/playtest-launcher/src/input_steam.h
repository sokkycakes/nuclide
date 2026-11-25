/* Steam Input for the launcher: the Steam Deck, the Steam Controller and any
 * pad Steam handles drive the launcher through its own action set, and the
 * on-screen prompts match the controller in hand (Xelu's prompts, CC0).
 *
 * Works when the launcher runs as a non-Steam game: with no app id from
 * Steam, ISteamInput starts as app 480 (Spacewar), as the engine does. It
 * needs steam_api64.dll / libsteam_api.so beside the launcher or in the
 * game folder; without it (or without Steam) the launcher uses SDL. The
 * shared Steam layer is steaminput.c, the same file as Bulwark's
 * src/client/steaminput.c. */
#ifndef PL_INPUT_STEAM_H
#define PL_INPUT_STEAM_H

#include "steaminput.h"

enum {
	LA_UP, LA_DOWN, LA_SELECT, LA_BACK, LA_PLAY, LA_NOTES_UP, LA_NOTES_DOWN,
	LA_COUNT
};

typedef struct {
	int pressed[LA_COUNT]; /* went down this frame */
	int held[LA_COUNT];
	float move_y;          /* left stick, -1 up .. 1 down */
	float scroll_y;        /* right stick or trackpad, -1 up .. 1 down */
	int controllers;
	int used;              /* a Steam Input controller did something this frame */
} steam_ui_input;

/* writes the action manifest and layouts to <state_dir>/steam_input/ and
 * starts ISteamInput. 0 when Steam Input isn't available (the reason is
 * printed); the launcher then reads controllers through SDL */
int steam_input_init(const char *exe_dir, const char *game_dir, const char *state_dir, unsigned appid);
/* before the game starts: it needs Steam to itself */
void steam_input_shutdown(void);
int steam_input_active(void);
const char *steam_input_status(void);
void steam_input_poll(steam_ui_input *in);
/* the prompt for an action on the Steam Input controller used last, from
 * what the player has bound to it right now. 0 when there isn't one */
int steam_input_glyph(int action, si_set_t *set, si_button_t *btn);
/* the glyph set of the Steam Input controller used last, SI_SET_COUNT none */
si_set_t steam_input_set(void);

#endif
