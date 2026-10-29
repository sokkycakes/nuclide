/* lay.qc: MGS Portable Ops layout runtime for CSQC.
 *
 * Loads the .lay files written by mpo/tools/mpo2bw.py and plays them the way
 * the game's layout library does (BOOT.BIN 0x19e520 and friends). Each node
 * keeps a live state that starts as its base property block; animation keys
 * and code calls change that state, and the draw walks the node tree.
 *
 * What is read from the game's code (BOOT.BIN, source-confirmed):
 *  - play(layout, hash) does nothing while that animation is already playing
 *    (0x19e520 returns -2), stop removes it, isplaying is 0x19ec48.
 *  - node flag 0x400000 is "shown": root show 0x17722c / 0xaa338(1) set it,
 *    root hide 0x177274 clears it. Layout tags 1/2 are the same switch.
 *  - node +0x44 is a colour override written by menu code (0x80ffffff on,
 *    0x80404040 greyed out).
 * Hypotheses, marked where used:
 *  - play mode 1 (0x19e758) loops; animations run at mpo_animfps frames/s.
 *  - position, size and colour interpolate between keys; other tags step.
 *  - colours multiply down the tree; tag 9 0x20xx is additive blending.
 */

#define LAY_MAXTEX	256
#define LAY_MAXCOL	256
#define LAY_MAXUV	128
#define LAY_MAXGL	2048	/* 16 font slots of 128 codes */
#define LAY_MAXBLK	1024
#define LAY_MAXNODE	512
#define LAY_MAXCH	2048
#define LAY_MAXKEY	2048

/* block masks */
#define LB_V	1
#define LB_H	2
#define LB_P	4
#define LB_S	8
#define LB_C	16
#define LB_T	32
#define LB_U	64
#define LB_X	128
#define LB_F	256
#define LB_K	512
#define LB_B	1024

string g_texname[LAY_MAXTEX];
float g_texw[LAY_MAXTEX], g_texh[LAY_MAXTEX];
/* sprites share the texture index space: sprite n of a layout = slot sprb+n */
float g_sprtex[LAY_MAXTEX], g_sprw[LAY_MAXTEX], g_sprh[LAY_MAXTEX];
vector g_colrgb[LAY_MAXCOL];
float g_cola[LAY_MAXCOL];
vector g_uv0[LAY_MAXUV], g_uv1[LAY_MAXUV];
float g_glu0[LAY_MAXGL], g_glu1[LAY_MAXGL], g_glv0[LAY_MAXGL], g_glv1[LAY_MAXGL], g_gladv[LAY_MAXGL], g_glok[LAY_MAXGL];
entity g_blk[LAY_MAXBLK];
entity g_node[LAY_MAXNODE];
float g_chnode[LAY_MAXCH], g_chkey0[LAY_MAXCH], g_chnkey[LAY_MAXCH];
float g_keyfr[LAY_MAXKEY], g_keyblk[LAY_MAXKEY];

float g_ntex, g_nspr, g_ncol, g_nuv, g_nfont, g_nblk, g_nnode, g_nch, g_nkey;

/* layout fields */
.string lay_name;
.float lay_texb, lay_sprb, lay_colb, lay_uvb, lay_fontb, lay_blkb, lay_nodeb, lay_nnode;
.entity lay_anims;	/* chain of animations */
.entity lay_plays;	/* chain of playing entries */
.float lay_drawn;	/* drawn by lay_drawall */
.entity lay_next;
entity g_layouts;

/* animation fields */
.float an_hash, an_ch0, an_nch, an_len;
.entity an_next;

/* play entry fields */
.entity pl_anim;
.float pl_start, pl_mode;
.entity pl_next;

/* block fields */
.float b_mask, b_px, b_py, b_sw, b_sh, b_col, b_spr, b_uv, b_scale, b_blend, b_align, b_font;
.string b_txt;

