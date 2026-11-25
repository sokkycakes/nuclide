/* Small OS layer. All paths are UTF-8 with '/' separators accepted everywhere. */
#ifndef PL_PLATFORM_H
#define PL_PLATFORM_H

#include <stdint.h>
#include <stdio.h>

#ifdef _WIN32
#define PL_OS "windows"
#else
#define PL_OS "linux"
#endif

FILE *pl_fopen(const char *path, const char *mode);
/* creates every missing directory in path (path itself is a directory) */
int pl_mkdirs(const char *dir);
/* creates the parent directories of a file path */
int pl_mkparents(const char *file);
/* atomically replaces dst with src where the OS allows it */
int pl_rename(const char *src, const char *dst);
int pl_remove(const char *path);
/* removes now-empty folders from dir up to (not including) stop */
void pl_prune_dirs(const char *file, const char *stop);
/* returns 0 when the path exists as a regular file */
int pl_stat(const char *path, uint64_t *size, int64_t *mtime);
int pl_exists(const char *path);
/* full path of the running executable */
int pl_exe_path(char *out, size_t cap);
/* starts a program detached from us; argv is NULL-terminated, argv[0] is the program */
int pl_spawn(const char *exe, const char *const *argv, const char *cwd);
/* Runs the game so the process Steam started keeps owning it (non-Steam
 * game shortcuts, Steam Deck Game Mode). POSIX: replaces this process with
 * the game (only returns on failure). Windows/Proton: starts it, waits for
 * it to exit, returns its exit code or -1 on failure. */
int pl_run_attached(const char *exe, const char *const *argv, const char *cwd);
/* nonzero when started by Steam or inside SteamOS Game Mode (gamescope) */
int pl_under_steam(void);
int pl_is_gamescope(void);
void pl_make_executable(const char *path);
void pl_open_folder(const char *path);
/* strips the last path component in place */
void pl_dirname(char *path);
void pl_join(char *out, size_t cap, const char *a, const char *b);

#endif
