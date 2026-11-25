/* Playtest launcher: one window, five buttons, works with mouse, keyboard or
 * any controller: Steam Input (Steam Deck, Steam Controller and every pad
 * Steam handles, non-Steam-game launches included) or SDL (Xbox,
 * PlayStation, Switch, generic). Prompts are Xelu's, matched to the pad. */
#include "input_steam.h"
#include "input_steam_data.h"
#include "json.h"
#include "net.h"
#include "platform.h"
#include "update.h"

#include <SDL.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STB_TRUETYPE_IMPLEMENTATION
#include "thirdparty/stb_truetype.h"
#include "thirdparty/stb_image.h"

extern const unsigned char font_regular[];
extern const unsigned int font_regular_len;
extern const unsigned char font_bold[];
extern const unsigned int font_bold_len;

#define VW 1280
#define VH 720
#define OVERSAMPLE 2 /* fonts are baked at 2x the layout size */

/* ---------- config ---------- */

typedef struct {
	char title[128];
	char subtitle[128];
	char exe_dir[1024];
	update_config up;
	int close_on_play;
	int auto_update;
	SDL_Color bg, panel, accent, text, dim;
	char background_image[1024];
	char icon[1024];
	char font_regular[1024], font_bold[1024];
	int steam_input;            /* 0: SDL only */
	unsigned steam_input_appid; /* app id for non-Steam-game launches (480) */
} app_config;

static SDL_Color hexcolor(const char *s, SDL_Color def)
{
	unsigned v;
	SDL_Color c = def;
	if (!s || s[0] != '#' || strlen(s) != 7 || sscanf(s + 1, "%x", &v) != 1) return def;
	c.r = (Uint8)(v >> 16); c.g = (Uint8)(v >> 8); c.b = (Uint8)v; c.a = 255;
	return c;
}

static void resolve(char *out, size_t cap, const char *base, const char *p)
{
	if (!p || !p[0]) { out[0] = 0; return; }
	if (p[0] == '/' || (p[0] && p[1] == ':')) snprintf(out, cap, "%s", p);
	else pl_join(out, cap, base, p);
}

static int load_config(app_config *c, const char *path, char *err, size_t errlen)
{
	char *text = read_text_file(path, NULL);
	jval *j, *os, *theme, *args;
	SDL_Color d_bg = {16, 16, 20, 255}, d_panel = {28, 28, 36, 255}, d_acc = {232, 64, 88, 255},
	          d_text = {236, 236, 240, 255}, d_dim = {140, 140, 152, 255};
	if (!text) { snprintf(err, errlen, "Could not read %s", path); return -1; }
	j = json_parse(text, err, errlen);
	free(text);
	if (!j) return -1;
	snprintf(c->title, sizeof(c->title), "%s", json_str(j, "title", "Playtest"));
	snprintf(c->subtitle, sizeof(c->subtitle), "%s", json_str(j, "subtitle", "PLAYTEST BUILD"));
	snprintf(c->up.title, sizeof(c->up.title), "%s", c->title);
	snprintf(c->up.manifest_url, sizeof(c->up.manifest_url), "%s", json_str(j, "manifest_url", ""));
	resolve(c->up.install_dir, sizeof(c->up.install_dir), c->exe_dir, json_str(j, "install_dir", "game"));
	os = json_get(j, PL_OS);
	snprintf(c->up.run_exe, sizeof(c->up.run_exe), "%s", json_str(os, "exe", ""));
	args = json_get(os, "args");
	c->up.run_argc = 0;
	if (args && args->type == J_ARR)
		for (jval *a = args->child; a && c->up.run_argc < 16; a = a->next)
			if (a->type == J_STR) snprintf(c->up.run_args[c->up.run_argc++], 256, "%s", a->str);
	c->up.connections = (int)json_num(j, "connections", 6);
	c->up.allow_self_update = json_bool(j, "self_update", 1);
	c->close_on_play = json_bool(j, "close_on_play", 1);
	c->auto_update = json_bool(j, "auto_update", 1);
	c->steam_input = json_bool(j, "steam_input", 1);
	c->steam_input_appid = (unsigned)json_num(j, "steam_input_appid", 480);
	theme = json_get(j, "theme");
	c->bg = hexcolor(json_str(theme, "background", NULL), d_bg);
	c->panel = hexcolor(json_str(theme, "panel", NULL), d_panel);
	c->accent = hexcolor(json_str(theme, "accent", NULL), d_acc);
	c->text = hexcolor(json_str(theme, "text", NULL), d_text);
	c->dim = hexcolor(json_str(theme, "dim", NULL), d_dim);
	resolve(c->background_image, sizeof(c->background_image), c->exe_dir, json_str(theme, "background_image", NULL));
	resolve(c->icon, sizeof(c->icon), c->exe_dir, json_str(theme, "icon", NULL));
	resolve(c->font_regular, sizeof(c->font_regular), c->exe_dir, json_str(theme, "font", NULL));
	resolve(c->font_bold, sizeof(c->font_bold), c->exe_dir, json_str(theme, "font_bold", NULL));
	json_free(j);
	if (!c->up.manifest_url[0]) { snprintf(err, errlen, "launcher.json has no manifest_url"); return -1; }
	return 0;
}

/* ---------- text ---------- */

typedef struct {
	SDL_Texture *tex;
	stbtt_packedchar chars[224]; /* 32..255 */
	float size, ascent, line;
} font;

static unsigned char *g_font_files[2];

static int font_bake(SDL_Renderer *r, font *f, const unsigned char *ttf, float px)
{
	const int W = 1024, H = 1024;
	unsigned char *alpha = (unsigned char *)calloc((size_t)W * H, 1);
	Uint32 *rgba;
	stbtt_pack_context pc;
	stbtt_fontinfo info;
	int asc, desc, gap;
	float scale;
	if (!alpha) return -1;
	stbtt_PackBegin(&pc, alpha, W, H, 0, 1, NULL);
	stbtt_PackSetOversampling(&pc, 1, 1);
	stbtt_PackFontRange(&pc, ttf, 0, px * OVERSAMPLE, 32, 224, f->chars);
	stbtt_PackEnd(&pc);
	stbtt_InitFont(&info, ttf, stbtt_GetFontOffsetForIndex(ttf, 0));
	stbtt_GetFontVMetrics(&info, &asc, &desc, &gap);
	scale = stbtt_ScaleForPixelHeight(&info, px);
	f->ascent = asc * scale;
	f->line = (asc - desc + gap) * scale;
	f->size = px;
	rgba = (Uint32 *)malloc(sizeof(Uint32) * (size_t)W * H);
	for (int i = 0; i < W * H; i++) rgba[i] = ((Uint32)alpha[i] << 24) | 0x00FFFFFF;
	f->tex = SDL_CreateTexture(r, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STATIC, W, H);
	SDL_UpdateTexture(f->tex, NULL, rgba, W * 4);
	SDL_SetTextureBlendMode(f->tex, SDL_BLENDMODE_BLEND);
	SDL_SetTextureScaleMode(f->tex, SDL_ScaleModeLinear);
	free(rgba);
	free(alpha);
	return 0;
}