/* node fields: identity, live state, code overrides, draw results */
.float n_id, n_parent, n_hash, n_blk;
.float n_vis, n_px, n_py, n_sw, n_sh, n_hass, n_spr, n_uv, n_blend, n_align, n_font;
.vector n_rgb;
.float n_a;
.string n_txt;
.float n_ovcol;
.vector n_ovrgb;
.float n_ova;
.float n_wx, n_wy, n_wa, n_whid;
.vector n_wrgb;

var float autocvar_mpo_animfps = 60;
var float autocvar_mpo_laydebug = 0;

float
lay_hex(string s)
{
	return stof(s);
}

/* tokens from argv(i) */
float af(float i) { return stof(argv(i)); }

void
lay_blkparse(entity b, float n)
{
	float i = 2;
	string g;
	b.b_mask = 0;
	b.b_scale = 1;
	while (i < n) {
		g = argv(i);
		i++;
		if (g == "v") { b.b_mask |= LB_V; }
		else if (g == "h") { b.b_mask |= LB_H; }
		else if (g == "p") { b.b_mask |= LB_P; b.b_px = af(i); b.b_py = af(i+1); i += 2; }
		else if (g == "s") { b.b_mask |= LB_S; b.b_sw = af(i); b.b_sh = af(i+1); i += 2; }
		else if (g == "c") { b.b_mask |= LB_C; b.b_col = af(i); i++; }
		else if (g == "t") { b.b_mask |= LB_T; b.b_spr = af(i); i++; }
		else if (g == "u") { b.b_mask |= LB_U; b.b_uv = af(i); i++; }
		else if (g == "x") { b.b_mask |= LB_X; b.b_txt = strzone(argv(i)); i++; }
		else if (g == "f") { b.b_mask |= LB_F; b.b_align = af(i); b.b_font = af(i+1); i += 2; }
		else if (g == "k") { b.b_mask |= LB_K; b.b_scale = af(i); i++; }
		else if (g == "b") { b.b_mask |= LB_B; b.b_blend = af(i); i++; }
	}
}

/* apply a block to a node's live state */
void
lay_apply(entity lay, entity n, float bi)
{
	entity b;
	float c;
	if (bi < 0)
		return;
	b = g_blk[lay.lay_blkb + bi];
	if (!b)
		return;
	if (b.b_mask & LB_H) n.n_vis = 0;
	if (b.b_mask & LB_V) n.n_vis = 1;	/* v wins when both are present */
	if (b.b_mask & LB_P) { n.n_px = b.b_px; n.n_py = b.b_py; }
	if (b.b_mask & LB_S) { n.n_sw = b.b_sw; n.n_sh = b.b_sh; n.n_hass = 1; }
	if (b.b_mask & LB_C) {
		c = lay.lay_colb + b.b_col;
		n.n_rgb = g_colrgb[c];
		n.n_a = g_cola[c];
	}
	if (b.b_mask & LB_T) n.n_spr = b.b_spr;
	if (b.b_mask & LB_U) n.n_uv = b.b_uv;
	if (b.b_mask & LB_X) n.n_txt = b.b_txt;
	if (b.b_mask & LB_F) { n.n_align = b.b_align; n.n_font = b.b_font; }
	if (b.b_mask & LB_B) n.n_blend = b.b_blend;
}

/* blend between two keys for the tags both carry (hypothesis: linear) */
void
lay_lerp(entity lay, entity n, float b0, float b1, float f)
{
	entity a, b;
	float c0, c1;
	if (b0 < 0 || b1 < 0)
		return;
	a = g_blk[lay.lay_blkb + b0];
	b = g_blk[lay.lay_blkb + b1];
	if ((a.b_mask & LB_P) && (b.b_mask & LB_P)) {
		n.n_px = a.b_px + (b.b_px - a.b_px) * f;
		n.n_py = a.b_py + (b.b_py - a.b_py) * f;
	}
	if ((a.b_mask & LB_S) && (b.b_mask & LB_S)) {
		n.n_sw = a.b_sw + (b.b_sw - a.b_sw) * f;
		n.n_sh = a.b_sh + (b.b_sh - a.b_sh) * f;
	}
	if ((b.b_mask & LB_C)) {
		c1 = lay.lay_colb + b.b_col;
		if (a.b_mask & LB_C)
			c0 = lay.lay_colb + a.b_col;
		else
			return;
		n.n_rgb = g_colrgb[c0] + (g_colrgb[c1] - g_colrgb[c0]) * f;
		n.n_a = g_cola[c0] + (g_cola[c1] - g_cola[c0]) * f;
	}
}

