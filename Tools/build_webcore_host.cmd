@echo off
setlocal
call "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
cd /d C:\w\wc-fte
if errorlevel 1 exit /b 1

set SRC=C:\Users\sokky\Documents\Godot\bulwark_proto_funny\workspace\webcore-fte
set STUB_DIR=Tools\FTE\CMakeFiles\fte_render_harness.dir\stubs
if not exist "%STUB_DIR%" mkdir "%STUB_DIR%"

echo === COMPILE harness ===
cl.exe @harness-compile.rsp
if errorlevel 1 exit /b 1

rem WebCore.lib supplies FontCascade; linking the obsolete stub duplicates it.
echo === COMPILE FTE GraphicsLayer stub ===
cl.exe @harness-stub-flags.rsp /c /Fo%STUB_DIR%\GraphicsLayerFTE.cpp.obj "%SRC%\Source\WebCore\platform\graphics\fte\GraphicsLayerFTE.cpp"
if errorlevel 1 exit /b 1

echo === COMPILE curl dllimport shim ===
cl.exe /nologo /c /O2 /MD /DCURL_STATICLIB /I"%SRC%\deps\WebKitLibraries\include" /Fo%STUB_DIR%\curl_dllimport_shim.c.obj "%SRC%\Tools\FTE\host\curl_dllimport_shim.c"
if errorlevel 1 exit /b 1

echo === LINK ===
link.exe /nologo /LTCG Tools\FTE\CMakeFiles\fte_render_harness.dir\host\fte_render_harness.cpp.obj %STUB_DIR%\GraphicsLayerFTE.cpp.obj %STUB_DIR%\curl_dllimport_shim.c.obj /out:bin\ftewebcore.dll /implib:lib\ftewebcore.lib /pdb:bin\ftewebcore.pdb /dll /version:0.0 /machine:x64 /LARGEADDRESSAWARE /INCREMENTAL:NO -LIBPATH:%SRC%\deps\WebKitLibraries\lib lib\WebCore.lib lib\JavaScriptCore.lib C:\Users\sokky\Documents\Godot\bulwark_proto_funny\workspace\.tools\vcpkg\installed\x64-windows\lib\cairo.lib %SRC%\deps\WebKitLibraries\lib\libcurl.lib %SRC%\deps\WebKitLibraries\lib\ssl.lib %SRC%\deps\WebKitLibraries\lib\tls.lib %SRC%\deps\WebKitLibraries\lib\crypto.lib crypt32.lib iphlpapi.lib usp10.lib lib\PAL.lib lib\WTF.lib lib\mimalloc.lib psapi.lib shell32.lib user32.lib advapi32.lib DbgHelp.lib winmm.lib %SRC%\deps\WebKitLibraries\lib\icuin.lib %SRC%\deps\WebKitLibraries\lib\icuuc.lib %SRC%\deps\WebKitLibraries\lib\icudt.lib %SRC%\deps\WebKitLibraries\lib\brotlidec.lib %SRC%\deps\WebKitLibraries\lib\brotlienc.lib %SRC%\deps\WebKitLibraries\lib\brotlicommon.lib %SRC%\deps\WebKitLibraries\lib\harfbuzz-icu.lib %SRC%\deps\WebKitLibraries\lib\harfbuzz.lib %SRC%\deps\WebKitLibraries\lib\freetype.lib %SRC%\deps\WebKitLibraries\lib\jpeg-static.lib %SRC%\deps\WebKitLibraries\lib\nghttp2_static.lib %SRC%\deps\WebKitLibraries\lib\libpng16_static.lib %SRC%\deps\WebKitLibraries\lib\xml2.lib %SRC%\deps\WebKitLibraries\lib\xslt.lib %SRC%\deps\WebKitLibraries\lib\zlibstatic.lib lib\sqlite3.lib bcrypt.lib comctl32.lib normaliz.lib rpcrt4.lib shlwapi.lib version.lib wldap32.lib ws2_32.lib kernel32.lib user32.lib gdi32.lib winspool.lib shell32.lib ole32.lib oleaut32.lib uuid.lib comdlg32.lib advapi32.lib
echo EXIT=%ERRORLEVEL%
exit /b %ERRORLEVEL%
