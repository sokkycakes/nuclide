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

/** @file vgui.qc
A small reader and painter for Source VGUI resource files, so a Team
Fortress 2 HUD's own layout files (resource/clientscheme.res,
scripts/hudlayout.res, resource/ui/*.res) place and style this HUD.

What it understands:
- KeyValues text: quoted or bare tokens, // comments, nested blocks,
  #base and #include (keys already set win, as in Source), and platform
  conditions such as [$WIN32] (the layout is read as on Windows).
- The scheme: Colors, Fonts (TrueType files from CustomFontFiles, the
  entry whose yres fits the screen) and scalable_image Borders.
- Panels: xpos/ypos with r (from the right/bottom), c (from the centre)
  and plain values, wide/tall with f (full minus), proportional to a 480
  line tall screen like TF2's HUD, zpos order, visible, pin_to_sibling.
- ImagePanel/CTFImagePanel (image, drawcolor, scaleImage), Label/CExLabel
  (labelText with %variables%, font, fgcolor, textAlignment, textinsetx/y,
  centerwrap, auto_wide_tocontents), bgcolor_override with paintbackground,
  and borders behind any panel.

What the HUD code does for each element, like TF2's C++ panels: it sets the
%variables%, shows or hides panels and draws anything special.
Images are looked up under gfx/vgui/ (TF2 keeps them in materials/vgui/)
as .tga or .png.
*/

/* all keys, lowercased paths: "scheme/colors/tanlight", "<elem>/<panel>/xpos" */
var float g_vgTab;
/* per frame panel rectangles and variables */
var float g_vgFrameTab;
var float g_vgFrameNum;
var float g_vgScale;
var vector g_vgScreenMins;
var vector g_vgScreenSize;
var bool g_vgReady;
/* the local player's team as TF2 numbers it, for teambg_2/teambg_3 images */
var float g_vgTeam;

#define VG_NIL "\x7f"

string g_vgStack[24];
string g_vgBaseQueue[32];
int g_vgBaseCount;

string
VGui_Get(string keyPath)
{
	return (string)hash_get(g_vgTab, strtolower(keyPath), "");
}

bool
VGui_Has(string keyPath)
{
	return ((string)hash_get(g_vgTab, strtolower(keyPath), VG_NIL) != VG_NIL);
}

/** Sets a key unless it already has a value: the first one read wins. */
void
VGui_Put(string keyPath, string keyValue)
{
	keyPath = strtolower(keyPath);

	if ((string)hash_get(g_vgTab, keyPath, VG_NIL) == VG_NIL) {
		hash_add(g_vgTab, keyPath, strzone(keyValue), EV_STRING);
	}
}

/** Sets a key, replacing what was there (for the HUD code's overrides). */
void
VGui_Set(string keyPath, string keyValue)
{
	hash_add(g_vgTab, strtolower(keyPath), strzone(keyValue), EV_STRING | HASH_REPLACE);
}

/** Number of child blocks under a path, in file order. */
int
VGui_ChildCount(string keyPath)
{
	return stoi(VGui_Get(strcat(keyPath, "#n")));
}

string
VGui_Child(string keyPath, int childIndex)
{
	return VGui_Get(sprintf("%s#%i", keyPath, childIndex));
}

static void
VGui_AddChild(string parentPath, string childName)
{
	string seenKey = strtolower(strcat(parentPath, "#has/", childName));

	if ((string)hash_get(g_vgTab, seenKey, VG_NIL) != VG_NIL) {
		return;
	}

	int childCount = VGui_ChildCount(parentPath);
	hash_add(g_vgTab, seenKey, "1", EV_STRING);
	VGui_Set(sprintf("%s#%i", parentPath, childCount), childName);
	VGui_Set(strcat(parentPath, "#n"), itos(childCount + 1i));
}

/** Evaluates a condition such as [$WIN32], [!$X360] or [$WIN32&&!$OSX]. */
static bool
VGui_Condition(string conditionText)
{
	string innerText = strtolower(substring(conditionText, 1, strlen(conditionText) - 2));
	bool result = true;
	bool joinWithAnd = true;
	int textLength = strlen(innerText);
	int charIndex = 0;

	while (charIndex < textLength) {
		float charCode = str2chr(innerText, charIndex);

		if (charCode == '&' || charCode == '|') {
			joinWithAnd = (charCode == '&');
			charIndex += 2;
			continue;
		}

		if (charCode == ' ') {
			charIndex++;
			continue;
		}

		bool negate = false;

		if (charCode == '!') {
			negate = true;
			charIndex++;
		}

		int nameStart = charIndex;

		while (charIndex < textLength) {
			charCode = str2chr(innerText, charIndex);

			if (charCode == ' ' || charCode == '&' || charCode == '|') {
				break;
			}

			charIndex++;
		}

		string platformName = substring(innerText, nameStart, charIndex - nameStart);
		bool platformTrue = (platformName == "$win32" || platformName == "$windows" || platformName == "$english");

		if (negate) {
			platformTrue = !platformTrue;
		}

		result = joinWithAnd ? (result && platformTrue) : (result || platformTrue);
	}

	return (result);
}

