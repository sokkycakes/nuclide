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

/*! \brief Server-Entity: Entity Class Written In A Script */
/*!QUAKED ncScriptedEntity (.5 .5 .5) (-8 -8 -8) (8 8 8)
# OVERVIEW
Stands in for a map entity whose classname has no QC class, when a script
for that classname exists in `scripts/vscripts/entities/` (`.lua`, `.js`
or `.dat`). The entity keeps its map classname, so targetname and
classname lookups find it as usual, and the script is loaded into its
scope when it spawns.

The script sees:
- `Input<Name>` for every input sent to the entity.
- `InputUse()` when a target or the "Trigger" input fires it, with
  `activator` set. The `script_triggermode` field holds the trigger mode:
  0 off, 1 on, 2 toggle. (Input hooks get no arguments.)
- the map's keys through the `script_spawndata` field, as "key" "value" pairs.

# NOTES
Needs Bulwark's script builtins. Elsewhere the classname stays
unimplemented, as before.

@ingroup serverentity
@ingroup pointentity
*/
/** The trigger mode of the last time a scripted entity was triggered. */
.float script_triggermode;
/** A scripted entity's map keys. (m_rawSpawnData's field has a mangled name.) */
.string script_spawndata;

class
ncScriptedEntity:ncPointTrigger
{
public:
	void ncScriptedEntity(void);

	virtual void Trigger(entity,triggermode_t);
};

void
ncScriptedEntity::ncScriptedEntity(void)
{
}

void
ncScriptedEntity::Trigger(entity activatorEntity, triggermode_t triggerMode)
{
	if (checkbuiltin(script_input)) {
		script_triggermode = (float)triggerMode;
		script_input(this, activatorEntity, "Use", itos(triggerMode), activatorEntity);
	}
}

/** Returns the script that implements a classname, or "" when none does. */
string
ScriptedEntity_FileFor(string className)
{
	string fileName;

	if (!checkbuiltin(script_attach)) {
		return ("");
	}

	fileName = sprintf("scripts/vscripts/entities/%s.lua", className);

	if (fileExists(fileName)) {
		return (fileName);
	}

	fileName = sprintf("scripts/vscripts/entities/%s.js", className);

	if (fileExists(fileName)) {
		return (fileName);
	}

	fileName = sprintf("scripts/vscripts/entities/%s.dat", className);

	if (fileExists(fileName)) {
		return (fileName);
	}

	return ("");
}
