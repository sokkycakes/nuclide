// Title menu: keyboard, mouse and lobby dialog. Engine calls go through
// Bulwark.Cmd (console commands); keys arrive as Bulwark.On("key") events.
var TitleMenu = (function ()
{
	var COUNT = 4;
	var COMMANDS = [ "", "", "menu_options", "quit" ];
	var stage = $.GetContextPanel();
	var selected = 0;
	var dialog = "";

	function Select( index )
	{
		if ( dialog !== "" )
			return;
		if ( index < 0 ) index = 0;
		if ( index >= COUNT ) index = COUNT - 1;
		for ( var i = 1; i < COUNT; i++ )
			stage.SetHasClass( "TitleMenu-sel-" + i, i === index );
		selected = index;
	}

	function OpenDialog( kind )
	{
		dialog = kind;
		$( "#JoinTitle" ).text = kind === "create" ? "Create Lobby" : "Join Lobby";
		stage.SetHasClass( "join-open", true );
		stage.SetHasClass( "join-create", kind === "create" );
		stage.SetHasClass( "join-join", kind === "join" );
	}

	function CloseJoin()
	{
		dialog = "";
		stage.SetHasClass( "join-open", false );
		stage.SetHasClass( "join-create", false );
		stage.SetHasClass( "join-join", false );
	}

	function Activate( index )
	{
		if ( index !== undefined )
			Select( index );
		if ( selected === 0 )
			OpenDialog( "create" );
		else if ( selected === 1 )
			OpenDialog( "join" );
		else
			Bulwark.Cmd( COMMANDS[ selected ] );
	}

	function CreateLobby( online )
	{
		Bulwark.Cmd( online ? "lobby_create_online" : "lobby_create_lan" );
		CloseJoin();
	}

	function JoinAddress()
	{
		var address = $( "#JoinAddr" ).text.replace( /\s+/g, "" );
		if ( address !== "" )
			Bulwark.Cmd( "connect " + address );
		CloseJoin();
	}

	Bulwark.On( "key", function ( e )
	{
		if ( !e.down )
			return;
		if ( dialog !== "" )
		{
			if ( e.key === "Escape" )
				CloseJoin();
			return;
		}
		if ( e.key === "ArrowUp" || e.key === "w" || e.key === "WheelUp" )
			Select( selected - 1 );
		else if ( e.key === "ArrowDown" || e.key === "s" || e.key === "WheelDown" )
			Select( selected + 1 );
		else if ( e.key === "Enter" || e.key === " " )
			Activate();
	} );

	Select( 0 );
	return { Select: Select, Activate: Activate, CloseJoin: CloseJoin, CreateLobby: CreateLobby, JoinAddress: JoinAddress };
})();
