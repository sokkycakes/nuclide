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
		armor.SetHasClass( "hidden", !hero && ar <= 0 );

		var energy = $id( "EnergyBar" );
		energy.SetHasClass( "hidden", !hero );
		if ( hero )
		{
			$id( "EnergyValue" ).text = hero.energy + " / " + hero.emax;
			$id( "EnergyFill" ).style.width = pct( hero.energy, hero.emax );
		}
		abilities( hero );
	}

	// one row per part of the kit's status line: "[G] Courier ready"
	function abilities( hero )
	{
		var box = $id( "Abilities" );
		var key = hero ? hero.status + "\n" + hero.form + hero.formLine : "";
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
			var w = /^(.*?)\s+(ready|used|\d+s|\d+\/\d+|\d+%|\d+)$/i.exec( text );
			if ( w )
			{
				text = w[ 1 ];
				state = w[ 2 ];
			}
			var row = $.CreatePanel( "Panel", box, "", { "class": "ability" } );
			row.SetHasClass( "ready", /^ready$/i.test( state ) );
			row.SetHasClass( "engaged", i >= formFrom && hero.form > 0 );
			label( row, "ability-key", k );
			label( row, "ability-name", text );
			label( row, "ability-state", state );
		} );
	}

	// ---- weapons -------------------------------------------------------

	function weapons( s )
	{
		var ammo = $id( "Ammo" );
		$id( "WeaponName" ).text = s.weapon || "";
		ammo.SetHasClass( "empty", !s.weapon );
		ammo.SetHasClass( "noclip", s.clipSize <= 0 );
		ammo.SetHasClass( "low", s.clipSize > 0 && s.clip <= Math.max( 1, s.clipSize / 4 ) );
		$id( "Clip" ).text = String( s.clip );
		$id( "Reserve" ).text = s.noAmmo ? "" : String( s.reserve );
		$id( "Reserve" ).SetHasClass( "hidden", !!s.noAmmo );

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
			label( top, "mate-status", st );
			var meter = $.CreatePanel( "Panel", card, "", { "class": "meter" } );
			var fill = $.CreatePanel( "Panel", meter, "", { "class": "meter-fill" } );
			fill.style.width = pct( st === "Alive" || st === "Low" ? m.hp : 0, 100 );
		} );
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

	// ---- prompt --------------------------------------------------------

	function prompt( s )
	{
		var p = $id( "Prompt" );
		p.SetHasClass( "hidden", !s.prompt );
		if ( s.prompt )
		{
			$id( "PromptKey" ).text = s.promptKey || "E";
			$id( "PromptAction" ).text = s.prompt;
		}
	}

	Bulwark.On( "state", function ( s )
	{
		if ( !s )
			return;
		vitals( s );
		weapons( s );
		squad( s.team );
		wave( s );
		prompt( s );
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
