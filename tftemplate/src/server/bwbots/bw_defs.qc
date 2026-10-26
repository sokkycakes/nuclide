/* Bulwark bot framework: constants, shared globals and class declarations.
 * Behaviour follows docs/spec/bots.md. ISC licence, see LICENSE.
 *
 * The game supplies the usual FTE builtins and constants (Nuclide's
 * fteextensions.qc, or tests/bots/defs.qc). Everything here is prefixed BW /
 * bw_ so it can sit next to a game's own code. */

/* --- action results --------------------------------------------------- */
#define BWR_CONTINUE	0
#define BWR_CHANGE	1
#define BWR_SUSPEND	2
#define BWR_DONE	3
#define BWR_SUSTAIN	4

/* priorities for requests made from event handlers */
#define BWP_TRY		1
#define BWP_IMPORTANT	2
#define BWP_CRITICAL	3

/* answers to contextual queries */
#define BWQ_NO		0
#define BWQ_YES		1
#define BWQ_DONTCARE	2

/* --- events ------------------------------------------------------------ */
#define BWE_LEAVE_GROUND	1	/* e1 ground */
#define BWE_LAND		2	/* e1 ground */
#define BWE_CONTACT		3	/* e1 other */
#define BWE_MOVE_SUCCESS	4	/* e1 path */
#define BWE_MOVE_FAIL		5	/* e1 path, f1 reason */
#define BWE_STUCK		6
#define BWE_UNSTUCK		7
#define BWE_POSTURE		8
#define BWE_ANIM_DONE		9	/* f1 activity */
#define BWE_ANIM_INTERRUPTED	10	/* f1 activity */
#define BWE_ANIM_EVENT		11	/* f1 event id, s1 options */
#define BWE_INJURED		12	/* e1 inflictor, e2 attacker, f1 damage */
#define BWE_KILLED		13	/* e1 inflictor, e2 attacker, f1 damage */
#define BWE_OTHER_KILLED	14	/* e1 victim, e2 attacker */
#define BWE_SIGHT		15	/* e1 subject */
#define BWE_LOST_SIGHT		16	/* e1 subject */
#define BWE_SOUND		17	/* e1 source, v1 position, f1 volume */
#define BWE_WEAPON_FIRED	18	/* e1 shooter, e2 weapon */
#define BWE_CMD_ATTACK		19	/* e1 victim */
#define BWE_CMD_APPROACH_POS	20	/* v1 position, f1 tolerance */
#define BWE_CMD_APPROACH_ENT	21	/* e1 goal */
#define BWE_CMD_RETREAT		22	/* e1 threat, f1 range */
#define BWE_CMD_PAUSE		23	/* f1 duration */
#define BWE_CMD_RESUME		24
#define BWE_CMD_STRING		25	/* s1 command */
#define BWE_MODEL_CHANGED	26
#define BWE_PICKUP		27	/* e1 item, e2 giver */
#define BWE_DROP		28	/* e1 item */
#define BWE_SHOVED		29	/* e1 pusher */
#define BWE_BLINDED		30	/* e1 blinder */
#define BWE_WIN			31
#define BWE_LOSE		32
#define BWE_CUSTOM		33	/* s1 name, s2 text, e1, v1, f1 payload */
#define BWE_COUNT		34

/* reasons passed with BWE_MOVE_FAIL */
#define BWFAIL_NO_PATH		1
#define BWFAIL_STUCK		2
#define BWFAIL_FELL_OFF		3

/* --- debug categories ---------------------------------------------------- */
#define BWD_BEHAVIOR	1
#define BWD_LOOK	2
#define BWD_PATH	4
#define BWD_ANIMATION	8
#define BWD_LOCOMOTION	16
#define BWD_VISION	32
#define BWD_HEARING	64
#define BWD_EVENTS	128
#define BWD_ERRORS	256
#define BWD_ALL		511

/* --- body ------------------------------------------------------------------ */
#define BWPOSTURE_STAND	0
#define BWPOSTURE_CROUCH	1
#define BWPOSTURE_SIT	2
#define BWPOSTURE_LIE	3

