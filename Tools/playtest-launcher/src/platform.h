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
/* returns 0 when the path exists as a regular file */
int pl_stat(const char *path, uint64_t *size, int64_t *mtime);
int pl_exists(const char *path);
/* full path of the running executable */
int pl_exe_path(char *out, size_t cap);
/* starts a program detached from us; argv is NULL-terminated, argv[0] is the program */
int pl_spawn(const char *exe, const char *const *argv, const char *cwd);
void pl_make_executable(const char *path);
void pl_open_folder(const char *path);
/* strips the last path component in place */
void pl_dirname(char *path);
void pl_join(char *out, size_t cap, const char *a, const char *b);

#endif