/* decodes one UTF-8 codepoint; unknown ones become '?' */
static int next_cp(const char **s)
{
	const unsigned char *p = (const unsigned char *)*s;
	int cp;
	if (p[0] < 0x80) { cp = p[0]; *s += 1; }
	else if ((p[0] & 0xE0) == 0xC0 && p[1]) { cp = ((p[0] & 31) << 6) | (p[1] & 63); *s += 2; }
	else if ((p[0] & 0xF0) == 0xE0 && p[1] && p[2]) { cp = ((p[0] & 15) << 12) | ((p[1] & 63) << 6) | (p[2] & 63); *s += 3; }
	else { cp = '?'; *s += 1; while ((**s & 0xC0) == 0x80) (*s)++; }
	if (cp == 0x2022) cp = 0xB7;                       /* bullet -> middle dot */
	if (cp == 0x2014 || cp == 0x2013) cp = '-';
	if (cp == 0x2018 || cp == 0x2019) cp = '\'';
	if (cp == 0x201C || cp == 0x201D) cp = '"';
	if (cp == 0x2026) cp = '.';
	if (cp < 32 || cp > 255) cp = '?';
	return cp;
}

static float text_width(font *f, const char *s, size_t n)
{
	float w = 0;
	const char *end = s + n;
	while (s < end && *s) {
		int cp = next_cp(&s);
		w += f->chars[cp - 32].xadvance / OVERSAMPLE;
	}
	return w;
}

static void draw_text(SDL_Renderer *r, font *f, float x, float y, SDL_Color c, const char *s, size_t n)
{
	const char *end = s + n;
	SDL_SetTextureColorMod(f->tex, c.r, c.g, c.b);
	SDL_SetTextureAlphaMod(f->tex, c.a);
	y += f->ascent;
	while (s < end && *s) {
		int cp = next_cp(&s);
		stbtt_packedchar *pc = &f->chars[cp - 32];
		SDL_Rect src = { pc->x0, pc->y0, pc->x1 - pc->x0, pc->y1 - pc->y0 };
		SDL_FRect dst = { x + pc->xoff / OVERSAMPLE, y + pc->yoff / OVERSAMPLE,
		                  (pc->x1 - pc->x0) / (float)OVERSAMPLE, (pc->y1 - pc->y0) / (float)OVERSAMPLE };
		if (src.w > 0) SDL_RenderCopyF(r, f->tex, &src, &dst);
		x += pc->xadvance / OVERSAMPLE;
	}
}

static void draw_str(SDL_Renderer *r, font *f, float x, float y, SDL_Color c, const char *s) { draw_text(r, f, x, y, c, s, strlen(s)); }

/* word-wraps s into width w; returns the height used. draw=0 only measures. */
static float draw_wrapped(SDL_Renderer *r, font *f, float x, float y, float w, SDL_Color c, const char *s, int draw)
{
	float yy = y;
	while (*s) {
		const char *line = s, *brk = NULL, *p = s;
		size_t n;
		while (*p && *p != '\n') {
			const char *q = p;
			if (*p == ' ') brk = p;
			next_cp(&q);
			if (text_width(f, line, (size_t)(q - line)) > w && p > line) break;
			p = q;
		}
		if (*p && *p != '\n' && brk && brk > line) p = brk;
		n = (size_t)(p - line);
		if (draw) draw_text(r, f, x, yy, c, line, n);
		yy += f->line;
		s = p;
		if (*s == '\n' || *s == ' ') s++;
	}
	return yy - y;
}

/* ---------- UI ---------- */

enum { B_PLAY, B_CHECK, B_VERIFY, B_FOLDER, B_QUIT, B_COUNT };
static const char *button_ids[B_COUNT] = { "play", "check", "verify", "folder", "quit" };

typedef struct {
	SDL_Renderer *r;
	font title, big, body, small;
	SDL_Texture *bgimg;
	app_config cfg;
	int focus;
	int hover_lock;      /* mouse moved last */
	float notes_scroll, notes_max;
	update_status st;
	update_state last_state;
	int was_busy;
	int pad_connected;
	int launched;
	char launch_error[256];
	int quit;
	int steam;           /* started by Steam / SteamOS Game Mode */
	int exec_game;       /* POSIX: exec the game after shutting down SDL */
	SDL_Window *win;
	/* controller prompts: the set of the pad used last, and whether that
	 * was a Steam Input controller (whose prompts follow its bindings) */
	si_set_t glyphs;
	int prompt_steam, prompt_chosen;
	SDL_Texture *glyph_tex[SIG_SETS][SIG_BUTTONS];
	/* speed estimate */
	double speed, last_t;
	uint64_t last_bytes;
	SDL_Rect btn[B_COUNT];
} ui;

static int button_enabled(ui *u, int b)
{
	int busy = update_busy();
	switch (b) {
	case B_PLAY: return !busy && u->st.installed && u->st.run_exe[0];
	case B_CHECK: return !busy;
	case B_VERIFY: return !busy;
	case B_FOLDER: return !pl_is_gamescope(); /* no file manager in Game Mode */
	default: return 1;
	}
}

static void fill(SDL_Renderer *r, SDL_Color c, float x, float y, float w, float h)
{
	SDL_FRect rc = { x, y, w, h };
	SDL_SetRenderDrawColor(r, c.r, c.g, c.b, c.a);
	SDL_RenderFillRectF(r, &rc);
}

static SDL_Color mix(SDL_Color a, SDL_Color b, float t)
{
	SDL_Color c;
	c.r = (Uint8)(a.r + (b.r - a.r) * t); c.g = (Uint8)(a.g + (b.g - a.g) * t);
	c.b = (Uint8)(a.b + (b.b - a.b) * t); c.a = 255;
	return c;
}

static void fmt_bytes(char *out, size_t cap, uint64_t b)
{
	if (b >= (1ull << 30)) snprintf(out, cap, "%.2f GB", b / 1073741824.0);
	else snprintf(out, cap, "%.1f MB", b / 1048576.0);
}

