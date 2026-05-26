#include "hud.h"
#include "WeaponSelect.h"

var float autocvar_hlhud_weaponIconAlpha = 0.75;
var float autocvar_hlhud_weaponIconSelectedAlpha = 1.0f;

void
HLWeaponSelect::HLWeaponSelect(void)
{
	m_selectedWeapon = __NULL__;
	m_flHUDWeaponSelectTime = 0.0f;
}

void
HLWeaponSelect::Event_Opened(void)
{
	localsound("common/wpn_hudon.wav");
}

void
HLWeaponSelect::Event_Closed(void)
{
	localsound("common/wpn_hudoff.wav");
}

void
HLWeaponSelect::Event_SelectionChanged(void)
{
	localsound("common/wpn_moveselect.wav");
}

void
HLWeaponSelect::Event_SelectionTriggered(void)
{
	localsound("common/wpn_select.wav");
}

bool
HLWeaponSelect::Active(void)
{
	return (m_flHUDWeaponSelectTime > time) ? (true) : (false);
}

void
HLWeaponSelect::Trigger(void)
{
	weapon.SelectWeapon(m_selectedWeapon);
	Deactivate();
}

void
HLWeaponSelect::Deactivate(void)
{
	if (m_selectedWeapon == __NULL__) {
		return;
	}

	m_selectedWeapon = __NULL__;
	m_flHUDWeaponSelectTime = 0.0f;
	Event_Closed();
}

void
HLWeaponSelect::DrawBar(vector drawAtPos, float percentageAmount)
{
	vector colorLerp;
	float barWidth;

	draw.Rect(drawAtPos + [10,0], [20,4], g_fg_color, 1.0f);

	barWidth = bound(1, 20 * percentageAmount, 20);
	colorLerp[0] = lerp(1.0, 0.0f, percentageAmount);
	colorLerp[1] = lerp(0.0, 1.0f, percentageAmount);
	colorLerp[2] = lerp(0.0, 0.0f, percentageAmount);

	draw.Rect(drawAtPos + [10,0], [barWidth,4], colorLerp, 1.0f);
}

void
HLWeaponSelect::Draw(void)
{
	if (m_flHUDWeaponSelectTime < time) {
		Deactivate();
		return;
	}

	if (!m_selectedWeapon) {
		return;
	}

	vector hudMins = screen.HUDMins();
	vector hudRes = screen.HUDSize();
	vector vecPos = hudMins + [16,16];
	float lastSlot = -1;
	float currentSlot;
	entity linkedList = __NULL__;

	linkedList = m_firstWeapon;

#if 0
	float totalWidth = 120;
	totalWidth += (weapon.GetSlot(m_lastWeapon) * 40);
	vecPos = hudMins + [hudRes[0] / 2 - (totalWidth / 2),16];
#else
	vecPos = hudMins + [16,16];
#endif

	while (linkedList) {
		if (weapon.IsValid(linkedList) == true) {
			currentSlot = weapon.GetSlot(linkedList);

			if (lastSlot != currentSlot) {
				if (lastSlot == m_iWantSlot) {
					vecPos[0] += 175;
				} else {
					vecPos[0] += 25;
				}

				if (lastSlot == -1) {
#if 0
					vecPos[0] = hudMins[0] + (hudRes[0] / 2 - (totalWidth / 2));
#else
					vecPos = hudMins + [16,16];
#endif
				}

				vecPos[1] = hudMins[1] + 25;

			}

			if (lastSlot != currentSlot) {
				if (m_iWantSlot != currentSlot) {
					DrawSlotNum(vecPos, 0);
				}

				DrawSlotNum(vecPos + [0, -20], currentSlot + 1);
			} else {
				if (m_iWantSlot != currentSlot) {
					DrawSlotNum(vecPos, 0);
				}
			}

			lastSlot = currentSlot;

			if (m_iWantSlot == currentSlot) {
				float ammo1Percentage = (float)weapon.GetAmmo1(linkedList) / (float)weapon.MaxAmmo(linkedList);
				float ammo2Percentage = (float)weapon.GetAmmo2(linkedList) / (float)weapon.MaxAmmo(linkedList);

				if (linkedList == m_selectedWeapon) {
					atlasPic.Draw_RGBA(atlasPic.Load(weapon.GetSelectedIcon(linkedList)), vecPos, g_fg_color * autocvar_hlhud_weaponIconSelectedAlpha, g_fg_alphaScale, true);
					atlasPic.Draw_RGBA(g_spriteSheets[S_SELECTION], vecPos, g_fg_color * autocvar_hlhud_weaponIconSelectedAlpha, g_fg_alphaScale, true);

					if (weapon.AmmoRequired(linkedList) == true) {
						DrawBar(vecPos, ammo1Percentage);
					}

					if (weapon.UsesSecondaryAmmo(linkedList) == true) {
						DrawBar(vecPos + [35, 0], ammo2Percentage);
					}
				} else {
					atlasPic.Draw_RGBA(atlasPic.Load(weapon.GetIcon(linkedList)), vecPos, g_fg_color * autocvar_hlhud_weaponIconAlpha, g_fg_alphaScale, true);

					if (weapon.AmmoRequired(linkedList) == true) {
						DrawBar(vecPos, ammo1Percentage);
					}

					if (weapon.UsesSecondaryAmmo(linkedList) == true) {
						DrawBar(vecPos + [35, 0], ammo2Percentage);
					}
				}
				vecPos[1] += 50;
			} else {
				vecPos[1] += 25;
			}
		}

		linkedList = weapon.GetNextWeaponRelativeTo(linkedList);
	}
}