/** Resolves "../x" and "./x" in a path. */
static string
VGui_CleanPath(string filePath)
{
	int partCount = tokenizebyseparator(filePath, "/");
	string partList[32];
	int keptCount = 0;

	for (int i = 0; i < partCount && i < 32; i++) {
		string part = argv(i);

		if (part == ".." && keptCount > 0) {
			keptCount--;
		} else if (part != "." && part != "") {
			partList[keptCount] = part;
			keptCount++;
		}
	}

	string cleanPath = "";

	for (int i = 0; i < keptCount; i++) {
		cleanPath = (i == 0) ? partList[i] : strcat(cleanPath, "/", partList[i]);
	}

	return (cleanPath);
}

static string
VGui_DirName(string filePath)
{
	int lastSlash = -1;

	for (int i = 0; i < strlen(filePath); i++) {
		if (str2chr(filePath, i) == '/') {
			lastSlash = i;
		}
	}

	return (lastSlash < 0) ? "" : substring(filePath, 0, lastSlash + 1);
}

/** Reads one KeyValues file. Keys land under storePrefix, skipping the
first skipDepth block names (a .res file's own root name). #base files
are read afterwards, so their keys only fill gaps. */
void
VGui_ParseFile(string filePath, string storePrefix, int skipDepth)
{
	filePath = strtolower(filePath);
	filestream fileHandle = fopen(filePath, FILE_READ);

	if (fileHandle < 0) {
		return;
	}

	int stackDepth = 0;
	int skipUntilDepth = -1;
	string pendingKey = "";
	bool haveKey = false;
	string fileDir = VGui_DirName(filePath);
	int firstBase = g_vgBaseCount;
	string lineText;

	while ((lineText = fgets(fileHandle))) {
		int lineLength = strlen(lineText);
		int charIndex = 0;

		while (charIndex < lineLength) {
			float charCode = str2chr(lineText, charIndex);

			if (charCode == ' ' || charCode == '\t' || charCode == '\r' || charCode == '\n') {
				charIndex++;
				continue;
			}

			if (charCode == '/' && str2chr(lineText, charIndex + 1) == '/') {
				break;
			}

			if (charCode == '{') {
				charIndex++;

				if (haveKey) {
					g_vgStack[stackDepth] = pendingKey;
				} else {
					g_vgStack[stackDepth] = "";
				}

				if (skipUntilDepth < 0 && stackDepth >= skipDepth) {
					string parentPath = storePrefix;

					for (int i = skipDepth; i < stackDepth; i++) {
						parentPath = STRING_SET(parentPath) ? strcat(parentPath, "/", g_vgStack[i]) : g_vgStack[i];
					}

					VGui_AddChild(parentPath, g_vgStack[stackDepth]);
				}

				stackDepth++;
				haveKey = false;
				continue;
			}

			if (charCode == '}') {
				charIndex++;

				if (stackDepth > 0) {
					stackDepth--;
				}

				if (skipUntilDepth >= 0 && stackDepth <= skipUntilDepth) {
					skipUntilDepth = -1;
				}

				haveKey = false;
				continue;
			}

			if (charCode == '[') {
				int closeIndex = charIndex;

				while (closeIndex < lineLength && str2chr(lineText, closeIndex) != ']') {
					closeIndex++;
				}

				/* a false condition on a block name skips the block */
				if (haveKey && VGui_Condition(substring(lineText, charIndex, closeIndex - charIndex + 1)) == false) {
					if (skipUntilDepth < 0) {
						skipUntilDepth = stackDepth;
					}

					/* skipUntilDepth closes when the block's } brings us back */
				}

				charIndex = closeIndex + 1;
				continue;
			}

			/* a token: quoted or bare */
			string tokenText;

			if (charCode == '"') {
				int tokenEnd = charIndex + 1;

				while (tokenEnd < lineLength && str2chr(lineText, tokenEnd) != '"') {
					tokenEnd++;
				}

				tokenText = substring(lineText, charIndex + 1, tokenEnd - charIndex - 1);
				charIndex = tokenEnd + 1;
			} else {
				int tokenEnd = charIndex;

				while (tokenEnd < lineLength) {
					float endCode = str2chr(lineText, tokenEnd);

					if (endCode == ' ' || endCode == '\t' || endCode == '\r' || endCode == '\n' || endCode == '{' || endCode == '}' || endCode == '"') {
						break;
					}

					tokenEnd++;
				}

				tokenText = substring(lineText, charIndex, tokenEnd - charIndex);
				charIndex = tokenEnd;
			}

			if (haveKey == false) {
				pendingKey = tokenText;
				haveKey = true;

				/* #base "file" and #include "file" */
				if (stackDepth == 0 && (strtolower(tokenText) == "#base" || strtolower(tokenText) == "#include")) {
					pendingKey = "#base";
				}

				continue;
			}

			/* key and value */
			haveKey = false;

			if (pendingKey == "#base") {
				if (g_vgBaseCount < 32) {
					g_vgBaseQueue[g_vgBaseCount] = strzone(VGui_CleanPath(strcat(fileDir, tokenText)));
					g_vgBaseCount++;
				}

				continue;
			}

			/* look ahead for a condition on this key */
			int peekIndex = charIndex;

			while (peekIndex < lineLength && (str2chr(lineText, peekIndex) == ' ' || str2chr(lineText, peekIndex) == '\t')) {
				peekIndex++;
			}

			if (str2chr(lineText, peekIndex) == '[') {
				int condEnd = peekIndex;

				while (condEnd < lineLength && str2chr(lineText, condEnd) != ']') {
					condEnd++;
				}

				bool keep = VGui_Condition(substring(lineText, peekIndex, condEnd - peekIndex + 1));
				charIndex = condEnd + 1;

				if (keep == false) {
					continue;
				}
			}

			if (skipUntilDepth >= 0 || stackDepth < skipDepth) {
				continue;
			}

			string keyPath = storePrefix;

			for (int i = skipDepth; i < stackDepth; i++) {
				keyPath = STRING_SET(keyPath) ? strcat(keyPath, "/", g_vgStack[i]) : g_vgStack[i];
			}

			VGui_Put(STRING_SET(keyPath) ? strcat(keyPath, "/", pendingKey) : pendingKey, tokenText);
		}
	}

	fclose(fileHandle);

	/* the #base files, in order: each only fills keys still missing */
	int lastBase = g_vgBaseCount;

	for (int i = firstBase; i < lastBase; i++) {
		VGui_ParseFile(g_vgBaseQueue[i], storePrefix, skipDepth);
	}

	g_vgBaseCount = firstBase;
}

