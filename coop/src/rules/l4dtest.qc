/* Animation test stand-ins: Left 4 Dead's Hunter and Tank as one box per
 * bone. Their models are game files kept out of git (models/infected/
 * hunter.mdl and hulk.mdl, with anim_hunter/anim_hulk .mdl and .ani);
 * Bulwark's Source plugin reads them, and "src_boneboxes 1" draws a box per
 * bone in place of the mesh.
 *
 *   coop_l4d hunter|tank [sequence]   one in front of you, facing you
 *   coop_l4danim <sequence> [all]     the one you look at (or every one) plays it
 *   coop_l4dlist [filter]             the model's sequence names
 *   coop_l4dclear                     removes them all
 *
 * Sequences are the model's own names (Idle, Run_1, Lunge_While_Running_01),
 * and each blended sequence's other animations as "<sequence>:<animation>"
 * (Run_1:a_RunN). */

#define L4DTEST_MAX 32

entity g_l4dTest[L4DTEST_MAX];

static string
L4DTest_Class(string which)
{
	switch (strtolower(which)) {
	case "hunter":
		return "l4d_hunter";
	case "tank":
	case "hulk":
		return "l4d_tank";
	default:
		return "";
	}
}

static void
L4DTest_Play(entity e, string sequence)
{
	if (frameforname(e.modelindex, sequence) < 0) {
		print(sprintf("coop_l4danim: %s has no sequence %S (coop_l4dlist shows them)\n", e.model, sequence));
		return;
	}

	ents.Input(e, "PlayNamedSequence", sequence, world);
	print(sprintf("%s plays %s (%g s)\n", e.classname, sequence,
		frameduration(e.modelindex, frameforname(e.modelindex, sequence))));
}

/* the test entity under the crosshair, else the newest one */
static entity
L4DTest_Aimed(entity pl)
{
	entity best = world;
	float bestDot = 0.9f;
	vector eye = pl.origin + pl.view_ofs;
	makevectors(pl.v_angle);

	for (int i = 0i; i < L4DTEST_MAX; i++) {
		entity e = g_l4dTest[i];

		if (!e || wasfreed(e)) {
			continue;
		}

		float d = normalize(e.origin + [0, 0, 32] - eye) * v_forward;

		if (d > bestDot) {
			bestDot = d;
			best = e;
		}
	}

	if (best) {
		return (best);
	}

	for (int i = L4DTEST_MAX - 1i; i >= 0i; i--) {
		if (g_l4dTest[i] && !wasfreed(g_l4dTest[i])) {
			return (g_l4dTest[i]);
		}
	}

	return (world);
}

static void
L4DTest_Spawn(entity pl, string which, string sequence)
{
	string className = L4DTest_Class(which);
	int slot = -1i;

	if (className == "") {
		print("coop_l4d: hunter or tank\n");
		return;
	}

	for (int i = 0i; i < L4DTEST_MAX; i++) {
		if (!g_l4dTest[i] || wasfreed(g_l4dTest[i])) {
			slot = i;
			break;
		}
	}

	if (slot < 0i) {
		print("coop_l4d: too many; coop_l4dclear removes them\n");
		return;
	}

	/* 160 units ahead (less if a wall is closer), standing on the floor,
	 * and stepped aside from any already there */
	vector eye = pl.origin + pl.view_ofs;
	makevectors([0, pl.v_angle[1], 0]);
	traceline(eye, eye + v_forward * 160, MOVE_NOMONSTERS, pl);
	vector spot = trace_endpos - v_forward * 24;

	for (int tries = 0i; tries < 8i; tries++) {
		bool taken = false;

		for (int i = 0i; i < L4DTEST_MAX; i++) {
			entity placed = g_l4dTest[i];

			if (placed && !wasfreed(placed) && vlen([placed.origin[0] - spot[0], placed.origin[1] - spot[1], 0]) < 48) {
				taken = true;
			}
		}

		if (!taken) {
			break;
		}

		spot += v_right * 64;
	}

	traceline(spot, spot - [0, 0, 512], MOVE_NOMONSTERS, pl);

	entity e = ents.Create(className, trace_endpos);
	e.angles = [0, pl.v_angle[1] + 180, 0];
	g_l4dTest[slot] = e;
	print(sprintf("coop_l4d: %s at %v\n", className, trace_endpos));

	if (sequence != "") {
		L4DTest_Play(e, sequence);
	}
}

bool
L4DTest_Command(entity pl, string cmd)
{
	switch (cmd) {
	case "coop_l4d":
		L4DTest_Spawn(pl, argv(1), argv(2));
		return (true);
	case "coop_l4danim":
		if (argv(2) == "all") {
			for (int i = 0i; i < L4DTEST_MAX; i++) {
				if (g_l4dTest[i] && !wasfreed(g_l4dTest[i])) {
					L4DTest_Play(g_l4dTest[i], argv(1));
				}
			}
		} else {
			entity target = L4DTest_Aimed(pl);

			if (target) {
				L4DTest_Play(target, argv(1));
			} else {
				print("coop_l4danim: spawn one first (coop_l4d hunter|tank)\n");
			}
		}
		return (true);
	case "coop_l4dlist":
		entity listed = L4DTest_Aimed(pl);

		if (!listed) {
			print("coop_l4dlist: spawn one first (coop_l4d hunter|tank)\n");
			return (true);
		}

		float count = modelframecount(listed.modelindex);

		for (float f = 0; f < count; f++) {
			string seqName = frametoname(listed.modelindex, f);

			if (argv(1) == "" || strstrofs(strtolower(seqName), strtolower(argv(1))) >= 0) {
				print(sprintf("%3d %s (%g s)\n", f, seqName, frameduration(listed.modelindex, f)));
			}
		}
		return (true);
	case "coop_l4dclear":
		for (int i = 0i; i < L4DTEST_MAX; i++) {
			if (g_l4dTest[i] && !wasfreed(g_l4dTest[i])) {
				remove(g_l4dTest[i]);
			}

			g_l4dTest[i] = world;
		}
		return (true);
	}

	return (false);
}
