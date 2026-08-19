#ifndef APPLY_PATH_H
#define APPLY_PATH_H

#include <stddef.h>
#include <wchar.h>

int updater_validate_file_path(char *path, size_t path_cap);
int updater_resolve_dest(const wchar_t *install_root, const wchar_t *game_dir,
    const wchar_t *file_path_w, wchar_t *dest, size_t dest_cap);
int updater_replace_file(const wchar_t *partial, const wchar_t *dest,
    const wchar_t *self_exe);

#endif