/* ---- scheme ------------------------------------------------------------- */

/** A scheme colour name or "r g b a", as [r, g, b] 0-1 and alpha 0-1. */
vector
VGui_Color(string colorText, __out float colorAlpha)
{
	colorAlpha = 1.0f;

	if (!STRING_SET(colorText)) {
		return [1, 1, 1];
	}

	string schemeColor = VGui_Get(strcat("scheme/colors/", colorText));

	if (STRING_SET(schemeColor)) {
		colorText = schemeColor;
	}

	int partCount = tokenize(colorText);

	if (partCount < 3) {
		return [1, 1, 1];
	}

	if (partCount >= 4) {
		colorAlpha = stof(argv(3)) / 255;
	}

	return [stof(argv(0)), stof(argv(1)), stof(argv(2))] / 255;
}

/** Loads a scheme font at this screen's size, returning the font slot. */
float
VGui_Font(string fontName, __out float fontSize)
{
	string fontPath = strcat("scheme/fonts/", fontName);
	int entryCount = VGui_ChildCount(fontPath);
	string chosenEntry = "";

	fontSize = 0;

	/* the entry whose yres range holds the screen height, else the first */
	for (int i = 0; i < entryCount; i++) {
		string entryName = VGui_Child(fontPath, i);
		string yresText = VGui_Get(sprintf("%s/%s/yres", fontPath, entryName));

		if (!STRING_SET(yresText)) {
			if (!STRING_SET(chosenEntry)) {
				chosenEntry = entryName;
			}

			continue;
		}

		tokenize(yresText);

		if (g_vgScreenSize[1] >= stof(argv(0)) && g_vgScreenSize[1] <= stof(argv(1))) {
			chosenEntry = entryName;
			break;
		}
	}

	if (!STRING_SET(chosenEntry)) {
		return (0);
	}

	string entryPath = sprintf("%s/%s/", fontPath, chosenEntry);
	string faceName = strtolower(VGui_Get(strcat(entryPath, "name")));
	fontSize = rint(stof(VGui_Get(strcat(entryPath, "tall"))) * g_vgScale);

	if (fontSize < 4) {
		fontSize = 4;
	}

	/* cached per face and size */
	string cacheKey = sprintf("font:%s:%d", faceName, fontSize);
	float cachedSlot = (float)hash_get(g_vgFrameTab, cacheKey, -1, EV_FLOAT);

	if (cachedSlot >= 0) {
		return (cachedSlot);
	}

	string fontFile = VGui_Get(strcat("scheme/fontfile/", faceName));
	float fontSlot = 0;

	if (STRING_SET(fontFile)) {
		fontSlot = loadfont("", fontFile, ftos(fontSize), -1, 0, 0);
	}

	if (fontSlot < 0) {
		fontSlot = 0;
	}

	hash_add(g_vgFrameTab, cacheKey, fontSlot, EV_FLOAT | HASH_REPLACE);
	return (fontSlot);
}

