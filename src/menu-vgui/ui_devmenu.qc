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

/* Scratch panel for launching work-in-progress mod tooling: other vgui
 * panels and quick property toggles. This is intentionally a dumping ground
 * for dev menus -- add new launchers/toggles in UI_DevMenu_Show() below. */

int g_iDevMenuInitialized;

void UI_DevMenu_Show ( void )
{
	static vguiWindow winDevMenu;

	/* running cursor used to stack entries from the top down */
	static float flItemY;

	/* spawn a launcher button that calls a menu function */
	static vguiButton DevMenu_AddFunc ( string strTitle, string strIcon, void(void) func ) {
		vguiButton btn = spawn( vguiButton );
		btn.SetTitle( strTitle );
		btn.SetSize( '212 24' );
		btn.SetPos( [ 8, flItemY ] );
		btn.SetIcon( strIcon );
		btn.SetFunc( func );
		winDevMenu.Add( btn );
		flItemY += 26;
		return btn;
	}

	/* spawn a button that runs a console command */
	static vguiButton DevMenu_AddExec ( string strTitle, string strIcon, string strCmd ) {
		vguiButton btn = spawn( vguiButton );
		btn.SetTitle( strTitle );
		btn.SetSize( '212 24' );
		btn.SetPos( [ 8, flItemY ] );
		btn.SetIcon( strIcon );
		btn.SetExec( strCmd );
		winDevMenu.Add( btn );
		flItemY += 26;
		return btn;
	}

	/* add a section label and advance the cursor */
	static vguiLabel DevMenu_AddHeading ( string strTitle ) {
		vguiLabel lbl = spawn( vguiLabel );
		lbl.SetTitle( strTitle );
		lbl.SetSize( '212 16' );
		lbl.SetPos( [ 8, flItemY ] );
		lbl.SetAlignment( AF_LEFT );
		winDevMenu.Add( lbl );
		flItemY += 20;
		return lbl;
	}

	if ( !g_iDevMenuInitialized ) {
		g_iDevMenuInitialized = TRUE;

		winDevMenu = spawn( vguiWindow );
		winDevMenu.SetTitle( "Dev Menu (WIP)" );
		winDevMenu.SetIcon( "gfx/icon16/wrench" );
		winDevMenu.SetStyleMask( vguiWindowStyleDefault );
		g_uiDesktop.Add( winDevMenu );

		flItemY = 32;

		/* ---- WIP vgui panels --------------------------------------- */
		DevMenu_AddHeading( "WIP Panels" );
		DevMenu_AddFunc( "Model Viewer", "gfx/icon16/images", UI_ModelViewer_Show );

		/* ---- Quick dev toggles / properties ------------------------ */
		DevMenu_AddHeading( "Dev Toggles" );
		DevMenu_AddExec( "Toggle Developer", "gfx/icon16/bug", "toggle developer" );
		DevMenu_AddExec( "Toggle noclip", "gfx/icon16/arrow_out", "noclip" );
		DevMenu_AddExec( "Toggle god mode", "gfx/icon16/shield", "god" );
		DevMenu_AddExec( "Toggle notarget", "gfx/icon16/user_gray", "notarget" );
		DevMenu_AddExec( "Reload Mod Menu", "gfx/icon16/arrow_refresh", "menu_restart" );

		/* size the window to fit the entries we added */
		winDevMenu.SetSize( [ 228, flItemY + 8 ] );
	}

	winDevMenu.Show();
	winDevMenu.SetPos( ( g_vidsize / 2 ) - ( winDevMenu.GetSize() / 2 ) );
}
