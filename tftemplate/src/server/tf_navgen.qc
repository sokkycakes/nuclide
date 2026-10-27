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

/** @file tf_navgen.qc
Builds a bot waypoint graph for maps that ship without one (TF2 maps have
a .nav, which neither bot system reads), and saves it as data/<map>.way.

`tf_nav_generate [spacing]` walks the map with the player's box from every
spawn point, path_track and objective: from each waypoint it tries a step
of `spacing` units (default 64) in eight directions. It walks up stairs and
slopes, jumps up ledges a jump clears (from tf_player_base's pm_jumpheight
and the gravity; higher ones that a crouch jump clears also get LF_CROUCH)
and drops down ledges of up to TFNAV_DROP units, one way. Doors, trains and
spawn room walls are made non-solid while it runs, so the graph goes
through them. Spots inside a trigger_hurt are left out, and waypoints held
up only by a corner of the box (the edge of a ramp or a ledge) are moved
onto the floor or dropped.

The file is Nuclide's waypoint format, which both Nuclide's botlib and the
Bulwark bot framework read. Jump links carry LF_JUMP. */

#define TFNAV_STEP 18
#define TFNAV_SUBSTEPS 4
/* crouching in the air pulls the feet up by half the height lost: the
   player box is centred, 74 units standing and 38 crouched */
#define TFNAV_CROUCHGAIN 18
#define TFNAV_DROP 250
#define TFNAV_MAXNODES 16384
#define TFNAV_MAXLINKS 8

static vector *g_navPos;
static int *g_navLinkTo;
static int *g_navLinkFlags;
static int *g_navLinkCount;
static int g_navCount;
static float g_navSpacing;
static float g_navJump;
static float g_navCrouchJump;
static vector g_navMins;
static vector g_navMaxs;
static vector g_navSettled;
static vector g_navNudges[8] = {
	[16, 0, 0], [-16, 0, 0], [0, 16, 0], [0, -16, 0],
	[24, 0, 0], [-24, 0, 0], [0, 24, 0], [0, -24, 0]
};
static float g_navCells;
static entity *g_navHurt;
static int g_navHurtCount;
static vector g_navDirs[8] = {
	[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0],
	[1, 1, 0], [1, -1, 0], [-1, 1, 0], [-1, -1, 0]
};

static string
TFNav_CellKey(vector pos, float zBucket)
{
	return sprintf("%d %d %d", rint(pos[0] / g_navSpacing), rint(pos[1] / g_navSpacing), zBucket);
}

/** The waypoint already at pos (same grid cell, within a step up or down),
or -1. */
static int
TFNav_Find(vector pos)
{
	float zBucket = floor(pos[2] / 32);

	for (float z = zBucket - 1; z <= zBucket + 1; z++) {
		string cellNodes = hash_get(g_navCells, TFNav_CellKey(pos, z), "");
		float nodeCount = tokenize(cellNodes);

		for (float i = 0; i < nodeCount; i++) {
			int nodeID = stoi(argv(i));

			if (fabs(g_navPos[nodeID][2] - pos[2]) <= TFNAV_STEP + 2) {
				return (nodeID);
			}
		}
	}

	return (-1i);
}

static bool
TFNav_Hurts(vector pos)
{
	for (int i = 0i; i < g_navHurtCount; i++) {
		entity hurtEnt = g_navHurt[i];

		if (pos[0] + g_navMaxs[0] > hurtEnt.absmin[0] && pos[0] + g_navMins[0] < hurtEnt.absmax[0]
			&& pos[1] + g_navMaxs[1] > hurtEnt.absmin[1] && pos[1] + g_navMins[1] < hurtEnt.absmax[1]
			&& pos[2] + g_navMaxs[2] > hurtEnt.absmin[2] && pos[2] + g_navMins[2] < hurtEnt.absmax[2]) {
			return (true);
		}
	}

	return (false);
}

static int
TFNav_Add(vector pos)
{
	if (g_navCount >= TFNAV_MAXNODES) {
		return (-1i);
	}

	int nodeID = g_navCount++;
	g_navPos[nodeID] = pos;
	g_navLinkCount[nodeID] = 0i;

	string cellKey = TFNav_CellKey(pos, floor(pos[2] / 32));
	string cellNodes = hash_get(g_navCells, cellKey, "");
	hash_add(g_navCells, cellKey, strcat(cellNodes, " ", itos(nodeID)), EV_STRING | HASH_REPLACE);
	return (nodeID);
}

