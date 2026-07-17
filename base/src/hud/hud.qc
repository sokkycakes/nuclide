

#include "hud.h"
#include "WeaponSelect.h"

HLWeaponSelect weaponSelectionHUD;
var bool g_spritesLoaded;

#define SPRITE_OK(s) ((s) > 0)
#define SPRFRAME_OK(s) ((s) != "" && (s) != __NULL__)

void
HLHUD_AmmoNotify_Draw(__inout vector pos)
{
	pos[0] = g_hudMins[0] + g_hudRes[0] - 40;

	for (int i = 0; i < AMMO_COUNT; i++) {
		float a;

		if (g_ammonotify[i].alpha <= 0.0f) {
			g_ammonotify[i].count = 0;
			continue;
		}

		a = bound(0, g_ammonotify[i].alpha, 1.0);
		pos -= [0, 32 * a];

		if (g_spritesLoaded && SPRFRAME_OK(g_hud7_spr)) {
			vector srcpos = g_ammotype[i];
			draw.SubPic(pos,
				[24,24],
				g_hud7_spr,
				srcpos,
				[24/256, 24/128],
				g_fg_color,
				a,
				DRAWFLAG_ADDITIVE
			);
		}

		drawfont = (float)FONT_20.iID;
		string txt = sprintf("%i", g_ammonotify[i].count);
		float offs = stringwidth(txt, FALSE, [20,20]);
		draw.Text_RGBA(pos + [-offs - 8,4], txt, g_fg_color, a, FONT_20);

		g_ammonotify[i].alpha -= (clframetime * 0.5);
	}
}

void
HLHUD_AmmoNotify_Insert(int type, int count)
{
	if (count <= 0)
		return;

	if (type == 7 && count < 8) // hornet hack!
		return;

	g_ammonotify[type].count += count;
	g_ammonotify[type].alpha = 2.5f;

}

void
HLHUD_DamageNotifyDraw(vector hudmins, vector res)
{
	if (!g_spritesLoaded || !SPRFRAME_OK(g_dmg1_spr)) {
		return;
	}

	vector pos = hudmins + [16, res[1] - 128];

	for (int i = 0; i < DMG_COUNT; i++) {
		vector srcpos;
		float a;

		if (g_dmgnotify[i].alpha <= 0.0f) {
			continue;
		}

		srcpos = g_dmgtype[i];
		a = (sin(cltime * 2.5) * 0.5) + 0.5;
		a *= bound(0.0f, g_dmgnotify[i].alpha, 1.0);

		if (i < 4)
			draw.SubPic(pos, [64,64], g_dmg1_spr, srcpos, [64/256, 64/64], g_fg_color, a, DRAWFLAG_ADDITIVE);
		else
			draw.SubPic(pos, [64,64], g_dmg2_spr, srcpos, [64/256, 64/64], g_fg_color, a, DRAWFLAG_ADDITIVE);

		g_dmgnotify[i].alpha -= (clframetime * 2.0);
		pos -= [0, 64];
	}
}


void
HLHUD_ItemNotify_Draw(__inout vector pos)
{
	pos[0] = g_hudMins[0] + g_hudRes[0] - 44;

	for (int i = 0; i < ITEM_COUNT; i++) {
		float a;

		if (g_itemnotify[i].alpha <= 0.0f) {
			g_itemnotify[i].count = 0;
			continue;
		}

		a = bound(0, g_itemnotify[i].alpha, 1.0);
		pos -= [0, 52 * a];

		if (g_spritesLoaded && SPRFRAME_OK(g_hud2_spr)) {
			vector srcpos = g_itemtype[i];
			draw.SubPic(pos + [-20,0], [44,44], g_hud2_spr, srcpos, [44/256, 44/256], g_fg_color, a, DRAWFLAG_ADDITIVE);
		}

		if (g_itemnotify[i].count > 1) {
			drawfont = (float)FONT_20.iID;
			string txt = sprintf("%i", g_itemnotify[i].count);
			float offs = stringwidth(txt, FALSE, [20,20]) + 16;
			draw.Text_RGBA(pos + [-offs - 8,12], txt, g_fg_color, a, FONT_20);
		}

		g_itemnotify[i].alpha -= (clframetime * 0.5);
	}
}

