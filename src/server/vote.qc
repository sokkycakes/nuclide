/*
 * Copyright (c) 2016-2022 Vera Visions LLC.
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

/*
=================
Vote_End
=================
*/
void
Vote_End(void)
{

	localcmd(sprintf("%s\n", g_strVoteCmd));
	g_flVoteTime = 0.0f;
	g_iVoteState = VOTE_INACTIVE;
}


/*
=================
Vote_Reset

Make sure all the cached stuff is reset.
=================
*/
void
Vote_Reset(void)
{
	serverinfo.SetFloat("votes_y", 0);
	serverinfo.SetFloat("votes_n", 0);
	serverinfo.SetString("vote_cmd", "");

	for (entity e = world; (e = next.Player(e));) {
		ncPlayer pl = (ncPlayer)e;
		pl.voted = 0;
	}
}

/*
=================
Vote_Passed

Called whenever enough people agreed, or time has run out with enougn YES's
=================
*/
void
Vote_Passed(void)
{
	g_flVoteTime = time + 5.0f;
	g_iVoteState = VOTE_PASSED;
	bprint(PRINT_CHAT, "Vote passed.\n");
	g_strVoteCmd = serverkey("vote_cmd");
	Vote_Reset();
}

/*
=================
Vote_Failed

Called whenever enough people disagreed, or time has run out below the limit
=================
*/
void
Vote_Failed(void)
{
	g_flVoteTime = 0.0;
	g_iVoteState = VOTE_INACTIVE;
	bprint(PRINT_CHAT, "Vote failed.\n");
	Vote_Reset();
}

/*
=================
Vote_Frame

Called in ServerFrame... every single frame.
=================
*/
void
Vote_Frame(void)
{
	if (time >= g_flVoteTime) {
		
		if (g_iVoteState == VOTE_INPROGRESS) {
			if (serverinfo.GetFloat("votes_y") > serverinfo.GetFloat("votes_n")) {
				Vote_Passed();
			} else {
				Vote_Failed();
			}
		} else if (g_iVoteState == VOTE_PASSED) { 
			Vote_End();
		}
	}
}

/* Anyone connected and human may vote: players and spectators (a Duel
   queue waits as spectators). Bots never vote, so they are not counted
   either, or a host alone with bots could never carry a vote. */
static bool
Vote_CanVote(entity voter)
{
	if (!voter || clienttype(voter) != CLIENTTYPE_REAL) {
		return (false);
	}
	return (true);
}

static float
Vote_CountVoters(void)
{
	float voters = 0;

	/* client slots are the first edicts; the first non-client ends them */
	for (entity eFind = nextent(world); eFind; eFind = nextent(eFind)) {
		float ct = clienttype(eFind);
		if (ct == CLIENTTYPE_NOTACLIENT) {
			break;
		}
		if (Vote_CanVote(eFind)) {
			voters++;
		}
	}
	return (voters);
}

/*
=================
CSEv_VoteY

'vote yes'
=================
*/
void
CSEv_VoteY(void)
{
	ncPlayer pl = (ncPlayer)self;

	/* No vote is in progress */
	if (g_iVoteState != VOTE_INPROGRESS) {
		return;
	}

	if (Vote_CanVote(self) == false) {
		return;
	}

	if (pl.voted) {
		return;
	}

	serverinfo.SetFloat("votes_y", serverinfo.GetFloat("votes_y") + 1);
	pl.voted = 1;

	float playernums = Vote_CountVoters();

	/* We need at least half the players agreeing. */
	if (serverinfo.GetFloat("votes_y") > rint(playernums / 2)) {
		Vote_Passed();
		return;
	}

	if (serverinfo.GetFloat("votes_n") + serverinfo.GetFloat("votes_y") == playernums) {
		g_flVoteTime = time + 0.0f;
	}
}

