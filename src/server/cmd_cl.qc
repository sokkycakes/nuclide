/*
 * Copyright (c) 2024 Vera Visions LLC.
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

/* Cycle index for `arena` / `arena next` across MGE deathmatch spots. */
float g_arenaSpot;

static void
Cmd_ArenaPlace(ncClient sender, entity spot)
{
	vector org;
	int i;

	if (!spot) {
		return;
	}

	org = spot.origin;
	for (i = 0; i < 64; i++) {
		tracebox(org, sender.mins, sender.maxs, org, MOVE_NORMAL, sender);
		if (!trace_startsolid) {
			break;
		}
		org[2] += 1.0;
	}

	sender.origin = org;
	sender.angles = spot.angles;
	sender.v_angle = spot.angles;
	sender.velocity = [0, 0, 0];
	setorigin(sender, org);
	sender.SendFlags |= (PLAYER_ORIGIN | PLAYER_ANGLES);

	WriteByte(MSG_MULTICAST, SVC_CGAMEPACKET);
	WriteByte(MSG_MULTICAST, EV_ANGLE);
	WriteFloat(MSG_MULTICAST, spot.angles[0]);
	WriteFloat(MSG_MULTICAST, spot.angles[1]);
	WriteFloat(MSG_MULTICAST, spot.angles[2]);
	msg_entity = sender;
	multicast([0, 0, 0], MULTICAST_ONE_R);
}

static void
Cmd_ArenaTeleport(ncClient sender, int commandArguments)
{
	entity e;
	entity pick;
	string arg;
	string filter;
	string lastArena;
	float count;
	float want;
	float step;
	float listed;

	arg = "";
	filter = "";
	step = 1;
	if (commandArguments >= 2) {
		arg = argv(1);
	}

	if (arg == "list") {
		lastArena = "";
		listed = 0;
		for (e = find(world, classname, "info_player_deathmatch"); e;
			e = find(e, classname, "info_player_deathmatch")) {
			if (!STRING_SET(e.message)) {
				continue;
			}
			if (e.message == lastArena) {
				continue;
			}
			lastArena = e.message;
			listed = listed + 1;
			sprint(sender, PRINT_HIGH, sprintf("%g. %s\n", listed, e.message));
		}
		if (listed == 0) {
			sprint(sender, PRINT_HIGH, "No MGE arena spots on this map.\n");
		}
		return;
	}

	if (arg == "prev") {
		step = -1;
	} else if (arg == "next" || arg == "") {
		step = 1;
	} else {
		/* Partial arena name filter, then cycle within matches. */
		filter = arg;
		step = 1;
	}

	count = 0;
	for (e = find(world, classname, "info_player_deathmatch"); e;
		e = find(e, classname, "info_player_deathmatch")) {
		if (!STRING_SET(e.message)) {
			continue;
		}
		if (STRING_SET(filter) && strstrofs(e.message, filter) < 0) {
			continue;
		}
		count = count + 1;
	}

	if (count < 1) {
		sprint(sender, PRINT_HIGH, "No matching arena spots.\n");
		return;
	}

	g_arenaSpot = g_arenaSpot + step;
	while (g_arenaSpot < 0) {
		g_arenaSpot = g_arenaSpot + count;
	}
	while (g_arenaSpot >= count) {
		g_arenaSpot = g_arenaSpot - count;
	}

	want = 0;
	pick = world;
	for (e = find(world, classname, "info_player_deathmatch"); e;
		e = find(e, classname, "info_player_deathmatch")) {
		if (!STRING_SET(e.message)) {
			continue;
		}
		if (STRING_SET(filter) && strstrofs(e.message, filter) < 0) {
			continue;
		}
		if (want == g_arenaSpot) {
			pick = e;
			break;
		}
		want = want + 1;
	}

	if (!pick) {
		sprint(sender, PRINT_HIGH, "Arena spot lookup failed.\n");
		return;
	}

	Cmd_ArenaPlace(sender, pick);
	sprint(sender, PRINT_HIGH, sprintf("Arena: %s (%g/%g)\n", pick.message, g_arenaSpot + 1, count));
}

