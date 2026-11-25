/* what tools/gen_steam_input.py embeds (out/gen/steam_input_data.c) */
#ifndef PL_INPUT_STEAM_DATA_H
#define PL_INPUT_STEAM_DATA_H

#include <stddef.h>

typedef struct {
	const char *name; /* file name in <state>/steam_input/ */
	const char *text;
} steam_input_file;

typedef struct {
	const unsigned char *png;
	size_t len;
} steam_input_png;

/* glyph sets in si_set_t order; buttons in this order */
enum { SIG_SOUTH, SIG_EAST, SIG_START, SIG_DPAD, SIG_LB, SIG_RB, SIG_RSTICK, SIG_BUTTONS };
#define SIG_SETS 7

extern const steam_input_file steam_input_files[]; /* ends with {NULL, NULL} */
extern const steam_input_png steam_input_glyphs[SIG_SETS][SIG_BUTTONS];

#endif
