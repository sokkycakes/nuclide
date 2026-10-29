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

/** @brief A vguiTheme that draws with a VGUI scheme file (e.g. resource/clientscheme.res).

Colours come from the scheme's BaseSettings, which name entries in Colors
(followed up to 8 steps). Images come from these BaseSettings blocks, the
way the scheme names them:

- `Frame`: TopLeft, TopCenter, TopRight, MiddleLeft, MiddleCenter,
  MiddleRight, BottomLeft, BottomCenter, BottomRight (nine-slice window)
- `Button`: LeftN/CenterN/RightN, ...O (pointer over), ...C (pressed)
- `TextEntry`: the same nine names as Frame
- `Menu`: the same nine names, for drop-down lists

Image paths are used in lower case, without an extension, through drawpic.
A missing block falls back to the plain vguiTheme drawing.

Images some games draw from code rather than the scheme (check boxes, the
combo box arrow) are set with SetCheckboxImages() and SetComboArrowImage().

@ingroup vgui
*/
class vguiSchemeTheme:vguiTheme
{
public:
	void vguiSchemeTheme(void);

	/** Reads a scheme file. Returns false if it can't be opened. */
	nonvirtual bool LoadScheme(string);
	/** A colour from BaseSettings or Colors as RGB 0-1; the alpha goes to the second argument. */
	nonvirtual vector SchemeColor(string, __out float);
	/** An image path from a BaseSettings block, lower case, or "". */
	nonvirtual string SchemeImage(string);
	nonvirtual void SetCheckboxImages(string, string);
	nonvirtual void SetComboArrowImage(string);

	virtual void DrawWindow(vector, vector, VGUIDrawState_t);
	virtual void DrawWindowBackground(vector, vector, VGUIDrawState_t);
	virtual void DrawWindowTitle(vector, vector, string, string, font_s, VGUIDrawState_t);
	virtual void DrawButton(vector, vector, VGUIDrawState_t);
	virtual void DrawButtonTitle(vector, vector, string, font_s, VGUIDrawState_t);
	virtual void DrawText(vector, string, vector, font_s);
	virtual void DrawTextEntry(vector, vector, VGUIDrawState_t);
	virtual void DrawTextEntryText(vector, string, vector, font_s);
	virtual void DrawCheckbox(vector, vector, bool, VGUIDrawState_t);
	virtual void DrawComboBox(vector, vector, VGUIDrawState_t);
	virtual void DrawMenuBackground(vector, vector);
	virtual void DrawMenuItem(vector, vector, string, font_s, bool, bool);

	nonvirtual bool _DrawNine(string, vector, vector, float);
	nonvirtual vector _Color(string, string, __out float);

private:
	vguiKeyValues m_scheme;
	string m_checkOff;
	string m_checkOn;
	string m_comboArrow;
};

void
vguiSchemeTheme::vguiSchemeTheme(void)
{
	m_scheme = __NULL__;
	m_checkOff = "";
	m_checkOn = "";
	m_comboArrow = "";
}

bool
vguiSchemeTheme::LoadScheme(string fileName)
{
	m_scheme = spawn(vguiKeyValues);
	return m_scheme.LoadFile(fileName);
}

void
vguiSchemeTheme::SetCheckboxImages(string off, string on)
{
	m_checkOff = strzone(strtolower(off));
	m_checkOn = strzone(strtolower(on));
}

void
vguiSchemeTheme::SetComboArrowImage(string pic)
{
	m_comboArrow = strzone(strtolower(pic));
}

vector
vguiSchemeTheme::SchemeColor(string name, __out float alpha)
{
	string val = name;
	string next;
	alpha = 1.0f;

	if (!m_scheme)
		return [1,1,1];

	/* a setting names a colour, which may name another setting, and so on */
	for (int hops = 0i; hops < 8i; hops++) {
		string first = substring(val, 0, 1);

		/* a literal colour starts with a digit */
		if (first != "" && strstrofs("0123456789", first) >= 0 && tokenize(val) >= 3) {
			vector rgb = [stof(argv(0)), stof(argv(1)), stof(argv(2))] / 255;

			if (tokenize(val) >= 4)
				alpha = bound(0, stof(argv(3)), 255) / 255;

			return rgb;
		}

		next = m_scheme.GetString(strcat("Scheme/BaseSettings/", val));

		if (next == "")
			next = m_scheme.GetString(strcat("Scheme/Colors/", val));
		if (next == "")
			break;

		val = next;
	}

	return [1,1,1];
}

