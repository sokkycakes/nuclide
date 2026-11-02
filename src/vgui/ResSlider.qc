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

/** @brief A horizontal slider for a value in a range, like VGUI2's Slider
(and CCvarSlider, minus the cvar: the caller reads and writes the value).
Dragging or clicking the track moves it; the wheel steps it.

@ingroup vgui
*/
class vguiResSlider:vguiWidget
{
public:
	void vguiResSlider(void);

	nonvirtual void SetRange(float, float, float);
	nonvirtual void SetValue(float);
	nonvirtual float GetValue(void);
	nonvirtual void CallOnChange(void(entity));

	virtual void Draw(void);
	virtual bool Input(float, float, float, float);

private:
	nonvirtual void _SetFromMouse(void);

	float m_min;
	float m_max;
	float m_step;
	float m_value;
	bool m_dragging;
};

.void(entity) tmpvguiResSliderChange;

void
vguiResSlider::vguiResSlider(void)
{
	m_min = 0;
	m_max = 1;
	m_step = 0;
	m_value = 0;
}

/** step 0 means any value */
void
vguiResSlider::SetRange(float lo, float hi, float step)
{
	m_min = lo;
	m_max = max(hi, lo + 0.0001f);
	m_step = step;
	SetValue(m_value);
}

void
vguiResSlider::SetValue(float val)
{
	val = bound(m_min, val, m_max);

	if (m_step > 0)
		val = m_min + rint((val - m_min) / m_step) * m_step;

	m_value = val;
}

float
vguiResSlider::GetValue(void)
{
	return m_value;
}

void
vguiResSlider::CallOnChange(void(entity) func)
{
	tmpvguiResSliderChange = func;
}

void
vguiResSlider::_SetFromMouse(void)
{
	vector pos = m_parent.m_vecOrigin + m_vecOrigin;
	float frac = bound(0, (g_vecMousePos[0] - pos[0] - 4) / max(1, m_vecSize[0] - 8), 1);
	float old = m_value;

	SetValue(m_min + frac * (m_max - m_min));

	if (m_value != old && tmpvguiResSliderChange)
		tmpvguiResSliderChange(this);
}

void
vguiResSlider::Draw(void)
{
	vguiTheme theme = GetTheme();
	vector pos = m_parent.m_vecOrigin + m_vecOrigin;
	float frac = (m_value - m_min) / (m_max - m_min);
	float trackY = pos[1] + m_vecSize[1] / 2 - 2;
	float alpha = IsEnabled() ? 1.0f : 0.4f;

	drawfill([pos[0] + 4, trackY], [m_vecSize[0] - 8, 4], [0.1,0.1,0.1], alpha, 0);
	drawfill([pos[0] + 4, trackY], [(m_vecSize[0] - 8) * frac, 4], [0.85,0.6,0.2], alpha, 0);
	theme.DrawButton([pos[0] + (m_vecSize[0] - 8) * frac, pos[1] + m_vecSize[1] / 2 - 8], [8, 16],
		m_dragging ? VGUI_STATE_ACTIVE : VGUI_STATE_NORMAL);
}

bool
vguiResSlider::Input(float evType, float scanCode, float charCode, float devId)
{
	vector pos = m_parent.m_vecOrigin + m_vecOrigin;
	bool over = Util_MouseAbove(g_vecMousePos, pos, m_vecSize);

	if (!IsEnabled())
		return (false);

	if (evType == IE_KEYDOWN && scanCode == K_MOUSE1 && over) {
		m_dragging = true;
		_SetFromMouse();
		return (true);
	}

	if (evType == IE_KEYUP && scanCode == K_MOUSE1 && m_dragging) {
		m_dragging = false;
		return (true);
	}

	if (evType == IE_MOUSEABS && m_dragging) {
		_SetFromMouse();
		return (true);
	}

	if (evType == IE_KEYDOWN && over && (scanCode == K_MWHEELUP || scanCode == K_MWHEELDOWN)) {
		float step = (m_step > 0) ? m_step : (m_max - m_min) / 20;
		SetValue(m_value + ((scanCode == K_MWHEELUP) ? step : -step));
		if (tmpvguiResSliderChange)
			tmpvguiResSliderChange(this);
		return (true);
	}

	return (false);
}