entity
lay_nodebyid(entity lay, float id)
{
	if (id < 1 || id > lay.lay_nnode)
		return world;
	return g_node[lay.lay_nodeb + id];
}

entity
lay_find(entity lay, float hash)
{
	entity n;
	for (float i = 1; i <= lay.lay_nnode; i++) {
		n = g_node[lay.lay_nodeb + i];
		if (n && n.n_hash == hash)
			return n;
	}
	return world;
}

entity
lay_anim(entity lay, float hash)
{
	for (entity a = lay.lay_anims; a; a = a.an_next)
		if (a.an_hash == hash)
			return a;
	return world;
}

entity
lay_load(string stage, string name)
{
	string path = strcat("data/mpo/", stage, "/", name, ".lay");
	filestream fh = fopen(path, FILE_READ);
	string l, w;
	float n, i, slot;
	entity lay, b, nd, an = world, last = world;
	float curch = -1;

	if (fh < 0) {
		print(sprintf("^1lay: can't open %s\n", path));
		return world;
	}
	lay = spawn();
	lay.lay_name = strzone(name);
	lay.lay_texb = g_ntex;
	lay.lay_sprb = g_nspr;
	lay.lay_colb = g_ncol;
	lay.lay_uvb = g_nuv;
	lay.lay_fontb = g_nfont;
	lay.lay_blkb = g_nblk;
	lay.lay_nodeb = g_nnode;

	while ((l = fgets(fh))) {
		n = tokenize(l);
		if (n < 1)
			continue;
		w = argv(0);
		if (w == "tex") {
			i = lay.lay_texb + af(1);
			g_texname[i] = strzone(argv(2));
			g_texw[i] = af(3); g_texh[i] = af(4);
			precache_pic(g_texname[i]);
			if (i + 1 > g_ntex) g_ntex = i + 1;
		} else if (w == "spr") {
			/* sprites are 1-based in the layout */
			i = lay.lay_sprb + af(1);
			g_sprtex[i] = af(2) < 0 ? -1 : lay.lay_texb + af(2);
			g_sprw[i] = af(3); g_sprh[i] = af(4);
			if (i + 1 > g_nspr) g_nspr = i + 1;
		} else if (w == "col") {
			i = lay.lay_colb + af(1);
			g_colrgb[i] = [af(2), af(3), af(4)];
			g_cola[i] = af(5);
			if (i + 1 > g_ncol) g_ncol = i + 1;
		} else if (w == "uv") {
			i = lay.lay_uvb + af(1);
			g_uv0[i] = [af(2), af(3)];
			g_uv1[i] = [af(4), af(5)];
			if (i + 1 > g_nuv) g_nuv = i + 1;
		} else if (w == "font") {
			if (lay.lay_fontb + af(1) > g_nfont) g_nfont = lay.lay_fontb + af(1);
		} else if (w == "gl") {
			if (af(2) < 128) {
				slot = (lay.lay_fontb + af(1) - 1) * 128 + af(2);
				g_glu0[slot] = af(3); g_glu1[slot] = af(4);
				g_glv0[slot] = af(5); g_glv1[slot] = af(6);
				g_gladv[slot] = af(7); g_glok[slot] = 1;
			}
		} else if (w == "blk") {
			i = lay.lay_blkb + af(1);
			b = spawn();
			lay_blkparse(b, n);
			g_blk[i] = b;
			if (i + 1 > g_nblk) g_nblk = i + 1;
		} else if (w == "node") {
			i = lay.lay_nodeb + af(1);
			nd = spawn();
			nd.n_id = af(1); nd.n_parent = af(2); nd.n_hash = af(3); nd.n_blk = af(4);
			nd.n_rgb = '1 1 1'; nd.n_a = 1; nd.n_font = 1; nd.n_blend = 0x1010; nd.n_uv = -1;
			g_node[i] = nd;
			if (af(1) > lay.lay_nnode) lay.lay_nnode = af(1);
			if (i + 1 > g_nnode) g_nnode = i + 1;
		} else if (w == "anim") {
			an = spawn();
			an.an_hash = af(1);
			an.an_ch0 = g_nch;
			an.an_nch = 0;
			if (last) last.an_next = an; else lay.lay_anims = an;
			last = an;
		} else if (w == "ch") {
			curch = g_nch++;
			g_chnode[curch] = af(1);
			g_chkey0[curch] = g_nkey;
			g_chnkey[curch] = 0;
			an.an_nch++;
		} else if (w == "key") {
			g_keyfr[g_nkey] = af(1);
			g_keyblk[g_nkey] = af(2);
			g_nkey++;
			g_chnkey[curch]++;
		}
	}
	fclose(fh);
	g_nnode = lay.lay_nodeb + lay.lay_nnode + 1;

	/* animation length = the longest channel */
	for (an = lay.lay_anims; an; an = an.an_next) {
		an.an_len = 0;
		for (i = 0; i < an.an_nch; i++) {
			float c = an.an_ch0 + i, t = 0;
			for (float k = 0; k < g_chnkey[c]; k++)
				t += g_keyfr[g_chkey0[c] + k];
			if (t > an.an_len) an.an_len = t;
		}
	}
	/* base state */
	for (i = 1; i <= lay.lay_nnode; i++) {
		nd = g_node[lay.lay_nodeb + i];
		if (nd)
			lay_apply(lay, nd, nd.n_blk);
	}
	lay.lay_next = g_layouts;
	g_layouts = lay;
	print(sprintf("lay: %s/%s: %d nodes\n", stage, name, lay.lay_nnode));
	return lay;
}