void
HLHUD_ItemNotify_Insert(int type, int count)
{
	if (count <= 0) {
		return;
	}

	g_itemnotify[type].count += count;
	g_itemnotify[type].alpha = 2.5f;

}

void
HUD_PickedUpItem(string itemClass)
{
	switch (itemClass) {
	case "item_battery":
		HLHUD_ItemNotify_Insert(0i, 1i);
		break;
	case "item_healthkit":
		HLHUD_ItemNotify_Insert(1i, 1i);
		break;
	case "item_longjump":
		HLHUD_ItemNotify_Insert(2i, 1i);
		break;
	}
}


void
HLHUD_UpdateTimers(float health, float armor, float clip, float ammo1, float ammo2)
{
	if (health != g_oldHealth) {
		g_healthAlpha = 1.0;
	}
	if (armor != g_oldArmor) {
		g_armorAlpha = 1.0;
	}
	if (clip != g_oldClip) {
		g_clipAlpha = 1.0;
	}
	if (ammo1 != g_oldAmmo1) {
		g_ammo1Alpha = 1.0;
	}
	if (ammo2 != g_oldAmmo2) {
		g_ammo2Alpha = 1.0;
	}

	g_oldHealth = health;
	g_oldArmor = armor;
	g_oldClip = clip;
	g_oldAmmo1 = ammo1;
	g_oldAmmo2 = ammo2;
}

void
HLHUD_ClampTimers()
{
	g_healthAlpha = bound(g_fg_alpha, g_healthAlpha - (clframetime * 0.5), 1.0);
	g_armorAlpha = bound(g_fg_alpha, g_armorAlpha - (clframetime * 0.5), 1.0);
	g_clipAlpha = bound(g_fg_alpha, g_clipAlpha - (clframetime * 0.5), 1.0);
	g_ammo1Alpha = bound(g_fg_alpha, g_ammo1Alpha - (clframetime * 0.5), 1.0);
	g_ammo2Alpha = bound(g_fg_alpha, g_ammo2Alpha - (clframetime * 0.5), 1.0);
	g_ammoDisplayAlpha = bound(0.0, g_ammoDisplayAlpha - (clframetime * 5), 1.0);
	g_damageAlpha = bound(0.0, g_damageAlpha - (clframetime * 1), 1.0);
}

void
HLHUD_BigNums(vector pos, string numString, float alpha)
{
	if (alpha > g_fg_alpha) {
		float backAlpha = bound(0.0f, alpha - g_fg_alpha, 1.0f);
		draw.Text_RGBA(pos + [random(-2,2), 0], numString, g_fg_color, backAlpha, FONT_20);
		draw.Text_RGBA(pos, numString, g_fg_color, alpha, FONT_20);
	} else
		draw.Text_RGBA(pos, numString, g_fg_color, alpha, FONT_20);
}

void
HUD_Init(void)
{
	for (int i = 0; i < 61i; i++) {
		g_spriteSheets[i] = atlasPic.Load(g_hlSpriteNames[i]);
	}

	g_spritesLoaded = SPRITE_OK(g_spriteSheets[S_CROSS]);

	weaponSelectionHUD = spawn(HLWeaponSelect);
	g_spriteCrosshair = -1i;
}

void
HUD_ReloadVideoResources(void)
{
	font.Load("fonts/font20.font", FONT_20);
	font.Load("fonts/chat.font", FONT_CHAT);

#if 0
	font.Load("fonts/chat.font", FONT_20);
	font.Load("fonts/weaponicon.font", FONT_WEAPONICON);
	font.Load("fonts/weaponicon_sel.font", FONT_WEAPONICON_SEL);
	font.Load("fonts/weapontext.font", FONT_WEAPONTEXT);
	font.Load("fonts/weaponnumbers.font", FONT_WEAPONNUM);
	font.Load("fonts/weaponnumbers_blurry.font", FONT_WEAPONNUMB);
#endif

	g_hud1_spr = precache.SpriteFrame("sprites/640hud1.spr", 0, 0.0f);
	g_hud2_spr = precache.SpriteFrame("sprites/640hud2.spr", 0, 0.0f);
	g_hud3_spr = precache.SpriteFrame("sprites/640hud3.spr", 0, 0.0f);
	g_hud4_spr = precache.SpriteFrame("sprites/640hud4.spr", 0, 0.0f);
	g_hud5_spr = precache.SpriteFrame("sprites/640hud5.spr", 0, 0.0f);
	g_hud6_spr = precache.SpriteFrame("sprites/640hud6.spr", 0, 0.0f);
	g_hud7_spr = precache.SpriteFrame("sprites/640hud7.spr", 0, 0.0f);

	g_damage_spr_t = precache.SpriteFrame("sprites/640_pain.spr", 0, 0.0f);
	g_damage_spr_r = precache.SpriteFrame("sprites/640_pain.spr", 1, 0.0f);
	g_damage_spr_b = precache.SpriteFrame("sprites/640_pain.spr", 2, 0.0f);
	g_damage_spr_l = precache.SpriteFrame("sprites/640_pain.spr", 3, 0.0f);

	g_dmg1_spr = precache.SpriteFrame("sprites/640hud8.spr", 0, 0.0f);
	g_dmg2_spr = precache.SpriteFrame("sprites/640hud9.spr", 0, 0.0f);
}

