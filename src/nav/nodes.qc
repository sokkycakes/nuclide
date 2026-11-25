/*
 * Copyright (c) 2016-2024 Vera Visions LLC.
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

/* link two nodes together */
static void
Node_Link(graphNode_t *n1, graphNode_t *n2)
{
	local struct neighbour_s *n;
	int w2n = n2 - g_nodeGraph;

	for (int i = 0; i < n1->m_neighborCount; i++) {
		if (n1->m_neighborList[i].m_nodeID == w2n) {
			return;
		}
	}

	int idx = n1->m_neighborCount ++;
	n1->m_neighborList = (neighbour_s *)memreallocOld(n1->m_neighborList, \
											sizeof(*n1->m_neighborList), \
											idx, n1->m_neighborCount);

	n = n1->m_neighborList +idx;
	n->m_nodeID = w2n;
	n->m_travelCost = vlen(n2->m_origin - n1->m_origin);
	n->m_travelFlags = 0i;
}


/* loop through already existing nodes, test against them and link */
static void
Node_AutoLink(graphNode_t *new, entity nodeEntity)
{
	int x = new - g_nodeGraph;

	for (int i = 0; i < g_nodeCount; i++) {
		/* don't link to ourselves... */
		if (i == x) {
			continue;
		}

		/* can't use full player size, because steps = messy */
		tracebox(
			new->m_origin,
			[-16, -16, -16],
			[16, 16, 16],
			g_nodeGraph[i].m_origin,
			MOVE_NORMAL,
			nodeEntity
		);

		/* HACK!: work around c0a0e where info_nodes are blocked by the train */
		if (trace_ent.movetype == MOVETYPE_PUSH) {
			tracebox(
				new->m_origin,
				[-16, -16, -16],
				[16, 16, 16],
				g_nodeGraph[i].m_origin,
				MOVE_NORMAL,
				trace_ent
			);
		}

		/* line of sight blocked */
		if (trace_fraction < 1.0f) {
			continue;
		}

		Node_Link(new, &g_nodeGraph[i]);
		Node_Link(&g_nodeGraph[i], new);
	}
}

static void
Nodes_InsertNodeForClassname(string classn)
{
	for (entity a = world; (a = find(a, ::classname, classn));) {
		int iID = g_nodeCount++;
		g_nodeGraph = (graphNode_t *)memreallocOld(g_nodeGraph, sizeof(graphNode_t), iID, g_nodeCount);
		graphNode_t *n = g_nodeGraph + iID;

		a.solid = SOLID_BBOX;
		a.movetype = MOVETYPE_WALK;
		setsize(a, [-16,-16,-16], [16,16,16]);
		setorigin_safe(a, a.origin);

		n->m_origin = a.origin;
		n->m_neighborList = __NULL__;
		n->m_neighborCount = 0;
		n->m_nodeRadius = 32;
		Node_AutoLink(n, a);

		/* reset it to stupid attributes. */
		a.solid = SOLID_NOT;
		a.movetype = MOVETYPE_NONE;
		setsize(a, [0,0,0], [0,0,0]);
	}
}

bool
Nodes_Available(void)
{
	return (g_nodeCount) > 0i ? true : false;
}

static void
Nodes_BuildFromEnts(void)
{
	ncLog("Rebuilding node tree...");

	/* run through the ents and rebuild the tree */
	Nodes_InsertNodeForClassname("info_node");

#if 0
	Nodes_InsertNodeForClassname("scripted_sequence");
#endif

	/* last resort */
	if (g_nodeCount == 0)
		Nodes_InsertNodeForClassname("info_player_start");
	if (g_nodeCount == 0)
		Nodes_InsertNodeForClassname("info_player_deathmatch");

	ncLog("%i possible nodes found in %s", g_nodeCount, mapname);

	if (g_nodeCount > 0i) {
		ncLog("saving nodes nodes for %s", mapname);
		ncNodeEditor::SaveFile(sprintf("%s.way", mapname));
	} else {
		ncLog("no node data found for %s", mapname);
	}
}

void
NodeHints_Init(void)
{
	info_hint pinchPoint;

	for (int i = 0; i < g_nodeCount; i++) {
		/* is this a pinch point? */
		if (g_nodeGraph[i].m_neighborCount == 2) {
			pinchPoint = spawn(info_hint);
			pinchPoint.Spawn();
			pinchPoint.m_hintType = "pinchPoint";
			setorigin(pinchPoint, g_nodeGraph[i].m_origin);
		} else if (g_nodeGraph[i].m_neighborCount > 4) {
			pinchPoint = spawn(info_hint);
			pinchPoint.Spawn();
			pinchPoint.m_hintType = "disadvantaged";
			setorigin(pinchPoint, g_nodeGraph[i].m_origin);
		}
	}
}

/* generate node tree, used for AI movement/navigation */
void
Nodes_Init(void)
{
	InitStart();

	/* skip if present. TODO: check if they're out of date? */
	if (fileExists(sprintf("data/%s.way", mapname))) {
		ncNodeEditor::ReadFile(sprintf("data/%s.way", mapname), true);
	} else {
		Nodes_BuildFromEnts();
	}

	NodeHints_Init();

	InitEnd();
}

void
Nodes_Flush(void)
{
	ncNodeEditor::Flush();
}

/* =========================================================================
 * Automatic node graph ("sv way autogen [spacing]")
 *
 * Walks the floor out from every spawn point on a grid of `spacing` units
 * (default 64) with the player's hull: a step is kept when the hull fits
 * across at step height, there is floor within a fall the player survives,
 * the floor is not too steep and is not lava, slime or sky. Flat steps and
 * steps up to stair height link both ways, drops only down. The graph then
 * replaces the loaded one and is saved as <map>.way (the engine writes it
 * to data/, where Nodes_Init reads it on the next load).
 * ========================================================================= */
