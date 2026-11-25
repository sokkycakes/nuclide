// q3map2 versions of Nuclide's common/ tool materials (base/textures/common/*.mat).
// Nuclide's own compiler, vmap, reads the .mat files; q3map2 only reads shader
// scripts, so without this file caulk, clip, trigger, hint and sky faces
// compile as plain solid walls. Copy it to <game>/scripts/ (Stiletto Proto
// already ships its own scripts/common.shader). See ../README.md.

textures/common/alpha_0
{
	qer_editorImage "textures/common/alpha_0.tga"
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm trans
	surfaceParm nolightmap
}

textures/common/alpha_100
{
	qer_editorImage "textures/common/alpha_100.tga"
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm trans
	surfaceParm nolightmap
}

textures/common/alpha_25
{
	qer_editorImage "textures/common/alpha_25.tga"
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm trans
	surfaceParm nolightmap
}

textures/common/alpha_50
{
	qer_editorImage "textures/common/alpha_50.tga"
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm trans
	surfaceParm nolightmap
}

textures/common/alpha_75
{
	qer_editorImage "textures/common/alpha_75.tga"
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm trans
	surfaceParm nolightmap
}

textures/common/areaportal
{
	qer_editorImage "textures/common/areaportal.tga"
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm structural
	surfaceParm trans
	surfaceParm nomarks
	surfaceParm areaportal
	surfaceParm nolightmap
}

textures/common/blank
{
	surfaceParm nolightmap
}

textures/common/blocklight
{
	qer_editorImage "textures/common/blocklight.tga"
	surfaceParm nodraw2
	surfaceParm nonsolid
	surfaceParm nomarks
	surfaceParm nolightmap
}

textures/common/caulk
{
	qer_editorImage "textures/common/caulk.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm nomarks
	surfaceParm nolightmap
}

textures/common/caulkslime
{
	qer_editorImage "textures/common/caulkslime.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm trans
	surfaceParm slime
	surfaceParm nolightmap
}

textures/common/caulkwater
{
	qer_editorImage "textures/common/caulkwater.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm trans
	surfaceParm water
	surfaceParm nolightmap
	surfaceParm fog
}

textures/common/climb
{
	qer_editorImage "textures/common/climb.tga"
	qer_trans 0.50
	surfaceParm climb
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm nonsolid
	surfaceParm nolightmap
}

textures/common/clip
{
	qer_editorImage "textures/common/clip.tga"
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm nolightmap
}

textures/common/clipdirt
{
	qer_editorImage "textures/common/clip.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm dirt
	surfaceParm nolightmap
}

textures/common/clipglass
{
	qer_editorImage "textures/common/clip.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm glass
	surfaceParm nolightmap
}

textures/common/clipgrenade
{
	qer_editorImage "textures/common/clipgrenade.tga"
	qer_trans 0.50
	surfaceParm grenadeclip
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm trans
	surfaceParm nolightmap
}

textures/common/clipmetal
{
	qer_editorImage "textures/common/clipmetal.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm metal
	surfaceParm penetrate
	surfaceParm nolightmap
}

textures/common/clipplayer
{
	qer_editorImage "textures/common/clipplayer.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm playerclip
	surfaceParm nolightmap
}

textures/common/clipplayerdirt
{
	qer_editorImage "textures/common/clip.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm playerclip
	surfaceParm nolightmap
	surfaceParm dirt
}

textures/common/clipplayermetal
{
	qer_editorImage "textures/common/clipmetal.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm playerclip
	surfaceParm nolightmap
	surfaceParm metal
}

textures/common/clipplayersnow
{
	qer_editorImage "textures/common/clipwood.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm playerclip
	surfaceParm nolightmap
	surfaceParm snow
}

textures/common/clipplayerwood
{
	qer_editorImage "textures/common/clipwood.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm playerclip
	surfaceParm nolightmap
	surfaceParm wood
}

textures/common/clipsnow
{
	qer_editorImage "textures/common/clip.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm snow
	surfaceParm nolightmap
}

textures/common/cliptile
{
	qer_editorImage "textures/common/clip.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm tile
	surfaceParm nolightmap
}

textures/common/clipvehicle
{
	qer_editorImage "textures/common/clipvehicle.tga"
	qer_trans 0.50
	surfaceParm vehicleclip
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm trans
	surfaceParm nolightmap
}

textures/common/clipwood
{
	qer_editorImage "textures/common/clipwood.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm trans
	surfaceParm wood
	surfaceParm nolightmap
}

textures/common/donotenter
{
	qer_editorImage "textures/common/donotenter.tga"
	qer_trans 0.50
	surfaceparm nodraw
	surfaceparm nonsolid
	surfaceparm trans
	surfaceparm nomarks
	surfaceparm detail
	surfaceparm donotenter
	surfaceParm nolightmap
}

textures/common/hint
{
	qer_editorImage "textures/common/hint.tga"
	qer_trans 0.50
	qer_noCarve
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm structural
	surfaceParm trans
	surfaceParm noimpact
	surfaceParm nolightmap
	surfaceParm hint
}

textures/common/hitmesh
{
	qer_editorImage "textures/common/hitmesh.tga"
	surfaceParm nolightmap
	surfaceParm nomarks
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm noimpact
	surfaceParm nodlight
}

textures/common/lightgrid
{
	qer_editorImage "textures/common/lightgrid.tga"
	surfaceParm nodraw
	surfaceParm nolightmap
	surfaceParm nonsolid
	surfaceParm detail
	surfaceParm nomarks
	surfaceParm trans
	surfaceParm lightgrid
}

textures/common/nodraw
{
	qer_editorImage "textures/common/nodraw.tga"
	qer_trans 0.50
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm trans
	surfaceParm nomarks
	surfaceParm nolightmap
}

textures/common/origin
{
	qer_editorImage "textures/common/origin.tga"
	qer_trans 0.50
	qer_noCarve
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm origin
	surfaceParm nolightmap
}

textures/common/rtsurface
{
	surfaceParm nolightmap
	qer_editorImage "textures/common/rtsurface.tga"
}

textures/common/skip
{
	qer_editorImage "textures/common/skip.tga"
	qer_trans 0.50
	qer_noCarve
	surfaceParm nodraw
	surfaceParm nonsolid
	surfaceParm structural
	surfaceParm trans
	surfaceParm nolightmap
}

textures/common/skyportal
{
	qer_editorImage "textures/common/skyportal.tga"
	surfaceParm noimpact
	surfaceParm nolightmap
	surfaceParm sky
	surfaceParm nodlight
	skyParms - 512 -
}

textures/common/terrain
{
	qer_editorImage "textures/common/terrain.tga"
	surfaceParm nodraw
	surfaceParm nomarks
	surfaceParm nolightmap
}

textures/common/terrain2
{
	qer_editorImage "textures/common/terrain.tga"
	surfaceParm dust
	surfaceParm nodraw
	surfaceParm nomarks
	surfaceParm nolightmap
}

textures/common/trigger
{
	qer_editorImage "textures/common/trigger.tga"
	qer_trans 0.50
	qer_noCarve
	surfaceParm nodraw
	surfaceParm nolightmap
}
