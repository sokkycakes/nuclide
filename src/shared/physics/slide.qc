/*
 * Nuclide universal crouch slide system (Deadlock-style).
 * Four phases: Trigger -> State Change -> Physics (friction override + slope
 * projection + flat drag) -> Exit.
 *
 * Integrates into the shared pmove pipeline via hooks in Physics_Run().
 * Tuning via autocvars pm_slideminspeed, pm_slidedrag, pm_slidefriction.
 */

/* ---- Phase A + B: Trigger & Entry --------------------------------------- */

/* Min horizontal speed (qu/s) to enter or sustain a slide on flat ground. */
var float autocvar_pm_slideminspeed = 250.0f;

/* Exponential slide drag applied each frame on flat ground. Higher = stop faster. */
var float autocvar_pm_slidedrag = 3.0f;

/* Friction divisor applied before the engine ground-friction step while sliding.
 * The existing PMoveCustom_AccelFriction divides pm_friction by self.friction.
 * A value of 100.0 reduces effective friction from 4.0 to ~0.04. */
var float autocvar_pm_slidefriction = 100.0f;

/* ---- helpers ------------------------------------------------------------- */

float
Slide_HorizSpeed(entity e)
{
    return sqrt(e.velocity[0] * e.velocity[0] + e.velocity[1] * e.velocity[1]);
}

/* Returns the ground plane normal at the entity's feet.  g_vec_null if airborne. */
static vector
_Slide_GroundNormal(entity e)
{
    vector end;
    end = e.origin + [0, 0, -2];
    traceline(e.origin, end, MOVE_NORMAL, e);
    if (trace_fraction >= 1.0f) {
        return g_vec_null;
    }
    return trace_plane_normal;
}

/* ---- Phase A: can the player enter a slide? ----------------------------- */

bool
Slide_CheckEnter(entity e)
{
    ncPlayer pl = (ncPlayer)e;
    float horiz;
    vector norm;

    /* Must be on foot, on ground, not in water */
    if (pl.GetMovetype() != MOVETYPE_WALK)
        return false;
    if (!(pl.flags & FL_ONGROUND))
        return false;
    if (pl.waterlevel > WATERLEVEL_KNEE)
        return false;

    /* Already on a wall-cling or sliding */
    if (pl.HasVFlags(VFL_STILETTO_WALL))
        return false;
    if (pl.HasVFlags(VFL_SLIDING))
        return false;

    /* Crouch must be held */
    if (!(input_buttons & INPUT_CROUCH))
        return false;

    horiz = Slide_HorizSpeed(pl);

    /* Speed threshold check */
    if (horiz >= autocvar_pm_slideminspeed)
        return true;

    /* Slope bypass: on any slope, player can slide even at low speed */
    norm = _Slide_GroundNormal(pl);
    if (norm != g_vec_null && norm[2] >= 0.7f && norm[2] < 0.95f)
        return true;

    return false;
}

/* ---- Phase B: enter the slide ------------------------------------------- */

void
Slide_Enter(entity e)
{
    ncPlayer pl = (ncPlayer)e;
    pl.AddVFlags(VFL_SLIDING);
}

/* ---- Phase C pre-hook: override friction before ground-physics runs ------ */

void
Slide_OnPhysicsStart(entity e)
{
    ncPlayer pl = (ncPlayer)e;
    if (pl.HasVFlags(VFL_SLIDING)) {
        pl.friction = autocvar_pm_slidefriction;
    }
}

/* ---- Phase C: apply slope projection or flat-ground drag ---------------- */

void
Slide_ApplyGravityProjection(entity e)
{
    ncPlayer pl = (ncPlayer)e;
    vector norm;
    float drag;
    float horiz;

    if (!pl.HasVFlags(VFL_SLIDING))
        return;
    if (!(pl.flags & FL_ONGROUND))
        return;

    norm = _Slide_GroundNormal(pl);
    if (norm == g_vec_null)
        return;

    if (norm[2] >= 0.95f) {
        /* Flat ground: apply exponential slide drag to horizontal velocity */
        drag = autocvar_pm_slidedrag * input_timelength;
        if (drag > 0.999f)
            drag = 0.999f;
        pl.velocity[0] *= (1.0f - drag);
        pl.velocity[1] *= (1.0f - drag);
    } else if (norm[2] >= 0.7f) {
        /* Slope: project gravity along the surface normal to push downhill.
         * The horizontal component of gravity parallel to the slope is:
         *   accel_horiz = gravity * nz * [-nx, -ny]
         * This accelerates the player downhill, counteracting slide drag. */
        float accel = pl.gravity * norm[2] * input_timelength;
        pl.velocity[0] -= norm[0] * accel;
        pl.velocity[1] -= norm[1] * accel;
    }
}

/* ---- Phase D: exit checks ----------------------------------------------- */

void
Slide_CheckExit(entity e)
{
    ncPlayer pl = (ncPlayer)e;
    float horiz;
    vector norm;

    if (!pl.HasVFlags(VFL_SLIDING))
        return;

    /* Left the ground (jump / fall edge) */
    if (!(pl.flags & FL_ONGROUND)) {
        pl.RemoveVFlags(VFL_SLIDING);
        pl.friction = 0.0f;
        return;
    }

	/* Crouch released -> exit slide to normal crouch/stand */
	if (!(input_buttons & INPUT_CROUCH)) {
		pl.RemoveVFlags(VFL_SLIDING);
		pl.friction = 0.0f;
		return;
	}

	/* On flat ground, check if speed has dropped below the minimum */
    norm = _Slide_GroundNormal(pl);
    if (norm == g_vec_null)
        return;
    if (norm[2] >= 0.95f) {
        horiz = Slide_HorizSpeed(pl);
        if (horiz < autocvar_pm_slideminspeed) {
            pl.RemoveVFlags(VFL_SLIDING);
            pl.friction = 0.0f;
        }
    }
}
