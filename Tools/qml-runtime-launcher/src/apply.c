#include <windows.h>
#include <winhttp.h>
#include <bcrypt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#include "apply_path.h"

#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "bcrypt.lib")

static void status_write(const wchar_t *path, const char *phase, double progress,
    const char *message, const char *version)
{
    char json[1024];
    wchar_t tmp[MAX_PATH];
    HANDLE file;
    DWORD written;
    int n;

    if (!path || !path[0])
        return;

    if (version && version[0]) {
        n = _snprintf_s(json, sizeof(json), _TRUNCATE,
            "{\"phase\":\"%s\",\"progress\":%.4f,\"message\":\"%s\",\"version\":\"%s\"}",
            phase, progress, message ? message : "", version);
    } else {
        n = _snprintf_s(json, sizeof(json), _TRUNCATE,
            "{\"phase\":\"%s\",\"progress\":%.4f,\"message\":\"%s\"}",
            phase, progress, message ? message : "");
    }
    if (n <= 0)
        return;

    _snwprintf_s(tmp, MAX_PATH, _TRUNCATE, L"%s.tmp", path);
    file = CreateFileW(tmp, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE)
        return;
    WriteFile(file, json, (DWORD)strlen(json), &written, NULL);
    CloseHandle(file);
    MoveFileExW(tmp, path, MOVEFILE_REPLACE_EXISTING);
}

static wchar_t *utf8_to_wide(const char *utf8)
{
    int chars = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
    wchar_t *out;
    if (chars <= 0)
        return NULL;
    out = (wchar_t *)malloc((size_t)chars * sizeof(wchar_t));
    if (!out)
        return NULL;
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, out, chars);
    return out;
}

static int json_string_after_key(const char *json, const char *key, char *out, size_t out_cap)
{
    char pattern[128];
    const char *p;
    const char *start;
    const char *end;
    size_t len;

    _snprintf_s(pattern, sizeof(pattern), _TRUNCATE, "\"%s\"", key);
    p = strstr(json, pattern);
    if (!p)
        return 0;
    p = strchr(p + strlen(pattern), ':');
    if (!p)
        return 0;
    p++;
    while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')
        p++;
    if (*p != '"')
        return 0;
    start = p + 1;
    end = start;
    while (*end && *end != '"') {
        if (*end == '\\' && end[1])
            end += 2;
        else
            end++;
    }
    if (*end != '"')
        return 0;
    len = (size_t)(end - start);
    if (len + 1 > out_cap)
        len = out_cap - 1;
    memcpy(out, start, len);
    out[len] = '\0';
    return 1;
}

static int read_file_utf8(const wchar_t *path, char **out_data)
{
    HANDLE file;
    DWORD size;
    DWORD read;
    char *data;
    DWORD tries;

    for (tries = 0; tries < 50; tries++) {
        file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL, NULL);
        if (file != INVALID_HANDLE_VALUE)
            break;
        Sleep(100);
    }
    if (file == INVALID_HANDLE_VALUE)
        return 0;
    size = GetFileSize(file, NULL);
    data = (char *)malloc((size_t)size + 1);
    if (!data) {
        CloseHandle(file);
        return 0;
    }
    if (!ReadFile(file, data, size, &read, NULL)) {
        free(data);
        CloseHandle(file);
        return 0;
    }
    data[read] = '\0';
    CloseHandle(file);
    *out_data = data;
    return 1;
}

