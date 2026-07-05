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
 */

int g_iLobbyDialogInitialized;
int g_iLobbyViewInitialized;

/* ---- Create dialog widgets ----------------------------------- */
static vguiWindow winLobbyCreate;
static vguiLabel lblCrtHostname;
static vguiTextBox txbCrtHostname;
static vguiLabel lblCrtMaxplayers;
static vguiTextBox txbCrtMaxplayers;
static vguiButton btnCrtCreate;
static vguiButton btnCrtCancel;

/* ---- Lobby view widgets -------------------------------------- */
static vguiWindow winLobbyView;
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
	winLobbyView.Hide();
}

/* ---- Refresh lobby label text from cvars --------------------- */

void UI_LobbyView_Update ( void )
{
	if (!g_iLobbyViewInitialized)
		return;
	if (cvar("lobby_player_count") <= 0)
	{
		winLobbyView.Hide();
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

/* ---- Show the lobby view ------------------------------------- */

void UI_LobbyView_Show ( void )
{
	if (!g_iLobbyViewInitialized)
	{
		g_iLobbyViewInitialized = TRUE;

		winLobbyView = spawn( vguiWindow );
		winLobbyView.SetTitle( "Pregame Lobby" );
		winLobbyView.SetSize( '380 380' );

		lblLbRoomCode = spawn( vguiLabel );
		lblLbRoomCode.SetPos( '20 32' );
		lblLbRoomCode.SetTitle( "Room: ---" );

		lblLbHost = spawn( vguiLabel );
		lblLbHost.SetPos( '20 52' );
		lblLbHost.SetTitle( "Host: ---" );

		lblLbState = spawn( vguiLabel );
		lblLbState.SetPos( '20 72' );
		lblLbState.SetTitle( "" );

		lblLbCount = spawn( vguiLabel );
		lblLbCount.SetPos( '20 92' );
		lblLbCount.SetTitle( "Players: 0 / 0" );

		lblLbP1 = spawn( vguiLabel );
		lblLbP1.SetPos( '20 120' );
		lblLbP1.SetTitle( "" );

		lblLbP2 = spawn( vguiLabel );
		lblLbP2.SetPos( '20 140' );
		lblLbP2.SetTitle( "" );

		lblLbP3 = spawn( vguiLabel );
		lblLbP3.SetPos( '20 160' );
		lblLbP3.SetTitle( "" );

		lblLbP4 = spawn( vguiLabel );
		lblLbP4.SetPos( '20 180' );
		lblLbP4.SetTitle( "" );

		btnLbReady = spawn( vguiButton );
		btnLbReady.SetTitle( "Ready" );
		btnLbReady.SetSize( '100 24' );
		btnLbReady.SetPos( '20 220' );
		btnLbReady.SetFunc( LobbyView_Ready );

		btnLbStart = spawn( vguiButton );
		btnLbStart.SetTitle( "Start Game" );
		btnLbStart.SetSize( '100 24' );
		btnLbStart.SetPos( '140 220' );
		btnLbStart.SetFunc( LobbyView_Start );

		btnLbLeave = spawn( vguiButton );
		btnLbLeave.SetTitle( "Leave Lobby" );
		btnLbLeave.SetSize( '100 24' );
		btnLbLeave.SetPos( '260 220' );
		btnLbLeave.SetFunc( LobbyView_Leave );

		g_uiDesktop.Add( winLobbyView );
		winLobbyView.Add( lblLbRoomCode );
		winLobbyView.Add( lblLbHost );
		winLobbyView.Add( lblLbState );
		winLobbyView.Add( lblLbCount );
		winLobbyView.Add( lblLbP1 );
		winLobbyView.Add( lblLbP2 );
		winLobbyView.Add( lblLbP3 );
		winLobbyView.Add( lblLbP4 );
		winLobbyView.Add( btnLbReady );
		winLobbyView.Add( btnLbStart );
		winLobbyView.Add( btnLbLeave );
	}

	UI_LobbyView_Update();
	winLobbyView.Show();
	winLobbyView.SetPos( ( g_vidsize / 2 ) - ( winLobbyView.GetSize() / 2 ) );
}

/* ---- Create dialog callbacks --------------------------------- */

static void LobbyDialog_Create ( void )
{
	string hostName = txbCrtHostname.GetText();
	int maxPlayers = (int)max(stof(txbCrtMaxplayers.GetText()), 2);

	localcmd(sprintf("set hostname %s\n", hostName));
	localcmd(sprintf("set lobby_maxplayers %i\n", maxPlayers));
	localcmd("set sv_background 1\n");
	localcmd("set lobby_defaultmap background01\n");
	localcmd("lobby_create_lan\n");

	winLobbyCreate.Hide();
	UI_LobbyView_Show();
}

static void LobbyDialog_Cancel ( void )
{
	winLobbyCreate.Hide();
}

/* ---- Show the create dialog ---------------------------------- */

void UI_Lobby_Show ( void )
{
	if ( !g_iLobbyDialogInitialized )
	{
		g_iLobbyDialogInitialized = TRUE;
		winLobbyCreate = spawn( vguiWindow );
		winLobbyCreate.SetTitle( "Create Lobby" );
		winLobbyCreate.SetSize( '338 200' );
		winLobbyCreate.SetIcon( "gfx/icon16/group_add" );

		lblCrtHostname = spawn( vguiLabel );
		lblCrtHostname.SetPos( '20 32' );
		lblCrtHostname.SetTitle( "Server name" );

		txbCrtHostname = spawn( vguiTextBox );
		txbCrtHostname.SetPos( [ 20, 50 ] );
		txbCrtHostname.SetSize( [ 124, 24 ] );
		txbCrtHostname.SetText( cvar_string( "hostname" ) );

		lblCrtMaxplayers = spawn( vguiLabel );
		lblCrtMaxplayers.SetPos( '20 84' );
		lblCrtMaxplayers.SetTitle( "Max players" );

		txbCrtMaxplayers = spawn( vguiTextBox );
		txbCrtMaxplayers.SetPos( [ 20, 102 ] );
		txbCrtMaxplayers.SetSize( [ 124, 24 ] );
		txbCrtMaxplayers.SetText( "8" );

		btnCrtCreate = spawn( vguiButton );
		btnCrtCreate.SetTitle( "Create" );
		btnCrtCreate.SetSize( '80 24' );
		btnCrtCreate.SetPos( winLobbyCreate.GetSize() - '168 32' );
		btnCrtCreate.SetFunc( LobbyDialog_Create );

		btnCrtCancel = spawn( vguiButton );
		btnCrtCancel.SetTitle( "Cancel" );
		btnCrtCancel.SetSize( '80 24' );
		btnCrtCancel.SetPos( winLobbyCreate.GetSize() - '80 32' );
		btnCrtCancel.SetFunc( LobbyDialog_Cancel );

		g_uiDesktop.Add( winLobbyCreate );
		winLobbyCreate.Add( lblCrtHostname );
		winLobbyCreate.Add( txbCrtHostname );
		winLobbyCreate.Add( lblCrtMaxplayers );
		winLobbyCreate.Add( txbCrtMaxplayers );
		winLobbyCreate.Add( btnCrtCreate );
		winLobbyCreate.Add( btnCrtCancel );
	}

	winLobbyCreate.Show();
	winLobbyCreate.SetPos( ( g_vidsize / 2 ) - ( winLobbyCreate.GetSize() / 2 ) );
}
