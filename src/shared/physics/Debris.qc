/*
 * Copyright (c) 2023-2024 Vera Visions LLC.
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

#ifdef CLIENT
void
ncDebris::KeepMoving(void)
{
	think = KeepMoving;
	nextthink = time;
}

void
ncDebris::ncDebris(void)
{
	m_decalImpact = __NULL__;
	m_timeUntilNextDecalPlacement = 0.0f;
	touch = _TouchHandler;
	think = KeepMoving;
	nextthink = time;
	dimension_hit = 1;
	dimension_solid = 255;
}

void
ncDebris::Touch(entity touchingEnt)
{
	if (m_timeUntilNextDecalPlacement > time) {
		return;
	}

	if (STRING_SET(m_decalImpact)) {
		DecalGroups_Place(m_decalImpact, origin);
		m_timeUntilNextDecalPlacement = time + 1.0f;
	}
}

/* GoldSrc's SUB_StartFadeOut: solid models turn translucent, then lose
   7 of 255 alpha every 0.1 seconds, about 3.6 seconds in all */
void
ncDebris::StartFadeOut(void)
{
	if (GetRenderMode() == RM_NORMAL || GetRenderAmt() <= 1.0f) {
		if (GetRenderMode() == RM_NORMAL) {
			SetRenderMode(RM_TEXTURE);
		}
		SetRenderAmt(255);
	}

	SetSolid(SOLID_NOT);
	SetAngularVelocity([0,0,0]);
	ScheduleThink(FadeOut, 0.1f);
}

void
ncDebris::FadeOut(void)
{
	if (GetRenderAmt() > 7) {
		SetRenderAmt(GetRenderAmt() - 7);
		ScheduleThink(FadeOut, 0.1f);
	} else {
		SetRenderAmt(0);
		Disappear();
	}
}

void
ncDebris::SetImpactDecal(string impactDecal)
{
	m_decalImpact = impactDecal;
}
#endif