void
HLHUD_DrawNumber(int iNumber, vector vecPos, float fAlpha, vector vColor)
{
	atlasPic.Draw_RGBA(
		g_spriteSheets[S_NUMBER_0 + iNumber],
		vecPos,
		vColor * fAlpha,
		g_fg_alphaScale, 
		true
	);
}

void
HLHUD_DrawNums(float fNumber, vector vecPos, float fAlpha, vector vColor)
{
	int iNumber = fNumber;
	if (iNumber > 0) {
		while (iNumber > 0) {
			HLHUD_DrawNumber((float)iNumber % 10, vecPos, fAlpha, vColor);
			iNumber = iNumber / 10;
			vecPos[0] -= 20;
		} 
	} else {
		HLHUD_DrawNumber(0, vecPos, fAlpha, vColor);
	}
}

void
HLHUD_DrawHealth(vector pos, float healthValue)
{
	vector col = (healthValue > 25) ? g_fg_color : [1,0,0];
	float alpha = g_healthAlpha;

	if (g_spritesLoaded && SPRITE_OK(g_spriteSheets[S_CROSS])) {
		atlasPic.Draw_RGBA(g_spriteSheets[S_CROSS], pos + [-72,-4], col * alpha, g_fg_alphaScale, true);
		HLHUD_DrawNums(healthValue, pos, alpha, col);
	} else {
		drawfont = (float)FONT_20.iID;
		draw.Text_RGBA(pos + [-20, 0], sprintf("HP:%i", (int)healthValue), col, alpha, FONT_20);
	}
}

void
HLHUD_DrawArmor(vector pos, float armorValue)
{
	if (g_spritesLoaded && SPRITE_OK(g_spriteSheets[S_SUIT_EMPTY])) {
		atlasPic.Draw_RGBA(g_spriteSheets[S_SUIT_EMPTY], pos + [-80,-9], g_fg_color * g_armorAlpha, g_fg_alphaScale, true);
		if (armorValue > 0) {
			float perc = bound(0, (armorValue / 100), 1.0);
			atlasPic.DrawBottom_RGBA(g_spriteSheets[S_SUIT_FULL], pos + [-80,-9], perc, g_fg_color * g_armorAlpha, g_fg_alphaScale, true);
		}
		HLHUD_DrawNums(armorValue, pos, g_armorAlpha, g_fg_color);
	} else {
		drawfont = (float)FONT_20.iID;
		draw.Text_RGBA(pos + [-20, 0], sprintf("AR:%i", (int)armorValue), g_fg_color, g_armorAlpha, FONT_20);
	}
}

void
HLHUD_DrawFlashlight(vector pos, float sprintValue)
{
	if (g_spritesLoaded && SPRITE_OK(g_spriteSheets[S_FLASH_EMPTY])) {
		atlasPic.Draw_RGBA(g_spriteSheets[S_FLASH_EMPTY], pos, g_fg_color * g_armorAlpha, g_fg_alphaScale, true);
		if (sprintValue > 0 || player.IsSprinting()) {
			atlasPic.DrawLeft_RGBA(g_spriteSheets[S_FLASH_FULL], pos, sprintValue, g_fg_color * g_armorAlpha, g_fg_alphaScale, true);
			if (player.IsSprinting()) {
				atlasPic.Draw_RGBA(g_spriteSheets[S_FLASH_BEAM], pos + [32, 0], g_fg_color * g_armorAlpha, g_fg_alphaScale, true);
			}
		}
	} else {
		if (player.IsSprinting()) {
			drawfont = (float)FONT_20.iID;
			draw.Text_RGBA(pos, "FLASH", g_fg_color, g_armorAlpha, FONT_20);
		}
	}
}

