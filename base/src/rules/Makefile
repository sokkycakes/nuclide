QCC=fteqcc

all:
	@python -c "import os; os.makedirs('../../progs', exist_ok=True)"
	$(QCC) $(CFLAGS) deathmatch.src
	$(QCC) $(CFLAGS) singleplayer.src
	$(QCC) $(CFLAGS) invasion.src
	$(QCC) $(CFLAGS) domination.src
	$(QCC) $(CFLAGS) lastmanstanding.src
	$(QCC) $(CFLAGS) teamdm.src
	$(QCC) $(CFLAGS) duel.src
