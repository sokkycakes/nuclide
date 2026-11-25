#include "json.h"
#include "platform.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { const char *p; char *err; size_t errlen; int depth; } jp;

static void ws(jp *s) { while (*s->p == ' ' || *s->p == '\t' || *s->p == '\n' || *s->p == '\r') s->p++; }

static jval *mk(jtype t)
{
	jval *v = (jval *)calloc(1, sizeof(jval));
	if (v) v->type = t;
	return v;
}

static int fail(jp *s, const char *msg)
{
	if (s->err && !s->err[0]) snprintf(s->err, s->errlen, "%s", msg);
	return -1;
}

static void put_utf8(char **o, unsigned cp)
{
	char *d = *o;
	if (cp < 0x80) *d++ = (char)cp;
	else if (cp < 0x800) { *d++ = (char)(0xC0 | (cp >> 6)); *d++ = (char)(0x80 | (cp & 63)); }
	else if (cp < 0x10000) { *d++ = (char)(0xE0 | (cp >> 12)); *d++ = (char)(0x80 | ((cp >> 6) & 63)); *d++ = (char)(0x80 | (cp & 63)); }
	else { *d++ = (char)(0xF0 | (cp >> 18)); *d++ = (char)(0x80 | ((cp >> 12) & 63)); *d++ = (char)(0x80 | ((cp >> 6) & 63)); *d++ = (char)(0x80 | (cp & 63)); }
	*o = d;
}

static int hex4(const char *p, unsigned *out)
{
	unsigned v = 0;
	for (int i = 0; i < 4; i++) {
		char c = p[i];
		v <<= 4;
		if (c >= '0' && c <= '9') v |= (unsigned)(c - '0');
		else if (c >= 'a' && c <= 'f') v |= (unsigned)(c - 'a' + 10);
		else if (c >= 'A' && c <= 'F') v |= (unsigned)(c - 'A' + 10);
		else return -1;
	}
	*out = v;
	return 0;
}

static char *pstr(jp *s)
{
	const char *start;
	size_t cap;
	char *out, *o;
	if (*s->p != '"') { fail(s, "expected string"); return NULL; }
	start = ++s->p;
	while (*s->p && *s->p != '"') { if (*s->p == '\\' && s->p[1]) s->p++; s->p++; }
	if (*s->p != '"') { fail(s, "unterminated string"); return NULL; }
	cap = (size_t)(s->p - start) + 1;
	out = o = (char *)malloc(cap * 2 + 4);
	if (!out) return NULL;
	for (const char *q = start; q < s->p; q++) {
		if (*q != '\\') { *o++ = *q; continue; }
		q++;
		switch (*q) {
		case 'n': *o++ = '\n'; break;
		case 't': *o++ = '\t'; break;
		case 'r': *o++ = '\r'; break;
		case 'b': *o++ = '\b'; break;
		case 'f': *o++ = '\f'; break;
		case 'u': {
			unsigned cp;
			if (hex4(q + 1, &cp)) { free(out); fail(s, "bad \\u escape"); return NULL; }
			q += 4;
			if (cp >= 0xD800 && cp < 0xDC00 && q[1] == '\\' && q[2] == 'u') {
				unsigned lo;
				if (!hex4(q + 3, &lo) && lo >= 0xDC00 && lo < 0xE000) {
					cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
					q += 6;
				}
			}
			put_utf8(&o, cp);
			break;
		}
		default: *o++ = *q; break;
		}
	}
	*o = 0;
	s->p++;
	return out;
}

static jval *pval(jp *s);

