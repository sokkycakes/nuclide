/* Native MapC: compiled by fteqcc, executed by Nuclide. */
#pragma target fte_5768
#includelist
../../src/rules.src
#endlist

void CodeCallback_Precache(void)
{
    print("FTEW_MAPC: editor_lab native map logic loaded\n");
}

void CodeCallback_PlayerSpawn(entity player)
{
    sprint(player, PRINT_HIGH, "Native world lab: walk onto the green plate to toggle the light.\n");
}

/* Fixture-only automation. Inactive during normal editor play sessions. */
var int probe_stage;
var float probe_time;
var string probe_light_before;
var float autocvar_ftew_probe = 0;

string ProbeLightState(entity light)
{
    for (float field = 0; field < numentityfields(); field++) {
        if (strstrofs(entityfieldname(field), "m_iState") >= 0 &&
            strstrofs(entityfieldname(field), "light_dynamic") >= 0)
            return ftos(stof(getentityfieldstring(field, light)));
    }
    return "missing";
}

void CodeCallback_PlayerConnect(entity player)
{
    if (autocvar_ftew_probe) print(sprintf("FTEW_CLIENT %s connected\n", player.netname));
}

void CodeCallback_FrameStart(void)
{
    if (!autocvar_ftew_probe || probe_stage == 2) return;
    entity player = find(world, ::netname, "WorldProbeA");
    entity light = find(world, ::classname, "light_dynamic");
    if (!player || !light || player.health <= 0) return;
    if (probe_stage == 0 && time > 8) {
        probe_light_before = ProbeLightState(light);
        print(sprintf("FTEW_IO before=%s player=%v\n", probe_light_before, player.origin));
        /* Physical overlap must fire the exported trigger's native output. */
        setorigin(player, [0, 0, -player.mins[2] + 0.1]);
        player.velocity = '0 0 0';
        probe_time = time + 0.5;
        probe_stage = 1;
    } else if (probe_stage == 1 && time >= probe_time) {
        string after = ProbeLightState(light);
        print(sprintf("FTEW_IO before=%s after=%s player=%v\n", probe_light_before, after, player.origin));
        probe_stage = 2;
    }
}
