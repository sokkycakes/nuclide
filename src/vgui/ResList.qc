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

/** Draws a vertical three-piece image (`base_top`, `base_center`,
`base_bottom`, each with `suffix`). Returns false if the top piece is missing. */
bool
VGUI_DrawThreePicV(vector pos, vector size, string base, string suffix, float alpha)
{
	string t = strcat(base, "_top", suffix);
	string c = strcat(base, "_center", suffix);
	string b = strcat(base, "_bottom", suffix);
	vector ts = drawgetimagesize(t);
	vector bs = drawgetimagesize(b);

	if (ts[0] <= 0)
		return (false);

	float th = min(ts[1], size[1] / 2);
	float bh = min(bs[1], size[1] / 2);

	drawpic(pos + [0, th], c, [size[0], size[1] - th - bh], [1,1,1], alpha, 0);
	drawpic(pos, t, [size[0], th], [1,1,1], alpha, 0);
	drawpic(pos + [0, size[1] - bh], b, [size[0], bh], [1,1,1], alpha, 0);
	return (true);
}

/** States a list can show instead of (or over) its rows. */
typedef enum
{
	VGUI_LIST_READY,	/**< rows, or the empty text when there are none */
	VGUI_LIST_LOADING,	/**< the state text, no rows */
	VGUI_LIST_ERROR	/**< the state text in the error colour, no rows */
} vguiResListState_t;

/** @brief A VGUI2-style ListPanel: column headers, rows of text, one selection.

Rows are tab-separated strings, one field per column; a row can carry a
hidden key for the caller. Clicking selects a row, a double click (or
Enter) activates it. The wheel and the scroll bar scroll. While loading or
after an error the list shows a line of text instead of rows; with no rows
it shows the empty text.

The art is named, not built in: a nine-piece background, three-piece
column headers (suffixes "_n", "_o", "_c"), nine-piece selected and hover
highlights, and a vertical three-piece scroll bar thumb.

@ingroup vgui
*/
class vguiResList:vguiWidget
{
public:
	void vguiResList(void);

	nonvirtual void AddColumn(string, float);
	nonvirtual void ClearColumns(void);
	nonvirtual int AddRow(string, string);
	nonvirtual void ClearRows(void);
	nonvirtual int RowCount(void);
	nonvirtual string RowText(int);
	nonvirtual string RowKey(int);
	nonvirtual int GetSelected(void);
	nonvirtual void SetSelected(int);
	nonvirtual void SetState(vguiResListState_t, string);
	nonvirtual vguiResListState_t GetState(void);
	nonvirtual void SetEmptyText(string);
	nonvirtual void SetRowHeight(float);
	nonvirtual void SetArt(string, string, string, string, string);
	nonvirtual void SetColors(vector, vector, vector);
	nonvirtual void CallOnSelect(void(entity, int));
	nonvirtual void CallOnActivate(void(entity, int));

	virtual void Draw(void);
	virtual bool Input(float, float, float, float);

private:
	nonvirtual int _VisibleRows(void);
	nonvirtual int _RowAt(vector);

	float m_rows;
	int m_rowCount;
	string m_colTitles[16];
	float m_colWidths[16];
	int m_colCount;
	int m_selected;
	int m_hover;
	int m_scroll;
	float m_rowHeight;
	float m_lastClick;
	int m_lastClickRow;
	vguiResListState_t m_state;
	string m_stateText;
	string m_emptyText;
	string m_artBg;
	string m_artHeader;
	string m_artSelected;
	string m_artOver;
	string m_artScroll;
	vector m_colText;
	vector m_colHeader;
	vector m_colError;
};

.void(entity, int) tmpvguiResListSelect;
.void(entity, int) tmpvguiResListActivate;

void
vguiResList::vguiResList(void)
{
	m_rows = buf_create();
	m_rowCount = 0i;
	m_colCount = 0i;
	m_selected = -1i;
	m_hover = -1i;
	m_scroll = 0i;
	m_rowHeight = 20;
	m_state = VGUI_LIST_READY;
	m_stateText = "";
	m_emptyText = "";
	m_artBg = m_artHeader = m_artSelected = m_artOver = m_artScroll = "";
	m_colText = [1,1,1];
	m_colHeader = [1,1,1];
	m_colError = [1,0.4,0.4];
}

void
vguiResList::AddColumn(string title, float width)
{
	if (m_colCount >= 16i)
		return;

	m_colTitles[m_colCount] = strzone(title);
	m_colWidths[m_colCount] = width;
	m_colCount++;
}

