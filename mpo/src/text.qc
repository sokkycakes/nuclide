/* text.qc: a stage's string tables (data/mpo/<stage>/text.txt from
 * mpo2bw.py, which reads minifont.fcx). FUN_000037b0(table, idx) in
 * BOOT.BIN returns string[table start + idx]. */

#define TXT_MAX		1024
#define TXT_MAXTAB	64

string g_str[TXT_MAX];
float g_nstr;
float g_tabhash[TXT_MAXTAB], g_tabstart[TXT_MAXTAB];
float g_ntab;

void
text_load(string stage)
{
	filestream fh = fopen(strcat("data/mpo/", stage, "/text.txt"), FILE_READ);
	string l;
	float i;
	if (fh < 0) {
		print(sprintf("^1text: no string tables for %s\n", stage));
		return;
	}
	while ((l = fgets(fh))) {
		if (tokenize(l) < 3)
			continue;
		if (argv(0) == "tab" && g_ntab < TXT_MAXTAB) {
			g_tabhash[g_ntab] = stof(argv(1));
			g_tabstart[g_ntab] = stof(argv(2));
			g_ntab++;
		} else if (argv(0) == "str") {
			i = stof(argv(1));
			if (i >= 0 && i < TXT_MAX) {
				g_str[i] = strzone(argv(2));
				if (i + 1 > g_nstr) g_nstr = i + 1;
			}
		}
	}
	fclose(fh);
}

/* FUN_000037b0; "" when the table isn't known (e.g. 0x7ffae2) */
string
text_get(float tab, float idx)
{
	for (float i = 0; i < g_ntab; i++)
		if (g_tabhash[i] == tab) {
			if (g_tabstart[i] + idx < g_nstr)
				return g_str[g_tabstart[i] + idx];
			return "";
		}
	return "";
}
