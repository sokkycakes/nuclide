/*
 * Copyright (c) 2026 Vera Visions LLC.
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

/* Observer target list (toggle).

   A lightweight VGUI window listing every connected player; picking a row
   asks the server to make the local spectator chase that player. Target
   switching reuses the already-networked spectator target field via the
   existing client-command channel ("cmd specTarget <entnum>" -> handled in
   src/server/cmd_cl.qc) so no new protocol/netcode is introduced.

   Modeled on src/client/vgui_playerlist.qc but trimmed down: no 3D model
   viewer, just the scrollable name list. Player slot index i maps to edict
   i + 1 (edicts 1..sv_playerslots are the player clients). */

bool g_iObserverListInitialized;

static bool
VGUI_Observers_IsValidTarget(int slotIndex)
{
	string playerName = getplayerkeyvalue(slotIndex, "name");

	if (!STRING_SET(playerName)) {
		return false;
	}

	entity target = findfloat(world, ::entnum, slotIndex + 1);

	if (target) {
		return Spectator_IsValidChaseTarget(pSeat->m_ePlayer, target);
	}

	/* entity not replicated yet — fall back to userinfo spectator markers */
	if (getplayerkeyfloat(slotIndex, "*spec")) {
		return false;
	}

	if (getplayerkeyfloat(slotIndex, "*spectator")) {
		return false;
	}

	if ((int)getplayerkeyfloat(slotIndex, "*team") == TEAM_SPECTATOR) {
		return false;
	}

	return true;
}

void
VGUI_Observers(void)
{
	static vguiWindow winObservers;
	static vguiList lstObservers;
	static vguiScrollBar scrlObservers;

	static void VGUI_Observers_ScrollUpdate(void) {
		scrlObservers.SetValue(lstObservers.GetOffset());
	}

	static void VGUI_Observers_ListUpdate(void) {
		lstObservers.SetOffset(scrlObservers.GetValue(), FALSE);
	}

	/* a row was picked: ask the server to chase that player */
	static void VGUI_Observers_SelectionChanged(void) {
		int selectedEntry = lstObservers.GetSelected();

		if (selectedEntry < 0) {
			return;
		}

		/* skip empty slots and non-playable targets */
		if (!VGUI_Observers_IsValidTarget(selectedEntry)) {
			return;
		}

		/* edict number for player slot N is N + 1 */
		localcmd(sprintf("cmd specTarget %i\n", selectedEntry + 1i));
	}

	static void VGUI_Observers_Resize(void) {
		vector vWinSize = winObservers.GetSize();
		lstObservers.SetPos([6, 32]);
		lstObservers.SetSize([vWinSize[0] - 12 - 16, vWinSize[1] - 52]);
		scrlObservers.SetPos(lstObservers.GetPos() + [lstObservers.GetSize()[0], 0]);
		scrlObservers.SetLength(lstObservers.GetSize()[1]);
		scrlObservers.SetMax(lstObservers.GetMaxVisibleItems());
	}

	if (!g_iObserverListInitialized) {
		g_iObserverListInitialized = true;

		winObservers = spawn(vguiWindow);
		winObservers.SetTitle("Observe Player");
		winObservers.SetSize([280, 390]);
		winObservers.SetMinSize([220, 200]);
		winObservers.SetMaxSize([9999, 9999]);
		winObservers.SetStyleMask(vguiWindowStyleDefault | vguiWindowResizeable);
		winObservers.SetPos([64, 64]);
		winObservers.SetIcon("gfx/icon16/user");
		winObservers.CallOnResize(VGUI_Observers_Resize);

		lstObservers = spawn(vguiList);
		lstObservers.SetItemCount(serverinfo.GetInteger("sv_playerslots"));
		lstObservers.CallOnScroll(VGUI_Observers_ScrollUpdate);
		lstObservers.CallOnSelectionChanged(VGUI_Observers_SelectionChanged);

		for (int i = 0i; i < serverinfo.GetInteger("sv_playerslots"); i++) {
			lstObservers.AddItem(getplayerkeyvalue(i, "name"));
		}

		scrlObservers = spawn(vguiScrollBar);
		scrlObservers.SetMin(0);
		scrlObservers.SetStep(1);
		scrlObservers.CallOnChange(VGUI_Observers_ListUpdate);

		VGUI_Observers_Resize();

		g_uiDesktop.Add(winObservers);
		winObservers.Add(lstObservers);
		winObservers.Add(scrlObservers);
	}

	/* refresh names each time the window opens */
	for (int i = 0i; i < serverinfo.GetInteger("sv_playerslots"); i++) {
		if (VGUI_Observers_IsValidTarget(i)) {
			lstObservers.m_strItems[i] = strdecolorize(getplayerkeyvalue(i, "name"));
		} else {
			lstObservers.m_strItems[i] = strcat("^8", localize("#EMPTY_PLAYERSLOT"));
		}
	}

	winObservers.Show();
}