/** Maps every CustomFontFiles face name to its file. */
static void
VGui_IndexFontFiles(void)
{
	string filesPath = "scheme/customfontfiles";
	int fileCount = VGui_ChildCount(filesPath);

	for (int i = 0; i < fileCount; i++) {
		string entryName = VGui_Child(filesPath, i);
		string fontFile = VGui_Get(sprintf("%s/%s/font", filesPath, entryName));
		string faceName = VGui_Get(sprintf("%s/%s/name", filesPath, entryName));

		if (STRING_SET(fontFile) && STRING_SET(faceName)) {
			VGui_Put(strcat("scheme/fontfile/", strtolower(faceName)), strtolower(fontFile));
		}
	}
}

void
VGui_Init(void)
{
	if (g_vgReady) {
		return;
	}

	g_vgTab = hash_createtab(4096, EV_STRING);
	g_vgFrameTab = hash_createtab(1024, EV_STRING);
	VGui_ParseFile("resource/clientscheme.res", "", 0);
	VGui_IndexFontFiles();
	VGui_ParseFile("scripts/hudlayout.res", "hudlayout", 1);
	g_vgReady = true;
}

/** Reads an element's .res file; its panels are then "<elementName>/<panel>". */
void
VGui_LoadElement(string elementName, string resFile)
{
	VGui_ParseFile(resFile, elementName, 1);
}

/* ---- layout ------------------------------------------------------------- */

void
VGui_BeginFrame(void)
{
	g_vgFrameNum++;
	g_vgScreenMins = screen.HUDMins();
	g_vgScreenSize = screen.HUDSize();
	float newScale = g_vgScreenSize[1] / 480;

	/* fonts are loaded per size, so drop them when the screen changes */
	if (newScale != g_vgScale) {
		hash_destroytab(g_vgFrameTab);
		g_vgFrameTab = hash_createtab(1024, EV_STRING);
	}

	g_vgScale = newScale;
}

/** A variable for labels' %name% text in this element, this frame. */
void
VGui_SetVar(string elementName, string varName, string varValue)
{
	hash_add(g_vgFrameTab, strtolower(sprintf("var:%s:%s", elementName, varName)), varValue, EV_STRING | HASH_REPLACE);
}

/* nested panels ("HudMatchStatus/ObjectiveStatusTimePanel") use their
   element's variables */
static string
VGui_GetVar(string elementName, string varName)
{
	int slashAt = strstrofs(elementName, "/");

	if (slashAt >= 0) {
		elementName = substring(elementName, 0, slashAt);
	}

	return (string)hash_get(g_vgFrameTab, strtolower(sprintf("var:%s:%s", elementName, varName)), "");
}

/** Shows or hides a panel, overriding its "visible" key. */
void
VGui_Show(string elementName, string panelName, bool isShown)
{
	VGui_Set(sprintf("%s/%s/@visible", elementName, panelName), isShown ? "1" : "0");
}

bool
VGui_IsShown(string elementName, string panelName)
{
	string panelPath = sprintf("%s/%s/", elementName, panelName);
	string overrideValue = VGui_Get(strcat(panelPath, "@visible"));

	if (STRING_SET(overrideValue)) {
		return (stof(overrideValue) != 0);
	}

	string visibleValue = VGui_Get(strcat(panelPath, "visible"));
	return (!STRING_SET(visibleValue) || stof(visibleValue) != 0);
}

/** Replaces a key for this element's panel (such as its image). */
void
VGui_Override(string elementName, string panelName, string keyName, string keyValue)
{
	VGui_Set(sprintf("%s/%s/@%s", elementName, panelName, keyName), keyValue);
}

/** A panel key, preferring the HUD code's override. */
string
VGui_Key(string elementName, string panelName, string keyName)
{
	string panelPath = sprintf("%s/%s/", elementName, panelName);
	string overrideValue = VGui_Get(strcat(panelPath, "@", keyName));

	if (STRING_SET(overrideValue)) {
		return (overrideValue);
	}

	return VGui_Get(strcat(panelPath, keyName));
}

