/*
 * Goomba stomp: land on an enemy from above after meeting both a downward-speed
 * gate and an airtime gate → instant kill + Player.GoombaStomp (6-sample pool).
 *
 * Players are SOLID_SLIDEBOX, so they never become groundentity (BSP-only).
 * Detection is impact-shaped: downward contact via touch and a short post-move
 * probe — not a continuous airborne feet hunt.
 *
 * Timing fields live on ncPlayer (Player.h) — do NOT use global .float here;
 * that shifts entity field indices and desyncs csprogs when only progs rebuilds.
 */

static bool
GoombaStomp_HeroEnabled(ncPlayer pl)
{
	/* hero_base defaults goomba_stomp "1"; "0" opts out */
	return (pl.GetDefFloat("goomba_stomp") > 0.0f);
}

static bool
GoombaStomp_GatesPass(ncPlayer pl, float fallSpeed)
{
	float minFall;
	float minAir;

	if (!g_goombaStompDecl) {
		return (false);
	}

	minFall = g_goombaStompDecl.GetFloat("minFallSpeed");
	minAir = g_goombaStompDecl.GetFloat("minAirtime");

	if (fallSpeed < minFall) {
		return (false);
	}

	if (pl.m_stilettoAirTime < minAir) {
		return (false);
	}

	return (true);
}

static bool
GoombaStomp_FromAbove(ncPlayer pl, entity victim)
{
	float feetZ;
	float victimMidZ;

	feetZ = pl.origin[2] + pl.mins[2];
	victimMidZ = victim.origin[2] + (victim.mins[2] + victim.maxs[2]) * 0.5f;

	/* stomper feet at/above victim mid-height (velocity may already be zeroed) */
	return (feetZ >= victimMidZ);
}

#ifdef SERVER
static bool
GoombaStomp_ValidVictim(ncPlayer pl, entity hit)
{
	ncSurfacePropEntity sp;
	ncRuleDelegate rules;

	if (!hit || hit == world || hit == pl) {
		return (false);
	}

	/* Brush ents (func_wall, etc.) are not SurfacePropEntity — calling
	 * IsVulnerable/IsAlive on them is a NULL virtual and hard-crashes. */
	if (is.Player(hit)) {
		ncPlayer victim = (ncPlayer)hit;

		if (victim.team == TEAM_SPECTATOR || victim.team == TEAM_UNASSIGNED) {
			return (false);
		}

		rules = (ncRuleDelegate)ncRuleDelegate::ActiveInstance();
		if (rules && rules.IsTeamplay()) {
			if (victim.team == pl.team) {
				return (false);
			}
		}

		sp = (ncSurfacePropEntity)hit;
		if (!sp.IsVulnerable() || !sp.IsAlive()) {
			return (false);
		}

		return (true);
	}

	if (hit.flags & FL_MONSTER) {
		sp = (ncSurfacePropEntity)hit;
		if (!sp.IsVulnerable() || !sp.IsAlive()) {
			return (false);
		}

		return (true);
	}

	return (false);
}
#endif

#ifdef SERVER
static void
GoombaStomp_Apply(ncPlayer pl, entity hit)
{
	ncSurfacePropEntity sp;
	ncDict damageDecl;
	float dmg;

	sp = (ncSurfacePropEntity)hit;
	dmg = sp.GetHealth();
	if (dmg < 1.0f) {
		dmg = 1.0f;
	}

	/* Lethal via Damage() — do not pre-zero health (Player::Damage early-outs).
	 * noGod bypasses Stiletto i-frames; noArmor matches fall/backstab lethal. */
	damageDecl = spawn(ncDict);
	damageDecl.AddKey("damage", itos((int)dmg));
	damageDecl.AddKey("noArmor", "1");
	damageDecl.AddKey("noGod", "1");
	damageDecl.AddKey("weapon", "goomba_stomp");
	sp.Damage(pl, pl, damageDecl, 1.0, [0, 0, -1], hit.origin + [0, 0, hit.maxs[2]]);
	remove(damageDecl);

	/* CHAN_AUTO — CHAN_BODY is footsteps/jump and cuts the stomp off mid-clip.
	 * Guard against OnTouch + PostMove (or multi-clip touch) restarting the sample. */
	if (time >= pl.m_goombaStompSoundTime) {
		pl.m_goombaStompSoundTime = time + 0.25f;
		pl.StartSoundDef("Player.GoombaStomp", CHAN_AUTO, true);
	}
}
#endif

/** Touch-path entry: called when player physics touches another solid. */
void
GoombaStomp_OnTouch(entity stomper, entity hitEnt)
{
#ifdef SERVER
	ncPlayer pl;
	float fallSpeed;

	if (!is.Player(stomper)) {
		return;
	}

	pl = (ncPlayer)stomper;
	if (!is.Alive(pl) || pl.waterlevel >= 2) {
		return;
	}

	if (!GoombaStomp_HeroEnabled(pl)) {
		return;
	}

	fallSpeed = pl.m_goombaFallSpeed;
	if (fallSpeed < 0.0f) {
		fallSpeed = 0.0f;
	}

	if (!GoombaStomp_GatesPass(pl, fallSpeed)) {
		return;
	}

	if (!GoombaStomp_FromAbove(pl, hitEnt)) {
		return;
	}

	if (!GoombaStomp_ValidVictim(pl, hitEnt)) {
		return;
	}

	GoombaStomp_Apply(pl, hitEnt);
#endif
}

/** Post-move probe: short downward contact when gates already pass. */
void
GoombaStomp_PostMove(entity e, float fallSpeed)
{
#ifdef SERVER
	ncPlayer pl;
	float probe;
	vector dest;

	if (!is.Player(e)) {
		return;
	}

	pl = (ncPlayer)e;
	if (!is.Alive(pl) || pl.waterlevel >= 2) {
		return;
	}

	if (!GoombaStomp_HeroEnabled(pl)) {
		return;
	}

	if (!GoombaStomp_GatesPass(pl, fallSpeed)) {
		return;
	}

	if (!g_goombaStompDecl) {
		return;
	}

	probe = g_goombaStompDecl.GetFloat("probeDistance");
	if (probe <= 0.0f) {
		probe = 18.0f;
	}

	dest = pl.origin;
	dest[2] -= probe;
	tracebox(pl.origin, pl.mins, pl.maxs, dest, MOVE_NORMAL, pl);

	if (trace_fraction >= 1.0f && !trace_startsolid) {
		return;
	}

	/* Prefer a top-face hit; startsolid still allows a stuck-on-head case. */
	if (!trace_startsolid && trace_plane_normal[2] < 0.7f) {
		return;
	}

	if (!GoombaStomp_FromAbove(pl, trace_ent)) {
		return;
	}

	if (!GoombaStomp_ValidVictim(pl, trace_ent)) {
		return;
	}

	GoombaStomp_Apply(pl, trace_ent);
#endif
}

void
GoombaStomp_Init(void)
{
	g_goombaStompDecl = ncDict::LoadDeclFromFile("goombastomp", "typeinfo/goombastomp.decl");
#ifdef SERVER
	precache.Sound("Player.GoombaStomp");
#endif
}
