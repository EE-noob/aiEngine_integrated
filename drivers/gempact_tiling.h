#ifndef GEMPACT_TILING_H
#define GEMPACT_TILING_H
#include <stdint.h>
/* Host/compiler helper. rows/cols refer to the public logical output shape. */
typedef struct {
    uint32_t ia_reuse, w_reuse;
    uint32_t row_groups, row_tail_tiles, col_groups, col_tail_tiles;
} gempact_tiling_t;
static inline uint32_t gempact_floor_supported(uint32_t x) {
    uint32_t p=1;
    if (x==25) return 25;
    while (p <= x/2u) p <<= 1;
    return p;
}
static inline int gempact_plan_tiling(uint32_t rows, uint32_t cols,
    uint32_t size, uint32_t cache, uint32_t ps, uint32_t req_r, uint32_t req_w,
    int is_mode, int per_channel, gempact_tiling_t *out) {
    uint32_t tr,tc,rc,wc,wr,r,w,tmp;
    if (!out || !rows || !cols || !size || (size & (size-1u)) || !cache || !ps) return 0;
    if (is_mode) {tmp=rows;rows=cols;cols=tmp;}
    tr=rows/size+(rows%size!=0u);tc=cols/size+(cols%size!=0u);
    tmp=cache/2u;if (!tmp) tmp=1;
    rc=gempact_floor_supported(tr<tmp?tr:tmp);
    wr=tc<ps?tc:ps;wc=gempact_floor_supported(wr);
    r=gempact_floor_supported(!req_r||req_r>=rc?rc:req_r);
    w=gempact_floor_supported(!req_w||req_w>=wc?wc:req_w);
    if (is_mode && per_channel && r>wc) r=wc;
    if (is_mode && w<r && wr>=r) w=r;
    out->ia_reuse=r;out->w_reuse=w;
    out->row_groups=tr/r+(tr%r!=0u);out->row_tail_tiles=tr%r?tr%r:r;
    out->col_groups=tc/w+(tc%w!=0u);out->col_tail_tiles=tc%w?tc%w:w;
    return out->row_groups<=65535u && out->col_groups<=65535u && r<=65535u && w<=65535u;
}

/* Logical sector-pool admission, host only. pool_bytes=0 selects the legacy
 * uncompressed profile. For the current fixed 16-lane codec every record may
 * require 64 B. Include the spare frame used while reading the old frame and
 * writing the new frame; do not budget from an average compression ratio.
 * The independent mode directory is NOT deducted from the payload pool twice.
 */
static inline uint64_t gempact_ps_payload_bound(uint32_t size, uint32_t r,
                                               uint32_t w) {
    return (((uint64_t)r+1u)*size-1u)*((uint64_t)w+1u)*size*4u;
}
static inline int gempact_supported_reuse(uint32_t x) {
    return x && ((x & (x-1u))==0u || x==25u);
}
static inline int gempact_plan_capacity(uint32_t rows, uint32_t cols,
    uint32_t size, uint32_t cache, uint32_t ps, uint32_t req_r, uint32_t req_w,
    int is_mode, int per_channel, uint32_t pool_bytes,
    gempact_tiling_t *out, uint64_t *payload_bound) {
    gempact_tiling_t cap, candidate, best;
    uint64_t best_cost=UINT64_MAX, best_area=0, best_bytes=UINT64_MAX;
    uint32_t tr,tc,sr,sc,r,w; int found=0;
    if (!out || !gempact_plan_tiling(rows,cols,size,cache,ps,req_r,req_w,
                                     is_mode,per_channel,&cap)) return 0;
    if (!pool_bytes) {
        *out=cap; if(payload_bound) *payload_bound=0; return 1;
    }
    /* The sector codec is a fixed 16xINT32 record, unlike the legacy RAM. */
    if (size!=16u || pool_bytes%64u) return 0;
    if (gempact_ps_payload_bound(size,cap.ia_reuse,cap.w_reuse)<=pool_bytes) {
        *out=cap;
        if(payload_bound) *payload_bound=gempact_ps_payload_bound(size,cap.ia_reuse,cap.w_reuse);
        return 1;
    }
    sr=is_mode?cols:rows; sc=is_mode?rows:cols;
    tr=sr/size+(sr%size!=0u); tc=sc/size+(sc%size!=0u);
    /* At most 16 powers of two and the special factor 25 are evaluated. */
    for (uint32_t ri=0;ri<17u;ri++) {
        r=ri==16u?25u:(1u<<ri);
        if (r>cap.ia_reuse) continue;
        for (uint32_t wi=0;wi<17u;wi++) {
            uint64_t bytes,cost,area;
            w=wi==16u?25u:(1u<<wi);
            if (w>cap.w_reuse) continue;
            if (!gempact_plan_tiling(rows,cols,size,cache,ps,r,w,is_mode,
                                     per_channel,&candidate)) continue;
            /* IS legality can increase W; evaluate the actual pair only. */
            if (candidate.ia_reuse!=r || candidate.w_reuse!=w) continue;
            bytes=gempact_ps_payload_bound(size,r,w);
            if (bytes>pool_bytes) continue;
            cost=(uint64_t)sr*(tc/w+(tc%w!=0u))+
                 (uint64_t)sc*(tr/r+(tr%r!=0u));
            area=(uint64_t)r*w;
            if (!found || cost<best_cost || (cost==best_cost &&
                (area>best_area || (area==best_area && bytes<best_bytes)))) {
                found=1; best=candidate;best_cost=cost;best_area=area;best_bytes=bytes;
            }
        }
    }
    if (!found) return 0;
    *out=best;if(payload_bound) *payload_bound=best_bytes;return 1;
}
#endif
