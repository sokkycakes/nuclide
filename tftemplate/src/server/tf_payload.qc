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

/** @file tf_payload.qc
Payload: the cart, the watcher that turns pushers into cart speed, and the
round timer, round win and respawn entities payload maps lean on.

Speeds and timings follow the Team Fortress 2 wiki's description of payload:
one pusher moves the cart at 55% of its top speed, two at 77%, three or more
at full speed; Scouts count as two. Defenders on the cart stop it. When no
attacker has pushed for 30 seconds (or "train_recede_time") it rolls back,
but never past the last checkpoint. The recede speed is not documented
there; tf_pl_recedespeed is an estimate.
*/

var float autocvar_tf_pl_speed1 = 0.55f;
var float autocvar_tf_pl_speed2 = 0.77f;
var float autocvar_tf_pl_speed3 = 1.0f;
var float autocvar_tf_pl_recedetime = 30.0f;
var float autocvar_tf_pl_recedespeed = 0.5f;
var string autocvar_tf_pl_cartmodel = "progs/armor.mdl";
var float autocvar_tf_pl_cartscale = 2.0f;

#define TFTRAIN_TICK 0.1f
#define TFTRAIN_MAXCHILDREN 16

/** Whether `testEnt` rides along with the entity named `parentName`:
its "parentname" key names it, or it's a phys_constraint tying something
to it. Returns the rider's name for constraints (the other end), the
entity's own targetname when it is parented, "" otherwise. */
string
TF_RiderName(entity testEnt, string parentName)
{
	ncEntity theEnt = (ncEntity)testEnt;

	if (testEnt.classname == "phys_constraint" || testEnt.classname == "phys_ballsocket" || testEnt.classname == "phys_hinge") {
		string attachA = theEnt.GetSpawnString("attach1");
		string attachB = theEnt.GetSpawnString("attach2");

		if (attachA == parentName) {
			return (attachB);
		} else if (attachB == parentName) {
			return (attachA);
		}

		return ("");
	}

	return (theEnt.GetSpawnString("parentname") == parentName) ? "!self" : "";
}

/** Stands in for a cart prop whose model is missing (or copies it when it
isn't), so the cart can be seen. It keeps the prop's targetname so map
logic aimed at the prop still finds it, and "Kill" only hides it until the
next round. */
class
tfCartVisual:ncRenderableEntity
{
public:
	void tfCartVisual(void);

	virtual void Input(entity, string, string);
	nonvirtual void PutBack(void);

	string m_visualModel;
	vector m_visualAngles;
	vector m_visualHome;
	float m_visualScale;
};

void
tfCartVisual::tfCartVisual(void)
{
	m_visualModel = __NULL__;
	m_visualScale = 1.0f;
}

void
tfCartVisual::PutBack(void)
{
	SetModel(m_visualModel);
	SetAngles(m_visualAngles);
	SetScale(m_visualScale);
	SetSolid(SOLID_NOT);
	SetMovetype(MOVETYPE_NOCLIP);
	SetVelocity([0, 0, 0]);
	SetOrigin(m_visualHome);
	Show();
}

void
tfCartVisual::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "Kill":
	case "KillHierarchy":
		Hide();
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}

/** func_tracktrain for Team Fortress maps: a brush that slides along a
chain of path_track nodes. A team_train_watcher drives payload carts
through SetTrainSpeed(); other trains move by their inputs.

Keys: "target" (first path_track), "startspeed" (top speed), "speed"
(speed it starts moving at), "height" (above the path), "dmg" (damage to
whatever blocks it). The train doesn't turn: it slides with its spawn
orientation.

Inputs: StartForward, StartBackward, Stop, Resume, SetSpeed (fraction of
startspeed), SetSpeedReal (units per second), SetSpeedDir (signed
fraction), TeleportToPathTrack. Kill stops and hides it until the next
round instead of removing it, so rounds can restart.

Entities whose "parentname" is this train, and props tied to it by a
phys_constraint, move with it. path_track OnPass outputs fire as the train
passes a node going forward. */
class
tfTrackTrain:ncRenderableEntity
{
public:
	void tfTrackTrain(void);

	virtual void SpawnKey(string, string);
	virtual void Spawned(void);
	virtual void Respawn(void);
	virtual void Input(entity, string, string);
	virtual void Blocked(entity);

	nonvirtual void SetTrainSpeed(float);
	nonvirtual float TrainSpeed(void);
	nonvirtual float TopSpeed(void);
	nonvirtual bool IsStopped(void);
	nonvirtual bool IsKilled(void);
	nonvirtual void TeleportToNode(path_track);
	nonvirtual path_track NodeBehind(void);
	nonvirtual path_track NodeAhead(void);
	nonvirtual vector NodePosition(entity);

	nonvirtual void _AddRider(entity);
	nonvirtual void _Activate(void);
	nonvirtual void _Tick(void);
	nonvirtual void _MoveRiders(void);
	nonvirtual float _Advance(float);

private:
	float m_startSpeed;
	float m_initialSpeed;
	float m_height;
	float m_damage;
	float m_speed;
	bool m_killed;
	bool m_stuck;
	path_track m_nodeBehind;
	path_track m_nodeAhead;
	vector m_logicalPos;

	int m_riderCount;
	entity m_riders[TFTRAIN_MAXCHILDREN];
	vector m_riderOffsets[TFTRAIN_MAXCHILDREN];
};