static void
TFNav_Link(int fromID, int toID, int linkFlags)
{
	int linkCount = g_navLinkCount[fromID];

	if (fromID == toID || linkCount >= TFNAV_MAXLINKS) {
		return;
	}

	for (int i = 0i; i < linkCount; i++) {
		if (g_navLinkTo[fromID * TFNAV_MAXLINKS + i] == toID) {
			return;
		}
	}

	g_navLinkTo[fromID * TFNAV_MAXLINKS + linkCount] = toID;
	g_navLinkFlags[fromID * TFNAV_MAXLINKS + linkCount] = linkFlags;
	g_navLinkCount[fromID] = linkCount + 1i;
}

/** Where a player standing near pos would stand: drops onto the floor below
(up to `dropLimit`). Returns false when there is no floor or no room. */
static bool
TFNav_Ground(vector pos, float dropLimit)
{
	tracebox(pos, g_navMins, g_navMaxs, pos - [0, 0, dropLimit], MOVE_NOMONSTERS, world);

	if (trace_startsolid || trace_allsolid || trace_fraction >= 1.0f) {
		return (false);
	}

	if (trace_plane_normal[2] < 0.7f) {
		return (false);
	}

	return (true);
}

/** Tries to move from `fromPos` towards `toXY` (only x and y are used):
walking with a step up, or jumping up a ledge. On success trace_endpos is
where the player lands and the return value is the link's flags, or -1. */
static int
TFNav_Move(vector fromPos, vector toXY)
{
	vector liftedFrom, liftedTo;

	/* walk in short steps, so slopes and stairs work: each one steps up
	   to TFNAV_STEP, moves across and settles on the floor below */
	vector walkPos = fromPos;
	bool walked = true;

	for (float part = 1; part <= TFNAV_SUBSTEPS; part++) {
		vector partXY = fromPos + (toXY - fromPos) * (part / TFNAV_SUBSTEPS);

		/* straight across first, as the player physics does, then up a
		   step (which needs the headroom) */
		liftedFrom = walkPos;
		liftedTo = [partXY[0], partXY[1], liftedFrom[2]];
		tracebox(liftedFrom, g_navMins, g_navMaxs, liftedTo, MOVE_NOMONSTERS, world);

		if (trace_startsolid || trace_fraction < 1.0f) {
			liftedFrom = walkPos + [0, 0, TFNAV_STEP];
			liftedTo = [partXY[0], partXY[1], liftedFrom[2]];
			tracebox(liftedFrom, g_navMins, g_navMaxs, liftedTo, MOVE_NOMONSTERS, world);

			if (trace_startsolid || trace_fraction < 1.0f) {
				walked = false;
				break;
			}
		}

		if (TFNav_Ground(liftedTo, TFNAV_STEP + TFNAV_DROP) == false) {
			return (-1i);
		}

		walkPos = trace_endpos;
	}

	if (walked) {
		trace_endpos = walkPos;
		return (0i);
	}

	/* jump up a ledge: room above us, then across. A plain jump first,
	   then a crouch jump, which clears TFNAV_CROUCHGAIN more */
	for (int crouched = 0i; crouched < 2i; crouched++) {
		float jumpHeight = (crouched) ? g_navCrouchJump : g_navJump;
		float lowest = (crouched) ? g_navJump : TFNAV_STEP;

		tracebox(fromPos, g_navMins, g_navMaxs, fromPos + [0, 0, jumpHeight], MOVE_NOMONSTERS, world);

		if (trace_fraction < 1.0f) {
			return (-1i);
		}

		liftedFrom = fromPos + [0, 0, jumpHeight];
		liftedTo = [toXY[0], toXY[1], liftedFrom[2]];
		tracebox(liftedFrom, g_navMins, g_navMaxs, liftedTo, MOVE_NOMONSTERS, world);

		if (trace_startsolid || trace_fraction < 1.0f) {
			continue;
		}

		/* only this kind of jump if a smaller one wouldn't do */
		if (TFNav_Ground(liftedTo, jumpHeight - lowest)) {
			return (crouched) ? (LF_JUMP | LF_CROUCH) : LF_JUMP;
		}
	}

	return (-1i);
}

