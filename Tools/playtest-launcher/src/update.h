/* Update engine: fetches manifest.json, works out which files differ from the
 * local install, downloads only those (byte ranges out of release packs, in
 * parallel), verifies SHA-256 and swaps them in. Runs on a background thread;
 * the UI reads progress through update_snapshot(). */
#ifndef PL_UPDATE_H
#define PL_UPDATE_H

#include <stdint.h>

typedef enum {
	US_IDLE,
	US_CHECKING,      /* fetching manifest */
	US_SELF_UPDATE,   /* replacing the launcher itself */
	US_RESTART,       /* launcher was replaced; UI should relaunch */
	US_SCANNING,      /* hashing local files */
	US_DOWNLOADING,
	US_READY,         /* install matches manifest */
	US_OFFLINE,       /* manifest unreachable, local install usable */
	US_ERROR          /* nothing playable */
} update_state;

typedef struct {
	char title[128];
	char manifest_url[1024];
	char install_dir[1024];   /* absolute */
	char exe_path[1024];      /* the running launcher */
	char run_exe[256];        /* relative to install_dir */
	char run_args[16][256];
	int run_argc;
	int connections;
	int allow_self_update;
	int verify_all;           /* ignore cached hashes */
} update_config;

typedef struct {
	update_state state;
	char message[512];
	char local_version[128];
	char remote_version[128];
	char notes[16384];
	uint64_t bytes_done, bytes_total;
	int files_done, files_total;
	int installed;            /* a complete install exists on disk */
	/* launch command, possibly overridden by the manifest */
	char run_exe[256];
	char run_args[16][256];
	int run_argc;
} update_status;

void update_start(const update_config *cfg);
void update_snapshot(update_status *out);
void update_cancel(void);
int update_busy(void);
/* reads install_dir/.launcher/state.txt to learn the installed version */
void update_read_local(const update_config *cfg);
const char *update_state_name(update_state s);

#endif
