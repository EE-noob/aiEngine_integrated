"""Python standard-library interface to the unmodified, compiled RTL simulation."""
import ctypes as ct
import hashlib
import json
import platform
import os
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
UINT64_MAX = (1 << 64)-1
SCALARS = [
    "rst_n", "calc_start", "sa_ready", "done_valid", "err_code",
    "ia_row_valid", "store_weight_req", "acc_valid", "requant_valid",
    "fifo_full", "tile_over", "axi_flags", "araddr", "arlen", "rdata",
    "awaddr", "awlen", "wdata", "wstrb", "controller_state", "ia_l1_switch",
    "ia_tile_start", "ia_calc_done", "weight_valid", "fifo_valid", "fifo_ready",
    "ia_dma_done", "kernel_dma_done", "oa_dma_done", "is_mode",
    "int16_output", "int16_input",
]
LANES = ["ia", "weight", "acc", "requant"]

def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read_words(path):
    """Read this project's 32-bit, one-hex-word-per-line memory format."""
    words = []
    for raw in Path(path).read_text().splitlines():
        line = raw.split("//", 1)[0].strip()
        if not line:
            continue
        if line.startswith("@"):
            address = int(line[1:], 16)
            if address < len(words):
                raise ValueError(f"{path}: backwards @ address is not supported")
            words.extend([0] * (address-len(words)))
            continue
        for token in line.split():
            value = int(token, 16)
            if not 0 <= value <= 0xffffffff:
                raise ValueError(f"{path}: expected 32-bit words")
            words.append(value)
    return words

def config_words(case):
    cfg = read_words(Path(case)/"config.mem")
    if len(cfg) != 32 or cfg[0] != 0x4e505531:
        raise ValueError("Expected a 32-word NPU1 config.mem from top_regression/gen_mem.py")
    if min(cfg[3:6]) < 1:
        raise ValueError("This interface requires positive K/N/M")
    if not (0 < cfg[10] <= cfg[11] <= 131072):
        raise ValueError("Memory bounds exceed the original RTL testbench")
    if not (cfg[30] & 65535) or not (cfg[30] >> 16) or not (cfg[31] & 65535) or not (cfg[31] >> 16):
        raise ValueError("External tiling is required: generate with the current gen_mem.py or run top_regression/host_tiling.py SOURCE DESTINATION")
    return cfg

class _ServerLib:
    """C ABI shaped adapter for the static process; no shared-library ABI needed."""
    def __init__(self, binary):
        self.binary = binary

    def _read(self):
        line = self.pipe.readline()
        if not line:
            raise RuntimeError(f"RTL process ended unexpectedly (exit={self.process.poll()})")
        return json.loads(line)

    def _command(self,text):
        self.process.stdin.write((text+"\n").encode()); self.process.stdin.flush()
        return self._read()

    def npu_create(self,argc,argv):
        read_fd,write_fd = os.pipe()
        try:
            args = [argv[i].decode() for i in range(1,argc)]
            self.process = subprocess.Popen(
                [str(self.binary),f"--api-fd={write_fd}",*args],
                stdin=subprocess.PIPE,pass_fds=(write_fd,),
            )
        except Exception:
            os.close(read_fd)
            raise
        finally:
            os.close(write_fd)
        self.pipe = os.fdopen(read_fd,"r")
        self.state = self._read()
        return 1

    def npu_destroy(self,handle):
        try:
            if self.process.poll() is None:
                self._command("close")
        finally:
            self.process.stdin.close()
            self.pipe.close()
            self.process.wait(timeout=10)

    def npu_step(self,handle):
        self.state = self._command("step")
        return self.state["advanced"]

    def npu_run(self,handle,limit):
        self.state = self._command(f"run {limit}")
        if self.state["advanced"] < 0:
            raise RuntimeError("RTL event queue became empty before $finish")

    def npu_finished(self,handle): return self.state["finished"]
    def npu_cycles(self,handle): return self.state["cycles"]
    def npu_time_ps(self,handle): return self.state["time_ps"]
    def npu_start_cycle(self,handle): return self.state["start"]
    def npu_ready_cycle(self,handle): return self.state["ready"]
    def npu_scalar(self,handle,index): return self.state["scalars"][index]
    def npu_lane(self,handle,kind,index): return self.state["lanes"][kind][index]
    def npu_flush(self,handle): self._command("flush")
    def npu_read_words(self,handle,start,count,out):
        words = self._command(f"memory {start+count}")
        for i,value in enumerate(words[start:]): out[i] = value

