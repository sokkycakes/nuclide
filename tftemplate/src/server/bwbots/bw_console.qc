/* Bulwark bot framework: console commands. The game's ConsoleCmd passes
 * lines to bw_console_command. ISC licence, see LICENSE. */

void bw_console_register(void)
{
	registercommand("bot_debug", "bot_debug <behavior|look|path|animation|locomotion|vision|hearing|events|errors|*|none>...");
	registercommand("bot_debug_filter", "bot_debug_filter [entnum|name]...: limit debug output to these bots");
	registercommand("bot_status", "lists the bots with position, health and actions");
	registercommand("bot_command", "bot_command <text>: sends a command string to the bots");
	registercommand("bot_delete_all", "bot_delete_all [team]");
	registercommand("bot_move_to_cursor", "tells the bots to go where the player is looking");
}

entity bw_first_client(void) { return findflags(world, flags, FL_CLIENT); }

float bw_debug_category(string s)
{
	switch (strtolower(s)) {
	case "behavior": case "behaviour": return BWD_BEHAVIOR;
	case "look": return BWD_LOOK;
	case "path": return BWD_PATH;
	case "animation": return BWD_ANIMATION;
	case "locomotion": return BWD_LOCOMOTION;
	case "vision": return BWD_VISION;
	case "hearing": return BWD_HEARING;
	case "events": return BWD_EVENTS;
	case "errors": return BWD_ERRORS;
	case "*": case "all": return BWD_ALL;
	}
	return 0;
}

void bw_status(void)
{
	BWBot b;
	print(sprintf("%g bots\n", bw_nbots));
	for (b = bw_bots; b; b = b.m_bot_next)
		print(sprintf("#%d %s team %g hp %g at %v: %s\n", num_for_edict(b), b.BotName(), b.team, b.health,
		      b.origin, b.m_intention.StackString()));
}

float bw_console_command(string line)
{
	float argc = tokenize_console(line), i, c, tm;
	string cmd = strtolower(argv(0));
	BWBot b, n;
	entity pl;

	switch (cmd) {
	case "bot_debug":
		if (argc < 2) {
			print(sprintf("bot debug flags %g\n", bw_debug_flags));
			return TRUE;
		}
		bw_debug_flags = 0;
		for (i = 1; i < argc; i++) {
			c = bw_debug_category(argv(i));
			if (!c && strtolower(argv(i)) != "none" && argv(i) != "0")
				print(sprintf("bot_debug: unknown category %s\n", argv(i)));
			bw_debug_flags |= c;
		}
		return TRUE;
	case "bot_debug_filter":
		for (i = 0; i < bw_debug_nfilter; i++)
			strunzone(bw_debug_filter[i]);
		bw_debug_nfilter = 0;
		/* argv() strings are temporary: keep copies */
		for (i = 1; i < argc && bw_debug_nfilter < 8; i++)
			bw_debug_filter[bw_debug_nfilter++] = strzone(argv(i));
		return TRUE;
	case "bot_status":
		bw_status();
		return TRUE;
	case "bot_command":
		bw_ev_clear();
		bw_ev_s1 = substring(line, argv_start_index(1), -1);
		bw_send(world, BWE_CMD_STRING);
		return TRUE;
	case "bot_delete_all":
		tm = (argc > 1) ? stof(argv(1)) : -1;
		for (b = bw_bots; b; b = n) {
			n = b.m_bot_next;
			if (tm < 0 || b.team == tm)
				b.BotRemove();
		}
		return TRUE;
	case "bot_move_to_cursor":
		pl = bw_first_client();
		if (!pl) {
			print("bot_move_to_cursor: no player\n");
			return TRUE;
		}
		makevectors(pl.v_angle);
		traceline(pl.origin + pl.view_ofs, pl.origin + pl.view_ofs + v_forward * 8192, MOVE_NORMAL, pl);
		bw_ev_clear();
		bw_ev_v1 = trace_endpos;
		bw_ev_f1 = 32;
		bw_send(world, BWE_CMD_APPROACH_POS);
		return TRUE;
	}
	return FALSE;
}