static void button_label(ui *u, int b, char *out, size_t cap)
{
	update_status *s = &u->st;
	switch (b) {
	case B_PLAY:
		if (s->state == US_DOWNLOADING && s->bytes_total)
			snprintf(out, cap, "UPDATING %d%%", (int)(100.0 * s->bytes_done / s->bytes_total));
		else if (s->state == US_CHECKING || s->state == US_SCANNING || s->state == US_SELF_UPDATE) snprintf(out, cap, "CHECKING...");
		else if (s->state == US_OFFLINE && s->installed) snprintf(out, cap, "PLAY OFFLINE");
		else if (!s->installed) snprintf(out, cap, "NOT INSTALLED");
		else snprintf(out, cap, "PLAY");
		break;
	case B_CHECK: snprintf(out, cap, (s->state == US_ERROR || s->state == US_OFFLINE) ? "RETRY" : "CHECK FOR UPDATES"); break;
	case B_VERIFY: snprintf(out, cap, "REPAIR GAME FILES"); break;
	case B_FOLDER: snprintf(out, cap, "OPEN GAME FOLDER"); break;
	default: snprintf(out, cap, "QUIT"); break;
	}
}

static void draw_glyph(ui *u, float x, float y, const char *label, SDL_Color c)
{
	float w = text_width(&u->small, label, strlen(label)) + 16;
	fill(u->r, c, x, y, w, 28);
	draw_str(u->r, &u->small, x + 8, y + 3, u->cfg.bg, label);
}

static int glyph_slot(si_button_t b)
{
	switch (b) {
	case SI_BTN_SOUTH: return SIG_SOUTH;
	case SI_BTN_EAST: return SIG_EAST;
	case SI_BTN_START: return SIG_START;
	case SI_BTN_DPAD: case SI_BTN_DUP: case SI_BTN_DDOWN: case SI_BTN_DLEFT: case SI_BTN_DRIGHT: return SIG_DPAD;
	case SI_BTN_LB: return SIG_LB;
	case SI_BTN_RB: return SIG_RB;
	case SI_BTN_RSTICK: return SIG_RSTICK;
	default: return -1;
	}
}

static SDL_Texture *glyph_texture(ui *u, si_set_t set, si_button_t btn)
{
	int b = glyph_slot(btn), w, h, ch;
	const steam_input_png *png;
	unsigned char *px;
	if ((int)set < 0 || set >= SIG_SETS || b < 0) return NULL;
	if (u->glyph_tex[set][b]) return u->glyph_tex[set][b];
	png = &steam_input_glyphs[set][b];
	if (!png->png || !(px = stbi_load_from_memory(png->png, (int)png->len, &w, &h, &ch, 4))) return NULL;
	{
		SDL_Surface *s = SDL_CreateRGBSurfaceWithFormatFrom(px, w, h, 32, w * 4, SDL_PIXELFORMAT_RGBA32);
		if (s) {
			u->glyph_tex[set][b] = SDL_CreateTextureFromSurface(u->r, s);
			SDL_FreeSurface(s);
		}
	}
	stbi_image_free(px);
	if (u->glyph_tex[set][b]) SDL_SetTextureScaleMode(u->glyph_tex[set][b], SDL_ScaleModeLinear);
	return u->glyph_tex[set][b];
}

/* the prompt for a launcher action: what the player bound on a Steam Input
 * controller, otherwise the button the launcher reads on an SDL pad */
static void action_prompt(ui *u, int action, si_set_t *set, si_button_t *btn)
{
	static const si_button_t sdl_button[LA_COUNT] = {
		SI_BTN_DPAD, SI_BTN_DPAD, SI_BTN_SOUTH, SI_BTN_EAST, SI_BTN_START, SI_BTN_LB, SI_BTN_RB,
	};
	if (u->prompt_steam && steam_input_glyph(action, set, btn)) return;
	*set = u->glyphs < SI_SET_COUNT ? u->glyphs : SI_SET_XBOX;
	*btn = sdl_button[action];
}

static void draw_glyph(ui *u, float x, float y, const char *label, SDL_Color c);

static float draw_pad_hint(ui *u, float right, float y, int action, const char *what)
{
	si_set_t set;
	si_button_t btn;
	SDL_Texture *t;
	float x = right - text_width(&u->small, what, strlen(what));
	action_prompt(u, action, &set, &btn);
	draw_str(u->r, &u->small, x, y + 3, u->cfg.dim, what);
	if (!(t = glyph_texture(u, set, btn))) {
		/* no art for that button: its name in a box */
		const char *label = si_button_label(set, btn);
		x -= text_width(&u->small, label, strlen(label)) + 16 + 10;
		draw_glyph(u, x, y, label, u->cfg.dim);
		return x - 28;
	}
	{
		SDL_FRect dst = { x - 10 - 34, y - 3, 34, 34 };
		SDL_RenderCopyF(u->r, t, NULL, &dst);
		return dst.x - 28;
	}
}

static float draw_hint(ui *u, float right, float y, const char *glyph, const char *what)
{
	float tw = text_width(&u->small, what, strlen(what));
	float gw = text_width(&u->small, glyph, strlen(glyph)) + 16;
	float x = right - tw;
	draw_str(u->r, &u->small, x, y + 3, u->cfg.dim, what);
	x -= gw + 10;
	draw_glyph(u, x, y, glyph, u->cfg.dim);
	return x - 28;
}

