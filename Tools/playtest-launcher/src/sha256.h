#ifndef PL_SHA256_H
#define PL_SHA256_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
	uint32_t state[8];
	uint64_t bitlen;
	uint8_t buf[64];
	size_t buflen;
} sha256_ctx;

void sha256_init(sha256_ctx *c);
void sha256_update(sha256_ctx *c, const void *data, size_t len);
void sha256_final(sha256_ctx *c, uint8_t out[32]);
/* out must hold 65 bytes */
void sha256_hex(const uint8_t digest[32], char *out);
/* hashes a whole file; returns 0 on success */
int sha256_file(const char *path, char hex_out[65], uint64_t *size_out);

#endif