#define BWACT_NONE	0
#define BWACT_IDLE	1
#define BWACT_WALK	2
#define BWACT_RUN	3
#define BWACT_JUMP	4
#define BWACT_CLIMB	5
#define BWACT_CROUCH_IDLE	6
#define BWACT_CROUCH_WALK	7
#define BWACT_ATTACK	8
#define BWACT_DIE	9
#define BWACT_LIE	10
#define BWACT_COUNT	11

/* flags for StartActivity */
#define BWACTF_LOOP	1

/* head aim priorities */
#define BWLOOK_BORING		0
#define BWLOOK_INTERESTING	1
#define BWLOOK_IMPORTANT	2
#define BWLOOK_CRITICAL		3
#define BWLOOK_MANDATORY	4

/* why an aim request ended without reaching its target */
#define BWAIM_PREEMPTED	1
#define BWAIM_REJECTED	2
#define BWAIM_EXPIRED	3

/* --- paths ------------------------------------------------------------------ */
#define BWSEG_GROUND	0
#define BWSEG_DROP	1	/* the ground falls away: walk off the edge to this landing */
#define BWSEG_GAP	2	/* jump across a gap to this landing */
#define BWSEG_CLIMB	3	/* climb onto the ledge at this point */

#define BWPATH_MAXSEGS	192

/* --- player bots ---------------------------------------------------------------
 * input_buttons bits, the same as Nuclide's INPUT_BUTTON* (and the engine's
 * standard player physics, which reads BWIN_JUMP) */
#define BWIN_ATTACK	1
#define BWIN_JUMP	2
#define BWIN_PRONE	4
#define BWIN_RELOAD	8
#define BWIN_ATTACK2	16
#define BWIN_USE	32
#define BWIN_SPRINT	64
#define BWIN_CROUCH	128

/* one point of a path; segment i runs from point i-1 to point i */
struct bw_seg_t {
	vector pos;
	vector fwd;		/* unit direction from the previous point (2D for ground) */
	float type;		/* BWSEG_* */
	float len;		/* length from the previous point */
	float dist;		/* distance from the start of the path */
	float curv;		/* 0 straight on, 1 full reverse, at this point */
};

/* waypoint graph, see bw_waypoints.qc */
struct bw_wp_t {
	vector pos;
	float radius;
	float firstlink;
	float numlinks;
};
struct bw_wplink_t {
	float to;
	float cost;
	float flags;
};

/* --- shared state ----------------------------------------------------------- */

/* the result an action handler or Update returns travels in these */
entity bw_res_action;
string bw_res_why;
float bw_res_prio;

/* event payload; saved per nesting level while an event is delivered */
entity bw_ev_e1, bw_ev_e2;
vector bw_ev_v1;
float bw_ev_f1;
string bw_ev_s1, bw_ev_s2;

/* contextual query answers that are not yes or no */
float bw_q_defined;

/* debug */
float bw_debug_flags;
float bw_debug_nfilter;
string bw_debug_filter[8];

/* path cursor results (BWPath::PointAt) */
vector bw_cursor_fwd;
float bw_cursor_curv;
float bw_cursor_seg;

/* --- classes --------------------------------------------------------------- */
class BWBot;
class BWAction;
class BWPath;

/* everything that hears events: components and actions */
class BWEvents {
	virtual float HandleEvent(float type);

