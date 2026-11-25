#ifndef _WIN32
/* libcurl is loaded with dlopen so the launcher starts (and can say what is
 * wrong) even on a system without it. Every desktop Linux ships libcurl. */
#include "net.h"

#include <curl/curl.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static CURLcode (*p_global_init)(long);
static CURL *(*p_easy_init)(void);
static CURLcode (*p_easy_setopt)(CURL *, CURLoption, ...);
static CURLcode (*p_easy_perform)(CURL *);
static CURLcode (*p_easy_getinfo)(CURL *, CURLINFO, ...);
static void (*p_easy_cleanup)(CURL *);
static void (*p_easy_reset)(CURL *);
static const char *(*p_easy_strerror)(CURLcode);

struct net_conn { CURL *h; };

int net_global_init(char *err, size_t errlen)
{
	static const char *names[] = { "libcurl.so.4", "libcurl-gnutls.so.4", "libcurl-nss.so.4", "libcurl.so", NULL };
	void *lib = NULL;
	for (int i = 0; names[i] && !lib; i++) lib = dlopen(names[i], RTLD_NOW);
	if (!lib) { snprintf(err, errlen, "libcurl was not found on this system"); return -1; }
#define LOAD(var, name) *(void **)(&var) = dlsym(lib, name); if (!var) { snprintf(err, errlen, "libcurl lacks %s", name); return -1; }
	LOAD(p_global_init, "curl_global_init");
	LOAD(p_easy_init, "curl_easy_init");
	LOAD(p_easy_setopt, "curl_easy_setopt");
	LOAD(p_easy_perform, "curl_easy_perform");
	LOAD(p_easy_getinfo, "curl_easy_getinfo");
	LOAD(p_easy_cleanup, "curl_easy_cleanup");
	LOAD(p_easy_reset, "curl_easy_reset");
	LOAD(p_easy_strerror, "curl_easy_strerror");
#undef LOAD
	p_global_init(CURL_GLOBAL_DEFAULT);
	return 0;
}

net_conn *net_open(void)
{
	net_conn *c = (net_conn *)calloc(1, sizeof(*c));
	if (!c) return NULL;
	c->h = p_easy_init();
	if (!c->h) { free(c); return NULL; }
	return c;
}

void net_close(net_conn *c)
{
	if (!c) return;
	p_easy_cleanup(c->h);
	free(c);
}

typedef struct { net_sink sink; void *ud; int aborted; } wctx;

static size_t on_write(char *data, size_t sz, size_t n, void *ud)
{
	wctx *w = (wctx *)ud;
	if (w->sink(w->ud, data, sz * n)) { w->aborted = 1; return 0; }
	return sz * n;
}

int net_get(net_conn *c, const char *url, uint64_t rs, uint64_t rl,
            net_sink sink, void *ud, int *status, char *err, size_t errlen)
{
	char range[64], ebuf[CURL_ERROR_SIZE];
	wctx w;
	long code = 0;
	CURLcode r;
	w.sink = sink; w.ud = ud; w.aborted = 0;
	*status = 0;
	err[0] = 0;
	ebuf[0] = 0;
	p_easy_reset(c->h); /* keeps the connection cache */
	p_easy_setopt(c->h, CURLOPT_URL, url);
	p_easy_setopt(c->h, CURLOPT_FOLLOWLOCATION, 1L);
	p_easy_setopt(c->h, CURLOPT_FAILONERROR, 1L);
	p_easy_setopt(c->h, CURLOPT_MAXREDIRS, 8L);
	p_easy_setopt(c->h, CURLOPT_USERAGENT, "PlaytestLauncher/1.0");
	p_easy_setopt(c->h, CURLOPT_NOSIGNAL, 1L);
	p_easy_setopt(c->h, CURLOPT_CONNECTTIMEOUT, 15L);
	p_easy_setopt(c->h, CURLOPT_LOW_SPEED_LIMIT, 1L);
	p_easy_setopt(c->h, CURLOPT_LOW_SPEED_TIME, 60L);
	p_easy_setopt(c->h, CURLOPT_ERRORBUFFER, ebuf);
	p_easy_setopt(c->h, CURLOPT_WRITEFUNCTION, on_write);
	p_easy_setopt(c->h, CURLOPT_WRITEDATA, &w);
	if (rl) {
		snprintf(range, sizeof(range), "%llu-%llu", (unsigned long long)rs, (unsigned long long)(rs + rl - 1));
		p_easy_setopt(c->h, CURLOPT_RANGE, range);
	}
	r = p_easy_perform(c->h);
	p_easy_getinfo(c->h, CURLINFO_RESPONSE_CODE, &code);
	*status = (int)code;
	if (w.aborted) { snprintf(err, errlen, "cancelled or bad data"); return -1; }
	if (r != CURLE_OK) { snprintf(err, errlen, "%s", ebuf[0] ? ebuf : p_easy_strerror(r)); return -1; }
	if (code != 200 && code != 206) { snprintf(err, errlen, "HTTP %ld", code); return -1; }
	if (rl && rs && code == 200) { snprintf(err, errlen, "server ignored range request"); return -1; }
	return 0;
}
#endif