/** One coordinate: plain, r (from the far edge), c (from the centre),
f (full minus) or p (fraction of the parent), scaled to the screen. */
static float
VGui_Coord(string valueText, float parentSize, float ownSize)
{
	if (!STRING_SET(valueText)) {
		return (0);
	}

	float firstChar = str2chr(valueText, 0);

	/* "rs1" and "cs-0.5" count in the panel's own size */
	float secondChar = str2chr(valueText, 1);

	if ((firstChar == 'r' || firstChar == 'R') && (secondChar == 's' || secondChar == 'S')) {
		return parentSize - (stof(substring(valueText, 2, -1)) * ownSize);
	}

	if ((firstChar == 'c' || firstChar == 'C') && (secondChar == 's' || secondChar == 'S')) {
		return (parentSize / 2) + (stof(substring(valueText, 2, -1)) * ownSize);
	}

	if (firstChar == 'r' || firstChar == 'R') {
		return parentSize - (stof(substring(valueText, 1, -1)) * g_vgScale);
	}

	if (firstChar == 'c' || firstChar == 'C') {
		return (parentSize / 2) + (stof(substring(valueText, 1, -1)) * g_vgScale);
	}

	if (firstChar == 'f' || firstChar == 'F') {
		return parentSize - (stof(substring(valueText, 1, -1)) * g_vgScale);
	}

	if (firstChar == 'p' || firstChar == 'P') {
		return parentSize * stof(substring(valueText, 1, -1));
	}

	return stof(valueText) * g_vgScale;
}

/** The corner offset of a PIN_ name within a rectangle of that size. */
static vector
VGui_PinCorner(string pinName, vector rectSize)
{
	switch (strtoupper(pinName)) {
	case "PIN_TOPRIGHT":
	case "1":
		return [rectSize[0], 0];
	case "PIN_BOTTOMLEFT":
	case "2":
		return [0, rectSize[1]];
	case "PIN_BOTTOMRIGHT":
	case "3":
		return [rectSize[0], rectSize[1]];
	case "PIN_CENTER_TOP":
	case "4":
		return [rectSize[0] / 2, 0];
	case "PIN_CENTER_RIGHT":
	case "5":
		return [rectSize[0], rectSize[1] / 2];
	case "PIN_CENTER_BOTTOM":
	case "6":
		return [rectSize[0] / 2, rectSize[1]];
	case "PIN_CENTER_LEFT":
	case "7":
		return [0, rectSize[1] / 2];
	default:
		return [0, 0];
	}
}

/** Where the element's own panel sits on screen and its size. */
vector
VGui_ElementRect(string elementName, __out vector elementSize)
{
	/* the element's .res names its own panel after it; hudlayout.res
	   gives the rest */
	string ownPath = sprintf("%s/%s/", elementName, elementName);
	string layoutPath = sprintf("hudlayout/%s/", elementName);
	string xText = VGui_Get(strcat(ownPath, "xpos"));
	string yText = VGui_Get(strcat(ownPath, "ypos"));
	string wideText = VGui_Get(strcat(ownPath, "wide"));
	string tallText = VGui_Get(strcat(ownPath, "tall"));

	if (!STRING_SET(xText)) xText = VGui_Get(strcat(layoutPath, "xpos"));
	if (!STRING_SET(yText)) yText = VGui_Get(strcat(layoutPath, "ypos"));
	if (!STRING_SET(wideText)) wideText = VGui_Get(strcat(layoutPath, "wide"));
	if (!STRING_SET(tallText)) tallText = VGui_Get(strcat(layoutPath, "tall"));

	if (!STRING_SET(wideText)) wideText = "f0";
	if (!STRING_SET(tallText)) tallText = "f0";

	elementSize[0] = VGui_Coord(wideText, g_vgScreenSize[0], 0);
	elementSize[1] = VGui_Coord(tallText, g_vgScreenSize[1], 0);
	elementSize[2] = 0;
	return g_vgScreenMins + [VGui_Coord(xText, g_vgScreenSize[0], elementSize[0]), VGui_Coord(yText, g_vgScreenSize[1], elementSize[1])];
}