void
tfTrackTrain::tfTrackTrain(void)
{
	m_startSpeed = 100.0f;
	m_initialSpeed = 0.0f;
	m_height = 0.0f;
	m_damage = 0.0f;
	m_speed = 0.0f;
	m_killed = false;
	m_stuck = false;
	m_riderCount = 0i;
}

void
tfTrackTrain::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "startspeed":
		m_startSpeed = ReadFloat(setValue);
		break;
	case "speed":
		m_initialSpeed = ReadFloat(setValue);
		break;
	case "height":
		m_height = ReadFloat(setValue);
		break;
	case "dmg":
		m_damage = ReadFloat(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfTrackTrain::Spawned(void)
{
	super::Spawned();

	/* models can only be precached while the map spawns */
	precache.Model(autocvar_tf_pl_cartmodel);
}

void
tfTrackTrain::Respawn(void)
{
	/* back to where the mapper built it, so the riders' offsets can be
	   measured before moving onto the track */
	SetModel(GetSpawnString("model"));
	SetOrigin(GetSpawnVector("origin"));
	SetAngles(GetSpawnVector("angles"));
	SetMovetype(MOVETYPE_PUSH);
	SetSolid(HasSpawnFlags(8) ? SOLID_NOT : SOLID_BSP);
	SetVelocity([0, 0, 0]);
	Show();

	m_killed = false;
	m_stuck = false;
	m_speed = m_initialSpeed;
	m_nodeBehind = m_nodeAhead = __NULL__;
	m_riderCount = 0i;
	m_logicalPos = GetOrigin();

	/* once everything else has spawned */
	ScheduleThink(_Activate, 0.1f);
}

void
tfTrackTrain::_AddRider(entity riderEnt)
{
	if (m_riderCount >= TFTRAIN_MAXCHILDREN || riderEnt == this || is.Player(riderEnt)) {
		return;
	}

	/* props become a visual that follows the train. The prop stays where
	   it was built, out of sight; the visual takes its name, so map logic
	   aimed at the prop reaches the visual. */
	if (substring(riderEnt.classname, 0, 5) == "prop_") {
		tfCartVisual cartVisual = __NULL__;

		for (entity v = world; (v = find(v, ::classname, "tfCartVisual"));) {
			if (v.owner == this) {
				cartVisual = (tfCartVisual)v;
			}
		}

		if (!cartVisual) {
			cartVisual = spawn(tfCartVisual);
			cartVisual.classname = "tfCartVisual";
			cartVisual.owner = this;
			cartVisual.targetname = riderEnt.targetname;
			ncEntity theProp = (ncEntity)riderEnt;
			string propModel = theProp.GetSpawnString("model");
			cartVisual.m_visualModel = propModel;
			cartVisual.m_visualAngles = riderEnt.angles;
			cartVisual.m_visualHome = riderEnt.origin;

			if (!STRING_SET(propModel) || TF_PropModelMissing(propModel)) {
				/* a stand-in, sitting on the train's floor */
				cartVisual.m_visualModel = autocvar_tf_pl_cartmodel;
				cartVisual.m_visualScale = autocvar_tf_pl_cartscale;
				cartVisual.m_visualAngles = [0, 0, 0];
				cartVisual.m_visualHome = [origin[0], origin[1], origin[2] + mins[2]];
			}
		}

		riderEnt.solid = SOLID_NOT;
		riderEnt.movetype = MOVETYPE_NONE;
		riderEnt.effects |= EF_NODRAW;
		riderEnt = cartVisual;
	}

	for (int i = 0i; i < m_riderCount; i++) {
		if (m_riders[i] == riderEnt) {
			return;
		}
	}

	if (riderEnt.classname == "tfCartVisual") {
		tfCartVisual theVisual = (tfCartVisual)riderEnt;
		theVisual.PutBack();
	}

	/* we move riders ourselves; Nuclide's parenting assigns origins
	   without relinking, which leaves trigger bounds behind */
	riderEnt.tag_entity = world;

	m_riders[m_riderCount] = riderEnt;
	m_riderOffsets[m_riderCount] = riderEnt.origin - origin;
	m_riderCount++;
}

void
tfTrackTrain::_Activate(void)
{
	/* riders are measured from where the train was built */
	if (STRING_SET(targetname)) {
		for (entity e = world; (e = findfloat(e, ::identity, 1));) {
			string riderName = TF_RiderName(e, targetname);

			if (riderName == "!self") {
				_AddRider(e);
			} else if (STRING_SET(riderName)) {
				for (entity r = world; (r = find(r, ::targetname, riderName));) {
					_AddRider(r);
				}
			}
		}
	}

	path_track firstNode = (path_track)find(world, ::targetname, target);

	if (firstNode && firstNode.classname == "path_track") {
		TeleportToNode(firstNode);
	}

	ScheduleThink(_Tick, TFTRAIN_TICK);
}

vector
tfTrackTrain::NodePosition(entity nodeEnt)
{
	return (nodeEnt.origin + [0, 0, m_height]);
}

void
tfTrackTrain::TeleportToNode(path_track nodeEnt)
{
	m_nodeBehind = nodeEnt;
	m_nodeAhead = (path_track)nodeEnt.GetPathTargetEntity();

	if (m_nodeAhead == nodeEnt) {
		m_nodeAhead = __NULL__;
	}

	m_logicalPos = NodePosition(nodeEnt);
	SetOrigin(m_logicalPos);
	SetVelocity([0, 0, 0]);
	_MoveRiders();
}

path_track
tfTrackTrain::NodeBehind(void)
{
	return (m_nodeBehind);
}

path_track
tfTrackTrain::NodeAhead(void)
{
	return (m_nodeAhead);
}

float
tfTrackTrain::TopSpeed(void)
{
	return (m_startSpeed);
}

float
tfTrackTrain::TrainSpeed(void)
{
	return (m_speed);
}

void
tfTrackTrain::SetTrainSpeed(float newSpeed)
{
	if (m_killed) {
		newSpeed = 0.0f;
	}

	m_speed = bound(-m_startSpeed, newSpeed, m_startSpeed);
}

bool
tfTrackTrain::IsStopped(void)
{
	return (m_stuck || m_speed == 0.0f) ? (true) : (false);
}

bool
tfTrackTrain::IsKilled(void)
{
	return (m_killed);
}

/** Moves the logical position `moveDist` units along the track (negative is
backwards) and returns how far it actually got. */
float
tfTrackTrain::_Advance(float moveDist)
{
	float movedDist = 0.0f;

	while (fabs(moveDist) > 0.001f) {
		if (moveDist > 0.0f) {
			if (!m_nodeAhead) {
				break;
			}

			vector aheadPos = NodePosition(m_nodeAhead);
			float toAhead = vlen(aheadPos - m_logicalPos);

			if (moveDist < toAhead) {
				m_logicalPos += normalize(aheadPos - m_logicalPos) * moveDist;
				movedDist += moveDist;
				break;
			}

			/* reached the node ahead: it's passed */
			m_logicalPos = aheadPos;
			movedDist += toAhead;
			moveDist -= toAhead;
			m_nodeBehind = m_nodeAhead;
			m_nodeAhead = (path_track)m_nodeBehind.GetPathTargetEntity();

			if (m_nodeAhead == m_nodeBehind) {
				m_nodeAhead = __NULL__;
			}

			m_nodeBehind.PathPassTrigger(this, TRIG_TOGGLE);

			if (m_killed) {
				break;
			}
		} else {
			if (!m_nodeBehind) {
				break;
			}

			vector behindPos = NodePosition(m_nodeBehind);
			float toBehind = vlen(behindPos - m_logicalPos);

			if (-moveDist < toBehind) {
				m_logicalPos += normalize(behindPos - m_logicalPos) * -moveDist;
				movedDist += moveDist;
				break;
			}

			/* back on the node behind; carry on to the one before it,
			   unless it's disabled (checkpoints disable it) */
			m_logicalPos = behindPos;
			movedDist -= toBehind;
			moveDist += toBehind;
			path_track nodeBefore = (path_track)m_nodeBehind.GetSelfTargetEntity();

			if (!nodeBefore) {
				break;
			}

			m_nodeAhead = m_nodeBehind;
			m_nodeBehind = nodeBefore;
		}
	}

	return (movedDist);
}

void
tfTrackTrain::_MoveRiders(void)
{
	for (int i = 0i; i < m_riderCount; i++) {
		entity riderEnt = m_riders[i];

		if (wasfreed(riderEnt)) {
			continue;
		}

		setorigin(riderEnt, origin + m_riderOffsets[i]);

		/* visuals glide along; triggers and points just follow */
		if (riderEnt.movetype == MOVETYPE_NOCLIP) {
			riderEnt.velocity = velocity;
		}
	}
}

void
tfTrackTrain::_Tick(void)
{
	/* snap to where the last tick meant to end up, so we don't drift */
	if (vlen(origin - m_logicalPos) > 0.5f) {
		SetOrigin(m_logicalPos);
	}

	float wantDist = m_speed * TFTRAIN_TICK;
	float gotDist = _Advance(wantDist);
	m_stuck = (fabs(gotDist) < fabs(wantDist) * 0.5f) ? true : false;

	SetVelocity((m_logicalPos - origin) * (1.0f / TFTRAIN_TICK));
	_MoveRiders();
	ScheduleThink(_Tick, TFTRAIN_TICK);
}

void
tfTrackTrain::Blocked(entity blockingEnt)
{
	if (m_damage > 0.0f && blockingEnt.takedamage != DAMAGE_NO) {
		ents.Input(blockingEnt, "Damage", ftos(m_damage), this);
	}
}

void
tfTrackTrain::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "StartForward":
	case "Resume":
		SetTrainSpeed(m_startSpeed);
		break;
	case "StartBackward":
		SetTrainSpeed(-m_startSpeed);
		break;
	case "Stop":
		SetTrainSpeed(0.0f);
		break;
	case "SetSpeed":
		SetTrainSpeed(fabs(stof(dataField)) * m_startSpeed * ((m_speed < 0.0f) ? -1 : 1));
		break;
	case "SetSpeedDir":
		SetTrainSpeed(stof(dataField) * m_startSpeed);
		break;
	case "SetSpeedReal":
		SetTrainSpeed(stof(dataField));
		break;
	case "TeleportToPathTrack":
		path_track toNode = (path_track)find(world, ::targetname, dataField);

		if (toNode) {
			TeleportToNode(toNode);
		}
		break;
	case "Kill":
	case "KillHierarchy":
		m_killed = true;
		m_speed = 0.0f;
		SetSolid(SOLID_NOT);
		SetVelocity([0, 0, 0]);
		Hide();
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}

