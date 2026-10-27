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

/** @file tf_test.qc
Console commands for testing weapons and buildings without a client. The
rules progs pass any tf_test_* command they don't know to TF_TestCommand.

- tf_test_class <player> <class>: respawns the player as a class
- tf_test_hurt <player> <amount>: takes health away (never below 1)
- tf_test_uber <player>: fills a Medic's Ubercharge
- tf_test_use <player> <weapon def>: switches weapon
- tf_test_put <player> <x> <y> <z> [yaw]: moves and pins the player
- tf_test_hold <player> <buttons> <seconds> [target player]: pins the
  player and holds buttons ("primary", "secondary", "reload", "jump",
  "use", "none", joined with +) for that long, aiming at the target if
  given (a player name, or @classname for the first entity of a class). Bot AI is off while pinned.
- tf_test_release <player>: unpins, giving control back
- tf_test_report: health and state of every player and building
*/

static tfPlayer
TF_TestFindPlayer(string playerName)
{
	for (entity e = world; (e = next.Player(e));) {
		if (strtolower(e.netname) == strtolower(playerName)) {
			return ((tfPlayer)e);
		}
	}

	print(sprintf("no player %S\n", playerName));
	return (__NULL__);
}

/** "primary", "secondary", "reload", "jump", "use" or "none", joined with
"+", or a number of input_buttons bits. */
static float
TF_TestButtons(string buttonNames)
{
	float buttonBits = 0;
	float nameCount = tokenizebyseparator(buttonNames, "+");

	for (float i = 0; i < nameCount; i++) {
		switch (argv(i)) {
		case "primary":
			buttonBits |= INPUT_PRIMARY;
			break;
		case "secondary":
			buttonBits |= INPUT_SECONDARY;
			break;
		case "reload":
			buttonBits |= INPUT_RELOAD;
			break;
		case "jump":
			buttonBits |= INPUT_JUMP;
			break;
		case "use":
			buttonBits |= INPUT_USE;
			break;
		default:
			buttonBits |= stof(argv(i));
		}
	}

	return (buttonBits);
}

/** Rules bridge. Returns true when it handled the command. */
bool
TF_TestCommand(string commandLine)
{
	tokenize_console(commandLine);
	string commandName = argv(0);
	tfPlayer thePlayer;

	switch (commandName) {
	case "tf_test_class":
		thePlayer = TF_TestFindPlayer(argv(1));

		if (thePlayer) {
			thePlayer.tf_desiredClass = argv(2);
			ents.Input(thePlayer, "Damage", "1000", thePlayer);
		}
		break;
	case "tf_test_hurt":
		thePlayer = TF_TestFindPlayer(argv(1));

		if (thePlayer) {
			thePlayer.SetHealth(max(1, thePlayer.GetHealth() - stof(argv(2))));
		}
		break;
	case "tf_test_uber":
		thePlayer = TF_TestFindPlayer(argv(1));

		if (thePlayer) {
			thePlayer.m_tfUberCharge = 1.0f;
		}
		break;
	case "tf_test_use":
		thePlayer = TF_TestFindPlayer(argv(1));

		if (thePlayer) {
			thePlayer.SwitchToWeapon(argv(2));
		}
		break;
	case "tf_test_put":
		thePlayer = TF_TestFindPlayer(argv(1));

		if (thePlayer) {
			thePlayer.SetOrigin([stof(argv(2)), stof(argv(3)), stof(argv(4))]);
			thePlayer.SetVelocity([0, 0, 0]);
			thePlayer.m_tfTestPos = thePlayer.origin;
			thePlayer.m_tfTestPinned = true;
			thePlayer.angles = thePlayer.v_angle = [0, stof(argv(5)), 0];
			thePlayer.fixangle = 1;
		}
		break;
	case "tf_test_hold":
		thePlayer = TF_TestFindPlayer(argv(1));

		if (thePlayer) {
			string buttonNames = argv(2);
			thePlayer.m_tfTestUntil = time + stof(argv(3));
			string aimName = argv(4);

			/* "@classname" aims at the first entity of that class */
			if (substring(aimName, 0, 1) == "@") {
				thePlayer.m_tfTestAim = find(world, ::classname, substring(aimName, 1, -1));
			} else {
				thePlayer.m_tfTestAim = STRING_SET(aimName) ? (entity)TF_TestFindPlayer(aimName) : world;
			}
			thePlayer.m_tfTestButtons = TF_TestButtons(buttonNames);
			thePlayer.m_tfTestPos = thePlayer.origin;
			thePlayer.m_tfTestPinned = true;
		}
		break;
	case "tf_test_release":
		thePlayer = TF_TestFindPlayer(argv(1));

		if (thePlayer) {
			thePlayer.m_tfTestPinned = false;
		}
		break;
	case "tf_test_report":
		for (entity e = world; (e = next.Player(e));) {
			tfPlayer p = (tfPlayer)e;
			print(sprintf("%s: %s %s hp %d/%d origin %v\n", p.netname, TF_TeamColorString(p.team), p.classname,
				p.GetHealth(), p.GetMaxHealth(), p.origin));
			print(sprintf("  weapon %s clip %i reserve %i\n", p.GetCurrentWeapon(),
				p.m_activeWeapon ? p.m_activeWeapon.GetClip() : 0i,
				p.m_activeWeapon ? p.GetReserveAmmo(TF_WeaponAmmoType(p.m_activeWeapon)) : 0i));
			print(sprintf("  uber %d%% cloaked %d burning %d disguise %S meter %S\n", rint(p.m_tfUberCharge * 100),
				p.tf_cloaked, (p.tf_burnUntil > time), p.tf_disguiseClass, userinfo.GetString(p, "*tf_meter")));
		}

		for (entity b = world; (b = findfloat(b, ::tf_isBuilding, 1));) {
			tfBuilding theBuilding = (tfBuilding)b;
			print(sprintf("building %s of %s: level %d hp %d/%d\n", theBuilding.classname, theBuilding.tf_builder.netname,
				theBuilding.tf_buildingLevel, theBuilding.GetHealth(), theBuilding.GetMaxHealth()));
			print(sprintf("  working %d sapped %d origin %v\n", theBuilding.IsWorking(), theBuilding.tf_sapped, theBuilding.origin));
		}
		break;
	default:
		return (false);
	}

	return (true);
}
