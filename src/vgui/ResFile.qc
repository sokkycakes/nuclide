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

/** @brief Reads Valve-style KeyValues text: VGUI .res layouts, schemes and
localization files.

The rules follow Bulwark's docs/spec/vgui-res.md:

- `//` starts a comment, also right after a value.
- Backslashes are ordinary characters; there are no escapes.
- A quote left open at the end of a line ends there, unless SetSpanLines()
  is on (localization files have strings that run over several lines).
- A key with no value is dropped. A `{` with no key gets the key "".
- Stray `}` are ignored and blocks left open at the end are closed.
- Lookups ignore case, and the first of two equal keys wins.

Each repair is counted, see RepairCount().

Values live in one hash table under their lower-case path, such as
`createroompopup/xpos`. When a block repeats a key that is already a block
in the same parent, the copy gets the path `key#2`, `key#3` and so on, so
two panels with the same name stay apart.

@ingroup vgui
*/
class vguiKeyValues
{
public:
	void vguiKeyValues(void);

	/** Parses a file from the game's search path. Returns false if it can't be opened. */
	nonvirtual bool LoadFile(string);
	/** Value at a path such as "Panel/xpos", or "" if absent. */
	nonvirtual string GetString(string);
	nonvirtual float GetFloat(string);
	/** True when the path exists, as a value or a block. */
	nonvirtual bool Exists(string);
	/** True when the path is a block. "" is the root. */
	nonvirtual bool IsBlock(string);
	/** Number of entries directly in a block. */
	nonvirtual int ChildCount(string);
	/** Key of an entry in a block, in its original case. */
	nonvirtual string ChildKey(string, int);
	/** Path of an entry in a block, to pass to the other getters. */
	nonvirtual string ChildPath(string, int);
	/** Number of repairs made while reading, 0 for a clean file. */
	nonvirtual int RepairCount(void);
	/** Let quoted strings run over line ends, as localization files need.
	By default a quote left open ends with its line, which suits .res files. */
	nonvirtual void SetSpanLines(bool);

	nonvirtual void _Token(string);
	nonvirtual void _Open(void);
	nonvirtual void _Close(void);
	nonvirtual void _AddChild(string, string, bool);

private:
	hashtable m_tab;
	string m_path;
	int m_depth;
	string m_key;
	bool m_haveKey;
	int m_repairs;
	bool m_spanLines;
};

void
vguiKeyValues::vguiKeyValues(void)
{
	m_tab = 0;
	m_path = "";
	m_depth = 0i;
	m_haveKey = false;
	m_repairs = 0i;
	m_spanLines = false;
}

void
vguiKeyValues::SetSpanLines(bool span)
{
	m_spanLines = span;
}

static string
vguiKeyValues_Join(string path, string seg)
{
	if (path == "")
		return seg;

	return strcat(path, "/", seg);
}

void
vguiKeyValues::_AddChild(string key, string value, bool isBlock)
{
	string seg = strtolower(key);
	string full = vguiKeyValues_Join(m_path, seg);
	int count = (int)(float)hash_get(m_tab, strcat("n:", m_path), 0, EV_FLOAT);

	/* a second block of the same name gets a numbered path of its own */
	if (isBlock && (float)hash_get(m_tab, strcat("b:", full), 0, EV_FLOAT)) {
		int n = 2i;

		while ((float)hash_get(m_tab, strcat("b:", full, "#", sprintf("%i", n)), 0, EV_FLOAT))
			n++;

		seg = strcat(seg, "#", sprintf("%i", n));
		full = vguiKeyValues_Join(m_path, seg);
	}

	hash_add(m_tab, strcat("n:", m_path), (float)(count + 1i), HASH_REPLACE | EV_FLOAT);
	hash_add(m_tab, strcat("k:", m_path, ":", sprintf("%i", count)), strzone(key), EV_STRING);
	hash_add(m_tab, strcat("p:", m_path, ":", sprintf("%i", count)), strzone(full), EV_STRING);

	if (isBlock) {
		hash_add(m_tab, strcat("b:", full), 1, HASH_REPLACE | EV_FLOAT);
		m_path = full;
	} else if (!(float)hash_get(m_tab, strcat("v:", full), 0, EV_FLOAT)) {
		/* the first value wins */
		hash_add(m_tab, strcat("v:", full), 1, EV_FLOAT);
		hash_add(m_tab, strcat("s:", full), strzone(value), EV_STRING);
	}
}