static void draw_frame(ui *u)
{
	SDL_Renderer *r = u->r;
	app_config *c = &u->cfg;
	char buf[512];
	float y;
	SDL_SetRenderDrawColor(r, c->bg.r, c->bg.g, c->bg.b, 255);
	SDL_RenderClear(r);
	if (u->bgimg) {
		SDL_Rect full = { 0, 0, VW, VH };
		SDL_RenderCopy(r, u->bgimg, NULL, &full);
	}

	/* header */
	draw_str(r, &u->title, 64, 48, c->text, c->title);
	fill(r, c->accent, 64, 128, 6, 26);
	draw_str(r, &u->small, 80, 128, c->accent, c->subtitle);
	snprintf(buf, sizeof(buf), "Installed: %s     Latest: %s",
	         u->st.local_version[0] ? u->st.local_version : "none",
	         u->st.remote_version[0] ? u->st.remote_version : "-");
	draw_str(r, &u->small, 80 + text_width(&u->small, c->subtitle, strlen(c->subtitle)) + 24, 128, c->dim, buf);

	/* buttons */
	y = 196;
	for (int b = 0; b < B_COUNT; b++) {
		int en = button_enabled(u, b), foc = (u->focus == b);
		float h = b == B_PLAY ? 88 : 54;
		font *f = b == B_PLAY ? &u->big : &u->body;
		SDL_Color bgc = foc ? (b == B_PLAY && en ? c->accent : mix(c->panel, c->text, 0.18f)) : c->panel;
		SDL_Color tc = en ? c->text : c->dim;
		if (b == B_PLAY && !foc && en) bgc = mix(c->panel, c->accent, 0.35f);
		fill(r, bgc, 64, y, 380, h);
		if (foc) fill(r, c->text, 64, y, 6, h);
		button_label(u, b, buf, sizeof(buf));
		draw_str(r, f, 92, y + (h - f->line) / 2, tc, buf);
		u->btn[b].x = 64; u->btn[b].y = (int)y; u->btn[b].w = 380; u->btn[b].h = (int)h;
		y += h + (b == B_PLAY ? 18 : 10);
	}

	/* notes */
	{
		SDL_Rect clip = { 500, 236, 716, 326 };
		fill(r, c->panel, 488, 196, 728, 376);
		draw_str(r, &u->small, 500, 204, c->accent, "WHAT'S NEW");
		SDL_RenderSetClipRect(r, &clip);
		{
			const char *notes = u->st.notes[0] ? u->st.notes : "No notes for this build.";
			float h = draw_wrapped(r, &u->body, 500, 0, 696, c->text, notes, 0);
			u->notes_max = h > clip.h ? h - clip.h : 0;
			if (u->notes_scroll > u->notes_max) u->notes_scroll = u->notes_max;
			draw_wrapped(r, &u->body, 500, clip.y - u->notes_scroll, 696, c->text, notes, 1);
		}
		SDL_RenderSetClipRect(r, NULL);
		if (u->notes_max > 0) {
			float th = 326.0f * 326.0f / (326.0f + u->notes_max);
			fill(r, c->dim, 1206, 236 + (326 - th) * (u->notes_scroll / u->notes_max), 4, th);
		}
	}

	/* status + progress */
	{
		SDL_Color mc = (u->st.state == US_ERROR || u->launch_error[0]) ? c->accent : c->text;
		draw_wrapped(r, &u->body, 64, 590, 1152, mc, u->launch_error[0] ? u->launch_error : u->st.message, 1);
		if (u->st.state == US_DOWNLOADING || u->st.state == US_SCANNING) {
			double t = u->st.state == US_DOWNLOADING
				? (u->st.bytes_total ? (double)u->st.bytes_done / u->st.bytes_total : 0)
				: (u->st.files_total ? (double)u->st.files_done / u->st.files_total : 0);
			char a[32], b2[32];
			fill(r, c->panel, 64, 640, 1152, 12);
			fill(r, c->accent, 64, 640, (float)(1152 * (t > 1 ? 1 : t)), 12);
			if (u->st.state == US_DOWNLOADING) {
				fmt_bytes(a, sizeof(a), u->st.bytes_done);
				fmt_bytes(b2, sizeof(b2), u->st.bytes_total);
				if (u->speed > 1024) {
					double left = (u->st.bytes_total - u->st.bytes_done) / u->speed;
					snprintf(buf, sizeof(buf), "%s of %s   %.1f MB/s   about %d:%02d left", a, b2, u->speed / 1048576.0, (int)left / 60, (int)left % 60);
				} else snprintf(buf, sizeof(buf), "%s of %s", a, b2);
			} else snprintf(buf, sizeof(buf), "Checked %d of %d files", u->st.files_done, u->st.files_total);
			draw_str(r, &u->small, 64, 658, c->dim, buf);
		}
	}

	/* control hints */
	{
		float x = VW - 64;
		if (u->pad_connected) {
			x = draw_pad_hint(u, x, 676, LA_BACK, "Quit");
			x = draw_pad_hint(u, x, 676, LA_SELECT, "Select");
			draw_pad_hint(u, x, 676, LA_DOWN, "Move");
		} else {
			x = draw_hint(u, x, 676, "Esc", "Quit");
			x = draw_hint(u, x, 676, "Enter", "Select");
			draw_hint(u, x, 676, "Arrows", "Move");
		}
	}
}

static void render(ui *u)
{
	draw_frame(u);
	SDL_RenderPresent(u->r);
}

/* ---------- actions ---------- */

static void start_update(ui *u, int verify)
{
	update_config up = u->cfg.up;
	up.verify_all = verify;
	u->launch_error[0] = 0;
	update_start(&up);
}

static char g_exec_exe[1200];
static const char *g_exec_argv[20];

static void play(ui *u)
{
	static char exe[1200];
	const char *argv[20];
	int n = 0;
	update_snapshot(&u->st);
	pl_join(exe, sizeof(exe), u->cfg.up.install_dir, u->st.run_exe);
	argv[n++] = exe;
	for (int i = 0; i < u->st.run_argc && n < 19; i++) argv[n++] = u->st.run_args[i];
	argv[n] = NULL;
	if (!pl_exists(exe)) {
		snprintf(u->launch_error, sizeof(u->launch_error), "Could not find %s. Try Repair Game Files.", u->st.run_exe);
		return;
	}
	/* the game starts Steam Input itself, and should see the environment
	 * Steam gave us rather than the app id we named */
	steam_input_shutdown();
	if (u->steam) {
		/* Steam must keep seeing the game as the process it started, or it
		 * thinks the game quit and Game Mode drops the window and controller
		 * layout. POSIX: hand our process over to the game. Windows/Proton:
		 * hide the launcher and wait for the game. */
#ifdef _WIN32
		u->launched = 1;
		printf("launched %s (attached)\n", exe);
		fflush(stdout);
		SDL_HideWindow(u->win);
		pl_run_attached(exe, argv, u->cfg.up.install_dir);
		u->quit = 1;
#else
		snprintf(g_exec_exe, sizeof(g_exec_exe), "%s", exe);
		memcpy(g_exec_argv, argv, sizeof(argv));
		u->exec_game = 1;
		u->launched = 1;
		u->quit = 1;
#endif
		return;
	}
	if (pl_spawn(exe, argv, u->cfg.up.install_dir) != 0) {
		snprintf(u->launch_error, sizeof(u->launch_error), "Could not start %s. Try Repair Game Files.", u->st.run_exe);
		return;
	}
	u->launched = 1;
	printf("launched %s\n", exe);
	fflush(stdout);
	if (u->cfg.close_on_play) u->quit = 1;
}

