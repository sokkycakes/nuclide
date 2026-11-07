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

/** @defgroup script Entity scripts
    @brief VScript-style Lua, JavaScript and QuakeC scripts on entities.

Bulwark's server offers these builtins. Other engines don't, so every use
is guarded with checkbuiltin() and the game runs unchanged without them.

An entity with a `vscripts` key loads those script files (from
`scripts/vscripts/`) into its own script scope when it spawns, and a
`thinkfunction` key names a script function to run every 0.1 seconds.
The RunScriptCode, RunScriptFile, CallScriptFunction and
SetThinkFunction inputs reach the scope, and a script function named
`Input<InputName>` sees every input first; returning false swallows it.
@{ */

#ifdef SERVER
/** Loads a space separated list of script files into the entity's scope. Returns how many loaded. */
float(entity ent, string files) script_attach = #0:script_attach;
/** Sets the script function the entity thinks with, "" to stop. */
void(entity ent, string func) script_think = #0:script_think;
/** Offers an input to the script layer. Returns true when it was consumed. */
float(entity ent, entity activator, string input, string data, optional entity caller) script_input = #0:script_input;
/** Calls a function in the entity's scope, whatever language defines it. The result comes back as text. */
string(entity ent, string func, ...) script_call = #0:script_call;
/** Runs code in the entity's scope ('world' for the root scope). lang is "lua", "js" or "" for the scope's own. */
float(entity ent, string code, optional string lang) script_run = #0:script_run;
/** Calls OnGameEvent_<name>(params) in every scope. keyvalues is a list of "key" "value" pairs. */
void(string name, string keyvalues) script_event = #0:script_event;
#endif

/** @} */ // end of script