void
vguiResList::ClearColumns(void)
{
	m_colCount = 0i;
}

/** Adds a row: `text` holds one field per column, separated by tabs;
`key` is kept for the caller (RowKey). Returns the row's index. */
int
vguiResList::AddRow(string text, string key)
{
	bufstr_set(m_rows, m_rowCount * 2i, text);
	bufstr_set(m_rows, m_rowCount * 2i + 1i, key);
	m_rowCount++;
	return m_rowCount - 1i;
}

void
vguiResList::ClearRows(void)
{
	buf_del(m_rows);
	m_rows = buf_create();
	m_rowCount = 0i;
	m_selected = -1i;
	m_hover = -1i;
	m_scroll = 0i;
}

int
vguiResList::RowCount(void)
{
	return m_rowCount;
}

string
vguiResList::RowText(int row)
{
	if (row < 0i || row >= m_rowCount)
		return "";

	return bufstr_get(m_rows, row * 2i);
}

string
vguiResList::RowKey(int row)
{
	if (row < 0i || row >= m_rowCount)
		return "";

	return bufstr_get(m_rows, row * 2i + 1i);
}

int
vguiResList::GetSelected(void)
{
	return m_selected;
}

void
vguiResList::SetSelected(int row)
{
	if (row < -1i || row >= m_rowCount)
		return;

	m_selected = row;

	if (tmpvguiResListSelect)
		tmpvguiResListSelect(this, row);
}

void
vguiResList::SetState(vguiResListState_t state, string text)
{
	m_state = state;
	m_stateText = strzone(text);
}

vguiResListState_t
vguiResList::GetState(void)
{
	return m_state;
}

void
vguiResList::SetEmptyText(string text)
{
	m_emptyText = strzone(text);
}

void
vguiResList::SetRowHeight(float h)
{
	m_rowHeight = max(8, h);
}

/** Art bases: background nine-pic, column header three-pic, selected and
hover nine-pics, scroll bar thumb (vertical three-pic). "" skips one. */
void
vguiResList::SetArt(string bg, string header, string selected, string over, string scroll)
{
	m_artBg = strzone(bg);
	m_artHeader = strzone(header);
	m_artSelected = strzone(selected);
	m_artOver = strzone(over);
	m_artScroll = strzone(scroll);
}

void
vguiResList::SetColors(vector text, vector header, vector error)
{
	m_colText = text;
	m_colHeader = header;
	m_colError = error;
}

void
vguiResList::CallOnSelect(void(entity, int) func)
{
	tmpvguiResListSelect = func;
}

void
vguiResList::CallOnActivate(void(entity, int) func)
{
	tmpvguiResListActivate = func;
}

int
vguiResList::_VisibleRows(void)
{
	float header = (m_colCount > 0i) ? 19 : 0;
	return (int)floor((m_vecSize[1] - header - 4) / m_rowHeight);
}

/* the row under a point, or -1 */
int
vguiResList::_RowAt(vector point)
{
	vector pos = m_parent.m_vecOrigin + m_vecOrigin;
	float header = (m_colCount > 0i) ? 19 : 0;
	float y = point[1] - pos[1] - header - 2;

	if (!Util_MouseAbove(point, pos, m_vecSize - [14, 0]) || y < 0)
		return -1i;

	int row = (int)floor(y / m_rowHeight) + m_scroll;

	if (row >= m_rowCount || row - m_scroll >= _VisibleRows())
		return -1i;

	return row;
}

