/* What the Panorama HUD (coop/src/hud, layout/coop/hud.xml) needs from the
   server, a few times a second:

     serverinfo coop_left   monsters still to kill this wave, "" between
                            waves (coop_wave and coop_notice are set in
                            coop.qc)
     "*mate"                each player's "health|state" for their
                            teammates' cards: a alive, d down, x dead
     "*prompt"              the key prompt under the crosshair (Use)
     "*respawn"             while down: "<time downed> <delay>" for the
                            respawn bar, "survival" when only a revive
                            brings them back, else ""
     "*usable"              "1" when Use would do something: a teammate to
                            revive, a gun to take, a button or door ahead.
                            A controller's west button uses then, else it
                            reloads (coop/src/hud/jtf.qc, +coop_x)

   The hero's own line is "*herohud", from Hero_HudInfo.

     "*cadence"             "1" to "3" while a Choir's Cadence buffs this
                            player (3 = the middle of her cone), else ""
     "*cadenceN"            on a Choir: how many teammates her Cadence
                            buffs right now
     "*tint", "*aura"       a pulsing colour glow ("r g b", 0-255) and a
                            particle effect around this player, for
                            everyone (gold in a Cadence;
                            src/shared/game/Player.qc) */

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

/* Choir's Cadence: whether p is in one, and on a Choir how many she buffs */
void
Coop_HudCadence(entity p, int slot)
{
	bool buffed = (slot >= 0i && is.Alive(p) && time < g_cadenceUntil[slot]) ? true : false;
	int count = 0i;

	Coop_HudSet(p, "*cadence", buffed ? ftos(ceil(g_cadenceAmt[slot] * 3)) : "");
	/* in the world: a pulsing gold glow and rising gold motes (sokky: the
	   outline alone was too easy to miss) */
	Coop_HudSet(p, "*tint", buffed ? "200 140 30" : "");
	Coop_HudSet(p, "*aura", buffed ? "fx_cadence.motes" : "");

	if (slot >= 0i && g_hLogic[slot] == HL_CHOIR) {
		for (int i = 0i; i < COOP_MAXPLAYERS; i++) {
			if (i != slot && time < g_cadenceUntil[i] && g_cadenceBy[i] == slot) {
				count++;
			}
		}
		Coop_HudSet(p, "*cadenceN", itos(count));
	} else {
		Coop_HudSet(p, "*cadenceN", "");
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

	/* Engage's cost, for the tick on the HUD's energy meter */
	if (serverkey("coop_engageCost") != ftos(autocvar_coop_engageCost)) {
		serverinfo.SetString("coop_engageCost", ftos(autocvar_coop_engageCost));
	}

	for (entity p = world; (p = next.Player(p));) {
		int slot = Coop_Slot(p);
		string state = "a";
		string prompt = "";

		Coop_HudCadence(p, slot);	/* bots too: the outline is for everyone */

		if (p.classname == "spectator") {
			Coop_HudSet(p, "*mate", "");
			continue;
		}

		if (!is.Alive(p)) {
			state = (slot >= 0i && g_coopDown[slot]) ? "d" : "x";
		}

		Coop_HudSet(p, "*mate", sprintf("%d|%s", max(0, p.health), state));
		/* for the objective panel: score and shop points */
		Coop_HudSet(p, "*stats", sprintf("%d|%i", p.frags, Coop_Points(p)));	/* %i: points are an int */

		if (slot >= 0i && !is.Alive(p) && g_coopDown[slot]) {
			Coop_HudSet(p, "*respawn", autocvar_coop_survival ? "survival" :
				sprintf("%.2f %.2f", g_coopDownTime[slot], autocvar_coop_respawnDelay));
		} else {
			Coop_HudSet(p, "*respawn", "");
		}

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

		/* a floor gun in reach: the same Use prompt as a revive, and where
		   the gun is, so the HUD can draw the prompt as a callout on it */
		string promptAt = "";

		if (prompt == "" && slot >= 0i && is.Alive(p) && Hero_OfKit(p.classname) >= 0i) {
			entity gun = Hero_AimedGun(p, HERO_TAKERANGE);

			if (gun) {
				string gunName = entityDef.GetString(gun.classname, "inv_name");
				vector mid = (gun.absmin + gun.absmax) * 0.5f;
				prompt = sprintf("Take %s", (gunName != "") ? gunName : gun.classname);
				promptAt = sprintf("%d %d %d", mid[0], mid[1], mid[2]);
			}
		}

		Coop_HudSet(p, "*prompt", prompt);
		Coop_HudSet(p, "*promptAt", promptAt);
		Coop_HudSet(p, "*usable", Coop_Usable(p, slot) ? "1" : "");
	}
}
