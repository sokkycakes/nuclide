/* What the Panorama HUD (coop/src/hud, layout/coop/hud.xml) needs from the
   server, a few times a second:

     serverinfo coop_left   monsters still to kill this wave, "" between
                            waves (coop_wave and coop_notice are set in
                            coop.qc)
     "*mate"                each player's "health|state" for their
                            teammates' cards: a alive, d down, x dead
     "*prompt"              the key prompt under the crosshair (Use)
     "*usable"              "1" when Use would do something: a teammate to
                            revive, a gun to take, a button or door ahead.
                            A controller's west button uses then, else it
                            reloads (coop/src/hud/jtf.qc, +coop_x)

   The hero's own line is "*herohud", from Hero_HudInfo. */

float g_coopHudNext;

/* the server progs' field (src/server/defs.h), shared by name */
.void(void) PlayerUse;

/* would Use do anything for p: the player's own use trace (ncPlayer's,
   96 units ahead, then an 8 unit radius where it lands), a downed
   teammate in reach, or a floor gun to take */
bool
Coop_Usable(entity p, int slot)
{
	vector eye = p.origin + p.view_ofs;

	if (g_coopAnyDown && slot >= 0i && Coop_DownedNear(p.origin)) {
		return (true);
	}

	if (slot >= 0i && Hero_OfKit(p.classname) >= 0i && Hero_AimedGun(p, HERO_TAKERANGE)) {
		return (true);
	}

	makevectors(p.v_angle);
	traceline(eye, eye + v_forward * 96, MOVE_EVERYTHING, p);

	if (trace_fraction < 1.0f) {
		if (trace_ent.PlayerUse) {
			return (true);
		}

		for (entity e = findradius(trace_endpos, 8); e; e = e.chain) {
			if (e.PlayerUse) {
				return (true);
			}
		}
	}

	return (false);
}

void
Coop_HudSet(entity p, string key, string value)
{
	if (infokey(p, key) != value) {
		forceinfokey(p, key, value);
	}
}

void
Coop_HudFrame(void)
{
	string left = "";

	if (time < g_coopHudNext) {
		return;
	}

	g_coopHudNext = time + 0.25f;

	if (g_coopWave > 0i && g_coopWaveState != WAVE_WAITING) {
		left = itos(g_coopWaveLeft + Coop_MonstersAlive());
	}

	if (serverkey("coop_left") != left) {
		serverinfo.SetString("coop_left", left);
	}

	for (entity p = world; (p = next.Player(p));) {
		int slot = Coop_Slot(p);
		string state = "a";
		string prompt = "";

		if (p.classname == "spectator") {
			Coop_HudSet(p, "*mate", "");
			continue;
		}

		if (!is.Alive(p)) {
			state = (slot >= 0i && g_coopDown[slot]) ? "d" : "x";
		}

		Coop_HudSet(p, "*mate", sprintf("%d|%s", max(0, p.health), state));

		if (is.Bot(p)) {
			continue;
		}

		if (g_coopAnyDown && slot >= 0i && is.Alive(p)) {
			entity target = Coop_DownedNear(p.origin);

			if (target && g_coopReviveTarget[slot] == target) {
				prompt = sprintf("Reviving %s", target.netname);
			} else if (target) {
				prompt = sprintf("Hold to revive %s", target.netname);
			}
		}

		Coop_HudSet(p, "*prompt", prompt);
		Coop_HudSet(p, "*usable", Coop_Usable(p, slot) ? "1" : "");
	}
}
