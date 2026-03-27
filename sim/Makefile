.RECIPEPREFIX := >

compVsys:
>iverilog -g2012 -f ../flist/video_sys.f -s video_sys_top -o video_sys_top.vvp

compV:
>vcs -full64 -sverilog -f ../flist/video_sys.f

compM:
>vcs -full64 -sverilog -f ../flist/MMA.f -l comp.log

compC:
>vcs -full64 -sverilog -f ../flist/nice_core.f -l comp.log

compA:
>vcs -full64 -sverilog -f ../flist/ai_engine.f -l comp.log

clr:
>rm -rf *csrc ./*.daidir $(simv_name) *simv* DVE* ucli* *.vpd *.vdb *.log *.fsdb *novas* *.dat *Log *conf

TB_AXIL_CSR    = mma_axil_csr_tb
FLIST_AXIL_CSR = mma_axil_csr_tb.f

compAxilCsrTb:
>iverilog -g2012 -f $(FLIST_AXIL_CSR) -s $(TB_AXIL_CSR) -o $(TB_AXIL_CSR).vvp

runAxilCsrTb: compAxilCsrTb
>vvp $(TB_AXIL_CSR).vvp

waveAxilCsrTb: runAxilCsrTb
>@if command -v gtkwave >/dev/null 2>&1; then \
>  gtkwave $(TB_AXIL_CSR).vcd; \
>elif command -v verdi >/dev/null 2>&1; then \
>  verdi -sv -f $(FLIST_AXIL_CSR) -ssf $(TB_AXIL_CSR).fsdb; \
>else \
>  echo "No waveform viewer found (gtkwave/verdi)."; \
>fi
