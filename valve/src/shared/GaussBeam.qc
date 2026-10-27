#ifdef SERVER
/* Tau cannon shot. A plain shot does 20 damage; a charged one does up to
   200 after a full charge and can punch through thin walls. The beam
   bounces off walls it meets at a glancing angle, losing some of its
   damage, and stops in the first thing it hurts. */
class
hlGaussBeam:ncProjectile
{
	void hlGaussBeam(void);

	virtual void Launch(vector, vector, float, float, float);
	nonvirtual void GaussAttack(float);
	nonvirtual void GaussDamage(entity, float, vector, vector);
	nonvirtual void AddPoint(vector);

	int m_beamPoints;
};

void
hlGaussBeam::hlGaussBeam(void)
{
	m_beamPoints = 0i;
}

void
hlGaussBeam::Launch(vector startPos, vector launchDir, float fuseOffset, float powerMultiplier, float dmgMultiplier)
{
	ncPlayer ourOwner = (ncPlayer)owner;

	m_flDmgMultiplier = (dmgMultiplier > 0.0f) ? dmgMultiplier : 1.0f;
	GaussAttack(fuseOffset);
	FX_GaussBeam(ourOwner.GetEyePos(), ourOwner.GetViewAngle(), m_beamPoints, owner);
	Destroy();
}

void
hlGaussBeam::AddPoint(vector pointPos)
{
	if (m_beamPoints < GAUSSBEAM_MAXPOINTS) {
		g_gaussBeamPoints[m_beamPoints] = pointPos;
		m_beamPoints++;
	}
}

void
hlGaussBeam::GaussDamage(entity targetEnt, float damageAmount, vector damageDir, vector hitPos)
{
	ncSurfacePropEntity target = (ncSurfacePropEntity)targetEnt;
	ncDict damageDecl;

	if (targetEnt.takedamage == DAMAGE_NO || damageAmount < 1.0f) {
		return;
	}

	damageDecl = spawn(ncDict);
	damageDecl.AddKey("damage", itos((int)rint(damageAmount)));
	damageDecl.AddKey("weapon", "weapon_gauss");
	damageDecl.AddKey("location", vtos(hitPos));
	damageDecl.AddKey("push", ftos(damageAmount * 5.0f));
	target.Damage(this, owner, damageDecl, m_flDmgMultiplier, damageDir, hitPos);
	remove(damageDecl);

	sound(targetEnt, CHAN_ITEM, sprintf("weapons/electro%d.wav", random(0,3)+4), 1, ATTN_NORM);
}

void
hlGaussBeam::GaussAttack(float chargeTime)
{
	ncPlayer ourOwner = (ncPlayer)owner;
	vector vecDir = anglesToForward(ourOwner.GetViewAngle());
	vector vecSrc = ourOwner.GetEyePos();
	entity ignoreEnt = ourOwner;
	bool charged = (chargeTime > 0.0f);
	float damage;

	if (charged) {
		damage = lerp(20, 200, bound(0.0f, chargeTime / 4.0f, 1.0f));
	} else {
		damage = 20;
	}

	m_beamPoints = 0i;

	for (int i = 0i; i < GAUSSBEAM_MAXPOINTS && damage >= 10.0f; i++) {
		traceline(vecSrc, vecSrc + (vecDir * 8192), MOVE_NORMAL, ignoreEnt);
		AddPoint(trace_endpos);

		if (trace_fraction >= 1.0f) {
			break;
		}

		if (serverkeyfloat("*bspversion") == BSPVER_HL)
			if (getsurfacetexture(trace_ent, getsurfacenearpoint(trace_ent, trace_endpos)) == "sky") {
				break;
			}

		/* something that can be hurt takes it all */
		if (trace_ent.takedamage != DAMAGE_NO) {
			GaussDamage(trace_ent, damage, vecDir, trace_endpos);
			break;
		}

		vector hitNormal = trace_plane_normal;
		vector hitPos = trace_endpos;
		float facing = -(vecDir * hitNormal);

		/* glancing: bounce, keeping more of the damage the shallower it is */
		if (facing < 0.5f) {
			vecDir = vecDir + (2 * facing) * hitNormal;
			vecSrc = hitPos + (hitNormal * 1);
			damage *= (1.0f - facing);
			ignoreEnt = world;
			continue;
		}

		/* head-on: only a charged beam goes on, through up to `damage`
		   units of wall, and comes out the other side as a blast */
		if (charged == false) {
			break;
		}

		float thickness = 0.0f;
		vector probe = hitPos;
		bool through = false;

		while (thickness < damage) {
			thickness += 8.0f;
			probe = hitPos + (vecDir * thickness);

			if (pointcontents(probe) != CONTENT_SOLID) {
				through = true;
				break;
			}
		}

		if (through == false) {
			break;
		}

		/* back up to where the wall ends */
		traceline(probe, hitPos, MOVE_NOMONSTERS, ignoreEnt);
		damage -= thickness;
		combat.RadiusDamage(trace_endpos, damage, 0i, (int)damage, owner, "");
		AddPoint(trace_endpos);
		vecSrc = trace_endpos + (vecDir * 1);
		ignoreEnt = world;
	}
}
#endif