void
vguiResList::Draw(void)
{
	vector pos = m_parent.m_vecOrigin + m_vecOrigin;
	float header = (m_colCount > 0i) ? 19 : 0;
	float fontH = Font_GetHeight(g_fntDefault);
	int visible = _VisibleRows();

	if (m_artBg != "")
		VGUI_DrawNinePic(pos, m_vecSize, m_artBg, 1.0f);

	/* column headers */
	float x = pos[0];
	for (int c = 0i; c < m_colCount; c++) {
		vector hp = [x, pos[1]];
		vector hs = [m_colWidths[c], header];

		if (m_artHeader != "")
			VGUI_DrawThreePic(hp, hs, m_artHeader, "_n", 1.0f);

		drawsetcliparea(hp[0], hp[1], hs[0], hs[1]);
		Font_DrawText_RGB(hp + [6, (header - fontH) / 2], m_colTitles[c], m_colHeader, g_fntDefault);
		drawresetcliparea();
		x += m_colWidths[c];
	}

	vector body = pos + [0, header + 2];

	if (m_state != VGUI_LIST_READY || m_rowCount == 0i) {
		string msg = (m_state == VGUI_LIST_READY) ? m_emptyText : m_stateText;
		vector col = (m_state == VGUI_LIST_ERROR) ? m_colError : m_colText;
		Font_DrawField(body + [8, 8], [m_vecSize[0] - 16, fontH * 3], msg, g_fntDefault, AF_TOP | AF_LEFT | AF_RIGHT);

		if (m_state == VGUI_LIST_ERROR)
			drawfill(body + [4, 8], [2, fontH], col, 1.0f, 0);
		return;
	}

	drawsetcliparea(pos[0], body[1], m_vecSize[0], m_vecSize[1] - header - 2);

	for (int r = 0i; r < visible && r + m_scroll < m_rowCount; r++) {
		int row = r + m_scroll;
		vector rp = body + [2, r * m_rowHeight];
		vector rs = [m_vecSize[0] - 18, m_rowHeight];

		if (row == m_selected && m_artSelected != "")
			VGUI_DrawNinePic(rp, rs, m_artSelected, 1.0f);
		else if (row == m_hover && m_artOver != "")
			VGUI_DrawNinePic(rp, rs, m_artOver, 1.0f);

		int fields = (int)tokenizebyseparator(RowText(row), "\t");
		x = pos[0];
		for (int f = 0i; f < m_colCount; f++) {
			string cell = (f < fields) ? argv(f) : "";
			drawsetcliparea(x, body[1], m_colWidths[f] - 2, m_vecSize[1] - header - 2);
			Font_DrawText_RGB([x + 6, rp[1] + (m_rowHeight - fontH) / 2], cell, m_colText, g_fntDefault);
			x += m_colWidths[f];
		}
		drawsetcliparea(pos[0], body[1], m_vecSize[0], m_vecSize[1] - header - 2);
	}

	drawresetcliparea();

	/* scroll bar: only when the rows don't fit */
	if (m_rowCount > visible && m_artScroll != "") {
		float trackH = m_vecSize[1] - header - 4;
		float thumbH = max(24, trackH * visible / m_rowCount);
		float thumbY = (trackH - thumbH) * m_scroll / max(1, m_rowCount - visible);
		VGUI_DrawThreePicV(body + [m_vecSize[0] - 13, thumbY], [11, thumbH], m_artScroll, "@n", 1.0f);
	}
}

bool
vguiResList::Input(float evType, float scanCode, float charCode, float devId)
{
	vector pos = m_parent.m_vecOrigin + m_vecOrigin;
	bool over = Util_MouseAbove(g_vecMousePos, pos, m_vecSize);
	int visible = _VisibleRows();
	int maxScroll = (m_rowCount > visible) ? m_rowCount - visible : 0i;

	if (m_state != VGUI_LIST_READY)
		return (over && evType == IE_KEYDOWN && scanCode == K_MOUSE1);

	m_hover = _RowAt(g_vecMousePos);

	if (evType != IE_KEYDOWN)
		return (false);

	switch (scanCode) {
	case K_MWHEELUP:
		if (!over)
			return (false);
		m_scroll = (m_scroll > 3i) ? m_scroll - 3i : 0i;
		return (true);
	case K_MWHEELDOWN:
		if (!over)
			return (false);
		m_scroll = (m_scroll + 3i < maxScroll) ? m_scroll + 3i : maxScroll;
		return (true);
	case K_MOUSE1:
		if (!over)
			return (false);
		if (m_hover >= 0i) {
			bool twice = (m_hover == m_lastClickRow && time - m_lastClick < 0.5f); /* Windows' default double-click time */
			SetSelected(m_hover);
			m_lastClick = time;
			m_lastClickRow = m_hover;

			if (twice && tmpvguiResListActivate)
				tmpvguiResListActivate(this, m_hover);
		}
		return (true);
	case K_ENTER:
		if (m_selected >= 0i && tmpvguiResListActivate) {
			tmpvguiResListActivate(this, m_selected);
			return (true);
		}
		break;
	case K_UPARROW:
		if (m_selected > 0i) {
			SetSelected(m_selected - 1i);
			if (m_selected < m_scroll)
				m_scroll = m_selected;
			return (true);
		}
		break;
	case K_DOWNARROW:
		if (m_selected + 1i < m_rowCount) {
			SetSelected(m_selected + 1i);
			if (m_selected >= m_scroll + visible)
				m_scroll = m_selected - visible + 1i;
			return (true);
		}
		break;
	}

	return (false);
}