bool
Cmd_ParseClientCommand(ncClient sender, string cmd, int commandArguments)
{
	switch (argv(0)) {
	case "say":
		if (commandArguments == 2) {
			g_grMode.ChatMessageAll(sender, argv(1));
		} else {
			g_grMode.ChatMessageAll(sender, substring(cmd, 4, -1));
		}
		break;
	case "say_team":
		if (commandArguments == 2) {
			g_grMode.ChatMessageTeam(sender, argv(1));
		} else {
			g_grMode.ChatMessageTeam(sender, substring(cmd, 9, -1));
		}
		break;
	case "spectate":
		if (is.Player(sender)) {
			break;
		}

		ncPlayer pl = (ncPlayer)sender;
		pl.MakeSpectator();
		break;
	case "play":
		if (sender.classname != "spectator") {
			break;
		}

		EntityDef_SpawnClassname("player");
		PutClientInServer();
		break;
	case "specTarget":
		/* observer list (client VGUI_Observers) picked a player to chase.
		   Reuses the already-networked spectator target field; no new
		   protocol, just this command verb on the existing channel. */
		if (sender.classname != "spectator") {
			break;
		}

		float wishEntity = stof(argv(1));
		entity wishTarget = edict_num(wishEntity);

		/* must be a live in-game player and not our own client slot */
		if (!wishTarget || wishTarget == sender
			|| num_for_edict(wishTarget) == num_for_edict(sender)) {
			break;
		}

		ncSpectator spec = (ncSpectator)sender;

		if (!spec.IsValidChaseTarget(wishTarget)) {
			break;
		}

		spec.m_spectatingEntity = wishEntity;

		/* leaving free-fly: engage a chase camera so tracking kicks in */
		if (spec.m_spectatingMode == SPECMODE_FREE) {
			spec.m_spectatingMode = SPECMODE_THIRDPERSON;
		}

		spec.m_spectatingFlags &= ~(SPECFLAG_MODE_RELEASED | SPECFLAG_TARGET_RELEASED);
		spec.WarpToTarget();
		break;
	case "setpos":
		printf("%i %S\n", commandArguments, cmd);
		if (cvar("sv_cheats") == 1) {
			if (commandArguments == 2) { /* setpos "0 0 0" */
				setorigin(sender, stov(argv(1)));
			} else if (commandArguments == 3) {  /* setpos "0 0 0" "0 0 0" */
				setorigin(sender, stov(argv(1)));
			} else if (commandArguments == 4) { /* setpos 0 0 0 */
				setorigin(sender, [stof(argv(1)), stof(argv(2)), stof(argv(3))]);
			} else if (commandArguments == 7) { /* setpos 0 0 0 0 0 0 */
				setorigin(sender, [stof(argv(1)), stof(argv(2)), stof(argv(3))]);
			}
		}

		break;
	case "arena":
		/* Cycle/teleport across MGE info_player_deathmatch spots (message=arena name). */
		Cmd_ArenaTeleport(sender, commandArguments);
		break;
	case "timeleft":
		string timestring;
		float timeleft;
		timeleft = cvar("timelimit") - (time / 60);
		timestring = Util_TimeToString(timeleft);
		bprint(PRINT_CHAT, sprintf("we have %s minutes remaining", timestring));
		break;
	case "listInventory":
		ncActor_ListInventory(sender);
		break;
	case "giveInventoryItem":
		(ncActor)sender.GiveItem(argv(1));
		break;
	case "removeInventoryItem":
		(ncActor)sender.RemoveItem(argv(1));
		break;
	case "removeAllInventoryItems":
		(ncActor)sender.RemoveAllItems(false);
		break;
	case "listAmmo":
		Ammo_DebugList();
		break;
	case "joinTeam":
		g_grMode.PlayerRequestTeam((ncPlayer)sender, (int)stoi(argv(1)));
		break;
	case "nuclide_abi_grapple":
		/* Compatibility shim: old cmd callers still work; route via hero actions. */
		if (is.Player(sender)) {
			ncPlayer pl = (ncPlayer)sender;
			if (argv(1) == "1") {
				HeroActions_HeroToolPress(pl);
			} else {
				HeroActions_HeroToolRelease(pl);
			}
		}
		break;
	case "hero_guard":
		if (is.Player(sender)) {
			HeroActions_SetGuardHeld((ncPlayer)sender, argv(1) == "1");
		}
		break;
	case "hero_melee":
		if (is.Player(sender) && argv(1) == "1") {
			HeroActions_MeleePress((ncPlayer)sender);
		}
		break;
	case "hero_action":
		if (is.Player(sender)) {
			HeroActions_RequestSlot((ncPlayer)sender, stoi(argv(1)), argv(2));
		}
		break;
	case "weapon_mode":
		if (is.Player(sender)) {
			HeroActions_CycleWeaponMode((ncPlayer)sender);
		}
		break;
	case "stiletto_pred_replay":
		if (is.Player(sender)) {
			Stiletto_PredReplayCheck(sender);
		}
		break;
	default:
		clientcommand(sender, cmd);
	}
}