/** A panel's rectangle inside its element, following pin_to_sibling. */
vector
VGui_PanelRect(string elementName, string panelName, vector parentPos, vector parentSize, __out vector panelSize)
{
	string frameKey = sprintf("rect:%s:%s:%d", elementName, panelName, g_vgFrameNum);
	string cachedRect = (string)hash_get(g_vgFrameTab, frameKey, "");

	if (STRING_SET(cachedRect)) {
		tokenize(cachedRect);
		panelSize = [stof(argv(2)), stof(argv(3))];
		return [stof(argv(0)), stof(argv(1))];
	}

	/* placeholder against pinning loops */
	hash_add(g_vgFrameTab, frameKey, "0 0 0 0", EV_STRING | HASH_REPLACE);

	panelSize[0] = VGui_Coord(VGui_Key(elementName, panelName, "wide"), parentSize[0], 0);
	panelSize[1] = VGui_Coord(VGui_Key(elementName, panelName, "tall"), parentSize[1], 0);
	panelSize[2] = 0;

	vector panelPos;
	string pinSibling = VGui_Key(elementName, panelName, "pin_to_sibling");

	if (STRING_SET(pinSibling) && VGui_Has(sprintf("%s/%s/fieldname", elementName, pinSibling))) {
		vector siblingSize;
		vector siblingPos = VGui_PanelRect(elementName, pinSibling, parentPos, parentSize, siblingSize);
		vector siblingCorner = VGui_PinCorner(VGui_Key(elementName, panelName, "pin_to_sibling_corner"), siblingSize);
		vector ownCorner = VGui_PinCorner(VGui_Key(elementName, panelName, "pin_corner_to_sibling"), panelSize);
		panelPos = siblingPos + siblingCorner - ownCorner;
		panelPos[0] += stof(VGui_Key(elementName, panelName, "xpos")) * g_vgScale;
		panelPos[1] += stof(VGui_Key(elementName, panelName, "ypos")) * g_vgScale;
	} else {
		panelPos = parentPos;
		panelPos[0] += VGui_Coord(VGui_Key(elementName, panelName, "xpos"), parentSize[0], panelSize[0]);
		panelPos[1] += VGui_Coord(VGui_Key(elementName, panelName, "ypos"), parentSize[1], panelSize[1]);
	}

	hash_add(g_vgFrameTab, frameKey, sprintf("%f %f %f %f", panelPos[0], panelPos[1], panelSize[0], panelSize[1]), EV_STRING | HASH_REPLACE);
	return (panelPos);
}

/* ---- painting ----------------------------------------------------------- */

/** An image path from a .res file ("replay/thumbnails/x", "../hud/x")
as a picture name under gfx/vgui/. */
string
VGui_ImagePath(string imageName)
{
	return strtolower(VGui_CleanPath(strcat("gfx/vgui/", imageName)));
}

void
VGui_DrawImage(string imageName, vector imagePos, vector imageSize, vector imageColor, float imageAlpha)
{
	if (!STRING_SET(imageName) || imageAlpha <= 0) {
		return;
	}

	string picName = VGui_ImagePath(imageName);
	string existsKey = strcat("pic:", picName);
	float picExists = (float)hash_get(g_vgFrameTab, existsKey, -1, EV_FLOAT);

	/* TF2's own HUD pictures aren't there: draw nothing for those */
	if (picExists < 0) {
		precache_pic(picName);
		picExists = (drawgetimagesize(picName) != [0, 0, 0]) ? 1 : 0;
		hash_add(g_vgFrameTab, existsKey, picExists, EV_FLOAT | HASH_REPLACE);
	}

	if (picExists == 0) {
		return;
	}

	drawpic(imagePos, picName, imageSize, imageColor, imageAlpha, DRAWFLAG_NORMAL);
}

static void
VGui_DrawBorder(string borderName, vector borderPos, vector borderSize)
{
	string borderPath = strcat("scheme/borders/", borderName, "/");

	if (strtolower(VGui_Get(strcat(borderPath, "bordertype"))) != "scalable_image") {
		return;
	}

	float borderAlpha;
	vector borderColor = VGui_Color(VGui_Get(strcat(borderPath, "color")), borderAlpha);
	VGui_DrawImage(VGui_Get(strcat(borderPath, "image")), borderPos, borderSize, borderColor, borderAlpha);
}

/** Swaps %name% for the element's variables. */
string
VGui_FillText(string elementName, string labelText)
{
	int percentStart = strstrofs(labelText, "%");

	while (percentStart >= 0) {
		int percentEnd = strstrofs(labelText, "%", percentStart + 1);

		if (percentEnd < 0) {
			break;
		}

		string varName = substring(labelText, percentStart + 1, percentEnd - percentStart - 1);
		string varValue = VGui_GetVar(elementName, varName);
		labelText = strcat(substring(labelText, 0, percentStart), varValue, substring(labelText, percentEnd + 1, -1));
		percentStart = strstrofs(labelText, "%", percentStart + strlen(varValue));
	}

	/* #localization tokens we don't have: show nothing */
	if (substring(labelText, 0, 1) == "#") {
		return "";
	}

	return (labelText);
}