static void activate(ui *u, int b)
{
	if (!button_enabled(u, b)) return;
	switch (b) {
	case B_PLAY: play(u); break;
	case B_CHECK: start_update(u, 0); break;
	case B_VERIFY: start_update(u, 1); break;
	case B_FOLDER: pl_mkdirs(u->cfg.up.install_dir); pl_open_folder(u->cfg.up.install_dir); break;
	case B_QUIT: u->quit = 1; break;
	}
}

static void move_focus(ui *u, int dir)
{
	int f = u->focus;
	for (int i = 0; i < B_COUNT; i++) {
		f = (f + dir + B_COUNT) % B_COUNT;
		if (button_enabled(u, f)) { u->focus = f; return; }
	}
}

/* ---------- test scripting (drives the real event path) ---------- */

typedef struct {
	char **lines; int n, pc;
	Uint32 wait_start, sleep_until;
	SDL_Joystick *vjoy;
	int release_button;
	int failed;
} script;

static script T;

static void test_fail(const char *fmt, const char *a)
{
	printf("TEST FAIL (line %d): ", T.pc + 1);
	printf(fmt, a);
	printf("\n");
	fflush(stdout);
	T.failed = 1;
}

static int pad_button(const char *name)
{
	SDL_GameControllerButton b = SDL_GameControllerGetButtonFromString(name);
	return (int)b;
}

static void push_key(SDL_Keycode k)
{
	SDL_Event e;
	memset(&e, 0, sizeof(e));
	e.type = SDL_KEYDOWN;
	e.key.keysym.sym = k;
	e.key.keysym.scancode = SDL_GetScancodeFromKey(k);
	e.key.state = SDL_PRESSED;
	SDL_PushEvent(&e);
}

static void script_step(ui *u)
{
	char cmd[64], arg[512];
	Uint32 now = SDL_GetTicks();
	if (T.release_button >= 0) { SDL_JoystickSetVirtualButton(T.vjoy, T.release_button, 0); T.release_button = -1; return; }
	if (now < T.sleep_until || T.pc >= T.n || T.failed) return;
	cmd[0] = arg[0] = 0;
	sscanf(T.lines[T.pc], "%63s %511[^\n]", cmd, arg);
	if (!strcmp(cmd, "wait")) {
		char want[64]; int secs = 120;
		sscanf(arg, "%63s %d", want, &secs);
		if (!T.wait_start) T.wait_start = now;
		if (!strcmp(update_state_name(u->st.state), want) && !update_busy()) { T.wait_start = 0; T.pc++; printf("ok: state %s\n", want); return; }
		if (now - T.wait_start > (Uint32)secs * 1000) { test_fail("timed out waiting for state %s", want); printf("  state=%s message=%s\n", update_state_name(u->st.state), u->st.message); }
		return;
	}
	T.pc++;
	if (!strcmp(cmd, "press")) {
		int b = pad_button(arg);
		if (!T.vjoy || b < 0) { test_fail("no virtual pad or unknown button %s", arg); return; }
		SDL_JoystickSetVirtualButton(T.vjoy, b, 1);
		T.release_button = b;
		T.sleep_until = now + 80;
	} else if (!strcmp(cmd, "key")) {
		push_key(SDL_GetKeyFromName(arg));
		T.sleep_until = now + 80;
	} else if (!strcmp(cmd, "sleep")) {
		T.sleep_until = now + (Uint32)atoi(arg);
	} else if (!strcmp(cmd, "expect_focus")) {
		if (strcmp(button_ids[u->focus], arg)) test_fail("focus is not %s", arg); else printf("ok: focus %s\n", arg);
	} else if (!strcmp(cmd, "expect_local_version")) {
		if (strcmp(u->st.local_version, arg)) { test_fail("local version is not %s", arg); printf("  have %s\n", u->st.local_version); } else printf("ok: version %s\n", arg);
	} else if (!strcmp(cmd, "expect_launched")) {
		if (!u->launched) test_fail("game was not launched%s", ""); else printf("ok: launched\n");
	} else if (!strcmp(cmd, "expect_pad")) {
		if (!u->pad_connected) test_fail("controller not detected%s", ""); else printf("ok: controller detected\n");
	} else if (!strcmp(cmd, "expect_prompt")) {
		/* expect_prompt <action> <set>/<button> */
		static const char *names[LA_COUNT] = { "up", "down", "select", "back", "play", "notes_up", "notes_down" };
		char act[64] = "", want[128] = "", have[128];
		int a = -1;
		si_set_t set;
		si_button_t btn;
		sscanf(arg, "%63s %127s", act, want);
		for (int i = 0; i < LA_COUNT; i++) if (!strcmp(names[i], act)) a = i;
		if (a < 0) { test_fail("unknown action %s", act); return; }
		action_prompt(u, a, &set, &btn);
		snprintf(have, sizeof(have), "%s/%s", si_set_name(set), si_button_name(btn));
		if (strcmp(have, want)) { test_fail("prompt is not %s", want); printf("  have %s\n", have); }
		else printf("ok: prompt %s %s\n", act, have);
	} else if (!strcmp(cmd, "expect_steam_input")) {
		if (steam_input_active() != atoi(arg)) { test_fail("Steam Input active is not %s", arg); printf("  %s\n", steam_input_status()); }
		else printf("ok: steam input %s\n", arg);
	} else if (!strcmp(cmd, "shot")) {
		int w, h;
		SDL_Surface *s;
		SDL_GetRendererOutputSize(u->r, &w, &h);
		s = SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL_PIXELFORMAT_ARGB8888);
		draw_frame(u); /* read before present: D3D discards the back buffer on present */
		SDL_RenderReadPixels(u->r, NULL, SDL_PIXELFORMAT_ARGB8888, s->pixels, s->pitch);
		SDL_SaveBMP(s, arg);
		SDL_FreeSurface(s);
		printf("ok: screenshot %s\n", arg);
	} else if (!strcmp(cmd, "quit")) {
		u->quit = 1;
	} else if (cmd[0] && cmd[0] != '#') {
		test_fail("unknown command %s", cmd);
	}
	fflush(stdout);
}

static int script_load(const char *path)
{
	char *text = read_text_file(path, NULL), *save = NULL, *l;
	if (!text) return -1;
	T.lines = (char **)calloc(512, sizeof(char *));
	for (l = strtok_r(text, "\r\n", &save); l && T.n < 512; l = strtok_r(NULL, "\r\n", &save)) T.lines[T.n++] = strdup(l);
	free(text);
	T.release_button = -1;
	return 0;
}

