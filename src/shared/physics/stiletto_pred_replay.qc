/*
 * Replay the same canned commands twice from one snapshot and demand identical
 * movement-critical Stiletto state. Invoke with `stiletto_pred_replay`.
 *
 * ~135ms of 15ms commands covers jump/land, held-then-released move, parry
 * press, optional lunge charge/release, and a second jump. Wall contact is
 * taken from the live snapshot (recomputed from collision each command).
 */

static void
Stiletto_PredReplay_RestoreInput(vector move, int buttons, vector ang, float dt)
{
	input_movevalues = move;
	input_buttons = buttons;
	input_angles = ang;
	input_timelength = dt;
	input_impulse = 0;
}

static int
Stiletto_PredReplay_CmdButtons(int i, int toolBtn)
{
	if (i < 2) {
		return INPUT_JUMP;
	}
	if (i == 4) {
		return INPUT_RELOAD;
	}
	if (i >= 5 && i <= 6) {
		return toolBtn;
	}
	if (i == 7) {
		return 0;
	}
	if (i == 8) {
		return INPUT_JUMP;
	}
	return 0;
}

static void
Stiletto_PredReplay_RunQueued(ncPlayer pl, vector ang, int toolBtn)
{
	int i;
	int buttons;
	vector move;

	for (i = 0; i < 9; i++) {
		buttons = Stiletto_PredReplay_CmdButtons(i, toolBtn);
		if (i < 2) {
			move = [0, 0, 0];
		} else {
			move = [200, 0, 0];
		}
		Stiletto_PredReplay_RestoreInput(move, buttons, ang, 0.015f);
		pl.Physics_Run();
	}
}

