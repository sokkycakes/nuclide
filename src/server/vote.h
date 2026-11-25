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

/** @defgroup voting Voting
@brief Calling votes, evaluating them.
@ingroup server

# Voting System {#voting}

When the console variable `mp_allowvote` is set to 1, players are allowed access to the `callvote` command.  

They have access to the following subcommands:

### callvote map [mapname]

Will request a map change to the proposed map. Will alert when the map does not exist on the server.

### callvote gametype [mode]

Requests a different game type (`g_gametype`, a rules progs in `progs/`), then
loads the current map again with it.

### callvote kick [player name]

Requests a player to be kicked.

### callvote timelimit

Requests an adjustment to the timelimit.

### callvote fraglimit

Requests an adjustment to the fraglimit.

### callvote map_restart (or restart)

Requests the map to restart, without altering the [map cycle](@ref mapcycle).

### callvote nextmap

Requests a change to the next map.

Players and spectators may call and answer votes (`vote yes`, `vote no`, bound
to F1 and F2); bots neither vote nor count. A vote passes once more than half
of the voters say yes, or when the 30 seconds run out with more yes than no.
In game, `menu_callvote` (the pause page's Call a Vote) opens a window with
the maps, game types and players to vote on.

@{

*/

var string g_strVoteCmd;
var float g_flVoteTime;
var int g_iVoteState;
var int autocvar_mp_allowvote = TRUE;

enum
{
	VOTE_INACTIVE,
	VOTE_INPROGRESS,
	VOTE_PASSED
};

void Vote_End(void);
void Vote_Reset(void);
void Vote_Passed(void);
void Vote_Failed(void);
void Vote_Frame(void);
void Vote_InitiateVote(string);
void CSEv_VoteY(void);
void CSEv_VoteN(void);
void CSEv_CallVote_s(string);
void Vote_Init(void);

/** @} */ // end of voting
