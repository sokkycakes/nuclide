/* Included by gl_heightmap.c after its terrain loader helpers.
 * FTEW rendering reuses patch batches; collision uses the shared BIH path,
 * never the terrain editor's approximate patch selection collision.
 * Copyright (c) 2026. SPDX-License-Identifier: GPL-2.0-or-later */
#include "fte_world_format.h"
#include "com_bih.h"

static void FTEW_InitModel(model_t *m, const char *entities)
{
    heightmap_t *hm=Z_Malloc(sizeof(*hm));
    m->type=mod_heightmap; m->fromgame=fg_quake;
    m->terrain=hm; ClearBounds(m->mins,m->maxs); ClearLink(&hm->recycle);
    COM_FileBase(m->name,hm->path,sizeof(hm->path));
    hm->entitylock=Sys_CreateMutex(); hm->sectionsize=1024;
    hm->firstsegx=hm->maxsegx=hm->firstsegy=hm->maxsegy=CHUNKBIAS;
    hm->defaultgroundtype=DGT_HOLES; hm->exteriorcontents=FTECONTENTS_EMPTY;
    hm->brushlmscale=16;
    /* An empty sky mesh asks the renderer for an infinite background. The
     * native r_skybox override remains authoritative, even without BSP faces. */
    if (*entities) Q_strncpyz(hm->skyname,"@ftew",sizeof(hm->skyname));
    Q_strncpyz(hm->groundshadername,"terrainshader",sizeof(hm->groundshadername));
    Mod_SetEntitiesString(m,entities,true);
    m->funcs.LightPointValues=Heightmap_LightPointValues;
    m->funcs.StainNode=Heightmap_StainNode;
    m->funcs.MarkLights=Heightmap_MarkLights;
    m->funcs.ClusterForPoint=Heightmap_ClusterForPoint;
    m->funcs.ClusterPVS=Heightmap_ClusterPVS;
#ifdef HAVE_SERVER
    m->funcs.FindTouchedLeafs=Heightmap_FindTouchedLeafs;
    m->funcs.EdictInFatPVS=Heightmap_EdictInFatPVS;
    m->funcs.FatPVS=Heightmap_FatPVS;
#endif
    m->pvsbytes=sizeof(hmpvs_t);
}