void
vguiKeyValues::_Token(string tok)
{
	if (m_haveKey) {
		_AddChild(m_key, tok, false);
		m_haveKey = false;
	} else {
		m_key = tok;
		m_haveKey = true;
	}
}

void
vguiKeyValues::_Open(void)
{
	if (!m_haveKey) {
		m_key = "";
		m_repairs++;
	}

	hash_add(m_tab, strcat("d:", sprintf("%i", m_depth)), strzone(m_path), HASH_REPLACE | EV_STRING);
	_AddChild(m_key, "", true);
	m_haveKey = false;
	m_depth++;
}

void
vguiKeyValues::_Close(void)
{
	if (m_haveKey) {
		/* a key with no value before the brace */
		m_haveKey = false;
		m_repairs++;
	}

	if (m_depth <= 0i) {
		m_repairs++;
		return;
	}

	m_depth--;
	m_path = hash_get(m_tab, strcat("d:", sprintf("%i", m_depth)), "", EV_STRING);
}

/* whitespace as the reader counts it: space, tab, CR, VT and FF */
static bool
vguiKeyValues_IsSpace(float c)
{
	return (c == 32 || c == 9 || c == 13 || c == 11 || c == 12);
}

bool
vguiKeyValues::LoadFile(string fileName)
{
	filestream fh;
	string line;

	fh = fopen(fileName, FILE_READ);

	if (fh < 0)
		return (false);

	if (!m_tab)
		m_tab = hash_createtab(1024, EV_STRING);

	m_path = "";
	m_depth = 0i;
	m_haveKey = false;

	while (1) {
		int i = 0i;
		int len;

		line = fgets(fh);

		if not (line)
			break;

		len = (int)strlen(line);

		while (i < len) {
			float c = str2chr(line, i);

			if (vguiKeyValues_IsSpace(c)) {
				i++;
				continue;
			}

			/* comment to the end of the line */
			if (c == 47 && str2chr(line, i + 1i) == 47)
				break;

			if (c == 123) {
				_Open();
				i++;
				continue;
			}

			if (c == 125) {
				_Close();
				i++;
				continue;
			}

			if (c == 34) {
				int end = (int)strstrofs(line, "\"", i + 1i);

				if (end < 0i && m_spanLines) {
					/* the string goes on over the following lines */
					string acc = substring(line, i + 1i, len - i - 1i);

					while (1) {
						string next = fgets(fh);

						if not (next) {
							/* still open at the end of the file */
							_Token(acc);
							m_repairs++;
							i = len;
							break;
						}

						end = (int)strstrofs(next, "\"", 0);

						if (end >= 0i) {
							_Token(strcat(acc, "\n", substring(next, 0, end)));
							line = next;
							len = (int)strlen(line);
							i = end + 1i;
							break;
						}

						acc = strcat(acc, "\n", next);
					}
				} else if (end < 0i) {
					/* the quote is still open: the string ends with the line */
					_Token(substring(line, i + 1i, len - i - 1i));
					m_repairs++;
					i = len;
				} else {
					_Token(substring(line, i + 1i, end - i - 1i));
					i = end + 1i;
				}
				continue;
			}

			/* unquoted: up to whitespace, a brace, a quote or a comment */
			int start = i;

			while (i < len) {
				c = str2chr(line, i);

				if (vguiKeyValues_IsSpace(c) || c == 123 || c == 125 || c == 34)
					break;
				if (c == 47 && str2chr(line, i + 1i) == 47)
					break;
				i++;
			}

			_Token(substring(line, start, i - start));
		}
	}

	fclose(fh);

	if (m_haveKey) {
		m_haveKey = false;
		m_repairs++;
	}

	if (m_depth > 0i) {
		m_repairs++;
		m_depth = 0i;
		m_path = "";
	}

	return (true);
}

