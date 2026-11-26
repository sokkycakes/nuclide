/*
 * Copyright (c) 2016-2020 Marco Cawthorne <marco@icculus.org>
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

static string g_classDescrScout;
static string g_classDescrSniper;
static string g_classDescrSoldier;
static string g_classDescrDemoman;
static string g_classDescrMedic;
static string g_classDescrHWGuy;
static string g_classDescrPyro;
static string g_classDescrSpy;
static string g_classDescrEngineer;
static string g_classDescrRandomPC;

static void
TFCClass_Init(void)
{
	g_classDescrScout = textfile_to_string("classes/short_scout.txt");
	g_classDescrSniper = textfile_to_string("classes/short_sniper.txt");
	g_classDescrSoldier = textfile_to_string("classes/short_soldier.txt");
	g_classDescrDemoman = textfile_to_string("classes/short_demoman.txt");
	g_classDescrMedic = textfile_to_string("classes/short_medic.txt");
	g_classDescrHWGuy = textfile_to_string("classes/short_hwguy.txt");
	g_classDescrPyro = textfile_to_string("classes/short_pyro.txt");
	g_classDescrSpy = textfile_to_string("classes/short_spy.txt");
	g_classDescrEngineer = textfile_to_string("classes/short_engineer.txt");
	g_classDescrRandomPC = textfile_to_string("classes/short_randompc.txt");
}

/* Friendly display names for the Stiletto roster. Falls back to the title
 * system (then the raw id) for any class without an entry here. */
static string
Hero_DisplayName(string heroID)
{
	if (heroID == "hero_collier") {
		return ("Collier");
	} else if (heroID == "hero_beaumont") {
		return ("Beaumont");
	} else if (heroID == "hero_vagrant") {
		return ("Vagrant");
	} else if (heroID == "hero_skipstream") {
		return ("Skipstream");
	} else if (heroID == "hero_angel") {
		return ("Angel");
	} else if (heroID == "hero_motionblue") {
		return ("Motionblue");
	} else if (heroID == "hero_archstiletto") {
		return ("Archstiletto");
	} else if (heroID == "hero_juliet") {
		return ("Juliet");
	}

	return (Titles_GetTextBody(heroID));
}

/* the hero's portrait, or "" when the game ships none: a portrait at
 * gfx/ui/<hero id>/portrait wins, then the classic per-model picture
 * models/player/<hero id>/<hero id> */
static string
Hero_PreviewImage(string heroID)
{
	string candidates[2];

	candidates[0] = strcat("gfx/ui/", heroID, "/portrait");
	candidates[1] = strcat("models/player/", heroID, "/", heroID);

	for (int i = 0; i < 2; i++) {
		vector imgSize = drawgetimagesize(candidates[i]);

		if (imgSize[0] > 0 && imgSize[1] > 0) {
			return (candidates[i]);
		}
	}

	return ("");
}

/* the hero's one-paragraph description from titles.txt
 * (ClassDescription_<hero id>); nothing rather than the raw key when an
 * entry is missing */
static string
Hero_Description(string heroID)
{
	string key = strtoupper(strcat("ClassDescription_", heroID));
	string text = Titles_GetTextBody(key);

	if (text == key) {
		return ("");
	}

	return (text);
}

static int g_classMenuTeam;
static vguiWindow winClassSelection;
static vguiPic imgClassPreview;
static vguiLabel lblClassTitle;
static vguiLabel lblClassDescription;
static vguiLabel lblClassCounter;

class VGUIChangeClassButton:vguiButton
{
	void VGUIChangeClassButton(void);

	virtual void OnMouseUp(void);
	virtual void OnMouseEntered(void);
};

void
VGUIChangeClassButton::VGUIChangeClassButton(void)
{
}

void
VGUIChangeClassButton::OnMouseUp(void)
{
	int classSelection = GetTag();
	int teamID = g_classMenuTeam;

	if (teamID <= 0i) {
		teamID = player.GetTeam();
	}

	string heroID = teams.ClassForIndex(teamID, classSelection);

	/* server-authoritative hero pick, validated in CodeCallback_ClientCommand */
	localcmd(sprintf("cmd selecthero %s\n", heroID));
	winClassSelection.Hide();
}

