/*
 * Copyright (c) 2024 Vera Visions LLC.
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

void
ncSpawnPoint::ncSpawnPoint(void)
{
}

void
ncSpawnPoint::Spawned(void)
{
	super::Spawned();

#ifdef SERVER
	ncHint::PlaceEntityHint(this, "SPAWN");
#endif
}

void
ncSpawnPoint::Respawn(void)
{
	vector newMins, newMaxs;

	newMins = GetSpawnVector("mins");
	newMaxs = GetSpawnVector("maxs");

	if (newMins == g_vec_null) {
		newMins = VEC_HULL_MIN;
		newMaxs = VEC_HULL_MAX;
	}

	SetSolid(SOLID_BBOX);
	SetSize(newMins, newMaxs);

	/* Raw .map loads can embed "// entity N" comments inside the spawn text,
	 * which makes tokenize() return nothing from m_rawSpawnData. Fall back to
	 * the engine-parsed fields (already correct) rather than clobbering them
	 * with (0,0,0). */
	vector spawnOrigin = GetSpawnVector("origin");
	if (spawnOrigin == g_vec_null) {
		spawnOrigin = origin;
	}
	SetOriginUnstick(spawnOrigin);

#ifdef SERVER
	/* RestoreAngles() reads spawn text the same way; keep the engine-parsed
	 * "angle"/"angles" values when the tokenizer returns nothing. */
	vector spawnAngles = GetSpawnVector("angles");
	if (spawnAngles == g_vec_null) {
		spawnAngles = angles;
	}
	SetAngles(spawnAngles);
#endif
	
	SetSolid(SOLID_NOT);
	SetMovetype(MOVETYPE_NONE);
	Disappear();
}