/* --- the game's layout API --- */

float
lay_isplaying(entity lay, float hash)
{
	for (entity p = lay.lay_plays; p; p = p.pl_next)
		if (p.pl_anim.an_hash == hash)
			return 1;
	return 0;
}

/* 0x19e734 (mode 0), 0x19e758 (mode 1), 0x19e77c (mode 4) */
float
lay_play_mode(entity lay, float hash, float mode)
{
	entity a, p, q;
	if (!lay)
		return -1;
	a = lay_anim(lay, hash);
	if (!a) {
		if (autocvar_mpo_laydebug)
			print(sprintf("lay: %s has no anim %x\n", lay.lay_name, hash));
		return -1;
	}
	if (lay_isplaying(lay, hash))
		return -2;
	p = spawn();
	p.pl_anim = a;
	p.pl_start = cltime;
	p.pl_mode = mode;
	/* keep play order: later plays are applied after earlier ones */
	if (!lay.lay_plays) {
		lay.lay_plays = p;
	} else {
		for (q = lay.lay_plays; q.pl_next; q = q.pl_next);
		q.pl_next = p;
	}
	return 0;
}

float lay_play(entity lay, float hash) { return lay_play_mode(lay, hash, 0); }

/* 0x19e8ec */
void
lay_stop(entity lay, float hash)
{
	entity p, prev = world, nx;
	if (!lay)
		return;
	for (p = lay.lay_plays; p; p = nx) {
		nx = p.pl_next;
		if (p.pl_anim.an_hash == hash) {
			if (prev) prev.pl_next = nx; else lay.lay_plays = nx;
			remove(p);
		} else {
			prev = p;
		}
	}
}