	virtual float OnLeaveGround(entity ground);
	virtual float OnLandOnGround(entity ground);
	virtual float OnContact(entity touched);
	virtual float OnMoveToSuccess(BWPath path);
	virtual float OnMoveToFailure(BWPath path, float reason);
	virtual float OnStuck(void);
	virtual float OnUnStuck(void);
	virtual float OnPostureChanged(void);
	virtual float OnAnimationActivityComplete(float activity);
	virtual float OnAnimationActivityInterrupted(float activity);
	virtual float OnAnimationEvent(float id, string options);
	virtual float OnInjured(entity inflictor, entity attacker, float damage);
	virtual float OnKilled(entity inflictor, entity attacker, float damage);
	virtual float OnOtherKilled(entity victim, entity attacker);
	virtual float OnSight(entity subject);
	virtual float OnLostSight(entity subject);
	virtual float OnSound(entity source, vector pos, float volume);
	virtual float OnWeaponFired(entity shooter, entity weapon);
	virtual float OnCommandAttack(entity victim);
	virtual float OnCommandApproach(vector pos, float tolerance);
	virtual float OnCommandApproachEntity(entity goal);
	virtual float OnCommandRetreat(entity threat, float range);
	virtual float OnCommandPause(float duration);
	virtual float OnCommandResume(void);
	virtual float OnCommandString(string cmd);
	virtual float OnModelChanged(void);
	virtual float OnPickUp(entity item, entity giver);
	virtual float OnDrop(entity item);
	virtual float OnShoved(entity pusher);
	virtual float OnBlinded(entity blinder);
	virtual float OnWin(void);
	virtual float OnLose(void);
	virtual float OnCustomEvent(string name, string text);
};

class BWComponent : BWEvents {
	BWBot m_bot;
	virtual void Reset(void);
	virtual void Update(float interval);	/* at the think rate */
	virtual void FrameUpdate(float dt);	/* every server frame */
};

/* asked when a head aim request ends */
class BWAimReply {
	virtual void OnSuccess(BWBot bot);
	virtual void OnFail(BWBot bot, float reason);
};

class BWLocomotion : BWComponent {
	/* tuning, set by the bot or its factory */
	float m_run_speed, m_walk_speed, m_accel, m_yaw_rate;
	float m_step, m_max_jump, m_slope, m_gravity_scale;
	float m_desired_speed;

	vector m_pend_dir;
	float m_pend_weight;
	vector m_pend_goal;	/* weighted sum of the goals asked for */
	vector m_move_goal;	/* where this think's requests point */
	vector m_move_dir;
	float m_move_until;
	vector m_face_goal;
	float m_face_until;

	float m_jumping;	/* left the ground on purpose; cleared on landing */
	float m_climbing;
	vector m_air_goal;
	float m_air_speed;
	float m_air_accel;	/* air control strength; 0 means the default */

	vector m_last_good;
	vector m_stuck_anchor;
	float m_stuck_anchor_time, m_stuck, m_stuck_since, m_stuck_next;
	float m_still_since;
	float m_wants_move;
	entity m_contacts[4];
	float m_ncontacts;
	float m_actor_blocked;	/* last time an actor was in the way */

	virtual void Reset(void);
	virtual void FrameUpdate(float dt);

	nonvirtual void Approach(vector goal, float weight);
	nonvirtual void FaceTowards(vector pos);
	nonvirtual void Stop(void);
	nonvirtual void SetDesiredSpeed(float s);
	nonvirtual void Run(void);
	nonvirtual void Walk(void);
	nonvirtual float GetSpeed(void);
	nonvirtual float IsOnGround(void);
	nonvirtual float IsClimbingOrJumping(void);
	nonvirtual float IsStuck(void);
	nonvirtual float GetStuckDuration(void);
	nonvirtual float IsImmobile(void);
	nonvirtual float GetStillDuration(void);
	nonvirtual void ClearStuck(void);
	nonvirtual float IsBlockedByActor(void);

	virtual void Jump(float height);
	virtual void Leap(vector vel);
	virtual float JumpAcrossGap(vector landing, vector fwd);
	virtual float ClimbUpToLedge(vector ledge, vector fwd);
	virtual float DrivesInput(void);	/* TRUE for player bots */

	virtual float IsPotentiallyTraversable(vector from, vector to, float eventually);
	virtual float HasGap(vector from, vector to);
	virtual float IsEntityTraversable(entity e, float eventually);

	nonvirtual vector SlideMove(vector start, vector vel, float dt, float grounded);
	nonvirtual void Move(float dt);
	nonvirtual void CheckGround(float was);
	nonvirtual void UpdateStuck(void);
	nonvirtual void Turn(float dt);
};

/* Locomotion for player bots: fake clients made with spawnclient(). Instead
 * of moving the box it turns requests into the input a player would send,
 * and the game's player physics moves it. See bw_player.qc. */
