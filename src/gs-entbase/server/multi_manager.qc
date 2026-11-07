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

#define MM_MULTITHREADED 1

static class
multi_manager_sub:ncPointTrigger
{
public:
	void multi_manager_sub(void);

	/* overrides */
	virtual void Save(float);
	virtual void Restore(string,string);
	nonvirtual void ActivateSub(void);

private:
	entity m_lastActivator;
	float m_flUntilTriggered;
};

void
multi_manager_sub::multi_manager_sub(void)
{
	m_lastActivator = __NULL__;
	m_flUntilTriggered = 0.0f;
}

void
multi_manager_sub::Save(float handle)
{
	super::Save(handle);
	SaveEntity(handle, "m_lastActivator", m_lastActivator);
	SaveFloat(handle, "m_flUntilTriggered", m_flUntilTriggered);
}

void
multi_manager_sub::Restore(string strKey, string setValue)
{
	switch (strKey) {
	case "m_lastActivator":
		m_lastActivator = ReadEntity(setValue);
		break;
	case "m_flUntilTriggered":
		m_flUntilTriggered = ReadFloat(setValue);
		break;
	default:
		super::Restore(strKey, setValue);
	}
}

void
multi_manager_sub::ActivateSub(void)
{
	SetValue(1i);
	UseTargets(m_lastActivator, TRIG_TOGGLE, 0.0f);
}

/*! \brief Server-Entity: Triggers Up To 64 Different Targets */
/*!QUAKED multi_manager (1 0 0) (-8 -8 -8) (8 8 8) MM_MULTITHREADED
# OVERVIEW
Triggers a maximum of 64 user defined entities with additonal timers.
(Half-Life allowed 16; Sven Co-op maps use more.)
Add a target's name as an entity key, with the value set to the time in seconds
that'll pass before the entity will be triggered.

# KEYS
- "targetname" : Name

# SPAWNFLAGS
- MM_MULTITHREADED (1) : Allow the multi_manager to be triggered again before it has
finished triggering it's previous list of entities.

# TRIVIA
This entity was introduced in Half-Life (1998).

@ingroup serverentity
@ingroup pointentity
*/
#define MM_MAXTARGETS 64i

class
multi_manager:ncPointTrigger
{
private:
	multi_manager_sub m_subTriggers[MM_MAXTARGETS];
	int m_subCount;
	string m_triggerBuffer;

public:
	void multi_manager(void);

	/* overrides */
	virtual void Save(float);
	virtual void Restore(string,string);
	virtual void SpawnKey(string,string);
	virtual void Spawned(void);
	virtual void Respawn(void);
	virtual void Trigger(entity, triggermode_t);
};

void
multi_manager::multi_manager(void)
{
	for (int i = 0; i < MM_MAXTARGETS; i++)
		m_subTriggers[i] = __NULL__;

	m_subCount = 0i;
	m_triggerBuffer = __NULL__;
}

void
multi_manager::Save(float handle)
{
	super::Save(handle);
	SaveString(handle, "m_triggerBuffer", m_triggerBuffer);
	SaveInt(handle, "m_subCount", m_subCount);

	for (int i = 0; i < m_subCount; i++) {
		SaveEntity(handle, sprintf("m_subTriggers_%i", i), m_subTriggers[i]);
	}
}

void
multi_manager::Restore(string strKey, string setValue)
{
	switch (strKey) {
	case "m_triggerBuffer":
		m_triggerBuffer = ReadString(setValue);
		break;
	case "m_subCount":
		m_subCount = ReadInt(setValue);
		break;
	default:
		if (substring(strKey, 0, 14) == "m_subTriggers_") {
			int subIndex = stoi(substring(strKey, 14, -1));

			if (subIndex >= 0i && subIndex < MM_MAXTARGETS) {
				m_subTriggers[subIndex] = (multi_manager_sub)ReadEntity(setValue);
			}
			break;
		}
		super::Restore(strKey, setValue);
	}
}

void
multi_manager::SpawnKey(string strKey, string setValue)
{
	switch (strKey) {
	case "{":
	case "}":
	case "classname":
	case "origin":
	case "targetname":
	case "spawnflags":
	case "angle":
	case "angles":
	case "target":
	case "spawnflags":
		super::SpawnKey(strKey, setValue);
		break;
	default:
		if (substring(strKey, strlen(strKey) - 3,  1) == "#") {
			m_triggerBuffer = sprintf("%s%s %s ",
							m_triggerBuffer,
							substring(strKey,
							0, strlen(strKey) - 3),
							setValue);
		} else if (substring(strKey, strlen(strKey) - 2,  1) == "#") {
			m_triggerBuffer = sprintf("%s%s %s ",
							m_triggerBuffer,
							substring(strKey,
							0, strlen(strKey) - 2),
							setValue);
		} else {
			m_triggerBuffer = sprintf("%s%s %s ", m_triggerBuffer, strKey, setValue);
		}
	}
}

void
multi_manager::Spawned(void)
{
	int iFields;
	int b;

	super::Spawned();

	/* one sub-entity for each target. spawning them first, since
	   spawning can tokenize and clobber argv() below */
	iFields = tokenizebyseparator(m_triggerBuffer, " ");
	m_subCount = iFields / 2i;

	if (m_subCount > MM_MAXTARGETS) {
		EntWarning("%i targets, only the first %i are used", m_subCount, MM_MAXTARGETS);
		m_subCount = MM_MAXTARGETS;
	}

	for (b = 0; b < m_subCount; b++) {
		m_subTriggers[b] = spawn(multi_manager_sub);
		m_subTriggers[b].Spawn();
	}

	/* set up our triggers */
	b = 0;
	iFields = tokenizebyseparator(m_triggerBuffer, " ");
	for (int i = 0; i < iFields; i+=2) {
		if (b >= m_subCount) {
			break;
		}

		if (!argv(i))
			break;

		/* avoid infinite-loops, only when MULTITHREADED flag is NOT set */
		if ((!HasSpawnFlags(MM_MULTITHREADED) && targetname == argv(i)))
			continue;

		m_subTriggers[b].SetTriggerTarget(argv(i));
		m_subTriggers[b].target = argv(i);
		m_subTriggers[b].m_flUntilTriggered = stof(argv(i+1));
		b++;
	}
}

void
multi_manager::Respawn(void)
{
	InitPointTrigger();

	SetValue(0i);

	/* Mark them inactive */
	for (int b = 0; b < m_subCount; b++) {
		m_subTriggers[b].SetValue(0i);
	}
}

void
multi_manager::Trigger(entity act, triggermode_t state)
{
	if (GetMaster(act) == FALSE)
		return;

	SetValue(1i);

	/* If not multi-threaded, we have to watch out 'til all triggers are done. */
	if (!HasSpawnFlags(MM_MULTITHREADED)) {
		for (int i = 0; i < m_subCount; i++) {
			if (m_subTriggers[i].IsThinking() == true) {
				return;
			}
		}
	}

	/* time to trigger our sub triggers */
	for (int i = 0; i < m_subCount; i++) {
		if (m_subTriggers[i].HasTriggerTarget() == false)
			continue;

		m_subTriggers[i].SetValue(0i);
		m_subTriggers[i].m_lastActivator = act;
		m_subTriggers[i].ScheduleThink(multi_manager_sub::ActivateSub, m_subTriggers[i].m_flUntilTriggered);
	}
}