void
HLHUD_DrawObituaries(vector drawAtPos, bool rightAlign)
{
	if (g_killMsgTime < time && g_killMsgCount > 0i) {
		for (int i = 0i; i < (KILLMESSAGE_LIMIT-1i); i++) {
			g_killMsgRecord[i].m_target = g_killMsgRecord[i+1].m_target;
			g_killMsgRecord[i].m_attacker = g_killMsgRecord[i+1].m_attacker;
			g_killMsgRecord[i].m_icon = g_killMsgRecord[i+1].m_icon;
		}

		g_killMsgRecord[KILLMESSAGE_LIMIT-1].m_target = "";
		g_killMsgRecord[KILLMESSAGE_LIMIT-1].m_attacker = "";
		g_killMsgRecord[KILLMESSAGE_LIMIT-1].m_icon = -1;

		g_killMsgTime = time + KILLMESSAGE_TIME;
		g_killMsgCount--;
	}

	if (g_killMsgCount <= 0i) {
		return;
	}

	drawAtPos += g_hudMins;

	for (int i = 0i; i < g_killMsgCount; i++) {
		float m_ofs1 = font.StringWidth(g_killMsgRecord[i].m_target, true, FONT_CHAT);
		float m_ofs2 = atlasPic.GetWidth(g_killMsgRecord[i].m_icon);
		float m_padding = 8.0f;

		if (rightAlign == true) {
			draw.RText(drawAtPos, g_killMsgRecord[i].m_target, FONT_CHAT);
			atlasPic.Draw_RGBA(
				g_killMsgRecord[i].m_icon,
				[drawAtPos[0] - (m_ofs1 + m_padding + m_ofs2), drawAtPos[1]],
				g_fg_color * HUD_ALPHA,
				g_fg_alphaScale, 
				true
			);
			draw.RText([drawAtPos[0] - (m_ofs1 + m_padding + m_ofs2 + m_padding), drawAtPos[1]], g_killMsgRecord[i].m_attacker, FONT_CHAT);
		} else {
			draw.Text(drawAtPos, g_killMsgRecord[i].m_target, FONT_CHAT);
			atlasPic.Draw_RGBA(
				g_killMsgRecord[i].m_icon,
				drawAtPos,
				g_fg_color * HUD_ALPHA,
				g_fg_alphaScale, 
				true
			);
			draw.Text(drawAtPos, g_killMsgRecord[i].m_attacker, FONT_CHAT);
		}
		drawAtPos[1] += font.GetHeight(FONT_CHAT) + m_padding;
	}
}

void
HUD_DrawSeperator(vector vecPos)
{
	if (g_spritesLoaded && SPRITE_OK(g_spriteSheets[S_DIVIDER])) {
		atlasPic.Draw_RGBA(g_spriteSheets[S_DIVIDER], vecPos - [0, 7], g_fg_color * HUD_ALPHA, g_fg_alphaScale, true);
	} else {
		vector c = g_fg_color * HUD_ALPHA;
		draw.Line(1.0f, vecPos + [0, -7], vecPos + [30, -7], c, 1.0f);
	}
}

void
HLHUD_DrawAmmo1(vector pos, float ammoValue)
{
	if (g_spritesLoaded && SPRITE_OK(g_spriteSheets[S_NUMBER_0])) {
		HLHUD_DrawNums(ammoValue, pos, g_clipAlpha, g_fg_color);
		HUD_DrawSeperator(pos + [30,0]);
	} else {
		drawfont = (float)FONT_20.iID;
		draw.Text_RGBA(pos + [30, 0], sprintf("CLIP:%i", (int)ammoValue), g_fg_color, g_clipAlpha, FONT_20);
	}
}

