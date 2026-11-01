/* The Half-Life HUD from valve/src/hud, kept whole: the co-op HUD (jtf.qc)
   draws it when cg_hudPanorama is 0 or the engine has no Panorama, and
   uses its weapon selection, pickup notices and damage arrows either way.
   Its HUD_Draw and HUD_Obituary are renamed so jtf.qc can wrap them. */

#define HUD_Draw HLHUD_ClassicDraw
#define HUD_Obituary HLHUD_ClassicObituary
#include "../../../valve/src/hud/hud.qc"
#undef HUD_Draw
#undef HUD_Obituary
