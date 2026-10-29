/* main.qc: CSQC entry points for the MPO menu test game. */

void
CSQC_Init(float apilevel, string enginename, float engineversion)
{
	text_load("r_main01");
	pause_init();
	registercommand("mpo_pause", "Open or close the MGS:PO pause menu");
	registercommand("mpo_laynode", "Print a pause menu node's state");
}

float
CSQC_ConsoleCommand(string cmd)
{
	tokenize(cmd);
	if (argv(0) == "mpo_pause") {
		if (g_pmstate == PM_CLOSED)
			pause_open();
		else if (g_pmstate == PM_IDLE)
			pause_close();
		return 1;
	}
	if (argv(0) == "mpo_laynode") {
		/* mpo_laynode <id>: print a pause menu node's live state */
		entity n = lay_nodebyid(g_pm, stof(argv(1)));
		if (n)
			print(sprintf("node %d parent %d hash %x vis %d pos %v hid %d txt %s\n", n.n_id, n.n_parent, n.n_hash, n.n_vis, [n.n_px, n.n_py], n.n_whid, n.n_txt));
		return 1;
	}
	return 0;
}

float
CSQC_InputEvent(float evtype, float scanx, float chary, float devid)
{
	if (evtype == IE_KEYDOWN)
		return pause_key(scanx);
	if (evtype == IE_KEYUP)
		return g_pmstate != PM_CLOSED;
	return 0;
}

void
CSQC_UpdateView(float w, float h, float focus)
{
	clearscene();
	setproperty(VF_MIN, '0 0');
	setproperty(VF_SIZE, [w, h]);
	setproperty(VF_DRAWENGINESBAR, 0);
	setproperty(VF_DRAWCROSSHAIR, 0);
	/* this progs has no player prediction; view from the local player */
	setproperty(VF_ORIGIN, (vector)getentity(player_localentnum, GE_ORIGIN) + '0 0 28');
	setproperty(VF_ANGLES, input_angles);
	addentities(MASK_ENGINE);
	renderscene();
	lay_setview([w, h]);
	pause_draw();
}
