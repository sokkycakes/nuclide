/*
 * Copyright (c) 2016-2022 Vera Visions LLC.
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

/* Screen shake as GoldSrc does it (Xash3D's pfnCalcShake was the
   behaviour reference): every so often the camera gets a new random
   offset of up to the amplitude on each axis, plus a roll of up to a
   quarter of it. Both swing on a sine wave that dies out over the
   duration, and the amplitude itself decays while the shake runs.

   The view origin and roll move; the view angles the player aims with
   don't, so a shake never pushes the crosshair around. */

/* a new shake. A weaker one doesn't cut a stronger one short. */
void
Shake_Start(float amplitude, float frequency, float duration)
{
	if (amplitude > pSeat->m_flShakeAmp) {
		pSeat->m_flShakeAmp = amplitude;
	}

	pSeat->m_flShakeDuration = duration;
	pSeat->m_flShakeTime = time + duration;
	pSeat->m_flShakeFreq = frequency;
	pSeat->m_flShakeNext = 0.0f;
}

void
Shake_Stop(void)
{
	pSeat->m_flShakeAmp = 0.0f;
	pSeat->m_flShakeDuration = 0.0f;
	pSeat->m_flShakeTime = 0.0f;
	pSeat->m_flShakeFreq = 0.0f;
	pSeat->m_flShakeNext = 0.0f;
	pSeat->m_vecShakeOffset = g_vec_null;
	pSeat->m_flShakeAngle = 0.0f;
}

void
Shake_Update(ncPlayer pl)
{
	float fraction;
	float freq;
	vector camAngle;

	if (time > pSeat->m_flShakeTime || pSeat->m_flShakeAmp <= 0.0f || pSeat->m_flShakeFreq <= 0.0f || pSeat->m_flShakeDuration <= 0.0f) {
		return;
	}

	/* pick a new direction to shake in */
	if (time > pSeat->m_flShakeNext) {
		float amp = pSeat->m_flShakeAmp;
		pSeat->m_flShakeNext = time + (pSeat->m_flShakeFreq / pSeat->m_flShakeDuration);
		pSeat->m_vecShakeOffset[0] = random(-amp, amp);
		pSeat->m_vecShakeOffset[1] = random(-amp, amp);
		pSeat->m_vecShakeOffset[2] = random(-amp, amp);
		pSeat->m_flShakeAngle = random(-amp * 0.25f, amp * 0.25f);
	}

	/* goes from -1 to 0 over the duration; squared, it falls off fast */
	fraction = (time - pSeat->m_flShakeTime) / pSeat->m_flShakeDuration;
	freq = (fraction != 0.0f) ? (pSeat->m_flShakeFreq / fraction) * pSeat->m_flShakeFreq : 0.0f;
	fraction *= fraction * sin(time * freq);

	g_view.SetCameraOrigin(g_view.GetCameraOrigin() + (pSeat->m_vecShakeOffset * fraction));
	camAngle = g_view.GetCameraAngle();
	camAngle[2] += pSeat->m_flShakeAngle * fraction;
	g_view.SetCameraAngle(camAngle);

	/* decays slower on long or high frequency shakes */
	pSeat->m_flShakeAmp -= pSeat->m_flShakeAmp * (clframetime / (pSeat->m_flShakeFreq * pSeat->m_flShakeDuration));
}