static void
VGui_DrawLabel(string elementName, string panelName, vector labelPos, vector labelSize, float panelAlpha)
{
	string labelText = VGui_FillText(elementName, VGui_Key(elementName, panelName, "labeltext"));

	if (!STRING_SET(labelText)) {
		return;
	}

	float fontSize;
	float fontSlot = VGui_Font(VGui_Key(elementName, panelName, "font"), fontSize);
	float textAlpha;
	string colorText = VGui_Key(elementName, panelName, "fgcolor_override");

	if (!STRING_SET(colorText)) {
		colorText = VGui_Key(elementName, panelName, "fgcolor");
	}

	vector textColor = VGui_Color(colorText, textAlpha);
	string alignText = strtolower(VGui_Key(elementName, panelName, "textalignment"));
	vector textInset = [stof(VGui_Key(elementName, panelName, "textinsetx")), stof(VGui_Key(elementName, panelName, "textinsety"))] * g_vgScale;

	if (fontSize <= 0) {
		fontSize = 12 * g_vgScale;
	}

	/* the HUD progs draws through the client's font API: it sets drawfont
	   in the client progs */
	font_s labelFont;
	labelFont.iID = (int)fontSlot;
	labelFont.iScaleX = labelFont.iScaleY = (int)fontSize;
	labelFont.vecColor = [1, 1, 1];
	labelFont.flAlpha = 1.0f;
	labelFont.iFlags = 0i;
	float textWidth = font.StringWidth(labelText, TRUE, labelFont);
	vector textPos = labelPos;

	if (strstrofs(alignText, "east") >= 0) {
		textPos[0] += labelSize[0] - textWidth - textInset[0];
	} else if (alignText == "center" || alignText == "north" || alignText == "south") {
		textPos[0] += (labelSize[0] - textWidth) / 2 + textInset[0];
	} else {
		textPos[0] += textInset[0];
	}

	if (strstrofs(alignText, "north") >= 0) {
		textPos[1] += textInset[1];
	} else if (strstrofs(alignText, "south") >= 0) {
		textPos[1] += labelSize[1] - fontSize - textInset[1];
	} else {
		textPos[1] += (labelSize[1] - fontSize) / 2 + textInset[1];
	}

	/* a border behind the text, as wide as the text when asked */
	string borderName = VGui_Key(elementName, panelName, "border");

	if (STRING_SET(borderName)) {
		vector borderPos = labelPos;
		vector borderSize = labelSize;

		if (stof(VGui_Key(elementName, panelName, "auto_wide_tocontents")) != 0) {
			borderSize[0] = textWidth + textInset[0] * 2;
		}

		VGui_DrawBorder(borderName, borderPos, borderSize);
	}

	draw.Text_RGBA(textPos, labelText, textColor, textAlpha * panelAlpha, labelFont);
}

/* a scheme font as the client's font API wants it, in g_vgTextFont */
font_s g_vgTextFont;

static void
VGui_SetTextFont(string fontName)
{
	float fontSize;
	float fontSlot = VGui_Font(fontName, fontSize);

	if (fontSize <= 0) {
		fontSize = 12 * g_vgScale;
	}

	g_vgTextFont.iID = (int)fontSlot;
	g_vgTextFont.iScaleX = g_vgTextFont.iScaleY = (int)fontSize;
	g_vgTextFont.vecColor = [1, 1, 1];
	g_vgTextFont.flAlpha = 1.0f;
	g_vgTextFont.iFlags = 0i;
}

/** Text in a scheme font, for panels the HUD code draws itself. */
void
VGui_DrawText(string fontName, vector textPos, string textValue, vector textColor, float textAlpha)
{
	VGui_SetTextFont(fontName);
	draw.Text_RGBA(textPos, textValue, textColor, textAlpha, g_vgTextFont);
}

float
VGui_TextWidth(string fontName, string textValue)
{
	VGui_SetTextFont(fontName);
	return font.StringWidth(textValue, TRUE, g_vgTextFont);
}

float
VGui_FontHeight(string fontName)
{
	float fontSize;
	VGui_Font(fontName, fontSize);
	return (fontSize > 0) ? fontSize : 12 * g_vgScale;
}