class BWPlayerLocomotion : BWLocomotion {
	vector m_in_move;	/* input_movevalues for this frame */
	float m_was_ground;
	float m_jump_press;	/* press jump on the next input frame */
	float m_jump_at;	/* when the jump was asked for */
	float m_air_steer;	/* keep moving towards m_air_goal while airborne */

	virtual void Reset(void);
	virtual void FrameUpdate(float dt);
	virtual void Jump(float height);
	virtual float JumpAcrossGap(vector landing, vector fwd);
	virtual float ClimbUpToLedge(vector ledge, vector fwd);
	virtual float DrivesInput(void);
	nonvirtual void Observe(void);
	nonvirtual void Feel(void);
};

class BWBody : BWComponent {
	float m_posture;
	float m_activity, m_act_flags, m_act_end, m_act_done;

	vector m_look_pos;
	entity m_look_ent;
	float m_look_prio, m_look_until, m_look_start, m_look_done;
	BWAimReply m_look_reply;
	string m_look_reason;
	vector m_track;
	vector m_view;		/* the view angles; a player's v_angle can be reset by the game each input frame */
	float m_on_target;
	/* aiming skill; 0 means the default */
	float m_head_rate;	/* degrees per second when far off target */
	float m_track_rate;	/* how fast the aim catches up with a moving subject */
	float m_aim_error;	/* degrees of error, re-rolled every half second or so */
	vector m_err_off;
	float m_err_next;
	vector m_aim_pos;	/* where the head is steering now, error included */

	virtual void Reset(void);
	virtual void FrameUpdate(float dt);

	virtual float SetDesiredPosture(float posture);
	nonvirtual float GetPosture(void);
	virtual vector PostureMaxs(float posture);
	virtual float PostureEyeHeight(float posture);
	nonvirtual vector GetEyePosition(void);
	nonvirtual vector GetViewVector(void);

	virtual string ActivitySequence(float act);
	nonvirtual float StartActivity(float act, float flags);
	nonvirtual float GetActivity(void);
	nonvirtual float IsActivityDone(void);

	nonvirtual void AimHeadTowards(vector pos, float prio, float duration, BWAimReply reply, string reason);
	nonvirtual void AimHeadTowardsEntity(entity subject, float prio, float duration, BWAimReply reply, string reason);
	nonvirtual float IsHeadAimingOnTarget(void);
	nonvirtual float IsHeadSteady(void);
	nonvirtual float IsAimingAt(vector pos, float radius);
	nonvirtual void ClearAim(void);
	nonvirtual void EndAim(float reason);
};

/* what a bot knows about one actor */
class BWKnown {
	entity m_subject;
	vector m_lastpos;
	float m_lastseen;	/* time last visible; 0 if only told */
	float m_visible, m_visible_since, m_known_since;
	float m_sighted;	/* OnSight sent for the current sighting */
	float m_scan;
	BWKnown m_next;
};

class BWVision : BWComponent {
	float m_fov, m_cos_half_fov, m_reaction, m_range;
	BWKnown m_known;
	entity m_last_threat;	/* the last primary threat, for hysteresis */
	float m_last_update;
	float m_team_last_seen[8];

	virtual void Reset(void);
	virtual void Update(float interval);

	nonvirtual void Forget(entity e);
	nonvirtual void ForgetAll(void);
	nonvirtual BWKnown GetKnown(entity e);
	nonvirtual BWKnown AddKnownEntity(entity e);
	nonvirtual BWKnown FindRecord(entity e);

	virtual float IsActor(entity e);
	nonvirtual float IsAware(BWKnown k);
	nonvirtual BWKnown GetPrimaryKnownThreat(float only_visible);
	nonvirtual BWKnown GetClosestKnown(float tm);
	nonvirtual float GetKnownCount(float tm, float only_visible, float range);
	nonvirtual float GetTimeSinceVisible(float tm);

	nonvirtual void SetFieldOfView(float degrees);
	nonvirtual float IsInFieldOfView(vector pos);
	nonvirtual float IsLineOfSightClear(vector pos);
	nonvirtual float IsAbleToSee(entity e, float check_fov);
	nonvirtual float IsAbleToSeePosition(vector pos, float check_fov);
	nonvirtual float IsLookingAt(vector pos, float cos_tolerance);
	nonvirtual void DebugDraw(void);
};