/*
=================
CSEv_VoteN

'vote no'
=================
*/
void
CSEv_VoteN(void)
{
	ncPlayer pl = (ncPlayer)self;

	/* No vote is in progress */
	if (g_iVoteState != VOTE_INPROGRESS) {
		return;
	}

	if (Vote_CanVote(self) == false) {
		return;
	}

	if (pl.voted) {
		return;
	}

	serverinfo.SetFloat("votes_n", serverinfo.GetFloat("votes_n") + 1);
	pl.voted = 1;

	float playernums = Vote_CountVoters();

	/* We need at least half the players disagreeing. */
	if (serverinfo.GetFloat("votes_n") > rint(playernums / 2)) {
		Vote_Failed();
		return;
	}

	if (serverinfo.GetFloat("votes_n") + serverinfo.GetFloat("votes_y") == playernums) {
		g_flVoteTime = time + 0.0f;
	}
}


/*
=================
Vote_InitiateVote

Send the info to the clients and set the timer up
=================
*/
void
Vote_InitiateVote(string votemsg)
{
	/* A vote is in progress */
	if (g_iVoteState != VOTE_INACTIVE) {
		return;
	}

	if (Vote_CanVote(self) == false) {
		return;
	}

	Vote_Reset();

	serverinfo.SetString("vote_cmd", votemsg);
	g_flVoteTime = time + 30.0f;
	g_iVoteState = VOTE_INPROGRESS;
}

/*
=================
CSEv_CallVote_s

Initiates a vote via the 'callvote' client command.
=================
*/
void 
CSEv_CallVote_s(string text)
{
	string voteCmd = "";

	if (autocvar_mp_allowvote == FALSE) {
		sprint(self, PRINT_CHAT, "Voting is turned off on this server (mp_allowvote 0).\n");
		return;
	}

	if (Vote_CanVote(self) == false) {
		return;
	}

	/* No vote is in progress */
	if (g_iVoteState != VOTE_INACTIVE) {
		sprint(self, PRINT_CHAT, "A vote is already in progress.\n");
		return;
	}

	tokenize(text);
	string voteType = strtolower(argv(0));
	string voteArg = argv(1);

	/* keep what reaches the server console to one plain word */
	if (strstrofs(voteArg, ";") >= 0 || strstrofs(voteArg, "\"") >= 0
		|| strstrofs(voteArg, "\n") >= 0) {
		sprint(self, PRINT_CHAT, "That vote has characters it can't use.\n");
		return;
	}

	switch (voteType) {
	case "map":
	case "changelevel":
		if (fileExists(sprintf("maps/%s.bsp", voteArg)) == false) {
			sprint(self, PRINT_CHAT, sprintf("Map '%s' not available on server.\n", voteArg));
			return;
		}
		voteCmd = sprintf("map %s", voteArg);
		break;
	case "gametype":
	case "g_gametype":
		voteArg = strtolower(voteArg);
		if (!STRING_SET(voteArg) || fileExists(sprintf("progs/%s.dat", voteArg)) == false) {
			sprint(self, PRINT_CHAT, sprintf("Game type '%s' not available on server.\n", voteArg));
			return;
		}
		/* g_gametype is read when a map loads: reload this one */
		voteCmd = sprintf("g_gametype %s; map %s", voteArg, mapname);
		break;
	case "kick":
		if (!STRING_SET(voteArg)) {
			sprint(self, PRINT_CHAT, "Usage: callvote kick <player name>\n");
			return;
		}
		voteCmd = sprintf("kick \"%s\"", voteArg);
		break;
	case "restart":
	case "map_restart":
		voteCmd = "map_restart";
		break;
	case "slowmo":
	case "timelimit":
	case "fraglimit":
		if (!STRING_SET(voteArg) || stof(voteArg) < 0) {
			sprint(self, PRINT_CHAT, sprintf("Usage: callvote %s <number>\n", voteType));
			return;
		}
		voteCmd = sprintf("%s %s", voteType, ftos(stof(voteArg)));
		break;
	case "nextmap":
		voteCmd = "nextmap";
		break;
	default:
		sprint(self, PRINT_CHAT, sprintf("Cannot callvote for '%s'. Votes: map, gametype, kick, restart, nextmap, timelimit, fraglimit.\n", argv(0)));
		return;
	}

	Vote_InitiateVote(voteCmd);
	bprint(PRINT_CHAT, sprintf("%s called a vote: %s (F1 yes, F2 no)\n", self.netname, voteCmd));
	CSEv_VoteY();
}

void 
Vote_Init(void)
{
	Vote_Reset();
}
