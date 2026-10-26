/*
 * Copyright (c) 2026 sokkycakes
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF MIND, USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/** The player class every template class def spawns as.

All class stats live in decls/def/tf_classes.def; this only reads the
template's own keys so the rules and bots can see them:
- "tf_classIndex": 1 to 9, the slot on the class menu
- "tf_capRate": how many players this class counts as on a capture area
- "tf_regen": health regenerated per second (the Medic's trait in TF2)

Give new class mechanics a home here (or in a subclass) rather than in the
rules, so they keep working in every game mode. */
class
tfPlayer:ncPlayer
{
public:
	void tfPlayer(void);

	virtual void SpawnKey(string, string);
	virtual void Respawn(void);
};

void
tfPlayer::tfPlayer(void)
{
	tf_capRate = 1.0f;
	tf_regenRate = 0.0f;
	tf_classIndex = 0;
	tf_charge = 0.0f;
	tf_healTarget = __NULL__;
}

void
tfPlayer::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "tf_classIndex":
		tf_classIndex = ReadFloat(setValue);
		break;
	case "tf_capRate":
		tf_capRate = ReadFloat(setValue);
		break;
	case "tf_regen":
		tf_regenRate = ReadFloat(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfPlayer::Respawn(void)
{
	super::Respawn();
	tf_charge = 0.0f;
	tf_healTarget = __NULL__;
	tf_lastRegenTime = time;
}

/** Bots spawn as this class instead, through the class's "_bot" def, so bot
code can derive from it without losing its methods on every class change.
A bot framework replaces it by defining TF_BOT_PAWN and its own tfBotPawn
class (for example `class tfBotPawn:BWBot {}` with BW_PAWN_BASE set to
tfPlayer) before this file is compiled. */
#ifndef TF_BOT_PAWN
class
tfBotPawn:tfPlayer
{
public:
	void tfBotPawn(void);
};

void
tfBotPawn::tfBotPawn(void)
{
}
#endif