/* root node show (0x17722c) / hide (0x177274) */
void
lay_root(entity lay, float on)
{
	entity r;
	if (!lay)
		return;
	r = lay_nodebyid(lay, 1);
	if (r)
		r.n_vis = on;
	lay.lay_drawn = on;
}

/* 0xaa478 */
void
lay_nodeshow(entity n, float on)
{
	if (n)
		n.n_vis = on;
}

/* 0x19f4b8 */
void
lay_settext(entity n, string s)
{
	if (n)
		n.n_txt = s;
}

/* node +0x44: on = 1 sets the override colour, 0 clears it */
void
lay_setcolor(entity n, float on, vector rgb, float a)
{
	if (!n)
		return;
	n.n_ovcol = on;
	n.n_ovrgb = rgb;
	n.n_ova = a;
}

/* --- per-frame animation --- */

void
lay_runchannel(entity lay, float c, float fr, float done)
{
	entity n = lay_nodebyid(lay, g_chnode[c]);
	float k0 = g_chkey0[c], nk = g_chnkey[c], t = 0, k;
	if (!n || nk < 1)
		return;
	for (k = 0; k < nk; k++) {
		t += g_keyfr[k0 + k];
		if (t > fr && !done) {
			/* between key k-1 and key k */
			if (k > 0) {
				float d = g_keyfr[k0 + k];
				lay_lerp(lay, n, g_keyblk[k0 + k - 1], g_keyblk[k0 + k], d > 0 ? 1 - (t - fr) / d : 1);
			}
			return;
		}
		lay_apply(lay, n, g_keyblk[k0 + k]);
	}
}

void
lay_run(entity lay)
{
	entity p, nx, prev = world, a;
	float fr, done;
	for (p = lay.lay_plays; p; p = nx) {
		nx = p.pl_next;
		a = p.pl_anim;
		fr = (cltime - p.pl_start) * autocvar_mpo_animfps;
		done = 0;
		if (p.pl_mode & 1) {
			/* hypothesis: mode 1 loops */
			if (a.an_len > 0)
				fr = fr - floor(fr / a.an_len) * a.an_len;
		} else if (fr >= a.an_len) {
			done = 1;
		}
		for (float i = 0; i < a.an_nch; i++)
			lay_runchannel(lay, a.an_ch0 + i, fr, done);
		if (done) {
			if (prev) prev.pl_next = nx; else lay.lay_plays = nx;
			remove(p);
		} else {
			prev = p;
		}
	}
}

/* --- drawing --- */

vector g_layorg;
float g_layscale;

void
lay_drawtext(entity lay, entity n, vector pos, vector size, vector rgb, float a, float flag)
{
	float slot0 = (lay.lay_fontb + n.n_font - 1) * 128;
	float si = lay.lay_sprb + n.n_spr;
	float ti = g_sprtex[si];
	float sw = g_sprw[si], sh = g_sprh[si];
	float i, c, l, tw = 0, x, gw, gh;
	string s = n.n_txt;
	if (ti < 0 || !s)
		return;
	l = strlen(s);
	for (i = 0; i < l; i++) {
		c = str2chr(s, i);
		if (c < 128 && g_glok[slot0 + c])
			tw += g_gladv[slot0 + c];
	}
	x = pos[0];
	if (n.n_align == 1) x += size[0] - tw;
	else if (n.n_align == 2) x += (size[0] - tw) / 2;
	for (i = 0; i < l; i++) {
		c = str2chr(s, i);
		if (c >= 128 || !g_glok[slot0 + c])
			continue;
		c += slot0;
		gw = (g_glu1[c] - g_glu0[c]) * sw;
		gh = (g_glv1[c] - g_glv0[c]) * sh;
		drawsubpic(g_layorg + [x, pos[1] + (size[1] - gh) / 2] * g_layscale, [gw, gh] * g_layscale, g_texname[ti],
			[g_glu0[c] * sw / g_texw[ti], g_glv0[c] * sh / g_texh[ti]],
			[gw / g_texw[ti], gh / g_texh[ti]], rgb, a, flag);
		x += g_gladv[c];
	}
}