string
vguiKeyValues::GetString(string path)
{
	if (!m_tab)
		return "";

	return hash_get(m_tab, strcat("s:", strtolower(path)), "", EV_STRING);
}

float
vguiKeyValues::GetFloat(string path)
{
	return stof(GetString(path));
}

bool
vguiKeyValues::IsBlock(string path)
{
	if (path == "")
		return (m_tab) ? true : false;

	if (!m_tab)
		return (false);

	return (float)hash_get(m_tab, strcat("b:", strtolower(path)), 0, EV_FLOAT) ? true : false;
}

bool
vguiKeyValues::Exists(string path)
{
	if (!m_tab)
		return (false);

	if (IsBlock(path))
		return (true);

	return (float)hash_get(m_tab, strcat("v:", strtolower(path)), 0, EV_FLOAT) ? true : false;
}

int
vguiKeyValues::ChildCount(string path)
{
	if (!m_tab)
		return 0i;

	return (int)(float)hash_get(m_tab, strcat("n:", strtolower(path)), 0, EV_FLOAT);
}

string
vguiKeyValues::ChildKey(string path, int idx)
{
	if (!m_tab)
		return "";

	return hash_get(m_tab, strcat("k:", strtolower(path), ":", sprintf("%i", idx)), "", EV_STRING);
}

string
vguiKeyValues::ChildPath(string path, int idx)
{
	if (!m_tab)
		return "";

	return hash_get(m_tab, strcat("p:", strtolower(path), ":", sprintf("%i", idx)), "", EV_STRING);
}

int
vguiKeyValues::RepairCount(void)
{
	return m_repairs;
}

/** @brief Localized strings for `#Token` labels.

Load one or more KeyValues files with a "Tokens" block (such as a
converted `resource/<game>_<language>.txt`). The files must be UTF-8:
the originals are usually UTF-16 and have to be converted first.

@ingroup vgui
*/
vguiKeyValues g_vguiLocalization;

/** Adds the "Tokens" of a localization file. Earlier files win. */
bool
VGUI_LoadLocalization(string fileName)
{
	if (!g_vguiLocalization) {
		g_vguiLocalization = spawn(vguiKeyValues);
		g_vguiLocalization.SetSpanLines(true);
	}

	return g_vguiLocalization.LoadFile(fileName);
}

/** Returns the text for "#Token", or the input unchanged when it is not a token or is unknown. */
string
VGUI_Localize(string text)
{
	string root;
	string val;

	if (substring(text, 0, 1) != "#" || !g_vguiLocalization)
		return text;

	/* the root block is usually "lang", but take whatever the file used */
	for (int i = 0i; i < g_vguiLocalization.ChildCount(""); i++) {
		root = g_vguiLocalization.ChildPath("", i);
		val = g_vguiLocalization.GetString(strcat(root, "/tokens/", substring(text, 1, -1)));

		if (val != "")
			return val;
	}

	return text;
}

/** @brief A VGUI .res layout: one block per panel, keyed by name.

Positions use the VGUI forms `N`, `rN` (from the far edge of the parent),
`cN` (from the parent's centre) and `-N`. Their meaning for any given game
is a convention, see Bulwark's docs/spec/vgui-res.md.

@ingroup vgui
*/
class vguiResLayout:vguiKeyValues
{
public:
	void vguiResLayout(void);