/** team_train_watcher: turns the players at a payload cart into its speed,
and tracks how far along the track it is.

Keys follow Team Fortress 2:
- "train": the func_tracktrain
- "start_node", "goal_node": first and last path_track
- "linked_pathtrack_1" .. "_8": checkpoint nodes, with "linked_cp_1" .. "_8"
  the team_control_point each one stands for
- "train_can_recede": 1 to roll back when nobody pushes
- "train_recede_time": seconds before rolling back (0 means 30)
- "handle_train_movement": 0 leaves the train's speed alone
- "speed_forward_modifier": scales the push speeds

The pushers are counted in the trigger_capture_area that rides with the
train. The team that may capture there pushes; the other team blocks.
Outputs: OnTrainStartRecede, OnTrainStopRecede. */
class
tfTrainWatcher:ncEntity
{
public:
	void tfTrainWatcher(void);

	virtual void SpawnKey(string, string);
	virtual void Spawned(void);
	virtual void Respawn(void);
	virtual void Input(entity, string, string);

	nonvirtual tfTrackTrain GetTrain(void);
	nonvirtual tfCaptureArea GetArea(void);
	nonvirtual float AttackingTeam(void);
	nonvirtual float Progress(void);
	nonvirtual void _Activate(void);
	nonvirtual void _Tick(void);

private:
	string m_trainName;
	string m_startName;
	string m_goalName;
	string m_checkpointNames[8];
	bool m_canRecede;
	float m_recedeTime;
	bool m_handleMovement;
	float m_forwardModifier;
	bool m_startDisabled;
	bool m_disabled;

	/* the track, from start to goal */
	int m_nodeCount;
	entity m_nodes[128];
	float m_nodeDistance[128];
	float m_trackLength;

	float m_lastPush;
	bool m_receding;
	bool m_delivered;

	/* Nuclide's botlib goes for GOALITEM hints whose owner isn't on its
	   team: one rides on the cart, owned by the (teamless) train */
	ncHint m_botHint;

	string m_outputOnTrainStartRecede;
	string m_outputOnTrainStopRecede;
};

