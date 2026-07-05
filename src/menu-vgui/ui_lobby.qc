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
 *
 * --- Pre-game lobby UI (menu level, backed by engine lobby_session.c)
 *
 * Uses the engine-native lobby system (lobby_create_lan etc.) so the host
 * stays in the menu --- no map loaded, no player spawned.  The lobby session
 * manages connected players; lobby_* cvars expose state to QC.
 *
 * Full-screen layout: replaces the main menu entirely while active. Backing
 * out returns to the main menu.
 */

int g_iLobbyViewInitialized;
int g_bLobbyShowPending;	/* set TRUE to show lobby view on next update */

/* Forward declarations */
void UI_LobbyView_Show(void);
void UI_LobbyView_Hide(void);
void Desktop_ShowMenu(float fShow);

/* ---- Lobby view widgets (full-screen, children of g_uiDesktop) --------- */
static vguiLabel lblLbRoomCode;
static vguiLabel lblLbHost;
static vguiLabel lblLbState;
static vguiLabel lblLbCount;
static vguiLabel lblLbP1;
static vguiLabel lblLbP2;
static vguiLabel lblLbP3;
static vguiLabel lblLbP4;
static vguiButton btnLbReady;
static vguiButton btnLbStart;
static vguiButton btnLbLeave;

/* ---- Lobby view callbacks ------------------------------------ */

static void LobbyView_Ready ( void )
{
	localcmd("lobby_ready\n");
}

static void LobbyView_Start ( void )
{
	localcmd("lobby_start\n");
}

static void LobbyView_Leave ( void )
{
	localcmd("lobby_close\n");
	UI_LobbyView_Hide();
}

/* ---- Refresh lobby label text from cvars --------------------- */

void UI_LobbyView_Update ( void )
{
	if (!g_iLobbyViewInitialized) {
		/* If a lobby show is pending and the lobby is now active, do it */
		if (g_bLobbyShowPending && cvar("lobby_player_count") > 0) {
			g_bLobbyShowPending = FALSE;
			UI_LobbyView_Show();
		}
		return;
	}
	if (cvar("lobby_player_count") <= 0)
	{
		UI_LobbyView_Hide();
		return;
	}

	lblLbRoomCode.SetTitle(sprintf("Room: %s", cvar_string("lobby_room_code")));
	lblLbHost.SetTitle(sprintf("Host: %s", cvar_string("lobby_host_name")));
	lblLbState.SetTitle(cvar_string("lobby_state_str"));
	lblLbCount.SetTitle(sprintf("Players: %i / %i",
		(int)cvar("lobby_player_count"),
		(int)cvar("lobby_max_players")));
	lblLbP1.SetTitle(cvar_string("lobby_player1_name"));
	lblLbP2.SetTitle(cvar_string("lobby_player2_name"));
	lblLbP3.SetTitle(cvar_string("lobby_player3_name"));
	lblLbP4.SetTitle(cvar_string("lobby_player4_name"));
}

/* ---- Show the lobby view (full-screen, replaces main menu) --- */