/** Is the floor right under the middle of a player standing at pos? */
static bool
TFNav_Centred(vector pos)
{
	/* 20 below the feet: on a slope the box sits on its uphill edge */
	traceline(pos, pos + [0, 0, g_navMins[2] - 20], MOVE_NOMONSTERS, world);
	return (trace_fraction < 1.0f) ? true : false;
}

/** Waypoints on the edge of a ramp or a ledge, held up by a corner of the
box, are moved up to 24 units onto the floor (g_navSettled), or dropped. */
static bool
TFNav_Settle(vector pos)
{
	if (TFNav_Centred(pos)) {
		g_navSettled = pos;
		return (true);
	}

	for (int i = 0i; i < 8i; i++) {
		vector tryPos = pos + g_navNudges[i];

		tracebox(pos, g_navMins, g_navMaxs, tryPos, MOVE_NOMONSTERS, world);

		if (trace_startsolid || trace_fraction < 1.0f) {
			continue;
		}

		if (TFNav_Ground(tryPos + [0, 0, TFNAV_STEP], TFNAV_STEP * 2) == false) {
			continue;
		}

		vector groundPos = trace_endpos;

		if (TFNav_Centred(groundPos)) {
			g_navSettled = groundPos;
			return (true);
		}
	}

	return (false);
}

static int
TFNav_Seed(vector seedPos)
{
	vector snapped = [rint(seedPos[0] / g_navSpacing) * g_navSpacing, rint(seedPos[1] / g_navSpacing) * g_navSpacing, seedPos[2]];
	vector tryPos;

	for (int attempt = 0i; attempt < 2i; attempt++) {
		tryPos = (attempt == 0i) ? snapped : seedPos;

		if (TFNav_Ground(tryPos + [0, 0, TFNAV_STEP + 36], TFNAV_STEP + 36 + TFNAV_DROP)) {
			if (TFNav_Settle(trace_endpos) == false) {
				continue;
			}

			vector groundPos = g_navSettled;

			if (TFNav_Hurts(groundPos)) {
				continue;
			}

			int existing = TFNav_Find(groundPos);
			return (existing >= 0i) ? existing : TFNav_Add(groundPos);
		}
	}

	return (-1i);
}

/** Things that block players now but open up later. */
static bool
TFNav_IsMover(entity e)
{
	if (e.solid == SOLID_NOT || e.solid == SOLID_TRIGGER) {
		return (false);
	}

	if (e.movetype == MOVETYPE_PUSH) {
		return (true);
	}

	if (e.classname == "func_respawnroomvisualizer") {
		return (true);
	}

	return (false);
}