void
tfTrainWatcher::tfTrainWatcher(void)
{
	m_trainName = __NULL__;
	m_startName = __NULL__;
	m_goalName = __NULL__;

	for (int i = 0i; i < 8i; i++) {
		m_checkpointNames[i] = __NULL__;
	}

	m_canRecede = true;
	m_recedeTime = 0.0f;
	m_handleMovement = true;
	m_forwardModifier = 1.0f;
	m_startDisabled = false;
	m_outputOnTrainStartRecede = __NULL__;
	m_outputOnTrainStopRecede = __NULL__;
}

void
tfTrainWatcher::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "train":
		m_trainName = ReadString(setValue);
		break;
	case "start_node":
		m_startName = ReadString(setValue);
		break;
	case "goal_node":
		m_goalName = ReadString(setValue);
		break;
	case "linked_pathtrack_1":
	case "linked_pathtrack_2":
	case "linked_pathtrack_3":
	case "linked_pathtrack_4":
	case "linked_pathtrack_5":
	case "linked_pathtrack_6":
	case "linked_pathtrack_7":
	case "linked_pathtrack_8":
		m_checkpointNames[stof(substring(keyName, 17, 1)) - 1] = ReadString(setValue);
		break;
	case "train_can_recede":
		m_canRecede = ReadBool(setValue);
		break;
	case "train_recede_time":
		m_recedeTime = ReadFloat(setValue);
		break;
	case "handle_train_movement":
		m_handleMovement = ReadBool(setValue);
		break;
	case "speed_forward_modifier":
		m_forwardModifier = ReadFloat(setValue);
		break;
	case "StartDisabled":
		m_startDisabled = ReadBool(setValue);
		break;
	case "OnTrainStartRecede":
		m_outputOnTrainStartRecede = PrepareOutput(m_outputOnTrainStartRecede, setValue);
		break;
	case "OnTrainStopRecede":
		m_outputOnTrainStopRecede = PrepareOutput(m_outputOnTrainStopRecede, setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfTrainWatcher::Spawned(void)
{
	super::Spawned();

	if (STRING_SET(m_outputOnTrainStartRecede))
		m_outputOnTrainStartRecede = CreateOutput(m_outputOnTrainStartRecede);
	if (STRING_SET(m_outputOnTrainStopRecede))
		m_outputOnTrainStopRecede = CreateOutput(m_outputOnTrainStopRecede);
}

void
tfTrainWatcher::Respawn(void)
{
	tf_isObjective = 1;
	tf_objective = TFOBJ_CART;
	tf_cartProgress = 0.0f;
	tf_cartPushers = 0.0f;
	tf_cartState = TFCART_IDLE;
	team = TF_TEAM_NONE;

	SetOrigin(GetSpawnVector("origin"));
	SetSolid(SOLID_NOT);
	SetMovetype(MOVETYPE_NONE);
	m_disabled = m_startDisabled;
	m_lastPush = time;
	m_receding = false;
	m_delivered = false;
	m_nodeCount = 0i;

	/* after the train has found its track */
	ScheduleThink(_Activate, 0.3f);
}

tfTrackTrain
tfTrainWatcher::GetTrain(void)
{
	tfTrackTrain theTrain = (tfTrackTrain)find(world, ::targetname, m_trainName);

	if (theTrain && theTrain.classname == "func_tracktrain") {
		return (theTrain);
	}

	return (__NULL__);
}

/** The trigger_capture_area that rides with the train. */
tfCaptureArea
tfTrainWatcher::GetArea(void)
{
	for (entity e = world; (e = find(e, ::classname, "trigger_capture_area"));) {
		ncEntity theArea = (ncEntity)e;

		if (theArea.GetSpawnString("parentname") == m_trainName) {
			return ((tfCaptureArea)e);
		}
	}

	return (__NULL__);
}

float
tfTrainWatcher::AttackingTeam(void)
{
	tfCaptureArea theArea = GetArea();

	if (theArea) {
		if (theArea.TeamCanCap(TF_TEAM_BLU) && !theArea.TeamCanCap(TF_TEAM_RED)) {
			return (TF_TEAM_BLU);
		} else if (theArea.TeamCanCap(TF_TEAM_RED) && !theArea.TeamCanCap(TF_TEAM_BLU)) {
			return (TF_TEAM_RED);
		}
	}

	return (TF_TEAM_BLU);
}

void
tfTrainWatcher::_Activate(void)
{
	/* walk the track once, so progress can be measured */
	entity nodeEnt = find(world, ::targetname, m_startName);
	m_trackLength = 0.0f;
	m_nodeCount = 0i;

	while (nodeEnt && m_nodeCount < 128i) {
		if (m_nodeCount > 0i) {
			m_trackLength += vlen(nodeEnt.origin - m_nodes[m_nodeCount - 1i].origin);
		}

		m_nodes[m_nodeCount] = nodeEnt;
		m_nodeDistance[m_nodeCount] = m_trackLength;
		m_nodeCount++;

		if (nodeEnt.targetname == m_goalName || !STRING_SET(nodeEnt.target)) {
			break;
		}

		nodeEnt = find(world, ::targetname, nodeEnt.target);

		/* loops back on itself */
		for (int i = 0i; i < m_nodeCount; i++) {
			if (m_nodes[i] == nodeEnt) {
				nodeEnt = __NULL__;
				break;
			}
		}
	}

	team = AttackingTeam();

	if (!m_botHint) {
		m_botHint = spawn(ncHint);
		m_botHint.m_hintType = "GOALITEM";
	}

	m_botHint.owner = GetTrain();
	ScheduleThink(_Tick, 0.1f);
}

/** 0 at the start node, 1 at the goal. */
float
tfTrainWatcher::Progress(void)
{
	tfTrackTrain theTrain = GetTrain();

	if (!theTrain || m_trackLength <= 0.0f) {
		return (0.0f);
	}

	entity behindNode = theTrain.NodeBehind();

	for (int i = 0i; i < m_nodeCount; i++) {
		if (m_nodes[i] == behindNode) {
			float trackPos = m_nodeDistance[i] + vlen(theTrain.origin - theTrain.NodePosition(behindNode));
			return bound(0.0f, trackPos / m_trackLength, 1.0f);
		}
	}

	return (tf_cartProgress);
}

void
tfTrainWatcher::_Tick(void)
{
	tfTrackTrain theTrain = GetTrain();
	tfCaptureArea theArea = GetArea();
	float attackTeam = team;
	float pushWeight = 0.0f;
	float defenders = 0.0f;
	float newSpeed = 0.0f;

	ScheduleThink(_Tick, 0.1f);

	if (!theTrain || theTrain.IsKilled()) {
		tf_cartPushers = 0.0f;
		tf_cartState = TFCART_IDLE;
		return;
	}

	tf_cartProgress = Progress();

	/* the watcher stands where the cart's push zone is, so bot code can
	   go to it like any other objective (TF_ObjectiveFor) */
	if (theArea) {
		setorigin(this, (theArea.absmin + theArea.absmax) * 0.5f);
	} else {
		setorigin(this, theTrain.WorldSpaceCenter());
	}

	if (m_botHint) {
		setorigin(m_botHint, origin);
	}

	if (m_disabled || !theArea) {
		return;
	}

	for (entity e = world; (e = next.Player(e));) {
		if (is.Alive(e) == false || theArea.Contains(e) == false) {
			continue;
		}

		if (e.team == attackTeam) {
			pushWeight += (e.tf_capRate > 0.0f) ? e.tf_capRate : 1.0f;
		} else if (e.team == TF_EnemyTeam(attackTeam)) {
			defenders += 1;
		}
	}

	/* the rules may hold the cart, e.g. during setup */
	bool cartLive = TF_RulesAllow("TFRules_AllowCartPush", this, attackTeam);

	if (cartLive == false) {
		pushWeight = 0.0f;
	}

	tf_cartPushers = pushWeight;

	if (pushWeight > 0.0f && defenders > 0.0f) {
		tf_cartState = TFCART_BLOCKED;
		m_lastPush = time;
	} else if (pushWeight > 0.0f) {
		float speedFraction = autocvar_tf_pl_speed1;

		if (pushWeight >= 3.0f) {
			speedFraction = autocvar_tf_pl_speed3;
		} else if (pushWeight >= 2.0f) {
			speedFraction = autocvar_tf_pl_speed2;
		}

		newSpeed = theTrain.TopSpeed() * speedFraction * m_forwardModifier;
		tf_cartState = TFCART_PUSHED;
		m_lastPush = time;
	} else {
		float recedeAfter = (m_recedeTime > 0.0f) ? m_recedeTime : autocvar_tf_pl_recedetime;

		if (m_canRecede && cartLive && (time - m_lastPush) >= recedeAfter) {
			newSpeed = -theTrain.TopSpeed() * autocvar_tf_pl_recedespeed;
		}

		tf_cartState = (newSpeed < 0.0f) ? TFCART_RECEDING : TFCART_IDLE;
	}

	/* a receding cart that's back at a checkpoint has stopped */
	if (tf_cartState == TFCART_RECEDING && theTrain.IsStopped() && theTrain.TrainSpeed() < 0.0f) {
		tf_cartState = TFCART_IDLE;
	}

	if (tf_cartState == TFCART_RECEDING && m_receding == false) {
		m_receding = true;
		UseOutput(this, m_outputOnTrainStartRecede);
	} else if (tf_cartState != TFCART_RECEDING && m_receding == true) {
		m_receding = false;
		UseOutput(this, m_outputOnTrainStopRecede);
	}

	if (m_handleMovement) {
		theTrain.SetTrainSpeed(newSpeed);
	}

	/* delivered */
	entity trainAt = theTrain.NodeBehind();

	if (m_delivered == false && STRING_SET(m_goalName) && trainAt && trainAt.targetname == m_goalName) {
		m_delivered = true;
		tf_cartProgress = 1.0f;
		TF_RulesEvent("TF_CartDelivered", this, ftos(attackTeam));
	}
}

void
tfTrainWatcher::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "Enable":
		m_disabled = false;
		break;
	case "Disable":
		m_disabled = true;
		break;
	case "SetTrainCanRecede":
		m_canRecede = stof(dataField) ? true : false;
		break;
	case "SetTrainRecedeTime":
		m_recedeTime = stof(dataField);
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}

