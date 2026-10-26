/*
 * Copyright (c) 2026 sokkycakes
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF MIND, USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

void
Game_Worldspawn(void)
{
#ifdef BW_BOTS
	bw_init();
#endif
}

/** Picks the game mode when g_gametype isn't set, from the map name's prefix
like Team Fortress 2 does: ctf_ maps run tf_ctf, cp_ maps tf_cp, koth_
maps tf_koth and pl_ maps tf_pl. Anything else falls back to tf_ctf. */
string
Game_DefaultRules(void)
{
	string gameType = cvars.GetString("g_gametype");

	if (STRING_SET(gameType)) {
		return (gameType);
	}

	if (substring(mapname, 0, 4) == "ctf_") {
		gameType = "tf_ctf";
	} else if (substring(mapname, 0, 3) == "cp_") {
		gameType = "tf_cp";
	} else if (substring(mapname, 0, 5) == "koth_") {
		gameType = "tf_koth";
	} else if (substring(mapname, 0, 3) == "pl_") {
		gameType = "tf_pl";
	} else {
		gameType = "tf_ctf";
	}

	/* the overlay loader and entity filters read it back */
	cvars.SetString("g_gametype", gameType);
	return (gameType);
}
