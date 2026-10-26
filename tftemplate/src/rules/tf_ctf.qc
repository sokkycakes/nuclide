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

/** @file tf_ctf.qc
Capture the Flag. Each team has an item_teamflag and a func_capturezone;
bring the enemy's flag to your zone. The first team to tf_ctf_capturelimit
captures wins the round. If the round timer runs out, the team with more
captures wins, otherwise it's a stalemate. */

var float autocvar_tf_ctf_capturelimit = 3.0f;
var float autocvar_tf_ctf_roundtime = 600.0f;
var float autocvar_tf_ctf_flaghome = 0.0f;

float g_ctfCaps[3];

string
Mode_Name(void)
{
	return ("ctf");
}

void
Mode_Init(void)
{
	float flagCount = 0;

	for (entity e = world; (e = TFServer_NextObjective(e));) {
		if (e.tf_objective == TFOBJ_FLAG) {
			flagCount++;
		}
	}

	if (flagCount == 0) {
		print("^1TF template CTF: this map has no item_teamflag. Add some in maps/<map>_tf_ctf.add.\n");
	}
}

void
Mode_RoundStart(void)
{
	g_ctfCaps[1] = g_ctfCaps[2] = 0;
	teams.SetScore(TF_TEAM_RED, 0);
	teams.SetScore(TF_TEAM_BLU, 0);
}

float
Mode_SetupTime(void)
{
	return (0);
}

float
Mode_RoundTime(void)
{
	return (autocvar_tf_ctf_roundtime);
}

void
Mode_Frame(void)
{
}

float
Mode_TimeUp(void)
{
	if (g_ctfCaps[1] > g_ctfCaps[2]) {
		return (TF_TEAM_RED);
	} else if (g_ctfCaps[2] > g_ctfCaps[1]) {
		return (TF_TEAM_BLU);
	}

	return (TF_TEAM_NONE);
}

void
Mode_Event(entity activator, string eventName, string eventData)
{
	float flagTeam = stof(eventData);

	switch (eventName) {
	case "TF_FlagPickup":
		TF_Announce(sprintf("%s picked up %s's flag.", activator.netname, TF_TeamName(flagTeam)));
		break;
	case "TF_FlagDropped":
		TF_Announce(sprintf("%s's flag was dropped.", TF_TeamName(flagTeam)));
		break;
	case "TF_FlagReturned":
		TF_Announce(sprintf("%s's flag returned.", TF_TeamName(flagTeam)));
		break;
	case "TF_FlagCaptured":
		float capTeam = activator.team;
		g_ctfCaps[capTeam] += 1;
		teams.AddScore((int)capTeam, 1);
		activator.frags += 2;
		TF_Announce(sprintf("%s captured %s's flag! (%d/%d)", activator.netname,
			TF_TeamName(flagTeam), g_ctfCaps[capTeam], autocvar_tf_ctf_capturelimit));

		if (autocvar_tf_ctf_capturelimit > 0 && g_ctfCaps[capTeam] >= autocvar_tf_ctf_capturelimit) {
			TF_RoundWin(capTeam, "Capture limit reached.");
		}
		break;
	}
}

void
Mode_HUD(void)
{
	string caps = sprintf("%d %d", g_ctfCaps[1], g_ctfCaps[2]);

	if (serverinfo.GetString("tf_caps") != caps) {
		serverinfo.SetString("tf_caps", caps);
	}
}

/** Flags can only be taken while the round is live. */
float
TFRules_AllowFlagPickup(entity playerEnt, float flagTeam)
{
	return TF_ObjectivesLive();
}

/** With tf_ctf_flaghome 1, your own flag has to be home to score. */
float
TFRules_AllowFlagCapture(entity carrierEnt, float carriedTeam)
{
	if (TF_ObjectivesLive() == false) {
		return (false);
	}

	if (autocvar_tf_ctf_flaghome) {
		for (entity e = world; (e = TFServer_NextObjective(e));) {
			if (e.tf_objective == TFOBJ_FLAG && e.team == carrierEnt.team && e.tf_flagState != TFFLAG_HOME) {
				return (false);
			}
		}
	}

	return (true);
}
