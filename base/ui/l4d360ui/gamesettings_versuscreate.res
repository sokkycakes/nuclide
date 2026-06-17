"Resource/UI/GameSettings_VersusCreate.res"
{
	"GameSettings"
	{
		"ControlName"				"Frame"
		"fieldName"					"GameSettings"
		"xpos"						"0"
		"ypos"						"0"
		"wide"						"f0"
		"tall"						"230"
		"autoResize"				"0"
		"pinCorner"					"0"
		"visible"					"1"
		"enabled"					"1"
		"tabPosition"				"0"
	}
	
	// black border
	"PnlImageBack"
	{
		"ControlName"			"Panel"
		"fieldName"				"PnlImageBack"
		"xpos"					"c50"
		"ypos"					"95"
		"wide"					"204"
		"tall"					"104"
		"autoResize"			"0"
		"pinCorner"				"0"
		"visible"				"1"
		"enabled"				"1"
		"tabPosition"			"0"
		"bgcolor_override"		"80 80 80 255"
	}
	"ImgLevelImage"
	{
		"ControlName"			"ImagePanel"
		"fieldName"				"ImgLevelImage"
		"xpos"					"c52"
		"ypos"					"97"
		"wide"					"200"
		"tall"					"100"
		"scaleImage"			"1"
		"pinCorner"				"0"
		"visible"				"1"
		"enabled"				"1"
		"tabPosition"			"0"
		"image"					"maps/l4d_hospital01_apartment"
		"scaleImage"			"1"
	}
	
	// Campaign dropdown
	"DrpMission"
	{
		"ControlName"			"DropDownMenu"
		"fieldName"				"DrpMission"
		"xpos"					"c-250"
		"ypos"					"90"
		"zpos"					"1"
		"wide"					"280"
		"tall"					"20"
		"visible"				"1"
		"enabled"				"1"
		"navUp"					"BtnStartLobby"
		"navDown"				"DrpMissionExtended"
		
		//button and label
		"BtnDropButton"
		{
			"ControlName"					"L4D360HybridButton"
			"fieldName"						"BtnDropButton"
			"xpos"							"0"
			"ypos"							"0"
			"zpos"							"2"
			"wide"							"280"
			"tall"							"20"
			"autoResize"					"1"
			"pinCorner"						"0"
			"visible"						"1"
			"enabled"						"1"
			"tabPosition"					"0"
			"labelText"						"#L4D360UI_GameSettings_Mission"
			"tooltiptext"					"#L4D360UI_GameSettings_Tooltip_Mission"
			"disabled_tooltiptext"			"#L4D360UI_GameSettings_Tooltip_Mission_Disabled"
			"style"							"DropDownButton"
			"command"						"FlmMissionVersus"
			"ActivationType"				"1" [$X360]
		}
	}
	
	// Campaign flyout	
	"FlmMissionVersus"
	{
		"ControlName"			"FlyoutMenu"
		"fieldName"				"FlmMissionVersus"
		"visible"				"0"
		"wide"					"0"
		"tall"					"0"
		"zpos"					"4"
		"InitialFocus"			"BtnHospital"
		"ResourceFile"			"resource/UI/L4D360UI/DropDownMissionVersus.res"
	}
	
	"DrpMissionExtended"
	{
		"ControlName"			"DropDownMenu"
		"fieldName"				"DrpMissionExtended"
		"xpos"					"c-250"
		"ypos"					"115"
		"zpos"					"1"
		"wide"					"280"
		"tall"					"20"
		"visible"				"0"
		"enabled"				"1"
		"navUp"					"DrpMission"
		"navDown"				"DrpGameAccess"
		
		//button and label
		"BtnDropButton"
		{
			"ControlName"					"L4D360HybridButton"
			"fieldName"						"BtnDropButton"
			"xpos"							"0"
			"ypos"							"0"
			"zpos"							"2"
			"wide"							"280"
			"tall"							"20"
			"autoResize"					"1"
			"pinCorner"						"0"
			"visible"						"1"
			"enabled"						"1"
			"tabPosition"					"0"
			"labelText"						"#L4D360UI_GameSettings_Mission"
			"tooltiptext"					"#L4D360UI_GameSettings_Tooltip_Mission"
			"disabled_tooltiptext"			"#L4D360UI_GameSettings_Tooltip_Mission_Disabled"
			"style"							"DropDownButton"
			"command"						"FlmMissionVersusExtended"
			"ActivationType"				"1" [$X360]
		}
	}
	
	"FlmMissionVersusExtended"
	{
		"ControlName"			"FlyoutMenu"
		"fieldName"				"FlmMissionVersusExtended"
		"visible"				"0"
		"wide"					"0"
		"tall"					"0"
		"zpos"					"4"
		"InitialFocus"			"BtnHospital"
		"ResourceFile"			"resource/UI/L4D360UI/DropDownMissionVersusExtended.res"
	}

	"DrpGameAccess"
	{
		"ControlName"			"DropDownMenu"
		"fieldName"				"DrpGameAccess"
		"xpos"					"c-250"
		"ypos"					"115"
		"zpos"					"1"
		"wide"					"280"
		"tall"					"20"
		"visible"				"1"
		"enabled"				"1"
		"navUp"					"DrpMissionExtended"
		"navDown"				"BtnStartLobby"
		
		//button and label
		"BtnDropButton"
		{
			"ControlName"			"L4D360HybridButton"
			"fieldName"				"BtnDropButton"
			"xpos"					"0"
			"ypos"					"0"
			"zpos"					"2"
			"wide"					"280"
			"tall"					"20"
			"autoResize"			"1"
			"pinCorner"				"0"
			"visible"				"1"
			"enabled"				"1"
			"tabPosition"			"0"
			"labelText"				"#L4D360UI_Lobby_Change_GameAccess"
			"tooltiptext"			"#L4D360UI_Lobby_Change_GameAccess_Tip"
			"disabled_tooltiptext"	"#L4D360UI_GameSettings_Tooltip_Access_Disabled"
			"style"					"DropDownButton"
			"command"				"FlmGameAccess"
			"ActivationType"		"1" [$X360]
		}
	}
		
	"FlmGameAccess"
	{
		"ControlName"			"FlyoutMenu"
		"fieldName"				"FlmGameAccess"
		"visible"				"0"
		"wide"					"0"
		"tall"					"0"
		"zpos"					"3"
		"InitialFocus"			"BtnFriends"
		"ResourceFile"			"resource/UI/L4D360UI/DropDownGameAccess.res"
	}

	// Chapter Dropdown
	"DrpChapter"
	{
		"ControlName"			"DropDownMenu"
		"fieldName"				"DrpChapter"
		"xpos"					"0"
		"ypos"					"0"
		"zpos"					"1"
		"wide"					"280"
		"tall"					"20"
		"visible"				"0"
		"enabled"				"0"
		"navUp"					""
		"navDown"				""
		
		//button and label
		"BtnDropButton"
		{
			"ControlName"					"L4D360HybridButton"
			"fieldName"						"BtnDropButton"
			"xpos"							"0"
			"ypos"							"0"
			"zpos"							"2"
			"wide"							"280"
			"tall"							"20"
			"autoResize"					"1"
			"pinCorner"						"0"
			"visible"						"1"
			"enabled"						"1"
			"tabPosition"					"0"
			"labelText"						"#L4D360UI_GameSettings_Chapter"
			"tooltiptext"					"#L4D360UI_GameSettings_Tooltip_Chapter"
			"disabled_tooltiptext"			"#L4D360UI_GameSettings_Tooltip_Chapter_Disabled"
			"style"							"DropDownButton"
			"command"						""
			"ActivationType"				"1" [$X360]
		}
	}
	
	//flyouts		
	"FlmHospitalFlyout"
	{
		"ControlName"			"FlyoutMenu"
		"fieldName"				"FlmHospitalFlyout"
		"visible"				"0"
		"wide"					"0"
		"tall"					"0"
		"zpos"					"4"
		"InitialFocus"			"BtnApartments"
		"ResourceFile"			"resource/UI/L4D360UI/DropDownHospital.res"
	}
	
	"FlmAirportFlyout"
	{
		"ControlName"			"FlyoutMenu"
		"fieldName"				"FlmAirportFlyout"
		"visible"				"0"
		"wide"					"0"
		"tall"					"0"
		"zpos"					"4"
		"InitialFocus"			"BtnGreenhouse"
		"ResourceFile"			"resource/UI/L4D360UI/DropDownAirport.res"
	}
	
	"FlmFarmFlyout"
	{
		"ControlName"			"FlyoutMenu"
		"fieldName"				"FlmFarmFlyout"
		"visible"				"0"
		"wide"					"0"
		"tall"					"0"
		"zpos"					"4"
		"InitialFocus"			"BtnHilltop"
		"ResourceFile"			"resource/UI/L4D360UI/DropDownFarm.res"
	}
	
	"FlmSmallTownFlyout"
	{
		"ControlName"			"FlyoutMenu"
		"fieldName"				"FlmSmallTownFlyout"
		"visible"				"0"
		"wide"					"0"
		"tall"					"0"
		"zpos"					"4"
		"InitialFocus"			"BtnCaves"
		"ResourceFile"			"resource/UI/L4D360UI/DropDownSmallTown.res"
	}
	
	"BtnStartLobby"
	{
		"ControlName"			"L4D360HybridButton"
		"fieldName"				"BtnStartLobby"
		"xpos"					"c-250"
		"ypos"					"140"
		"zpos"					"0"
		"wide"					"200"
		"tall"					"20"
		"autoResize"			"1"
		"pinCorner"				"0"
		"visible"				"0"
		"enabled"				"1"
		"tabPosition"			"1"
		"wrap"					"1"
		"navUp"					"DrpGameAccess"
		"navDown"				"DrpMission"
		"labelText"				"#L4D360UI_GameSettings_Create_Lobby"
		"tooltiptext"			"#L4D360UI_GameSettings_Tooltip_Create_Lobby"
		"style"					"DefaultButton"
		"command"				"StartLobby"
		EnabledTextInsetX		"2"
		DisabledTextInsetX		"2"
		FocusTextInsetX			"2"
		OpenTextInsetX			"2"
	}

	"BtnCancel"	[$WIN32]
	{
		"ControlName"			"L4D360HybridButton"
		"fieldName"				"BtnCancel"
		"xpos"					"c-250"
		"ypos"					"190"
		"zpos"					"0"
		"wide"					"200"
		"tall"					"20"
		"autoResize"			"1"
		"pinCorner"				"0"
		"visible"				"0"
		"enabled"				"1"
		"tabPosition"			"1"
		"wrap"					"1"
		"navUp"					"BtnJoinStart"
		"navDown"				"DrpDifficulty"
		"labelText"				"#L4D360UI_Back_Caps"
		"tooltiptext"			"#L4D360UI_Tooltip_Back"
		"style"					"DefaultButton"
		"command"				"Back"
		EnabledTextInsetX		"2"
		DisabledTextInsetX		"2"
		FocusTextInsetX			"2"
		OpenTextInsetX			"2"
	}
}