class BWIntention : BWComponent {
	BWAction m_root;
	BWAction m_forced;

	virtual void Reset(void);
	virtual void Update(float interval);
	virtual float HandleEvent(float type);

	nonvirtual void EnsureBehavior(void);
	nonvirtual void ForceChange(BWAction a, string why);
	nonvirtual string StackString(void);

	nonvirtual float ShouldPickUp(entity item);
	nonvirtual float ShouldHurry(void);
	nonvirtual float ShouldRetreat(void);
	nonvirtual float IsPositionAllowed(vector pos);
	nonvirtual entity SelectMoreDangerousThreat(entity a, entity b);
	nonvirtual vector SelectTargetPoint(entity subject);
};

class BWAction : BWEvents {
	BWBot m_bot;
	BWAction m_parent;	/* action whose child stack holds this one */
	BWAction m_child;	/* top of this action's child stack */
	BWAction m_under;	/* action this one is suspended over */
	BWAction m_over;	/* action suspended over this one */
	float m_started, m_ended, m_suspended, m_childinit;
	float m_req_type, m_req_prio;
	BWAction m_req_action;
	string m_req_why;
	entity m_owned;		/* objects freed with the action, linked by bw_ownnext */

	virtual string GetName(void);
	virtual float OnStart(BWAction prior);
	virtual float Update(float interval);
	virtual void OnEnd(BWAction next);
	virtual float OnSuspend(BWAction by);
	virtual float OnResume(BWAction from);
	virtual BWAction InitialChild(void);

	virtual float ShouldPickUp(entity item);
	virtual float ShouldHurry(void);
	virtual float ShouldRetreat(void);
	virtual float IsPositionAllowed(vector pos);
	virtual entity SelectMoreDangerousThreat(entity a, entity b);
	virtual vector SelectTargetPoint(entity subject);

	virtual float HandleEvent(float type);

	nonvirtual float Continue(void);
	nonvirtual float ChangeTo(BWAction a, string why);
	nonvirtual float SuspendFor(BWAction a, string why);
	nonvirtual float Done(string why);
	nonvirtual float TryChangeTo(BWAction a, float prio, string why);
	nonvirtual float TrySuspendFor(BWAction a, float prio, string why);
	nonvirtual float TryDone(float prio, string why);
	nonvirtual float TryToSustain(float prio, string why);
	nonvirtual void Own(entity obj);
	nonvirtual BWAction GetActiveChild(void);
};

class BWPath {
	bw_seg_t *m_segs;
	float m_count;
	float m_valid, m_partial;
	float m_computed;
	float m_length;
	vector m_goal;

	nonvirtual void Invalidate(void);
	nonvirtual void Free(void);
	virtual float Compute(BWBot bot, vector goal, float forbid);
	nonvirtual float AddPoint(vector pos, float type);
	nonvirtual void Finish(void);
	nonvirtual float IsValid(void);
	nonvirtual float GetLength(void);
	nonvirtual vector GetEndPosition(void);
	nonvirtual vector PointAt(float d);
	nonvirtual float ClosestDistance(vector pos);
	nonvirtual vector ClosestPoint(vector pos);
	nonvirtual void Draw(void);
	nonvirtual void Probe(BWBot bot, vector a, vector b);
};

class BWPathFollower : BWPath {
	float m_goal_idx;
	float m_best, m_progress_time;
	float m_failed;
	float m_last_follow;
	float m_block_since;
	vector m_dodge_dir;
	float m_dodge_until;
	float m_speed;		/* base speed; 0 uses the bot's run speed */
	entity m_ignore;	/* not avoided (a chased subject) */

	virtual float Compute(BWBot bot, vector goal, float forbid);
	virtual void Follow(BWBot bot);
	nonvirtual float CheckProgress(BWBot bot);
	nonvirtual float IsReached(BWBot bot, float i);
	nonvirtual vector Avoid(BWBot bot, vector goal);
	nonvirtual void Fail(BWBot bot, float reason);
	nonvirtual vector CurrentGoal(void);
	nonvirtual float Sidestep(BWBot bot);
};

