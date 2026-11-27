/*
 * Copyright (c) 2016-2022 Vera Visions LLC.
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

/*
   The engine provides us with 3 devices right now, each giving us
   their position, angle etc. as well as field stating which bits
   of information have gotten updated.

   If no updates are happening from the HMD/head, that means we're
   most like not in VR, or the player has taken the headset off and
   laid it down.

   If we have no updates from the left and right XR devices, we
   will use the regular input_angles and view position for weapons.
*/

static NSXRSpace
FindXRSpace(entity playerEntity)
{
	NSXRSpace foundSpace = __NULL__;

	for (NSXRSpace spaceList = world; (spaceList = find(spaceList, ::classname, "NSXRSpace"));) {
		if (spaceList.owner == playerEntity) {
			return (spaceList);
		}
	}

	foundSpace = spawn(NSXRSpace);
	foundSpace.solid = SOLID_NOT;
	foundSpace.touch = 0;
	foundSpace.owner = playerEntity;
	return (foundSpace);
}

static NSXRInput
FindXRInput(entity playerEntity, xrinput_t inputType)
{
	NSXRInput foundInput = __NULL__;

	/* See if it exists already */
	for (NSXRInput inputList = world; (inputList = find(inputList, ::classname, "NSXRInput"));) {
		/* only reuse this player's own inputs; skipping them here (as
		   this used to) spawned three new ones on every Init and left
		   the old ones lying around in reused edict slots */
		if (inputList.owner != playerEntity) {
			continue;
		}
		if (inputList.GetType() != inputType) {
			continue;
		}
		return (inputList);
	}

	/* Doesn't exist. Create it. */
	foundInput = spawn(NSXRInput);
	foundInput.SetType(inputType);
	foundInput.SetParentSpace(FindXRSpace(playerEntity));
	foundInput.solid = SOLID_NOT;
	foundInput.touch = 0;
	foundInput.owner = playerEntity;
	return (foundInput);
}

/* true when 'input' is still one of this player's XR inputs. The classname
   check comes first: only then is it safe to treat it as an NSXRInput.
   The input type (GetType) is not compared here: xrinput_t is a 64-bit
   enum and Bulwark's VM does not compare it the way FTE does, so the check
   failed on every frame there and Init spawned three new inputs per frame
   until the server ran out of edicts. The owner check is enough to catch a
   slot reused by someone else's input; this player's own inputs are only
   ever (re)assigned all together by Init. */
static bool
XRManager_InputValid(ncClient pl, NSXRInput input)
{
	if (!input || wasfreed(input) || input.classname != "NSXRInput") {
		return (false);
	}
	if (input.owner != pl) {
		return (false);
	}
	return (true);
}

/* true when the player's XR space and inputs are all still there and still
   theirs. The references live on the player edict, which outlives what they
   point at: once one of those entities is removed its slot gets reused by
   something else (a timer, a projectile, another player's XR input), and
   calling an NSXRInput method on a different class is a NULL function call,
   which aborts a stock FTE server. Another player's input would pass the
   class check but drive this player's view and weapon from the wrong hand. */
static bool
XRManager_RefsValid(ncClient pl)
{
	if (!pl.m_xrSpace || wasfreed(pl.m_xrSpace) || pl.m_xrSpace.classname != "NSXRSpace" || pl.m_xrSpace.owner != pl) {
		return (false);
	}
	if (!XRManager_InputValid(pl, pl.m_xrInputHead)) {
		return (false);
	}
	if (!XRManager_InputValid(pl, pl.m_xrInputLeft)) {
		return (false);
	}
	if (!XRManager_InputValid(pl, pl.m_xrInputRight)) {
		return (false);
	}
	return (true);
}

void
ncXRManager::Init(entity ePlayer)
{
	ncClient pl = (ncClient)ePlayer;
	pl.m_xrSpace = FindXRSpace(pl);
	pl.m_xrInputHead = FindXRInput(pl, XR_INPUT_HEAD);
	pl.m_xrInputLeft = FindXRInput(pl, XR_INPUT_LEFT);
	pl.m_xrInputRight = FindXRInput(pl, XR_INPUT_RIGHT);
}

void
ncXRManager::Shutdown(entity ePlayer)
{
	ncClient pl = (ncClient)ePlayer;
	pl.m_xrSpace = __NULL__;
	pl.m_xrInputHead = __NULL__;
	pl.m_xrInputLeft = __NULL__;
	pl.m_xrInputRight = __NULL__;
}

#ifdef CLIENT
void
ncXRManager::UpdateView(entity ePlayer)
{
	ncClient pl = (ncClient)ePlayer;

	/* not yet ready, or a reference went stale */
	if (XRManager_RefsValid(pl) == false) {
		ncXRManager::Init(ePlayer);
	}

	/* update our space */
	if (ncXRManager::Available(ePlayer)) {
		pl.m_xrSpace.SetOrigin(g_view.GetCameraOrigin());
		pl.m_xrSpace.SetAngles(view_angles);

		/* now we get the HMD's org/ang and send that off to the renderer */
		setviewprop(VF_ANGLES, pl.m_xrInputHead.GetAngles());
		setviewprop(VF_ORIGIN, pl.m_xrInputHead.GetOrigin() + [0,0, autocvar_xr_viewHeight]);
	} else {
		pl.m_xrSpace.SetOrigin(g_view.GetCameraOrigin());
		pl.m_xrSpace.SetAngles(input_angles);

	/*
		setviewprop(VF_ANGLES, pl.m_xrInputHead.GetAngles());
		setviewprop(VF_ORIGIN, pl.m_xrInputHead.GetOrigin());
	*/
	}
}
#endif

void
ncXRManager::InputFrame(entity ePlayer)
{
	ncClient pl = (ncClient)ePlayer;

	/* not yet ready, or a reference went stale */
	if (XRManager_RefsValid(pl) == false) {
		ncXRManager::Init(ePlayer);
	}

	if (autocvar_xr_testInputs) {
		input_head_status = (XR_STATUS_ORG | XR_STATUS_ANG);
		input_left_status = (XR_STATUS_ORG | XR_STATUS_ANG);
		input_right_status = (XR_STATUS_ORG | XR_STATUS_ANG);

		input_head_angles = [sin(time), sin(time * 1.25) * 5, sin(time * 1.45)];
		input_left_angles = [cos(time) * 5,cos(time) * 25,sin(time) * 5];
		input_right_angles = [cos(time) * 5,cos(time) * 25,sin(time) * 5];
		
		input_head_origin = [sin(time)*5,cos(time)*5,sin(time)*5];
		input_left_origin = input_head_origin + [cos(time*8) * 2,4,sin(time*8) * 2];
		input_right_origin = input_head_origin + [cos(time*8) * 2,-4,sin(time*8) * 2];
	}

	/* update the input internals for keeping track*/
	pl.m_xrInputHead.InputFrame();
	pl.m_xrInputLeft.InputFrame();
	pl.m_xrInputRight.InputFrame();
}

bool
ncXRManager::Available(entity ePlayer)
{
	ncClient pl = (ncClient)ePlayer;

	if (XRManager_RefsValid(pl) == false) {
		return (false);
	}

	/* we only care about the HMD... otherwise why even bother? */
	return pl.m_xrInputHead.IsAvailable();
}