void
HLHUD_DrawAmmo2(vector pos, float ammoValue)
{
	if (g_spritesLoaded && SPRITE_OK(g_spriteSheets[S_NUMBER_0])) {
		HLHUD_DrawNums(ammoValue, pos, g_ammo1Alpha, g_fg_color);
	} else {
		drawfont = (float)FONT_20.iID;
		draw.Text_RGBA(pos, sprintf("AM1:%i", (int)ammoValue), g_fg_color, g_ammo1Alpha, FONT_20);
	}
}

void
HLHUD_DrawAmmo3(vector pos, float ammoValue)
{
	if (g_spritesLoaded && SPRITE_OK(g_spriteSheets[S_NUMBER_0])) {
		HLHUD_DrawNums(ammoValue, pos, g_ammo2Alpha, g_fg_color);
	} else {
		drawfont = (float)FONT_20.iID;
		draw.Text_RGBA(pos, sprintf("AM2:%i", (int)ammoValue), g_fg_color, g_ammo2Alpha, FONT_20);
	}
}

/* WebCore HTML HUD overlay (second decoder view). Gate: webcore_hud 1 */
var float autocvar_webcore_hud = 0;
var string autocvar_webcore_hud_url = "fte://data/web/webcore-test/hud-smoke.html";
var float g_webcoreHudAlive;

void
WebCoreHud_Shutdown(void)
{
	if (g_webcoreHudAlive) {
		gecko_destroy("webcore_hud");
		g_webcoreHudAlive = 0;
	}
}

void
WebCoreHud_Ensure(void)
{
	string media;

	if (g_webcoreHudAlive)
		return;

	media = sprintf("webcore:%s", autocvar_webcore_hud_url);
	if (gecko_create("webcore_hud", media)) {
		gecko_navigate("webcore_hud", "cmd:transparent");
		g_webcoreHudAlive = 1;
	}
}

void
WebCoreHud_Draw(void)
{
	if (autocvar_webcore_hud <= 0) {
		WebCoreHud_Shutdown();
		return;
	}

	WebCoreHud_Ensure();
	if (!g_webcoreHudAlive)
		return;

	gecko_resize("webcore_hud", g_hudRes[0], g_hudRes[1]);
	drawpic(g_hudMins, "webcore_hud", g_hudRes, [1, 1, 1], 1, 0);
}