	/** Path of the root block, the one holding the panels. */
	nonvirtual string RootPath(void);
	/** Number of panels. */
	nonvirtual int PanelCount(void);
	/** Path of a panel, for GetString() and friends. */
	nonvirtual string PanelPath(int);
	/** A panel's name: its fieldName, or its block key. */
	nonvirtual string PanelName(int);
	/** Path of the panel with this name, or "" if there is none. */
	nonvirtual string FindPanel(string);
	/** Resolves one coordinate against the size of the parent along that axis. */
	nonvirtual float ResolveCoord(string, float, float);
	/** A panel's position, given its parent's size and the scale applied to plain numbers. */
	nonvirtual vector PanelPos(string, vector, float);
	/** A panel's size, given the same. */
	nonvirtual vector PanelSize(string, vector, float);
	/** Whether a panel is visible: "visible" defaults to 1. */
	nonvirtual bool PanelVisible(string);
};

void
vguiResLayout::vguiResLayout(void)
{
}

string
vguiResLayout::RootPath(void)
{
	/* the first top-level block; a stray key after it does not count */
	for (int i = 0i; i < ChildCount(""); i++) {
		string p = ChildPath("", i);

		if (IsBlock(p))
			return p;
	}

	return "";
}

int
vguiResLayout::PanelCount(void)
{
	return ChildCount(RootPath());
}

string
vguiResLayout::PanelPath(int idx)
{
	return ChildPath(RootPath(), idx);
}

string
vguiResLayout::PanelName(int idx)
{
	string path = PanelPath(idx);
	string field = GetString(strcat(path, "/fieldName"));

	if (field != "")
		return field;

	return ChildKey(RootPath(), idx);
}

string
vguiResLayout::FindPanel(string name)
{
	for (int i = 0i; i < PanelCount(); i++) {
		if (strtolower(PanelName(i)) == strtolower(name))
			return PanelPath(i);
	}

	return "";
}

float
vguiResLayout::ResolveCoord(string val, float parentSize, float scale)
{
	string first;

	val = strtrim(val);
	first = strtolower(substring(val, 0, 1));

	if (first == "r")
		return parentSize - stof(substring(val, 1, -1)) * scale;
	if (first == "c")
		return parentSize / 2 + stof(substring(val, 1, -1)) * scale;

	return stof(val) * scale;
}

vector
vguiResLayout::PanelPos(string path, vector parentSize, float scale)
{
	vector ret = [0,0,0];
	ret[0] = ResolveCoord(GetString(strcat(path, "/xpos")), parentSize[0], scale);
	ret[1] = ResolveCoord(GetString(strcat(path, "/ypos")), parentSize[1], scale);
	return ret;
}

vector
vguiResLayout::PanelSize(string path, vector parentSize, float scale)
{
	vector ret = [0,0,0];
	ret[0] = ResolveCoord(GetString(strcat(path, "/wide")), parentSize[0], scale);
	ret[1] = ResolveCoord(GetString(strcat(path, "/tall")), parentSize[1], scale);
	return ret;
}

bool
vguiResLayout::PanelVisible(string path)
{
	if (!Exists(strcat(path, "/visible")))
		return (true);

	return GetFloat(strcat(path, "/visible")) ? true : false;
}

/** Called when a button VGUI_ResBuild made is clicked, with the button and its "command" value. */
var void(vguiWidget, string) g_vguiResCommand;

/** A button that reports its "command" to g_vguiResCommand. */
class vguiResButton:vguiButton
{
public:
	void vguiResButton(void);
	virtual void OnMouseUp(void);

	string m_resCommand;
};

void
vguiResButton::vguiResButton(void)
{
	m_resCommand = "";
}

void
vguiResButton::OnMouseUp(void)
{
	if (g_vguiResCommand)
		g_vguiResCommand(this, m_resCommand);
}

/** Called for each panel whose ControlName VGUI_ResBuild doesn't know.
Return a widget to use, or __NULL__ to skip the panel. */
var vguiWidget(vguiResLayout, string) g_vguiResCustomControl;