def available_backends():
    return sorted(p.parent for p in (HERE/"backends").glob("*/manifest.json"))

class NpuModel:
    """One original testbench instance. step() advances one rising-edge sample.

    This is a Python interface, not a handwritten approximation of RTL timing.
    Only one instance may be active in a process at a time. Use subprocesses for
    parallel test cases or different backend configurations.
    """
    _active = False

    def __init__(self, case, backend=None, trace=None, plusargs=(),
                 timeout_cycles=2_000_000, verify_sources=True):
        if NpuModel._active:
            raise RuntimeError("Use one active model per process; close the previous instance")
        self.handle = None
        self.case = Path(case).resolve()
        self.cfg = config_words(self.case)
        if platform.system() != "Linux" or platform.machine() not in ("x86_64", "AMD64"):
            raise RuntimeError("The packaged backend requires Linux x86_64; see README for rebuild")
        tag = f"s{self.cfg[1]}_c{self.cfg[2]}_p{self.cfg[9]}"
        self.backend = Path(backend).resolve() if backend else HERE/"backends"/tag
        manifest_file = self.backend/"manifest.json"
        if not manifest_file.exists():
            choices = ", ".join(p.name for p in available_backends())
            raise FileNotFoundError(f"No prebuilt backend {tag}; available: {choices}")
        self.manifest = json.loads(manifest_file.read_text())
        for idx, key in [(1,"size"),(2,"ia_cache_blocks"),(9,"ps_frame_count")]:
            if self.cfg[idx] != self.manifest[key]:
                raise ValueError(f"Case {key} differs from the frozen backend")
        if verify_sources:
            for name, expected in self.manifest["sources"].items():
                path = ROOT/name
                if not path.is_file() or sha256(path) != expected:
                    raise ValueError(f"RTL/testbench differs from compiled snapshot: {name}")
            for name, expected in self.manifest["adapter_sources"].items():
                if sha256(HERE/name) != expected:
                    raise ValueError(f"Adapter differs from compiled snapshot: {name}")
        self.golden = read_words(self.case/"golden.mem")
        init = read_words(self.case/"init.mem")
        if len(self.golden) < self.cfg[11] or len(init) < self.cfg[11]:
            raise ValueError("init.mem/golden.mem shorter than config.mem memory size")
        libpath = self.backend/"libnpu_model.so"
        server = self.backend/"rtl_server"
        use_server = server.is_file()
        binary = server if use_server else libpath
        expected_hash = self.manifest["server_sha256"] if use_server else self.manifest["library_sha256"]
        if sha256(binary) != expected_hash:
            raise ValueError("Backend checksum mismatch")
        if use_server and not os.access(server,os.X_OK):
            # Python ZipFile.extractall() does not restore Unix executable bits.
            server.chmod(server.stat().st_mode | 0o100)
        try:
            self.lib = _ServerLib(server) if use_server else ct.CDLL(str(libpath))
        except OSError as exc:
            raise RuntimeError(f"Cannot load {libpath}: {exc}. Check the backend ABI requirements.") from exc
        prototypes = {
            "npu_create": ([ct.c_int, ct.POINTER(ct.c_char_p)], ct.c_void_p),
            "npu_destroy": ([ct.c_void_p], None),
            "npu_step": ([ct.c_void_p], ct.c_int),
            "npu_finished": ([ct.c_void_p], ct.c_int),
            "npu_cycles": ([ct.c_void_p], ct.c_uint64),
            "npu_time_ps": ([ct.c_void_p], ct.c_uint64),
            "npu_start_cycle": ([ct.c_void_p], ct.c_uint64),
            "npu_ready_cycle": ([ct.c_void_p], ct.c_uint64),
            "npu_scalar": ([ct.c_void_p,ct.c_uint], ct.c_uint32),
            "npu_lane": ([ct.c_void_p,ct.c_uint,ct.c_uint], ct.c_uint32),
            "npu_read_words": ([ct.c_void_p,ct.c_uint,ct.c_uint,ct.POINTER(ct.c_uint32)], None),
            "npu_flush": ([ct.c_void_p], None),
        }
        if not use_server:
            for name,(arguments,result) in prototypes.items():
                fn = getattr(self.lib,name); fn.argtypes = arguments; fn.restype = result
        args = [
            "python_npu_model", f"+INIT_MEM={self.case/'init.mem'}",
            f"+GOLDEN_MEM={self.case/'golden.mem'}", f"+CASE_MEM={self.case/'config.mem'}",
            f"+TB_TIMEOUT_CYCLES={int(timeout_cycles)}", "+FULL_MEM_CHECK",
        ]
        if trace:
            trace = Path(trace).resolve(); trace.parent.mkdir(parents=True,exist_ok=True)
            args.append(f"+PY_TRACE={trace}")
        forbidden = ["+INIT_MEM=", "+GOLDEN_MEM=", "+CASE_MEM=", "+PY_TRACE=", "+TB_TIMEOUT_CYCLES="]
        for arg in plusargs:
            if not arg.startswith("+") or any(arg.startswith(p) for p in forbidden):
                raise ValueError(f"Unsupported or reserved plusarg: {arg}")
            args.append(arg)
        encoded = [arg.encode() for arg in args]
        self.argv = (ct.c_char_p*len(encoded))(*encoded)
        self.handle = self.lib.npu_create(len(encoded),self.argv)
        if not self.handle:
            raise RuntimeError("RTL model creation failed")
        NpuModel._active = True

    def close(self):
        if self.handle:
            try:
                try:
                    self.lib.npu_flush(self.handle)
                finally:
                    self.lib.npu_destroy(self.handle)
            finally:
                self.handle = None
                NpuModel._active = False

    def __enter__(self):
        return self

    def __exit__(self,*_):
        self.close()

    @property
    def finished(self):
        return bool(self.lib.npu_finished(self.handle))

    @property
    def cycles(self):
        return int(self.lib.npu_cycles(self.handle))

    def step(self, snapshot=True):
        """Return settled state 1 ps after the next rising edge; None at finish."""
        status = self.lib.npu_step(self.handle)
        if status < 0:
            raise RuntimeError("RTL event queue became empty before $finish")
        if not status:
            return None
        return self.snapshot() if snapshot else True

    def snapshot(self):
        result = {"cycle":self.cycles-1,"time_ps":int(self.lib.npu_time_ps(self.handle))}
        result.update({key:int(self.lib.npu_scalar(self.handle,i)) for i,key in enumerate(SCALARS)})
        for kind,key in enumerate(LANES):
            values = [int(self.lib.npu_lane(self.handle,kind,i)) for i in range(self.cfg[1])]
            result[key] = [x-(1<<32) if x & (1<<31) else x for x in values]
        return result

    def memory(self):
        values = (ct.c_uint32*self.cfg[11])()
        self.lib.npu_read_words(self.handle,0,len(values),values)
        return list(values)

    def result(self):
        self.lib.npu_flush(self.handle)
        actual = self.memory()
        differences = [(i,actual[i],self.golden[i]) for i in range(self.cfg[10])
                       if actual[i] != self.golden[i]]
        start = int(self.lib.npu_start_cycle(self.handle))
        ready = int(self.lib.npu_ready_cycle(self.handle))
        complete = start != UINT64_MAX and ready != UINT64_MAX
        err_code = int(self.lib.npu_scalar(self.handle,4))
        return {
            "engine":"original RTL driven by Python", "backend":self.backend.name,
            "finished":self.finished, "passed":bool(self.finished and complete and not differences and not err_code),
            "sampled_rising_edges":self.cycles,
            "start_sample_cycle":start if start != UINT64_MAX else None,
            "ready_sample_cycle":ready if ready != UINT64_MAX else None,
            "start_to_ready_cycles":ready-start if complete else None,
            "clock_period_ps":self.manifest["clock_period_ps"],
            "full_memory_compare_words":self.cfg[10],
            "memory_mismatch_count":len(differences),
            "first_mismatches":[{"word":i,"actual":a,"expected":e} for i,a,e in differences[:16]],
            "err_code":err_code,
            "rtl_sources_sha256":hashlib.sha256(json.dumps(self.manifest["sources"],sort_keys=True).encode()).hexdigest(),
        }

    def run(self,max_cycles=2_000_000):
        if isinstance(self.lib,_ServerLib):
            self.lib.npu_run(self.handle,max_cycles)
            return self.result()
        while not self.finished and self.cycles < max_cycles:
            self.step(snapshot=False)
        return self.result()