void UI_LobbyView_Show ( void )
{
	if (!g_iLobbyViewInitialized)
	{
		g_iLobbyViewInitialized = TRUE;

		/* ---- Background cover (fills screen behind labels) ----- */
		/* Using a themed approach — the background map renders below
		 * the VGUI layer, so the lobby text reads on top of it. */

		/* Room code */
		lblLbRoomCode = spawn( vguiLabel );
		lblLbRoomCode.SetPos( '20 40' );
		lblLbRoomCode.SetTitle( "Room: ---" );

		/* Host */
		lblLbHost = spawn( vguiLabel );
		lblLbHost.SetPos( '20 64' );
		lblLbHost.SetTitle( "Host: ---" );

		/* State */
		lblLbState = spawn( vguiLabel );
		lblLbState.SetPos( '20 88' );
		lblLbState.SetTitle( "" );

		/* Player count */
		lblLbCount = spawn( vguiLabel );
		lblLbCount.SetPos( '20 112' );
		lblLbCount.SetTitle( "Players: 0 / 0" );

		/* Player 1-4 */
		lblLbP1 = spawn( vguiLabel );
		lblLbP1.SetPos( '20 140' );
		lblLbP1.SetTitle( "" );

		lblLbP2 = spawn( vguiLabel );
		lblLbP2.SetPos( '20 164' );
		lblLbP2.SetTitle( "" );

		lblLbP3 = spawn( vguiLabel );
		lblLbP3.SetPos( '20 188' );
		lblLbP3.SetTitle( "" );

		lblLbP4 = spawn( vguiLabel );
		lblLbP4.SetPos( '20 212' );
		lblLbP4.SetTitle( "" );

		/* Ready button */
		btnLbReady = spawn( vguiButton );
		btnLbReady.SetTitle( "Ready" );
		btnLbReady.SetSize( '100 24' );
		btnLbReady.SetPos( '20 260' );
		btnLbReady.SetFunc( LobbyView_Ready );

		/* Start Game button */
		btnLbStart = spawn( vguiButton );
		btnLbStart.SetTitle( "Start Game" );
		btnLbStart.SetSize( '100 24' );
		btnLbStart.SetPos( '140 260' );
		btnLbStart.SetFunc( LobbyView_Start );

		/* Leave button */
		btnLbLeave = spawn( vguiButton );
		btnLbLeave.SetTitle( "Leave Lobby" );
		btnLbLeave.SetSize( '100 24' );
		btnLbLeave.SetPos( '260 260' );
		btnLbLeave.SetFunc( LobbyView_Leave );

		/* Add all widgets to the desktop */
		g_uiDesktop.Add( lblLbRoomCode );
		g_uiDesktop.Add( lblLbHost );
		g_uiDesktop.Add( lblLbState );
		g_uiDesktop.Add( lblLbCount );
		g_uiDesktop.Add( lblLbP1 );
		g_uiDesktop.Add( lblLbP2 );
		g_uiDesktop.Add( lblLbP3 );
		g_uiDesktop.Add( lblLbP4 );
		g_uiDesktop.Add( btnLbReady );
		g_uiDesktop.Add( btnLbStart );
		g_uiDesktop.Add( btnLbLeave );
	}

	/* Hide main menu buttons */
	Desktop_ShowMenu(FALSE);

	/* Show lobby view elements */
	lblLbRoomCode.Show();
	lblLbHost.Show();
	lblLbState.Show();
	lblLbCount.Show();
	lblLbP1.Show();
	lblLbP2.Show();
	lblLbP3.Show();
	lblLbP4.Show();
	btnLbReady.Show();
	btnLbStart.Show();
	btnLbLeave.Show();

	UI_LobbyView_Update();
}

/* ---- Hide the lobby view (return to main menu) --------------- */

void UI_LobbyView_Hide ( void )
{
	if (!g_iLobbyViewInitialized)
		return;

	/* Hide all lobby view elements */
	lblLbRoomCode.Hide();
	lblLbHost.Hide();
	lblLbState.Hide();
	lblLbCount.Hide();
	lblLbP1.Hide();
	lblLbP2.Hide();
	lblLbP3.Hide();
	lblLbP4.Hide();
	btnLbReady.Hide();
	btnLbStart.Hide();
	btnLbLeave.Hide();

	/* Show main menu buttons */
	Desktop_ShowMenu(TRUE);
}

/* ---- Create lobby with defaults and enter full-screen view --- */

void UI_Lobby_Show ( void )
{
	string hostName = cvar_string("name");
	int maxPlayers = 16;

	localcmd(sprintf("set hostname %s\n", hostName));
	localcmd(sprintf("set lobby_maxplayers %i\n", maxPlayers));
	localcmd("set sv_background 1\n");
	localcmd("set lobby_defaultmap background01\n");
	localcmd("lobby_create_lan\n");

	/* Lobby view spawns on the next frame via UI_LobbyView_Update once
	 * lobby_create_lan has executed and cvars are populated */
	g_bLobbyShowPending = TRUE;
}
