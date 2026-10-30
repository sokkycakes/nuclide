// Co-op menu: the title menu and, in a game, the pause menu. Pages are
// built here from plain Panels, Buttons and Labels. The menu progs
// (coop/src/menu/main.qc) answers "maps", "binds", "servers" and "roster";
// cvars are read through the bridge and commands go out with Bulwark.Cmd.
// The Hero page asks the progs for a 3D preview ("preview"), drawn under
// this view in the see-through #HeroWindow.
var CoopMenu = ( function ()
{
	var stage = $( "#Stage" );
	var page = $( "#Page" );
	var body = $( "#PageBody" );
	var footer = $( "#PageFooter" );
	var inGame = false;
	var current = "";
	var keyHandler = null;	// the open page's own key handling
	var wheelHandler = null;

	// ---- helpers ---------------------------------------------------------

	function query( request )
	{
		try { return fte_query( request ); } catch ( e ) { return ""; }
	}
	function cvar( name ) { return query( "cvar:" + name ); }
	function cvarNum( name, fallback )
	{
		var v = parseFloat( cvar( name ) );
		return isNaN( v ) ? fallback : v;
	}
	function cmd( text ) { Bulwark.Cmd( text ); }
	function quote( s ) { return "\"" + String( s ).replace( /"/g, "'" ) + "\""; }

	function make( type, parent, cls, props )
	{
		props = props || {};
		if ( cls )
			props[ "class" ] = cls;
		return $.CreatePanel( type, parent, "", props );
	}
	function label( parent, cls, text )
	{
		return make( "Label", parent, cls, { text: text, hittest: "false" } );
	}
	function button( parent, cls, text, fn )
	{
		var b = make( "Button", parent, cls, { hittest: "true" } );
		label( b, "", text );
		b.SetPanelEvent( "onactivate", function ()
		{
			$.GetContextPanel().SetFocus();
			fn();
		} );
		return b;
	}
	function section( parent, text )
	{
		var s = make( "Panel", parent, "section", { hittest: "false" } );
		label( s, "", text );
		return s;
	}

	// ---- settings rows ---------------------------------------------------
	// Every row edits a pending value; Apply/OK writes them with seta.

	var pending = {};
	var restartVideo = false;

	function value( name, fallback )
	{
		if ( pending.hasOwnProperty( name ) )
			return pending[ name ];
		var v = cvar( name );
		return v === "" ? fallback : v;
	}
	function setPending( name, v, video )
	{
		pending[ name ] = String( v );
		if ( video )
			restartVideo = true;
	}

	function row( parent, name )
	{
		var r = make( "Panel", parent, "row", { hittest: "true" } );
		label( r, "row-name", name );
		return make( "Panel", r, "row-control", { hittest: "false" } );
	}

	// a value box with a fill bar and - / + steppers
	function sliderRow( parent, name, cvarName, min, max, step, fallback, format )
	{
		var ctl = row( parent, name );
		var minus = button( ctl, "btn small", "-", function () { change( -step ); } );
		var box = make( "Panel", ctl, "row-value", { hittest: "false" } );
		var bar = make( "Panel", box, "row-bar", { hittest: "false" } );
		var text = label( box, "", "" );
		var plus = button( ctl, "btn small", "+", function () { change( step ); } );

		function show()
		{
			var v = parseFloat( value( cvarName, fallback ) );
			if ( isNaN( v ) ) v = fallback;
			text.text = format ? format( v ) : String( Math.round( v * 100 ) / 100 );
			bar.style.width = Math.max( 0, Math.min( 100, ( v - min ) / ( max - min ) * 100 ) ) + "%";
		}
		function change( d )
		{
			var v = parseFloat( value( cvarName, fallback ) );
			if ( isNaN( v ) ) v = fallback;
			v = Math.round( ( v + d ) / step ) * step;
			v = Math.max( min, Math.min( max, v ) );
			setPending( cvarName, Math.round( v * 1000 ) / 1000 );
			show();
		}
		show();
	}

	// cycles through choices: [[value, "Label"], ...]
	function choiceRow( parent, name, cvarName, choices, fallback, video, onChange )
	{
		var ctl = row( parent, name );
		var box;
		var text;
		button( ctl, "btn small", "<", function () { step( -1 ); } );
		box = make( "Panel", ctl, "row-value", { hittest: "false" } );
		text = label( box, "", "" );
		button( ctl, "btn small", ">", function () { step( 1 ); } );

		function index()
		{
			var v = value( cvarName, fallback );
			for ( var i = 0; i < choices.length; i++ )
				if ( String( choices[ i ][ 0 ] ) === String( v ) )
					return i;
			return -1;
		}
		function show()
		{
			var i = index();
			text.text = i >= 0 ? choices[ i ][ 1 ] : String( value( cvarName, fallback ) );
		}
		function step( d )
		{
			var i = index();
			i = ( i < 0 ? 0 : i + d + choices.length ) % choices.length;
			setPending( cvarName, choices[ i ][ 0 ], video );
			if ( onChange )
				onChange( choices[ i ][ 0 ] );
			show();
		}
		show();
	}

	function toggleRow( parent, name, cvarName, fallback, onValue, offValue, video )
	{
		onValue = onValue === undefined ? "1" : onValue;
		offValue = offValue === undefined ? "0" : offValue;
		var ctl = row( parent, name );
		var box = make( "Button", ctl, "row-value", { hittest: "true" } );
		var text = label( box, "", "" );

		function isOn() { return String( value( cvarName, fallback ) ) === String( onValue ); }
		function show()
		{
			text.text = isOn() ? "On" : "Off";
			ctl.SetHasClass( "toggle-on", isOn() );
		}
		box.SetPanelEvent( "onactivate", function ()
		{
			$.GetContextPanel().SetFocus();
			setPending( cvarName, isOn() ? offValue : onValue, video );
			show();
		} );
		show();
	}

	function entryRow( parent, name, cvarName, maxchars )
	{
		var ctl = row( parent, name );
		var entry = make( "TextEntry", ctl, "entry", { text: value( cvarName, "" ), maxchars: String( maxchars || 32 ) } );
		return function () { return entry.text; };
	}

	function applyPending()
	{
		for ( var name in pending )
			cmd( "seta " + name + " " + quote( pending[ name ] ) );
		if ( restartVideo )
			cmd( "vid_restart" );
		cmd( "writeconfig" );
		pending = {};
		restartVideo = false;
	}

	// ---- lists with their own paging --------------------------------------

	function pagedList( parent, rowsShown, height )
	{
		var list = make( "Panel", parent, "list", { hittest: "false", style: "height: " + height + "px;" } );
		var pager = make( "Panel", parent, "list-pager", { hittest: "false" } );
		var info = label( pager, "", "" );
		var items = [];
		var first = 0;
		var draw = null;

		function render()
		{
			var count = items.filter( function ( it ) { return !it.divider; } ).length;
			list.RemoveAndDeleteChildren();
			if ( first > Math.max( 0, items.length - rowsShown ) )
				first = Math.max( 0, items.length - rowsShown );
			for ( var i = first; i < items.length && i < first + rowsShown; i++ )
				draw( list, items[ i ], i );
			info.text = items.length > rowsShown ?
				( first + 1 ) + "-" + Math.min( items.length, first + rowsShown ) + " of " + items.length + "   (mouse wheel scrolls)" :
				( count ? count + " shown" : "" );
		}
		return {
			Set: function ( newItems, drawFn ) { items = newItems; draw = drawFn; render(); },
			Scroll: function ( d ) { first = Math.max( 0, first + d ); render(); },
			Refresh: render,
			Items: function () { return items; }
		};
	}

	// ---- pages -------------------------------------------------------------

	function openPage( name, title )
	{
		heroPageOff();
		current = name;
		keyHandler = null;
		wheelHandler = null;
		body.RemoveAndDeleteChildren();
		footer.RemoveAndDeleteChildren();
		$( "#PageTitle" ).text = title;
		page.SetHasClass( "open", true );
		stage.SetHasClass( "paging", true );
		markButtons();
	}
	function closePage()
	{
		heroPageOff();
		current = "";
		keyHandler = null;
		wheelHandler = null;
		body.RemoveAndDeleteChildren();
		footer.RemoveAndDeleteChildren();
		page.SetHasClass( "open", false );
		stage.SetHasClass( "paging", false );
		pending = {};
		restartVideo = false;
		Bulwark.Send( "stopservers", "" );
		markButtons();
	}

	// Play: pick a map and the server's settings
	var mapList = null;
	var selectedMap = "";

	function playPage()
	{
		openPage( "play", "Start a co-op game" );
		var cols = make( "Panel", body, "columns", { hittest: "false" } );
		var left = make( "Panel", cols, "column", { hittest: "false", style: "width: 40%; margin-right: 3%;" } );
		var right = make( "Panel", cols, "column", { hittest: "false", style: "width: 57%;" } );

		section( left, "Map" );
		mapList = pagedList( left, 13, 13 * 40 + 2 );
		wheelHandler = function ( d ) { mapList.Scroll( d ); };
		selectedMap = value( "coop_lastmap", "coop_arena" );
		Bulwark.Send( "maps", "" );

		section( right, "Server" );
		var hostname = entryRow( right, "Server name", "hostname", 48 );
		sliderRow( right, "Max players", "maxplayers", 1, 64, 1, 32 );
		choiceRow( right, "Difficulty", "skill", [ [ "1", "Easy" ], [ "2", "Medium" ], [ "3", "Hard" ] ], "2" );
		section( right, "Rules" );
		toggleRow( right, "Survival (no respawns, revive only)", "coop_survival", "0" );
		toggleRow( right, "Monster waves", "coop_waves", "1" );
		sliderRow( right, "Respawn delay", "coop_respawnDelay", 0, 30, 1, 5, function ( v ) { return v + " s"; } );
		toggleRow( right, "XP mod (levels and skills)", "coop_plugins", "xpm", "xpm", "" );
		toggleRow( right, "Allow votes", "mp_allowvote", "1" );

		button( footer, "btn primary", "Start", function ()
		{
			if ( !selectedMap )
				return;
			pending[ "hostname" ] = hostname();
			pending[ "coop_lastmap" ] = selectedMap;
			// the co-op defaults first, then what was picked here on top
			cmd( "exec default_coop.cfg" );
			applyPending();
			cmd( "map " + selectedMap );
		} );
		button( footer, "btn", "Back", closePage );
	}

	function showMaps( maps )
	{
		if ( !mapList || current !== "play" )
			return;
		var items = [];
		if ( maps.coop.length )
			items.push( { divider: "Co-op maps" } );
		maps.coop.forEach( function ( m ) { items.push( { map: m } ); } );
		if ( maps.other.length )
			items.push( { divider: "Other maps" } );
		maps.other.forEach( function ( m ) { items.push( { map: m } ); } );
		mapList.Set( items, function ( list, item )
		{
			if ( item.divider )
			{
				var d = make( "Panel", list, "list-divider", { hittest: "false" } );
				label( d, "", item.divider );
				return;
			}
			var r = make( "Button", list, "list-row" + ( item.map === selectedMap ? " selected" : "" ), { hittest: "true" } );
			label( r, "", item.map );
			r.SetPanelEvent( "onactivate", function ()
			{
				$.GetContextPanel().SetFocus();
				selectedMap = item.map;
				mapList.Refresh();
			} );
		} );
	}

	// Hero: the hero and kit to play, saved for every server with heroes on
	var roster = null;

	// #HeroWindow, as fractions of the screen (menu.css .hero-window)
	var HERO_WINDOW = "0.715 0.12 0.225 0.76";

	function heroPageOff()
	{
		if ( current !== "hero" )
			return;
		stage.SetHasClass( "hero-open", false );
		Bulwark.Send( "preview", "" );
	}

	function heroPage()
	{
		openPage( "hero", "Hero" );
		stage.SetHasClass( "hero-open", true );
		var list = make( "Panel", body, "heroes-list title-heroes", { hittest: "false" } );
		var status = label( body, "status", "" );
		body.heroList = list;
		body.heroStatus = status;
		button( footer, "btn", "Back", closePage );
		Bulwark.Send( "roster", "" );
	}

	function showRoster( r )
	{
		roster = r;
		if ( current !== "hero" || !body.heroList )
			return;
		var list = body.heroList;
		var kits = r.items.filter( function ( it ) { return it.type === "kit"; } );
		var shown = kits.filter( function ( k ) { return k.def === r.picked; } )[ 0 ] || kits[ 0 ];
		list.RemoveAndDeleteChildren();

		r.items.filter( function ( it ) { return it.type === "hero"; } ).forEach( function ( h )
		{
			var card = make( "Panel", list, "hero", { hittest: "false" } );
			var head = make( "Panel", card, "hero-head", { hittest: "false" } );
			label( head, "hero-name", h.name );
			label( head, "hero-stats", ( h.role && h.role !== h.name ? h.role + "  ·  " : "" ) +
				h.health + " health  ·  speed " + h.speed );
			if ( h.desc )
				label( card, "hero-desc", h.desc );
			kits.filter( function ( k ) { return k.hero === h.id; } ).forEach( function ( k )
			{
				var picked = k.def === r.picked;
				var row = make( "Button", card, "skill kit" + ( picked ? " current" : "" ), { hittest: "true" } );
				var text = make( "Panel", row, "skill-text", { hittest: "false" } );
				label( text, "skill-name", k.name );
				label( text, "skill-desc", k.desc || "" );
				label( row, "kit-state", picked ? "Picked" : "" );
				row.SetPanelEvent( "onactivate", function ()
				{
					$.GetContextPanel().SetFocus();
					Bulwark.Send( "hero", k.def );
				} );
			} );
		} );

		body.heroStatus.text = r.picked && kits.some( function ( k ) { return k.def === r.picked; } ) ?
			"Saved for every server with heroes on." :
			"No hero picked: servers will ask.";
		if ( shown )
			Bulwark.Send( "preview", shown.def + " screen " + HERO_WINDOW + " backdrop" );
	}

	// Find servers: the LAN servers for this game, or an address
	var serverList = null;
	var selectedServer = "";

	function serversPage()
	{
		openPage( "servers", "Find servers" );
		section( body, "Servers on your network" );
		var head = make( "Panel", body, "list-head", { hittest: "false" } );
		label( head, "", "Name" ).style.width = "46%";
		label( head, "", "Map" ).style.width = "24%";
		label( head, "", "Players" ).style.width = "14%";
		label( head, "", "Ping" ).style.width = "10%";
		serverList = pagedList( body, 9, 9 * 40 + 2 );
		wheelHandler = function ( d ) { serverList.Scroll( d ); };
		serverList.Set( [], drawServer );
		var status = label( body, "status", "Looking for servers..." );
		section( body, "Join by address" );
		var address = entryRow( body, "Address (host:port)", "coop_lastaddress", 64 );

		button( footer, "btn primary", "Join", function ()
		{
			if ( selectedServer )
				cmd( "connect " + selectedServer );
		} );
		button( footer, "btn", "Join address", function ()
		{
			var a = address().trim();
			if ( !a )
				return;
			cmd( "seta coop_lastaddress " + quote( a ) );
			cmd( "connect " + a );
		} );
		button( footer, "btn", "Refresh", function ()
		{
			status.text = "Looking for servers...";
			Bulwark.Send( "servers", "" );
		} );
		button( footer, "btn", "Back", closePage );
		serverList.status = status;
		Bulwark.Send( "servers", "" );
	}

	function drawServer( list, s )
	{
		var r = make( "Button", list, "list-row" + ( s.address === selectedServer ? " selected" : "" ), { hittest: "true" } );
		label( r, "", s.name || s.address ).style.width = "46%";
		label( r, "", s.map ).style.width = "24%";
		label( r, "", s.players + " / " + s.max ).style.width = "14%";
		label( r, "", String( s.ping ) ).style.width = "10%";
		r.SetPanelEvent( "onactivate", function ()
		{
			$.GetContextPanel().SetFocus();
			if ( selectedServer === s.address )
				cmd( "connect " + s.address );	// a second click joins
			selectedServer = s.address;
			serverList.Refresh();
		} );
	}

	function showServers( servers )
	{
		if ( !serverList || current !== "servers" )
			return;
		serverList.Set( servers, drawServer );
		serverList.status.text = servers.length ? "" : "No servers found yet.";
	}

	// Options: Player, Video, Audio, Mouse, Keys
	var optionsTab = "player";
	var bindsList = null;
	var capture = null;	// the command waiting for a key
	var captureRelease = false;	// still waiting for the click that started it to let go

	var KEYS = [
		[ "+forward", "Move forward" ], [ "+back", "Move back" ], [ "+moveleft", "Strafe left" ],
		[ "+moveright", "Strafe right" ], [ "+jump", "Jump" ], [ "+duck", "Duck" ], [ "+speed", "Walk" ],
		[ "+use", "Use / revive" ], [ "+attack", "Fire" ], [ "+attack2", "Secondary fire" ],
		[ "+reload", "Reload" ], [ "impulse 100", "Flashlight" ], [ "lastinv", "Last weapon" ],
		[ "invnext", "Next weapon" ], [ "invprev", "Previous weapon" ], [ "slot1", "Weapon slot 1" ],
		[ "slot2", "Weapon slot 2" ], [ "slot3", "Weapon slot 3" ], [ "slot4", "Weapon slot 4" ],
		[ "slot5", "Weapon slot 5" ], [ "+showscores", "Scores" ], [ "messagemode", "Chat" ],
		[ "messagemode2", "Team chat" ], [ "cmd selectskills", "Skills" ], [ "cmd shop", "Shop and skills" ], [ "vote yes", "Vote yes" ],
		[ "vote no", "Vote no" ], [ "impulse 201", "Spray" ]
	];
	var binds = {};

	function optionsPage( tab )
	{
		optionsTab = tab || optionsTab;
		openPage( "options", "Options" );
		var tabs = make( "Panel", body, "tabs", { hittest: "false" } );
		[ [ "player", "Player" ], [ "video", "Video" ], [ "audio", "Audio" ], [ "mouse", "Mouse" ], [ "keys", "Keys" ] ]
			.forEach( function ( t )
			{
				var b = button( tabs, "tab" + ( t[ 0 ] === optionsTab ? " current" : "" ), t[ 1 ], function ()
				{
					optionsPage( t[ 0 ] );
				} );
			} );
		var area = make( "Panel", body, "column fill", { hittest: "false", style: "width: 100%;" } );

		if ( optionsTab === "player" )
		{
			var name = entryRow( area, "Name", "name", 32 );
			sliderRow( area, "Field of view", "fov", 70, 120, 1, 90 );
			toggleRow( area, "Fast weapon switch", "hud_fastswitch", "0" );
			toggleRow( area, "Names over teammates", "cg_nameplates", "1" );
			toggleRow( area, "Name and health of who you aim at", "cg_targetID", "1" );
			toggleRow( area, "XP readout", "xpm_hud", "1" );
			toggleRow( area, "Always run", "cl_run", "1" );
			area.readName = name;
		}
		else if ( optionsTab === "video" )
		{
			var modes = [ "1024x768", "1280x720", "1280x1024", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160" ];
			var current = cvar( "vid_width" ) + "x" + cvar( "vid_height" );
			if ( modes.indexOf( current ) < 0 )
				modes.unshift( current );
			pending[ "coop_videomode" ] = pending[ "coop_videomode" ] || current;
			choiceRow( area, "Resolution", "coop_videomode", modes.map( function ( m ) { return [ m, m.replace( "x", " x " ) ]; } ),
				current, true );
			choiceRow( area, "Display", "vid_fullscreen", [ [ "0", "Window" ], [ "1", "Full screen" ], [ "2", "Full screen (desktop)" ] ], "0", true );
			toggleRow( area, "Vertical sync", "vid_vsync", "1" );
			toggleRow( area, "Windows-style font drawing (GDI)", "r_gdifont", "1" );
			label( area, "note", "Resolution and display changes restart the video when you apply them." );
		}
		else if ( optionsTab === "audio" )
		{
			var pct = function ( v ) { return Math.round( v * 100 ) + "%"; };
			sliderRow( area, "Effects volume", "volume", 0, 1, 0.05, 0.7, pct );
			sliderRow( area, "Music volume", "bgmvolume", 0, 1, 0.05, 0.5, pct );
		}
		else if ( optionsTab === "mouse" )
		{
			sliderRow( area, "Sensitivity", "sensitivity", 0.5, 20, 0.5, 3 );
			var pitch = cvarNum( "m_pitch", 0.022 );
			pending[ "coop_invertmouse" ] = pending[ "coop_invertmouse" ] || ( pitch < 0 ? "1" : "0" );
			toggleRow( area, "Invert mouse", "coop_invertmouse", "0" );
			toggleRow( area, "Mouse smoothing", "m_filter", "0" );
		}
		else if ( optionsTab === "keys" )
		{
			label( area, "note", "Click an action, then press a key or mouse button. Escape cancels, Backspace clears." );
			bindsList = pagedList( area, 10, 10 * 50 + 2 );
			wheelHandler = function ( d ) { bindsList.Scroll( d ); };
			drawBinds();
			Bulwark.Send( "binds", KEYS.map( function ( k ) { return "\"" + k[ 0 ] + "\""; } ).join( " " ) );
		}

		button( footer, "btn primary", "OK", function () { applyOptions( area ); closePage(); } );
		button( footer, "btn", "Apply", function () { applyOptions( area ); optionsPage( optionsTab ); } );
		button( footer, "btn", "Cancel", closePage );
	}

	function applyOptions( area )
	{
		if ( area.readName )
			pending[ "name" ] = area.readName();
		if ( pending.hasOwnProperty( "coop_videomode" ) )
		{
			var m = pending[ "coop_videomode" ].split( "x" );
			if ( m.length === 2 && ( m[ 0 ] !== cvar( "vid_width" ) || m[ 1 ] !== cvar( "vid_height" ) ) )
			{
				pending[ "vid_width" ] = m[ 0 ];
				pending[ "vid_height" ] = m[ 1 ];
				restartVideo = true;
			}
			delete pending[ "coop_videomode" ];
		}
		if ( pending.hasOwnProperty( "coop_invertmouse" ) )
		{
			var p = Math.abs( cvarNum( "m_pitch", 0.022 ) );
			pending[ "m_pitch" ] = String( pending[ "coop_invertmouse" ] === "1" ? -p : p );
			delete pending[ "coop_invertmouse" ];
		}
		applyPending();
	}

	function drawBinds()
	{
		bindsList.Set( KEYS, function ( list, k )
		{
			var r = make( "Button", list, "row" + ( capture === k[ 0 ] ? " capture" : "" ), { hittest: "true" } );
			label( r, "row-name", k[ 1 ] );
			var ctl = make( "Panel", r, "row-control", { hittest: "false" } );
			var box = make( "Panel", ctl, "row-value", { hittest: "false" } );
			var keys = ( binds[ k[ 0 ] ] || "" ).trim();
			label( box, "", capture === k[ 0 ] ? "Press a key..." : ( keys ? keys.toUpperCase().split( " " ).join( ", " ) : "-" ) );
			r.SetPanelEvent( "onactivate", function ()
			{
				$.GetContextPanel().SetFocus();
				capture = k[ 0 ];
				captureRelease = true;
				drawBinds();
			} );
		} );
	}

	function captureKey( e )
	{
		if ( !capture )
			return false;
		if ( captureRelease )
		{
			// the button that activated the row is not the key wanted
			if ( !e.down )
				captureRelease = false;
			return true;
		}
		if ( !e.down )
			return true;
		var command = capture;
		if ( e.key === "Escape" )
		{
			capture = null;
		}
		else if ( e.key === "Backspace" )
		{
			( binds[ command ] || "" ).trim().split( " " ).forEach( function ( k ) { if ( k ) cmd( "unbind " + k ); } );
			capture = null;
		}
		else if ( e.bind )
		{
			cmd( "bind " + e.bind + " " + quote( command ) );
			capture = null;
		}
		else
		{
			return true;
		}
		drawBinds();
		cmd( "writeconfig" );
		Bulwark.Send( "binds", KEYS.map( function ( k ) { return "\"" + k[ 0 ] + "\""; } ).join( " " ) );
		return true;
	}

	// Vote: what Nuclide's callvote takes
	function votePage()
	{
		openPage( "vote", "Call a vote" );
		section( body, "Difficulty" );
		var row1 = make( "Panel", body, "row", { hittest: "false" } );
		[ [ "1", "Easy" ], [ "2", "Medium" ], [ "3", "Hard" ] ].forEach( function ( s )
		{
			button( row1, "btn inline", s[ 1 ], function () { cmd( "callvote skill " + s[ 0 ] ); resume(); } );
		} );
		section( body, "Map" );
		var row2 = make( "Panel", body, "row", { hittest: "false" } );
		button( row2, "btn inline", "Restart this map", function () { cmd( "callvote map_restart 0" ); resume(); } );
		button( row2, "btn inline", "Next map", function () { cmd( "callvote nextmap 0" ); resume(); } );
		section( body, "Current vote" );
		var row3 = make( "Panel", body, "row", { hittest: "false" } );
		button( row3, "btn inline", "Vote yes", function () { cmd( "vote yes" ); resume(); } );
		button( row3, "btn inline", "Vote no", function () { cmd( "vote no" ); resume(); } );
		label( body, "note", "Votes need mp_allowvote on the server. Half the players must agree." );
		button( footer, "btn", "Back", closePage );
	}

	// ---- main buttons ------------------------------------------------------

	var mainButtons = [];

	function resume() { Bulwark.Send( "close", "" ); }

	function buildMain()
	{
		var list = $( "#MainButtons" );
		list.RemoveAndDeleteChildren();
		mainButtons = [];
		var items = inGame ?
			[ [ "", "Resume", resume ], [ "", "Shop and skills", function () { cmd( "cmd shop" ); } ], [ "vote", "Vote", votePage ], [ "options", "Options", function () { optionsPage(); } ],
			  [ "-" ], [ "", "Disconnect", function () { cmd( "disconnect" ); } ], [ "", "Quit", function () { cmd( "quit" ); } ] ] :
			[ [ "play", "Play", playPage ], [ "hero", "Hero", heroPage ], [ "servers", "Find servers", serversPage ], [ "options", "Options", function () { optionsPage(); } ],
			  [ "-" ], [ "", "Quit", function () { cmd( "quit" ); } ] ];
		items.forEach( function ( it )
		{
			if ( it[ 0 ] === "-" )
			{
				make( "Panel", list, "main-gap", { hittest: "false" } );
				return;
			}
			var b = button( list, "main-button", it[ 1 ], it[ 2 ] );
			b.pageName = it[ 0 ];
			mainButtons.push( b );
		} );
		markButtons();
	}

	function markButtons()
	{
		mainButtons.forEach( function ( b ) { b.SetHasClass( "current", b.pageName !== "" && b.pageName === current ); } );
	}

	// ---- events --------------------------------------------------------------

	Bulwark.On( "context", function ( c )
	{
		inGame = !!( c && c.ingame );
		stage.SetHasClass( "ingame", inGame );
		closePage();
		buildMain();
	} );
	Bulwark.On( "maps", showMaps );
	Bulwark.On( "servers", showServers );
	Bulwark.On( "roster", showRoster );
	Bulwark.On( "binds", function ( b )
	{
		binds = b || {};
		if ( bindsList && current === "options" && optionsTab === "keys" )
			drawBinds();
	} );
	Bulwark.On( "key", function ( e )
	{
		if ( !e )
			return;
		if ( captureKey( e ) )
			return;
		if ( !e.down )
			return;
		if ( e.key === "WheelUp" && wheelHandler )
			wheelHandler( -3 );
		else if ( e.key === "WheelDown" && wheelHandler )
			wheelHandler( 3 );
		else if ( e.key === "Escape" )
		{
			if ( current )
				closePage();
			else if ( inGame )
				resume();
		}
	} );

	buildMain();

	return {};
} )();
