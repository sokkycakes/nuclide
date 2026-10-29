/* pause.qc: the pause menu, ported from BOOT.BIN.
 *
 * The menu object's fields in the game, and what they are here:
 *   +0x173c lay_pausemenu   g_pm
 *   +0x1740 lay_pausebg     g_pmbg
 *   +0x1744 a third layout (squad table; not ported, it only gets the close)
 *   +0x1668 state step      g_pmstep
 *   +0x1678 cursor          g_pmcursor
 *   +0x166c flags           g_pmflags (0x800 = "back to briefing" variant)
 *   +0x1838 state handler   g_pmstate
 * Node handles are looked up by hash at init (0x177a0c), as the game does.
 */

#define PM_CLOSED	0
#define PM_OPENBG	1	/* 0x178778 steps 2-3: background open, then 88c23e */
#define PM_OPENMENU	2	/* steps 4-6: menu open, then 88c23e */
#define PM_IDLE		3	/* LAB_00178480 */
#define PM_CLOSING	4	/* 0x177e9c: close on every layout, then hide */

/* animation hashes */
#define A_OPEN		0x394d0e
#define A_CLOSE		0x67cacb
#define A_POSTOPEN	0x88c23e

/* string tables */
#define T_PAUSE		0x58e675	/* item labels */
#define T_HELP		0x523eb0	/* help line per item */
#define T_NAMES		0x7ffae2	/* names and missions: not found in the stage files */

entity g_pm, g_pmbg;
float g_pmstate, g_pmstep, g_pmcursor, g_pmflags;
float g_pmenabled[5];	/* seg2 0x6030c: filled at runtime by the game; all on here */
entity g_pmtitle, g_pmsub, g_pmitem[5], g_pmhelp, g_pmfloor, g_pmfloortxt, g_pmhint;

var float autocvar_mpo_pause_briefing = 0;	/* sets flag 0x800 (BACK TO BRIEFING) */

void
pause_init(void)
{
	g_pm = lay_load("r_main01", "lay_pausemenu");
	g_pmbg = lay_load("r_main01", "lay_pausebg");
	if (!g_pm || !g_pmbg)
		return;
	g_pmtitle = lay_find(g_pm, 0x3bddb1);
	g_pmsub = lay_find(g_pm, 0x3bddb2);
	g_pmitem[0] = lay_find(g_pm, 0x6dda96);
	g_pmitem[1] = lay_find(g_pm, 0x6e5a96);
	g_pmitem[2] = lay_find(g_pm, 0x6eda96);
	g_pmitem[3] = lay_find(g_pm, 0x6f5a96);
	g_pmitem[4] = lay_find(g_pm, 0x6fda96);
	g_pmhelp = lay_find(g_pm, 0x997a96);
	g_pmfloor = lay_find(g_pm, 0x5961e0);
	g_pmfloortxt = lay_find(g_pm, 0x3f48d0);
	g_pmhint = lay_find(g_pm, 0x3f48d1);
	lay_settext(g_pmfloortxt, text_get(T_PAUSE, 6));
	lay_settext(g_pmhint, text_get(T_PAUSE, 7));
	for (float i = 0; i < 5; i++)
		g_pmenabled[i] = 1;
	/* init ends with both roots hidden (0x179150, 0x1794ec) */
	lay_root(g_pm, 0);
	lay_root(g_pmbg, 0);
	g_pmstate = PM_CLOSED;
}

/* 0x177968 / 0x1779b0: next / previous enabled item, no wrap */
float
pause_next(float from)
{
	for (float i = 0; i < 5; i++)
		if (g_pmenabled[i] && from < i)
			return i;
	return from;
}

float
pause_prev(float from)
{
	if (from < 0 || from > 4)
		return -1;
	for (float i = 4; i >= 0; i--)
		if (g_pmenabled[i] && i < from)
			return i;
	return from;
}

/* 0x177534 -> 0x1822bc */
void
pause_help(void)
{
	float i = g_pmcursor;
	if (i == 1 && (g_pmflags & 0x800))
		i = 9;
	/* 0x1822bc sets text mode 1 (0x19fd48) before the help line: mixed-case
	 * strings go through the game's keepfont .row font, which isn't decoded
	 * yet. The layout fonts have capitals only, so this is uppercased. */
	lay_settext(g_pmhelp, strtoupper(text_get(T_HELP, i)));
}

