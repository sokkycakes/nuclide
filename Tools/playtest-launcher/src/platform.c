#include "platform.h"

#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <sys/stat.h>

static wchar_t *widen_raw(const char *s)
{
	int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
	wchar_t *w = (wchar_t *)malloc(sizeof(wchar_t) * (n > 0 ? n : 1));
	if (!w) return NULL;
	if (n <= 0) { w[0] = 0; return w; }
	MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n);
	return w;
}

static wchar_t *widen(const char *s)
{
	int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
	wchar_t *w = (wchar_t *)malloc(sizeof(wchar_t) * (n > 0 ? n : 1));
	if (!w) return NULL;
	if (n <= 0) { w[0] = 0; return w; }
	MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n);
	for (int i = 0; w[i]; i++) if (w[i] == L'/') w[i] = L'\\';
	return w;
}

FILE *pl_fopen(const char *path, const char *mode)
{
	wchar_t *wp = widen(path), *wm = widen(mode);
	FILE *f = (wp && wm) ? _wfopen(wp, wm) : NULL;
	free(wp); free(wm);
	return f;
}

static int mkdir1(const char *p)
{
	wchar_t *w = widen(p);
	BOOL ok = w ? CreateDirectoryW(w, NULL) : FALSE;
	DWORD e = GetLastError();
	free(w);
	return (ok || e == ERROR_ALREADY_EXISTS) ? 0 : -1;
}

int pl_rename(const char *src, const char *dst)
{
	wchar_t *a = widen(src), *b = widen(dst);
	BOOL ok = (a && b) ? MoveFileExW(a, b, MOVEFILE_REPLACE_EXISTING | MOVEFILE_COPY_ALLOWED) : FALSE;
	free(a); free(b);
	return ok ? 0 : -1;
}

int pl_remove(const char *path)
{
	wchar_t *w = widen(path);
	BOOL ok = w ? DeleteFileW(w) : FALSE;
	free(w);
	return ok ? 0 : -1;
}

