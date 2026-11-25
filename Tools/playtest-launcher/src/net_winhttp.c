#ifdef _WIN32
#include "net.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winhttp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY
#define WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY 4
#endif
#ifndef WINHTTP_OPTION_ENABLE_HTTP_PROTOCOL
#define WINHTTP_OPTION_ENABLE_HTTP_PROTOCOL 133
#endif

struct net_conn { HINTERNET session; };

int net_global_init(char *err, size_t errlen) { (void)err; (void)errlen; return 0; }

net_conn *net_open(void)
{
	net_conn *c = (net_conn *)calloc(1, sizeof(*c));
	DWORD proto = 1; /* HTTP/2 when the OS has it */
	if (!c) return NULL;
	c->session = WinHttpOpen(L"PlaytestLauncher/1.0", WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
	                         WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
	if (!c->session)
		c->session = WinHttpOpen(L"PlaytestLauncher/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
		                         WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
	if (!c->session) { free(c); return NULL; }
	WinHttpSetOption(c->session, WINHTTP_OPTION_ENABLE_HTTP_PROTOCOL, &proto, sizeof(proto));
	WinHttpSetTimeouts(c->session, 15000, 15000, 30000, 60000);
	return c;
}

void net_close(net_conn *c)
{
	if (!c) return;
	if (c->session) WinHttpCloseHandle(c->session);
	free(c);
}

static int one_request(net_conn *c, const wchar_t *wurl, uint64_t rs, uint64_t rl,
                       net_sink sink, void *ud, int *status, wchar_t *redirect, size_t redirect_cap,
                       char *err, size_t errlen)
{
	URL_COMPONENTS uc;
	wchar_t host[512], path[8192];
	HINTERNET conn = NULL, req = NULL;
	DWORD flags, code = 0, sz = sizeof(code), redirpolicy = WINHTTP_OPTION_REDIRECT_POLICY_NEVER;
	int ret = -1;
	char *buf = NULL;

	memset(&uc, 0, sizeof(uc));
	uc.dwStructSize = sizeof(uc);
	uc.lpszHostName = host; uc.dwHostNameLength = 512;
	uc.lpszUrlPath = path; uc.dwUrlPathLength = 8192;
	uc.dwSchemeLength = (DWORD)-1;
	uc.dwExtraInfoLength = (DWORD)-1;
	if (!WinHttpCrackUrl(wurl, 0, 0, &uc)) { snprintf(err, errlen, "bad URL"); return -1; }
	if (uc.lpszExtraInfo && uc.dwExtraInfoLength) {
		size_t pl = wcslen(path);
		if (pl + uc.dwExtraInfoLength < 8192) {
			wcsncat(path, uc.lpszExtraInfo, uc.dwExtraInfoLength);
		}
	}
	conn = WinHttpConnect(c->session, host, uc.nPort, 0);
	if (!conn) { snprintf(err, errlen, "connect failed (%lu)", GetLastError()); goto out; }
	flags = (uc.nScheme == INTERNET_SCHEME_HTTPS) ? WINHTTP_FLAG_SECURE : 0;
	req = WinHttpOpenRequest(conn, L"GET", path, NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, flags);
	if (!req) { snprintf(err, errlen, "request failed (%lu)", GetLastError()); goto out; }
	WinHttpSetOption(req, WINHTTP_OPTION_REDIRECT_POLICY, &redirpolicy, sizeof(redirpolicy));
	if (rl) {
		wchar_t hdr[128];
		swprintf(hdr, 128, L"Range: bytes=%llu-%llu", (unsigned long long)rs, (unsigned long long)(rs + rl - 1));
		WinHttpAddRequestHeaders(req, hdr, (DWORD)-1, WINHTTP_ADDREQ_FLAG_ADD);
	}
	if (!WinHttpSendRequest(req, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0) ||
	    !WinHttpReceiveResponse(req, NULL)) {
		snprintf(err, errlen, "no response (%lu)", GetLastError());
		goto out;
	}
	WinHttpQueryHeaders(req, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, WINHTTP_HEADER_NAME_BY_INDEX, &code, &sz, WINHTTP_NO_HEADER_INDEX);
	*status = (int)code;
	if (code == 301 || code == 302 || code == 303 || code == 307 || code == 308) {
		DWORD len = (DWORD)(redirect_cap * sizeof(wchar_t));
		if (WinHttpQueryHeaders(req, WINHTTP_QUERY_LOCATION, WINHTTP_HEADER_NAME_BY_INDEX, redirect, &len, WINHTTP_NO_HEADER_INDEX))
			ret = 1;
		else
			snprintf(err, errlen, "redirect without location");
		goto out;
	}
	if (code != 200 && code != 206) { snprintf(err, errlen, "HTTP %lu", code); goto out; }
	if (rl && code == 200 && rs) {
		/* server ignored Range; we cannot use a full body here */
		snprintf(err, errlen, "server ignored range request");
		goto out;
	}
	buf = (char *)malloc(256 * 1024);
	if (!buf) goto out;
	for (;;) {
		DWORD got = 0;
		if (!WinHttpReadData(req, buf, 256 * 1024, &got)) { snprintf(err, errlen, "read failed (%lu)", GetLastError()); goto out; }
		if (got == 0) break;
		if (sink(ud, buf, got)) { snprintf(err, errlen, "cancelled"); goto out; }
	}
	ret = 0;
out:
	free(buf);
	if (req) WinHttpCloseHandle(req);
	if (conn) WinHttpCloseHandle(conn);
	return ret;
}

int net_get(net_conn *c, const char *url, uint64_t rs, uint64_t rl,
            net_sink sink, void *ud, int *status, char *err, size_t errlen)
{
	wchar_t cur[8192], next[8192];
	int hops;
	*status = 0;
	err[0] = 0;
	if (!MultiByteToWideChar(CP_UTF8, 0, url, -1, cur, 8192)) return -1;
	for (hops = 0; hops < 8; hops++) {
		int r = one_request(c, cur, rs, rl, sink, ud, status, next, 8192, err, errlen);
		if (r != 1) return r;
		if (wcsncmp(next, L"http", 4) != 0) {
			/* relative redirect: keep scheme://host */
			wchar_t *p = wcsstr(cur, L"://");
			wchar_t *slash = p ? wcschr(p + 3, L'/') : NULL;
			if (slash) *slash = 0;
			wcsncat(cur, next, 8192 - wcslen(cur) - 1);
		} else {
			wcscpy(cur, next);
		}
	}
	snprintf(err, errlen, "too many redirects");
	return -1;
}
#endif
