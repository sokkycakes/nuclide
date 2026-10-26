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

/** @file tf_props.qc
Props whose model isn't installed. Team Fortress 2 maps are full of props
from TF2's own content; without it Nuclide would draw its error model for
each one. These stay out of sight and out of the way instead. Their
collision doesn't go missing: an engine that loads Source maps (Bulwark)
builds it into the map from the prop's .phy file or the prop clip table
(scripts/propclip.txt). Props whose model is there behave as usual.
*/

bool
TF_PropModelMissing(string modelName)
{
	if (!STRING_SET(modelName) || substring(modelName, 0, 1) == "*") {
		return (false);
	}

	return (whichpack(modelName) == __NULL__) ? (true) : (false);
}

class
tfPropDynamic:prop_dynamic
{
public:
	void tfPropDynamic(void);
	virtual void Respawn(void);
};

void
tfPropDynamic::tfPropDynamic(void)
{
}

void
tfPropDynamic::Respawn(void)
{
	super::Respawn();

	if (TF_PropModelMissing(GetSpawnString("model"))) {
		SetSolid(SOLID_NOT);
		SetMovetype(MOVETYPE_NONE);
		Hide();
	}
}

class
tfPropPhysics:prop_physics
{
public:
	void tfPropPhysics(void);
	virtual void Respawn(void);
};

void
tfPropPhysics::tfPropPhysics(void)
{
}

void
tfPropPhysics::Respawn(void)
{
	super::Respawn();

	if (TF_PropModelMissing(GetSpawnString("model"))) {
		SetSolid(SOLID_NOT);
		SetMovetype(MOVETYPE_NONE);
		Hide();
	}
}