/** @brief Builds widgets for a layout inside a window.

The first panel whose position is not relative to anything (normally the
frame itself, e.g. the root dialog) sizes and places `frame`. Every other
panel becomes a child of `frame`:

- Label: vguiLabel, with labelText localized and textAlignment honoured.
- Button: vguiResButton with labelText; a click calls g_vguiResCommand with its "command".
- TextEntry: vguiTextBox.
- CheckButton: vguiCheckbox with labelText.
- ComboBox: vguiComboBox.
- Anything else goes to g_vguiResCustomControl, or is skipped.

Each widget's `vguiResName` field holds its panel name, for VGUI_ResFind().
Combo boxes are added last, bottom first, so open lists draw over the rest.

Returns the number of widgets made. */
int
VGUI_ResBuild(vguiWindow frame, vguiResLayout res, string framePanel, float scale)
{
	int made = 0i;
	vector frameSize;
	string framePath = res.FindPanel(framePanel);

	if (framePath != "") {
		frameSize = res.PanelSize(framePath, g_vidsize, scale);
		frame.SetSize(frameSize);
		frame.SetTitle(VGUI_Localize(res.GetString(strcat(framePath, "/title"))));
		frame.vguiResName = framePanel;
	} else {
		frameSize = frame.GetSize();
	}

	for (int pass = 0i; pass < 2i; pass++) {
		for (int j = 0i; j < res.PanelCount(); j++) {
			/* combo boxes go in the second pass, lowest on screen first */
			int i = (pass == 1i) ? (res.PanelCount() - 1i - j) : j;
			string path = res.PanelPath(i);
			string ctl = strtolower(res.GetString(strcat(path, "/ControlName")));
			string label = VGUI_Localize(res.GetString(strcat(path, "/labelText")));
			vguiWidget w = __NULL__;

			if (path == framePath)
				continue;
			if ((ctl == "combobox") != (pass == 1i))
				continue;

			switch (ctl) {
			case "label":
				vguiLabel lbl = spawn(vguiLabel);
				string align = strtolower(res.GetString(strcat(path, "/textAlignment")));
				lbl.SetTitle(label);
				lbl.SetSize(res.PanelSize(path, frameSize, scale));

				if (align == "center")
					lbl.SetAlignment(AF_LEFT | AF_RIGHT | AF_TOP | AF_BOTTOM);
				else if (align == "east")
					lbl.SetAlignment(AF_RIGHT | AF_TOP | AF_BOTTOM);
				else
					lbl.SetAlignment(AF_LEFT | AF_TOP | AF_BOTTOM);
				w = lbl;
				break;
			case "button":
				vguiResButton btn = spawn(vguiResButton);
				btn.SetTitle(label);
				btn.m_resCommand = strzone(res.GetString(strcat(path, "/command")));
				w = btn;
				break;
			case "textentry":
				vguiTextBox txt = spawn(vguiTextBox);
				w = txt;
				break;
			case "checkbutton":
				vguiCheckbox chk = spawn(vguiCheckbox);
				chk.SetTitle(label);
				w = chk;
				break;
			case "combobox":
				vguiComboBox combo = spawn(vguiComboBox);
				w = combo;
				break;
			default:
				if (g_vguiResCustomControl)
					w = g_vguiResCustomControl(res, path);
			}

			if (!w)
				continue;

			w.vguiResName = res.PanelName(i);
			w.SetPos(res.PanelPos(path, frameSize, scale));
			w.SetSize(res.PanelSize(path, frameSize, scale));
			frame.Add(w);

			if (!res.PanelVisible(path))
				w.Hide();

			made++;
		}
	}

	return made;
}

/** Finds a widget that VGUI_ResBuild made, by panel name. */
vguiWidget
VGUI_ResFind(string name)
{
	for (entity e = find(__NULL__, vguiResName, name); e; e = find(e, vguiResName, name)) {
		if (e.isVGUI)
			return (vguiWidget)e;
	}

	return __NULL__;
}
