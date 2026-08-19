#include <string.h>
#include <windows.h>
#include "apply_path.h"

int updater_validate_file_path(char *path, size_t path_cap)
{
    size_t i;

    (void)path_cap;

    if (strstr(path, ".."))
        return 0;
    if (strchr(path, '\\'))
        return 0;
    if (path[0] == '/' || path[0] == '\0')
        return 0;
    if (((path[0] >= 'A' && path[0] <= 'Z') || (path[0] >= 'a' && path[0] <= 'z'))
        && path[1] == ':')
        return 0;

    for (i = 0; path[i]; i++) {
        if (path[i] == '/')
            path[i] = '\\';
    }
    return 1;
}

int updater_resolve_dest(const wchar_t *install_root, const wchar_t *game_dir,
    const wchar_t *file_path_w, wchar_t *dest, size_t dest_cap)
{
    const wchar_t *rest;

    if (_wcsnicmp(file_path_w, L"launcher\\", 9) == 0) {
        rest = file_path_w + 9;
        if (!rest[0])
            return 0;
        if (_snwprintf_s(dest, dest_cap, _TRUNCATE, L"%s\\%s", install_root, rest) < 0)
            return 0;
        return 1;
    }

    if (_snwprintf_s(dest, dest_cap, _TRUNCATE, L"%s\\%s", game_dir, file_path_w) < 0)
        return 0;
    return 1;
}

int updater_replace_file(const wchar_t *partial, const wchar_t *dest,
    const wchar_t *self_exe)
{
    wchar_t old_path[MAX_PATH];
    int is_self;

    is_self = (_wcsicmp(dest, self_exe) == 0);

    if (is_self) {
        if (_snwprintf_s(old_path, MAX_PATH, _TRUNCATE, L"%s.old", dest) < 0)
            return 0;
        DeleteFileW(old_path);
        if (!MoveFileExW(dest, old_path, MOVEFILE_REPLACE_EXISTING))
            return 0;
    } else {
        DeleteFileW(dest);
    }

    if (!MoveFileExW(partial, dest, MOVEFILE_REPLACE_EXISTING))
        return 0;

    return 1;
}