void
HUD_Draw(void)
{
	vector pos;
	vector hud_mins, hud_size;
	float armorValue  = player.GetArmor();
	float healthValue = player.GetHealth();
	int teamID = player.GetTeam();
	float clipValue = weapon.GetClip();
	float ammoValue = weapon.GetAmmo1();
	float ammoValue2 = weapon.GetAmmo2();
	float staminaValue = 1.0 - player.GetStamina();

	g_hudMins = hud_mins = screen.HUDMins();
	g_hudRes = hud_size = screen.HUDSize();

	HLHUD_UpdateTimers(healthValue, armorValue, clipValue, ammoValue, ammoValue2);
	HLHUD_DamageNotifyDraw(hud_mins, hud_size);

	if (1) {
		pos = g_hudMins + [g_hudRes[0] - 192, g_hudRes[1] - 128];
		pos[1] += 48;
		HLHUD_ItemNotify_Draw(pos);
		HLHUD_AmmoNotify_Draw(pos);
	}

	HLHUD_DrawObituaries([g_hudRes[0] - 16, 48], true);

	if (g_damageAlpha > 0.0f) {
		vector center;
		vector rel_pos;
		float fw, fw_alpha;
		float rt, rt_alpha;

		center = hud_mins + (hud_size / 2);

		vector playerPosition = player.GetCameraPosition();
		vector playerAngle = player.GetCameraAngles();
		playerPosition[2] = g_damageLocation[2];
		rel_pos = vectorNormalize(g_damageLocation - playerPosition);
		fw = vectorDot(rel_pos, anglesToForward(playerAngle));
		rt = vectorDot(rel_pos, anglesToRight(playerAngle));

		fw_alpha = fabs(fw) * g_damageAlpha;
		if (fw > 0.25f) {
			if (g_spritesLoaded && SPRFRAME_OK(g_damage_spr_t)) {
				draw.Pic(center + [-64,-102], g_damage_spr_t,
					[128,48], [1,1,1], fw_alpha, DRAWFLAG_ADDITIVE);
			} else {
				draw.Text_RGBA(center + [-64,-102], "FRONT", [1,0,0], fw_alpha, FONT_20);
			}
		} else if (fw < -0.25f) {
			if (g_spritesLoaded && SPRFRAME_OK(g_damage_spr_b)) {
				draw.Pic(center + [-64,70], g_damage_spr_b,
					[128,48], [1,1,1], fw_alpha, DRAWFLAG_ADDITIVE);
			} else {
				draw.Text_RGBA(center + [-64,70], "BACK", [1,0,0], fw_alpha, FONT_20);
			}
		}

		rt_alpha = fabs(rt) * g_damageAlpha;
		if (rt > 0.25f) {
			if (g_spritesLoaded && SPRFRAME_OK(g_damage_spr_r)) {
				draw.Pic(center + [70,-64], g_damage_spr_r,
					[48,128], [1,1,1], rt_alpha, DRAWFLAG_ADDITIVE);
			} else {
				draw.Text_RGBA(center + [70,-64], "RIGHT", [1,0,0], rt_alpha, FONT_20);
			}
		} else if (rt < -0.25f) {
			if (g_spritesLoaded && SPRFRAME_OK(g_damage_spr_l)) {
				draw.Pic(center + [-102,-64], g_damage_spr_l,
					[48,128], [1,1,1], rt_alpha, DRAWFLAG_ADDITIVE);
			} else {
				draw.Text_RGBA(center + [-102,-64], "LEFT", [1,0,0], rt_alpha, FONT_20);
			}
		}

		if (autocvar_cg_damageFill > 0.0) {
			vector screenSize = screen.Size();
			vector finalColor = [1,1,1];
			finalColor[1] = finalColor[2] = 1.0 - (g_damageAlpha * autocvar_cg_damageFill);
			draw.Pic(screen.Mins(), "fade_modulate", screenSize, finalColor, 1.0, DRAWFLAG_NORMAL);
		}

		g_damageAlpha -= clframetime;
	}

	pos = hud_mins + [88, hud_size[1] - 42];
	HLHUD_DrawHealth(pos, healthValue); 
	pos = hud_mins + [198, hud_size[1] - 42];
	HLHUD_DrawArmor(pos, armorValue);

	weaponSelectionHUD.Draw();

	if (g_spriteCrosshair != -1i && g_spritesLoaded) {
		atlasPic.DrawCrosshair(g_spriteCrosshair);
	} else {
		vector crosshairPos = hud_mins + (hud_size / 2);
		drawfont = (float)FONT_20.iID;
		draw.Text_RGBA(crosshairPos + [0, 0], "+", g_fg_color, g_fg_alphaScale, FONT_20);
	}

	pos = hud_mins + [hud_size[0] - 52, 16];
	HLHUD_DrawFlashlight(pos, staminaValue);

	if (weapon.AmmoRequired() == false) {
		HLHUD_ClampTimers();
		/* Still composite WebCore HUD (melee / ammoRequired 0). */
		WebCoreHud_Draw();
		return;
	}

	/* ammo displays */

	/* ammo 2 */
	if (weapon.UsesSecondaryAmmo() == true) {
		pos = hud_mins + [hud_size[0] - 72, hud_size[1] - 74];
		HLHUD_DrawAmmo3(pos, ammoValue2);
	}

	pos = hud_mins + [hud_size[0] - 48, hud_size[1] - 42];

	if (g_spritesLoaded && SPRITE_OK(g_spriteAmmoIcon)) {
		atlasPic.Draw_RGBA(g_spriteAmmoIcon, pos, g_fg_color, g_fg_alphaScale, true);
	} else {
		drawfont = (float)FONT_20.iID;
		draw.Text_RGBA(pos, weapon.GetTitle(), g_fg_color, g_fg_alphaScale, FONT_20);
	}

	if (weapon.GetClipSize() > 0) {
		pos = hud_mins + [hud_size[0] - 152, hud_size[1] - 42];
		HLHUD_DrawAmmo1(pos, clipValue);
	}

	pos = hud_mins + [hud_size[0] - 72, hud_size[1] - 42];
	HLHUD_DrawAmmo2(pos, ammoValue);

	HLHUD_ClampTimers();

	/* Letterboxed WebCore HUD last so it composites over HudC chrome. */
	WebCoreHud_Draw();
}

