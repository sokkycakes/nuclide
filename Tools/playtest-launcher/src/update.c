#include "update.h"
#include "json.h"
#include "net.h"
#include "platform.h"
#include "sha256.h"

#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* stb_image is only used for its zlib decoder (and PNG backgrounds in the UI) */
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#define STBI_NO_STDIO
#include "thirdparty/stb_image.h"

#define MAX_COMPRESSED_RAW (16u << 20)
#define SPAN_MAX (24ull << 20)
#define SPAN_GAP (256ull << 10)
#define MAX_TRIES 4
#define CHUNK (8ull << 20)     /* big raw files are fetched in parallel chunks of this size */

typedef struct {
	char *path;
	char sha[65];
	uint64_t size;
	int pack;
	uint64_t off, len;
	int z, x, keep;
	int need, done;
	/* chunked download of a big raw file */
	int nchunks, chunks_left;
	unsigned char *chunk_done;
} mfile;

typedef struct { char *path; char sha[65]; uint64_t size; int64_t mtime; } sentry;

typedef struct {
	int pack;
	uint64_t start, end;
	int *files;     /* indices into g.files, sorted by offset */
	int nfiles;
	int tries;
	uint64_t received;
	int chunk;      /* >= 0: this task is one chunk of files[0] */
} span;

static struct {
	SDL_mutex *lock;
	SDL_Thread *thread;
	update_config cfg;
	update_status st;
	volatile int cancel;
	int busy;

	/* worker shared state (valid during a download) */
	mfile *files; int nfiles;
	char **packs; int npacks;
	char base_url[1024];
	span *spans; int nspans;
	int *queue; int qhead, qtail, qcap;
	int active_workers;
	int failed;
	char fail_msg[256];
	sentry *done_entries; int ndone, done_cap;
} g;

static void set_status(update_state s, const char *fmt, ...)
{
	va_list ap;
	SDL_LockMutex(g.lock);
	g.st.state = s;
	va_start(ap, fmt);
	vsnprintf(g.st.message, sizeof(g.st.message), fmt, ap);
	va_end(ap);
	SDL_UnlockMutex(g.lock);
}

const char *update_state_name(update_state s)
{
	static const char *n[] = { "idle", "checking", "self_update", "restart", "scanning", "downloading", "ready", "offline", "error" };
	return (s >= 0 && s <= US_ERROR) ? n[s] : "?";
}

/* ---------- local state file ---------- */

static int sentry_cmp(const void *a, const void *b) { return strcmp(((const sentry *)a)->path, ((const sentry *)b)->path); }

static void state_path(char *out, size_t cap) { char t[1100]; pl_join(t, sizeof(t), g.cfg.install_dir, ".launcher"); pl_join(out, cap, t, "state.txt"); }