void
HLWeaponSelect::DrawSlotNum(vector vecPos, float fValue)
{
	atlasPic.Draw_RGBA(
		g_spriteSheets[S_BUCKET0 + fValue],
		vecPos,
		g_fg_color,
		g_fg_alphaScale,
		true
	);
}

void
HLWeaponSelect::SelectSlot(int wantedSlot, bool fastSwitch)
{
}

void
HLWeaponSelect::SelectNext(bool fastSwitch)
{
	entity currentWeapon = weapon.GetActiveWeapon();

	if (!currentWeapon) {
		return;
	}

	m_firstWeapon = weapon.GetFirstWeaponInInventory();
	m_lastWeapon = weapon.GetLastWeaponInInventory();

	if (!m_selectedWeapon) {
		m_selectedWeapon = weapon.GetNextWeaponRelativeTo(currentWeapon);
	} else {
		m_selectedWeapon = weapon.GetNextWeaponRelativeTo(m_selectedWeapon);
	}

	if (!m_selectedWeapon) {
		m_selectedWeapon = m_firstWeapon;
		Event_Opened();
	} else {
		Event_SelectionChanged();
	}

	m_flHUDWeaponSelectTime = time + autocvar_hlhud_hideTime;
	m_iWantSlot = weapon.GetSlot(m_selectedWeapon);
	m_iWantSlotPos = weapon.GetSlotPos(m_selectedWeapon);
}

void
HLWeaponSelect::SelectPrevious(bool fastSwitch)
{
	entity currentWeapon = weapon.GetActiveWeapon();

	if (!currentWeapon) {
		return;
	}

	m_firstWeapon = weapon.GetFirstWeaponInInventory();
	m_lastWeapon = weapon.GetLastWeaponInInventory();

	if (!m_selectedWeapon) {
		m_selectedWeapon = weapon.GetPreviousWeaponRelativeTo(currentWeapon);
	} else {
		m_selectedWeapon = weapon.GetPreviousWeaponRelativeTo(m_selectedWeapon);
	}

	if (!m_selectedWeapon) {
		m_selectedWeapon = m_firstWeapon;
	}

	if (m_flHUDWeaponSelectTime < time) {
		Event_Opened();
	} else {
		Event_SelectionChanged();
	}

	m_flHUDWeaponSelectTime = time + autocvar_hlhud_hideTime;
	m_iWantSlot = weapon.GetSlot(m_selectedWeapon);
	m_iWantSlotPos = weapon.GetSlotPos(m_selectedWeapon);
}
