// Statically linked RTL runtime. Python talks to it through a dedicated pipe.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

struct Model;
extern "C" {
Model* npu_create(int, const char**);
void npu_destroy(Model*);
int npu_step(Model*);
int npu_finished(Model*);
uint64_t npu_cycles(Model*);
uint64_t npu_time_ps(Model*);
uint64_t npu_start_cycle(Model*);
uint64_t npu_ready_cycle(Model*);
uint32_t npu_scalar(Model*, unsigned);
uint32_t npu_lane(Model*, unsigned, unsigned);
void npu_read_words(Model*, unsigned, unsigned, uint32_t*);
void npu_flush(Model*);
}
#ifndef MODEL_SIZE
#define MODEL_SIZE 16
#endif

static void status(FILE* out, Model* model, int advanced) {
    std::fprintf(out, "{\"advanced\":%d,\"finished\":%d,\"cycles\":%llu,"
                 "\"time_ps\":%llu,\"start\":%llu,\"ready\":%llu,\"scalars\":[",
                 advanced,npu_finished(model),(unsigned long long)npu_cycles(model),
                 (unsigned long long)npu_time_ps(model),
                 (unsigned long long)npu_start_cycle(model),
                 (unsigned long long)npu_ready_cycle(model));
    for (unsigned i=0;i<32;++i) std::fprintf(out,"%s%u",i?",":"",npu_scalar(model,i));
    std::fputs("],\"lanes\":[",out);
    for (unsigned kind=0;kind<4;++kind) {
        std::fputs(kind?",[":"[",out);
        for (unsigned i=0;i<MODEL_SIZE;++i)
            std::fprintf(out,"%s%u",i?",":"",npu_cycles(model)?npu_lane(model,kind,i):0);
        std::fputc(']',out);
    }
    std::fputs("]}\n",out); std::fflush(out);
}

int main(int argc, char** argv) {
    int api_fd = -1;
    for (int i=1;i<argc;++i)
        if (std::strncmp(argv[i],"--api-fd=",9)==0) api_fd=std::atoi(argv[i]+9);
    if (api_fd < 0) { std::fputs("Run through the Python runtime.\n",stderr); return 2; }
    FILE* out=fdopen(api_fd,"w");
    if (!out) return 2;
    Model* model=npu_create(argc,const_cast<const char**>(argv));
    status(out,model,0);
    char command[128];
    while (std::fgets(command,sizeof(command),stdin)) {
        if (std::strncmp(command,"step",4)==0) {
            const int advanced=npu_step(model);
            status(out,model,advanced);
        } else if (std::strncmp(command,"run ",4)==0) {
            const uint64_t limit=std::strtoull(command+4,nullptr,10);
            int advanced=0;
            while (!npu_finished(model) && npu_cycles(model)<limit) {
                advanced=npu_step(model);
                if (advanced<0) break;
            }
            npu_flush(model); status(out,model,advanced);
        } else if (std::strncmp(command,"memory ",7)==0) {
            const unsigned count=std::strtoul(command+7,nullptr,10);
            if (count>131072) { std::fputs("[]\n",out); std::fflush(out); continue; }
            std::vector<uint32_t> memory(count);
            npu_read_words(model,0,count,memory.data());
            std::fputc('[',out);
            for (unsigned i=0;i<count;++i) std::fprintf(out,"%s%u",i?",":"",memory[i]);
            std::fputs("]\n",out); std::fflush(out);
        } else if (std::strncmp(command,"flush",5)==0) {
            npu_flush(model); std::fputs("{}\n",out); std::fflush(out);
        } else if (std::strncmp(command,"close",5)==0) {
            npu_destroy(model); model=nullptr;
            std::fputs("{}\n",out); std::fflush(out); break;
        }
    }
    if (model) npu_destroy(model);
    std::fclose(out);
    return 0;
}
