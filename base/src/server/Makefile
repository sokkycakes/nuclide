QCC=fteqcc

# Output path is set by #pragma progs_dat in progs.src. Do not pass -o here: Win64 fteqcc (c781d13)
# can fault immediately when -o is used together with captured/redirected stdio (common in CI/IDE).
# -I../shared is unnecessary for this tree (includes are relative to progs.src / defs).
all:
	$(QCC) $(CFLAGS) progs.src