/** mapobj_cart_dispenser: heals and resupplies its team ("TeamNum") inside
the volume named by "touch_trigger", like a level 1 Dispenser: 10 health
per second and a fifth of each ammo type per second (TF2 wiki figures). */
class
tfCartDispenser:ncEntity
{
public:
	void tfCartDispenser(void);

	virtual void SpawnKey(string, string);
	virtual void Respawn(void);
	nonvirtual void _Tick(void);

private:
	float m_dispenserTeam;
	string m_touchName;
	float m_lastTick;
};

void
tfCartDispenser::tfCartDispenser(void)
{
	m_dispenserTeam = TF_TEAM_NONE;
	m_touchName = __NULL__;
}

void
tfCartDispenser::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "TeamNum":
		m_dispenserTeam = TF_TeamFromMapKey(ReadFloat(setValue));
		break;
	case "touch_trigger":
		m_touchName = ReadString(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfCartDispenser::Respawn(void)
{
	SetOrigin(GetSpawnVector("origin"));
	SetSolid(SOLID_NOT);
	SetMovetype(MOVETYPE_NONE);
	team = m_dispenserTeam;
	m_lastTick = time;
	ScheduleThink(_Tick, 0.5f);
}

void
tfCartDispenser::_Tick(void)
{
	tfVolume touchVolume = (tfVolume)find(world, ::targetname, m_touchName);
	float deltaTime = time - m_lastTick;
	m_lastTick = time;
	ScheduleThink(_Tick, 0.2f);

	if (!touchVolume) {
		return;
	}

	for (entity e = world; (e = next.Player(e));) {
		if (is.Alive(e) == false || touchVolume.Contains(e) == false) {
			continue;
		}

		if (m_dispenserTeam != TF_TEAM_NONE && e.team != m_dispenserTeam) {
			continue;
		}

		ncPlayer thePlayer = (ncPlayer)e;

		if (thePlayer.GetHealth() < thePlayer.GetMaxHealth()) {
			thePlayer.SetHealth(min(thePlayer.GetHealth() + 10.0f * deltaTime, thePlayer.GetMaxHealth()));
		}

		for (int ammoID = 1i; ammoID < 16i; ammoID++) {
			int maxAmmo = ammo.MaxForNum(ammoID);

			if (maxAmmo > 0i) {
				thePlayer.GiveAmmo(ammoID, (int)ceil(maxAmmo * 0.2f * deltaTime));
			}
		}
	}
}

/** dispenser_touch_trigger: the volume a mapobj_cart_dispenser serves. It
does nothing by itself. */
class
tfDispenserTouch:tfVolume
{
public:
	void tfDispenserTouch(void);
};

void
tfDispenserTouch::tfDispenserTouch(void)
{
}

/** team_round_timer: the map's round clock. The rules own the clock; this
entity gives them the map's lengths and turns the round's progress into
outputs.

Keys: "timer_length" (seconds of play), "setup_length" (seconds of setup),
"max_length" (the most AddTime can stretch the clock to, 0 for no limit).
Inputs: AddTime <seconds>, AddTeamTime <team> <seconds>, SetTime <seconds>.
Outputs: OnSetupStart, OnSetupFinished, OnRoundStart, OnFinished,
On5MinRemain, On1MinRemain, On30SecRemain, On10SecRemain. */
class
tfRoundTimer:ncEntity
{
public:
	void tfRoundTimer(void);

	virtual void SpawnKey(string, string);
	virtual void Spawned(void);
	virtual void Respawn(void);
	virtual void Input(entity, string, string);
	nonvirtual void _Tick(void);

private:
	float m_lastRound;
	float m_lastLeft;

	string m_outputOnSetupStart;
	string m_outputOnSetupFinished;
	string m_outputOnRoundStart;
	string m_outputOnFinished;
	string m_outputOn5MinRemain;
	string m_outputOn1MinRemain;
	string m_outputOn30SecRemain;
	string m_outputOn10SecRemain;
};

void
tfRoundTimer::tfRoundTimer(void)
{
	tf_timerLength = 600.0f;
	tf_setupLength = 0.0f;
	tf_timerMax = 0.0f;
	m_outputOnSetupStart = __NULL__;
	m_outputOnSetupFinished = __NULL__;
	m_outputOnRoundStart = __NULL__;
	m_outputOnFinished = __NULL__;
	m_outputOn5MinRemain = __NULL__;
	m_outputOn1MinRemain = __NULL__;
	m_outputOn30SecRemain = __NULL__;
	m_outputOn10SecRemain = __NULL__;
}

void
tfRoundTimer::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "timer_length":
		tf_timerLength = ReadFloat(setValue);
		break;
	case "setup_length":
		tf_setupLength = ReadFloat(setValue);
		break;
	case "max_length":
		tf_timerMax = ReadFloat(setValue);
		break;
	case "OnSetupStart":
		m_outputOnSetupStart = PrepareOutput(m_outputOnSetupStart, setValue);
		break;
	case "OnSetupFinished":
		m_outputOnSetupFinished = PrepareOutput(m_outputOnSetupFinished, setValue);
		break;
	case "OnRoundStart":
		m_outputOnRoundStart = PrepareOutput(m_outputOnRoundStart, setValue);
		break;
	case "OnFinished":
		m_outputOnFinished = PrepareOutput(m_outputOnFinished, setValue);
		break;
	case "On5MinRemain":
		m_outputOn5MinRemain = PrepareOutput(m_outputOn5MinRemain, setValue);
		break;
	case "On1MinRemain":
		m_outputOn1MinRemain = PrepareOutput(m_outputOn1MinRemain, setValue);
		break;
	case "On30SecRemain":
		m_outputOn30SecRemain = PrepareOutput(m_outputOn30SecRemain, setValue);
		break;
	case "On10SecRemain":
		m_outputOn10SecRemain = PrepareOutput(m_outputOn10SecRemain, setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfRoundTimer::Spawned(void)
{
	super::Spawned();

	if (STRING_SET(m_outputOnSetupStart))
		m_outputOnSetupStart = CreateOutput(m_outputOnSetupStart);
	if (STRING_SET(m_outputOnSetupFinished))
		m_outputOnSetupFinished = CreateOutput(m_outputOnSetupFinished);
	if (STRING_SET(m_outputOnRoundStart))
		m_outputOnRoundStart = CreateOutput(m_outputOnRoundStart);
	if (STRING_SET(m_outputOnFinished))
		m_outputOnFinished = CreateOutput(m_outputOnFinished);
	if (STRING_SET(m_outputOn5MinRemain))
		m_outputOn5MinRemain = CreateOutput(m_outputOn5MinRemain);
	if (STRING_SET(m_outputOn1MinRemain))
		m_outputOn1MinRemain = CreateOutput(m_outputOn1MinRemain);
	if (STRING_SET(m_outputOn30SecRemain))
		m_outputOn30SecRemain = CreateOutput(m_outputOn30SecRemain);
	if (STRING_SET(m_outputOn10SecRemain))
		m_outputOn10SecRemain = CreateOutput(m_outputOn10SecRemain);
}

void
tfRoundTimer::Respawn(void)
{
	tf_roundTimer = 1;
	SetOrigin(GetSpawnVector("origin"));
	SetSolid(SOLID_NOT);
	SetMovetype(MOVETYPE_NONE);
	m_lastRound = serverinfo.GetFloat("tf_round");
	m_lastLeft = -1;
	ScheduleThink(_Tick, 0.1f);
}

void
tfRoundTimer::_Tick(void)
{
	float roundState = serverinfo.GetFloat("tf_round");
	float timeLeft = serverinfo.GetFloat("tf_timer");
	ScheduleThink(_Tick, 0.1f);

	if (roundState != m_lastRound) {
		if (roundState == TFROUND_SETUP) {
			UseOutput(this, m_outputOnSetupStart);
		} else if (roundState == TFROUND_ACTIVE) {
			if (m_lastRound == TFROUND_SETUP) {
				UseOutput(this, m_outputOnSetupFinished);
			}

			UseOutput(this, m_outputOnRoundStart);
		}

		m_lastRound = roundState;
		m_lastLeft = -1;
		return;
	}

	if (roundState != TFROUND_ACTIVE || timeLeft < 0) {
		return;
	}

	/* the clock crossing a mark, going down */
	if (m_lastLeft > 300 && timeLeft <= 300)
		UseOutput(this, m_outputOn5MinRemain);
	if (m_lastLeft > 60 && timeLeft <= 60)
		UseOutput(this, m_outputOn1MinRemain);
	if (m_lastLeft > 30 && timeLeft <= 30)
		UseOutput(this, m_outputOn30SecRemain);
	if (m_lastLeft > 10 && timeLeft <= 10)
		UseOutput(this, m_outputOn10SecRemain);

	/* overtime holds the clock at 0 without finishing */
	if (m_lastLeft > 0 && timeLeft == 0 && serverinfo.GetFloat("tf_overtime") == 0) {
		UseOutput(this, m_outputOnFinished);
	}

	m_lastLeft = timeLeft;
}

void
tfRoundTimer::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "AddTime":
		TF_RulesEvent("TF_AddTime", activatorEnt, sprintf("%s %d", dataField, tf_timerMax));
		break;
	case "AddTeamTime":
		/* "<team> <seconds>"; the team only matters for the HUD in TF2 */
		tokenize_console(dataField);
		TF_RulesEvent("TF_AddTime", activatorEnt, sprintf("%s %d", argv(1), tf_timerMax));
		break;
	case "SetTime":
		TF_RulesEvent("TF_SetTime", activatorEnt, dataField);
		break;
	case "SetSetupTime":
		tf_setupLength = stof(dataField);
		break;
	case "SetMaxTime":
		tf_timerMax = stof(dataField);
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}

/** game_round_win: Input RoundWin ends the round for "TeamNum" (0 for a
stalemate). */
class
tfRoundWin:ncEntity
{
public:
	void tfRoundWin(void);

	virtual void SpawnKey(string, string);
	virtual void Input(entity, string, string);

private:
	float m_winTeam;
};

void
tfRoundWin::tfRoundWin(void)
{
	m_winTeam = TF_TEAM_NONE;
}

void
tfRoundWin::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "TeamNum":
		m_winTeam = TF_TeamFromMapKey(ReadFloat(setValue));
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfRoundWin::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "RoundWin":
		TF_RulesEvent("TF_RoundWin", activatorEnt, ftos(m_winTeam));
		break;
	case "SetTeam":
		m_winTeam = TF_TeamFromMapKey(stof(dataField));
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}

