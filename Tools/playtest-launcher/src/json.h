/* Minimal JSON DOM: enough for manifests and config files. */
#ifndef PL_JSON_H
#define PL_JSON_H

#include <stddef.h>

typedef enum { J_NULL, J_BOOL, J_NUM, J_STR, J_ARR, J_OBJ } jtype;

typedef struct jval {
	jtype type;
	double num;
	int boolean;
	char *str;           /* J_STR value, UTF-8 */
	char *key;           /* set when the value is an object member */
	struct jval *child;  /* first element/member */
	struct jval *next;   /* next sibling */
} jval;

jval *json_parse(const char *text, char *err, size_t errlen);
void json_free(jval *v);
jval *json_get(const jval *obj, const char *key);
const char *json_str(const jval *obj, const char *key, const char *def);
double json_num(const jval *obj, const char *key, double def);
int json_bool(const jval *obj, const char *key, int def);
/* reads a whole file into a NUL-terminated buffer */
char *read_text_file(const char *path, size_t *len);

#endif
