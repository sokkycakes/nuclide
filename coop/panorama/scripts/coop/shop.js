// Co-op points shop. The list comes from the server as a "shop" event:
// {points, closed, message, items: [{id, category, name, price, state}]},
// state 0 can buy, 1 can't afford, 2 owned, 3 full (health, armour). Buying sends "buy"
// and the server answers with a fresh list.
//
// The keys work like Counter-Strike's buy menu: a number picks a category,
// then a number buys an item; 0 goes back, and closes at the top.
var CoopShop = ( function ()
{
	var CATEGORIES = [ [ "weapons", "Weapons" ], [ "ammo", "Ammo" ], [ "supplies", "Health and armour" ] ];
	var PER_PAGE = 7;	// 8 and 9 turn the page

	var shop = { points: 0, closed: "", message: "", items: [] };
	var category = "";	// "" while picking a category
	var pageNum = 0;

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

	function render()
	{
		var cats = $( "#Categories" );
		var list = $( "#Items" );
		cats.RemoveAndDeleteChildren();
		list.RemoveAndDeleteChildren();
		$( "#Points" ).text = shop.points + ( shop.points === 1 ? " point" : " points" );
		$( "#Message" ).text = shop.message || "";

		if ( shop.closed )
		{
			label( list, "shop-closed", shop.closed );
			$( "#Keys" ).text = "0  Close";
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

		$( "#Keys" ).text = category ?
			"1-" + Math.min( PER_PAGE, items.length ) + "  Buy      0  Back" :
			"1-" + catList.length + "  Category      0  Close";
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
	function close() { Bulwark.Send( "close", "" ); }

	function digit( n )
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

	Bulwark.On( "shop", function ( s )
	{
		shop = s || shop;
		render();
	} );
	Bulwark.On( "key", function ( e )
	{
		if ( !e || !e.down )
			return;
		if ( e.key === "Escape" )
			close();
		else if ( /^[0-9]$/.test( e.bind ) )
			digit( parseInt( e.bind, 10 ) );
		else if ( e.key === "WheelUp" || e.key === "WheelDown" )
			digit( e.key === "WheelUp" ? 8 : 9 );
	} );
	$( "#Close" ).SetPanelEvent( "onactivate", close );

	render();
	return {};
} )();
