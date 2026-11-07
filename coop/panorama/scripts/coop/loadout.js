// Co-op shop menu: heroes, the points shop and the XP mod's skills on tabs.
//
// Hero tab: a "heroes" event {on, current, picked, message, items: [{type:
// "hero", id, def, name, role, desc, health, speed, full} and {type: "kit",
// id, hero, def, name, desc}]} from the rules. The tab only shows when the
// server has heroes on. A number key or a click picks a kit ("hero" ->
// "cmd hero <kit>"); it takes effect when the player next spawns.
//
// Shop tab: a "shop" event {points, closed, message, items: [{id, category,
// name, price, state}]}, state 0 can buy, 1 can't afford, 2 owned (or
// bought for the next spawn), 3 full. Buying sends "buy" and the server
// answers with a fresh list. The keys work like Counter-Strike's buy menu:
// a number picks a category, then a number buys an item; 0 goes back, and
// closes at the top.
//
// Skills tab: a "skills" event {points, level, rank, skills: [{id, name,
// level, max}]} from the XP plugin. A number key or a click spends a point
// ("spend" -> "cmd menuselect <n>"), 0 closes.
//
// Tab switches tabs; a "tab" event ("hero", "shop" or "skills") picks one.
//
// A controller drives it too (sokky 2026-11-02; d-pad up opens it, see
// Menu_PadLayout in coop/src/menu/main.qc): the d-pad or the left stick
// (the engine turns the stick into d-pad presses while a menu is open)
// moves a highlight, A picks, B goes back and closes at the top, LB and RB
// change tabs, Start closes. In the shop, right opens a category, and left
// and right turn the pages of a long one. Any pad button shows the
// highlight and the button prompts; a number key or Tab hides them again.
var CoopLoadout = ( function ()
{
	var CATEGORIES = [ [ "weapons", "Weapons" ], [ "ammo", "Ammo" ], [ "supplies", "Health and armour" ] ];
	var PER_PAGE = 7;	// 8 and 9 turn the page
	var ABOUT = {
		"Strength": "+1 health each",
		"Superior Armor": "+1 armour each",
		"Health Regeneration": "Health comes back over time",
		"Nano Armor": "Armour comes back over time",
		"Ammo Reincarnation": "Ammo for the weapon in hand comes back over time",
		"Anti Gravity Device": "Lower gravity while you hold jump after a jump",
		"Awareness": "Makes the other skills work better",
		"Team Power": "Heals and armours teammates near you",
		"Block Attack": "A chance to take no damage"
	};

	var tab = "shop";
	var shop = { points: 0, closed: "", message: "", items: [] };
	var category = "";	// "" while picking a category
	var pageNum = 0;
	var skills = null;	// null until the plugin sends them: the XP mod is off
	var heroes = null;	// null until the rules send them

	var pad = false;	// a controller is driving: show the highlight
	var sel = { hero: 0, cats: 0, items: 0, skills: 0 };	// highlighted line of each list
	var lines = [];	// the highlightable lines on screen, top down, with .act

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
	function line( parent, cls, key, name, price, fn )
	{
		var b = make( "Button", parent, "shop-line " + cls, { hittest: "true" } );
		label( b, "shop-key", key );
		label( b, "shop-name", name );
		if ( price !== "" )
			label( b, "shop-price", price );
		b.SetPanelEvent( "onactivate", function ()
		{
			$.GetContextPanel().SetFocus();
			fn();
		} );
		b.act = fn;
		return b;
	}
	function plural( n, one ) { return n + " " + one + ( n === 1 ? "" : "s" ); }

	// ---- shop ----

	function categories()
	{
		// the categories the list has, in CATEGORIES order, then any others
		var seen = {};
		shop.items.forEach( function ( it ) { seen[ it.category ] = true; } );
		var out = CATEGORIES.filter( function ( c ) { return seen[ c[ 0 ] ]; } );
		Object.keys( seen ).forEach( function ( c )
		{
			if ( !CATEGORIES.some( function ( k ) { return k[ 0 ] === c; } ) )
				out.push( [ c, c.charAt( 0 ).toUpperCase() + c.slice( 1 ) ] );
		} );
		return out;
	}
	function itemsIn( c )
	{
		return shop.items.filter( function ( it ) { return it.category === c; } );
	}

	function renderShop()
	{
		var cats = $( "#Categories" );
		var list = $( "#Items" );
		cats.RemoveAndDeleteChildren();
		list.RemoveAndDeleteChildren();
		$( "#Message" ).text = shop.message || "";

		if ( shop.closed )
		{
			label( list, "shop-closed", shop.closed );
			$( "#Keys" ).text = "0  Close      Tab  Skills";
			return;
		}

		var catList = categories();
		cats.SetHasClass( "inactive", category !== "" );
		list.SetHasClass( "inactive", category === "" );

		catList.forEach( function ( c, i )
		{
			var b = line( cats, c[ 0 ] === category ? "current" : "", String( i + 1 ), c[ 1 ], "", function ()
			{
				pick( c[ 0 ] );
			} );
			if ( !category )
				lines.push( b );
		} );

		// items of the picked category, or a preview of the first one
		var shown = category || ( catList.length ? catList[ 0 ][ 0 ] : "" );
		var items = itemsIn( shown );
		var pages = Math.max( 1, Math.ceil( items.length / PER_PAGE ) );
		if ( pageNum >= pages )
			pageNum = pages - 1;

		items.slice( pageNum * PER_PAGE, pageNum * PER_PAGE + PER_PAGE ).forEach( function ( it, i )
		{
			var cls = it.state === 1 ? "dim" : ( it.state >= 2 ? "dim owned" : "" );
			var price = it.state === 2 ? "Have it" : ( it.state === 3 ? "Full" : String( it.price ) );
			lines.push( line( list, cls, String( i + 1 ), it.name, price, function () { buy( it ); } ) );
		} );

		if ( pages > 1 )
		{
			var pager = make( "Panel", list, "shop-pager", { hittest: "false" } );
			label( pager, "", "Page " + ( pageNum + 1 ) + " of " + pages +
				( pad ? "" : "    8  Previous    9  Next" ) );
		}

		$( "#Keys" ).text = ( category ?
			"1-" + Math.min( PER_PAGE, items.length ) + "  Buy      0  Back" :
			"1-" + catList.length + "  Category      0  Close" ) + "      Tab  Skills";
	}

	function pick( c )
	{
		category = c;
		pageNum = 0;
		sel.items = 0;
		categories().forEach( function ( k, i ) { if ( k[ 0 ] === c ) sel.cats = i; } );
		shop.message = "";
		render();
	}
	function buy( it )
	{
		if ( category !== it.category )
			category = it.category;
		Bulwark.Send( "buy", String( it.id ) );
	}

	function shopDigit( n )
	{
		if ( shop.closed )
		{
			if ( n === 0 )
				close();
			return;
		}
		if ( !category )
		{
			var cats = categories();
			if ( n === 0 )
				close();
			else if ( n <= cats.length )
				pick( cats[ n - 1 ][ 0 ] );
			return;
		}
		var items = itemsIn( category );
		if ( n === 0 )
		{
			category = "";
			shop.message = "";
			render();
		}
		else if ( n === 8 && pageNum > 0 )
		{
			pageNum--;
			sel.items = pageNum * PER_PAGE;
			render();
		}
		else if ( n === 9 && ( pageNum + 1 ) * PER_PAGE < items.length )
		{
			pageNum++;
			sel.items = pageNum * PER_PAGE;
			render();
		}
		else if ( n <= PER_PAGE )
		{
			var it = items[ pageNum * PER_PAGE + n - 1 ];
			if ( it )
				buy( it );
		}
	}

	// ---- skills ----

	function spend( id ) { Bulwark.Send( "spend", String( id ) ); }

	function renderSkills()
	{
		var list = $( "#Skills" );
		list.RemoveAndDeleteChildren();

		if ( !skills )
		{
			$( "#Rank" ).text = "";
			label( list, "skills-off", "The XP mod is off on this server." );
			$( "#Keys" ).text = "0  Close      Tab  Shop";
			return;
		}

		list.SetHasClass( "spent", skills.points <= 0 );
		$( "#Rank" ).text = "Level " + skills.level + "  ·  " + skills.rank;

		skills.skills.forEach( function ( sk )
		{
			var maxed = sk.level >= sk.max;
			var row = make( "Button", list, "skill" + ( maxed ? " maxed" : "" ), { hittest: "true" } );
			label( row, "shop-key", String( sk.id ) );
			var text = make( "Panel", row, "skill-text", { hittest: "false" } );
			label( text, "skill-name", sk.name );
			label( text, "skill-desc", ABOUT[ sk.name ] || "" );
			var meter = make( "Panel", row, "skill-meter", { hittest: "false" } );
			var bar = make( "Panel", meter, "skill-bar", { hittest: "false" } );
			var fill = make( "Panel", bar, "skill-fill", { hittest: "false" } );
			fill.style.width = ( sk.max > 0 ? Math.min( 100, sk.level / sk.max * 100 ) : 0 ) + "%";
			label( meter, "skill-count", maxed ? "Mastered" : sk.level + " / " + sk.max );
			row.act = function () { spend( sk.id ); };
			row.SetPanelEvent( "onactivate", function ()
			{
				$.GetContextPanel().SetFocus();
				row.act();
			} );
			lines.push( row );
		} );

		$( "#Keys" ).text = ( skills.points > 0 ?
			"1-" + skills.skills.length + "  Spend a point      0  Close" : "No points to spend      0  Close" ) + "      Tab  Shop";
	}

	// ---- heroes ----

	function heroesOn() { return !!( heroes && heroes.on ); }
	function kits()
	{
		return heroes.items.filter( function ( it ) { return it.type === "kit"; } );
	}
	function pickKit( kit ) { Bulwark.Send( "hero", kit.def ); }

	// #HeroPreview in design units from the screen's centre: the panel is
	// 1100 x 840 and centred, the header and tabs take 120 at the top, the
	// footer 76 at the bottom and the list 640 on the left (skills.css)
	var HERO_PREVIEW = "90 -300 460 644";

	function preview()
	{
		if ( tab !== "hero" || !heroesOn() )
		{
			Bulwark.Send( "preview", "" );
			return;
		}
		var all = kits();
		var shown = ( pad ? all[ sel.hero ] : null ) || all.filter( function ( k ) { return k.def === heroes.picked; } )[ 0 ] ||
			all.filter( function ( k ) { return k.def === heroes.current; } )[ 0 ] || all[ 0 ];
		Bulwark.Send( "preview", shown ? shown.def + " center " + HERO_PREVIEW + " dim" : "" );
	}

	var heroRows = [];	// the kit lines as built, and the list they were built from
	var heroSig = "";

	// the Playing / Next spawn marks of a kit line
	function markKit( row, k )
	{
		var now = k.def === heroes.current;
		var next = k.def === heroes.picked && !now;
		row.SetHasClass( "current", now );
		row.SetHasClass( "picked", next );
		row.stateLabel.text = now ? "Playing" : ( next ? "Next spawn" : "" );
	}

	function renderHeroes()
	{
		var list = $( "#Heroes" );
		var all = kits();
		$( "#HeroMessage" ).text = heroes.message || "";
		$( "#Keys" ).text = "1-" + all.length + "  Pick a kit      0  Close      Tab  Shop";

		// the same roster (a pick only moves the marks): keep the lines, so
		// the list keeps where it was scrolled to
		var sig = JSON.stringify( heroes.items );
		if ( sig === heroSig && heroRows.length )
		{
			heroRows.forEach( function ( r ) { markKit( r, r.kit ); lines.push( r ); } );
			return;
		}
		heroSig = sig;
		heroRows = [];
		list.RemoveAndDeleteChildren();
		var key = 0;
		heroes.items.filter( function ( it ) { return it.type === "hero"; } ).forEach( function ( h )
		{
			var card = make( "Panel", list, "hero" + ( h.full ? " full" : "" ), { hittest: "false" } );
			var head = make( "Panel", card, "hero-head", { hittest: "false" } );
			label( head, "hero-name", h.name );
			label( head, "hero-stats", ( h.role && h.role !== h.name ? h.role + "  ·  " : "" ) +
				h.health + " health  ·  speed " + h.speed + ( h.full ? "  ·  full" : "" ) );
			if ( h.desc )
				label( card, "hero-desc", h.desc );

			all.filter( function ( k ) { return k.hero === h.id; } ).forEach( function ( k )
			{
				key++;
				var row = make( "Button", card, "skill kit", { hittest: "true" } );
				label( row, "shop-key", String( key ) );
				var text = make( "Panel", row, "skill-text", { hittest: "false" } );
				label( text, "skill-name", k.name );
				label( text, "skill-desc", k.desc || "" );
				row.stateLabel = label( row, "kit-state", "" );
				row.kit = k;
				markKit( row, k );
				heroRows.push( row );
				row.act = function () { pickKit( k ); };
				row.SetPanelEvent( "onactivate", function ()
				{
					$.GetContextPanel().SetFocus();
					row.act();
				} );
				lines.push( row );
			} );
		} );
	}

	// ---- both ----

	function render()
	{
		lines = [];
		if ( tab === "hero" && !heroesOn() )
			tab = "shop";
		$( "#TabHero" ).SetHasClass( "hidden", !heroesOn() );
		$( "#TabHero" ).SetHasClass( "current", tab === "hero" );
		$( "#HeroPage" ).SetHasClass( "open", tab === "hero" );
		$( "#Loadout" ).SetHasClass( "hero-tab", tab === "hero" );
		$( "#Stage" ).SetHasClass( "hero-tab", tab === "hero" );
		$( "#TabShop" ).SetHasClass( "current", tab === "shop" );
		$( "#TabSkills" ).SetHasClass( "current", tab === "skills" );
		$( "#ShopPage" ).SetHasClass( "open", tab === "shop" );
		$( "#SkillsPage" ).SetHasClass( "open", tab === "skills" );

		// unspent skill points show on the tab from the shop too
		var unspent = skills ? skills.points : 0;
		$( "#TabSkills" ).SetHasClass( "has-points", unspent > 0 );
		$( "#TabSkillsLabel" ).text = unspent > 0 ? "Skills (" + unspent + ")" : "Skills";

		if ( tab === "hero" )
		{
			$( "#Points" ).text = plural( shop.points, "point" );
			renderHeroes();
		}
		else if ( tab === "shop" )
		{
			$( "#Points" ).text = plural( shop.points, "point" );
			renderShop();
		}
		else
		{
			$( "#Points" ).text = skills ? plural( skills.points, "skill point" ) : "";
			renderSkills();
		}
		highlight();
		preview();
	}

	// ---- the controller ----

	// which list the highlight is in, and how long that list is
	function list()
	{
		if ( tab === "hero" )
			return [ "hero", heroesOn() ? kits().length : 0 ];
		if ( tab === "skills" )
			return [ "skills", skills ? skills.skills.length : 0 ];
		if ( shop.closed )
			return [ "cats", 0 ];
		return category ? [ "items", itemsIn( category ).length ] : [ "cats", categories().length ];
	}
	// the highlighted line among those on screen (items show a page at a time)
	function onScreen()
	{
		var l = list();
		if ( l[ 1 ] <= 0 )
			return -1;
		sel[ l[ 0 ] ] = Math.max( 0, Math.min( sel[ l[ 0 ] ], l[ 1 ] - 1 ) );
		return l[ 0 ] === "items" ? sel.items - pageNum * PER_PAGE : sel[ l[ 0 ] ];
	}
	function prompts( keys )
	{
		var row = $( "#PadKeys" );
		row.RemoveAndDeleteChildren();
		keys.forEach( function ( k )
		{
			k[ 0 ].split( " " ).forEach( function ( g )
			{
				make( "Image", row, "pad-glyph", { src: "file://{images}/xelu/xbox/XboxSeriesX_" + g + ".png", hittest: "false" } );
			} );
			label( row, "pad-text", k[ 1 ] );
		} );
	}
	function highlight()
	{
		var i = pad ? onScreen() : -1;
		lines.forEach( function ( b, n ) { b.SetHasClass( "focus", n === i ); } );
		if ( i >= 0 && lines[ i ] )
		{
			// a rebuilt list starts back at the top and its new lines have no
			// place to scroll to until they're laid out: jump there a moment later
			var shown = lines[ i ];
			shown.ScrollParentToMakePanelFit( 1, false );
			$.Schedule( 0.05, function () { shown.ScrollParentToMakePanelFit( 1, true ); } );
		}

		$( "#Keys" ).SetHasClass( "hidden", pad );
		$( "#PadKeys" ).SetHasClass( "hidden", !pad );
		if ( !pad )
			return;
		var l = list();
		var keys = [];
		if ( l[ 1 ] > 0 )
			keys.push( [ "A", { hero: "Pick", skills: "Spend", cats: "Open", items: "Buy" }[ l[ 0 ] ] ] );
		if ( l[ 0 ] === "items" && itemsIn( category ).length > PER_PAGE )
			keys.push( [ "Dpad_Left Dpad_Right", "Page" ] );
		keys.push( [ "B", l[ 0 ] === "items" ? "Back" : "Close" ] );
		keys.push( [ "LB RB", "Tabs" ] );
		prompts( keys );
	}
	function move( d )
	{
		var l = list();
		if ( l[ 1 ] <= 0 )
			return;
		sel[ l[ 0 ] ] = ( sel[ l[ 0 ] ] + d + l[ 1 ] ) % l[ 1 ];
		if ( l[ 0 ] === "items" && pageNum !== Math.floor( sel.items / PER_PAGE ) )
		{
			pageNum = Math.floor( sel.items / PER_PAGE );
			render();
			return;
		}
		// only the highlight moves: rebuilding the list would lose its scroll
		highlight();
		preview();
	}
	function turnPage( d )
	{
		var n = itemsIn( category ).length;
		var to = pageNum + d;
		if ( to < 0 || to * PER_PAGE >= n )
			return false;
		pageNum = to;
		sel.items = Math.min( n - 1, to * PER_PAGE + ( sel.items % PER_PAGE ) );
		render();
		return true;
	}
	function back()
	{
		if ( tab === "shop" && category && !shop.closed )
		{
			category = "";
			shop.message = "";
			render();
		}
		else
			close();
	}
	function padKey( b )
	{
		var l = list();
		var i = onScreen();
		if ( b === "GP_DPAD_UP" )
			move( -1 );
		else if ( b === "GP_DPAD_DOWN" )
			move( 1 );
		else if ( b === "GP_A" )
		{
			if ( i >= 0 && lines[ i ] && lines[ i ].act )
				lines[ i ].act();
		}
		else if ( b === "GP_B" )
			back();
		else if ( b === "GP_MENU" || b === "GP_START" )
			close();
		else if ( b === "GP_LSHOULDER" || b === "GP_RSHOULDER" )
			nextTab( b === "GP_LSHOULDER" ? -1 : 1 );
		else if ( b === "GP_DPAD_RIGHT" )
		{
			if ( l[ 0 ] === "cats" && i >= 0 && lines[ i ] )
				lines[ i ].act();
			else if ( l[ 0 ] === "items" )
				turnPage( 1 );
		}
		else if ( b === "GP_DPAD_LEFT" )
		{
			if ( l[ 0 ] === "items" && !turnPage( -1 ) )
				back();
		}
	}

	function setTab( t )
	{
		tab = ( t === "skills" || ( t === "hero" && heroesOn() ) ) ? t : "shop";
		render();
	}
	function nextTab( d )
	{
		var tabs = heroesOn() ? [ "hero", "shop", "skills" ] : [ "shop", "skills" ];
		setTab( tabs[ ( tabs.indexOf( tab ) + ( d || 1 ) + tabs.length ) % tabs.length ] );
	}
	function close() { Bulwark.Send( "close", "" ); }

	Bulwark.On( "shop", function ( s )
	{
		shop = s || shop;
		render();
	} );
	Bulwark.On( "skills", function ( d )
	{
		skills = d || skills;
		render();
	} );
	Bulwark.On( "heroes", function ( h )
	{
		heroes = h || heroes;
		render();
	} );
	Bulwark.On( "tab", function ( t ) { setTab( t ); } );
	// the Left 4 Dead menus are on (coop/src/menu/l4d360.qc): styles/coop/l4d360.css
	Bulwark.On( "l4d", function () { $( "#Stage" ).SetHasClass( "l4d", true ); } );
	Bulwark.On( "key", function ( e )
	{
		if ( !e || !e.down )
			return;
		if ( /^GP_/.test( e.bind ) )
		{
			pad = true;
			padKey( e.bind );
			highlight();
			return;
		}
		if ( pad && e.bind !== "MOUSE1" && !/^Wheel/.test( e.key ) )
		{
			pad = false;
			highlight();
		}
		if ( e.key === "Escape" )
			close();
		else if ( e.key === "Tab" )
			nextTab();
		else if ( /^[0-9]$/.test( e.bind ) )
		{
			var n = parseInt( e.bind, 10 );
			if ( tab === "hero" )
			{
				var k = heroesOn() ? kits()[ n - 1 ] : null;
				if ( n === 0 )
					close();
				else if ( k )
					pickKit( k );
			}
			else if ( tab === "shop" )
				shopDigit( n );
			else if ( n === 0 )
				close();
			else if ( skills )
				spend( n );
		}
		else if ( tab === "shop" && ( e.key === "WheelUp" || e.key === "WheelDown" ) )
			shopDigit( e.key === "WheelUp" ? 8 : 9 );
	} );
	$( "#Close" ).SetPanelEvent( "onactivate", close );
	$( "#TabHero" ).SetPanelEvent( "onactivate", function () { setTab( "hero" ); } );
	$( "#TabShop" ).SetPanelEvent( "onactivate", function () { setTab( "shop" ); } );
	$( "#TabSkills" ).SetPanelEvent( "onactivate", function () { setTab( "skills" ); } );

	// opened from the pad (d-pad up): start with the highlight showing
	try { pad = fte_query( "cvar:in_lastdevice" ) === "1"; } catch ( err ) {}
	render();
	return {};
} )();
