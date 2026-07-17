window.__H3_MENU_DATA__ = {
  "_source": "Sourced from H3EK tags\\ui\\halox\\main_menu\\* and tags\\ui\\main_menu.user_interface_globals_definition. See data.json.README in this folder for tag provenance.",
  "screen": {
    "id": "main_menu",
    "widget_tag": "ui\\halox\\main_menu\\main_menu",
    "logical_size_720p": [1280, 720],
    "title_safe_720p": { "top": 40, "left": 64, "bottom": 680, "right": 1216 },
    "initial_button_key": "main_menu_offline",
    "on_load_script": "mainmenu_cam",
    "flags": ["B-Back shouldn't dispose screen", "do not apply old content upscaling"]
  },
  "list": {
    "datasource": "ui\\halox\\main_menu\\main_menu_list",
    "name": "main_menu",
    "rows_visible": 6,
    "wraps": true,
    "row_height_720p": 25,
    "row_pulse_ms": 2000,
    "row_focus_color": [1.0, 1.0, 1.0],
    "row_unfocused_color": [0.698, 0.780, 1.0],
    "row_unfocused_alpha": 0.25,
    "_visibility_note": "The engine drops conditional rows at runtime based on game state. Image-2 (real H3) defaults to 6 visible. We model that here via 'hidden_by_default'; set to false to enable in the mockup.",
    "items": [
      { "id": "start_new_campaign", "label": "START SOLO GAME",       "destination": "campaign_select_difficulty" },
      { "id": "resume_campaign",    "label": "RESUME SOLO GAME",      "destination": "campaign_loading",          "hidden_by_default": true, "_reason": "engine hides until a save file exists" },
      { "id": "campaign",           "label": "CAMPAIGN",              "destination": "pregame_lobby_campaign" },
      { "id": "matchmaking",        "label": "MATCHMAKING",           "destination": "pregame_lobby_matchmaking" },
      { "id": "multiplayer",        "label": "CUSTOM GAMES",          "destination": "pregame_lobby_multiplayer" },
      { "id": "mapeditor",          "label": "FORGE",                 "destination": "pregame_lobby_mapeditor" },
      { "id": "theater",            "label": "THEATER",               "destination": "pregame_lobby_theater" },
      { "id": "locked",             "label": "PLAY THE BETA",         "destination": "alpha_locked_down",         "disabled": true, "hidden_by_default": true, "_reason": "Recon/ODST beta promo only" },
      { "id": "leave_game",         "label": "QUIT TO XBOX DASHBOARD","destination": "_quit",                     "hidden_by_default": true, "_reason": "engine hides off-Xbox" }
    ]
  },
  "button_keys": {
    "main_menu_offline": [ { "glyph": "X", "label": "Settings" } ],
    "main_menu_online":  [ { "glyph": "X", "label": "Settings" }, { "glyph": "Y", "label": "Friends" } ]
  },
  "right_group_chrome": {
    "title_bitmap":  "assets/halo3_logo.png",
    "bungie_bitmap": "assets/bungielogo.png",
    "title_pos_720p":  { "top": 395, "right": 615 },
    "bungie_pos_720p": { "top": 550, "right": 243 }
  },
  "left_group_chrome": {
    "channel_strip":   { "src": "assets/mainmenu_bkd.png",    "top": 364, "left": 78,  "bottom": 595, "right": 385 },
    "bottom_gradient": { "src": "assets/bottom_gradient.png", "top": 595, "left": 78,  "bottom": 640, "right": 385 },
    "channel_blur":    { "src": null, "top": 364, "left": 78, "bottom": 640, "right": 385, "alpha": 0.25 },
    "version_text":    { "top": 533, "left": 78,  "bottom": 563, "right": 373, "font": "body-text", "color": "dim", "justify": "right" },
    "build_text":      { "top": 454, "left": 580, "bottom": 520, "right": 1036, "font": "terminal", "justify": "left" }
  },
  "animations": {
    "_source": "tags\\ui\\halox\\global_animations\\animations\\* and tags\\ui\\halox\\main_menu\\animations\\*",
    "fade_in_250":         { "keyframes": [ [0, 0], [125, 0], [250, 1] ], "property": "alpha" },
    "fade_out_250":        { "keyframes": [ [0, 1], [125, 0], [250, 0] ], "property": "alpha" },
    "delayd_fade_in_250":  { "keyframes": [ [0, 0], [333, 0], [666, 1] ], "property": "alpha" },
    "delayd_fade_out_250": { "keyframes": [ [0, 1], [333, 0], [666, 0] ], "property": "alpha" },
    "slide_up":            { "keyframes": [ [0, [0, 280, 0]], [333, [0, 280, 0]], [666, [0, 0, 0]] ], "property": "position", "_source": "ui\\halox\\main_menu\\animations\\slide_up.gui_widget_position_animation_definition" },
    "slide_down":          { "keyframes": [ [0, [0, 0, 0]], [333, [0, 0, 0]], [666, [0, 280, 0]] ], "property": "position", "_source": "ui\\halox\\main_menu\\animations\\slide_down.gui_widget_position_animation_definition" },
    "lobby_slide_in":      { "keyframes": [ [0, [-540, 0, 0]], [333, [-540, 0, 0]], [666, [0, 0, 0]] ], "property": "position", "_source": "ui\\halox\\pregame_lobby\\animations\\lobby_slide_in.gui_widget_position_animation_definition" },
    "lobby_slide_out":     { "keyframes": [ [0, [0, 0, 0]], [333, [-540, 0, 0]], [666, [-540, 0, 0]] ], "property": "position", "_source": "ui\\halox\\pregame_lobby\\animations\\lobby_slide_out.gui_widget_position_animation_definition" },
    "subtle_pulsate":      { "keyframes": [ [0, 1], [1000, 0.6], [2000, 1] ], "property": "alpha", "loop": "cyclic" },
    "black_fade_in":       { "keyframes": [ [0, 1], [500, 0] ], "property": "alpha" }
  },
  "screen_transitions": {
    "_source": "tags\\ui\\halox\\main_menu\\animations\\mainmenu_slide_up.wacd + tags\\ui\\halox\\main_menu\\animations\\lobby_slide.wacd",
    "_note": "Engine runs `transition-from` on the outgoing screen and `transition-to` on the incoming screen CONCURRENTLY over 666 ms. Each keyframe set has a 333 ms hold + 333 ms motion. Pixel deltas are in 720p coordinates: Y=280 -> 280/720 = 38.89% canvas height; X=540 -> 540/1280 = 42.19% canvas width.",
    "main_menu": {
      "_collection": "ui\\halox\\main_menu\\animations\\mainmenu_slide_up",
      "transition-to":   "slide_up",
      "transition-from": "slide_down"
    },
    "pregame_lobby": {
      "_collection": "ui\\halox\\main_menu\\animations\\lobby_slide",
      "transition-to":   "lobby_slide_in",
      "transition-from": "lobby_slide_out"
    }
  },
  "pregame_lobbies": {
    "_source": "tags\\ui\\halox\\pregame_lobby\\pregame_lobby_template.{scn3,grup} + lobby_list_*.dsrc",
    "_strings_note": "Display labels here are sensible English defaults that match retail H3. Authoritative strings live in pregame_lobby/strings.multilingual_unicode_string_list (binary, not extracted).",
    "template": {
      "_widget_tag": "ui\\halox\\pregame_lobby\\pregame_lobby_template",
      "channel_panel_720p":  { "top": 0,   "left": 79, "bottom": 640, "right": 542 },
      "title_720p":          { "top": 41,  "left": 88, "bottom": 111, "right": 544 },
      "list_origin_720p":    { "top": 85,  "left": 86 },
      "list_row_pitch_720p": 26,
      "visual": {
        "_source": "pregame_lobby_template.grup bitmaps + list.skn3 + lobby_ui_list.lst3 + standard_list.wacd",
        "_css_reference": "D:\\Games\\ElDewrito\\ElDewrito\\ui\\screens\\dialog\\style.css - retail H3 pregame_lobby_template was re-skinned in CEF as the .dialog component, and we mirror that grammar (header strip + blue gradient body + ul.dialog-list with buttonhover.svg focus bar).",
        "_screenshot_reference": "ElDewrito Custom Games Lobby (provided by user 2026-05-25). Shows the rendered pregame_lobby_template - separator above the primary action row (START GAME / FIND GAME / EDIT MAP / PLAY FILM), Ready sub-header + body paragraph, map_image preview + gametype tile, multiplayer_game_name caption.",
        "_differs_from_main_menu": "Main menu uses mainmenu_bkd + bottom_gradient_ui + a header/body/footer flex stack. Lobby uses channel_ui (full-height channel strip), but visually maps to the SAME .dialog header/body/footer pattern in ElDewrito's CEF.",
        "channel_panel": {
          "bitmap": "ui\\halox\\pregame_lobby\\channel_ui",
          "bounds_720p": [0, 79, 640, 542],
          "screen_blur": "ui\\halox\\common\\common_bitmaps\\black_25",
          "fade_overlay": "ui\\halox\\common\\blackness_ui",
          "_export_status": "channel_ui.bitm fails tool.exe export-bitmap-tga; CSS uses an ElDewrito-derived blue gradient (hsl 216deg 70% 17% -> hsl 219deg 70% 8%) plus a backdrop-filter blur to approximate."
        },
        "header_strip": {
          "_css": ".lobby-panel__header (mirrors ElDewrito .dialog-header)",
          "background": "hsl(210deg 30% 10% / 85%)",
          "border": "1px solid rgba(64, 69, 78, 0.85) top + bottom",
          "height_vh": 6.25
        },
        "title": {
          "font": "title",
          "color_preset": "hilite",
          "bounds_720p": [41, 88, 111, 544],
          "_css": ".lobby-title (mirrors ElDewrito .dialog-title - 6.66vh hilite)"
        },
        "body": {
          "_css": ".lobby-panel__body (mirrors ElDewrito .dialog-body)",
          "gradient": "linear-gradient(hsl(216deg 70% 17% / 85%), hsl(219deg 70% 8% / 85%))",
          "font_size_vh": 3.19444,
          "color_preset": "ice"
        },
        "list": {
          "skin": "ui\\halox\\pregame_lobby\\list",
          "list_template": "ui\\halox\\pregame_lobby\\lobby_ui_list",
          "animation": "ui\\halox\\pregame_lobby\\animations\\standard_list",
          "row_pitch_720p": 26,
          "row_text_height_720p": 33,
          "uppercase": true,
          "focus_bitmap": "ui\\halox\\common\\standard_list\\black_bar",
          "row_focus_color": [1.0, 1.0, 1.0],
          "row_unfocused_color": [0.458824, 0.623529, 0.85098],
          "_unfocused_source": "standard_list.wacd ambient-unfocused -> ui\\halox\\global_animations\\animation_definitions\\list_item_unfocused -> blue.wclr",
          "_disabled_unfocused_source": "ui\\halox\\common\\standard_list\\unfocused_listitem.wclr (0.25 alpha â€” disabled rows only)",
          "_css": "ul.lobby-list / .lobby-list__item (mirrors ElDewrito ul.dialog-list - 3.26vh uppercase rows, .hilite class for focus, buttonhover.svg as focus bar). black_bar.bitm and buttonhover.svg are alternate art for the same focused-row strip; ElDewrito's web port uses buttonhover.svg for both main menu and lobby, which the retail screenshot confirms.",
          "_separator_rule": ".lobby-list__item--separated tags the primary action row (start_game / find_game / play_film / edit_map) so it sits below a hairline divider, matching retail."
        },
        "status_block": {
          "_css": ".lobby-status-block - hairline divider on top, hilite Ready sub-header, ice body paragraph",
          "heading_color": "hilite",
          "body_color": "ice"
        },
        "lobby_status": { "font": "body text", "color_preset": "ice" },
        "game_name":    { "font": "body text", "color_preset": "ice" }
      },
      "lobby_status_720p":   { "top": 255, "left": 89, "bottom": 377, "right": 537 },
      "map_image_720p":      { "top": 346, "left": 79, "bottom": 498, "right": 542 },
      "gametype_image_720p": { "top": 356, "left": 90, "bottom": 486, "right": 220 },
      "game_name_720p":      { "top": 500, "left": 89, "bottom": 530, "right": 537 },
      "roster_720p":         { "top": 64,  "right_from_canvas": 437, "_note": "right-edge anchored: bounds 720p=64,843,0,0 -> 1280-843=437px from left, but right-edge anchor pins to right side" },
      "players_in_game_720p": {
        "top": 36, "left": 846, "bottom": 73, "right": 1093,
        "_source": "pregame_lobby_template.grup -> text_widget_block index=1 'players_in_game'. Sits directly above the roster widget. Font=body text, justify=left, color preset=\"\" (default ice). Value identifier is empty; engine pumps the current/max count at runtime.",
        "_css": ".lobby-players (positioned over the roster in the lobby section)",
        "_default_text": "PLAYERS: 1 / 16"
      },
      "roster": {
        "_source": "ui\\halox\\common\\roster\\roster.grup -> roster.lst3 (16 nameplate slots) + roster.skn3 (per-slot skin)",
        "_layout_note": "Halo bounds_2d = (top, left, bottom, right). 0,0 for bottom/right means 'use natural bitmap size'. Slot 'anchor' (local x=0) is where the player name starts; emblem and speaking ring live at NEGATIVE x.",
        "slot_count": 16,
        "slot_pitch_720p": 32,
        "slot_content_extent_720p": { "left": -63, "right": 250, "width": 313, "_note": "ring_of_light at x=-63 is the leftmost element; party_bar_player at x=250 is the rightmost" },
        "slot_anchor_to_panel_left_pct": 20.13,
        "slot_pitch_cqh": 4.4444,
        "skin_elements": {
          "name":              { "kind": "text",   "bounds_720p": { "top": 3,   "left": 0,   "bottom": 33, "right": 202 }, "font": "body text", "justify": "left", "color_preset": "ice",    "_css": ".roster-slot__name" },
          "name_hilite":       { "kind": "text",   "bounds_720p": { "top": -7,  "left": 7,   "bottom": 25, "right": 209 }, "font": "body text", "justify": "left", "color_preset": "hilite", "_css": ".roster-slot__name (focused state)" },
          "service_tag":       { "kind": "text",   "bounds_720p": { "top": 15,  "left": 7,   "bottom": 46, "right": 209 }, "font": "body text", "justify": "left", "uppercase": true,         "_css": ".roster-slot__service-tag" },
          "press_a_to_join":   { "kind": "text",   "bounds_720p": { "top": 3,   "left": -27, "bottom": 35, "right": 240 }, "font": "body text", "color_preset": "dim",                       "_css": ".roster-slot__empty-prompt (data-state=empty)" },
          "looking_for_player":{ "kind": "text",   "bounds_720p": { "top": 3,   "left": 0,   "bottom": 35, "right": 240 }, "font": "body text", "color_preset": "semi_dim",                  "_css": ".roster-slot__searching-text (data-state=searching)" },
          "player_found":      { "kind": "text",   "bounds_720p": { "top": 2,   "left": 0,   "bottom": 35, "right": 240 }, "font": "body text", "color_preset": "white",                     "_css": ".roster-slot__found-text (data-state=found)" },
          "base_color":        { "kind": "bitmap", "bounds_720p": { "top": 0,   "left": -36 }, "bitmap": "ui\\halox\\common\\roster\\roster_unfocused_ui", "_css": ".roster-slot__base" },
          "base_color_hilite": { "kind": "bitmap", "bounds_720p": { "top": -12, "left": -36 }, "bitmap": "ui\\halox\\common\\roster\\roster_focused_ui",   "_css": ".roster-slot__base (data-focused=true)" },
          "player_emblem":     { "kind": "bitmap", "bounds_720p": { "top": 2,   "left": -32, "bottom": 28, "right": -6 }, "bitmap": "ui\\halox\\common\\common_bitmaps\\emblems", "flags": "render_as_player_emblem, scale_to_fit", "_css": ".roster-slot__emblem" },
          "player_emblem_hilite": { "kind": "bitmap", "bounds_720p": { "top": -4, "left": -33, "bottom": 33, "right": 4 }, "bitmap": "ui\\halox\\common\\common_bitmaps\\emblems", "_css": ".roster-slot__emblem (focused)" },
          "rank_tray":         { "kind": "bitmap", "bounds_720p": { "top": 0,   "left": 193 }, "bitmap": "ui\\halox\\common\\roster\\rank_tray_ui",  "_css": ".roster-slot__rank-tray" },
          "rank_tray_hilite":  { "kind": "bitmap", "bounds_720p": { "top": -8,  "left": 193 }, "bitmap": "ui\\halox\\common\\roster\\rank_tray_ui",  "sprite_frame": 1, "_css": ".roster-slot__rank-tray (focused)" },
          "skill_level":       { "kind": "bitmap", "bounds_720p": { "top": 5,   "left": 200 }, "bitmap": "ui\\halox\\common\\roster\\lvl_sm_ui",    "_css": ".roster-slot__skill" },
          "skill_level_hilite":{ "kind": "bitmap", "bounds_720p": { "top": 5,   "left": 201 }, "bitmap": "ui\\halox\\common\\roster\\lvl_sm_ui",    "_css": ".roster-slot__skill (focused)" },
          "experience":        { "kind": "bitmap", "bounds_720p": { "top": 3,   "left": 226, "bottom": 27, "right": 243 }, "bitmap": "ui\\halox\\common\\roster\\exp_med_ui",   "_css": ".roster-slot__exp" },
          "experience_hilite": { "kind": "bitmap", "bounds_720p": { "top": 0,   "left": 225, "bottom": 30, "right": 246 }, "bitmap": "ui\\halox\\common\\roster\\exp_med_ui",   "_css": ".roster-slot__exp (focused)" },
          "party_bar_player":  { "kind": "bitmap", "bounds_720p": { "top": 0,   "left": 250 }, "bitmap": "ui\\halox\\common\\roster\\partybar_ui",  "_css": ".roster-slot__party-bar" },
          "ring_of_light":     { "kind": "bitmap", "bounds_720p": { "top": 3,   "left": -63 }, "bitmap": "ui\\halox\\common\\roster\\ringspeak_ui", "_css": ".roster-slot__ring (data-speaking=true)" },
          "outer_ring":        { "kind": "bitmap", "bounds_720p": { "top": 3,   "left": -31 }, "bitmap": "ui\\halox\\common\\roster\\outer_ring_ui", "_css": ".roster-slot__ring-outer (searching)" },
          "middle_ring":       { "kind": "bitmap", "bounds_720p": { "top": 7,   "left": -27 }, "bitmap": "ui\\halox\\common\\roster\\middle_ring_ui", "_css": ".roster-slot__ring-middle (searching)" },
          "party_up":          { "kind": "bitmap", "bounds_720p": { "top": 0,   "left": -36 }, "bitmap": "ui\\halox\\common\\roster\\roster_flashy_ui", "_css": ".roster-slot__party-up (party-up flash)" },
          "check":             { "kind": "bitmap", "bounds_720p": { "top": 3,   "left": -90 }, "bitmap": "ui\\halox\\common\\roster\\blankcheck_ui",    "_css": ".roster-slot__check" },
          "player_found_bitmap": { "kind": "bitmap", "bounds_720p": { "top": 0, "left": -36 }, "bitmap": "ui\\halox\\common\\roster\\matchmaking", "sprite_frame": 1, "_css": ".roster-slot__found-bitmap" },
          "looking_for_player_bitmap": { "kind": "bitmap", "bounds_720p": { "top": 0, "left": -36 }, "bitmap": "ui\\halox\\common\\roster\\matchmaking", "sprite_frame": 0, "_css": ".roster-slot__searching-bitmap" }
        },
        "states": {
          "empty":     "press_a_to_join + dimmed base_color",
          "filled":    "name + service_tag + emblem + rank_tray + skill_level + experience + party_bar visible",
          "focused":   "swap to base_color_hilite + name_hilite + player_emblem_hilite + rank_tray_hilite",
          "speaking":  "ring_of_light fades in (left of emblem)",
          "searching": "outer_ring + middle_ring rotate while 'LOOKING FOR PLAYER' text shows",
          "found":     "matchmaking checkmark + 'PLAYER FOUND' text in white"
        },
        "_export_status": "Tag XML exported to exported/roster_nameplate_tags_xml/. Bitmaps exported to assets/roster/ â€” all are RGBA WHITE ALPHA MASKS (RGB=255,255,255, alpha varies) that the engine tints at runtime, so the CSS uses them as mask-image with a colored layer underneath.",
        "exported_bitmaps": {
          "roster_unfocused_ui": { "file": "assets/roster/roster_unfocused_ui.png", "size_px": [284, 31], "mode": "RGBA alpha mask (white)",  "_note": "Base nameplate strip. 31px tall matches our 32px slot pitch exactly. Alpha is brightest at the top and fades to transparent at the bottom, giving the angled-bottom look retail H3 has." },
          "roster_focused_ui":   { "file": "assets/roster/roster_focused_ui.png",   "size_px": [286, 228], "mode": "RGBA alpha mask (black)", "_note": "Focused-state halo. Much taller than a single row (228 ~= 7 rows worth) - it's the soft black halo that bleeds above/below the focused row." },
          "rank_tray_ui":        { "file": "assets/roster/rank_tray_ui.png",        "size_px": [114, 48],  "mode": "L (greyscale)",          "_note": "Rank tray angular shape, recolored by the engine. 48px tall = bleeds 8px above + 8px below a 32px row." },
          "partybar_ui":         { "file": "assets/roster/partybar_ui.png",         "size_px": [48, 962],  "mode": "RGBA alpha mask",        "_note": "Tall sprite sheet of party-bar states (multiple frames stacked vertically)." },
          "exp_med_ui":          { "file": "assets/roster/exp_med_ui.png",          "size_px": [418, 212], "mode": "RGBA alpha mask",        "_note": "Sprite sheet of exp meter frames." },
          "lvl_sm_ui":           { "file": "assets/roster/lvl_sm_ui.png",           "size_px": [250, 122], "mode": "RGBA alpha mask",        "_note": "Sprite sheet of skill level icons (chevrons/numerals)." },
          "ringspeak_ui":        { "file": "assets/roster/ringspeak_ui.png",        "size_px": [82, 112],  "mode": "RGBA alpha mask",        "_note": "Speaking-ring frames." }
        },
        "_base_render_rule": "base_color is unconditional â€” ALL 16 slots render the roster_unfocused_ui strip the same way, whether empty or filled. The 'PRESS A TO JOIN' text widget just overlays on top of the same strip for empty slots; no separate dimmed treatment for the strip itself."
      },
      "button_keys": [
        { "glyph": "B", "label": "Back" },
        { "glyph": "X", "label": "Settings" },
        { "glyph": "Y", "label": "Roster" }
      ]
    },
    "modes": {
      "campaign": {
        "title": "CAMPAIGN",
        "game_name": "The Storm  -  Heroic",
        "lobby_status": "Select a level and difficulty, then START GAME to begin the mission.",
        "datasource": "ui\\halox\\pregame_lobby\\lobby_list_campaign",
        "show_preview": true,
        "items": [
          { "id": "switch_lobby",                "label": "CHANGE LOBBY", "value": "" },
          { "id": "select_network_mode",         "label": "NETWORK",      "value": "Offline",   "target": "network_mode" },
          { "id": "switch_campaign_level",       "label": "LEVEL",        "value": "The Storm", "target": "level" },
          { "id": "switch_campaign_difficulty",  "label": "DIFFICULTY",   "value": "Heroic",    "target": "difficulty" },
          { "id": "start_game",                  "label": "START GAME",   "value": "" }
        ]
      },
      "matchmaking": {
        "title": "MATCHMAKING",
        "game_name": "Team Slayer Playlist",
        "lobby_status": "Select a playlist and FIND GAME to be matched with other players.",
        "datasource": "ui\\halox\\pregame_lobby\\lobby_list_matchmaking",
        "show_preview": false,
        "items": [
          { "id": "switch_lobby",              "label": "CHANGE LOBBY", "value": "" },
          { "id": "select_network_mode",       "label": "NETWORK",      "value": "Xbox LIVE",    "target": "network_mode" },
          { "id": "switch_matchmaking_hopper", "label": "PLAYLIST",     "value": "Team Slayer",  "target": "hopper" },
          { "id": "start_game",                "label": "FIND GAME",    "value": "" }
        ]
      },
      "multiplayer": {
        "title": "CUSTOM GAMES",
        "game_name": "Slayer on Valhalla",
        "lobby_status": "Use the menu to select a map and game variant, then START GAME when ready.",
        "datasource": "ui\\halox\\pregame_lobby\\lobby_list_multiplayer",
        "show_preview": true,
        "items": [
          { "id": "switch_lobby",            "label": "CHANGE LOBBY", "value": "" },
          { "id": "select_network_mode",     "label": "NETWORK",      "value": "Xbox LIVE", "target": "network_mode" },
          { "id": "switch_multiplayer_game", "label": "GAME",         "value": "Slayer",    "target": "variant" },
          { "id": "switch_multiplayer_map",  "label": "MAP",          "value": "Valhalla",  "target": "map" },
          { "id": "start_game",              "label": "START GAME",   "value": "" }
        ]
      },
      "mapeditor": {
        "title": "FORGE",
        "game_name": "Foundry  -  Forge",
        "lobby_status": "Choose a map to edit in Forge, then EDIT MAP to enter the editor.",
        "datasource": "ui\\halox\\pregame_lobby\\lobby_list_mapeditor",
        "show_preview": true,
        "items": [
          { "id": "switch_lobby",          "label": "CHANGE LOBBY", "value": "" },
          { "id": "select_network_mode",   "label": "NETWORK",      "value": "System Link", "target": "network_mode" },
          { "id": "switch_mapeditor_map",  "label": "MAP",          "value": "Foundry",     "target": "map" },
          { "id": "start_game",            "label": "EDIT MAP",     "value": "" }
        ]
      },
      "theater": {
        "title": "THEATER",
        "game_name": "Last Match  -  Theater",
        "lobby_status": "Choose a film clip from your saved files, then PLAY FILM to watch it.",
        "datasource": "ui\\halox\\pregame_lobby\\lobby_list_theater",
        "show_preview": false,
        "items": [
          { "id": "switch_lobby",        "label": "CHANGE LOBBY", "value": "" },
          { "id": "select_network_mode", "label": "NETWORK",      "value": "Offline",    "target": "network_mode" },
          { "id": "switch_film",         "label": "FILM",         "value": "Last Match", "target": "film" },
          { "id": "start_game",          "label": "PLAY FILM",    "value": "" }
        ]
      }
    }
  },
  "navigation_table": {
    "_source": "tags\\ui\\main_menu.user_interface_globals_definition - halox screen widgets block",
    "main_menu": "ui\\halox\\main_menu\\main_menu",
    "start_menu": "ui\\halox\\start_menu\\start_menu",
    "campaign_select_difficulty": "ui\\halox\\campaign\\campaign_select_difficulty",
    "campaign_select_level": "ui\\halox\\campaign\\campaign_select_level",
    "campaign_loading": "ui\\halox\\campaign\\campaign_loading",
    "pregame_lobby_campaign": "ui\\halox\\pregame_lobby\\pregame_lobby_campaign",
    "pregame_lobby_matchmaking": "ui\\halox\\pregame_lobby\\pregame_lobby_matchmaking",
    "pregame_lobby_multiplayer": "ui\\halox\\pregame_lobby\\pregame_lobby_multiplayer",
    "pregame_lobby_mapeditor": "ui\\halox\\pregame_lobby\\pregame_lobby_mapeditor",
    "pregame_lobby_theater": "ui\\halox\\pregame_lobby\\pregame_lobby_theater",
    "game_browser": "ui\\halox\\game_browser\\game_browser",
    "alpha_legal": "ui\\halox\\alpha_legal\\alpha_legal",
    "alpha_locked_down": "ui\\halox\\alpha_locked_down\\alpha_locked_down",
    "alert_nonblocking": "ui\\halox\\alert\\alert_nonblocking",
    "dialog": "ui\\halox\\dialog\\dialog"
  }
}
;
