/* Exercise the production light entity, replication, and render updates. */
#pragma target fte_5768
#includelist
../../src/rules.src
#endlist
var float previousStage = -1;
void CodeCallback_FrameStart(void)
{
    float stage = cvar("ftew_sun_stage");
    entity lamp = find(world, ::classname, "light_dynamic");
    if (!lamp || stage == previousStage) return;
    previousStage = stage;
    float number = num_for_edict(lamp);
    localcmd(sprintf("sv input %d brightness %g\n", number, stage == 0 ? 0 : 2));
    localcmd(sprintf("sv input %d _shadows %g\n", number, stage == 2 ? 0 : 1));
    localcmd(sprintf("sv input %d angles \"45 %g 0\"\n", number, stage == 3 ? 135 : 225));
    print(sprintf("FTEW_SUN_STAGE %g\n", stage));
}
