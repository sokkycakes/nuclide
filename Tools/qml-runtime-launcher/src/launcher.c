#include <windows.h>
#include <string.h>
#include <wchar.h>

int updater_run_apply(void);

static BOOL append_argument(wchar_t *command, size_t capacity,
    const wchar_t *argument)
{
    size_t length = wcslen(command);
    size_t argument_length = wcslen(argument);

    if (length + argument_length + 2 >= capacity) {
        return FALSE;
    }

    if (length != 0) {
        command[length++] = L' ';
        command[length] = L'\0';
    }

    memcpy(command + length, argument, (argument_length + 1) * sizeof(*argument));
    return TRUE;
}

static BOOL append_quoted_argument(wchar_t *command, size_t capacity,
    const wchar_t *argument)
{
    size_t length = wcslen(command);
    size_t argument_length = wcslen(argument);

    /* This launcher only supplies known, local paths. */
    if (length + argument_length + 4 >= capacity) {
        return FALSE;
    }

    if (length != 0) {
        command[length++] = L' ';
        command[length] = L'\0';
    }

    command[length++] = L'"';
    memcpy(command + length, argument, argument_length * sizeof(*argument));
    length += argument_length;
    command[length++] = L'"';
    command[length] = L'\0';
    return TRUE;
}

static BOOL wants_apply_mode(const wchar_t *command_line, const wchar_t *root)
{
    wchar_t request_path[MAX_PATH];

    if (command_line && wcsstr(command_line, L"--apply"))
        return TRUE;

    swprintf_s(request_path, MAX_PATH, L"%ls\\apply.request", root);
    if (GetFileAttributesW(request_path) != INVALID_FILE_ATTRIBUTES) {
        DeleteFileW(request_path);
        return TRUE;
    }
    return FALSE;
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous_instance,
    PWSTR command_line, int show_command)
{
    wchar_t executable_path[MAX_PATH];
    wchar_t application_root[MAX_PATH];
    wchar_t runtime_path[MAX_PATH];
    wchar_t qml_path[MAX_PATH];
    wchar_t command[MAX_PATH * 3];
    STARTUPINFOW startup_info = { 0 };
    PROCESS_INFORMATION process_info = { 0 };
    DWORD path_length;
    wchar_t *separator;

    (void)instance;
    (void)previous_instance;
    (void)show_command;

    startup_info.cb = sizeof(startup_info);

    path_length = GetModuleFileNameW(NULL, executable_path,
        (DWORD)(sizeof(executable_path) / sizeof(*executable_path)));
    if (path_length == 0 || path_length == (sizeof(executable_path) / sizeof(*executable_path))) {
        MessageBoxW(NULL, L"Could not determine the launcher location.",
            L"Nuclide Launcher", MB_ICONERROR | MB_OK);
        return 1;
    }

    wcscpy_s(application_root, sizeof(application_root) / sizeof(*application_root),
        executable_path);
    separator = wcsrchr(application_root, L'\\');
    if (separator == NULL) {
        MessageBoxW(NULL, L"Could not determine the launcher folder.",
            L"Nuclide Launcher", MB_ICONERROR | MB_OK);
        return 1;
    }
    *separator = L'\0';

    /* Same exe, apply mode: download/verify/replace then exit (no UI). */
    if (wants_apply_mode(command_line, application_root))
        return updater_run_apply();

    {
        wchar_t old_exe[MAX_PATH];
        _snwprintf_s(old_exe, MAX_PATH, _TRUNCATE, L"%s.old", executable_path);
        DeleteFileW(old_exe);
    }

    swprintf_s(runtime_path, sizeof(runtime_path) / sizeof(*runtime_path),
        L"%ls\\runtime\\qml.exe", application_root);
    swprintf_s(qml_path, sizeof(qml_path) / sizeof(*qml_path),
        L"%ls\\app\\main.qml", application_root);

    if (GetFileAttributesW(runtime_path) == INVALID_FILE_ATTRIBUTES ||
        GetFileAttributesW(qml_path) == INVALID_FILE_ATTRIBUTES) {
        MessageBoxW(NULL,
            L"The launcher runtime is incomplete.\n\nExpected runtime\\qml.exe and app\\main.qml next to NuclideLauncher.exe.",
            L"Nuclide Launcher", MB_ICONERROR | MB_OK);
        return 1;
    }

    command[0] = L'\0';
    if (!append_quoted_argument(command, sizeof(command) / sizeof(*command), runtime_path) ||
        !append_quoted_argument(command, sizeof(command) / sizeof(*command), qml_path) ||
        !append_argument(command, sizeof(command) / sizeof(*command), L"-style") ||
        !append_argument(command, sizeof(command) / sizeof(*command), L"Fusion")) {
        MessageBoxW(NULL, L"The launcher command line is too long.",
            L"Nuclide Launcher", MB_ICONERROR | MB_OK);
        return 1;
    }

    /* Match Qt Design Studio Fusion preview (default on Windows is native). */
    SetEnvironmentVariableW(L"QT_QUICK_CONTROLS_STYLE", L"Fusion");
    /* Allow XMLHttpRequest to read/write local status + config beside the app. */
    SetEnvironmentVariableW(L"QML_XHR_ALLOW_FILE_READ", L"1");
    SetEnvironmentVariableW(L"QML_XHR_ALLOW_FILE_WRITE", L"1");

    if (!CreateProcessW(NULL, command, NULL, NULL, FALSE, 0, NULL,
            application_root, &startup_info, &process_info)) {
        wchar_t message[512];
        swprintf_s(message, sizeof(message) / sizeof(*message),
            L"Could not start the QML runtime.\n\nWindows error %lu.", GetLastError());
        MessageBoxW(NULL, message, L"Nuclide Launcher", MB_ICONERROR | MB_OK);
        return 1;
    }

    CloseHandle(process_info.hThread);
    CloseHandle(process_info.hProcess);
    return 0;
}
