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

#define COMBOBOX_ROW 20

.void(entity) tmpvguiComboChange;

/** VGUI Widget: ComboBox

Shows the selected item. A click opens a list of all items below it, and
a click on an item selects it. Each item has a display text and a value.

@ingroup vgui
*/
class vguiComboBox:vguiWidget
{
public:
	void vguiComboBox(void);

	/** Adds an item with a display text and a value. */
	nonvirtual void AddItem(string, string);
	nonvirtual void Clear(void);
	nonvirtual int GetItemCount(void);
	nonvirtual int GetSelected(void);
	nonvirtual void SetSelected(int);
	/** Selects the first item with this value. Returns false if there is none. */
	nonvirtual bool SelectValue(string);
	nonvirtual string GetText(void);
	nonvirtual string GetValue(void);
	/** Called with the combo box (as an entity) after the user picks an item. */
	nonvirtual void CallOnChange(void(entity));

	virtual void Draw(void);
	virtual bool Input(float, float, float, float);

private:
	hashtable m_items;
	int m_count;
	int m_selected;
	bool m_open;
};

void
vguiComboBox::vguiComboBox(void)
{
	m_items = 0;
	m_count = 0i;
	m_selected = -1i;
	m_open = false;
}

void
vguiComboBox::AddItem(string text, string value)
{
	if (!m_items)
		m_items = hash_createtab(32, EV_STRING);

	hash_add(m_items, strcat("t", sprintf("%i", m_count)), strzone(text), HASH_REPLACE | EV_STRING);
	hash_add(m_items, strcat("v", sprintf("%i", m_count)), strzone(value), HASH_REPLACE | EV_STRING);
	m_count++;

	if (m_selected < 0i)
		m_selected = 0i;
}

void
vguiComboBox::Clear(void)
{
	m_count = 0i;
	m_selected = -1i;
	m_open = false;
}

int
vguiComboBox::GetItemCount(void)
{
	return m_count;
}

int
vguiComboBox::GetSelected(void)
{
	return m_selected;
}

void
vguiComboBox::SetSelected(int idx)
{
	if (idx >= 0i && idx < m_count)
		m_selected = idx;
}

bool
vguiComboBox::SelectValue(string value)
{
	for (int i = 0i; i < m_count; i++) {
		if (hash_get(m_items, strcat("v", sprintf("%i", i)), "", EV_STRING) == value) {
			m_selected = i;
			return (true);
		}
	}

	return (false);
}

string
vguiComboBox::GetText(void)
{
	if (m_selected < 0i)
		return "";

	return hash_get(m_items, strcat("t", sprintf("%i", m_selected)), "", EV_STRING);
}

string
vguiComboBox::GetValue(void)
{
	if (m_selected < 0i)
		return "";

	return hash_get(m_items, strcat("v", sprintf("%i", m_selected)), "", EV_STRING);
}

void
vguiComboBox::CallOnChange(void(entity) func)
{
	tmpvguiComboChange = func;
}

void
vguiComboBox::Draw(void)
{
	vguiTheme theme = GetTheme();
	vector pos = m_parent.m_vecOrigin + m_vecOrigin;
	vector arrowPos = pos + [m_vecSize[0] - m_vecSize[1], 0];

	theme.DrawTextBackground(pos, m_vecSize, VGUI_STATE_NORMAL);
	theme.DrawBorder(pos, m_vecSize, VGUI_BORDER_INSET, __NULL__);
	theme.DrawButton(arrowPos, [m_vecSize[1], m_vecSize[1]], m_open ? VGUI_STATE_ACTIVE : VGUI_STATE_NORMAL);
	theme.DrawText(arrowPos + [m_vecSize[1] / 2 - 4, m_vecSize[1] / 2 - 6], "v", [m_vecSize[1], m_vecSize[1]], g_fntDefault);

	drawsetcliparea(pos[0], pos[1], m_vecSize[0] - m_vecSize[1], m_vecSize[1]);
	theme.DrawText(pos + [6, m_vecSize[1] / 2 - 6], GetText(), m_vecSize, g_fntDefault);
	drawresetcliparea();

	if (!m_open)
		return;

	/* the list, under the box */
	vector listPos = pos + [0, m_vecSize[1]];
	vector listSize = [m_vecSize[0], m_count * COMBOBOX_ROW];
	/* opaque, so the controls under the list don't show through */
	drawfill(listPos, listSize, UI_MAINCOLOR, 1.0f);
	theme.DrawWindowBackground(listPos, listSize, VGUI_STATE_NORMAL);
	theme.DrawBorder(listPos, listSize, VGUI_BORDER_OUTSET, __NULL__);

	for (int i = 0i; i < m_count; i++) {
		vector rowPos = listPos + [0, i * COMBOBOX_ROW];
		vector rowSize = [m_vecSize[0], COMBOBOX_ROW];

		if (Util_MouseAbove(g_vecMousePos, rowPos, rowSize) || i == m_selected)
			drawfill(rowPos, rowSize, UI_HICOLOR, (i == m_selected) ? 0.25f : 0.125f);

		theme.DrawText(rowPos + [6, COMBOBOX_ROW / 2 - 6], hash_get(m_items, strcat("t", sprintf("%i", i)), "", EV_STRING), rowSize, g_fntDefault);
	}
}

bool
vguiComboBox::Input(float flEVType, float flKey, float flChar, float flDevID)
{
	vector pos = m_parent.m_vecOrigin + m_vecOrigin;

	if (IsEnabled() == false)
		return (false);

	if (flEVType != IE_KEYDOWN || flKey != K_MOUSE1)
		return (m_open && flEVType == IE_KEYUP && flKey == K_MOUSE1);

	if (m_open) {
		vector listPos = pos + [0, m_vecSize[1]];

		m_open = false;

		for (int i = 0i; i < m_count; i++) {
			if (Util_MouseAbove(g_vecMousePos, listPos + [0, i * COMBOBOX_ROW], [m_vecSize[0], COMBOBOX_ROW])) {
				m_selected = i;

				if (tmpvguiComboChange)
					tmpvguiComboChange(this);
				break;
			}
		}

		/* a click anywhere closes the list and goes no further */
		return (true);
	}

	if (Util_MouseAbove(g_vecMousePos, pos, m_vecSize)) {
		m_open = true;
		return (true);
	}

	return (false);
}