static void attach_virtual_pad(void)
{
#if SDL_VERSION_ATLEAST(2, 24, 0)
	SDL_VirtualJoystickDesc d;
	int idx;
	memset(&d, 0, sizeof(d));
	d.version = SDL_VIRTUAL_JOYSTICK_DESC_VERSION;
	d.type = SDL_JOYSTICK_TYPE_GAMECONTROLLER;
	d.naxes = SDL_CONTROLLER_AXIS_MAX;
	d.nbuttons = SDL_CONTROLLER_BUTTON_MAX;
	d.name = "Test Pad";
	idx = SDL_JoystickAttachVirtualEx(&d);
	if (idx < 0) { printf("virtual pad failed: %s\n", SDL_GetError()); return; }
	T.vjoy = SDL_JoystickOpen(idx);
#else
	printf("virtual pad needs SDL 2.24 or newer\n");
#endif
}

/* ---------- main ---------- */

static SDL_GameController *g_pads[8];

/* what an SDL pad really is, and so its prompts. Started by Steam (a Steam
 * app or a non-Steam game) the launcher sees Steam's virtual gamepad; SDL
 * 2.30 reads SteamVirtualGamepadInfo and reports the real device, and this
 * reads the file too in case SDL didn't */
static si_set_t pad_set(SDL_GameController *gc)
{
	uint16_t vid = SDL_GameControllerGetVendor(gc), pid = SDL_GameControllerGetProduct(gc);
	int type = (int)SDL_GameControllerGetType(gc);
	if (vid == SI_VID_VALVE && pid == SI_PID_STEAM_VIRTUAL_GAMEPAD) {
		int slot = si_virtual_gamepad_slot(SDL_GameControllerName(gc));
		uint16_t rv = 0, rp = 0;
		const char *deck = getenv("SteamDeck");
		if (slot < 0) slot = SDL_GameControllerGetPlayerIndex(gc);
		if (si_virtual_gamepad_info(slot, &rv, &rp, NULL, 0) && rv) { vid = rv; pid = rp; type = SI_SDLTYPE_UNKNOWN; }
		else if (deck && atoi(deck)) return SI_SET_STEAMDECK;
	}
	return si_set_for_device(vid, pid, type);
}

static SDL_GameController *pad_by_id(SDL_JoystickID id)
{
	for (int i = 0; i < 8; i++)
		if (g_pads[i] && SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(g_pads[i])) == id) return g_pads[i];
	return NULL;
}

static void open_pad(ui *u, int idx)
{
	if (!SDL_IsGameController(idx)) return;
	if (pad_by_id(SDL_JoystickGetDeviceInstanceID(idx))) return; /* already open */
	for (int i = 0; i < 8; i++) if (!g_pads[i]) {
		if ((g_pads[i] = SDL_GameControllerOpen(idx))) {
			si_set_t set = pad_set(g_pads[i]);
			printf("controller: %s (%s prompts)\n", SDL_GameControllerName(g_pads[i]), si_set_name(set));
			fflush(stdout);
			if (!u->prompt_chosen) u->glyphs = set;
		}
		return;
	}
}

static int pad_count(void)
{
	int n = 0;
	for (int i = 0; i < 8; i++) if (g_pads[i] && SDL_GameControllerGetAttached(g_pads[i])) n++;
	return n;
}

static SDL_Texture *load_png(SDL_Renderer *r, const char *path, SDL_Surface **surf_out)
{
	size_t len;
	char *data;
	int w, h, ch;
	unsigned char *px;
	SDL_Surface *s;
	SDL_Texture *t = NULL;
	if (!path[0] || !(data = read_text_file(path, &len))) return NULL;
	px = stbi_load_from_memory((unsigned char *)data, (int)len, &w, &h, &ch, 4);
	free(data);
	if (!px) return NULL;
	s = SDL_CreateRGBSurfaceWithFormatFrom(px, w, h, 32, w * 4, SDL_PIXELFORMAT_RGBA32);
	if (r) t = SDL_CreateTextureFromSurface(r, s);
	if (surf_out) { *surf_out = SDL_DuplicateSurface(s); }
	SDL_FreeSurface(s);
	stbi_image_free(px);
	return t;
}

static void remove_old_exe(const char *exe)
{
	char old[1200];
	snprintf(old, sizeof(old), "%s.old", exe);
	for (int i = 0; i < 20 && pl_exists(old); i++) { if (pl_remove(old) == 0) break; SDL_Delay(100); }
}