/* 0x177aec */
void
pause_fill(void)
{
	/* uRam0000bd84 is set at runtime; 0xfdf7e6 is the variant with five
	 * items and the sixth row hidden (hypothesis: chosen by item count) */
	lay_play(g_pm, 0xfdf7e6);
	/* 0x177a3c */
	lay_stop(g_pm, 0x329064);
	lay_play_mode(g_pm, 0x380dd6, 1);
	/* 0xbd8c: one cursor animation per row */
	lay_play(g_pm, 0x9234b7 + g_pmcursor);
	/* title and subtitle come from table 0x7ffae2 (soldier name, mission);
	 * that table isn't in the stage files, so they are blanked */
	lay_settext(g_pmtitle, text_get(T_NAMES, 0));
	lay_settext(g_pmsub, text_get(T_NAMES, 0));
	lay_settext(g_pmitem[0], text_get(T_PAUSE, 0));
	lay_settext(g_pmitem[1], text_get(T_PAUSE, (g_pmflags & 0x800) ? 2 : 1));
	lay_settext(g_pmitem[2], text_get(T_PAUSE, 3));
	lay_settext(g_pmitem[3], text_get(T_PAUSE, 4));
	lay_settext(g_pmitem[4], text_get(T_PAUSE, 5));
	for (float i = 0; i < 5; i++) {
		if (g_pmenabled[i])
			lay_setcolor(g_pmitem[i], 1, '1 1 1', 1);	/* 0x80ffffff */
		else
			lay_setcolor(g_pmitem[i], 1, [0x40, 0x40, 0x40] / 255, 1);	/* 0x80404040 */
	}
	pause_help();
	/* 0x1771c0 */
	lay_nodeshow(g_pmfloor, 1);
}

void
pause_open(void)
{
	if (!g_pm || g_pmstate != PM_CLOSED)
		return;
	g_pmflags = autocvar_mpo_pause_briefing ? 0x800 : 0;
	/* step 2 (0x178800): background open, then show its root */
	lay_play(g_pmbg, A_OPEN);
	lay_root(g_pmbg, 1);
	g_pmstate = PM_OPENBG;
	g_pmstep = 0;
}

void
pause_close(void)
{
	/* 0x177e9c: close plays on all three layouts */
	lay_play(g_pm, A_CLOSE);
	lay_play(g_pmbg, A_CLOSE);
	g_pmstate = PM_CLOSING;
}

void
pause_select(void)
{
	/* the jump table at the select branch of LAB_00178480 */
	switch (g_pmcursor) {
	case 0:
		print("pause: MEMBER CHANGE (0x17bc90, not ported)\n");
		break;
	case 1:
	case 2:
		print("pause: confirm dialog (0x17a258, not ported)\n");
		break;
	case 3:
		print("pause: KEY CONFIG (0x185b64, not ported)\n");
		break;
	case 4:
		print("pause: OPTIONS (0x184470, not ported)\n");
		break;
	}
}

void
pause_frame(void)
{
	if (!g_pm)
		return;
	switch (g_pmstate) {
	case PM_OPENBG:
		if (g_pmstep == 0 && !lay_isplaying(g_pmbg, A_OPEN)) {
			lay_play(g_pmbg, A_POSTOPEN);
			g_pmstep = 1;
		} else if (g_pmstep == 1 && !lay_isplaying(g_pmbg, A_POSTOPEN)) {
			/* step 4 (0x1789dc) */
			lay_play_mode(g_pm, 0x57b231, 1);
			lay_play(g_pm, A_OPEN);
			g_pmcursor = pause_next(-1);
			lay_play(g_pm, 0x857aa2);	/* 0xe4d723 when flag 0x2000000 is set */
			pause_fill();
			lay_root(g_pm, 1);
			g_pmstate = PM_OPENMENU;
			g_pmstep = 0;
		}
		break;
	case PM_OPENMENU:
		if (g_pmstep == 0 && !lay_isplaying(g_pm, A_OPEN)) {
			lay_play(g_pm, A_POSTOPEN);
			g_pmstep = 1;
		} else if (g_pmstep == 1 && !lay_isplaying(g_pm, A_POSTOPEN)) {
			g_pmstate = PM_IDLE;
		}
		break;
	case PM_CLOSING:
		if (!lay_isplaying(g_pm, A_CLOSE) && !lay_isplaying(g_pmbg, A_CLOSE)) {
			/* 0x177f4c, 0x177f54 */
			lay_root(g_pm, 0);
			lay_root(g_pmbg, 0);
			g_pm.lay_plays = world;
			g_pmbg.lay_plays = world;
			g_pmstate = PM_CLOSED;
		}
		break;
	}
}

/* pad bits as read from +0x1674: 0x10 up, 0x40 down */
void
pause_move(float dir)
{
	float c = dir < 0 ? pause_prev(g_pmcursor) : pause_next(g_pmcursor);
	if (c < 0) c = 0;
	if (c > 4) c = 4;
	if (c == g_pmcursor)
		return;
	/* sound 0x14f (cursor) */
	g_pmcursor = c;
	lay_play(g_pm, 0x9234b7 + c);
	pause_help();
}

/* returns 1 when the key was used */
float
pause_key(float key)
{
	if (g_pmstate == PM_CLOSED) {
		if (key == K_ESCAPE || key == 'p') {
			pause_open();
			return 1;
		}
		return 0;
	}
	if (g_pmstate != PM_IDLE)
		return 1;	/* input is ignored while animating */
	if (key == K_UPARROW) pause_move(-1);
	else if (key == K_DOWNARROW) pause_move(1);
	else if (key == K_ENTER) pause_select();
	else if (key == K_ESCAPE || key == K_BACKSPACE || key == 'p') pause_close();	/* sound 0x161, 0x17ae00 */
	return 1;
}

void
pause_draw(void)
{
	pause_frame();
	lay_draw(g_pmbg);
	lay_draw(g_pm);
}