void
TF_NavGenerate(float nodeSpacing)
{
	float startTime = gettime(0);
	float *savedSolid;
	int entCount = 0i;
	entity e;

	g_navSpacing = (nodeSpacing > 16) ? nodeSpacing : 64;
	g_navMins = g_pmoveVars.GetStandingMins();
	g_navMaxs = g_pmoveVars.GetStandingMaxs();

	if (g_navMaxs[2] - g_navMins[2] <= 0) {
		g_navMins = VEC_HULL_MIN;
		g_navMaxs = VEC_HULL_MAX;
	}

	/* how high a standing jump goes: v^2 / 2g, less a margin */
	float jumpSpeed = stof(EntityDef_GetKeyValue("tf_player_base", "pm_jumpheight"));
	float jumpGravity = cvar("sv_gravity");

	if (jumpSpeed <= 0) {
		jumpSpeed = cvar("pm_jumpheight");
	}

	if (jumpGravity <= 0) {
		jumpGravity = 800;
	}

	g_navJump = max(TFNAV_STEP + 1, (jumpSpeed * jumpSpeed) / (2 * jumpGravity) - 2);
	g_navCrouchJump = g_navJump + TFNAV_CROUCHGAIN;
	g_navPos = memalloc(sizeof(vector) * TFNAV_MAXNODES);
	g_navLinkTo = memalloc(sizeof(int) * TFNAV_MAXNODES * TFNAV_MAXLINKS);
	g_navLinkFlags = memalloc(sizeof(int) * TFNAV_MAXNODES * TFNAV_MAXLINKS);
	g_navLinkCount = memalloc(sizeof(int) * TFNAV_MAXNODES);
	g_navCells = hash_createtab(4096, EV_STRING);
	g_navCount = 0i;

	/* doors, trains and spawn room walls get out of the way */
	for (e = world; (e = nextent(e));) {
		entCount++;
	}

	savedSolid = memalloc(sizeof(float) * (entCount + 1));
	entCount = 0i;

	for (e = world; (e = nextent(e));) {
		if (TFNav_IsMover(e)) {
			savedSolid[entCount] = e.solid;
			e.solid = SOLID_NOT;
			setorigin(e, e.origin);
		} else {
			savedSolid[entCount] = -1;
		}

		entCount++;
	}

	g_navHurtCount = 0i;

	for (e = world; (e = find(e, ::classname, "trigger_hurt"));) {
		g_navHurtCount++;
	}

	g_navHurt = memalloc(sizeof(entity) * (g_navHurtCount + 1i));
	g_navHurtCount = 0i;

	for (e = world; (e = find(e, ::classname, "trigger_hurt"));) {
		g_navHurt[g_navHurtCount++] = e;
	}

	/* seeds: spawn points, the cart's track and the objectives */
	for (e = world; (e = nextent(e));) {
		if (substring(e.classname, 0, 11) == "info_player" || e.classname == "path_track") {
			TFNav_Seed(e.origin);
		} else if (e.tf_objective && e.tf_objective != TFOBJ_CART) {
			TFNav_Seed((e.absmin + e.absmax) * 0.5);
		}
	}

	/* flood out from the seeds */
	for (int nodeID = 0i; nodeID < g_navCount; nodeID++) {
		vector fromPos = g_navPos[nodeID];

		for (int d = 0i; d < 8i; d++) {
			vector toXY = fromPos + g_navDirs[d] * g_navSpacing;
			int linkFlags = TFNav_Move(fromPos, toXY);

			if (linkFlags < 0i) {
				continue;
			}

			if (TFNav_Settle(trace_endpos) == false) {
				continue;
			}

			vector landPos = g_navSettled;

			if (TFNav_Hurts(landPos)) {
				continue;
			}

			int toID = TFNav_Find(landPos);

			if (toID < 0i) {
				toID = TFNav_Add(landPos);

				if (toID < 0i) {
					continue;
				}
			}

			TFNav_Link(nodeID, toID, linkFlags);
		}
	}

	/* put the movers back */
	entCount = 0i;

	for (e = world; (e = nextent(e));) {
		if (savedSolid[entCount] >= 0) {
			e.solid = savedSolid[entCount];
			setorigin(e, e.origin);
		}

		entCount++;
	}

	/* save it */
	int linkTotal = 0i;
	int jumpTotal = 0i;
	filestream wayFile = fopen(sprintf("%s.way", mapname), FILE_WRITE);

	if (wayFile < 0) {
		print(sprintf("tf_nav_generate: can't write %s.way\n", mapname));
	} else {
		fputs(wayFile, sprintf("%i\n", g_navCount));

		for (int i = 0i; i < g_navCount; i++) {
			int linkCount = g_navLinkCount[i];
			fputs(wayFile, sprintf("%v %f %i\n", g_navPos[i], g_navSpacing * 0.5f, linkCount));

			for (int j = 0i; j < linkCount; j++) {
				int toNode = g_navLinkTo[i * TFNAV_MAXLINKS + j];
				int flags = g_navLinkFlags[i * TFNAV_MAXLINKS + j];
				float cost = vlen(g_navPos[toNode] - g_navPos[i]);

				if (flags & LF_JUMP) {
					cost += (flags & LF_CROUCH) ? 128 : 64;
					jumpTotal++;
				}

				fputs(wayFile, sprintf(" %i %f %i\n", toNode, cost, flags));
				linkTotal++;
			}
		}

		fclose(wayFile);
		print(sprintf("tf_nav_generate: jumps up to %d units, crouch jumps up to %d\n", g_navJump, g_navCrouchJump));
	print(sprintf("tf_nav_generate: %i waypoints, %i links (%i jumps) in %.1f s, saved data/%s.way%s\n",
			g_navCount, linkTotal, jumpTotal, gettime(0) - startTime, mapname,
			(g_navCount >= TFNAV_MAXNODES) ? " (hit the waypoint limit: try a larger spacing)" : ""));
	}

	hash_destroytab(g_navCells);
	memfree(savedSolid);
	memfree(g_navHurt);
	memfree(g_navPos);
	memfree(g_navLinkTo);
	memfree(g_navLinkFlags);
	memfree(g_navLinkCount);
}