class BWChasePath : BWPathFollower {
	entity m_subject;
	float m_next_repath;
	float m_lead;		/* lead the subject when inside this radius; 0 off */
	float m_direct;		/* drive straight at a visible, reachable subject */
	float m_lifetime;	/* repath after this long; 0 never */
	float m_tolerance;

	virtual void Chase(BWBot bot, entity subject);
	nonvirtual vector PredictSubjectPosition(BWBot bot, entity subject);
	nonvirtual float IsRepathNeeded(BWBot bot, entity subject);
};

/* the bot itself: games derive from this. A game whose player bots must be
 * its own player class defines BW_PAWN_BASE to that class before including
 * the framework, so the bot is both (see docs/spec/bots.md, "Player bots"). */
#ifdef BW_PAWN_BASE
class BWBot : BW_PAWN_BASE {
#else
class BWBot {
#endif
	BWLocomotion m_loco;
	BWBody m_body;
	BWVision m_vision;
	BWIntention m_intention;
	float m_next_think, m_last_think;
	float m_bot_dead;
	float m_bot_paused;
	BWBot m_bot_next;
	float m_debug_on;
	float m_btn_until[8];	/* held buttons, by bit */
	float m_btn_once;	/* pressed for the next input frame only */
	float m_impulse;

	virtual BWLocomotion CreateLocomotion(void);
	virtual BWBody CreateBody(void);
	virtual BWVision CreateVision(void);
	virtual BWIntention CreateIntention(void);
	virtual BWAction InitialAction(void);
	virtual BWAction DeadAction(void);

	virtual float IsEnemy(entity e);
	virtual float IsFriend(entity e);
#ifndef BW_PAWN_BASE
	virtual float IsAlive(void);	/* the pawn class has its own */
#endif
	virtual string BotName(void);

	nonvirtual void BotStart(void);
	nonvirtual void BotRemove(void);
	nonvirtual void BotRespawn(void);
	nonvirtual void BotFrame(void);
	nonvirtual void SendEvent(float type);
	nonvirtual void Killed(entity inflictor, entity attacker, float damage);
	nonvirtual float IsDebugging(float category);

	/* player bots: buttons and weapon switches for the input frame */
	nonvirtual void PressButton(float bits, float duration);
	nonvirtual void ReleaseButton(float bits);
	nonvirtual float IsButtonDown(float bits);
	nonvirtual float TakeButtons(void);
	nonvirtual void SelectWeapon(float impulse);
	nonvirtual void PlayerInput(void);
};

.entity bw_ownnext;
.float bw_ispath;	/* set on BWPath objects, which own memory */
BWBot bw_bots;		/* every bot, linked by m_bot_next */
float bw_nbots;

/* forward declarations of the plain functions */
void bw_log(BWBot bot, float cat, string msg);
float bw_cvar(string name);
float bw_anglediff(float a, float b);
vector bw_flat(vector v);
float bw_dist2d(vector a, vector b);
BWAction bw_stack_update(BWAction top, float interval);
float bw_stack_event(BWAction top, float type);
void bw_stack_end(BWAction top, BWAction next);
BWAction bw_action_begin(BWAction a, BWBot bot, BWAction parent, BWAction under, BWAction prior, float depth);
BWAction bw_apply(BWAction cur, float r, BWAction target, string why, float depth);
string bw_stack_string(BWAction top);
void bw_ev_save(void);
void bw_ev_load(void);
void bw_ev_drop(void);
string bw_event_name(float type);
float bw_wp_load(void);
float bw_wp_count;
bw_wp_t *bw_wps;
bw_wplink_t *bw_wplinks;
float bw_wp_nearest(vector pos, float los);
float bw_route(float from, float to, float forbid);
float *bw_route_nodes;
float bw_route_len;
float bw_route_partial;
void bw_bot_physics(void);
void bw_player_input(entity pawn);
void bw_console_register(void);
float bw_debug_matches(BWBot bot);
