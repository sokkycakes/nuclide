// Justice Task Force in-game HUD. The co-op HUD progs (coop/src/hud/jtf.qc)
// posts "state" when anything shown changes, "feed" for each kill and
// "notice" for wave news. Panels are in layout/coop/hud.xml.
( function ()
{
	function $id( id ) { return $( "#" + id ); }
	function label( parent, cls, text )
	{
		return $.CreatePanel( "Label", parent, "", { "class": cls, text: text, hittest: "false" } );
	}
	function pct( v, max ) { return Math.max( 0, Math.min( 100, max > 0 ? 100 * v / max : 0 ) ) + "%"; }

	var last = {};

	// ---- button glyphs: Xelu's prompts (CC0, images/xelu) ---------------
	// an engine key name ("G", "MOUSE2", "GP_LSHOULDER") to its glyph image,
	// "" when there's none (the key's name is shown instead)
	var PAD_GLYPHS = {
		GP_A: "A", GP_B: "B", GP_X: "X", GP_Y: "Y", GP_LSHOULDER: "LB", GP_RSHOULDER: "RB",
		GP_LTRIGGER: "LT", GP_RTRIGGER: "RT", GP_LTHUMB: "Left_Stick_Click", GP_RTHUMB: "Right_Stick_Click",
		GP_START: "Menu", GP_MENU: "Menu", GP_BACK: "View", GP_VIEW: "View", GP_DPAD_UP: "Dpad_Up",
		GP_DPAD_DOWN: "Dpad_Down", GP_DPAD_LEFT: "Dpad_Left", GP_DPAD_RIGHT: "Dpad_Right"
	};
	var KEY_GLYPHS = {
		MOUSE1: "Mouse_Left", MOUSE2: "Mouse_Right", MOUSE3: "Mouse_Middle", SPACE: "Space", SHIFT: "Shift",
		LSHIFT: "Shift", RSHIFT: "Shift", CTRL: "Ctrl", LCTRL: "Ctrl", RCTRL: "Ctrl", ALT: "Alt", LALT: "Alt",
		RALT: "Alt", TAB: "Tab", ENTER: "Enter", ESCAPE: "Esc", BACKSPACE: "Backspace", UPARROW: "Arrow_Up",
		DOWNARROW: "Arrow_Down", LEFTARROW: "Arrow_Left", RIGHTARROW: "Arrow_Right", INS: "Insert", DEL: "Del",
		HOME: "Home", END: "End", PGUP: "Page_Up", PGDN: "Page_Down", CAPSLOCK: "Caps_Lock", TILDE: "Tilda",
		BACKQUOTE: "Tilda", SEMICOLON: "Semicolon", MINUS: "Minus", SLASH: "Slash", "[": "Bracket_Left",
		"]": "Bracket_Right", "'": "Quote", ";": "Semicolon", "-": "Minus", "/": "Slash", "`": "Tilda"
	};
	function glyph( key )
	{
		key = String( key || "" ).toUpperCase();
		if ( PAD_GLYPHS[ key ] )
			return "file://{images}/xelu/xbox/XboxSeriesX_" + PAD_GLYPHS[ key ] + ".png";
		var k = KEY_GLYPHS[ key ] || ( /^([A-Z0-9]|F[1-9]|F1[0-2])$/.test( key ) ? key : "" );
		return k ? "file://{images}/xelu/keyboard/" + k + "_Key_Dark.png" : "";
	}
	// a short label for a key with no glyph, so a long name such as
	// KP_DOWNARROW doesn't push the ability's name onto two lines
	// the keypad by its digits (the HUD font has no arrows)
	var SHORT = {
		END: "1", DOWNARROW: "2", PGDN: "3", LEFTARROW: "4", "5": "5", RIGHTARROW: "6", HOME: "7",
		UPARROW: "8", PGUP: "9", INS: "0", DEL: ".", ENTER: "Ent", SLASH: "/", STAR: "*", MINUS: "-", PLUS: "+"
	};
	function shortKey( key )
	{
		key = String( key || "" ).toUpperCase();
		var m = /^MOUSE(\d+)$/.exec( key );
		if ( m )
			return "M" + m[ 1 ];
		m = /^MWHEEL(UP|DOWN)$/.exec( key );
		if ( m )
			return m[ 1 ] === "UP" ? "WhU" : "WhD";
		m = /^KP_(.+)$/.exec( key );
		if ( m )
			return "KP" + ( SHORT[ m[ 1 ] ] || m[ 1 ] );
		m = /^GP_(.+)$/.exec( key );
		if ( m )
			return m[ 1 ];
		return key.length > 5 ? key.substr( 0, 4 ) : key;
	}
	// glyphs for "KEY" or a chord "KEY+KEY" into parent, or the text when a
	// key has no glyph
	function keyGlyphs( parent, cls, keys )
	{
		parent.RemoveAndDeleteChildren();
		String( keys || "" ).split( "+" ).forEach( function ( k )
		{
			if ( !k )
				return;
			var src = glyph( k );
			if ( src )
				$.CreatePanel( "Image", parent, "", { "class": cls + "-glyph", src: src, hittest: "false" } );
			else
				label( parent, cls + "-text", shortKey( k ) );
		} );
	}

	// ---- vitals --------------------------------------------------------

	function vitals( s )
	{
		$id( "HealthValue" ).text = String( s.hp );
		$id( "HealthReadout" ).SetHasClass( "low", s.hp < 25 );

		var hero = s.hero;
		var armor = $id( "ArmorBar" );
		var cap = hero ? hero.cap : 100;
		var ar = hero ? hero.barrier : s.ar;
		$id( "ArmorLabel" ).text = hero ? "Barrier" : "Armor";
		$id( "ArmorValue" ).text = hero ? ar + " / " + cap : String( ar );
		$id( "ArmorFill" ).style.width = pct( ar, cap );
		// a hero's Barrier is a blue number beside the health, shown only
		// while there is some; the bar is only for plain armour
		armor.SetHasClass( "hidden", !!hero || ar <= 0 );
		$id( "BarrierReadout" ).SetHasClass( "hidden", !hero || ar <= 0 );
		$id( "BarrierValue" ).text = String( ar );
		cadence( s );

		var energy = $id( "EnergyBar" );
		energy.SetHasClass( "hidden", !hero );
		if ( hero )
		{
			$id( "EnergyValue" ).text = hero.energy + " / " + hero.emax;
			$id( "EnergyFill" ).style.width = pct( hero.energy, hero.emax );
			// a tick at Engage's cost, once there's enough for it
			var canEngage = hero.ecost > 0 && hero.energy >= hero.ecost && !( hero.form > 0 );
			$id( "EngageTickRow" ).SetHasClass( "hidden", !canEngage );
			$id( "EngageTickGap" ).style.width = pct( hero.ecost, hero.emax );
		}
		abilities( hero );
	}

	// one row per part of the kit's status line: "[G] Courier ready"
	function abilities( hero )
	{
		var box = $id( "Abilities" );
		var keys = hero && hero.keys ? hero.keys : {};
		var key = hero ? hero.status + "\n" + hero.form + hero.formLine + JSON.stringify( keys ) : "";
		box.SetHasClass( "hidden", !hero );
		if ( key === last.abilities )
			return;
		last.abilities = key;
		box.RemoveAndDeleteChildren();
		if ( !hero )
			return;
		var parts = hero.status.split( /\s{2,}/ );
		var formFrom = parts.length;
		if ( hero.formLine )
			parts = parts.concat( hero.formLine.split( /\s{2,}/ ) );
		parts.forEach( function ( p, i )
		{
			p = p.trim();
			if ( !p )
				return;
			var m = /^\[(\w+)\]\s*(.*)$/.exec( p );
			var k = m ? m[ 1 ] : "", text = m ? m[ 2 ] : p, state = "";
			// passives (no key) aren't listed
			if ( !k )
				return;
			var w = /^(.*?)\s+(ready|used|\d+s|\d+\/\d+|\d+%|\d+)$/i.exec( text );
			if ( w )
			{
				text = w[ 1 ];
				state = w[ 2 ];
			}
			var row = $.CreatePanel( "Panel", box, "", { "class": "ability" } );
			var ready = /^ready$/i.test( state ), engaged = i >= formFrom && hero.form > 0;
			row.SetHasClass( "ready", ready );
			row.SetHasClass( "engaged", engaged );
			// a keyed ability that can't be used now (cooling down, used,
			// out of charges, not enough energy): greyed and darkened
			row.SetHasClass( "unavailable", !!k && !ready && !engaged && !/^[1-9]\d*\/\d+$/.test( state ) );
			// the letter in the status line is the keyboard default: show
			// what this player presses for it, as a glyph
			var keyBox = $.CreatePanel( "Panel", row, "", { "class": "ability-key", hittest: "false" } );
			keyGlyphs( keyBox, "ability-key", keys[ k ] || k );
			label( row, "ability-name", text );
			// ready shows as the corner triangle, not as text
			label( row, "ability-state", ready ? "" : state );
		} );
	}

	// ---- weapons -------------------------------------------------------

	function weapons( s )
	{
		var ammo = $id( "Ammo" );
		$id( "WeaponName" ).text = s.weapon || "";
		// the hero slots above already name a hero weapon in hand
		$id( "WeaponName" ).SetHasClass( "hidden", s.held > 0 );
		ammo.SetHasClass( "empty", !s.weapon );
		ammo.SetHasClass( "noclip", s.clipSize <= 0 );
		ammo.SetHasClass( "low", s.clipSize > 0 && s.clip <= Math.max( 1, s.clipSize / 4 ) );
		$id( "Clip" ).text = String( s.clip );
		$id( "Reserve" ).text = s.noAmmo ? "" : String( s.reserve );
		$id( "Reserve" ).SetHasClass( "hidden", !!s.noAmmo );
		// the hero's own weapon never runs dry: no reserve count (sokky)
		ammo.SetHasClass( "noreserve", !!s.hero && s.held === 1 );

		var hero = s.hero;
		slot( "SlotStatic", "SlotStaticName", hero ? hero.staticName : "", hero, s.held === 1 );
		slot( "SlotDynamic", "SlotDynamicName", hero ? hero.dynamicName : "", hero, s.held === 2 );
	}

	function slot( id, nameId, name, show, active )
	{
		var p = $id( id );
		p.SetHasClass( "hidden", !show );
		p.SetHasClass( "active", !!active );
		p.SetHasClass( "empty", !name );
		$id( nameId ).text = name || "—";
	}

	// ---- Choir's Cadence ------------------------------------------------
	// buffing us: "Cadence" and 1-3 pips. A Choir's own count is in her
	// ability line already ("Cadence: N backed"), so she gets no chip.

	function cadence( s )
	{
		var on = s.cadence > 0;
		$id( "Cadence" ).SetHasClass( "hidden", !on );
		if ( !on )
			return;
		var pips = $id( "CadencePips" ).Children();
		for ( var i = 0; i < pips.length; i++ )
			pips[ i ].SetHasClass( "on", i < s.cadence );
	}

	// ---- squad ---------------------------------------------------------

	function squad( team )
	{
		var key = JSON.stringify( team || [] );
		if ( key === last.squad )
			return;
		last.squad = key;
		var box = $id( "Squad" );
		box.RemoveAndDeleteChildren();
		( team || [] ).forEach( function ( m )
		{
			var card = $.CreatePanel( "Panel", box, "", { "class": "mate" } );
			var st = m.st === "d" ? "Down" : m.st === "x" ? "Dead" : m.hp < 25 ? "Low" : "Alive";
			card.SetHasClass( "low", st === "Low" );
			card.SetHasClass( "down", st === "Down" );
			card.SetHasClass( "dead", st === "Dead" );
			var top = $.CreatePanel( "Panel", card, "", { "class": "mate-top" } );
			label( top, "mate-name", m.name );
			// in a Choir's Cadence: a gold up arrow in place of "Alive"
			if ( m.cad > 0 && st === "Alive" )
				$.CreatePanel( "Image", top, "", { "class": "mate-up", src: "file://{images}/coop/buff_up.png", hittest: "false" } );
			else
				label( top, "mate-status", st );
			card.SetHasClass( "mate-cadence", m.cad > 0 );
			var meter = $.CreatePanel( "Panel", card, "", { "class": "meter" } );
			var fill = $.CreatePanel( "Panel", meter, "", { "class": "meter-fill" } );
			fill.style.width = pct( st === "Alive" || st === "Low" ? m.hp : 0, 100 );
		} );
	}

	// ---- target ID: who the crosshair is on, drawn like a squad card ----

	function targetID( t )
	{
		var card = $id( "TargetID" );
		card.SetHasClass( "hidden", !t );
		if ( !t )
			return;
		var low = t.hp * 4 < t.max, up = t.cad > 0 && !low;
		card.SetHasClass( "low", low );
		card.SetHasClass( "mate-cadence", t.cad > 0 );
		card.style.opacity = String( t.a );
		$id( "TargetName" ).text = t.name;
		$id( "TargetStatus" ).text = low ? "Low" : "Alive";
		$id( "TargetStatus" ).SetHasClass( "hidden", up );
		$id( "TargetUp" ).SetHasClass( "hidden", !up );
		$id( "TargetFill" ).style.width = pct( t.hp, t.max );
	}

	// ---- wave ----------------------------------------------------------

	function wave( s )
	{
		var w = $id( "Wave" );
		w.SetHasClass( "hidden", !( s.wave > 0 ) );
		if ( !( s.wave > 0 ) )
			return;
		$id( "WaveTitle" ).text = "Wave " + s.wave;
		var fighting = s.left >= 0;
		$id( "WaveLeft" ).text = fighting ? String( s.left ) : "—";
		$id( "WaveCaption" ).text = fighting ? "monsters left" : "next wave soon";
	}

	// ---- respawn bar: fills while down, then fire respawns -------------

	function respawn( s )
	{
		var r = s.respawn;
		var p = $id( "Respawn" );
		p.SetHasClass( "hidden", !r );
		if ( !r )
			return;
		var ready = !r.survival && r.frac >= 1;
		p.SetHasClass( "ready", ready );
		$id( "RespawnFill" ).style.width = ( r.survival ? 0 : Math.round( r.frac * 100 ) ) + "%";
		$id( "RespawnLabel" ).text = r.survival ? "Down" : ready ? "Ready to respawn" : "Respawning";
		$id( "RespawnValue" ).text = r.survival || ready ? "" : r.left + "s";
		$id( "RespawnHint" ).text = r.survival ? "Survival: wait for a teammate to revive you" :
			ready ? "Press " + shortKey( s.fireKey || "MOUSE1" ) + " to respawn" : "A teammate can revive you";
	}

	// ---- prompt --------------------------------------------------------

	function prompt( s )
	{
		var p = $id( "Prompt" );
		p.SetHasClass( "hidden", !s.prompt );
		if ( s.prompt )
		{
			var pk = s.promptKey || "E";
			keyGlyphs( $id( "PromptKeyBox" ), "prompt-key", pk );
			$id( "PromptKeyBox" ).SetHasClass( "glyph", !!glyph( pk ) );
			$id( "PromptAction" ).text = s.prompt;
		}
	}

	Bulwark.On( "state", function ( s )
	{
		if ( !s )
			return;
		if ( s.hero )
			s.hero.keys = s.keys;
		vitals( s );
		weapons( s );
		squad( s.team );
		wave( s );
		prompt( s );
		respawn( s );
		targetID( s.tid );
	} );

	// ---- kill feed: five lines, each for six seconds -------------------

	var FEED_MAX = 5, FEED_TIME = 6.0;
	Bulwark.On( "feed", function ( k )
	{
		if ( !k )
			return;
		var box = $id( "Feed" );
		var row = $.CreatePanel( "Panel", box, "", { "class": "feed-entry" } );
		row.SetHasClass( "you", !!k.you );
		if ( k.a )
			label( row, "feed-attacker", k.a );
		label( row, "feed-weapon", k.w || "killed" );
		label( row, "feed-victim last", k.v );
		if ( box.GetChildCount() > 1 )
			box.MoveChildBefore( row, box.GetChild( 0 ) );
		while ( box.GetChildCount() > FEED_MAX )
			box.GetChild( box.GetChildCount() - 1 ).DeleteAsync( 0 );
		// Bulwark's DeleteAsync deletes at once, whatever the delay
		$.Schedule( FEED_TIME, function ()
		{
			if ( row.IsValid() )
				row.DeleteAsync( 0 );
		} );
	} );

	// ---- notice --------------------------------------------------------

	var noticeTimer = null;
	Bulwark.On( "notice", function ( n )
	{
		if ( !n )
			return;
		var p = $id( "Notice" );
		$id( "NoticeTitle" ).text = n.title || "";
		$id( "NoticeSub" ).text = n.sub || "";
		$id( "NoticeSub" ).SetHasClass( "hidden", !n.sub );
		p.SetHasClass( "hidden", false );
		if ( noticeTimer !== null )
			$.CancelScheduled( noticeTimer );
		noticeTimer = $.Schedule( n.hold || 3.0, function ()
		{
			noticeTimer = null;
			p.SetHasClass( "hidden", true );
		} );
	} );

	$id( "Notice" ).SetHasClass( "hidden", true );
	$id( "Prompt" ).SetHasClass( "hidden", true );
} )();