/* a colour from a block's setting, else the general one */
vector
vguiSchemeTheme::_Color(string block, string key, __out float alpha)
{
	if (block != "" && m_scheme.GetString(strcat("Scheme/BaseSettings/", block, "/", key)) != "")
		return SchemeColor(strcat(block, "/", key), alpha);

	return SchemeColor(key, alpha);
}

string
vguiSchemeTheme::SchemeImage(string path)
{
	if (!m_scheme)
		return "";

	return strtolower(m_scheme.GetString(strcat("Scheme/BaseSettings/", path)));
}

/* nine-slice: the corners keep their size, edges and middle stretch */
bool
vguiSchemeTheme::_DrawNine(string block, vector pos, vector size, float alpha)
{
	string tl = SchemeImage(strcat(block, "/TopLeft"));

	if (tl == "")
		return (false);

	string tc = SchemeImage(strcat(block, "/TopCenter"));
	string tr = SchemeImage(strcat(block, "/TopRight"));
	string ml = SchemeImage(strcat(block, "/MiddleLeft"));
	string mc = SchemeImage(strcat(block, "/MiddleCenter"));
	string mr = SchemeImage(strcat(block, "/MiddleRight"));
	string bl = SchemeImage(strcat(block, "/BottomLeft"));
	string bc = SchemeImage(strcat(block, "/BottomCenter"));
	string br = SchemeImage(strcat(block, "/BottomRight"));

	vector tlSize = drawgetimagesize(tl);
	vector brSize = drawgetimagesize(br);
	float left = tlSize[0];
	float top = tlSize[1];
	float right = brSize[0];
	float bottom = brSize[1];
	float midW = size[0] - left - right;
	float midH = size[1] - top - bottom;

	if (midW < 0)
		midW = 0;
	if (midH < 0)
		midH = 0;

	drawpic(pos + [left, top], mc, [midW, midH], [1,1,1], alpha, 0);
	drawpic(pos + [left, 0], tc, [midW, top], [1,1,1], alpha, 0);
	drawpic(pos + [left, size[1] - bottom], bc, [midW, bottom], [1,1,1], alpha, 0);
	drawpic(pos + [0, top], ml, [left, midH], [1,1,1], alpha, 0);
	drawpic(pos + [size[0] - right, top], mr, [right, midH], [1,1,1], alpha, 0);
	drawpic(pos, tl, [left, top], [1,1,1], alpha, 0);
	drawpic(pos + [size[0] - right, 0], tr, [right, top], [1,1,1], alpha, 0);
	drawpic(pos + [0, size[1] - bottom], bl, [left, bottom], [1,1,1], alpha, 0);
	drawpic(pos + size - [right, bottom], br, [right, bottom], [1,1,1], alpha, 0);
	return (true);
}

void
vguiSchemeTheme::DrawWindow(vector atPos, vector withSize, VGUIDrawState_t drawStyle)
{
	if (!_DrawNine("Frame", atPos, withSize, 1.0f))
		super::DrawWindow(atPos, withSize, drawStyle);
}

void
vguiSchemeTheme::DrawWindowBackground(vector atPos, vector withSize, VGUIDrawState_t drawStyle)
{
	float a;
	vector rgb = SchemeColor("WindowBgColor", a);
	drawfill(atPos, withSize, rgb, a);
}

void
vguiSchemeTheme::DrawWindowTitle(vector atPos, vector withSize, string titleText, string withIcon, font_s textFont, VGUIDrawState_t drawStyle)
{
	float a;
	vector rgb = SchemeColor("TitleBarFgColor", a);

	if (STRING_SET(titleText))
		Font_DrawText_RGBA(atPos + [10, 6], titleText, rgb, a, textFont);
}

