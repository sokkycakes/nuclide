"""Install the isolated FTEW module into the canonical FTE workspace.

Only exact, small registration/search-list edits are made to existing files.
Other in-progress engine work is preserved. Re-running is safe.
"""
from pathlib import Path
import argparse
import shutil

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, required=True)
    args = parser.parse_args()
    root = args.engine.resolve()
    canonical = (Path(__file__).resolve().parents[2].parent / "workspace/fteqw").resolve()
    if root != canonical and canonical not in root.parents:
        raise SystemExit("Engine destination must be the canonical workspace/fteqw or its worktree.")
    engine = root / "engine"
    # Keep the explicit menu switch, but editor launches leave menus enabled.
    path = engine / "client/m_webcore_menu.c"
    text = path.read_text()
    if 'cvar_t webcore_menu_enabled' not in text:
        edits = {
            'cvar_t webcore_menu_url =': 'cvar_t webcore_menu_enabled = CVARFD("webcore_menu_enabled", "1", 0,\n\t"Enable WebCore menus and automatic title-map startup.");\n\ncvar_t webcore_menu_url =',
            '\tCvar_Register(&webcore_menu_url, "WebCore menu");': '\tCvar_Register(&webcore_menu_enabled, "WebCore menu");\n\tCvar_Register(&webcore_menu_url, "WebCore menu");',
            'void WebcoreMenu_Frame(void)\n{': 'void WebcoreMenu_Frame(void)\n{\n\tif (!webcore_menu_enabled.ival) {\n\t\twebcore_title_pending = false;\n\t\twebcore_menumap_queued = false;\n\t\treturn;\n\t}',
            '\tWebcoreMenu_RegisterCvars();\n\turl = WebcoreMenu_ResolveURL(url_override);': '\tWebcoreMenu_RegisterCvars();\n\tif (!webcore_menu_enabled.ival) return;\n\turl = WebcoreMenu_ResolveURL(url_override);',
        }
        for old,new in edits.items():
            assert text.count(old)==1, "Unexpected WebCore menu layout"
            text = text.replace(old,new)
        path.write_text(text,newline="\n")
    # A title request can arrive during local server startup, before the
    # client reaches ca_active. Never queue a backdrop over that game/connect.
    marker = '\turl = WebcoreMenu_ResolveURL(url_override);'
    guard = '''
	/* Loading a game is already a destination, even before client signon. */
	if (WebcoreMenu_IsTitleURL(url) && !WebcoreMenu_IsBackgroundMap() &&
		(sv.state || cls.state != ca_disconnected || CL_TryingToConnect()))
		return;
'''
    if guard not in text:
        assert text.count(marker) == 1, "Unexpected WebCore menu routing"
        text = text.replace(marker, marker + '\n' + guard)
        path.write_text(text, newline="\n")
    # Orthographic sunlight must retain its directional shader when shadows
    # are disabled; the original ORTHO branch always rendered a shadow map.
    path = engine / "gl/gl_shadow.c"
    text = path.read_text()
    old = '\t\t\tSh_DrawShadowMapLight(dl, colour, axis, NULL);\n\t\t\tVectorCopy(saveorg, dl->origin);'
    new = '''\t\t\tif ((dl->flags & LFLAG_NOSHADOWS) ||
                ((i >= RTL_FIRST)?!r_shadow_realtime_world_shadows.ival:!r_shadow_realtime_dlight_shadows.ival))
                Sh_DrawShadowlessLight(dl, colour, axis, NULL, LSHADER_ORTHO);
            else
                Sh_DrawShadowMapLight(dl, colour, axis, NULL);
\t\t\tVectorCopy(saveorg, dl->origin);'''
    if old in text:
        assert text.count(old) == 1
        path.write_text(text.replace(old,new), newline="\n")
    else:
        assert new in text, "Unexpected native directional-light branch"
    # PNG screenshot DLLs may use a different Windows CRT than the executable.
    # Keep FILE* access in the executable by supplying libpng I/O callbacks.
    path = engine / "client/image.c"
    text = path.read_text()
    if "Image_PNGWriteData" not in text:
        old = "static void (PNGAPI *qpng_init_io) PNGARG((png_structp png_ptr, png_FILE_p fp)) PSTATIC(png_init_io);"
        new = "static void (PNGAPI *qpng_set_write_fn) PNGARG((png_structp png_ptr, png_voidp io_ptr, png_rw_ptr write_fn, png_flush_ptr flush_fn)) PSTATIC(png_set_write_fn);"
        assert text.count(old) == 1
        text = text.replace(old, new).replace('&qpng_init_io,', '&qpng_set_write_fn,').replace('"png_init_io"', '"png_set_write_fn"')
        marker = "int Image_WritePNG (const char *filename,"
        assert text.count(marker) == 1
        callbacks = '''/* FILE objects must stay within the CRT that opened them. */
static void PNGAPI Image_PNGWriteData(png_structp png, png_bytep data, png_size_t length)
{
    FILE *fp = (FILE *)qpng_get_io_ptr(png);
    if (fwrite(data, 1, length, fp) != length) qpng_error(png, "PNG write failed");
}
static void PNGAPI Image_PNGFlush(png_structp png)
{
    if (fflush((FILE *)qpng_get_io_ptr(png))) qpng_error(png, "PNG flush failed");
}

'''
        text = text.replace(marker, callbacks + marker)
        assert text.count("qpng_init_io(png_ptr, fp);") == 1
        text = text.replace("qpng_init_io(png_ptr, fp);", "qpng_set_write_fn(png_ptr, fp, Image_PNGWriteData, Image_PNGFlush);")
        path.write_text(text, newline="\n")
    # Existing fallback build bug: the header already supplies this no-op.
    path = engine / "client/m_slint_menu.c"
    text = path.read_text()
    duplicate = "void SlintMenu_RegisterCvars(void)\n{\n    /* No-op: Slint not compiled in */\n}\n"
    if duplicate in text:
        path.write_text(text.replace(duplicate, "/* SlintMenu_RegisterCvars is supplied by m_slint_input.h. */\n"), newline="\n")
    source = Path(__file__).parent / "engine"
    for filename in ("fte_world_format.h", "gl_fteworld.h"):
        shutil.copyfile(source / filename, engine / "gl" / filename)
    path = engine / "gl/gl_heightmap.c"
    text = path.read_text()
    if '"ftew_background"' not in text:
        marker = '\t\tif (*hm->skyname)\n'
        assert text.count(marker) == 1
        text = text.replace(marker, '\t\tif (!strcmp(hm->skyname, "@ftew"))\n\t\t\thm->skyshader = R_RegisterShader("ftew_background", SUF_NONE, "{\\nsort sky\\nsurfaceparm sky\\nsurfaceparm nodlight\\n}\\n");\n\t\telse if (*hm->skyname)\n')
    # Supply a black fallback for worlds without a selected native sky.
    text = text.replace('R_RegisterShader("ftew_background", SUF_NONE, "{\\nsort sky\\nsurfaceparm sky\\nsurfaceparm nodlight\\n}\\n")',
                        'R_RegisterShader("ftew_background", SUF_NONE, "{\\nsort sky\\nsurfaceparm sky\\nsurfaceparm nodlight\\n{\\nmap $whiteimage\\nrgbgen const ( 0 0 0 )\\n}\\n}\\n")')
    if '#include "gl_fteworld.h"' not in text:
        marker = "void *Mod_LoadTerrainInfo(model_t *mod, char *loadname, qboolean force)"
        assert text.count(marker) == 1
        text = text.replace(marker, '#if defined(Q2BSPS) || defined(Q3BSPS)\n#include "gl_fteworld.h"\n#endif\n\n' + marker)
    marker = '\tMod_RegisterModelFormatText(NULL, "Quake Map Format (map)", "{", Terr_LoadTerrainModel);'
    if '"FTE native world (ftew)"' not in text:
        assert text.count(marker) == 1
        text = text.replace(marker, marker + '\n#if defined(Q2BSPS) || defined(Q3BSPS)\n\tMod_RegisterModelFormatMagic(NULL, "FTE native world (ftew)", (qbyte *)"FTEW", 4, FTEW_Load);\n#endif')
    if 'Cmd_AddCommand("ftew_trace"' not in text:
        marker = '\tMod_RegisterModelFormatMagic(NULL, "FTE native world (ftew)", (qbyte *)"FTEW", 4, FTEW_Load);'
        assert marker in text
        text = text.replace(marker, marker + '\n\tCmd_AddCommand("ftew_trace", FTEW_Trace_f);')
    path.write_text(text, newline="\n")
    for relative in ("server/sv_init.c", "server/sv_ccmds.c"):
        path = engine / relative
        text = path.read_text()
        # Both lookup lists preserve their established BSP preference.
        if '"maps/%s.ftew"' not in text:
            marker = '"maps/%s.hmp",'
            assert marker in text
            text = text.replace(marker, '"maps/%s.hmp", "maps/%s.ftew",')
        if relative.endswith("sv_ccmds.c"):
            marker = 'COM_EnumerateFiles(va("maps/%s*.map", partial), CompleteMapListExt, ctx);'
            if '"maps/%s*.ftew"' not in text:
                assert marker in text
                text = text.replace(marker, marker + '\n\t\tCOM_EnumerateFiles(va("maps/%s*.ftew", partial), CompleteMapListExt, ctx);')
        path.write_text(text, newline="\n")
    print("Installed FTEW module into", root)

if __name__ == "__main__":
    main()