/** Draws the visible child panels of a panel path, lowest zpos first,
then each one's own children inside it. */
void
VGui_DrawChildren(string parentPath, vector parentPos, vector parentSize, float parentAlpha)
{
	int panelCount = VGui_ChildCount(parentPath);
	string panelNames[96];
	float panelOrder[96];
	int drawCount = 0;
	string ownName = strtolower(parentPath);

	for (int i = 0; i < panelCount && drawCount < 96; i++) {
		string panelName = VGui_Child(parentPath, i);

		/* the element's own settings, and blocks that aren't panels */
		if (strtolower(panelName) == ownName || !VGui_Has(sprintf("%s/%s/fieldname", parentPath, panelName))) {
			continue;
		}

		if (!VGui_IsShown(parentPath, panelName)) {
			continue;
		}

		panelNames[drawCount] = panelName;
		panelOrder[drawCount] = stof(VGui_Key(parentPath, panelName, "zpos"));

		/* a "...Shadow" label goes behind the label it shadows when they
		   share a zpos (REDUX's CTF scores do), as they do in TF2 */
		if (strstrofs(strtolower(panelName), "shadow") >= 0) {
			panelOrder[drawCount] -= 0.5f;
		}
		drawCount++;
	}

	/* insertion sort by zpos, keeping file order for ties */
	for (int i = 1; i < drawCount; i++) {
		string movingName = panelNames[i];
		float movingOrder = panelOrder[i];
		int j = i - 1;

		/* QuakeC doesn't short-circuit &&, so test j on its own */
		while (j >= 0) {
			if (panelOrder[j] <= movingOrder) {
				break;
			}

			panelNames[j + 1] = panelNames[j];
			panelOrder[j + 1] = panelOrder[j];
			j--;
		}

		panelNames[j + 1] = movingName;
		panelOrder[j + 1] = movingOrder;
	}

	for (int i = 0; i < drawCount; i++) {
		string panelName = panelNames[i];
		vector panelSize;
		vector panelPos = VGui_PanelRect(parentPath, panelName, parentPos, parentSize, panelSize);
		string controlName = strtolower(VGui_Key(parentPath, panelName, "controlname"));
		float panelAlpha = parentAlpha;
		string alphaText = VGui_Key(parentPath, panelName, "alpha");

		if (STRING_SET(alphaText)) {
			panelAlpha *= stof(alphaText) / 255;
		}

		/* off-screen panels (TF2 HUDs park unused ones at 9999) */
		if (panelPos[0] > g_vgScreenMins[0] + g_vgScreenSize[0] || panelPos[1] > g_vgScreenMins[1] + g_vgScreenSize[1]) {
			continue;
		}

		if (panelPos[0] + panelSize[0] < g_vgScreenMins[0] || panelPos[1] + panelSize[1] < g_vgScreenMins[1]) {
			continue;
		}

		/* background colour */
		string bgText = VGui_Key(parentPath, panelName, "bgcolor_override");

		if (STRING_SET(bgText) && stof(VGui_Key(parentPath, panelName, "paintbackground")) != 0) {
			float bgAlpha;
			vector bgColor = VGui_Color(bgText, bgAlpha);
			drawfill(panelPos, panelSize, bgColor, bgAlpha * panelAlpha, DRAWFLAG_NORMAL);
		}

		if (strstrofs(controlName, "label") >= 0) {
			VGui_DrawLabel(parentPath, panelName, panelPos, panelSize, panelAlpha);
		} else {
			string borderName = VGui_Key(parentPath, panelName, "border");

			if (STRING_SET(borderName)) {
				VGui_DrawBorder(borderName, panelPos, panelSize);
			}

			/* ImagePanel, CTFImagePanel, CTFClassImage, ... */
			if (strstrofs(controlName, "image") >= 0) {
				string fillText = VGui_Key(parentPath, panelName, "fillcolor");

				if (STRING_SET(fillText)) {
					float fillAlpha;
					vector fillColor = VGui_Color(fillText, fillAlpha);
					drawfill(panelPos, panelSize, fillColor, fillAlpha * panelAlpha, DRAWFLAG_NORMAL);
				}

				float imageAlpha;
				vector imageColor = VGui_Color(VGui_Key(parentPath, panelName, "drawcolor"), imageAlpha);
				string imageName = VGui_Key(parentPath, panelName, "image");
				string teamImage = VGui_Key(parentPath, panelName, sprintf("teambg_%d", g_vgTeam));

				if (STRING_SET(teamImage)) {
					imageName = teamImage;
				}

				VGui_DrawImage(imageName, panelPos, panelSize, imageColor, imageAlpha * panelAlpha);
			}
		}

		VGui_DrawChildren(sprintf("%s/%s", parentPath, panelName), panelPos, panelSize, panelAlpha);
	}
}

/** Draws every visible panel of an element. */
void
VGui_DrawElement(string elementName, float elementAlpha)
{
	if (!VGui_IsShown("hudlayout", elementName)) {
		return;
	}

	vector elementSize;
	vector elementPos = VGui_ElementRect(elementName, elementSize);
	VGui_DrawChildren(elementName, elementPos, elementSize, elementAlpha);
}