void
lay_draw(entity lay)
{
	entity n, p;
	float i, si, ti, flag;
	vector pos, size, rgb, uv0, uv1, src0, srcs;

	lay_run(lay);
	if (!lay.lay_drawn)
		return;
	for (i = 1; i <= lay.lay_nnode; i++) {
		n = g_node[lay.lay_nodeb + i];
		if (!n)
			continue;
		p = lay_nodebyid(lay, n.n_parent);
		if (p && p != n) {
			n.n_wx = p.n_wx + n.n_px; n.n_wy = p.n_wy + n.n_py;
			n.n_wrgb = [p.n_wrgb[0] * n.n_rgb[0], p.n_wrgb[1] * n.n_rgb[1], p.n_wrgb[2] * n.n_rgb[2]];
			n.n_wa = p.n_wa * n.n_a;
			n.n_whid = (p.n_whid || n.n_vis == 0) ? 1 : 0;
		} else {
			n.n_wx = n.n_px; n.n_wy = n.n_py;
			n.n_wrgb = n.n_rgb; n.n_wa = n.n_a;
			n.n_whid = (n.n_vis == 0) ? 1 : 0;
		}
		if (n.n_ovcol) {
			n.n_wrgb = [n.n_wrgb[0] * n.n_ovrgb[0], n.n_wrgb[1] * n.n_ovrgb[1], n.n_wrgb[2] * n.n_ovrgb[2]];
			n.n_wa *= n.n_ova;
		}
		if (n.n_whid || n.n_wa <= 0)
			continue;
		pos = [n.n_wx, n.n_wy];
		rgb = n.n_wrgb;
		flag = ((n.n_blend & 0xff00) == 0x2000) ? DRAWFLAG_ADD : DRAWFLAG_NORMAL;
		si = lay.lay_sprb + n.n_spr;
		ti = n.n_spr > 0 ? g_sprtex[si] : -1;
		if (n.n_uv >= 0 && lay.lay_uvb + n.n_uv < g_nuv) {
			uv0 = g_uv0[lay.lay_uvb + n.n_uv];
			uv1 = g_uv1[lay.lay_uvb + n.n_uv];
		} else {
			uv0 = '0 0'; uv1 = '1 1';
		}
		if (n.n_hass)
			size = [n.n_sw, n.n_sh];
		else if (ti >= 0)
			size = [g_sprw[si] * fabs(uv1[0] - uv0[0]), g_sprh[si] * fabs(uv1[1] - uv0[1])];
		else
			continue;
		if (size[0] <= 0 || size[1] <= 0)
			continue;
		if (ti >= 0 && n.n_txt) {
			lay_drawtext(lay, n, pos, size, rgb, n.n_wa, flag);
		} else if (ti >= 0) {
			/* sprite crop scaled by the uv entry; a reversed uv flips */
			src0 = [uv0[0] * g_sprw[si] / g_texw[ti], uv0[1] * g_sprh[si] / g_texh[ti]];
			srcs = [(uv1[0] - uv0[0]) * g_sprw[si] / g_texw[ti], (uv1[1] - uv0[1]) * g_sprh[si] / g_texh[ti]];
			drawsubpic(g_layorg + pos * g_layscale, size * g_layscale, g_texname[ti], src0, srcs, rgb, n.n_wa, flag);
		} else {
			drawfill(g_layorg + pos * g_layscale, size * g_layscale, rgb, n.n_wa, flag);
		}
	}
}

/* fit the PSP's 480x272 screen into the view */
void
lay_setview(vector vsize)
{
	g_layscale = min(vsize[0] / 480, vsize[1] / 272);
	g_layorg = [(vsize[0] - 480 * g_layscale) / 2, (vsize[1] - 272 * g_layscale) / 2];
}