int pl_stat(const char *path, uint64_t *size, int64_t *mtime)
{
	WIN32_FILE_ATTRIBUTE_DATA a;
	wchar_t *w = widen(path);
	BOOL ok = w ? GetFileAttributesExW(w, GetFileExInfoStandard, &a) : FALSE;
	free(w);
	if (!ok || (a.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) return -1;
	if (size) *size = ((uint64_t)a.nFileSizeHigh << 32) | a.nFileSizeLow;
	if (mtime) *mtime = (int64_t)((((uint64_t)a.ftLastWriteTime.dwHighDateTime << 32) | a.ftLastWriteTime.dwLowDateTime) / 10000000ULL);
	return 0;
}

int pl_exe_path(char *out, size_t cap)
{
	wchar_t w[MAX_PATH * 4];
	DWORD n = GetModuleFileNameW(NULL, w, MAX_PATH * 4);
	if (!n) return -1;
	if (!WideCharToMultiByte(CP_UTF8, 0, w, -1, out, (int)cap, NULL, NULL)) return -1;
	return 0;
}

static void append_quoted(wchar_t *cmd, size_t cap, const wchar_t *arg)
{
	size_t len = wcslen(cmd);
	int needs = (*arg == 0) || wcspbrk(arg, L" \t\"") != NULL;
	if (len && len + 1 < cap) cmd[len++] = L' ';
	if (!needs) {
		for (; *arg && len + 1 < cap; arg++) cmd[len++] = *arg;
		cmd[len] = 0;
		return;
	}
	if (len + 1 < cap) cmd[len++] = L'"';
	for (; *arg && len + 3 < cap; arg++) {
		if (*arg == L'"') cmd[len++] = L'\\';
		cmd[len++] = *arg;
	}
	if (len + 1 < cap) cmd[len++] = L'"';
	cmd[len] = 0;
}

int pl_spawn(const char *exe, const char *const *argv, const char *cwd)
{
	static wchar_t cmd[32768];
	STARTUPINFOW si;
	PROCESS_INFORMATION pi;
	wchar_t *wexe = widen(exe), *wcwd = cwd ? widen(cwd) : NULL;
	BOOL ok;
	cmd[0] = 0;
	for (int i = 0; argv[i]; i++) {
		wchar_t *a = i == 0 ? widen(argv[i]) : widen_raw(argv[i]);
		if (a) {
			append_quoted(cmd, 32768, a);
			free(a);
		}
	}
	memset(&si, 0, sizeof(si));
	si.cb = sizeof(si);
	ok = CreateProcessW(wexe, cmd, NULL, NULL, FALSE, 0, NULL, wcwd, &si, &pi);
	free(wexe); free(wcwd);
	if (!ok) return -1;
	CloseHandle(pi.hThread);
	CloseHandle(pi.hProcess);
	return 0;
}

void pl_make_executable(const char *path) { (void)path; }

void pl_open_folder(const char *path)
{
	wchar_t *w = widen(path);
	if (w) ShellExecuteW(NULL, L"open", w, NULL, NULL, SW_SHOWNORMAL);
	free(w);
}

#else /* POSIX */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

FILE *pl_fopen(const char *path, const char *mode) { return fopen(path, mode); }

static int mkdir1(const char *p)
{
	if (mkdir(p, 0755) == 0 || errno == EEXIST) return 0;
	return -1;
}

int pl_rename(const char *src, const char *dst) { return rename(src, dst) == 0 ? 0 : -1; }
int pl_remove(const char *path) { return unlink(path) == 0 ? 0 : -1; }

int pl_stat(const char *path, uint64_t *size, int64_t *mtime)
{
	struct stat st;
	if (stat(path, &st) != 0 || !S_ISREG(st.st_mode)) return -1;
	if (size) *size = (uint64_t)st.st_size;
	if (mtime) *mtime = (int64_t)st.st_mtime;
	return 0;
}

int pl_exe_path(char *out, size_t cap)
{
	ssize_t n = readlink("/proc/self/exe", out, cap - 1);
	if (n <= 0) return -1;
	out[n] = 0;
	return 0;
}

int pl_spawn(const char *exe, const char *const *argv, const char *cwd)
{
	pid_t pid = fork();
	if (pid < 0) return -1;
	if (pid == 0) {
		/* double fork so the game is not our child when we exit */
		if (fork() != 0) _exit(0);
		setsid();
		if (cwd && chdir(cwd) != 0) _exit(127);
		execv(exe, (char *const *)argv);
		_exit(127);
	}
	{
		int st;
		waitpid_retry:
		if (waitpid(pid, &st, 0) < 0 && errno == EINTR) goto waitpid_retry;
	}
	return access(exe, X_OK) == 0 ? 0 : -1;
}

void pl_make_executable(const char *path) { chmod(path, 0755); }

void pl_open_folder(const char *path)
{
	const char *argv[] = { "xdg-open", path, NULL };
	pl_spawn("/usr/bin/xdg-open", argv, NULL);
}
#endif

int pl_exists(const char *path) { return pl_stat(path, NULL, NULL) == 0; }

int pl_mkdirs(const char *dir)
{
	char tmp[4096];
	size_t len = strlen(dir);
	if (len == 0 || len >= sizeof(tmp)) return -1;
	memcpy(tmp, dir, len + 1);
	for (size_t i = 1; i < len; i++) {
		if (tmp[i] == '/' || tmp[i] == '\\') {
			char c = tmp[i];
			if (i == 2 && tmp[1] == ':') continue; /* C:\ */
			tmp[i] = 0;
			mkdir1(tmp);
			tmp[i] = c;
		}
	}
	return mkdir1(tmp);
}

int pl_mkparents(const char *file)
{
	char tmp[4096];
	if (strlen(file) >= sizeof(tmp)) return -1;
	strcpy(tmp, file);
	pl_dirname(tmp);
	if (!tmp[0]) return 0;
	return pl_mkdirs(tmp);
}

void pl_dirname(char *path)
{
	char *a = strrchr(path, '/'), *b = strrchr(path, '\\');
	char *s = a > b ? a : b;
	if (s) *s = 0; else path[0] = 0;
}

void pl_join(char *out, size_t cap, const char *a, const char *b)
{
	size_t la = strlen(a);
	if (la == 0) { snprintf(out, cap, "%s", b); return; }
	if (a[la - 1] == '/' || a[la - 1] == '\\') snprintf(out, cap, "%s%s", a, b);
	else snprintf(out, cap, "%s/%s", a, b);
}
