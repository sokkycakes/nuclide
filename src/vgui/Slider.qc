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

static void
vguiSlider_Trigger(void(void) targetFunc, entity delegateEntity)
{
	entity oldSelf = self;

	self = delegateEntity;
	targetFunc();
	self = oldSelf;
}

class vguiSlider:vguiWidget
{
	void vguiSlider(void);

	nonvirtual void SetMin(int);
	nonvirtual void SetMax(int);
	nonvirtual void SetStep(int);
	nonvirtual int GetValue(void);
	nonvirtual void SetValue(int);
	nonvirtual void CallOnChange(void(void));

	virtual void Spawned(void);
	virtual void Draw(void);
	virtual bool Input(float, float, float, float);

private:
	int m_min;
	int m_max;
	int m_val;
	int m_step;
	int m_hover;
	int m_hold;
	float m_knobW;
	virtual void(void) m_changed = 0;
	entity m_delegateEntity;

	nonvirtual float ValueToRatio(void);
	nonvirtual void ValueFromMouse(void);
};

void
vguiSlider::vguiSlider(void)
{
	m_min = 0;
	m_max = 100;
	m_val = 0;
	m_step = 1;
	m_hover = FALSE;
	m_hold = FALSE;
	m_knobW = 12;
	m_changed = __NULL__;
	m_delegateEntity = __NULL__;
}

void
vguiSlider::Spawned(void)
{
	SetSize([160, 22]);
}

void
vguiSlider::SetMin(int v)
{
	m_min = v;
}

void
vguiSlider::SetMax(int v)
{
	m_max = v;
}

void
vguiSlider::SetStep(int v)
{
	m_step = bound(1, v, 65535);
}

int
vguiSlider::GetValue(void)
{
	return m_val;
}

void
vguiSlider::SetValue(int v)
{
	int sn;
	int span;

	if (v < m_min)
		v = m_min;
	else if (v > m_max)
		v = m_max;

	if (m_step > 1) {
		span = (m_max - m_min);
		if (span < 1)
			span = 1;
		sn = (((v - m_min) + m_step / 2) / m_step);
		sn = sn * m_step + m_min;

		if (sn < m_min)
			sn = m_min;
		if (sn > m_max)
			sn = m_max;
		v = sn;
	}

	if (v == m_val)
		return;

	m_val = v;

	if (m_changed)
		vguiSlider_Trigger(m_changed, m_delegateEntity);
}

float
vguiSlider::ValueToRatio(void)
{
	float span = (float)(m_max - m_min);

	if (span < 1)
		return 0;

	return bound(0.0f, ((float)(m_val - m_min)) / span, 1.0f);
}

void
vguiSlider::ValueFromMouse(void)
{
	float lx;
	float u;
	float sw;
	int span;
	vector tl = m_parent.m_vecOrigin + m_vecOrigin;

	lx = g_vecMousePos[0] - tl[0];
	sw = (float)m_vecSize[0];

	if (sw <= 0)
		return;

	u = lx / sw;
	u = bound(0.0f, u, 1.0f);

	span = m_max - m_min;
	if (span < 1)
		span = 1;

	SetValue(m_min + rint(u * (float)span));
}

void
vguiSlider::CallOnChange(void(void) vFunc)
{
	m_changed = vFunc;
	m_delegateEntity = this;
}

void
vguiSlider::Draw(void)
{
	vguiTheme theme = GetTheme();
	vector tl = m_parent.m_vecOrigin + m_vecOrigin;
	float trackH = 6;
	float ty = tl[1] + (m_vecSize[1] - trackH) * 0.5f;
	float knobW = m_knobW;
	float knobH = m_vecSize[1] - 4;
	float usable;
	vector kpos;

	if (knobH < 10)
		knobH = 10;

	drawfill([tl[0], ty], [m_vecSize[0], trackH], [0.3f, 0.3f, 0.3f], 1.0f);

	usable = (float)m_vecSize[0] - knobW;

	if (usable < 4)
		usable = 4;

	kpos[0] = tl[0] + ValueToRatio() * usable;
	kpos[1] = tl[1] + (m_vecSize[1] - knobH) * 0.5f;
	kpos[2] = 0;

	if (m_hold)
		theme.DrawButton(kpos, [knobW, knobH], VGUI_STATE_ACTIVE);
	else if (m_hover)
		theme.DrawButton(kpos, [knobW, knobH], VGUI_STATE_HOVER);
	else
		theme.DrawButton(kpos, [knobW, knobH], VGUI_STATE_NORMAL);
}

bool
vguiSlider::Input(float type, float x, float y, float devid)
{
	vector tl = m_parent.m_vecOrigin + m_vecOrigin;

	m_hover = FALSE;

	if (Util_MouseAbove(g_vecMousePos, tl, m_vecSize))
		m_hover = TRUE;

	if (type == IE_KEYDOWN && m_hover && x == K_MWHEELDOWN) {
		SetValue(GetValue() - m_step);
		return true;
	}

	if (type == IE_KEYDOWN && m_hover && x == K_MWHEELUP) {
		SetValue(GetValue() + m_step);
		return true;
	}

	if (m_hover && type == IE_KEYDOWN && x == K_MOUSE1) {
		m_hold = TRUE;
		ValueFromMouse();
		g_lastmousepos[0] = g_vecMousePos[0];
		g_lastmousepos[1] = g_vecMousePos[1];
		return true;
	}

	if (type == IE_KEYUP && x == K_MOUSE1)
		m_hold = FALSE;

	if (m_hold &&
	    (g_vecMousePos[0] != g_lastmousepos[0]
	     || g_vecMousePos[1] != g_lastmousepos[1])) {
		ValueFromMouse();
		g_lastmousepos[0] = g_vecMousePos[0];
		g_lastmousepos[1] = g_vecMousePos[1];
		return true;
	}

	return false;
}