static qboolean QDECL FTEW_Load(model_t *world, void *buffer, size_t size)
{
    fw_file file; char error[160], name[MAX_QPATH];
    fw_mesh *meshes;
    const unsigned char *p, *collider;
    char (*materials)[64];
    uint32_t i,j,k,s,idx,flags,mi;
    size_t leafcount;
    if (!fw_validate(buffer,size,&file,error,sizeof(error))) {
        Con_Printf(CON_ERROR "%s: %s\n",world->name,error); return false;
    }
    materials=BZ_Malloc(sizeof(*materials)*file.materials.count);
    p=file.materials.p;
    for(i=0;i<file.materials.count;++i) {
        uint32_t len=fw_u32(p);p+=4;memcpy(materials[i],p,len);materials[i][len]=0;p+=len;
    }
    meshes=BZ_Malloc(sizeof(*meshes)*file.meshes.count);
    for(i=0,p=file.meshes.p;i<file.meshes.count;++i) p=fw_mesh_next(p,&meshes[i]);
    for(s=0;s<file.models;++s) {
        model_t *m;
        struct bihleaf_s *leafs,*leaf;
        if (!s) m=world;
        else {
            Q_snprintfz(name,sizeof(name),"*%u:%s",s,world->name);
            m=Mod_FindName(name);
            if (m->loadstate==MLS_LOADED) continue;
        }
        FTEW_InitModel(m,s?"":(const char *)file.entities.p);
        leafcount=0;
        for(i=0,p=file.instances.p;i<file.instances.count;++i,p+=60)
            if(fw_u32(p+4)==s && (fw_u32(p+8)&2)) leafcount+=meshes[fw_u32(p)].indices/3;
        for(i=0,p=file.collision.p;i<file.collision.count;++i,p+=36+fw_u32(p+32)*16)
            if(fw_u32(p)==s) ++leafcount;
        leaf=leafs=BZ_Malloc(sizeof(*leafs)*(leafcount?leafcount:1));
        for(i=0,p=file.instances.p;i<file.instances.count;++i,p+=60) {
            fw_mesh *mesh;
            vecV_t *xyz;
            index_t *indexes;
            vec3_t basis[3],origin;
            float det;
            if(fw_u32(p+4)!=s) continue;
            mi=fw_u32(p);flags=fw_u32(p+8);mesh=&meshes[mi];
            for(j=0;j<3;++j) for(k=0;k<3;++k) basis[j][k]=fw_f32(p+12+(j*3+k)*4);
            for(j=0;j<3;++j) origin[j]=fw_f32(p+48+j*4);
            det=basis[0][0]*(basis[1][1]*basis[2][2]-basis[1][2]*basis[2][1])-basis[1][0]*(basis[0][1]*basis[2][2]-basis[0][2]*basis[2][1])+basis[2][0]*(basis[0][1]*basis[1][2]-basis[0][2]*basis[1][1]);
            xyz=ZG_Malloc(&m->memgroup,sizeof(*xyz)*mesh->vertices);
            indexes=ZG_Malloc(&m->memgroup,sizeof(*indexes)*mesh->indices);
            for(j=0;j<mesh->vertices;++j) {
                float v[3];for(k=0;k<3;++k)v[k]=fw_f32(mesh->v+j*36+k*4);
                for(k=0;k<3;++k) xyz[j][k]=origin[k]+v[0]*basis[0][k]+v[1]*basis[1][k]+v[2]*basis[2][k];
                AddPointToBounds(xyz[j],m->mins,m->maxs);
            }
            for(j=0;j<mesh->indices;j+=3) {
                indexes[j]=fw_u32(mesh->idx+j*4);
                indexes[j+1]=fw_u32(mesh->idx+(j+(det<0?2:1))*4);
                indexes[j+2]=fw_u32(mesh->idx+(j+(det<0?1:2))*4);
                if(flags&2) {
                    leaf->type=BIH_TRIANGLE;leaf->data.contents=FTECONTENTS_SOLID;
                    leaf->data.tri.xyz=xyz;leaf->data.tri.indexes=indexes+j;
                    ClearBounds(leaf->mins,leaf->maxs);
                    for(k=0;k<3;++k)AddPointToBounds(xyz[indexes[j+k]],leaf->mins,leaf->maxs);
                    ++leaf;
                }
#ifdef HAVE_CLIENT
                if((flags&1) && !isDedicated) {
                    qcpatchvert_t cp[4];brushes_t *patch;
                    for(k=0;k<4;++k) {
                        idx=indexes[j+(k==3?2:k)];
                        VectorCopy(xyz[idx],cp[k].v);
                        cp[k].tc[0]=fw_f32(mesh->v+idx*36+12);cp[k].tc[1]=fw_f32(mesh->v+idx*36+16);
                        for(uint32_t c=0;c<4;++c)cp[k].rgba[c]=fw_f32(mesh->v+idx*36+20+c*4);
                    }
                    patch=Terr_Patch_Insert(m,m->terrain,Terr_Brush_FindTexture(m->terrain,materials[mesh->material]),2,2,0,0,cp,2);
                    if(patch)patch->contents=0;
                }
#endif
            }
        }
        for(i=0,collider=file.collision.p;i<file.collision.count;++i,collider+=36+fw_u32(collider+32)*16) {
            q2cbrush_t *brush;
            uint32_t planes;
            if(fw_u32(collider)!=s)continue;
            planes=fw_u32(collider+32);
            brush=ZG_Malloc(&m->memgroup,sizeof(*brush));
            brush->numsides=planes;brush->contents=FTECONTENTS_SOLID;
            brush->brushside=ZG_Malloc(&m->memgroup,sizeof(*brush->brushside)*planes);
            for(j=0;j<3;++j){brush->absmins[j]=fw_f32(collider+8+j*4);brush->absmaxs[j]=fw_f32(collider+20+j*4);}
            for(j=0;j<planes;++j) {
                mplane_t *plane=ZG_Malloc(&m->memgroup,sizeof(*plane));
                plane->type=3;
                for(k=0;k<3;++k){plane->normal[k]=fw_f32(collider+36+j*16+k*4);if(plane->normal[k]<0)plane->signbits|=1<<k;}
                plane->dist=fw_f32(collider+48+j*16);
                brush->brushside[j].plane=plane;
            }
            leaf->type=BIH_BRUSH;leaf->data.contents=brush->contents;leaf->data.brush=brush;
            VectorCopy(brush->absmins,leaf->mins);VectorCopy(brush->absmaxs,leaf->maxs);
            AddPointToBounds(leaf->mins,m->mins,m->maxs);AddPointToBounds(leaf->maxs,m->mins,m->maxs);++leaf;
        }
        BIH_Build(m,leafs,leaf-leafs);BZ_Free(leafs);
        if(m->mins[0]>m->maxs[0]){VectorClear(m->mins);VectorClear(m->maxs);}
        if(s) m->loadstate=MLS_LOADED;
    }
    world->numsubmodels=file.models;
    Con_Printf("FTEW loaded %s: %u meshes, %u instances, %u colliders, %u models\n",world->name,file.meshes.count,file.instances.count,file.collision.count,file.models);
    BZ_Free(materials);BZ_Free(meshes);
    return true;
}

/* Read-only trace diagnostic for editor automation and collision regression checks. */
static void FTEW_Trace_f(void)
{
    model_t *m=NULL;trace_t trace;vec3_t start,end,mins={0,0,0},maxs={0,0,0};int i;
#ifdef HAVE_SERVER
    m=sv.world.worldmodel;
#endif
#ifdef HAVE_CLIENT
    if(!m)m=cl.worldmodel;
#endif
    if(!m || !m->funcs.NativeTrace || Cmd_Argc()<7){Con_Printf("ftew_trace x y z x y z [player_hull]\n");return;}
    for(i=0;i<3;++i){start[i]=atof(Cmd_Argv(1+i));end[i]=atof(Cmd_Argv(4+i));}
    if(atoi(Cmd_Argv(7))){VectorSet(mins,-16,-16,-24);VectorSet(maxs,16,16,32);}
    m->funcs.NativeTrace(m,0,NULL,NULL,start,end,mins,maxs,false,FTECONTENTS_SOLID,&trace);
    Con_Printf("FTEW_TRACE fraction %.6f end %.3f %.3f %.3f startsolid %i\n",trace.fraction,trace.endpos[0],trace.endpos[1],trace.endpos[2],trace.startsolid);
}