/** game_forcerespawn: ForceRespawn brings every dead player back now,
ForceTeamRespawn <team> only that team's (TF2 numbering). */
class
tfForceRespawn:ncEntity
{
public:
	void tfForceRespawn(void);
	virtual void Input(entity, string, string);
};

void
tfForceRespawn::tfForceRespawn(void)
{
}

void
tfForceRespawn::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "ForceRespawn":
		TF_RulesEvent("TF_ForceRespawn", activatorEnt, "0");
		break;
	case "ForceTeamRespawn":
		TF_RulesEvent("TF_ForceRespawn", activatorEnt, ftos(TF_TeamFromMapKey(stof(dataField))));
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}

/** func_respawnroomvisualizer: the wall across a spawn room's door that
only the other team bumps into. "respawnroomname" names the
func_respawnroom whose team owns the door; with "solid_to_enemies" 1 the
brush is solid to everyone else.

It uses collision dimensions: players carry their team's bit in
dimension_hit (see TF_PlayerThink), the wall is solid only in the
enemies' bit, so projectiles and the owners pass. It isn't sent to clients,
so client prediction lets the owners walk through it. */
class
tfRespawnVisualizer:ncEntity
{
public:
	void tfRespawnVisualizer(void);

	virtual void SpawnKey(string, string);
	virtual void Respawn(void);
	virtual void Input(entity, string, string);
	virtual float SendEntity(entity, float);
	nonvirtual void _Activate(void);

private:
	string m_roomName;
	bool m_solidToEnemies;
	bool m_startDisabled;
};

