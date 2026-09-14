/* FTEW v1: portable, bounds-checked reader. See worldsrc/FORMAT.md.
 * Copyright (c) 2026. SPDX-License-Identifier: MIT */
#ifndef FTE_WORLD_FORMAT_H
#define FTE_WORLD_FORMAT_H
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#define FW_HEADER_SIZE 96
#define FW_MAX_MESHES 4096
#define FW_MAX_INSTANCES 16384
#define FW_MAX_TRIANGLES 50000
#define FW_MAX_MODELS 1024
typedef struct { const unsigned char *p; size_t len; uint32_t count; } fw_section;
typedef struct { fw_section materials, meshes, instances, collision, entities; uint32_t models; } fw_file;
typedef struct { uint32_t material, vertices, indices; const unsigned char *v, *idx; } fw_mesh;

static uint32_t fw_u32(const unsigned char *p)
{ return (uint32_t)p[0] | (uint32_t)p[1]<<8 | (uint32_t)p[2]<<16 | (uint32_t)p[3]<<24; }
static float fw_f32(const unsigned char *p)
{ uint32_t u = fw_u32(p); float f; memcpy(&f, &u, 4); return f; }
static int fw_error(char *error, size_t cap, const char *message)
{ if (cap) snprintf(error, cap, "FTEW: %s", message); return 0; }
static int fw_floats(const unsigned char *p, size_t count)
{
    size_t i;
    for (i=0; i<count; ++i) { float f=fw_f32(p+i*4); if (!isfinite(f) || fabsf(f)>1e8f) return 0; }
    return 1;
}
static const unsigned char *fw_mesh_next(const unsigned char *p, fw_mesh *m)
{
    m->material=fw_u32(p); m->vertices=fw_u32(p+4); m->indices=fw_u32(p+8);
    m->v=p+12; m->idx=m->v+(size_t)m->vertices*36;
    return m->idx+(size_t)m->indices*4;
}
static int fw_validate(const void *data, size_t size, fw_file *out, char *error, size_t cap)
{
    const unsigned char *b=(const unsigned char *)data, *p, *end;
    const char *tags[5]={"MATL","MESH","INST","COLL","ENTS"};
    fw_section *sections[5]={&out->materials,&out->meshes,&out->instances,&out->collision,&out->entities};
    uint32_t i,j,k,off=FW_HEADER_SIZE, n, nv, ni, mesh_counts[FW_MAX_MESHES];
    size_t triangles=0;
    if (size<FW_HEADER_SIZE || size>128u*1024u*1024u || memcmp(b,"FTEW",4)) return fw_error(error,cap,"invalid header or file size");
    if (fw_u32(b+4)!=1) return fw_error(error,cap,"unsupported version (expected 1)");
    if (fw_u32(b+8)!=size) return fw_error(error,cap,"file length does not match header");
    out->models=fw_u32(b+12);
    if (!out->models || out->models>FW_MAX_MODELS) return fw_error(error,cap,"invalid submodel count");
    for (i=0;i<5;++i) {
        const unsigned char *d=b+16+i*16;
        uint32_t len=fw_u32(d+8);
        if (memcmp(d,tags[i],4) || fw_u32(d+4)!=off || len>size-off) return fw_error(error,cap,"invalid section directory");
        sections[i]->p=b+off; sections[i]->len=len; sections[i]->count=fw_u32(d+12); off+=len;
    }
    if (off!=size || out->materials.count>4096 || out->meshes.count>FW_MAX_MESHES || out->instances.count>FW_MAX_INSTANCES || out->collision.count>16384)
        return fw_error(error,cap,"resource count/length limit exceeded");
    p=out->materials.p; end=p+out->materials.len;
    for (i=0;i<out->materials.count;++i) {
        if ((size_t)(end-p)<4) return fw_error(error,cap,"truncated material");
        n=fw_u32(p); p+=4;
        if (!n || n>=64 || n>(size_t)(end-p)) return fw_error(error,cap,"invalid material path length");
        for (j=0;j<n;++j) if (p[j]<33 || p[j]>126 || p[j]=='"' || p[j]=='\\' || p[j]==':' || p[j]==';') return fw_error(error,cap,"invalid material path");
        if (p[0]=='/' || (n>1 && p[0]=='.' && p[1]=='.')) return fw_error(error,cap,"material path must be game-relative");
        for (j=1;j+2<n;++j) if (p[j]=='/' && p[j+1]=='.' && p[j+2]=='.') return fw_error(error,cap,"material traversal is forbidden");
        p+=n;
    }
    if (p!=end) return fw_error(error,cap,"material section length mismatch");
    p=out->meshes.p; end=p+out->meshes.len;
    for (i=0;i<out->meshes.count;++i) {
        if ((size_t)(end-p)<12) return fw_error(error,cap,"truncated mesh");
        n=fw_u32(p); nv=fw_u32(p+4); ni=fw_u32(p+8); p+=12;
        if (n>=out->materials.count || nv<3 || nv>65535 || !ni || ni%3 || ni>FW_MAX_TRIANGLES*3 || (size_t)nv*36+(size_t)ni*4>(size_t)(end-p)) return fw_error(error,cap,"invalid mesh size/material");
        if (!fw_floats(p,(size_t)nv*9)) return fw_error(error,cap,"non-finite mesh vertex");
        p+=(size_t)nv*36;
        for (j=0;j<ni;++j) if (fw_u32(p+j*4)>=nv) return fw_error(error,cap,"mesh index out of range");
        p+=(size_t)ni*4; mesh_counts[i]=ni/3;
    }
    if (p!=end) return fw_error(error,cap,"mesh section length mismatch");
    if (out->instances.len!=(size_t)out->instances.count*60) return fw_error(error,cap,"instance section length mismatch");
    for (i=0,p=out->instances.p;i<out->instances.count;++i,p+=60) {
        double det, m[9];
        n=fw_u32(p);
        if (n>=out->meshes.count || fw_u32(p+4)>=out->models || !(fw_u32(p+8)&3) || (fw_u32(p+8)&~3u) || !fw_floats(p+12,12)) return fw_error(error,cap,"invalid instance");
        for(j=0;j<9;++j) m[j]=fw_f32(p+12+j*4);
        /* Normalize columns first: determinant magnitude otherwise confuses
         * small import unit scales with collapsed transforms. Use doubles so
         * squared float components cannot underflow/overflow here. */
        for (j=0;j<9;j+=3) {
            double length=sqrt(m[j]*m[j]+m[j+1]*m[j+1]+m[j+2]*m[j+2]);
            if (!isfinite(length) || length==0) return fw_error(error,cap,"singular instance transform");
            m[j]/=length;m[j+1]/=length;m[j+2]/=length;
        }
        det=m[0]*(m[4]*m[8]-m[5]*m[7])-m[3]*(m[1]*m[8]-m[2]*m[7])+m[6]*(m[1]*m[5]-m[2]*m[4]);
        if (!isfinite(det) || fabs(det)<1e-6) return fw_error(error,cap,"singular instance transform");
        triangles+=mesh_counts[n];
        if (triangles>FW_MAX_TRIANGLES) return fw_error(error,cap,"expanded triangle budget exceeded (50000)");
    }
    p=out->collision.p; end=p+out->collision.len;
    for (i=0;i<out->collision.count;++i) {
        if ((size_t)(end-p)<36) return fw_error(error,cap,"truncated convex collider");
        n=fw_u32(p+32);
        if (fw_u32(p)>=out->models || fw_u32(p+4)!=1 || n<4 || n>64 || !fw_floats(p+8,6) || (size_t)n*16>(size_t)(end-p-36)) return fw_error(error,cap,"invalid convex collider");
        for (j=0;j<3;++j) if (fw_f32(p+8+j*4)>=fw_f32(p+20+j*4)) return fw_error(error,cap,"empty collider bounds");
        p+=36;
        if (!fw_floats(p,n*4)) return fw_error(error,cap,"non-finite collider plane");
        for (j=0;j<n;++j) {
            float length=0; for(k=0;k<3;++k) {float f=fw_f32(p+j*16+k*4);length+=f*f;}
            if (fabsf(length-1)>0.002f) return fw_error(error,cap,"collider plane normal must be normalized");
        }
        p+=(size_t)n*16;
    }
    if (p!=end) return fw_error(error,cap,"collision section length mismatch");
    if (!out->entities.len || out->entities.len>4*1024*1024 || out->entities.count!=1 || out->entities.p[out->entities.len-1]!=0 || memchr(out->entities.p,0,out->entities.len-1)) return fw_error(error,cap,"invalid entity section");
    if (cap) error[0]=0;
    return 1;
}
#endif
