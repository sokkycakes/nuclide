#include <stdio.h>
#include <string.h>
#include <wchar.h>
#include <windows.h>
#include "apply_path.h"

static int fail(const char *msg)
{
    fprintf(stderr, "FAIL: %s\n", msg);
    return 1;
}

static int write_bytes(const wchar_t *path, const char *bytes)
{
    HANDLE f = CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL, NULL);
    DWORD written = 0;
    if (f == INVALID_HANDLE_VALUE)
        return 0;
    WriteFile(f, bytes, (DWORD)strlen(bytes), &written, NULL);
    CloseHandle(f);
    return 1;
}

static int read_bytes(const wchar_t *path, char *buf, size_t cap)
{
    HANDLE f = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL,
        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    DWORD n = 0;
    if (f == INVALID_HANDLE_VALUE)
        return 0;
    if (!ReadFile(f, buf, (DWORD)(cap - 1), &n, NULL)) {
        CloseHandle(f);
        return 0;
    }
    CloseHandle(f);
    buf[n] = '\0';
    return 1;
}

int main(void)
{
    char path[260];
    wchar_t dest[MAX_PATH];
    wchar_t tmp[MAX_PATH];
    wchar_t dest_file[MAX_PATH];
    wchar_t partial_file[MAX_PATH];
    wchar_t old_file[MAX_PATH];
    char buf[32];

    strcpy_s(path, sizeof(path), "base/progs.dat");
    if (!updater_validate_file_path(path, sizeof(path)))
        return fail("progs path should be valid");
    if (strcmp(path, "base\\progs.dat") != 0)
        return fail("slashes should become backslashes");

    strcpy_s(path, sizeof(path), "../secret");
    if (updater_validate_file_path(path, sizeof(path)))
        return fail(".. must be rejected");

    strcpy_s(path, sizeof(path), "C:/foo");
    if (updater_validate_file_path(path, sizeof(path)))
        return fail("C:/foo must be rejected");

    strcpy_s(path, sizeof(path), "C:foo");
    if (updater_validate_file_path(path, sizeof(path)))
        return fail("C:foo must be rejected");

    strcpy_s(path, sizeof(path), "launcher/NuclideLauncher.exe");
    if (!updater_validate_file_path(path, sizeof(path)))
        return fail("launcher path should be valid");
    if (!updater_resolve_dest(L"C:\\install", L"C:\\install\\game",
            L"launcher\\NuclideLauncher.exe", dest, MAX_PATH))
        return fail("launcher dest resolve");
    if (wcscmp(dest, L"C:\\install\\NuclideLauncher.exe") != 0)
        return fail("launcher dest should strip prefix onto install root");

    if (!updater_resolve_dest(L"C:\\install", L"C:\\install\\game",
            L"base\\progs.dat", dest, MAX_PATH))
        return fail("game dest resolve");
    if (wcscmp(dest, L"C:\\install\\game\\base\\progs.dat") != 0)
        return fail("game dest should stay under game\\");

    GetTempPathW(MAX_PATH, tmp);
    _snwprintf_s(dest_file, MAX_PATH, _TRUNCATE, L"%sapply_dest.bin", tmp);
    _snwprintf_s(partial_file, MAX_PATH, _TRUNCATE, L"%sapply_partial.bin", tmp);
    _snwprintf_s(old_file, MAX_PATH, _TRUNCATE, L"%s.old", dest_file);
    DeleteFileW(old_file);
    if (!write_bytes(dest_file, "old-exe") || !write_bytes(partial_file, "new-exe"))
        return fail("temp write");
    if (!updater_replace_file(partial_file, dest_file, dest_file))
        return fail("self replace");
    if (!read_bytes(dest_file, buf, sizeof(buf)) || strcmp(buf, "new-exe") != 0)
        return fail("dest should be new-exe");
    if (!read_bytes(old_file, buf, sizeof(buf)) || strcmp(buf, "old-exe") != 0)
        return fail(".old should be old-exe");
    DeleteFileW(dest_file);
    DeleteFileW(old_file);
    DeleteFileW(partial_file);

    /* Self-rename failure: existing dest.old directory blocks rename. */
    GetTempPathW(MAX_PATH, tmp);
    _snwprintf_s(dest_file, MAX_PATH, _TRUNCATE, L"%sapply_dest_blocked.bin", tmp);
    _snwprintf_s(partial_file, MAX_PATH, _TRUNCATE, L"%sapply_partial_blocked.bin", tmp);
    _snwprintf_s(old_file, MAX_PATH, _TRUNCATE, L"%s.old", dest_file);
    DeleteFileW(dest_file);
    DeleteFileW(partial_file);
    RemoveDirectoryW(old_file);
    if (!write_bytes(dest_file, "old-exe") || !write_bytes(partial_file, "new-exe"))
        return fail("blocked temp write");
    if (!CreateDirectoryW(old_file, NULL))
        return fail("create dest.old directory");
    if (updater_replace_file(partial_file, dest_file, dest_file))
        return fail("self replace should fail when dest.old is a directory");
    if (!read_bytes(dest_file, buf, sizeof(buf)) || strcmp(buf, "old-exe") != 0)
        return fail("dest should be preserved on rename failure");
    if (!read_bytes(partial_file, buf, sizeof(buf)) || strcmp(buf, "new-exe") != 0)
        return fail("partial should not be installed on rename failure");
    DeleteFileW(dest_file);
    DeleteFileW(partial_file);
    RemoveDirectoryW(old_file);

    printf("apply_path_test ok\n");
    return 0;
}
