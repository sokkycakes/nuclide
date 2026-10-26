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

/** Draws a three-piece image stretched across a box: `base_left`,
`base_center` and `base_right`, each with `suffix` (such as "@n") appended.
The end pieces keep their own width; the middle one stretches. Returns
false if the left piece doesn't exist. */
bool
VGUI_DrawThreePic(vector pos, vector size, string base, string suffix, float alpha)
{
	string l = strcat(base, "_left", suffix);
	string c = strcat(base, "_center", suffix);
	string r = strcat(base, "_right", suffix);
	vector ls = drawgetimagesize(l);
	vector rs = drawgetimagesize(r);

	if (ls[0] <= 0)
		return (false);

	/* the pieces are drawn at the box's height */
	float lw = ls[0] * (size[1] / max(1, ls[1]));
	float rw = rs[0] * (size[1] / max(1, rs[1]));

	if (lw + rw > size[0]) {
		lw = size[0] / 2;
		rw = size[0] - lw;
	}

	drawpic(pos + [lw, 0], c, [size[0] - lw - rw, size[1]], [1,1,1], alpha, 0);
	drawpic(pos, l, [lw, size[1]], [1,1,1], alpha, 0);
	drawpic(pos + [size[0] - rw, 0], r, [rw, size[1]], [1,1,1], alpha, 0);
	return (true);
}

/** Draws a nine-piece image (`base_top_left` ... `base_bottom_right`)
around and inside a box. The corners keep their size; edges and the centre
stretch. Returns false if the top-left piece doesn't exist. */
bool
VGUI_DrawNinePic(vector pos, vector size, string base, float alpha)
{
	vector tl = drawgetimagesize(strcat(base, "_top_left"));
	vector br = drawgetimagesize(strcat(base, "_bottom_right"));

	if (tl[0] <= 0)
		return (false);

	float left = min(tl[0], size[0] / 2);
	float top = min(tl[1], size[1] / 2);
	float right = min(br[0], size[0] / 2);
	float bottom = min(br[1], size[1] / 2);
	float midW = size[0] - left - right;
	float midH = size[1] - top - bottom;

	drawpic(pos + [left, top], strcat(base, "_center_center"), [midW, midH], [1,1,1], alpha, 0);
	drawpic(pos + [left, 0], strcat(base, "_top_center"), [midW, top], [1,1,1], alpha, 0);
	drawpic(pos + [left, size[1] - bottom], strcat(base, "_bottom_center"), [midW, bottom], [1,1,1], alpha, 0);
	drawpic(pos + [0, top], strcat(base, "_center_left"), [left, midH], [1,1,1], alpha, 0);
	drawpic(pos + [size[0] - right, top], strcat(base, "_center_right"), [right, midH], [1,1,1], alpha, 0);
	drawpic(pos, strcat(base, "_top_left"), [left, top], [1,1,1], alpha, 0);
	drawpic(pos + [size[0] - right, 0], strcat(base, "_top_right"), [right, top], [1,1,1], alpha, 0);
	drawpic(pos + [0, size[1] - bottom], strcat(base, "_bottom_left"), [left, bottom], [1,1,1], alpha, 0);
	drawpic(pos + size - [right, bottom], strcat(base, "_bottom_right"), [right, bottom], [1,1,1], alpha, 0);
	return (true);
}

/** Turns a VGUI2 nine-pic path such as "resource/Control/Selected/Over"
into the base the files use ("resource/control/selected/over"): the last
part of the path is the file prefix inside that folder. */
string
VGUI_NinePicBase(string path)
{
	return strtolower(path);
}

/** @brief An ImagePanel from a .res layout.

Reads `image` (drawn at its own size unless `scaleImage` is 1),
`fillcolor` ("r g b a", 0-255, drawn under the image), `ThreePicsTgaPath`
and `NinePicsTgaPath`. A panel with `command` reports clicks like a
vguiResButton does through g_vguiResImageCommand.

@ingroup vgui
*/
class vguiResImage:vguiWidget
{
public:
	void vguiResImage(void);

	nonvirtual void SetImage(string);
	nonvirtual string GetImage(void);
	nonvirtual void SetScaleImage(bool);
	nonvirtual void SetFillColor(vector, float);
	nonvirtual void SetThreePic(string);
	nonvirtual void SetNinePic(string);
	nonvirtual void SetCommand(string);

	virtual void Draw(void);
	virtual bool Input(float, float, float, float);

	string m_resImage;
	string m_resThree;
	string m_resNine;
	string m_resImageCommand;
	bool m_resScale;
	vector m_resFill;
	float m_resFillAlpha;
	bool m_resHover;
};

/** Called when an image panel with a "command" is clicked. */
var void(vguiWidget, string) g_vguiResImageCommand;

void
vguiResImage::vguiResImage(void)
{
	m_resImage = "";
	m_resThree = "";
	m_resNine = "";
	m_resImageCommand = "";
	m_resScale = false;
	m_resFillAlpha = 0.0f;
}

void
vguiResImage::SetImage(string img)
{
	m_resImage = strzone(img);
}

string
vguiResImage::GetImage(void)
{
	return m_resImage;
}

void
vguiResImage::SetScaleImage(bool val)
{
	m_resScale = val;
}

void
vguiResImage::SetFillColor(vector rgb, float alpha)
{
	m_resFill = rgb;
	m_resFillAlpha = alpha;
}

void
vguiResImage::SetThreePic(string base)
{
	m_resThree = strzone(base);
}

void
vguiResImage::SetNinePic(string base)
{
	m_resNine = strzone(VGUI_NinePicBase(base));
}

void
vguiResImage::SetCommand(string cmd)
{
	m_resImageCommand = strzone(cmd);
}

void
vguiResImage::Draw(void)
{
	vector pos = m_parent.m_vecOrigin + m_vecOrigin;

	if (m_resFillAlpha > 0.0f)
		drawfill(pos, m_vecSize, m_resFill, m_resFillAlpha, 0);

	if (m_resNine != "")
		VGUI_DrawNinePic(pos, m_vecSize, m_resNine, 1.0f);

	if (m_resThree != "")
		VGUI_DrawThreePic(pos, m_vecSize, m_resThree, m_resHover ? "@o" : "@n", 1.0f);

	if (m_resImage != "") {
		if (m_resScale) {
			drawpic(pos, m_resImage, m_vecSize, [1,1,1], 1.0f, 0);
		} else {
			vector sz = drawgetimagesize(m_resImage);

			if (sz[0] > 0)
				drawpic(pos, m_resImage, sz, [1,1,1], 1.0f, 0);
		}
	}
}

bool
vguiResImage::Input(float evType, float scanCode, float charCode, float devId)
{
	if (m_resImageCommand == "")
		return (false);

	m_resHover = Util_MouseAbove(g_vecMousePos, m_parent.m_vecOrigin + m_vecOrigin, m_vecSize);

	if (evType == IE_KEYUP && scanCode == K_MOUSE1 && m_resHover) {
		if (g_vguiResImageCommand)
			g_vguiResImageCommand(this, m_resImageCommand);
		return (true);
	}

	return (false);
}

/** Parses a .res colour "r g b a" (0-255). The alpha goes to the second argument. */
vector
VGUI_ResColor(string val, __out float alpha)
{
	int n = tokenize(val);

	if (n < 3) {
		alpha = 0.0f;
		return [0,0,0];
	}

	alpha = (n >= 4) ? stof(argv(3)) / 255 : 1.0f;
	return [stof(argv(0)), stof(argv(1)), stof(argv(2))] / 255;
}