/* Framework chrome (watching bar, top bar, timer/score, key hints,
   observer crosshair) is drawn by src/client/hud.qc before this runs.
   This is the game-specific extension point; derive the letterboxed rect
   via screen.HUDMins()/screen.HUDSize() if adding extras here. */
void
HUD_DrawSpectator(void)
{

}

void
HUD_WeaponSwitched(string weaponName)
{
	g_spriteAmmoIcon = atlasPic.Load(strcat(weaponName, ".ammo"));
	g_spriteCrosshair = atlasPic.Load(strcat(weaponName, ".crosshair"));
	g_ammoDisplayAlpha = 1.0f;
}

float
HUD_InputFrame(float inputButtons)
{
	if (weaponSelectionHUD.Active()) {
		if (inputButtons & INPUT_PRIMARY) {
			weaponSelectionHUD.Trigger();
		} else if (inputButtons & INPUT_SECONDARY) {
			weaponSelectionHUD.Deactivate();
		}

		return (0.2f);
	}

	return (0.0f);
}

bool
HUD_ConsoleCommand(string commandString)
{
	tokenize_console(commandString);

	switch (argv(0)) {
	case "invnext":
		weaponSelectionHUD.SelectNext(false);
		break;
	case "invprev":
		weaponSelectionHUD.SelectPrevious(false);
		break;
	default:
		return (false);
	}

	return (true);
}

	
void
HUD_DamageReceived(vector damageLocation, int damagePoints, int damageFlags)
{
	if (damagePoints <= 0i) {
		return;
	}

	g_damageAlpha = 1.0;
	g_damageLocation = damageLocation;
	g_damageFlags = damageFlags;

	if (g_damageFlags & DMG_CHEMICAL) {
		g_damageFlags &= ~DMG_CHEMICAL;
		DMG_NOTIFY_SET(DMGNOT_CHEMICAL);
	}
	if (g_damageFlags & DMG_BURN) {
		g_damageFlags &= ~DMG_BURN;
		DMG_NOTIFY_SET(DMGNOT_BURN);
	}
	if (g_damageFlags & DMG_SLOWBURN) {
		g_damageFlags &= ~DMG_SLOWBURN;
		DMG_NOTIFY_SET(DMGNOT_BURN);
	}
	if (g_damageFlags & DMG_ELECTRO) {
		g_damageFlags &= ~DMG_ELECTRO;
		DMG_NOTIFY_SET(DMGNOT_SHOCK);
	}
	if (g_damageFlags & DMG_DROWN) {
		g_damageFlags &= ~DMG_DROWN;
		DMG_NOTIFY_SET(DMGNOT_DROWN);
	}
	if (g_damageFlags & DMG_NERVEGAS) {
		g_damageFlags &= ~DMG_NERVEGAS;
		DMG_NOTIFY_SET(DMGNOT_NERVEGAS);
	}
	if (g_damageFlags & DMG_POISON) {
		g_damageFlags &= ~DMG_POISON;
		DMG_NOTIFY_SET(DMGNOT_POISON);
	}
	if (g_damageFlags & DMG_RADIATION) {
		g_damageFlags &= ~DMG_RADIATION;
		DMG_NOTIFY_SET(DMGNOT_RADIATION);
	}
	if (g_damageFlags & DMG_FREEZE) {
		g_damageFlags &= ~DMG_FREEZE;
		DMG_NOTIFY_SET(DMGNOT_FREEZE);
	}
	if (g_damageFlags & DMG_SLOWFREEZE) {
		g_damageFlags &= ~DMG_SLOWFREEZE;
		DMG_NOTIFY_SET(DMGNOT_FREEZE);
	}
}


vector g_ammotype[AMMO_COUNT] = {
	[0/256, 72/128], // pistol
	[24/256, 72/128], // revolver
	[48/256, 72/128], // grenade
	[72/256, 72/128], // shell
	[96/256, 72/128], //  arrow
	[120/256, 72/128], // rocket
	[0/256, 96/128], // uranium
	[24/256, 96/128], // hornet
	[48/256, 96/128], // grenade
	[72/256, 96/128], // satchel
	[96/256, 96/128], //  snark
	[120/256, 96/128], // tripmine
	[24/256, 72/128], // 556 (same as 357)
	[24/256, 72/128], // 762 (same as 357)
	[200/256, 48/128], // spore
	[224/256, 48/128], //  shock
	[144/256, 72/128], // penguin
};

