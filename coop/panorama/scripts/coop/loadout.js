// Co-op shop menu: the points shop and the XP mod's skills on two tabs.
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
// Tab switches tabs; a "tab" event ("shop" or "skills") picks one.
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
			line( cats, c[ 0 ] === category ? "current" : "", String( i + 1 ), c[ 1 ], "", function ()
			{
				pick( c[ 0 ] );
			} );
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
			line( list, cls, String( i + 1 ), it.name, price, function () { buy( it ); } );
		} );

		if ( pages > 1 )
		{
			var pager = make( "Panel", list, "shop-pager", { hittest: "false" } );
			label( pager, "", "Page " + ( pageNum + 1 ) + " of " + pages + "    8  Previous    9  Next" );
		}

		$( "#Keys" ).text = ( category ?
			"1-" + Math.min( PER_PAGE, items.length ) + "  Buy      0  Back" :
			"1-" + catList.length + "  Category      0  Close" ) + "      Tab  Skills";
	}

	function pick( c )
	{
		category = c;
		pageNum = 0;
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
			render();
		}
		else if ( n === 9 && ( pageNum + 1 ) * PER_PAGE < items.length )
		{
			pageNum++;
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
			row.SetPanelEvent( "onactivate", function ()
			{
				$.GetContextPanel().SetFocus();
				spend( sk.id );
			} );
		} );

		$( "#Keys" ).text = ( skills.points > 0 ?
			"1-" + skills.skills.length + "  Spend a point      0  Close" : "No points to spend      0  Close" ) + "      Tab  Shop";
	}

	// ---- both ----

	function render()
	{
		$( "#TabShop" ).SetHasClass( "current", tab === "shop" );
		$( "#TabSkills" ).SetHasClass( "current", tab === "skills" );
		$( "#ShopPage" ).SetHasClass( "open", tab === "shop" );
		$( "#SkillsPage" ).SetHasClass( "open", tab === "skills" );

		// unspent skill points show on the tab from the shop too
		var unspent = skills ? skills.points : 0;
		$( "#TabSkills" ).SetHasClass( "has-points", unspent > 0 );
		$( "#TabSkillsLabel" ).text = unspent > 0 ? "Skills (" + unspent + ")" : "Skills";

		if ( tab === "shop" )
		{
			$( "#Points" ).text = plural( shop.points, "point" );
			renderShop();
		}
		else
		{
			$( "#Points" ).text = skills ? plural( skills.points, "skill point" ) : "";
			renderSkills();
		}
	}

	function setTab( t )
	{
		tab = t === "skills" ? "skills" : "shop";
		render();
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
	Bulwark.On( "tab", function ( t ) { setTab( t ); } );
	Bulwark.On( "key", function ( e )
	{
		if ( !e || !e.down )
			return;
		if ( e.key === "Escape" )
			close();
		else if ( e.key === "Tab" )
			setTab( tab === "shop" ? "skills" : "shop" );
		else if ( /^[0-9]$/.test( e.bind ) )
		{
			var n = parseInt( e.bind, 10 );
			if ( tab === "shop" )
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
	$( "#TabShop" ).SetPanelEvent( "onactivate", function () { setTab( "shop" ); } );
	$( "#TabSkills" ).SetPanelEvent( "onactivate", function () { setTab( "skills" ); } );

	render();
	return {};
} )();
