"Resource/UI/Achievements.res"
{
	"Achievements"
	{
		"ControlName"		"Frame"
		"fieldName"		"Achievements"
		"xpos"			"c-250"
		"ypos"			"c-170"
		"wide"			"500"
		"tall"			"300" [$X360]
		"tall"			"325" [$WIN32]
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"usetitlesafe"	"1"
	}

	"PnlUpperGarnish"
	{
		"ControlName"		"Panel"
		"fieldName"		"PnlUpperGarnish"
		"xpos"			"0"
		"ypos"			"0"
		"zpos"			"-1"
		"wide"			"f0"
		"tall"			"45"
		"autoResize"		"1"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"proportionalToParent"	"1"
	}

	"LblComplete"
	{
		"ControlName"		"Label"
		"fieldName"		"LblComplete"
		"xpos"			"15"
		"ypos"			"39"
		"wide"			"150"
		"autoResize"		"1"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"proportionalToParent"	"1"
		"textAlignment"		"west"
	}

	"LblGamerscore"
	{
		"ControlName"		"Label"
		"fieldName"		"LblGamerscore"
		"xpos"			"r270"
		"ypos"			"39"
		"wide"			"250"
		"autoResize"		"1"
		"pinCorner"		"0"
		"visible"		"1" [$X360]
		"visible"		"0" [$WIN32]
		"enabled"		"1"
		"tabPosition"		"0"
		"proportionalToParent"	"1"
		"textAlignment"		"east"
	}

	"GplAchievements"
	{
		"ControlName"		"GenericPanelList"
		"fieldName"		"GplAchievements"
		"xpos"			"15"
		"ypos"			"60"
		"wide"			"f30"
		"tall"			"238"
		"autoResize"		"1"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"1"
		"proportionalToParent"	"1"
	}

	"PnlLowerGarnish"
	{
		"ControlName"		"Panel"
		"fieldName"		"PnlLowerGarnish"
		"xpos"			"0"
		"ypos"			"r45"
		"zpos"			"-1"
		"wide"			"f0"
		"tall"			"45"
		"autoResize"		"1"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"proportionalToParent"	"1"
	}
	
	"ProTotalProgressPlaceholder"
	{
		"ControlName"			"ContinuousProgressBar"
		"fieldName"				"ProTotalProgressPlaceholder"
		"xpos"					"10"
		"ypos"					"31"
		"wide"					"480"
		"tall"					"9"
		"autoResize"			"0"
		"pinCorner"				"0"
		"visible"				"0"
		"enabled"				"1"
		"tabPosition"			"0"
		"proportionalToParent"	"1"
	}

	"BtnCancel" [$WIN32]
	{
		"ControlName"			"L4D360HybridButton"
		"fieldName"				"BtnCancel"
		"ypos"					"290"
		"xpos"					"10"
		"wide"					"250"
		"tall"					"20"
		"autoResize"			"1"
		"pinCorner"				"0"
		"visible"				"1"
		"enabled"				"1"
		"tabPosition"			"1"
		"wrap"					"1"
		"labelText"				"#L4D360UI_Back_Caps"
		"tooltiptext"			"#L4D360UI_Tooltip_Back"
		"style"					"DefaultButton"
		"command"				"Back"
		"proportionalToParent"	"1"
		"usetitlesafe" 			"0"
		EnabledTextInsetX		"2"
		DisabledTextInsetX		"2"
		FocusTextInsetX			"2"
		OpenTextInsetX			"2"
	}
}