void
VGUIChangeClassButton::OnMouseEntered(void)
{
	int classSelection = GetTag();
	int teamID = g_classMenuTeam;

	if (teamID <= 0i) {
		teamID = player.GetTeam();
	}

	string heroID = teams.ClassForIndex(teamID, classSelection);

	string preview = Hero_PreviewImage(heroID);
	float textX = 338;

	/* no picture for this hero: hide the frame and let the text use
	 * the space instead of leaving an empty box */
	if (preview == "") {
		imgClassPreview.Hide();
		textX = 190;
	} else {
		imgClassPreview.SetImage(preview);
		imgClassPreview.SetSize([140,182]);
		imgClassPreview.Show();
	}

	lblClassTitle.SetPos([textX, 90]);
	lblClassCounter.SetPos([textX, 90 + 32]);
	lblClassDescription.SetPos([textX, 90 + 32 + 32]);
	lblClassDescription.SetSize([588 - textX, 240]);

	lblClassTitle.SetTitle(Hero_DisplayName(heroID));
	lblClassDescription.SetTitle(Hero_Description(heroID));
}

void
VGUI_ShowClassSelectionMenu(int wishTeam)
{
	if (wishTeam <= 0i && teams.TotalClasses(1) > 0i) {
		wishTeam = 1i;
	}

	g_classMenuTeam = wishTeam;

	static int initialized;
	static VGUIChangeClassButton *btns;
	static vguiLabel lblSelectClass;
	static vguiFrame frmClassInfo;

	if (!initialized) {
		vector btnpos = [40,80];
		initialized = TRUE;

		TFCClass_Init();

		winClassSelection = spawn(vguiWindow);
		winClassSelection.SetSize([640, 480]);
		winClassSelection.SetStyleMask(vguiWindowBorderless | vguiWindowFullscreen);

		lblSelectClass = spawn(vguiLabel);
		lblSelectClass.SetTitle("SELECT YOUR HERO");
		lblSelectClass.SetTextSize(19);
		lblSelectClass.SetPos([40, 38]);
		lblSelectClass.SetSize([400, 24]);

		frmClassInfo = spawn(vguiFrame);
		frmClassInfo.SetPos([176, 80]);
		frmClassInfo.SetSize([424, 312]);

		imgClassPreview = spawn(vguiPic);
		imgClassPreview.SetPos([190, 90]);

		lblClassTitle = spawn(vguiLabel);
		lblClassTitle.SetPos([338, 90]);
		lblClassTitle.SetTextSize(19);
		lblClassTitle.SetSize([320, 24]);

		lblClassCounter = spawn(vguiLabel);
		lblClassCounter.SetPos([338, 90 + 32]);
		lblClassCounter.SetSize([320, 18]);

		lblClassDescription = spawn(vguiLabel);
		lblClassDescription.SetPos([338, 90 + 32 + 32]);
		lblClassDescription.SetSize([250, 240]);

		g_uiDesktop.Add(winClassSelection);
		winClassSelection.Add(lblSelectClass);
		winClassSelection.Add(frmClassInfo);
		winClassSelection.Add(imgClassPreview);
		imgClassPreview.Hide();
		winClassSelection.Add(lblClassTitle);
		winClassSelection.Add(lblClassCounter);
		winClassSelection.Add(lblClassDescription);

		int classCount = teams.TotalClasses(wishTeam);
		btns = memalloc(sizeof(VGUIChangeClassButton) * classCount);
		for (int i = 0; i < classCount; i++) {
			btns[i] = spawn(VGUIChangeClassButton);
			btns[i].SetTitle(Hero_DisplayName(teams.ClassForIndex(wishTeam, i)));
			btns[i].SetSize([124, 24]);
			btns[i].SetPos(btnpos);
			btns[i].SetTag(i);

			if (i == 9) {
				btns[i].SetKeyEquivalent("0");
			} else {
				btns[i].SetKeyEquivalent(ftos((float)i+1));
			}

			winClassSelection.Add(btns[i]);
			btnpos[1] += 32;
		}
	}

	winClassSelection.Show();
	winClassSelection.SetPos((g_vidsize / 2) - (winClassSelection.GetSize() / 2));
}
