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
Spawn_ObserverCam

Find a spawnpoint for spectators and set origin and angle of the 'pl' target.
=================
*/
void
Spawn_ObserverCam(ncPlayer pl)
{
	entity eTarget;
	entity eCamera = find(world, ::classname, "trigger_camera");

	if (eCamera) {
		pl.origin = eCamera.origin;
		
		if (eCamera.target) {
			eTarget = find(world, ::targetname, eCamera.target);
			if (eTarget) {
				pl.angles = vectoangles(eTarget.origin - eCamera.origin);
				//pl.angles[0] *= -1;
			}
		}
	} else {
		/* can't find a camera? CS chooses to pick a spawnpoint instead */
		eCamera = find (world, ::classname, "info_player_start");
		
		if (eCamera) {
			pl.origin = eCamera.origin;
			pl.angles = eCamera.angles;
		}
	}

	Client_FixAngle(pl, pl.angles);
}

/*
=================
Spawn_PlayerRange

Returns how close the closest player is to any given spot.
=================
*/
float Spawn_PlayerRange(entity spot) {
	entity pl;
	float bestdist;
	float dist;

	bestdist = 9999999;

	for (pl = world; (pl = next.Player(pl));) {
		if (pl->health <= 0) {
			continue;
		}
		dist = vlen(spot.origin - pl.origin);
		if (dist < bestdist) {
			bestdist = dist;
		}
	}

	for (pl = world; (pl = findfloat(pl, takedamage, DAMAGE_AIM));) {
		if (pl->health <= 0) {
			continue;
		}
		dist = vlen(spot.origin - pl.origin);
		if (dist < bestdist) {
			bestdist = dist;
		}
	}

	return bestdist;
}

/*
=================
Spawn_CountClass
=================
*/
static float
Spawn_CountClass(string cname)
{
	float count = 0;

	for (entity e = world; (e = find(e, ::classname, cname));) {
		count++;
	}

	return count;
}

/*
=================
Spawn_SelectRandom

Return a point in the map that's both 'random' and also not too close to any
living player.
=================
*/
entity Spawn_SelectRandom(string cname) 
{
	static entity lastspot;
	entity spot = world;

	float max = Spawn_CountClass(cname);

	if (max <= 0) {
		return __NULL__;
	}

	for (int i = random(1, max); i > 0; i--) {
		spot = find(spot, ::classname, cname);
	}

	if (spot == __NULL__) {
		spot = find(world, ::classname, cname);
	}

	entity firstspot = spot;
	do {
		if (spot) {
			if (Spawn_PlayerRange(spot) > 128) {
				if (spot.origin == [0,0,0]) {
					spot = find(spot, ::classname, cname);
					continue;
				}
				lastspot = spot;
				return spot;
			}
		}
		spot = find(spot, ::classname, cname);
	} while (spot != firstspot);

	if (!spot) {
		return __NULL__;
	}

	/* everyone is clustered; use the last random pick anyway */
	lastspot = spot;
	return spot;
}

/*
=================
Spawn_SendAngles
=================
*/
static void
Spawn_SendAngles(entity targetEnt, entity spawnPoint)
{
	WriteByte(MSG_MULTICAST, SVC_CGAMEPACKET);
	WriteByte(MSG_MULTICAST, EV_ANGLE);
	WriteFloat(MSG_MULTICAST, spawnPoint.angles[0]);
	WriteFloat(MSG_MULTICAST, spawnPoint.angles[1]);
	WriteFloat(MSG_MULTICAST, spawnPoint.angles[2]);
	msg_entity = targetEnt;
	multicast([0,0,0], MULTICAST_ONE_R);
}

/*
=================
Spawn_PlaceAtSpot

Move the player to a spawn entity, nudging upward until the hull is clear.
=================
*/
static bool
Spawn_PlaceAtSpot(entity targetEnt, entity spawnPoint)
{
	vector testorg;

	if (!spawnPoint) {
		return (false);
	}

	testorg = spawnPoint.origin;

	for (int i = 0; i < 64; i++) {
		tracebox(testorg, targetEnt.mins, targetEnt.maxs, testorg, MOVE_NORMAL, targetEnt);

		if (!trace_startsolid) {
			break;
		}

		testorg[2] += 1.0;
	}

	targetEnt.origin = testorg;
	targetEnt.angles = spawnPoint.angles;
	setorigin(targetEnt, testorg);
	Spawn_SendAngles(targetEnt, spawnPoint);
	return (true);
}

/*
=================
Spawn_TryClassname
=================
*/
static bool
Spawn_TryClassname(entity targetEnt, string cname)
{
	entity spawnPoint;

	if (!STRING_SET(cname)) {
		return (false);
	}

	if (Spawn_CountClass(cname) <= 0) {
		return (false);
	}

	spawnPoint = Spawn_SelectRandom(cname);

	if (!spawnPoint) {
		return (false);
	}

	return Spawn_PlaceAtSpot(targetEnt, spawnPoint);
}

static bool
Spawn_TryFallbackChain(entity targetEnt)
{
	/* intermission / observer fallbacks before generic player starts */
	if (Spawn_TryClassname(targetEnt, "info_intermission")) {
		return (true);
	}

	if (Spawn_TryClassname(targetEnt, "info_player_deathmatch")) {
		return (true);
	}

	if (Spawn_TryClassname(targetEnt, "info_player_coop")) {
		return (true);
	}

	if (Spawn_TryClassname(targetEnt, "info_player_start")) {
		return (true);
	}

	/* trigger_camera (with target look-at) or a lone info_player_start */
	Spawn_ObserverCam((ncPlayer)targetEnt);
	if (vlen(targetEnt.origin) > 0.1) {
		return (true);
	}

	return (false);
}

void
Spawn_TeleportToSpawn(entity targetEnt)
{
	string desiredSpawn = teams.SpawnPoint((int)targetEnt.team);

	/* singleplayer landmark transitions */
	if (STRING_SET(startspot)) {
		targetEnt.origin = Landmark_GetSpot();
		setorigin_safe(targetEnt, targetEnt.origin);
		return;
	}

	if (Spawn_TryClassname(targetEnt, desiredSpawn)) {
		return;
	}

	/* ruleset spawn classname missing or not on map — try the usual fallbacks */
	if (Spawn_TryFallbackChain(targetEnt)) {
		return;
	}

	print("^1Error: no player spawn points found on this map.\n");
}

bool
Spawn_TeleportToClassname(entity targetEnt, string cname)
{
	if (Spawn_TryClassname(targetEnt, cname)) {
		return (true);
	}

	return (Spawn_TryFallbackChain(targetEnt));
}

void
Spawn_RepositionPlayersAtOrigin(void)
{
	for (entity pl = world; (pl = next.Player(pl));) {
		if (vlen(pl.origin) < 1.0) {
			Spawn_TeleportToSpawn(pl);
		}
	}
}
