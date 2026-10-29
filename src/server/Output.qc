/*
 * Copyright (c) 2016-2025 Vera Visions LLC.
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

/* the script layer sees each input first, see c_script.h */
static void
ncOutput_Deliver(ncIO target, entity activatorEnt, entity callerEnt, string inputName, string dataString)
{
	if (scriptInput(target, activatorEnt, inputName, dataString, callerEnt))
		return;

	target.Input(activatorEnt, inputName, dataString);
}

void
ncOutput::TriggerOutput(void)
{
	ncIO ourOwner = (ncIO)owner;
	ncIO ourActivator = (ncIO)m_eActivator;

	/* plug into all the inputs. */
	if (m_strTarget == "!self") {
		if (ourOwner)
			ncOutput_Deliver(ourOwner, ourOwner, ourOwner, m_strInput, m_strData);
	} else if (m_strTarget == "!activator") {
		if (ourActivator)
			ncOutput_Deliver(ourActivator, ourActivator, ourOwner, m_strInput, m_strData);
	} else if (m_strTarget == "!target") {
		ncEntity ourTarget = (ncEntity)find(world, ::targetname, ourOwner.target);

		if (ourTarget)
			ncOutput_Deliver(ourTarget, ourActivator, ourOwner, m_strInput, m_strData);
	} else if (m_strTarget == "!rules") {
		ncRuleDelegate ourRules = ncRuleDelegate::ActiveInstance();

		if (ourRules)
			ncOutput_Deliver(ourRules, ourActivator, ourOwner, m_strInput, m_strData);
	} else {
		if (!STRING_SET(m_strTarget)) {
			EntError("target invalid.");
			return;
		}

		float targetLength = strlen(m_strTarget);

		/* Source Engine: a trailing * matches every name with that prefix */
		if (substring(m_strTarget, targetLength - 1, 1) == "*") {
			string targetPrefix = substring(m_strTarget, 0, targetLength - 1);

			for (entity f = world; (f = nextent(f));) {
				if (!STRING_SET(f.targetname) || substring(f.targetname, 0, targetLength - 1) != targetPrefix) {
					continue;
				}

				ncEntity wildTrigger = (ncEntity)f;

				if (wildTrigger.Input != __NULL__) {
					ncOutput_Deliver(wildTrigger, m_eActivator, ourOwner, m_strInput, m_strData);
				}
			}
		} else {
			for (entity f = world; (f = find(f, ::targetname, m_strTarget));) {
				ncEntity trigger = (ncEntity)f;

				if (trigger.Input != __NULL__) {
					ncOutput_Deliver(trigger, m_eActivator, ourOwner, m_strInput, m_strData);
				}
			}
		}
	}

	/* we're not -1 (infinite) and we've still got one use to deduct */
	if (m_iCount > 0)
		m_iCount--;

	nextthink = 0.0f;
}

void
ncOutput::ScheduleOutput(entity activatorEnt)
{
	m_eActivator = activatorEnt;

	if (m_flDelay > 0.0f || GetSpawnAge() == 0.0f) {
		think = TriggerOutput;
		nextthink = time + m_flDelay;
	} else {
		nextthink = 0.0f;
		think = __NULL__;
		TriggerOutput();
	}
}

void
ncOutput::Init(void)
{
	/* Init of ncIO will tokenize __fullspawndata which
	   in turn will break ncIO::CreateOutput's tokenize loop,
	   as we'll be creating a bunch of ncOutputs in there */
}

void
ncOutput::Respawn(void)
{
	/* gotta reset our counter */
	m_iCount = m_iOldCount;
	nextthink = 0.0f;
	think = __NULL__;
}

void
ncOutput::ncOutput(void)
{
	/* Make sure Respawn() will be called between rounds */
	identity = 1;
	m_eActivator = __NULL__;
	m_strTarget =
	m_strInput =
	m_strData = __NULL__;
	m_flDelay = 0.0f;
	m_iCount = 0i;
	m_iOldCount = 0i;
}