#define AUTOGEN_MAXNODES 2048
#define AUTOGEN_STEP 18
#define AUTOGEN_MAXDROP 192

static int
Nodes_AutoGen_Find(vector pos, float snap)
{
	for (int i = 0i; i < g_nodeCount; i++) {
		vector d = g_nodeGraph[i].m_origin - pos;

		if (fabs(d[2]) > 24) {
			continue;
		}
		d[2] = 0;
		if (vlen(d) < snap) {
			return (i);
		}
	}
	return (-1i);
}

static int
Nodes_AutoGen_Add(vector pos)
{
	int iID = g_nodeCount++;
	g_nodeGraph = (graphNode_t *)memreallocOld(g_nodeGraph, sizeof(graphNode_t), iID, g_nodeCount);
	graphNode_t *n = g_nodeGraph + iID;
	n->m_origin = pos;
	n->m_neighborList = __NULL__;
	n->m_neighborCount = 0;
	n->m_nodeRadius = 32;
	return (iID);
}

/* the floor under `pos` for a standing player, or [0,0,0] with false */
static bool
Nodes_AutoGen_Floor(vector pos, float maxDrop)
{
	tracebox(pos, VEC_HULL_MIN, VEC_HULL_MAX, pos - [0, 0, maxDrop], MOVE_NOMONSTERS, world);

	if (trace_startsolid || trace_allsolid || trace_fraction >= 1.0f) {
		return (false);
	}
	if (trace_plane_normal[2] < 0.7f) {
		return (false);
	}

	float c = pointcontents(trace_endpos + [0, 0, VEC_HULL_MIN[2] + 2]);
	if (c == CONTENT_LAVA || c == CONTENT_SLIME || c == CONTENT_SKY) {
		return (false);
	}
	return (true);
}

static void
Nodes_AutoGen_Seed(string classn, float snap)
{
	for (entity a = world; (a = find(a, ::classname, classn));) {
		if (g_nodeCount >= AUTOGEN_MAXNODES) {
			return;
		}
		/* spawn points sit at, or a little into, the floor */
		if (Nodes_AutoGen_Floor(a.origin + [0, 0, 36], 256)
			&& Nodes_AutoGen_Find(trace_endpos, snap) < 0i) {
			Nodes_AutoGen_Add(trace_endpos);
		}
	}
}

void
Nodes_AutoGenerate(float spacing)
{
	float snap;
	int head = 0i;

	if (spacing < 32) {
		spacing = 64;
	}
	snap = spacing * 0.6f;

	Nodes_Flush();
	g_nodeGraph = __NULL__;
	g_nodeCount = 0i;

	Nodes_AutoGen_Seed("info_player_deathmatch", snap);
	Nodes_AutoGen_Seed("info_player_start", snap);
	Nodes_AutoGen_Seed("info_player_team1", snap);
	Nodes_AutoGen_Seed("info_player_team2", snap);
	Nodes_AutoGen_Seed("info_player_teamspawn", snap);
	Nodes_AutoGen_Seed("info_node", snap);

	if (g_nodeCount == 0i) {
		print("way autogen: no spawn points to start from\n");
		return;
	}

	while (head < g_nodeCount) {
		vector from = g_nodeGraph[head].m_origin;

		for (float k = 0; k < 8; k++) {
			vector dir;
			vector to;
			vector ground;
			int other;

			dir[0] = cos(k * 45 * (M_PI / 180));
			dir[1] = sin(k * 45 * (M_PI / 180));
			dir[2] = 0;
			/* diagonals reach the same grid as the straight steps */
			to = from + dir * ((k % 2) ? spacing * 1.41421356f : spacing);

			/* the hull must fit across at step height */
			tracebox(from + [0, 0, AUTOGEN_STEP], VEC_HULL_MIN, VEC_HULL_MAX,
				to + [0, 0, AUTOGEN_STEP], MOVE_NOMONSTERS, world);
			if (trace_startsolid || trace_fraction < 1.0f) {
				continue;
			}

			if (Nodes_AutoGen_Floor(to + [0, 0, AUTOGEN_STEP], AUTOGEN_STEP + AUTOGEN_MAXDROP) == false) {
				continue;
			}
			ground = trace_endpos;

			/* more than a stair up is a jump: leave it out */
			if (ground[2] - from[2] > AUTOGEN_STEP + 1) {
				continue;
			}

			other = Nodes_AutoGen_Find(ground, snap);
			if (other == head) {
				continue;
			}
			if (other < 0i) {
				if (g_nodeCount >= AUTOGEN_MAXNODES) {
					continue;
				}
				other = Nodes_AutoGen_Add(ground);
			}

			Node_Link(&g_nodeGraph[head], &g_nodeGraph[other]);

			/* walk back up only what is a stair at most */
			if (fabs(g_nodeGraph[other].m_origin[2] - from[2]) <= AUTOGEN_STEP + 1) {
				Node_Link(&g_nodeGraph[other], &g_nodeGraph[head]);
			}
		}
		head++;
	}

	int links = 0i;
	for (int i = 0i; i < g_nodeCount; i++) {
		links += g_nodeGraph[i].m_neighborCount;
	}

	print(sprintf("way autogen: %i nodes, %i links on %s (spacing %d)\n", g_nodeCount, links, mapname, spacing));
	if (g_nodeCount >= AUTOGEN_MAXNODES) {
		print("way autogen: hit the node limit; try a wider spacing\n");
	}

	ncNodeEditor::SaveFile(sprintf("%s.way", mapname));
	print(sprintf("way autogen: saved %s.way (data/%s.way in the writable game folder)\n", mapname, mapname));
}