static sentry *state_load(int *count, char *version, size_t vcap, int load_run)
{
	char path[1200];
	char *text, *line, *save = NULL;
	sentry *e = NULL;
	int n = 0, cap = 0;
	state_path(path, sizeof(path));
	*count = 0;
	if (version) version[0] = 0;
	text = read_text_file(path, NULL);
	if (!text) return NULL;
	for (line = strtok_r(text, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
		if (!strncmp(line, "version\t", 8)) { if (version) snprintf(version, vcap, "%s", line + 8); continue; }
		if (!strncmp(line, "run\t", 4)) {
			if (!load_run) continue;
			/* launch command the last manifest asked for, so offline play still works */
			char *tok, *s2 = NULL;
			int k = 0;
			SDL_LockMutex(g.lock);
			for (tok = strtok_r(line + 4, "\t", &s2); tok; tok = strtok_r(NULL, "\t", &s2), k++) {
				if (k == 0) { snprintf(g.st.run_exe, sizeof(g.st.run_exe), "%s", tok); g.st.run_argc = 0; }
				else if (g.st.run_argc < 16) snprintf(g.st.run_args[g.st.run_argc++], 256, "%s", tok);
			}
			SDL_UnlockMutex(g.lock);
			continue;
		}
		if (!strncmp(line, "f\t", 2)) {
			char sha[65]; unsigned long long size; long long mt; int off = 0;
			if (sscanf(line + 2, "%64s\t%llu\t%lld\t%n", sha, &size, &mt, &off) == 3 && off > 0) {
				if (n == cap) { cap = cap ? cap * 2 : 256; e = (sentry *)realloc(e, sizeof(*e) * (size_t)cap); }
				e[n].path = strdup(line + 2 + off);
				memcpy(e[n].sha, sha, 65);
				e[n].size = size;
				e[n].mtime = mt;
				n++;
			}
		}
	}
	free(text);
	if (n) qsort(e, (size_t)n, sizeof(*e), sentry_cmp);
	*count = n;
	return e;
}

static void state_free(sentry *e, int n) { for (int i = 0; i < n; i++) free(e[i].path); free(e); }

static int state_save(const char *version, sentry *e, int n)
{
	char path[1200], tmp[1300];
	FILE *f;
	state_path(path, sizeof(path));
	snprintf(tmp, sizeof(tmp), "%s.tmp", path);
	pl_mkparents(path);
	f = pl_fopen(tmp, "wb");
	if (!f) return -1;
	fprintf(f, "version\t%s\n", version ? version : "");
	SDL_LockMutex(g.lock);
	if (g.st.run_exe[0] && strcmp(g.st.run_exe, g.cfg.run_exe)) {
		fprintf(f, "run\t%s", g.st.run_exe);
		for (int i = 0; i < g.st.run_argc; i++) fprintf(f, "\t%s", g.st.run_args[i][0] ? g.st.run_args[i] : " ");
		fprintf(f, "\n");
	}
	SDL_UnlockMutex(g.lock);
	for (int i = 0; i < n; i++)
		fprintf(f, "f\t%s\t%llu\t%lld\t%s\n", e[i].sha, (unsigned long long)e[i].size, (long long)e[i].mtime, e[i].path);
	fclose(f);
	return pl_rename(tmp, path);
}

void update_read_local(const update_config *cfg)
{
	char ver[128];
	int n;
	sentry *e;
	if (!g.lock) g.lock = SDL_CreateMutex();
	g.cfg = *cfg;
	SDL_LockMutex(g.lock);
	snprintf(g.st.run_exe, sizeof(g.st.run_exe), "%s", cfg->run_exe);
	g.st.run_argc = cfg->run_argc;
	memcpy(g.st.run_args, cfg->run_args, sizeof(g.st.run_args));
	SDL_UnlockMutex(g.lock);
	e = state_load(&n, ver, sizeof(ver), 1);
	SDL_LockMutex(g.lock);
	snprintf(g.st.local_version, sizeof(g.st.local_version), "%s", ver);
	g.st.installed = ver[0] != 0;
	SDL_UnlockMutex(g.lock);
	state_free(e, n);
}

/* ---------- helpers ---------- */

typedef struct { char *data; size_t len, cap; size_t limit; } membuf;

static int mem_sink(void *ud, const void *data, size_t len)
{
	membuf *m = (membuf *)ud;
	if (m->len + len > m->limit) return 1;
	if (m->len + len + 1 > m->cap) {
		size_t nc = m->cap ? m->cap * 2 : 65536;
		while (nc < m->len + len + 1) nc *= 2;
		m->data = (char *)realloc(m->data, nc);
		if (!m->data) return 1;
		m->cap = nc;
	}
	memcpy(m->data + m->len, data, len);
	m->len += len;
	m->data[m->len] = 0;
	return 0;
}

static int safe_rel_path(const char *p)
{
	if (!p[0] || p[0] == '/' || strchr(p, '\\') || strchr(p, ':')) return 0;
	for (const char *s = p; *s; ) {
		const char *e = strchr(s, '/');
		size_t n = e ? (size_t)(e - s) : strlen(s);
		if (n == 0 || (n == 1 && s[0] == '.') || (n == 2 && s[0] == '.' && s[1] == '.')) return 0;
		if (!e) break;
		s = e + 1;
	}
	return 1;
}

static void url_dir(const char *url, char *out, size_t cap)
{
	const char *q = strchr(url, '?');
	size_t n = q ? (size_t)(q - url) : strlen(url);
	while (n > 0 && url[n - 1] != '/') n--;
	if (n >= cap) n = cap - 1;
	memcpy(out, url, n);
	out[n] = 0;
}

static void sleep_ms(int ms) { SDL_Delay((Uint32)ms); }

static int is_hex64(const char *s)
{
	if (!s || strlen(s) != 64) return 0;
	for (int i = 0; i < 64; i++) if (!((s[i] >= '0' && s[i] <= '9') || (s[i] >= 'a' && s[i] <= 'f'))) return 0;
	return 1;
}

/* ---------- download workers ---------- */

typedef struct {
	span *sp;
	int fi;           /* index into sp->files of the blob being read */
	uint64_t pos;     /* absolute offset in the pack of the next byte */
	/* current blob */
	int open;
	int discard;
	mfile *f;
	FILE *out;
	char part[1200];
	sha256_ctx sha;
	unsigned char *zbuf;
	uint64_t zlen;
	uint64_t got;
	int bad;
	char err[256];
} spanctx;

static void record_done(mfile *f, const char *full)
{
	uint64_t size; int64_t mt;
	if (pl_stat(full, &size, &mt) != 0) return;
	SDL_LockMutex(g.lock);
	if (g.ndone == g.done_cap) {
		g.done_cap = g.done_cap ? g.done_cap * 2 : 256;
		g.done_entries = (sentry *)realloc(g.done_entries, sizeof(sentry) * (size_t)g.done_cap);
	}
	g.done_entries[g.ndone].path = strdup(f->path);
	memcpy(g.done_entries[g.ndone].sha, f->sha, 65);
	g.done_entries[g.ndone].size = size;
	g.done_entries[g.ndone].mtime = mt;
	g.ndone++;
	f->done = 1;
	g.st.files_done++;
	SDL_UnlockMutex(g.lock);
}

static int blob_begin(spanctx *c, mfile *f)
{
	char full[1200];
	c->f = f;
	c->open = 1;
	c->got = 0;
	c->discard = f->done;
	if (c->discard) return 0;
	pl_join(full, sizeof(full), g.cfg.install_dir, f->path);
	snprintf(c->part, sizeof(c->part), "%s.part", full);
	if (f->z) {
		c->zbuf = (unsigned char *)malloc(f->len ? f->len : 1);
		if (!c->zbuf) { snprintf(c->err, sizeof(c->err), "out of memory"); return -1; }
		c->zlen = 0;
		return 0;
	}
	if (pl_mkparents(full) != 0) { snprintf(c->err, sizeof(c->err), "cannot create folder for %s", f->path); return -1; }
	c->out = pl_fopen(c->part, "wb");
	if (!c->out) { snprintf(c->err, sizeof(c->err), "cannot write %s", f->path); return -1; }
	sha256_init(&c->sha);
	return 0;
}

static int blob_feed(spanctx *c, const unsigned char *d, size_t n)
{
	c->got += n;
	if (c->discard) return 0;
	if (c->f->z) { memcpy(c->zbuf + c->zlen, d, n); c->zlen += n; return 0; }
	sha256_update(&c->sha, d, n);
	if (fwrite(d, 1, n, c->out) != n) { snprintf(c->err, sizeof(c->err), "disk full? writing %s", c->f->path); return -1; }
	return 0;
}

static int blob_end(spanctx *c)
{
	mfile *f = c->f;
	char full[1200], hex[65];
	uint8_t dg[32];
	c->open = 0;
	if (c->discard) return 0;
	pl_join(full, sizeof(full), g.cfg.install_dir, f->path);
	if (f->z) {
		char *raw = (char *)malloc(f->size ? f->size : 1);
		int n;
		FILE *o;
		if (!raw) { free(c->zbuf); c->zbuf = NULL; snprintf(c->err, sizeof(c->err), "out of memory"); return -1; }
		n = stbi_zlib_decode_buffer(raw, (int)f->size, (const char *)c->zbuf, (int)c->zlen);
		free(c->zbuf); c->zbuf = NULL;
		if (n < 0 || (uint64_t)n != f->size) { free(raw); snprintf(c->err, sizeof(c->err), "corrupt data for %s", f->path); return -1; }
		sha256_init(&c->sha);
		sha256_update(&c->sha, raw, f->size);
		sha256_final(&c->sha, dg);
		sha256_hex(dg, hex);
		if (strcmp(hex, f->sha)) { free(raw); snprintf(c->err, sizeof(c->err), "checksum mismatch for %s", f->path); return -1; }
		if (pl_mkparents(full) != 0 || !(o = pl_fopen(c->part, "wb"))) { free(raw); snprintf(c->err, sizeof(c->err), "cannot write %s", f->path); return -1; }
		if (fwrite(raw, 1, f->size, o) != f->size) { fclose(o); free(raw); snprintf(c->err, sizeof(c->err), "disk full? writing %s", f->path); return -1; }
		fclose(o);
		free(raw);
	} else {
		fclose(c->out); c->out = NULL;
		sha256_final(&c->sha, dg);
		sha256_hex(dg, hex);
		if (strcmp(hex, f->sha)) { pl_remove(c->part); snprintf(c->err, sizeof(c->err), "checksum mismatch for %s", f->path); return -1; }
	}
	if (pl_rename(c->part, full) != 0) {
		pl_remove(c->part);
		snprintf(c->err, sizeof(c->err), "cannot replace %s (is the game still running?)", f->path);
		return -1;
	}
	if (f->x) pl_make_executable(full);
	record_done(f, full);
	return 0;
}

static int span_sink(void *ud, const void *data, size_t len)
{
	spanctx *c = (spanctx *)ud;
	const unsigned char *d = (const unsigned char *)data;
	if (g.cancel) return 1;
	SDL_LockMutex(g.lock);
	g.st.bytes_done += len;
	SDL_UnlockMutex(g.lock);
	c->sp->received += len;
	while (len > 0) {
		mfile *f;
		uint64_t bstart, bend;
		if (c->fi >= c->sp->nfiles) return 0; /* trailing bytes, ignore */
		f = &g.files[c->sp->files[c->fi]];
		bstart = f->off; bend = f->off + f->len;
		if (c->pos < bstart) { /* gap between blobs */
			uint64_t skip = bstart - c->pos;
			if (skip > len) skip = len;
			c->pos += skip; d += skip; len -= (size_t)skip;
			continue;
		}
		if (!c->open && blob_begin(c, f) != 0) { c->bad = 1; return 1; }
		{
			uint64_t take = bend - c->pos;
			if (take > len) take = len;
			if (take && blob_feed(c, d, (size_t)take) != 0) { c->bad = 1; return 1; }
			c->pos += take; d += take; len -= (size_t)take;
		}
		if (c->pos == bend) {
			if (blob_end(c) != 0) { c->bad = 1; return 1; }
			c->fi++;
		}
	}
	return 0;
}

static void span_cleanup(spanctx *c)
{
	if (c->out) { fclose(c->out); c->out = NULL; pl_remove(c->part); }
	free(c->zbuf); c->zbuf = NULL;
}

/* ---- chunked big files: <path>.part plus <path>.part.chunks listing finished chunks ---- */

static void part_paths(mfile *f, char *part, char *side, size_t cap)
{
	char full[1200];
	pl_join(full, sizeof(full), g.cfg.install_dir, f->path);
	snprintf(part, cap, "%s.part", full);
	snprintf(side, cap, "%s.part.chunks", full);
}

/* loads finished chunks from an earlier interrupted run, or starts a fresh .part */
static int chunks_prepare(mfile *f)
{
	char part[1300], side[1300], *text;
	uint64_t psize;
	f->nchunks = (int)((f->size + CHUNK - 1) / CHUNK);
	free(f->chunk_done);
	f->chunk_done = (unsigned char *)calloc((size_t)f->nchunks, 1);
	f->chunks_left = f->nchunks;
	part_paths(f, part, side, sizeof(part));
	text = read_text_file(side, NULL);
	if (text && !strncmp(text, f->sha, 64) && pl_stat(part, &psize, NULL) == 0 && psize == f->size) {
		char *line, *save = NULL;
		for (line = strtok_r(text + 64, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
			int c = atoi(line);
			if (c >= 0 && c < f->nchunks && !f->chunk_done[c]) { f->chunk_done[c] = 1; f->chunks_left--; }
		}
		free(text);
		return 0;
	}
	free(text);
	{
		char full[1200];
		FILE *o, *sf;
		pl_join(full, sizeof(full), g.cfg.install_dir, f->path);
		if (pl_mkparents(full) != 0) return -1;
		o = pl_fopen(part, "wb");
		if (!o) return -1;
		fclose(o);
		/* size the file up front so chunks can be written in any order */
		o = pl_fopen(part, "r+b");
		if (!o) return -1;
#ifdef _WIN32
		_fseeki64(o, (long long)f->size - 1, SEEK_SET);
#else
		fseeko(o, (off_t)f->size - 1, SEEK_SET);
#endif
		fputc(0, o);
		fclose(o);
		sf = pl_fopen(side, "wb");
		if (!sf) return -1;
		fprintf(sf, "%s\n", f->sha);
		fclose(sf);
	}
	return 0;
}

typedef struct { FILE *out; uint64_t left; int bad; } chunkctx;

static int chunk_sink(void *ud, const void *data, size_t len)
{
	chunkctx *c = (chunkctx *)ud;
	if (g.cancel) return 1;
	if (len > c->left) len = (size_t)c->left;
	if (len && fwrite(data, 1, len, c->out) != len) { c->bad = 1; return 1; }
	c->left -= len;
	SDL_LockMutex(g.lock);
	g.st.bytes_done += len;
	SDL_UnlockMutex(g.lock);
	return 0;
}

static int run_chunk(net_conn *conn, span *sp, char *err, size_t errlen)
{
	mfile *f = &g.files[sp->files[0]];
	char url[2048], part[1300], side[1300];
	chunkctx c;
	int status, r, last = 0;
	uint64_t at = (uint64_t)sp->chunk * CHUNK;
	part_paths(f, part, side, sizeof(part));
	c.out = pl_fopen(part, "r+b");
	if (!c.out) { snprintf(err, errlen, "cannot write %s", f->path); return -1; }
#ifdef _WIN32
	_fseeki64(c.out, (long long)at, SEEK_SET);
#else
	fseeko(c.out, (off_t)at, SEEK_SET);
#endif
	c.left = sp->end - sp->start;
	c.bad = 0;
	snprintf(url, sizeof(url), "%s%s", g.base_url, g.packs[sp->pack]);
	r = net_get(conn, url, sp->start, sp->end - sp->start, chunk_sink, &c, &status, err, errlen);
	fclose(c.out);
	sp->received = (sp->end - sp->start) - c.left;
	if (c.bad) { snprintf(err, errlen, "disk full? writing %s", f->path); return -1; }
	if (r != 0) return -1;
	if (c.left) { snprintf(err, errlen, "download ended early"); return -1; }
	SDL_LockMutex(g.lock);
	if (!f->chunk_done[sp->chunk]) {
		FILE *sf = pl_fopen(side, "ab");
		if (sf) { fprintf(sf, "%d\n", sp->chunk); fclose(sf); }
		f->chunk_done[sp->chunk] = 1;
		last = --f->chunks_left == 0;
	}
	SDL_UnlockMutex(g.lock);
	if (last) {
		char full[1200], hex[65];
		pl_join(full, sizeof(full), g.cfg.install_dir, f->path);
		if (sha256_file(part, hex, NULL) != 0 || strcmp(hex, f->sha)) {
			/* start the file over on the next try */
			pl_remove(part); pl_remove(side);
			SDL_LockMutex(g.lock);
			chunks_prepare(f);
			SDL_UnlockMutex(g.lock);
			snprintf(err, errlen, "checksum mismatch for %s", f->path);
			return -2;
		}
		if (pl_rename(part, full) != 0) { snprintf(err, errlen, "cannot replace %s (is the game still running?)", f->path); return -1; }
		pl_remove(side);
		if (f->x) pl_make_executable(full);
		record_done(f, full);
	}
	return 0;
}

static int run_span(net_conn *conn, span *sp, char *err, size_t errlen)
{
	char url[2048];
	spanctx c;
	int status = 0, r, first = 0;
	/* resume after files a previous try finished */
	while (first < sp->nfiles && g.files[sp->files[first]].done) first++;
	if (first == sp->nfiles) return 0;
	memset(&c, 0, sizeof(c));
	c.sp = sp;
	c.fi = first;
	c.pos = g.files[sp->files[first]].off;
	snprintf(url, sizeof(url), "%s%s", g.base_url, g.packs[sp->pack]);
	r = net_get(conn, url, c.pos, sp->end - c.pos, span_sink, &c, &status, err, errlen);
	if (r == 0 && c.fi < sp->nfiles && !c.bad) { r = -1; snprintf(err, errlen, "download ended early"); }
	if (c.bad) { r = -1; snprintf(err, errlen, "%s", c.err); }
	span_cleanup(&c);
	return r;
}

static int worker_main(void *unused)
{
	net_conn *conn = net_open();
	(void)unused;
	if (!conn) {
		SDL_LockMutex(g.lock);
		g.failed = 1; snprintf(g.fail_msg, sizeof(g.fail_msg), "network setup failed");
		g.active_workers--;
		SDL_UnlockMutex(g.lock);
		return 0;
	}
	for (;;) {
		int si = -1;
		span *sp;
		char err[256];
		uint64_t before;
		SDL_LockMutex(g.lock);
		if (!g.failed && !g.cancel && g.qhead < g.qtail) si = g.queue[g.qhead++];
		SDL_UnlockMutex(g.lock);
		if (si < 0) break;
		sp = &g.spans[si];
		before = sp->received;
		{
			int rr = sp->chunk >= 0 ? run_chunk(conn, sp, err, sizeof(err)) : run_span(conn, sp, err, sizeof(err));
			if (rr == 0) continue;
			if (rr == -2) {
				/* whole file failed its checksum: queue all of its chunks again */
				mfile *f = &g.files[sp->files[0]];
				SDL_LockMutex(g.lock);
				g.failed = 1;
				snprintf(g.fail_msg, sizeof(g.fail_msg), "%s (press Retry)", err);
				(void)f;
				SDL_UnlockMutex(g.lock);
				break;
			}
		}
		if (sp->chunk >= 0) before = 0;
		/* failed: undo the progress of this attempt and requeue */
		SDL_LockMutex(g.lock);
		g.st.bytes_done -= sp->received - before;
		sp->received = before;
		sp->tries++;
		if (g.cancel) { SDL_UnlockMutex(g.lock); break; }
		if (sp->tries >= MAX_TRIES) {
			g.failed = 1;
			snprintf(g.fail_msg, sizeof(g.fail_msg), "%s", err);
			SDL_UnlockMutex(g.lock);
			break;
		}
		if (g.qtail == g.qcap) { g.qcap *= 2; g.queue = (int *)realloc(g.queue, sizeof(int) * (size_t)g.qcap); }
		g.queue[g.qtail++] = si;
		SDL_UnlockMutex(g.lock);
		sleep_ms(500 * sp->tries);
	}
	net_close(conn);
	SDL_LockMutex(g.lock);
	g.active_workers--;
	SDL_UnlockMutex(g.lock);
	return 0;
}

/* ---------- planning ---------- */

static int need_cmp(const void *a, const void *b)
{
	const mfile *x = &g.files[*(const int *)a], *y = &g.files[*(const int *)b];
	if (x->pack != y->pack) return x->pack - y->pack;
	return x->off < y->off ? -1 : x->off > y->off;
}

static void build_spans(void)
{
	int *need = (int *)malloc(sizeof(int) * (size_t)(g.nfiles + 1));
	int n = 0;
	int nchunktasks = 0;
	for (int i = 0; i < g.nfiles; i++) {
		mfile *f = &g.files[i];
		if (!f->need) continue;
		if (!f->z && f->size > CHUNK) {
			if (chunks_prepare(f) == 0) { nchunktasks += f->chunks_left; continue; }
		}
		need[n++] = i;
	}
	qsort(need, (size_t)n, sizeof(int), need_cmp);
	g.spans = (span *)calloc((size_t)(n + nchunktasks + 1), sizeof(span));
	g.nspans = 0;
	for (int i = 0; i < g.nfiles; i++) {
		mfile *f = &g.files[i];
		if (!f->chunk_done) continue;
		for (int c = 0; c < f->nchunks; c++) {
			span *s;
			if (f->chunk_done[c]) continue;
			s = &g.spans[g.nspans++];
			s->pack = f->pack;
			s->start = f->off + (uint64_t)c * CHUNK;
			s->end = s->start + CHUNK;
			if (s->end > f->off + f->len) s->end = f->off + f->len;
			s->files = (int *)malloc(sizeof(int));
			s->files[0] = i;
			s->nfiles = 1;
			s->chunk = c;
		}
	}
	for (int i = 0; i < n; ) {
		span *s = &g.spans[g.nspans++];
		mfile *f = &g.files[need[i]];
		int j = i + 1;
		s->chunk = -1;
		s->pack = f->pack;
		s->start = f->off;
		s->end = f->off + f->len;
		while (j < n) {
			mfile *h = &g.files[need[j]];
			if (h->pack != s->pack || h->off < s->end || h->off - s->end > SPAN_GAP || h->off + h->len - s->start > SPAN_MAX) break;
			s->end = h->off + h->len;
			j++;
		}
		s->nfiles = j - i;
		s->files = (int *)malloc(sizeof(int) * (size_t)s->nfiles);
		memcpy(s->files, need + i, sizeof(int) * (size_t)s->nfiles);
		i = j;
	}
	free(need);
	/* biggest spans first so the tail of the download stays parallel */
	g.qcap = g.nspans * 2 + 8;
	g.queue = (int *)malloc(sizeof(int) * (size_t)g.qcap);
	g.qhead = g.qtail = 0;
	for (int i = 0; i < g.nspans; i++) g.queue[g.qtail++] = i;
	for (int i = 1; i < g.qtail; i++) {
		int v = g.queue[i], k = i - 1;
		uint64_t len = g.spans[v].end - g.spans[v].start;
		while (k >= 0 && g.spans[g.queue[k]].end - g.spans[g.queue[k]].start < len) { g.queue[k + 1] = g.queue[k]; k--; }
		g.queue[k + 1] = v;
	}
}

static void free_plan(void)
{
	for (int i = 0; i < g.nfiles; i++) { free(g.files[i].path); free(g.files[i].chunk_done); }
	free(g.files); g.files = NULL; g.nfiles = 0;
	for (int i = 0; i < g.npacks; i++) free(g.packs[i]);
	free(g.packs); g.packs = NULL; g.npacks = 0;
	for (int i = 0; i < g.nspans; i++) free(g.spans[i].files);
	free(g.spans); g.spans = NULL; g.nspans = 0;
	free(g.queue); g.queue = NULL;
	for (int i = 0; i < g.ndone; i++) free(g.done_entries[i].path);
	free(g.done_entries); g.done_entries = NULL; g.ndone = g.done_cap = 0;
}

/* ---------- self update ---------- */

typedef struct { FILE *f; sha256_ctx sha; } filesink;
static int file_sink(void *ud, const void *d, size_t n)
{
	filesink *s = (filesink *)ud;
	sha256_update(&s->sha, d, n);
	return fwrite(d, 1, n, s->f) != n;
}

/* returns 1 when the launcher was replaced and must restart */
static int self_update(net_conn *conn, const jval *man)
{
	const jval *l = json_get(json_get(man, "launcher"), PL_OS);
	const char *name = json_str(l, "name", NULL), *want = json_str(l, "sha256", NULL);
	char have[65], url[2048], newp[1200], oldp[1200], err[256], got[65];
	uint8_t dg[32];
	filesink fs;
	int status;
	if (!g.cfg.allow_self_update || !l || !name || !is_hex64(want) || !g.cfg.exe_path[0]) return 0;
	if (sha256_file(g.cfg.exe_path, have, NULL) != 0 || !strcmp(have, want)) return 0;
	set_status(US_SELF_UPDATE, "Updating the launcher...");
	snprintf(url, sizeof(url), "%s%s", g.base_url, name);
	snprintf(newp, sizeof(newp), "%s.new", g.cfg.exe_path);
	snprintf(oldp, sizeof(oldp), "%s.old", g.cfg.exe_path);
	fs.f = pl_fopen(newp, "wb");
	if (!fs.f) return 0;
	sha256_init(&fs.sha);
	if (net_get(conn, url, 0, 0, file_sink, &fs, &status, err, sizeof(err)) != 0) { fclose(fs.f); pl_remove(newp); return 0; }
	fclose(fs.f);
	sha256_final(&fs.sha, dg);
	sha256_hex(dg, got);
	if (strcmp(got, want)) { pl_remove(newp); return 0; }
	pl_remove(oldp);
	if (pl_rename(g.cfg.exe_path, oldp) != 0) { pl_remove(newp); return 0; }
	if (pl_rename(newp, g.cfg.exe_path) != 0) { pl_rename(oldp, g.cfg.exe_path); return 0; }
	pl_make_executable(g.cfg.exe_path);
	return 1;
}

/* ---------- main update thread ---------- */

static int parse_manifest(const jval *man, char *err, size_t errlen)
{
	const jval *packs = json_get(man, "packs"), *files = json_get(man, "files");
	int np = 0, nf = 0, i;
	if (!packs || packs->type != J_ARR || !files || files->type != J_ARR) { snprintf(err, errlen, "manifest has no file list"); return -1; }
	for (const jval *p = packs->child; p; p = p->next) np++;
	for (const jval *f = files->child; f; f = f->next) nf++;
	g.packs = (char **)calloc((size_t)np + 1, sizeof(char *));
	g.files = (mfile *)calloc((size_t)nf + 1, sizeof(mfile));
	i = 0;
	for (const jval *p = packs->child; p; p = p->next) {
		const char *n = json_str(p, "name", NULL);
		if (!n || strchr(n, '/') || strstr(n, "..")) { snprintf(err, errlen, "bad pack name in manifest"); return -1; }
		g.packs[i++] = strdup(n);
	}
	g.npacks = np;
	i = 0;
	for (const jval *f = files->child; f; f = f->next) {
		mfile *m = &g.files[i];
		const char *path = json_str(f, "path", NULL), *sha = json_str(f, "sha256", NULL);
		if (!path || !safe_rel_path(path) || !strncmp(path, ".launcher", 9)) { snprintf(err, errlen, "unsafe path in manifest: %s", path ? path : "(none)"); return -1; }
		if (!is_hex64(sha)) { snprintf(err, errlen, "bad checksum in manifest for %s", path); return -1; }
		m->path = strdup(path);
		memcpy(m->sha, sha, 65);
		m->size = (uint64_t)json_num(f, "size", 0);
		m->pack = (int)json_num(f, "pack", -1);
		m->off = (uint64_t)json_num(f, "offset", 0);
		m->len = (uint64_t)json_num(f, "length", 0);
		m->z = (int)json_num(f, "z", 0);
		m->x = (int)json_num(f, "x", 0);
		m->keep = (int)json_num(f, "keep", 0);
		if (m->pack < 0 || m->pack >= np) { snprintf(err, errlen, "bad pack index for %s", path); return -1; }
		if (m->z && (m->size > MAX_COMPRESSED_RAW || m->len > m->size + 1024)) { snprintf(err, errlen, "bad sizes for %s", path); return -1; }
		if (!m->z && m->len != m->size) { snprintf(err, errlen, "bad sizes for %s", path); return -1; }
		i++;
	}
	g.nfiles = nf;
	return 0;
}

static void apply_run_override(const jval *man)
{
	const jval *r = json_get(json_get(man, "run"), PL_OS);
	const jval *args = json_get(r, "args");
	const char *exe = json_str(r, "exe", NULL);
	if (!exe || !safe_rel_path(exe)) return;
	SDL_LockMutex(g.lock);
	snprintf(g.st.run_exe, sizeof(g.st.run_exe), "%s", exe);
	g.st.run_argc = 0;
	if (args && args->type == J_ARR)
		for (const jval *a = args->child; a && g.st.run_argc < 16; a = a->next)
			if (a->type == J_STR) snprintf(g.st.run_args[g.st.run_argc++], 256, "%s", a->str);
	SDL_UnlockMutex(g.lock);
}

static int update_thread(void *unused)
{
	net_conn *conn;
	membuf mb;
	char err[512], url[1200], local_ver[128];
	jval *man = NULL;
	sentry *old = NULL;
	int nold = 0, status = 0, r = -1;
	uint64_t total = 0;
	int nneed = 0;
	(void)unused;

	set_status(US_CHECKING, "Checking for updates...");
	conn = net_open();
	if (!conn) { set_status(g.st.installed ? US_OFFLINE : US_ERROR, "Network is not available"); goto done; }

	/* the manifest is replaced last during a publish; retry briefly if it is missing */
	memset(&mb, 0, sizeof(mb));
	mb.limit = 64u << 20;
	snprintf(url, sizeof(url), "%s%c%ld", g.cfg.manifest_url, strchr(g.cfg.manifest_url, '?') ? '&' : '?', (long)time(NULL));
	for (int t = 0; t < 3; t++) {
		mb.len = 0;
		r = net_get(conn, url, 0, 0, mem_sink, &mb, &status, err, sizeof(err));
		if (r == 0 || g.cancel) break;
		sleep_ms(1500);
	}
	if (r != 0) {
		free(mb.data);
		if (g.st.installed) set_status(US_OFFLINE, "Could not reach the update server (%s). You can still play the installed version.", err);
		else set_status(US_ERROR, "Could not reach the update server (%s). Check your internet connection and try again.", err);
		goto done;
	}
	man = json_parse(mb.data, err, sizeof(err));
	free(mb.data);
	if (!man) { set_status(g.st.installed ? US_OFFLINE : US_ERROR, "The update server sent a broken file list (%s).", err); goto done; }
	url_dir(g.cfg.manifest_url, g.base_url, sizeof(g.base_url));
	if (json_str(man, "base_url", NULL) && json_str(man, "base_url", "")[0]) snprintf(g.base_url, sizeof(g.base_url), "%s", json_str(man, "base_url", ""));

	SDL_LockMutex(g.lock);
	snprintf(g.st.remote_version, sizeof(g.st.remote_version), "%s", json_str(man, "version", "?"));
	snprintf(g.st.notes, sizeof(g.st.notes), "%s", json_str(man, "notes", ""));
	SDL_UnlockMutex(g.lock);
	apply_run_override(man);

	if (self_update(conn, man)) { set_status(US_RESTART, "Launcher updated, restarting..."); goto done; }

	if (parse_manifest(man, err, sizeof(err)) != 0) { set_status(g.st.installed ? US_OFFLINE : US_ERROR, "%s", err); goto done; }

	/* compare against the local install */
	set_status(US_SCANNING, "Checking installed files...");
	old = state_load(&nold, local_ver, sizeof(local_ver), 0);
	SDL_LockMutex(g.lock);
	g.st.files_total = g.nfiles;
	g.st.files_done = 0;
	SDL_UnlockMutex(g.lock);
	for (int i = 0; i < g.nfiles && !g.cancel; i++) {
		mfile *f = &g.files[i];
		char full[1200], hex[65];
		uint64_t size; int64_t mt;
		sentry key, *hit;
		pl_join(full, sizeof(full), g.cfg.install_dir, f->path);
		SDL_LockMutex(g.lock);
		g.st.files_done = i;
		SDL_UnlockMutex(g.lock);
		if (pl_stat(full, &size, &mt) != 0) { f->need = 1; continue; }
		if (f->keep) { f->need = 0; f->done = 1; continue; }
		key.path = f->path;
		hit = old ? (sentry *)bsearch(&key, old, (size_t)nold, sizeof(sentry), sentry_cmp) : NULL;
		if (!g.cfg.verify_all && hit && hit->size == size && hit->mtime == mt) {
			f->need = strcmp(hit->sha, f->sha) != 0;
		} else {
			f->need = size != f->size || sha256_file(full, hex, NULL) != 0 || strcmp(hex, f->sha) != 0;
		}
		if (!f->need) f->done = 1;
	}
	/* empty files need no download */
	for (int i = 0; i < g.nfiles; i++) {
		mfile *f = &g.files[i];
		char full[1200];
		FILE *o;
		if (!f->need || f->size != 0) continue;
		pl_join(full, sizeof(full), g.cfg.install_dir, f->path);
		pl_mkparents(full);
		if ((o = pl_fopen(full, "wb")) != NULL) { fclose(o); f->need = 0; f->done = 1; }
	}
	if (g.cancel) goto done;

	/* remove files we installed earlier that the new build no longer has */
	for (int i = 0; i < nold; i++) {
		int found = 0;
		for (int j = 0; j < g.nfiles && !found; j++) found = !strcmp(old[i].path, g.files[j].path);
		if (!found) {
			char full[1200];
			pl_join(full, sizeof(full), g.cfg.install_dir, old[i].path);
			pl_remove(full);
		}
	}

	for (int i = 0; i < g.nfiles; i++) if (g.files[i].need) nneed++;
	build_spans();
	for (int i = 0; i < g.nspans; i++) total += g.spans[i].end - g.spans[i].start;
	SDL_LockMutex(g.lock);
	g.st.bytes_total = total;
	g.st.bytes_done = 0;
	g.st.files_total = nneed;
	g.st.files_done = 0;
	SDL_UnlockMutex(g.lock);

	if (nneed > 0) {
		int nw = g.cfg.connections < 1 ? 1 : g.cfg.connections > 16 ? 16 : g.cfg.connections;
		SDL_Thread *th[16];
		if (nw > g.nspans) nw = g.nspans;
		set_status(US_DOWNLOADING, "Downloading update...");
		g.failed = 0;
		g.active_workers = nw;
		for (int i = 0; i < nw; i++) th[i] = SDL_CreateThread(worker_main, "dl", NULL);
		for (int i = 0; i < nw; i++) SDL_WaitThread(th[i], NULL);
	}

	/* build the new state: unchanged entries + freshly written ones */
	{
		int cap = g.nfiles + 1, n = 0;
		sentry *ns = (sentry *)calloc((size_t)cap, sizeof(sentry));
		for (int i = 0; i < g.nfiles; i++) {
			mfile *f = &g.files[i];
			char full[1200];
			uint64_t size; int64_t mt;
			if (!f->done) continue;
			pl_join(full, sizeof(full), g.cfg.install_dir, f->path);
			if (pl_stat(full, &size, &mt) != 0) continue;
			ns[n].path = strdup(f->path);
			memcpy(ns[n].sha, f->sha, 65);
			ns[n].size = size;
			ns[n].mtime = mt;
			n++;
		}
		qsort(ns, (size_t)n, sizeof(sentry), sentry_cmp);
		if (g.failed || g.cancel) {
			/* keep progress so the next try resumes, but don't claim the new version */
			state_save(local_ver, ns, n);
			state_free(ns, n);
			if (g.cancel) set_status(g.st.installed ? US_OFFLINE : US_ERROR, "Update cancelled.");
			else set_status(US_ERROR, "Update failed: %s. Press Retry to continue where it stopped.", g.fail_msg);
			SDL_LockMutex(g.lock);
			g.st.installed = 0; /* files are half old, half new */
			SDL_UnlockMutex(g.lock);
			goto done;
		}
		state_save(g.st.remote_version, ns, n);
		state_free(ns, n);
	}
	SDL_LockMutex(g.lock);
	snprintf(g.st.local_version, sizeof(g.st.local_version), "%s", g.st.remote_version);
	g.st.installed = 1;
	SDL_UnlockMutex(g.lock);
	if (nneed) set_status(US_READY, "Update installed. Ready to play.");
	else set_status(US_READY, "Up to date. Ready to play.");

done:
	json_free(man);
	state_free(old, nold);
	free_plan();
	net_close(conn);
	SDL_LockMutex(g.lock);
	g.busy = 0;
	SDL_UnlockMutex(g.lock);
	return 0;
}

void update_start(const update_config *cfg)
{
	if (!g.lock) g.lock = SDL_CreateMutex();
	SDL_LockMutex(g.lock);
	if (g.busy) { SDL_UnlockMutex(g.lock); return; }
	g.busy = 1;
	g.cancel = 0;
	g.cfg = *cfg;
	g.st.bytes_done = g.st.bytes_total = 0;
	g.st.files_done = g.st.files_total = 0;
	SDL_UnlockMutex(g.lock);
	if (g.thread) SDL_WaitThread(g.thread, NULL);
	g.thread = SDL_CreateThread(update_thread, "update", NULL);
}

void update_snapshot(update_status *out)
{
	SDL_LockMutex(g.lock);
	*out = g.st;
	SDL_UnlockMutex(g.lock);
}

void update_cancel(void) { g.cancel = 1; }

int update_busy(void)
{
	int b;
	SDL_LockMutex(g.lock);
	b = g.busy;
	SDL_UnlockMutex(g.lock);
	return b;
}
