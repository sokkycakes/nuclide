from pathlib import Path
p=Path('../workspace/fteqw/_worktrees/webcore-cpu-renderer/plugins/webcore/webcore.c')
s=p.read_text(encoding='utf-8')
a=s.index('static WCHAR webcore_font_paths[3]'); b=s.index('static int WebCore_EnsureHost',a)
chunk=s[a:b].replace('webcore_font_paths[3]','webcore_font_paths[4]').replace('i < 3','i < 4').replace('"data/web/lobby-menu/assets/fonts/Inter-Bold.ttf"','"data/web/lobby-menu/assets/fonts/Inter-Bold.ttf",\n        "data/web/ql-menu/assets/standard_07_57.ttf"')
p.write_text(s[:a]+chunk+s[b:],encoding='utf-8')
