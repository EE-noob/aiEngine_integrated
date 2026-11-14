"""Host-only tiling arithmetic. No counterpart divider is instantiated in RTL."""
from pathlib import Path
import argparse,json,shutil

def floor_supported(value):
    return 25 if value == 25 else 1 << (max(1,value).bit_length()-1)

def plan(rows, cols, size, cache, ps, requested_r=0, requested_w=0, is_mode=False, per_channel=False):
    if min(rows,cols,size,cache,ps) <= 0 or size & (size-1):
        raise ValueError("positive dimensions/capacities and power-of-two array size required")
    if is_mode: rows,cols=cols,rows
    tr=(rows+size-1)//size;tc=(cols+size-1)//size
    rcap=floor_supported(min(tr,max(1,cache//2)));wraw=min(tc,ps);wcap=floor_supported(wraw)
    r=floor_supported(min(requested_r or rcap,rcap));w=floor_supported(min(requested_w or wcap,wcap))
    if is_mode and per_channel: r=min(r,wcap)
    if is_mode and w<r and wraw>=r: w=r
    rg,rt=divmod(tr,r);cg,ct=divmod(tc,w)
    result=dict(ia_reuse=r,w_reuse=w,row_groups=rg+bool(rt),row_tail_tiles=rt or r,
                col_groups=cg+bool(ct),col_tail_tiles=ct or w)
    if max(result.values())>65535:raise ValueError("tiling fields exceed this 16-bit counter profile")
    return result

def payload_bound(size, r, w):
    """Worst-case payload incl. a complete spare frame; directory is separate."""
    return ((r+1)*size-1)*(w+1)*size*4


def plan_capacity(rows, cols, size, cache, ps, requested_r=0, requested_w=0,
                  is_mode=False, per_channel=False, pool_bytes=0):
    if any(not isinstance(x,int) or x<0 or x>0xffffffff for x in [rows,cols,size,cache,ps,requested_r,requested_w,pool_bytes]):
        raise ValueError('host tiling arguments must be unsigned 32-bit integers')
    cap=plan(rows,cols,size,cache,ps,requested_r,requested_w,is_mode,per_channel)
    if not pool_bytes:
        return cap,dict(policy='legacy_uncompressed',payload_bound_bytes=0)
    if size!=16 or pool_bytes<0 or pool_bytes%64:
        raise ValueError('current sector codec requires size=16 and a positive multiple-of-64 pool')
    sr,sc=(cols,rows) if is_mode else (rows,cols)
    tr=(sr+size-1)//size;tc=(sc+size-1)//size
    supported=[1<<i for i in range(16)]+[25]
    choices=[]
    for r in supported:
        if r>cap['ia_reuse']:continue
        for w in supported:
            if w>cap['w_reuse']:continue
            try:candidate=plan(rows,cols,size,cache,ps,r,w,is_mode,per_channel)
            except ValueError:continue
            if (candidate['ia_reuse'],candidate['w_reuse'])!=(r,w):continue
            bound=payload_bound(size,r,w)
            if bound>pool_bytes:continue
            cost=sr*((tc+w-1)//w)+sc*((tr+r-1)//r)
            choices.append(((cost,-r*w,bound),candidate))
    if not choices:raise ValueError('PS pool cannot hold even the smallest guaranteed workgroup')
    key,result=min(choices,key=lambda x:x[0])
    proof=dict(policy='worst_case_INT32',pool_bytes=pool_bytes,
        payload_bound_bytes=key[2],payload_margin_bytes=pool_bytes-key[2],
        max_record_bytes=64,spare_frames=1,
        requested_effective_r=cap['ia_reuse'],requested_effective_w=cap['w_reuse'],
        selected_r=result['ia_reuse'],selected_w=result['w_reuse'],
        changed=result!=cap,input_cost_per_reduction_element=key[0],
        directory_charged_separately=True)
    return result,proof


def apply_words(words,pool_bytes=0):
    if len(words)!=32 or any(x<0 or x>0xffffffff for x in words) or words[0]!=0x4e505531:raise ValueError("expected 32-word NPU1 tensor descriptor")
    p,proof=plan_capacity(words[3],words[5],words[1],words[2],words[9],words[6],words[7],
        bool(words[8] and not words[28]),bool(words[13]),pool_bytes)
    words=list(words);words[6]=p['ia_reuse'];words[7]=p['w_reuse']
    words[30]=p['row_groups'] | (p['col_groups']<<16)
    words[31]=p['row_tail_tiles'] | (p['col_tail_tiles']<<16)
    return words,{**p,'capacity':proof}


def prepare_case(source,dest,pool_bytes=0):
    source=Path(source);dest=Path(dest)
    words=[int(x,16) for x in (source/'config.mem').read_text().split()]
    words,p=apply_words(words,pool_bytes)
    # Fail before writing anything if the shape or capacity is invalid.
    dest.mkdir(parents=True,exist_ok=False)
    for name in ['init.mem','golden.mem']:shutil.copy2(source/name,dest/name)
    (dest/'config.mem').write_text(''.join(f'{x:08x}\n' for x in words))
    (dest/'host_tiling.json').write_text(json.dumps(p,indent=2)+'\n')
    return dest

if __name__=='__main__':
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument('source',type=Path);a.add_argument('destination',type=Path)
    a.add_argument('--pool-bytes',type=int,default=0,
        help='sector payload bytes; 0 explicitly selects the legacy uncompressed profile')
    x=a.parse_args();print(prepare_case(x.source,x.destination,x.pool_bytes))