void
HUD_AmmoChanged(int ammoType, int absoluteValue, int deltaValue)
{
	string ammoTypeName = ammo.NameForNum(ammoType);

	/* if you wonder why this isn't cleaner, this was ported from
	   the old HUD code. this can be changed to be decl specific at some point! */
	switch (ammoTypeName) {
	case "ammo_9mm":
		HLHUD_AmmoNotify_Insert(0, deltaValue);
		break;
	case "ammo_357":
		HLHUD_AmmoNotify_Insert(1, deltaValue);
		break;
	case "ammo_m203_grenade":
		HLHUD_AmmoNotify_Insert(2, deltaValue);
		break;
	case "ammo_buckshot":
		HLHUD_AmmoNotify_Insert(3, deltaValue);
		break;
	case "ammo_bolt":
		HLHUD_AmmoNotify_Insert(4, deltaValue);
		break;
	case "ammo_rocket":
		HLHUD_AmmoNotify_Insert(5, deltaValue);
		break;
	case "ammo_uranium":
		HLHUD_AmmoNotify_Insert(6, deltaValue);
		break;
	case "ammo_hornet":
		HLHUD_AmmoNotify_Insert(7, deltaValue);
		break;
	case "ammo_handgrenade":
		HLHUD_AmmoNotify_Insert(8, deltaValue);
		break;
	case "ammo_satchel":
		HLHUD_AmmoNotify_Insert(9, deltaValue);
		break;
	case "ammo_snark":
		HLHUD_AmmoNotify_Insert(10, deltaValue);
		break;
	case "ammo_tripmine":
		HLHUD_AmmoNotify_Insert(11, deltaValue);
		break;
	case "ammo_556":
		HLHUD_AmmoNotify_Insert(12, deltaValue);
		break;
	case "ammo_762":
		HLHUD_AmmoNotify_Insert(13, deltaValue);
		break;
	case "ammo_spore":
		HLHUD_AmmoNotify_Insert(14, deltaValue);
		break;
	case "ammo_shock":
		HLHUD_AmmoNotify_Insert(15, deltaValue);
		break;
	case "ammo_penguin":
		HLHUD_AmmoNotify_Insert(16, deltaValue);
		break;
	}
}

void
HUD_Obituary(string targetName, string attackerName, string weaponDef, string meansOfDeath)
{
	static void HUD_Obituary_Add(int id, string targetName, string attackerName, string weaponDef, string meansOfDeath) {
		string killIcon = entityDef.GetString(weaponDef, "killIcon");

		g_killMsgRecord[id].m_target = targetName;

		if (wordInString(meansOfDeath, "self") == false) {
			g_killMsgRecord[id].m_attacker = attackerName;
		} else {
			g_killMsgRecord[id].m_attacker = "";
		}

		if (STRING_SET(killIcon)) {
			g_killMsgRecord[id].m_icon = atlasPic.Load(killIcon);
		} else {
			if (wordInString(meansOfDeath, "vehicle") == true) {
				g_killMsgRecord[id].m_icon = g_spriteSheets[S_D_TRACKTRAIN];
			} else {
				g_killMsgRecord[id].m_icon = g_spriteSheets[S_D_SKULL];
			}
		}
	}

	if (g_killMsgCount < KILLMESSAGE_LIMIT) {
		HUD_Obituary_Add(g_killMsgCount, targetName, attackerName, weaponDef, meansOfDeath);
		g_killMsgCount++;
	} else {
		for (int i = 0i; i < (KILLMESSAGE_LIMIT-1); i++) {
			g_killMsgRecord[i].m_target = g_killMsgRecord[i+1].m_target;
			g_killMsgRecord[i].m_attacker = g_killMsgRecord[i+1].m_attacker;
			g_killMsgRecord[i].m_icon = g_killMsgRecord[i+1].m_icon;
		}

		HUD_Obituary_Add(KILLMESSAGE_LIMIT-1, targetName, attackerName, weaponDef, meansOfDeath);
	}

	g_killMsgTime = time + KILLMESSAGE_TIME;
}