int main(int argc, char **argv)
{
	ui u;
	char cfgpath[1200] = "", err[512];
	const char *test_path = NULL;
	SDL_Window *win;
	int verify = 0, after_self = 0, force_steam = 0, fullscreen = 0;
	Uint32 dir_held_since = 0, dir_last_rep = 0;
	int dir_held = 0, axis_dir = 0, steam_dir = 0;

	memset(&u, 0, sizeof(u));
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--config") && i + 1 < argc) snprintf(cfgpath, sizeof(cfgpath), "%s", argv[++i]);
		else if (!strcmp(argv[i], "--test-script") && i + 1 < argc) test_path = argv[++i];
		else if (!strcmp(argv[i], "--verify")) verify = 1;
		else if (!strcmp(argv[i], "--after-self-update")) after_self = 1;
		else if (!strcmp(argv[i], "--steam")) force_steam = 1;
		else if (!strcmp(argv[i], "--fullscreen")) fullscreen = 1;
	}
	if (pl_exe_path(u.cfg.up.exe_path, sizeof(u.cfg.up.exe_path)) == 0) {
		snprintf(u.cfg.exe_dir, sizeof(u.cfg.exe_dir), "%s", u.cfg.up.exe_path);
		pl_dirname(u.cfg.exe_dir);
	}
	if (!cfgpath[0]) pl_join(cfgpath, sizeof(cfgpath), u.cfg.exe_dir, "launcher.json");

	SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
	SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "linear");
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) != 0) {
		fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
		return 1;
	}
	if (load_config(&u.cfg, cfgpath, err, sizeof(err)) != 0) {
		SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Launcher", err, NULL);
		fprintf(stderr, "%s\n", err);
		return 1;
	}
	if (after_self) u.cfg.up.allow_self_update = 0;
	/* Steam Input first: whether it runs decides how SDL treats Valve's pads */
	u.glyphs = SI_SET_XBOX;
	if (u.cfg.steam_input) {
		char state[1100];
		pl_join(state, sizeof(state), u.cfg.up.install_dir, ".launcher");
		steam_input_init(u.cfg.exe_dir, u.cfg.up.install_dir, state, u.cfg.steam_input_appid);
	}
	/* buttons by position, as Steam Input names them: A is the bottom button
	 * on every pad, a Switch pad's B included, so the prompts line up */
	SDL_SetHint(SDL_HINT_GAMECONTROLLER_USE_BUTTON_LABELS, "0");
	/* without Steam, read a Steam Controller or Deck directly (SDL leaves
	 * them to Steam by default, since two readers fight) */
	if (!steam_input_active() && si_launch() == SI_LAUNCH_PLAIN) SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI_STEAM, "1");
	if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) != 0) fprintf(stderr, "controllers: %s\n", SDL_GetError());
	if (net_global_init(err, sizeof(err)) != 0) {
		SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, u.cfg.title, err, NULL);
		return 1;
	}
	remove_old_exe(u.cfg.up.exe_path);

	u.steam = pl_under_steam() || force_steam;
	if (u.steam) printf("steam mode%s\n", pl_is_gamescope() ? " (gamescope)" : "");
	win = SDL_CreateWindow(u.cfg.title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, VW, VH,
	                       SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI |
	                       ((u.steam || fullscreen) ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0));
	if (!win) { fprintf(stderr, "window: %s\n", SDL_GetError()); return 1; }
	u.win = win;
	if (u.steam || fullscreen) SDL_ShowCursor(SDL_DISABLE);
	if (!(u.steam || fullscreen)) {
		SDL_Rect usable;
		if (SDL_GetDisplayUsableBounds(0, &usable) == 0 && (usable.w < VW || usable.h < VH)) {
			float s = SDL_min(usable.w * 0.9f / VW, usable.h * 0.9f / VH);
			SDL_SetWindowSize(win, (int)(VW * s), (int)(VH * s));
			SDL_SetWindowPosition(win, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED);
		}
	}
	SDL_SetWindowMinimumSize(win, VW / 2, VH / 2);
	u.r = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
	if (!u.r) u.r = SDL_CreateRenderer(win, -1, SDL_RENDERER_SOFTWARE);
	if (!u.r) { fprintf(stderr, "renderer: %s\n", SDL_GetError()); return 1; }
	SDL_RenderSetLogicalSize(u.r, VW, VH);
	{
		SDL_Surface *icon = NULL;
		load_png(NULL, u.cfg.icon, &icon);
		if (icon) { SDL_SetWindowIcon(win, icon); SDL_FreeSurface(icon); }
	}
	u.bgimg = load_png(u.r, u.cfg.background_image, NULL);

	{
		const unsigned char *reg = font_regular, *bold = font_bold;
		if (u.cfg.font_regular[0] && (g_font_files[0] = (unsigned char *)read_text_file(u.cfg.font_regular, NULL))) reg = g_font_files[0];
		if (u.cfg.font_bold[0] && (g_font_files[1] = (unsigned char *)read_text_file(u.cfg.font_bold, NULL))) bold = g_font_files[1];
		font_bake(u.r, &u.title, bold, 60);
		font_bake(u.r, &u.big, bold, 36);
		font_bake(u.r, &u.body, reg, 21);
		font_bake(u.r, &u.small, bold, 17);
	}

	if (test_path) {
		if (script_load(test_path) != 0) { fprintf(stderr, "cannot read %s\n", test_path); return 1; }
		attach_virtual_pad();
	}
	for (int i = 0; i < SDL_NumJoysticks(); i++) open_pad(&u, i);

	update_read_local(&u.cfg.up);
	update_snapshot(&u.st);
	if (u.cfg.auto_update || !u.st.installed) start_update(&u, verify);
	u.focus = B_PLAY;
	u.last_state = US_IDLE;

	while (!u.quit) {
		SDL_Event e;
		Uint32 now = SDL_GetTicks();
		int dir = 0;
		steam_ui_input si;
		steam_input_poll(&si);
		while (SDL_PollEvent(&e)) {
			/* while Steam Input has controllers, SDL's pads are Steam's
			 * copy of the same controllers: read them once */
			if (si.controllers && (e.type == SDL_CONTROLLERBUTTONDOWN || e.type == SDL_CONTROLLERAXISMOTION)) continue;
			switch (e.type) {
			case SDL_QUIT: u.quit = 1; break;
			case SDL_CONTROLLERDEVICEADDED: open_pad(&u, e.cdevice.which); break;
			case SDL_CONTROLLERBUTTONDOWN:
				if (u.steam) SDL_ShowCursor(SDL_DISABLE);
				{
					SDL_GameController *gc = pad_by_id(e.cbutton.which);
					if (gc) { u.glyphs = pad_set(gc); u.prompt_steam = 0; u.prompt_chosen = 1; }
				}
				switch (e.cbutton.button) {
				case SDL_CONTROLLER_BUTTON_DPAD_UP: move_focus(&u, -1); dir_held = -1; dir_held_since = now; break;
				case SDL_CONTROLLER_BUTTON_DPAD_DOWN: move_focus(&u, 1); dir_held = 1; dir_held_since = now; break;
				case SDL_CONTROLLER_BUTTON_A: activate(&u, u.focus); break;
				case SDL_CONTROLLER_BUTTON_START: activate(&u, B_PLAY); break;
				case SDL_CONTROLLER_BUTTON_B: u.quit = 1; break;
				case SDL_CONTROLLER_BUTTON_LEFTSHOULDER: u.notes_scroll -= 120; break;
				case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER: u.notes_scroll += 120; break;
				}
				u.hover_lock = 0;
				break;
			case SDL_CONTROLLERBUTTONUP:
				if (e.cbutton.button == SDL_CONTROLLER_BUTTON_DPAD_UP || e.cbutton.button == SDL_CONTROLLER_BUTTON_DPAD_DOWN) dir_held = 0;
				break;
			case SDL_CONTROLLERAXISMOTION:
				if (e.caxis.axis == SDL_CONTROLLER_AXIS_LEFTY) {
					int d = e.caxis.value < -16000 ? -1 : e.caxis.value > 16000 ? 1 : 0;
					if (d && d != axis_dir) { move_focus(&u, d); dir_held = d; dir_held_since = now; }
					if (!d && axis_dir) dir_held = 0;
					axis_dir = d;
				}
				break;
			case SDL_KEYDOWN:
				switch (e.key.keysym.sym) {
				case SDLK_UP: case SDLK_w: move_focus(&u, -1); break;
				case SDLK_DOWN: case SDLK_s: case SDLK_TAB: move_focus(&u, 1); break;
				case SDLK_RETURN: case SDLK_KP_ENTER: case SDLK_SPACE: activate(&u, u.focus); break;
				case SDLK_ESCAPE: u.quit = 1; break;
				case SDLK_PAGEUP: u.notes_scroll -= 200; break;
				case SDLK_PAGEDOWN: u.notes_scroll += 200; break;
				}
				break;
			case SDL_MOUSEMOTION: {
				SDL_Point p = { e.motion.x, e.motion.y };
				if (!pl_is_gamescope()) SDL_ShowCursor(SDL_ENABLE);
				for (int b = 0; b < B_COUNT; b++) if (SDL_PointInRect(&p, &u.btn[b]) && button_enabled(&u, b)) u.focus = b;
				u.hover_lock = 1;
				break;
			}
			case SDL_MOUSEBUTTONDOWN:
				if (e.button.button == SDL_BUTTON_LEFT) {
					SDL_Point p = { e.button.x, e.button.y };
					for (int b = 0; b < B_COUNT; b++) if (SDL_PointInRect(&p, &u.btn[b])) activate(&u, b);
				}
				break;
			case SDL_MOUSEWHEEL: u.notes_scroll -= e.wheel.y * 60; break;
			}
		}
		/* Steam Input controllers: the launcher's own actions */
		if (si.controllers) {
			int d = si.held[LA_UP] ? -1 : si.held[LA_DOWN] ? 1 : si.move_y < -0.5f ? -1 : si.move_y > 0.5f ? 1 : 0;
			if (d && d != steam_dir) { move_focus(&u, d); dir_held = d; dir_held_since = now; }
			if (!d && steam_dir) dir_held = 0;
			steam_dir = d;
			if (si.pressed[LA_SELECT]) activate(&u, u.focus);
			if (si.pressed[LA_PLAY]) activate(&u, B_PLAY);
			if (si.pressed[LA_BACK]) u.quit = 1;
			if (si.pressed[LA_NOTES_UP]) u.notes_scroll -= 120;
			if (si.pressed[LA_NOTES_DOWN]) u.notes_scroll += 120;
			if (fabsf(si.scroll_y) > 0.25f) u.notes_scroll += si.scroll_y * 14;
			if (si.used || !u.prompt_chosen) {
				si_set_t set = steam_input_set();
				if (set < SI_SET_COUNT) u.glyphs = set;
				u.prompt_steam = 1;
				if (si.used) { u.prompt_chosen = 1; u.hover_lock = 0; if (u.steam) SDL_ShowCursor(SDL_DISABLE); }
			}
		} else if (steam_dir) { dir_held = 0; steam_dir = 0; }
		/* held direction repeat (d-pad or stick) */
		if (dir_held && now - dir_held_since > 400 && now - dir_last_rep > 130) { dir = dir_held; dir_last_rep = now; }
		if (dir) move_focus(&u, dir);
		/* right stick scrolls notes */
		for (int i = 0; i < 8; i++) if (g_pads[i] && !si.controllers) {
			int ry = SDL_GameControllerGetAxis(g_pads[i], SDL_CONTROLLER_AXIS_RIGHTY);
			if (abs(ry) > 8000) u.notes_scroll += ry / 32768.0f * 14;
		}
		if (u.notes_scroll < 0) u.notes_scroll = 0;

		update_snapshot(&u.st);
		u.pad_connected = pad_count() > 0 || si.controllers > 0;
		{
			/* when a check/update finishes, put the cursor where the player wants it */
			int busy = update_busy();
			if (!busy && (u.was_busy || u.last_state == US_IDLE)) {
				if ((u.st.state == US_READY || u.st.state == US_OFFLINE) && button_enabled(&u, B_PLAY)) u.focus = B_PLAY;
				else if (u.st.state == US_ERROR) u.focus = B_CHECK;
				u.last_state = u.st.state;
			}
			if (!busy && !button_enabled(&u, u.focus)) move_focus(&u, 1);
			u.was_busy = busy;
		}
		if (u.st.state == US_RESTART && !update_busy()) {
			const char *av[8];
			int k = 0;
			av[k++] = u.cfg.up.exe_path;
			av[k++] = "--after-self-update";
			if (force_steam) av[k++] = "--steam";
			if (test_path) { av[k++] = "--test-script"; av[k++] = test_path; }
			av[k] = NULL;
			printf("restarting after self-update\n");
			fflush(stdout);
			steam_input_shutdown();
			if (u.steam) {
				/* stay the process Steam is tracking */
				SDL_Quit();
#ifdef _WIN32
				exit(pl_run_attached(u.cfg.up.exe_path, av, u.cfg.exe_dir) < 0 ? 1 : 0);
#else
				pl_run_attached(u.cfg.up.exe_path, av, u.cfg.exe_dir);
				return 1;
#endif
			}
			pl_spawn(u.cfg.up.exe_path, av, u.cfg.exe_dir);
			break;
		}
		{
			double t = now / 1000.0;
			if (u.st.state == US_DOWNLOADING) {
				if (t - u.last_t >= 0.5) {
					double inst = (double)(u.st.bytes_done - u.last_bytes) / (t - u.last_t);
					u.speed = u.speed > 0 ? u.speed * 0.6 + inst * 0.4 : inst;
					u.last_t = t; u.last_bytes = u.st.bytes_done;
				}
			} else { u.speed = 0; u.last_t = t; u.last_bytes = 0; }
		}
		if (test_path) {
			script_step(&u);
			if (T.failed) break;
			if (T.pc >= T.n && T.release_button < 0) u.quit = 1;
		}
		render(&u);
		if (!(SDL_GetWindowFlags(win) & SDL_WINDOW_SHOWN)) SDL_Delay(16);
	}
	if (update_busy()) {
		update_cancel();
		for (int i = 0; i < 30 && update_busy(); i++) SDL_Delay(100);
	}
	steam_input_shutdown();
	if (test_path) {
		printf(T.failed ? "TEST RESULT: FAIL\n" : "TEST RESULT: PASS\n");
		fflush(stdout);
	}
	SDL_Quit();
	if (u.exec_game && !(test_path && T.failed)) {
		printf("exec %s\n", g_exec_exe);
		fflush(stdout);
		pl_run_attached(g_exec_exe, g_exec_argv, u.cfg.up.install_dir);
		fprintf(stderr, "could not start %s\n", g_exec_exe);
		return 1;
	}
	return (test_path && T.failed) ? 1 : 0;
}