void
tfRespawnVisualizer::tfRespawnVisualizer(void)
{
	m_roomName = __NULL__;
	m_solidToEnemies = true;
	m_startDisabled = false;
}

void
tfRespawnVisualizer::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "respawnroomname":
		m_roomName = ReadString(setValue);
		break;
	case "solid_to_enemies":
		m_solidToEnemies = ReadBool(setValue);
		break;
	case "StartDisabled":
		m_startDisabled = ReadBool(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfRespawnVisualizer::Respawn(void)
{
	SetModel(GetSpawnString("model"));
	SetOrigin(GetSpawnVector("origin"));
	SetMovetype(MOVETYPE_PUSH);
	SetSolid(SOLID_NOT);
	Hide();
	ScheduleThink(_Activate, 0.1f);
}

void
tfRespawnVisualizer::_Activate(void)
{
	entity roomEnt = find(world, ::targetname, m_roomName);

	team = roomEnt ? roomEnt.team : TF_TEAM_NONE;

	if (m_startDisabled || m_solidToEnemies == false || team == TF_TEAM_NONE) {
		SetSolid(SOLID_NOT);
		return;
	}

	SetSolid(SOLID_BSP);
	dimension_solid = TF_DimensionBlocking(TF_EnemyTeam(team));
}

float
tfRespawnVisualizer::SendEntity(entity toClient, float changedFlags)
{
	return (0);
}

void
tfRespawnVisualizer::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "Enable":
		m_startDisabled = false;
		_Activate();
		break;
	case "Disable":
		SetSolid(SOLID_NOT);
		break;
	case "SetSolid":
		m_solidToEnemies = stof(dataField) ? true : false;
		_Activate();
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}
