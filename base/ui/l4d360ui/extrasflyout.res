"Resource/UI/ExtrasFlyout.res"
{
	"PnlBackground"
	{
		"ControlName"		"Panel"
		"fieldName"			"PnlBackground"
		"xpos"				"0"
		"ypos"				"0"
		"zpos"				"-1"
		"wide"				"156" [$ENGLISH]
		"wide"				"236" [$!ENGLISH]
		"tall"				"65"	[$WIN32]
		"tall"				"45"	[$X360]
		"visible"			"1"
		"enabled"			"1"
		"paintbackground"	"1"
		"paintborder"		"1"
	}

	// Not present in Xbox
	"BtnWatchMovie"
	{
		"ControlName"			"L4D360HybridButton"
		"fieldName"				"BtnWatchMovie"
		"xpos"					"0"
		"ypos"					"0"
		"wide"					"150"
		"tall"					"20"
		"autoResize"			"1"
		"pinCorner"				"0"
		"visible"				"1"		[$WIN32]
		"visible"				"0"		[$X360]
		"enabled"				"1"
		"tabPosition"			"0"
		"navUp"					"BtnCredits"
		"navDown"				"BtnCommentary"
		"tooltiptext"			"#L4D360UI_Extras_WatchMovie_Tip"
		"labelText"				"#L4D360UI_Extras_WatchMovie"
		"style"					"FlyoutMenuButton"
		"command"				"WatchMovie"
	}

	"BtnCommentary"
	{
		"ControlName"			"L4D360HybridButton"
		"fieldName"				"BtnCommentary"
		"xpos"					"0"
		"ypos"					"20"	[$WIN32]
		"ypos"					"0"		[$X360]
		"wide"					"150"
		"tall"					"20"
		"autoResize"			"1"
		"pinCorner"				"0"
		"visible"				"1"
		"enabled"				"1"
		"tabPosition"			"0"
		"navUp"					"BtnWatchMovie"
		"navDown"				"BtnCredits"
		"tooltiptext"			"#L4D360UI_Extras_Commentary_Tip"
		"labelText"				"#L4D360UI_Extras_Commentary"
		"style"					"FlyoutMenuButton"
		"command"				"DeveloperCommentary"
	}

	"BtnCredits"
	{
		"ControlName"			"L4D360HybridButton"
		"fieldName"				"BtnCredits"
		"xpos"					"0"
		"ypos"					"40"	[$WIN32]
		"ypos"					"20"	[$X360]
		"wide"					"150"
		"tall"					"20"
		"autoResize"			"1"
		"pinCorner"				"0"
		"visible"				"1"
		"enabled"				"1"
		"tabPosition"			"0"
		"navUp"					"BtnCommentary"
		"navDown"				"BtnWatchMovie"
		"tooltiptext"			"#L4D360UI_Extras_Credits_Tip"
		"labelText"				"#L4D360UI_Extras_Credits"
		"style"					"FlyoutMenuButton"
		"command"				"Credits"
	}
}