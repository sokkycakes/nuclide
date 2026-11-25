/* HTTP(S) GET using what the OS already has: WinHTTP on Windows, the system
 * libcurl (loaded at run time) on Linux. Redirects are followed, which matters
 * for GitHub release assets (github.com -> objects.githubusercontent.com). */
#ifndef PL_NET_H
#define PL_NET_H

#include <stddef.h>
#include <stdint.h>

/* return nonzero to abort the transfer */
typedef int (*net_sink)(void *ud, const void *data, size_t len);

typedef struct net_conn net_conn;

int net_global_init(char *err, size_t errlen);
net_conn *net_open(void);
void net_close(net_conn *c);
/* range_len == 0 means the whole resource. Returns 0 on HTTP 200/206 with the
 * body passed to sink, otherwise -1 with *status set (0 when no response). */
int net_get(net_conn *c, const char *url, uint64_t range_start, uint64_t range_len,
            net_sink sink, void *ud, int *status, char *err, size_t errlen);

#endif
