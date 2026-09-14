/* Test MapC: exercise the actual server input and network-update paths. */
#pragma target fte_5768
#includelist
../../src/rules.src
#endlist
var float previousEnergy = -999;
void CodeCallback_FrameStart(void)
{
    float energy = cvar("ftew_test_energy");
    entity lamp = find(world, ::classname, "light_dynamic");
    if (!lamp || energy == previousEnergy) return;
    previousEnergy = energy;
    localcmd(sprintf("sv input %d brightness %g\n", num_for_edict(lamp), energy));
    print(sprintf("FTEW_LIGHT_ENERGY %g\n", energy));
}