void
Stiletto_PredReplayCheck(entity e)
{
	ncPlayer pl;
	entity oldSelf;
	vector oldMove;
	vector oldAng;
	int oldButtons;
	float oldDt;
	float oldImpulse;
	vector snapOrigin;
	vector snapVel;
	vector snapAng;
	vector snapWall;
	vector snapDash;
	int snapFlags;
	int snapVFlags;
	int snapPrev;
	int snapPunish;
	int snapCharging;
	int snapFlight;
	int snapLaunch;
	int snapGrappleHeld;
	float snapAir;
	float snapParry;
	float snapStall;
	float snapPunishT;
	float snapCharge;
	float snapCool;
	float snapWallCd;
	float snapDodge;
	float snapStallCh;
	float snapSeq;
	vector aOrigin;
	vector aVel;
	int aFlags;
	int aVFlags;
	int aPrev;
	int aPunish;
	int aCharging;
	int aFlight;
	float aAir;
	float aParry;
	float aStall;
	float aPunishT;
	float aCharge;
	float aCool;
	int i;
	int mismatch;
	int toolBtn;
	string tool;

	if (!e) {
		print("stiletto_pred_replay: FAIL (no entity)\n");
		return;
	}

	if (!is.Player(e)) {
		print("stiletto_pred_replay: FAIL (not a player)\n");
		return;
	}

	pl = (ncPlayer)e;
	oldSelf = self;
	oldMove = input_movevalues;
	oldButtons = input_buttons;
	oldAng = input_angles;
	oldDt = input_timelength;
	oldImpulse = input_impulse;
	self = pl;

	snapOrigin = pl.origin;
	snapVel = pl.velocity;
	snapAng = pl.v_angle;
	snapFlags = pl.flags;
	snapVFlags = (int)pl.m_nuclideFlags;
	snapWall = pl.m_stilettoWallNorm;
	snapDash = pl.m_stilettoDashAddVel;
	snapPrev = pl.m_stilettoPrevButtons;
	snapPunish = pl.m_stilettoPunishState;
	snapCharging = pl.m_stilettoLungeCharging;
	snapFlight = pl.m_stilettoLungeFlight;
	snapLaunch = pl.m_stilettoLungeLaunch;
	snapGrappleHeld = pl.m_stilettoGrappleActionHeld;
	snapAir = pl.m_stilettoAirTime;
	snapParry = pl.m_stilettoParryTime;
	snapStall = pl.m_stilettoAirStallTime;
	snapPunishT = pl.m_stilettoPunishTime;
	snapCharge = pl.m_stilettoLungeCharge;
	snapCool = pl.m_stilettoLungeCooldown;
	snapWallCd = pl.m_stilettoWallJumpCooldown;
	snapDodge = pl.m_stilettoAirDodgeCharges;
	snapStallCh = pl.m_stilettoAirStallCharges;
	snapSeq = pl.m_stilettoLungeSeqStrength;

	toolBtn = 0;
	tool = pl.GetDefString("hero_tool");
	if (tool == "lunge") {
		toolBtn = INPUT_HERO_TOOL;
	}

	Stiletto_PredReplay_RunQueued(pl, snapAng, toolBtn);

	aOrigin = pl.origin;
	aVel = pl.velocity;
	aFlags = pl.flags;
	aVFlags = (int)pl.m_nuclideFlags;
	aPrev = pl.m_stilettoPrevButtons;
	aPunish = pl.m_stilettoPunishState;
	aCharging = pl.m_stilettoLungeCharging;
	aFlight = pl.m_stilettoLungeFlight;
	aAir = pl.m_stilettoAirTime;
	aParry = pl.m_stilettoParryTime;
	aStall = pl.m_stilettoAirStallTime;
	aPunishT = pl.m_stilettoPunishTime;
	aCharge = pl.m_stilettoLungeCharge;
	aCool = pl.m_stilettoLungeCooldown;

	/* restore snapshot and replay again (and a third time for repeated rollback) */
	for (i = 0; i < 2; i++) {
		setorigin(pl, snapOrigin);
		pl.origin = snapOrigin;
		pl.velocity = snapVel;
		pl.v_angle = snapAng;
		pl.flags = snapFlags;
		pl.m_nuclideFlags = (float)snapVFlags;
		pl.m_stilettoWallNorm = snapWall;
		pl.m_stilettoDashAddVel = snapDash;
		pl.m_stilettoPrevButtons = snapPrev;
		pl.m_stilettoPunishState = snapPunish;
		pl.m_stilettoLungeCharging = snapCharging;
		pl.m_stilettoLungeFlight = snapFlight;
		pl.m_stilettoLungeLaunch = snapLaunch;
		pl.m_stilettoGrappleActionHeld = snapGrappleHeld;
		pl.m_stilettoAirTime = snapAir;
		pl.m_stilettoParryTime = snapParry;
		pl.m_stilettoAirStallTime = snapStall;
		pl.m_stilettoPunishTime = snapPunishT;
		pl.m_stilettoLungeCharge = snapCharge;
		pl.m_stilettoLungeCooldown = snapCool;
		pl.m_stilettoWallJumpCooldown = snapWallCd;
		pl.m_stilettoAirDodgeCharges = snapDodge;
		pl.m_stilettoAirStallCharges = snapStallCh;
		pl.m_stilettoLungeSeqStrength = snapSeq;

		Stiletto_PredReplay_RunQueued(pl, snapAng, toolBtn);
	}

	mismatch = 0;
	if (pl.origin != aOrigin) {
		mismatch = 1;
	}
	if (pl.velocity != aVel) {
		mismatch = 1;
	}
	if (pl.flags != aFlags) {
		mismatch = 1;
	}
	if ((int)pl.m_nuclideFlags != aVFlags) {
		mismatch = 1;
	}
	if (pl.m_stilettoPrevButtons != aPrev) {
		mismatch = 1;
	}
	if (pl.m_stilettoPunishState != aPunish) {
		mismatch = 1;
	}
	if (pl.m_stilettoLungeCharging != aCharging) {
		mismatch = 1;
	}
	if (pl.m_stilettoLungeFlight != aFlight) {
		mismatch = 1;
	}
	if (pl.m_stilettoAirTime != aAir) {
		mismatch = 1;
	}
	if (pl.m_stilettoParryTime != aParry) {
		mismatch = 1;
	}
	if (pl.m_stilettoAirStallTime != aStall) {
		mismatch = 1;
	}
	if (pl.m_stilettoPunishTime != aPunishT) {
		mismatch = 1;
	}
	if (pl.m_stilettoLungeCharge != aCharge) {
		mismatch = 1;
	}
	if (pl.m_stilettoLungeCooldown != aCool) {
		mismatch = 1;
	}

	if (mismatch) {
		print("stiletto_pred_replay: FAIL (two replays diverged)\n");
	} else {
		print("stiletto_pred_replay: PASS\n");
	}

	setorigin(pl, snapOrigin);
	pl.origin = snapOrigin;
	pl.velocity = snapVel;
	pl.v_angle = snapAng;
	pl.flags = snapFlags;
	pl.m_nuclideFlags = (float)snapVFlags;
	pl.m_stilettoWallNorm = snapWall;
	pl.m_stilettoDashAddVel = snapDash;
	pl.m_stilettoPrevButtons = snapPrev;
	pl.m_stilettoPunishState = snapPunish;
	pl.m_stilettoLungeCharging = snapCharging;
	pl.m_stilettoLungeFlight = snapFlight;
	pl.m_stilettoLungeLaunch = snapLaunch;
	pl.m_stilettoGrappleActionHeld = snapGrappleHeld;
	pl.m_stilettoAirTime = snapAir;
	pl.m_stilettoParryTime = snapParry;
	pl.m_stilettoAirStallTime = snapStall;
	pl.m_stilettoPunishTime = snapPunishT;
	pl.m_stilettoLungeCharge = snapCharge;
	pl.m_stilettoLungeCooldown = snapCool;
	pl.m_stilettoWallJumpCooldown = snapWallCd;
	pl.m_stilettoAirDodgeCharges = snapDodge;
	pl.m_stilettoAirStallCharges = snapStallCh;
	pl.m_stilettoLungeSeqStrength = snapSeq;

	input_movevalues = oldMove;
	input_buttons = oldButtons;
	input_angles = oldAng;
	input_timelength = oldDt;
	input_impulse = oldImpulse;
	self = oldSelf;
}
