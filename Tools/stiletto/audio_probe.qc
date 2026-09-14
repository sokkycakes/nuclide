#pragma target fte_5768
#includelist
../../src/rules.src
#endlist
var float previousAudioStage = -1;
void CodeCallback_FrameStart(void)
{
    float stage = cvar("ftew_audio_stage");
    if (stage == previousAudioStage) return;
    previousAudioStage = stage;
    entity speaker = world;
    while ((speaker = find(speaker, ::classname, "ambient_generic"))) {
        if (stage == 1 || stage == 4) localcmd(sprintf("sv input %d StopSound\n",num_for_edict(speaker)));
        if (stage == 2 || stage == 5) localcmd(sprintf("sv input %d PlaySound\n",num_for_edict(speaker)));
        if (stage == 3) {
            localcmd(sprintf("sv input %d Volume 0.25\n",num_for_edict(speaker)));
            localcmd(sprintf("sv input %d Pitch 150\n",num_for_edict(speaker)));
        }
    }
    print(sprintf("FTEW_AUDIO_STAGE %g\n",stage));
}