static jval *pcontainer(jp *s, int obj)
{
	jval *v = mk(obj ? J_OBJ : J_ARR), **tail;
	char close = obj ? '}' : ']';
	if (!v) return NULL;
	if (++s->depth > 64) { fail(s, "too deep"); free(v); return NULL; }
	tail = &v->child;
	s->p++;
	ws(s);
	if (*s->p == close) { s->p++; s->depth--; return v; }
	for (;;) {
		char *key = NULL;
		jval *c;
		ws(s);
		if (obj) {
			key = pstr(s);
			if (!key) { json_free(v); return NULL; }
			ws(s);
			if (*s->p != ':') { free(key); json_free(v); fail(s, "expected ':'"); return NULL; }
			s->p++;
		}
		c = pval(s);
		if (!c) { free(key); json_free(v); return NULL; }
		c->key = key;
		*tail = c;
		tail = &c->next;
		ws(s);
		if (*s->p == ',') { s->p++; continue; }
		if (*s->p == close) { s->p++; break; }
		json_free(v);
		fail(s, obj ? "expected ',' or '}'" : "expected ',' or ']'");
		return NULL;
	}
	s->depth--;
	return v;
}

static jval *pval(jp *s)
{
	jval *v;
	ws(s);
	switch (*s->p) {
	case '{': return pcontainer(s, 1);
	case '[': return pcontainer(s, 0);
	case '"': {
		char *str = pstr(s);
		if (!str) return NULL;
		v = mk(J_STR);
		if (!v) { free(str); return NULL; }
		v->str = str;
		return v;
	}
	case 't': if (!strncmp(s->p, "true", 4)) { s->p += 4; v = mk(J_BOOL); if (v) v->boolean = 1; return v; } break;
	case 'f': if (!strncmp(s->p, "false", 5)) { s->p += 5; return mk(J_BOOL); } break;
	case 'n': if (!strncmp(s->p, "null", 4)) { s->p += 4; return mk(J_NULL); } break;
	default:
		if (*s->p == '-' || (*s->p >= '0' && *s->p <= '9')) {
			char *end;
			double d = strtod(s->p, &end);
			if (end == s->p) break;
			s->p = end;
			v = mk(J_NUM);
			if (v) v->num = d;
			return v;
		}
	}
	fail(s, "unexpected character");
	return NULL;
}

jval *json_parse(const char *text, char *err, size_t errlen)
{
	jp s;
	jval *v;
	s.p = text; s.err = err; s.errlen = errlen; s.depth = 0;
	if (err && errlen) err[0] = 0;
	if ((unsigned char)s.p[0] == 0xEF && (unsigned char)s.p[1] == 0xBB && (unsigned char)s.p[2] == 0xBF) s.p += 3;
	v = pval(&s);
	if (v) {
		ws(&s);
		if (*s.p) { json_free(v); fail(&s, "trailing data"); return NULL; }
	}
	return v;
}

void json_free(jval *v)
{
	while (v) {
		jval *n = v->next;
		json_free(v->child);
		free(v->str);
		free(v->key);
		free(v);
		v = n;
	}
}

jval *json_get(const jval *obj, const char *key)
{
	if (!obj || obj->type != J_OBJ) return NULL;
	for (jval *c = obj->child; c; c = c->next)
		if (c->key && !strcmp(c->key, key)) return c;
	return NULL;
}

const char *json_str(const jval *obj, const char *key, const char *def)
{
	jval *v = json_get(obj, key);
	return (v && v->type == J_STR) ? v->str : def;
}

double json_num(const jval *obj, const char *key, double def)
{
	jval *v = json_get(obj, key);
	return (v && v->type == J_NUM) ? v->num : def;
}

int json_bool(const jval *obj, const char *key, int def)
{
	jval *v = json_get(obj, key);
	return (v && v->type == J_BOOL) ? v->boolean : def;
}

char *read_text_file(const char *path, size_t *len)
{
	FILE *f = pl_fopen(path, "rb");
	char *buf;
	long n;
	if (!f) return NULL;
	fseek(f, 0, SEEK_END);
	n = ftell(f);
	fseek(f, 0, SEEK_SET);
	if (n < 0) { fclose(f); return NULL; }
	buf = (char *)malloc((size_t)n + 1);
	if (!buf) { fclose(f); return NULL; }
	if (fread(buf, 1, (size_t)n, f) != (size_t)n) { fclose(f); free(buf); return NULL; }
	buf[n] = 0;
	fclose(f);
	if (len) *len = (size_t)n;
	return buf;
}