static int sha256_hex_file(const wchar_t *path, char out_hex[65])
{
    BCRYPT_ALG_HANDLE alg = NULL;
    BCRYPT_HASH_HANDLE hash = NULL;
    PUCHAR hash_obj = NULL;
    UCHAR digest[32];
    DWORD hash_obj_len = 0;
    DWORD data_len = 0;
    HANDLE file = INVALID_HANDLE_VALUE;
    UCHAR buffer[64 * 1024];
    DWORD read;
    DWORD i;
    DWORD tries;
    NTSTATUS st;

    for (tries = 0; tries < 50; tries++) {
        file = CreateFileW(path, GENERIC_READ,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
        if (file != INVALID_HANDLE_VALUE)
            break;
        Sleep(100);
    }
    if (file == INVALID_HANDLE_VALUE)
        return 0;

    st = BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, NULL, 0);
    if (st < 0)
        goto fail;
    st = BCryptGetProperty(alg, BCRYPT_OBJECT_LENGTH, (PUCHAR)&hash_obj_len,
        sizeof(hash_obj_len), &data_len, 0);
    if (st < 0 || hash_obj_len == 0)
        goto fail;
    hash_obj = (PUCHAR)malloc(hash_obj_len);
    if (!hash_obj)
        goto fail;
    st = BCryptCreateHash(alg, &hash, hash_obj, hash_obj_len, NULL, 0, 0);
    if (st < 0)
        goto fail;

    for (;;) {
        if (!ReadFile(file, buffer, sizeof(buffer), &read, NULL))
            goto fail;
        if (read == 0)
            break;
        st = BCryptHashData(hash, buffer, read, 0);
        if (st < 0)
            goto fail;
    }

    st = BCryptFinishHash(hash, digest, sizeof(digest), 0);
    if (st < 0)
        goto fail;

    for (i = 0; i < 32; i++)
        sprintf_s(out_hex + i * 2, 3, "%02x", digest[i]);
    out_hex[64] = '\0';

    BCryptDestroyHash(hash);
    BCryptCloseAlgorithmProvider(alg, 0);
    free(hash_obj);
    CloseHandle(file);
    return 1;

fail:
    if (hash)
        BCryptDestroyHash(hash);
    if (alg)
        BCryptCloseAlgorithmProvider(alg, 0);
    free(hash_obj);
    if (file != INVALID_HANDLE_VALUE)
        CloseHandle(file);
    return 0;
}

static int download_url(const char *url_utf8, const wchar_t *dest_path,
    const wchar_t *status_path, const char *label)
{
    wchar_t *url_w;
    URL_COMPONENTS parts;
    wchar_t host[256];
    wchar_t url_path[2048];
    wchar_t extra[1024];
    wchar_t full_path[3072];
    HINTERNET session = NULL;
    HINTERNET connect = NULL;
    HINTERNET request = NULL;
    DWORD bytes;
    DWORD downloaded = 0;
    DWORD content_length = 0;
    DWORD len;
    DWORD status_code = 0;
    DWORD status_len;
    HANDLE out = INVALID_HANDLE_VALUE;
    BYTE buffer[64 * 1024];
    BOOL https;
    int ok = 0;

    url_w = utf8_to_wide(url_utf8);
    if (!url_w)
        return 0;

    memset(&parts, 0, sizeof(parts));
    parts.dwStructSize = sizeof(parts);
    parts.lpszHostName = host;
    parts.dwHostNameLength = 256;
    parts.lpszUrlPath = url_path;
    parts.dwUrlPathLength = 2048;
    parts.lpszExtraInfo = extra;
    parts.dwExtraInfoLength = 1024;

    if (!WinHttpCrackUrl(url_w, 0, 0, &parts)) {
        free(url_w);
        return 0;
    }
    https = (parts.nScheme == INTERNET_SCHEME_HTTPS);

    session = WinHttpOpen(L"StilettoUpdater/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!session)
        goto done;
    connect = WinHttpConnect(session, host, parts.nPort, 0);
    if (!connect)
        goto done;

    _snwprintf_s(full_path, 3072, _TRUNCATE, L"%s%s", url_path, extra[0] ? extra : L"");
    request = WinHttpOpenRequest(connect, L"GET", full_path, NULL, WINHTTP_NO_REFERER,
        WINHTTP_DEFAULT_ACCEPT_TYPES, https ? WINHTTP_FLAG_SECURE : 0);
    if (!request)
        goto done;
    if (!WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
            WINHTTP_NO_REQUEST_DATA, 0, 0, 0))
        goto done;
    if (!WinHttpReceiveResponse(request, NULL))
        goto done;

    status_len = sizeof(status_code);
    WinHttpQueryHeaders(request,
        WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
        WINHTTP_HEADER_NAME_BY_INDEX, &status_code, &status_len, WINHTTP_NO_HEADER_INDEX);
    if (status_code != 200)
        goto done;

    len = sizeof(content_length);
    WinHttpQueryHeaders(request,
        WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER,
        WINHTTP_HEADER_NAME_BY_INDEX, &content_length, &len, WINHTTP_NO_HEADER_INDEX);

    out = CreateFileW(dest_path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL, NULL);
    if (out == INVALID_HANDLE_VALUE)
        goto done;

    status_write(status_path, "download", 0.0, label, NULL);

    for (;;) {
        bytes = 0;
        if (!WinHttpReadData(request, buffer, sizeof(buffer), &bytes))
            goto done;
        if (bytes == 0)
            break;
        {
            DWORD written = 0;
            if (!WriteFile(out, buffer, bytes, &written, NULL) || written != bytes)
                goto done;
        }
        downloaded += bytes;
        if (content_length > 0) {
            double p = (double)downloaded / (double)content_length;
            if (p > 1.0)
                p = 1.0;
            status_write(status_path, "download", p, label, NULL);
        }
    }

    ok = 1;

done:
    if (out != INVALID_HANDLE_VALUE)
        CloseHandle(out);
    if (request)
        WinHttpCloseHandle(request);
    if (connect)
        WinHttpCloseHandle(connect);
    if (session)
        WinHttpCloseHandle(session);
    free(url_w);
    return ok;
}

