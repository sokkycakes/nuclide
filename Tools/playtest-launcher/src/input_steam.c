/* Steam Input for the launcher; see input_steam.h */
#include "input_steam.h"
#include "input_steam_data.h"
#include "json.h"
#include "platform.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* action names, as tools/gen_steam_input.py declares them */
static const char *const digital_names[LA_COUNT] = {
	"ui_up", "ui_down", "ui_select", "ui_back", "ui_play", "ui_notes_up", "ui_notes_down",
};

static struct {
	int on;
	si_handle_t set, digital[LA_COUNT], move, scroll;
	struct {
		si_handle_t h;
		int held[LA_COUNT];
	} ctrl[SI_MAX_CONTROLLERS];
	si_handle_t last;
	char status[256];
} S;

static void log_line(const char *msg)
{
	printf("%s\n", msg);
	fflush(stdout);
}

/* writes a file unless it already holds exactly that text */
static int write_if_changed(const char *path, const char *text)
{
	size_t len = strlen(text), have = 0;
	char *old = read_text_file(path, &have);
	FILE *f;
	int same = old && have == len && !memcmp(old, text, len);
	free(old);
	if (same) return 0;
	if (!(f = pl_fopen(path, "wb"))) return -1;
	fwrite(text, 1, len, f);
	return fclose(f);
}

int steam_input_init(const char *exe_dir, const char *game_dir, const char *state_dir, unsigned appid)
{
	char dir[1200], path[1400], manifest[1400] = "";
	const char *libdirs[3] = { exe_dir, game_dir, NULL };
	si_config_t cfg;
	memset(&S, 0, sizeof(S));
	pl_join(dir, sizeof(dir), state_dir, "steam_input");
	if (pl_mkdirs(dir) == 0) {
		int ok = 1;
		for (const steam_input_file *f = steam_input_files; f->name; f++) {
			pl_join(path, sizeof(path), dir, f->name);
			if (write_if_changed(path, f->text) != 0) ok = 0;
		}
		if (ok) pl_join(manifest, sizeof(manifest), dir, "steam_input_manifest.vdf");
	}
	if (!manifest[0]) printf("Steam Input: could not write the action manifest to %s\n", dir);
	memset(&cfg, 0, sizeof(cfg));
	cfg.libdirs = libdirs;
	cfg.manifest = manifest[0] ? manifest : NULL;
	cfg.appid = appid;
	cfg.log = log_line;
	S.on = si_init(&cfg);
	snprintf(S.status, sizeof(S.status), "%s", si_status());
	return S.on;
}

void steam_input_shutdown(void)
{
	if (!S.on) return;
	si_shutdown();
	S.on = 0;
	S.last = 0;
}

int steam_input_active(void) { return S.on; }
const char *steam_input_status(void) { return S.status[0] ? S.status : "off"; }

/* handles exist once Steam has loaded the manifest, which can take frames */
static void find_handles(void)
{
	if (!S.set) S.set = si_action_set("Launcher");
	if (!S.set) return;
	for (int a = 0; a < LA_COUNT; a++)
		if (!S.digital[a]) S.digital[a] = si_digital_action(digital_names[a]);
	if (!S.move) S.move = si_analog_action("ui_move");
	if (!S.scroll) S.scroll = si_analog_action("ui_scroll");
}

void steam_input_poll(steam_ui_input *in)
{
	si_handle_t h[SI_MAX_CONTROLLERS];
	int n;
	memset(in, 0, sizeof(*in));
	if (!S.on) return;
	si_frame();
	find_handles();
	n = si_controllers(h);
	in->controllers = n;
	/* forget controllers that left */
	for (int k = 0; k < SI_MAX_CONTROLLERS; k++) {
		int found = 0;
		for (int i = 0; i < n && !found; i++) found = S.ctrl[k].h == h[i];
		if (!found) memset(&S.ctrl[k], 0, sizeof(S.ctrl[k]));
	}
	if (S.last) {
		int found = 0;
		for (int i = 0; i < n && !found; i++) found = S.last == h[i];
		if (!found) S.last = 0;
	}
	if (!S.set) return;
	for (int i = 0; i < n; i++) {
		int k, used = 0;
		float x = 0, y = 0;
		int mode = 0;
		bool active = false;
		for (k = 0; k < SI_MAX_CONTROLLERS && S.ctrl[k].h != h[i]; k++) {}
		if (k == SI_MAX_CONTROLLERS) {
			for (k = 0; k < SI_MAX_CONTROLLERS && S.ctrl[k].h; k++) {}
			if (k == SI_MAX_CONTROLLERS) continue;
			S.ctrl[k].h = h[i];
		}
		si_activate_set(h[i], S.set);
		for (int a = 0; a < LA_COUNT; a++) {
			int down = S.digital[a] && si_digital(h[i], S.digital[a], NULL);
			if (down && !S.ctrl[k].held[a]) in->pressed[a] = 1, used = 1;
			if (down) in->held[a] = 1;
			S.ctrl[k].held[a] = down;
		}
		/* Steam's y points up; the launcher's down */
		if (S.move) {
			si_analog(h[i], S.move, &x, &y, &mode, &active);
			if (active && fabsf(y) > fabsf(in->move_y)) in->move_y = -y;
			if (active && fabsf(y) > 0.5f) used = 1;
		}
		if (S.scroll) {
			si_analog(h[i], S.scroll, &x, &y, &mode, &active);
			if (active && fabsf(y) > fabsf(in->scroll_y)) in->scroll_y = -y;
			if (active && fabsf(y) > 0.3f) used = 1;
		}
		if (used) S.last = h[i], in->used = 1;
	}
	if (!S.last && n) S.last = h[0];
}

int steam_input_glyph(int action, si_set_t *set, si_button_t *btn)
{
	int origins[SI_MAX_ORIGINS], n;
	if (!S.on || !S.last || action < 0 || action >= LA_COUNT || !S.digital[action]) return 0;
	n = si_digital_origins(S.last, S.set, S.digital[action], origins);
	for (int i = 0; i < n; i++)
		if (si_origin_glyph(origins[i], set, btn)) return 1;
	return 0;
}

si_set_t steam_input_set(void)
{
	return (S.on && S.last) ? si_set_for_controller(S.last) : SI_SET_COUNT;
}
