// XP mod skill menu: {points, level, rank, skills: [{id, name, level, max}]}
// from the plugin. A number key or a click spends a point on that skill
// ("spend" -> "cmd menuselect <n>"); the plugin answers with the new
// levels, and the menu progs closes the view when the points run out.
var CoopSkills = ( function ()
{
	// what each skill does, by the plugin's names (coop/README.md)
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

	var data = { points: 0, level: 0, rank: "", skills: [] };

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

	function spend( id ) { Bulwark.Send( "spend", String( id ) ); }
	function close()
	{
		// the plugin's "Done" is 0, sent as 10
		Bulwark.Send( "spend", "10" );
		Bulwark.Send( "close", "" );
	}

	function render()
	{
		var list = $( "#Skills" );
		list.RemoveAndDeleteChildren();
		list.SetHasClass( "spent", data.points <= 0 );
		$( "#Points" ).text = data.points + ( data.points === 1 ? " skill point" : " skill points" );
		$( "#Rank" ).text = "Level " + data.level + "  ·  " + data.rank;

		data.skills.forEach( function ( sk )
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

		$( "#Keys" ).text = data.points > 0 ?
			"1-" + data.skills.length + "  Spend a point      0  Done" : "No points to spend      0  Done";
	}

	Bulwark.On( "skills", function ( d )
	{
		data = d || data;
		render();
	} );
	Bulwark.On( "key", function ( e )
	{
		if ( !e || !e.down )
			return;
		if ( e.key === "Escape" || e.bind === "0" )
			close();
		else if ( /^[1-9]$/.test( e.bind ) )
			spend( parseInt( e.bind, 10 ) );
	} );
	$( "#Close" ).SetPanelEvent( "onactivate", close );

	render();
	return {};
} )();