void
vguiSchemeTheme::DrawButton(vector atPos, vector withSize, VGUIDrawState_t drawStyle)
{
	string s = "N";
	float alpha = 1.0f;

	if (drawStyle == VGUI_STATE_HOVER)
		s = "O";
	else if (drawStyle == VGUI_STATE_ACTIVE)
		s = "C";
	else if (drawStyle == VGUI_STATE_DISABLED)
		alpha = 0.5f;

	string l = SchemeImage(strcat("Button/Left", s));
	string c = SchemeImage(strcat("Button/Center", s));
	string r = SchemeImage(strcat("Button/Right", s));

	if (l == "") {
		super::DrawButton(atPos, withSize, drawStyle);
		return;
	}

	/* three-slice: the ends keep their width, everything is stretched to the height */
	float lw = drawgetimagesize(l)[0];
	float rw = drawgetimagesize(r)[0];
	drawpic(atPos + [lw, 0], c, [withSize[0] - lw - rw, withSize[1]], [1,1,1], alpha, 0);
	drawpic(atPos, l, [lw, withSize[1]], [1,1,1], alpha, 0);
	drawpic(atPos + [withSize[0] - rw, 0], r, [rw, withSize[1]], [1,1,1], alpha, 0);
}

void
vguiSchemeTheme::DrawButtonTitle(vector atPos, vector withSize, string titleText, font_s textFont, VGUIDrawState_t drawStyle)
{
	float a;
	vector rgb = SchemeColor("FgColor", a);

	if (drawStyle == VGUI_STATE_DISABLED)
		rgb = SchemeColor("DisabledFgColor1", a);

	/* centred, the VGUI button default */
	float w = Font_StringWidth(titleText, TRUE, textFont);
	vector p = atPos + [(withSize[0] - w) / 2, (withSize[1] - textFont.iScaleY) / 2];
	Font_DrawText_RGBA(p, titleText, rgb, a, textFont);
}

void
vguiSchemeTheme::DrawText(vector atPos, string withText, vector boundSize, font_s textFont)
{
	float a;
	vector rgb = SchemeColor("FgColor", a);
	Font_DrawText_RGBA(atPos, withText, rgb, a, textFont);
}

void
vguiSchemeTheme::DrawTextEntry(vector atPos, vector withSize, VGUIDrawState_t drawStyle)
{
	if (!_DrawNine("TextEntry", atPos, withSize, 1.0f))
		super::DrawTextEntry(atPos, withSize, drawStyle);
}

void
vguiSchemeTheme::DrawTextEntryText(vector atPos, string withText, vector boundSize, font_s textFont)
{
	float a;
	vector rgb = SchemeColor("TextEntryFgColor", a);
	Font_DrawText_RGBA(atPos, withText, rgb, a, textFont);
}

void
vguiSchemeTheme::DrawCheckbox(vector atPos, vector withSize, bool checked, VGUIDrawState_t drawStyle)
{
	string pic = checked ? m_checkOn : m_checkOff;

	if (pic == "") {
		super::DrawCheckbox(atPos, withSize, checked, drawStyle);
		return;
	}

	vector picSize = drawgetimagesize(pic);
	drawpic(atPos + [0, (withSize[1] - picSize[1]) / 2], pic, picSize, [1,1,1], 1.0f, 0);
}

void
vguiSchemeTheme::DrawComboBox(vector atPos, vector withSize, VGUIDrawState_t drawStyle)
{
	if (!_DrawNine("TextEntry", atPos, withSize, 1.0f)) {
		super::DrawComboBox(atPos, withSize, drawStyle);
		return;
	}

	if (m_comboArrow != "") {
		vector arrowSize = drawgetimagesize(m_comboArrow);
		vector arrowPos = atPos + [withSize[0] - withSize[1] / 2 - arrowSize[0] / 2 - 2, (withSize[1] - arrowSize[1]) / 2];
		drawpic(arrowPos, m_comboArrow, arrowSize, [1,1,1], 1.0f, 0);
	}
}

void
vguiSchemeTheme::DrawMenuBackground(vector atPos, vector withSize)
{
	if (!_DrawNine("Menu", atPos, withSize, 1.0f))
		super::DrawMenuBackground(atPos, withSize);
}

void
vguiSchemeTheme::DrawMenuItem(vector atPos, vector withSize, string itemText, font_s textFont, bool armed, bool selected)
{
	float a;
	vector rgb;

	if (armed) {
		rgb = _Color("Menu", "ArmedBgColor", a);
		drawfill(atPos + [2, 0], withSize - [4, 0], rgb, a);
		rgb = _Color("Menu", "ArmedFgColor", a);
	} else {
		rgb = _Color("Menu", "FgColor", a);
	}

	vector inset = [stof(m_scheme.GetString("Scheme/BaseSettings/Menu/TextInset")), 0];
	Font_DrawText_RGBA(atPos + inset + [0, (withSize[1] - textFont.iScaleY) / 2], itemText, rgb, a, textFont);
}
