#include "engine/fte_world_format.h"
#include <stdlib.h>
#include <assert.h>

int main(int argc,char **argv)
{
    FILE *f;
    unsigned char *data,*copy;
    long length;
    size_t i;
    fw_file file;
    char error[160];
    if(argc!=2 && argc!=3)return 2;
    f=fopen(argv[1],"rb");if(!f)return 2;
    fseek(f,0,SEEK_END);length=ftell(f);rewind(f);
    if(length<0)return 2;
    data=malloc(length);copy=malloc(length);
    if(!data||!copy)return 2;
    if(fread(data,1,length,f)!=(size_t)length)return 2;
    fclose(f);
    if(!fw_validate(data,length,&file,error,sizeof(error))){puts(error);return 1;}
    printf("Valid world: %u meshes, %u instances, %u models\n",file.meshes.count,file.instances.count,file.models);
    if(argc==3 && !strcmp(argv[2],"--validate-only")) {free(data);free(copy);return 0;}
    assert(file.meshes.count==6 && file.instances.count==8 && file.models==2);
    for(i=0;i<(size_t)length;++i)assert(!fw_validate(data,i,&file,error,sizeof(error)));
    memcpy(copy,data,length);copy[4]=99;assert(!fw_validate(copy,length,&file,error,sizeof(error)));
    memcpy(copy,data,length);copy[20]=0;assert(!fw_validate(copy,length,&file,error,sizeof(error)));
    assert(fw_validate(data,length,&file,error,sizeof(error)));
    i=file.meshes.p-data+12;
    memcpy(copy,data,length);copy[i]=0;copy[i+1]=0;copy[i+2]=0xc0;copy[i+3]=0x7f;
    assert(!fw_validate(copy,length,&file,error,sizeof(error)));
    assert(fw_validate(data,length,&file,error,sizeof(error)));
    i=file.instances.p-data;
    memcpy(copy,data,length);memset(copy+i,0xff,4);assert(!fw_validate(copy,length,&file,error,sizeof(error)));
    memcpy(copy,data,length);memset(copy+i+12,0,36);assert(!fw_validate(copy,length,&file,error,sizeof(error)));
    /* Small, nonuniform, and mirrored import scales remain invertible. */
    {
        float matrices[][9]={{.001724f,0,0,0,.001724f,0,0,0,.001724f},
                            {-.0001f,0,0,0,.002f,0,0,0,2},
                            {1,0,0,.25f,1,0,0,0,1}};
        size_t k;
        for(k=0;k<sizeof(matrices)/sizeof(matrices[0]);++k) {
            memcpy(copy,data,length);memcpy(copy+i+12,matrices[k],36);
            assert(fw_validate(copy,length,&file,error,sizeof(error)));
        }
        /* Nonzero columns can still be dependent or almost parallel. */
        memcpy(copy,data,length);memcpy(copy+i+24,copy+i+12,12);
        assert(!fw_validate(copy,length,&file,error,sizeof(error)));
        {
            float parallel[9]={1,0,0,1,1e-8f,0,0,0,1};
            memcpy(copy,data,length);memcpy(copy+i+12,parallel,36);
            assert(!fw_validate(copy,length,&file,error,sizeof(error)));
        }
    }
    memcpy(copy,data,length);copy[length-1]='x';assert(!fw_validate(copy,length,&file,error,sizeof(error)));
    free(data);free(copy);
    puts("PASS: truncations, invalid records, small/mirrored/sheared transforms, collapsed/dependent axes, missing entity terminator");
    return 0;
}