/* Create every directory component in a wide path (backslash-separated). */
static int ensure_parent_dirs(const wchar_t *path)
{
    wchar_t tmp[MAX_PATH];
    wchar_t *p;
    wcscpy_s(tmp, MAX_PATH, path);
    p = tmp;
    /* skip \\server\share or drive letter root */
    if (tmp[0] == L'\\' && tmp[1] == L'\\') {
        p = wcschr(p + 2, L'\\');
        if (p) p = wcschr(p + 1, L'\\');
        if (!p) return 1;
        p++;
    } else if (tmp[1] == L':') {
        p = tmp + 2;
    }
    while (*p) {
        if (*p == L'\\') {
            *p = L'\0';
            CreateDirectoryW(tmp, NULL);
            *p = L'\\';
        }
        p++;
    }
    return 1;
}

int updater_run_apply(void)
{
    wchar_t exe_path[MAX_PATH];
    wchar_t root[MAX_PATH];
    wchar_t config_path[MAX_PATH];
    wchar_t status_path[MAX_PATH];
    wchar_t version_path[MAX_PATH];
    wchar_t temp_file[MAX_PATH];
    wchar_t temp_dir[MAX_PATH];
    wchar_t game_dir[MAX_PATH];
    wchar_t *slash;
    char *config_utf8 = NULL;
    char *manifest = NULL;
    char manifest_url[1024];
    char version[128];
    char done_msg[200];
    int file_count;
    int ret = 1;

    if (!GetModuleFileNameW(NULL, exe_path, MAX_PATH))
        return 1;
    wcscpy_s(root, MAX_PATH, exe_path);
    slash = wcsrchr(root, L'\\');
    if (!slash)
        return 1;
    *slash = L'\0';

    _snwprintf_s(config_path, MAX_PATH, _TRUNCATE, L"%s\\app\\config.json", root);
    _snwprintf_s(status_path, MAX_PATH, _TRUNCATE, L"%s\\apply-status.json", root);
    _snwprintf_s(game_dir, MAX_PATH, _TRUNCATE, L"%s\\game", root);
    _snwprintf_s(version_path, MAX_PATH, _TRUNCATE, L"%s\\game\\version.txt", root);

    status_write(status_path, "download", 0.0, "Reading config...", NULL);

    if (!read_file_utf8(config_path, &config_utf8)) {
        status_write(status_path, "error", 0.0, "Missing app/config.json", NULL);
        return 2;
    }
    if (!json_string_after_key(config_utf8, "manifestURL", manifest_url, sizeof(manifest_url))) {
        status_write(status_path, "error", 0.0, "config.json missing manifestURL", NULL);
        free(config_utf8);
        return 4;
    }
    free(config_utf8);

    GetTempPathW(MAX_PATH, temp_dir);
    GetTempFileNameW(temp_dir, L"man", 0, temp_file);
    if (!download_url(manifest_url, temp_file, status_path, "Fetching manifest...")) {
        status_write(status_path, "error", 0.0, "Couldn't fetch manifest", NULL);
        DeleteFileW(temp_file);
        return 5;
    }
    if (!read_file_utf8(temp_file, &manifest)) {
        DeleteFileW(temp_file);
        status_write(status_path, "error", 0.0, "Couldn't read manifest", NULL);
        return 5;
    }
    DeleteFileW(temp_file);

    if (!json_string_after_key(manifest, "version", version, sizeof(version))) {
        status_write(status_path, "error", 0.0, "Manifest missing version", NULL);
        free(manifest);
        return 6;
    }
    CreateDirectoryW(game_dir, NULL);

    /* Count file entries in the manifest files array. */
    {
        const char *fp = strstr(manifest, "\"files\"");
        int depth = 0;
        file_count = 0;
        if (fp) {
            fp = strchr(fp + 7, '[');
            if (fp) {
                fp++;
                while (*fp) {
                    if (*fp == '{') depth++;
                    else if (*fp == '}') { depth--; if (depth == 0) file_count++; }
                    else if (*fp == ']' && depth == 0) break;
                    fp++;
                }
            }
        }
    }

    if (file_count == 0) {
        status_write(status_path, "error", 0.0, "Manifest has no files", NULL);
        free(manifest);
        return 6;
    }

    /* Phase 1: download + verify every file to .partial. */
    {
        const char *fp = strstr(manifest, "\"files\"");
        int entry_idx = 0;
        wchar_t partial_path[MAX_PATH];
        wchar_t dest_path[MAX_PATH];
        char file_path[260];
        char file_url[1024];
        char expect_sha[80];
        char actual_sha[65];
        char label[300];
        int depth;

        if (fp) fp = strchr(fp + 7, '[');
        if (fp) fp++;

        while (fp && *fp && entry_idx < file_count) {
            /* skip to next { */
            while (*fp && *fp != '{') fp++;
            if (!*fp) break;

            /* extract one file object */
            {
                const char *obj_start = fp;
                char obj_buf[4096];
                int obj_len;
                depth = 0;
                while (*fp) {
                    if (*fp == '{') depth++;
                    else if (*fp == '}') { depth--; if (depth == 0) break; }
                    fp++;
                }
                if (!*fp) break;
                fp++;
                obj_len = (int)(fp - obj_start);
                if (obj_len >= (int)sizeof(obj_buf)) {
                    entry_idx++;
                    continue;
                }
                memcpy(obj_buf, obj_start, obj_len);
                obj_buf[obj_len] = '\0';

                if (!json_string_after_key(obj_buf, "path", file_path, sizeof(file_path)) ||
                    !json_string_after_key(obj_buf, "url", file_url, sizeof(file_url))) {
                    entry_idx++;
                    continue;
                }
                if (!json_string_after_key(obj_buf, "sha256", expect_sha, sizeof(expect_sha)))
                    expect_sha[0] = '\0';

                if (!updater_validate_file_path(file_path, sizeof(file_path))) {
                    char msg[200];
                    _snprintf_s(msg, sizeof(msg), _TRUNCATE,
                        "Invalid file path in manifest: %s", file_path);
                    status_write(status_path, "error", 0.0, msg, NULL);
                    free(manifest);
                    return 7;
                }

                {
                    wchar_t file_path_w[MAX_PATH];
                    if (!MultiByteToWideChar(CP_UTF8, 0, file_path, -1, file_path_w, MAX_PATH)) {
                        status_write(status_path, "error", 0.0, "Bad file path encoding", NULL);
                        free(manifest);
                        return 7;
                    }
                    if (!updater_resolve_dest(root, game_dir, file_path_w, dest_path, MAX_PATH)) {
                        status_write(status_path, "error", 0.0, "Invalid launcher path in manifest", NULL);
                        free(manifest);
                        return 7;
                    }
                    _snwprintf_s(partial_path, MAX_PATH, _TRUNCATE, L"%s.partial", dest_path);
                }

                _snprintf_s(label, sizeof(label), _TRUNCATE, "Downloading %s...", file_path);
                ensure_parent_dirs(dest_path);

                if (!download_url(file_url, partial_path, status_path, label)) {
                    char msg[200];
                    _snprintf_s(msg, sizeof(msg), _TRUNCATE, "Download failed: %s", file_path);
                    status_write(status_path, "error", 0.0, msg, NULL);
                    DeleteFileW(partial_path);
                    free(manifest);
                    return 8;
                }

                if (GetFileAttributesW(partial_path) == INVALID_FILE_ATTRIBUTES) {
                    status_write(status_path, "error", 0.0, "Download missing after write", NULL);
                    free(manifest);
                    return 8;
                }

                if (expect_sha[0]) {
                    status_write(status_path, "apply", 1.0, "Verifying checksum...", NULL);
                    if (!sha256_hex_file(partial_path, actual_sha)) {
                        char msg[160];
                        _snprintf_s(msg, sizeof(msg), _TRUNCATE,
                            "Couldn't hash download (err %lu)", GetLastError());
                        status_write(status_path, "error", 0.0, msg, NULL);
                        DeleteFileW(partial_path);
                        free(manifest);
                        return 9;
                    }
                    if (_stricmp(actual_sha, expect_sha) != 0) {
                        char msg[200];
                        _snprintf_s(msg, sizeof(msg), _TRUNCATE,
                            "SHA256 mismatch (%s)", file_path);
                        status_write(status_path, "error", 0.0, msg, NULL);
                        DeleteFileW(partial_path);
                        free(manifest);
                        return 9;
                    }
                }

                entry_idx++;
            }
        }
    }
    /* Phase 2: atomically rename all .partial files to final paths. */
    status_write(status_path, "apply", 1.0, "Installing...", NULL);
    {
        const char *fp = strstr(manifest, "\"files\"");
        int entry_idx = 0;
        wchar_t partial_path[MAX_PATH];
        wchar_t dest_path[MAX_PATH];
        char file_path[260];
        int depth;

        if (fp) fp = strchr(fp + 7, '[');
        if (fp) fp++;

        while (fp && *fp && entry_idx < file_count) {
            while (*fp && *fp != '{') fp++;
            if (!*fp) break;

            {
                const char *obj_start = fp;
                char obj_buf[4096];
                int obj_len;
                depth = 0;
                while (*fp) {
                    if (*fp == '{') depth++;
                    else if (*fp == '}') { depth--; if (depth == 0) break; }
                    fp++;
                }
                if (!*fp) break;
                fp++;
                obj_len = (int)(fp - obj_start);
                if (obj_len >= (int)sizeof(obj_buf)) { entry_idx++; continue; }
                memcpy(obj_buf, obj_start, obj_len);
                obj_buf[obj_len] = '\0';

                if (!json_string_after_key(obj_buf, "path", file_path, sizeof(file_path))) {
                    entry_idx++;
                    continue;
                }
                if (!updater_validate_file_path(file_path, sizeof(file_path))) {
                    entry_idx++;
                    continue;
                }

                {
                    wchar_t file_path_w[MAX_PATH];
                    MultiByteToWideChar(CP_UTF8, 0, file_path, -1, file_path_w, MAX_PATH);
                    if (!updater_resolve_dest(root, game_dir, file_path_w, dest_path, MAX_PATH)) {
                        status_write(status_path, "error", 0.0, "Invalid launcher path in manifest", NULL);
                        free(manifest);
                        return 7;
                    }
                    _snwprintf_s(partial_path, MAX_PATH, _TRUNCATE, L"%s.partial", dest_path);
                }

                if (GetFileAttributesW(partial_path) != INVALID_FILE_ATTRIBUTES) {
                    if (!updater_replace_file(partial_path, dest_path, exe_path)) {
                        char msg[200];
                        _snprintf_s(msg, sizeof(msg), _TRUNCATE,
                            "Couldn't replace %s (is the game running?)", file_path);
                        status_write(status_path, "error", 0.0, msg, NULL);
                        free(manifest);
                        return 10;
                    }
                }
                entry_idx++;
            }
        }
    }

    /* Write version.txt last — if we get here, all files are updated. */
    {
        HANDLE vf = CreateFileW(version_path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
            FILE_ATTRIBUTE_NORMAL, NULL);
        if (vf != INVALID_HANDLE_VALUE) {
            DWORD written = 0;
            WriteFile(vf, version, (DWORD)strlen(version), &written, NULL);
            CloseHandle(vf);
        }
    }

    _snprintf_s(done_msg, sizeof(done_msg), _TRUNCATE, "Updated to %s", version);
    status_write(status_path, "done", 1.0, done_msg, version);
    ret = 0;

    free(manifest);
    return ret;
}
